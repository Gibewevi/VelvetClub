"""Native-resolution isometric painter.

Each sprite pixel is decided once: the pixel's centre is traced along the
fixed 2:1 view direction against a handful of simple solids (boxes,
cylinders, ellipsoids). The hit decides *which* material and *which* tone of
its hand-picked ramp the pixel receives; there is no anti-aliasing, blur,
supersampling or downscaling. Pixel-art rules are then applied: 2:1 edges,
selective dark outlines, lit top edges and flat cel bands.
"""
from __future__ import annotations

import math

import numpy as np

from pa_core import HALF_H, HALF_W, PX_PER_M_Y, ramp, hexrgb, mix, INK

V = np.array([1.0, 2.0 * HALF_H / PX_PER_M_Y, 1.0])  # (1, 2/3, 1): towards the viewer
_L = np.array([0.35, 1.0, 0.75])
L = _L / np.linalg.norm(_L)
NEG = -1e9


def screen(p):
    """World metres -> screen pixels (float)."""
    x, y, z = p
    return (HALF_W * (x - z), HALF_H * (x + z) - PX_PER_M_Y * y)


class Mat:
    """A material is a 6-tone ramp: 0 outline, 1 deep, 2 shade, 3 base, 4 lit, 5 highlight."""

    def __init__(self, base=None, tones=None, emissive=False, bias=0, line=True, flat=None, name=""):
        if tones is None:
            tones = ramp(base)
        self.tones = [hexrgb(t) if isinstance(t, str) else tuple(t) for t in tones]
        self.emissive = emissive
        self.bias = bias
        self.line = line          # draws dark separation lines against nearer parts
        self.flat = flat          # force a single tone index regardless of normal
        self.name = name
        self.slot = None          # palette slot for recolourable art (walls, floors)


class Prim:
    def __init__(self, kind, A, T, mat, pattern=None, group=None, ylim=None, lit=True, shadow=True):
        self.kind = kind
        self.A = np.array(A, dtype=float)
        self.T = np.array(T, dtype=float)
        self.mat = mat
        self.pattern = pattern
        self.group = group
        self.ylim = ylim
        self.lit = lit
        self.shadow = shadow

    def corners(self):
        if self.kind == "tri":
            base = [(0,0,0),(1,0,0),(0,1,0)]
        elif self.kind == "box":
            base = [(x, y, z) for x in (-1, 1) for y in (-1, 1) for z in (-1, 1)]
        elif self.kind == "cyl":
            base = [(x, y, z) for x in (-1, 1) for y in (0, 1) for z in (-1, 1)]
        else:
            base = [(x, y, z) for x in (-1, 1) for y in (-1, 1) for z in (-1, 1)]
        return [self.A @ np.array(c, dtype=float) + self.T for c in base]

    def transformed(self, R, pivot=(0, 0, 0)):
        R = np.array(R, dtype=float)
        pivot = np.array(pivot, dtype=float)
        p = Prim(self.kind, R @ self.A, R @ (self.T - pivot) + pivot, self.mat, self.pattern, self.group, self.ylim, self.lit, self.shadow)
        p.R_total = R @ getattr(self, "R_total", np.eye(3))
        p.part = getattr(self, "part", None)
        return p


# ----------------------------------------------------------------- builders

def box(x0, y0, z0, x1, y1, z1, mat, **kw):
    c = ((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2)
    return Prim("box", np.diag([abs(x1 - x0) / 2, abs(y1 - y0) / 2, abs(z1 - z0) / 2]), c, mat, **kw)


def boxc(cx, cy, cz, sx, sy, sz, mat, **kw):
    """Box from its centre (cy = bottom) and full sizes."""
    return box(cx - sx / 2, cy, cz - sz / 2, cx + sx / 2, cy + sy, cz + sz / 2, mat, **kw)


def cyl(cx, y0, cz, r, h, mat, rz=None, **kw):
    return Prim("cyl", np.diag([r, h, rz if rz is not None else r]), (cx, y0, cz), mat, **kw)


def ell(cx, cy, cz, rx, ry, rz, mat, ylim=None, **kw):
    return Prim("sph", np.diag([rx, ry, rz]), (cx, cy, cz), mat, ylim=ylim, **kw)


def triangle(a, b, c, mat, **kw):
    """A cloth surface: one ray per final pixel, no smoothing/downsampling."""
    a,b,c = (np.array(p,dtype=float) for p in (a,b,c))
    u,v = b-a,c-a
    n = np.cross(u,v)
    n /= np.linalg.norm(n)
    return Prim("tri",np.column_stack([u,v,n]),a,mat,**kw)


def lathe(cx, y0, cz, profile, mat, step=1.0 / PX_PER_M_Y, rz_scale=1.0, **kw):
    """Stack of 1 px high discs following (height, radius) pairs."""
    out = []
    ys = [p[0] for p in profile]
    rs = [p[1] for p in profile]
    y = ys[0]
    group = kw.pop("group", object())
    while y < ys[-1] - 1e-6:
        r = float(np.interp(y + step / 2, ys, rs))
        if r > 0.004:
            out.append(cyl(cx, y0 + y, cz, r, step, mat, rz=r * rz_scale, group=group, **kw))
        y += step
    return out


def rot_y(deg):
    a = math.radians(deg)
    c, s = math.cos(a), math.sin(a)
    return np.array([[c, 0, s], [0, 1, 0], [-s, 0, c]])


def rot_x(deg):
    a = math.radians(deg)
    c, s = math.cos(a), math.sin(a)
    return np.array([[1, 0, 0], [0, c, -s], [0, s, c]])


def rot_z(deg):
    a = math.radians(deg)
    c, s = math.cos(a), math.sin(a)
    return np.array([[c, -s, 0], [s, c, 0], [0, 0, 1]])


def turn(prims, R, pivot=(0, 0, 0)):
    return [p.transformed(R, pivot) for p in prims]


def rod(a, b, r, mat, **kw):
    """Cylinder between two points."""
    a = np.array(a, dtype=float)
    b = np.array(b, dtype=float)
    d = b - a
    length = np.linalg.norm(d)
    up = d / length
    # Build an orthonormal frame whose y axis follows the rod.
    helper = np.array([1.0, 0, 0]) if abs(up[0]) < 0.9 else np.array([0, 0, 1.0])
    xa = np.cross(helper, up)
    xa /= np.linalg.norm(xa)
    za = np.cross(xa, up)
    A = np.column_stack([xa * r, up * length, za * r])
    return Prim("cyl", A, a, mat, **kw)


# ------------------------------------------------------------ intersection

def _intersect(p: Prim, O: np.ndarray):
    Ainv = np.linalg.inv(p.A)
    o = (O - p.T) @ Ainv.T
    d = Ainv @ V
    n = O.shape[0]
    normal = np.zeros((n, 3))
    if p.kind == "tri":
        if abs(d[2]) < 1e-12:
            t = np.full(n,NEG)
            local = np.zeros((n,3))
        else:
            distance = -o[:,2]/d[2]
            local = o+distance[:,None]*d
            hit = (local[:,0] >= -1e-8) & (local[:,1] >= -1e-8) & (local[:,0]+local[:,1] <= 1+1e-8)
            t = np.where(hit,distance,NEG)
        normal[:,2] = 1 if d[2] >= 0 else -1
    elif p.kind == "box":
        lo = np.full(n, -np.inf)
        hi = np.full(n, np.inf)
        axis = np.zeros(n, dtype=int)
        for k in range(3):
            if abs(d[k]) < 1e-12:
                bad = np.abs(o[:, k]) > 1
                lo[bad] = np.inf
                continue
            t1 = (-1 - o[:, k]) / d[k]
            t2 = (1 - o[:, k]) / d[k]
            lo = np.maximum(lo, np.minimum(t1, t2))
            h = np.maximum(t1, t2)
            upd = h < hi
            axis[upd] = k
            hi = np.minimum(hi, h)
        hit = hi >= lo
        t = np.where(hit, hi, NEG)
        normal[np.arange(n), axis] = np.sign(d[axis])
        local = o + t[:, None] * d
    elif p.kind == "cyl":
        a = d[0] ** 2 + d[2] ** 2
        b = 2 * (o[:, 0] * d[0] + o[:, 2] * d[2])
        c = o[:, 0] ** 2 + o[:, 2] ** 2 - 1
        if a < 1e-12:
            r1 = np.where(c <= 0, -np.inf, np.inf)
            r2 = np.where(c <= 0, np.inf, -np.inf)
        else:
            disc = b * b - 4 * a * c
            sq = np.sqrt(np.maximum(disc, 0))
            r1 = np.where(disc >= 0, (-b - sq) / (2 * a), np.inf)
            r2 = np.where(disc >= 0, (-b + sq) / (2 * a), -np.inf)
        if abs(d[1]) < 1e-12:
            ylo = np.where((o[:, 1] >= 0) & (o[:, 1] <= 1), -np.inf, np.inf)
            yhi = np.where((o[:, 1] >= 0) & (o[:, 1] <= 1), np.inf, -np.inf)
        else:
            ty1 = (0 - o[:, 1]) / d[1]
            ty2 = (1 - o[:, 1]) / d[1]
            ylo, yhi = np.minimum(ty1, ty2), np.maximum(ty1, ty2)
        tmin = np.maximum(r1, ylo)
        tmax = np.minimum(r2, yhi)
        hit = tmax >= tmin
        t = np.where(hit, tmax, NEG)
        local = o + np.where(hit, t, 0)[:, None] * d
        side = r2 <= yhi
        normal[:, 0] = np.where(side, local[:, 0], 0)
        normal[:, 2] = np.where(side, local[:, 2], 0)
        normal[:, 1] = np.where(side, 0, np.sign(d[1]))
    else:
        a = d @ d
        b = 2 * (o @ d)
        c = np.einsum("ij,ij->i", o, o) - 1
        disc = b * b - 4 * a * c
        sq = np.sqrt(np.maximum(disc, 0))
        r1 = np.where(disc >= 0, (-b - sq) / (2 * a), np.inf)
        r2 = np.where(disc >= 0, (-b + sq) / (2 * a), -np.inf)
        ylo = np.full(n, -np.inf)
        yhi = np.full(n, np.inf)
        if p.ylim is not None and abs(d[1]) > 1e-12:
            ty1 = (p.ylim[0] - o[:, 1]) / d[1]
            ty2 = (p.ylim[1] - o[:, 1]) / d[1]
            ylo, yhi = np.minimum(ty1, ty2), np.maximum(ty1, ty2)
        tmin = np.maximum(r1, ylo)
        tmax = np.minimum(r2, yhi)
        hit = tmax >= tmin
        t = np.where(hit, tmax, NEG)
        local = o + np.where(hit, t, 0)[:, None] * d
        side = r2 <= yhi
        normal = np.where(side[:, None], local, np.array([0, np.sign(d[1]), 0])[None, :])
    wn = normal @ Ainv  # inverse transpose applied to row vectors
    ln = np.linalg.norm(wn, axis=1, keepdims=True)
    wn = wn / np.maximum(ln, 1e-12)
    return t, wn, local, normal


# ------------------------------------------------------------------ render

class Canvas:
    """Result of tracing: colours plus per-pixel bookkeeping for later passes."""

    def __init__(self, w, h, ox, oy):
        self.w, self.h, self.ox, self.oy = w, h, ox, oy
        self.rgba = np.zeros((h, w, 4), dtype=np.uint8)
        self.t = np.full((h, w), NEG)
        self.pid = np.full((h, w), -1, dtype=int)

    def world_at_pixels(self):
        j, i = np.mgrid[0:self.h, 0:self.w]
        sx = i - self.ox + 0.5
        sy = j - self.oy + 0.5
        return sx, sy

    def put(self, sx, sy, color, t=None, bias=0.12):
        """Paint one pixel at screen coords (relative to anchor) if not hidden."""
        i = int(math.floor(sx + self.ox))
        j = int(math.floor(sy + self.oy))
        if 0 <= i < self.w and 0 <= j < self.h:
            if t is None or t >= self.t[j, i] - bias:
                if len(color) == 3:
                    color = tuple(color) + (255,)
                self.rgba[j, i] = color
                if t is not None:
                    self.t[j, i] = max(self.t[j, i], t)
                return True
        return False


def render(prims, margin=3, bounds=None, shadow=None, shadow_alpha=70, edge_light=True, lines=True, gap=0.05, outline_alpha=255):
    """Trace a list of Prims. Returns a Canvas (anchor = world origin)."""
    pts = []
    for p in prims:
        pts += p.corners()
    if bounds is not None:
        pts += [np.array(b, dtype=float) for b in bounds]
    sx = [screen(q)[0] for q in pts]
    sy = [screen(q)[1] for q in pts]
    x0 = math.floor(min(sx)) - margin
    x1 = math.ceil(max(sx)) + margin
    y0 = math.floor(min(sy)) - margin
    y1 = math.ceil(max(sy)) + margin
    cv = Canvas(x1 - x0, y1 - y0, -x0, -y0)
    SX, SY = cv.world_at_pixels()
    SX = SX.ravel()
    SY = SY.ravel()
    O = np.zeros((SX.size, 3))
    O[:, 0] = (SX / HALF_W + SY / HALF_H) / 2
    O[:, 2] = (SY / HALF_H - SX / HALF_W) / 2
    best_t = np.full(SX.size, NEG)
    best_id = np.full(SX.size, -1, dtype=int)
    best_n = np.zeros((SX.size, 3))
    best_local = np.zeros((SX.size, 3))
    best_lnorm = np.zeros((SX.size, 3))
    for k, p in enumerate(prims):
        t, wn, local, lnorm = _intersect(p, O)
        upd = t > best_t + 1e-9
        best_t[upd] = t[upd]
        best_id[upd] = k
        best_n[upd] = wn[upd]
        best_local[upd] = local[upd]
        best_lnorm[upd] = lnorm[upd]
    H, W = cv.h, cv.w
    tone = np.zeros(SX.size, dtype=int)
    inten = best_n @ L
    tone[:] = 1
    tone[inten >= 0.22] = 2
    tone[inten >= 0.47] = 3
    tone[inten >= 0.70] = 4
    world = O + best_t[:, None] * V
    override = np.zeros((SX.size, 4), dtype=np.uint8)
    for k, p in enumerate(prims):
        sel = best_id == k
        if not sel.any():
            continue
        if p.mat.flat is not None:
            tone[sel] = p.mat.flat
        if not p.lit:
            tone[sel] = 3
        tone[sel] += p.mat.bias
        if p.pattern is not None:
            half = np.linalg.norm(p.A, axis=0)
            res = p.pattern(best_local[sel] * half, best_lnorm[sel], world[sel], best_n[sel])
            if isinstance(res, tuple):
                delta, paint = res
            else:
                delta, paint = res, None
            if delta is not None:
                tone[sel] += np.asarray(delta, dtype=int)
            if paint is not None:
                override[sel] = paint
    tone = np.clip(tone, 0, 5)
    tone2 = tone.reshape(H, W)
    ids = best_id.reshape(H, W)
    tt = best_t.reshape(H, W)
    nn = best_n.reshape(H, W, 3)
    # Lit top edges: a top face pixel sitting directly above a side face of the same part.
    if edge_light:
        top = nn[..., 1] > 0.8
        below_side = np.zeros_like(top)
        below_side[:-1] = (ids[1:] == ids[:-1]) & (nn[1:, :, 1] < 0.35) & (ids[:-1] >= 0)
        tone2[top & below_side] = np.minimum(tone2[top & below_side] + 1, 5)
    # Dark separation lines hugging nearer parts.
    if lines:
        groups = np.array([id(p.group) if p.group is not None else -(k + 1) for k, p in enumerate(prims)] + [0])
        linemask = np.zeros((H, W), dtype=bool)
        for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0)):
            nid = np.full((H, W), -1)
            nt = np.full((H, W), NEG)
            ys = slice(max(dy, 0), H + min(dy, 0))
            yd = slice(max(-dy, 0), H + min(-dy, 0))
            xs = slice(max(dx, 0), W + min(dx, 0))
            xd = slice(max(-dx, 0), W + min(-dx, 0))
            nid[yd, xd] = ids[ys, xs]
            nt[yd, xd] = tt[ys, xs]
            valid = (ids >= 0) & (nid >= 0)
            diff_group = groups[np.where(ids >= 0, ids, -1)] != groups[np.where(nid >= 0, nid, -1)]
            linemask |= valid & diff_group & (nt > tt + gap)
        for k, p in enumerate(prims):
            if not p.mat.line:
                linemask[ids == k] = False
        tone2[linemask] = 0
    rgba = cv.rgba
    for k, p in enumerate(prims):
        sel = ids == k
        if not sel.any():
            continue
        tones = np.array(p.mat.tones, dtype=np.uint8)
        if p.mat.emissive:
            col = np.where((tone2[sel] == 0)[:, None], tones[0], tones[min(3 + p.mat.bias, 5)])
            rgba[sel, :3] = col
        else:
            rgba[sel, :3] = tones[tone2[sel]]
        rgba[sel, 3] = 255
    ov = override.reshape(H, W, 4)
    use = ov[..., 3] > 0
    rgba[use] = ov[use]
    cv.t = tt
    cv.pid = ids
    cv.tone = tone2
    cv.prims = prims
    # Floor contact shadow (drawn only where nothing else is).
    if shadow is not None:
        _floor_shadow(cv, shadow, shadow_alpha)
    return cv


def _floor_shadow(cv: Canvas, rects, alpha):
    """rects: list of (x0, z0, x1, z1) world floor rectangles (already rotated)."""
    SX, SY = cv.world_at_pixels()
    X = (SX / HALF_W + SY / HALF_H) / 2
    Z = (SY / HALF_H - SX / HALF_W) / 2
    mask = np.zeros(X.shape, dtype=bool)
    for (x0, z0, x1, z1) in rects:
        mask |= (X >= x0) & (X <= x1) & (Z >= z0) & (Z <= z1)
    empty = cv.rgba[..., 3] == 0
    m = mask & empty
    cv.rgba[m] = (20, 10, 26, alpha)


def finish(cv: Canvas, outline_color=None):
    """Exterior outline: transparent pixels next to the object take the
    darkest tone of the nearest touching part."""
    rgba = cv.rgba
    H, W = cv.h, cv.w
    solid = (rgba[..., 3] == 255) & (cv.pid >= 0)
    best_t = np.full((H, W), NEG)
    best_col = np.zeros((H, W, 3), dtype=np.uint8)
    cand = np.zeros((H, W), dtype=bool)
    for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0)):
        ys = slice(max(dy, 0), H + min(dy, 0))
        yd = slice(max(-dy, 0), H + min(-dy, 0))
        xs = slice(max(dx, 0), W + min(dx, 0))
        xd = slice(max(-dx, 0), W + min(-dx, 0))
        ns = np.zeros((H, W), dtype=bool)
        nt = np.full((H, W), NEG)
        nid = np.full((H, W), -1)
        ns[yd, xd] = solid[ys, xs]
        nt[yd, xd] = cv.t[ys, xs]
        nid[yd, xd] = cv.pid[ys, xs]
        upd = ns & (rgba[..., 3] < 255) & (nt > best_t)
        best_t[upd] = nt[upd]
        for k in np.unique(nid[upd]):
            if k < 0:
                continue
            sel = upd & (nid == k)
            col = outline_color if outline_color is not None else mix(cv.prims[k].mat.tones[0], INK, 0.45)
            best_col[sel] = col
        cand |= upd
    rgba[cand, :3] = best_col[cand]
    rgba[cand, 3] = 255
    return cv


def project_px(cv: Canvas, p):
    sx, sy = screen(p)
    return sx + cv.ox, sy + cv.oy


def ray_t(cv: Canvas, p):
    """Depth of a world point along the pixel ray (comparable to cv.t)."""
    return p[1] / V[1]


def dot(cv: Canvas, p, color, bias=0.08, size=1):
    """Paint a world-space point (decal) respecting occlusion."""
    sx, sy = screen(p)
    t = ray_t(cv, p)
    for dx in range(size):
        cv.put(sx + dx, sy, color, t, bias)


def stroke(cv: Canvas, a, b, color, bias=0.08, steps=None):
    a = np.array(a, dtype=float)
    b = np.array(b, dtype=float)
    sa, sb = screen(a), screen(b)
    n = steps or int(max(abs(sa[0] - sb[0]), abs(sa[1] - sb[1])) * 2) + 1
    for k in range(n + 1):
        p = a + (b - a) * (k / n)
        dot(cv, p, color, bias)
