"""The street and the car parks: kerbs, worn road and bay markings, wheel
stops, weeds, drains, oil stains, cracks and the parking sign.

Flat things (paint, stains, drains, cracks) are rasterised straight from
their floor shape, pixel by pixel; kerbs, wheel stops and the sign are
traced in 3D like the furniture. Sizes are real: a kerb stone is 1 m long,
18 cm wide and 12 cm high, a wheel stop 1.6 m, a road line 12 cm wide.
"""
from __future__ import annotations

import math

import numpy as np
from PIL import Image, ImageDraw

from pa_core import HALF_W, HALF_H, save, preview, hash01
from pa_iso import Mat, box, cyl, render, finish, screen

GRANITE = Mat("7f7c8a")
KERB_WORN = Mat("6e6b78")
CONCRETE = Mat("8e8a92")
WHITE = (206, 204, 196, 255)
GREY_PAINT = (160, 158, 154, 255)
GREENS = [(52, 104, 46), (70, 132, 54), (96, 158, 62), (128, 176, 70)]
DRY = [(150, 142, 74), (176, 160, 86)]

# The older road props keep their palette. Parking masonry has a quieter
# hand-picked ramp: lavender shade, warm stone tops and a restrained bevel.
PARK_STONE = Mat(tones=["36333f", "514b59", "69616e", "807981", "9c9693", "b3a99b"])
PARK_CONCRETE = Mat(tones=["35313d", "504957", "696270", "817b82", "a09991", "b8ad9b"])


def vnoise1(v, seed, freq=1.0):
    """1D value noise in [0, 1]."""
    x = v * freq
    i = np.floor(x).astype(int)
    f = x - i
    f = f * f * (3 - 2 * f)
    h = lambda k: ((k * 374761393 + seed * 668265263) & 0xFFFFFF) / float(0xFFFFFF)
    a = np.vectorize(h)(i)
    b = np.vectorize(h)(i + 1)
    return a + (b - a) * f


def flat(x0, z0, x1, z1, paint, margin=2):
    """RGBA picture of a floor rectangle (world metres, anchor = world origin),
    each pixel painted from its floor position."""
    pts = [(x0, z0), (x1, z0), (x1, z1), (x0, z1)]
    sx = [HALF_W * (x - z) for x, z in pts]
    sy = [HALF_H * (x + z) for x, z in pts]
    left = math.floor(min(sx)) - margin
    top = math.floor(min(sy)) - margin
    w = math.ceil(max(sx)) - left + margin
    h = math.ceil(max(sy)) - top + margin
    j, i = np.mgrid[0:h, 0:w]
    px = i + left + 0.5
    py = j + top + 0.5
    X = (px / HALF_W + py / HALF_H) / 2
    Z = (py / HALF_H - px / HALF_W) / 2
    rgba = paint(X, Z)
    return rgba, -left, -top


# ------------------------------------------------------------------ paint

def line(length, axis, seed, width=0.12):
    """A worn white line from the origin along x or z."""
    def paint(X, Z):
        along, across = (X, Z) if axis == "x" else (Z, X)
        inside = (along >= 0) & (along <= length) & (np.abs(across) <= width / 2)
        wear = vnoise1(along, seed, 2.3) * 0.7 + vnoise1(along * 3.1 + across * 9, seed + 7, 4.0) * 0.3
        img = np.zeros(X.shape + (4,), dtype=np.uint8)
        keep = inside & (wear > 0.3)
        img[keep] = WHITE
        img[keep & (wear < 0.45)] = GREY_PAINT
        speck = np.vectorize(lambda a, b: hash01(a, b, seed))(np.floor(X * 32).astype(int), np.floor(Z * 32).astype(int))
        img[keep & (speck > 0.9)] = (0, 0, 0, 0)
        return img
    if axis == "x":
        return flat(0, -width, length, width, paint)
    return flat(-width, 0, width, length, paint)


def parking_line(length, axis, seed, width=0.16):
    """Warm old bay paint, chipped in small groups along its edges.

    Keep a readable core at native resolution; isolated white speckles and
    regular dashed gaps make a narrow stripe look like road studs.
    """
    def paint(X, Z):
        along, across = (X, Z) if axis == "x" else (Z, X)
        inside = (along >= 0) & (along <= length) & (np.abs(across) <= width / 2)
        cells = np.floor(along * 3.0).astype(int)
        wear = np.vectorize(lambda k: hash01(int(k), 0, seed))(cells)
        # Short nicks enter one edge only, leaving most of the line intact.
        nick_side = np.where(wear > 0.5, 1.0, -1.0)
        nick = (wear > 0.82) & (across * nick_side > width * 0.04)
        phase = np.mod(along * 3.0, 1.0)
        nick &= (phase > 0.28) & (phase < 0.78)
        img = np.zeros(X.shape + (4,), dtype=np.uint8)
        keep = inside & ~nick
        img[keep] = (191, 181, 162, 255)
        faded = (wear < 0.25) | (np.abs(across) > width * 0.36)
        img[keep & faded] = (160, 151, 139, 255)
        img[keep & (wear > 0.57) & ~faded] = (202, 191, 172, 255)
        # One irregular missing flake across the stripe, never periodic dashes.
        missing_at = 0.8 + hash01(seed, 9, 47) * (length - 1.7)
        missing = np.abs(along - missing_at + across * 0.65) < 0.07 + (seed % 3) * 0.025
        img[missing & inside] = (0, 0, 0, 0)
        return img
    if axis == "x":
        return flat(0, -width, length, width, paint)
    return flat(-width, 0, width, length, paint)


def stain(seed, size=1.0):
    """A dark oil stain under where engines sit."""
    def paint(X, Z):
        r = np.hypot(X / (size * 0.55), Z / (size * 0.38))
        wob = vnoise1(np.arctan2(Z, X) * 2.0 + 10, seed, 1.0) * 0.35
        n = np.vectorize(lambda a, b: hash01(a, b, seed + 3))(np.floor(X * 16).astype(int), np.floor(Z * 16).astype(int))
        img = np.zeros(X.shape + (4,), dtype=np.uint8)
        body = r < 0.75 + wob
        img[body] = (18, 16, 24, 70)
        img[body & (r < 0.45 + wob * 0.6)] = (14, 12, 20, 110)
        img[body & (n > 0.93)] = (0, 0, 0, 0)
        return img
    return flat(-size, -size, size, size, paint)


def crack(seed, length=1.6):
    """A dark branching crack across the asphalt."""
    rng = np.random.default_rng(seed)
    pts = [(0.0, 0.0)]
    ang = rng.uniform(0, math.pi)
    for _ in range(int(length / 0.12)):
        ang += rng.normal(0, 0.45)
        x, z = pts[-1]
        pts.append((x + 0.12 * math.cos(ang), z + 0.12 * math.sin(ang)))
    branch = pts[len(pts) // 2]
    b_ang = ang + 1.2
    for _ in range(5):
        x, z = branch
        branch = (x + 0.12 * math.cos(b_ang), z + 0.12 * math.sin(b_ang))
        pts.append(branch)
    P = np.array(pts)

    def paint(X, Z):
        img = np.zeros(X.shape + (4,), dtype=np.uint8)
        d = np.full(X.shape, 9.0)
        for (x, z) in P:
            d = np.minimum(d, np.hypot(X - x, Z - z))
        img[d < 0.045] = (16, 14, 20, 200)
        img[(d >= 0.045) & (d < 0.075)] = (40, 38, 46, 90)
        return img
    x0, z0 = P.min(axis=0) - 0.2
    x1, z1 = P.max(axis=0) + 0.2
    return flat(x0, z0, x1, z1, paint)


def drain():
    """A kerbside grate, 60 x 35 cm."""
    def paint(X, Z):
        img = np.zeros(X.shape + (4,), dtype=np.uint8)
        inside = (np.abs(X) <= 0.3) & (Z >= -0.35) & (Z <= 0.0)
        frame = inside & ((np.abs(X) > 0.25) | (Z < -0.3) | (Z > -0.05))
        slot = inside & ~frame & (np.mod(X + 0.3, 0.1) < 0.045)
        img[inside] = (70, 68, 78, 255)
        img[frame] = (104, 100, 112, 255)
        img[slot] = (18, 16, 22, 255)
        return img
    return flat(-0.35, -0.4, 0.35, 0.05, paint)


def hatch(w, d, seed):
    """Worn diagonal hatching over a turning area kept free (w along x)."""
    def paint(X, Z):
        img = np.zeros(X.shape + (4,), dtype=np.uint8)
        inside = (X >= 0) & (X <= w) & (Z >= 0) & (Z <= d)
        border = inside & ((X < 0.12) | (X > w - 0.12) | (Z < 0.12) | (Z > d - 0.12))
        stripe = inside & (np.mod(X + Z, 1.0) < 0.12)
        wear = vnoise1(X * 1.3 + Z * 0.7, seed, 1.7)
        img[(border | stripe) & (wear > 0.35)] = (196, 176, 90, 200)
        return img
    return flat(0, 0, w, d, paint)


# ------------------------------------------------------------------ 3D bits

def chips(seed, amount=0.25):
    def pat(p, ln, w, n):
        from pa_tiles import vnoise
        d = np.zeros(len(p), dtype=int)
        v = vnoise(p[:, 0] + p[:, 1] * 3, p[:, 2] + p[:, 1], 7.0, seed)
        d[v > 1 - amount] = -1
        d[v < amount * 0.3] = 1
        return d
    return pat


def kerb(axis, low=False, seed=1):
    """A 1 m kerb stone, its outer face on the origin line, running along +axis."""
    h = 0.04 if low else 0.12
    m = KERB_WORN if low else GRANITE
    if axis == "x":
        prims = [box(0.02, 0, -0.09, 0.98, h, 0.09, m, pattern=chips(seed))]
    else:
        prims = [box(-0.09, 0, 0.02, 0.09, h, 0.98, m, pattern=chips(seed))]
    cv = render(prims, bounds=[(-0.2, 0, -0.2), (1.2, 0.3, 1.2)])
    finish(cv)
    return cv


def stripes(axis, seed):
    """Worn yellow paint bands across the top of a wheel stop."""
    base = chips(seed, 0.3)

    def pat(p, ln, w, n):
        from pa_tiles import vnoise
        d = base(p, ln, w, n)
        paint = np.zeros((len(p), 4), dtype=np.uint8)
        along = p[:, 0] if axis == "x" else p[:, 2]
        band = np.mod(along + 0.8, 0.4) < 0.2
        worn = vnoise(p[:, 0] * 3 + 5, p[:, 2] * 3, 4.0, seed + 9) > 0.35
        top = ln[:, 1] > 0.5
        paint[band & worn & (top | (np.abs(ln[:, 1]) < 0.5))] = (206, 170, 60, 255)
        return d, paint
    return pat


def wheel_stop(axis, seed=2):
    """A concrete wheel stop, 1.6 m long, centred on the origin, with worn
    yellow bands."""
    if axis == "x":
        prims = [box(-0.8, 0, -0.11, 0.8, 0.12, 0.11, CONCRETE, pattern=stripes(axis, seed))]
    else:
        prims = [box(-0.11, 0, -0.8, 0.11, 0.12, 0.8, CONCRETE, pattern=stripes(axis, seed))]
    cv = render(prims, shadow=[(-0.85, -0.16, 0.85, 0.16)] if axis == "x" else [(-0.16, -0.85, 0.16, 0.85)], shadow_alpha=50)
    finish(cv)
    return cv


def parking_stone_wear(seed):
    """Sparse shallow weathering, never bright noise on a stone surface."""
    def pat(p, ln, w, n):
        from pa_tiles import vnoise
        d = np.zeros(len(p), dtype=int)
        # A few connected chips, rather than a high-frequency stipple.
        broad = vnoise(w[:, 0] + seed * 0.19, w[:, 2], 3.0, seed + 411)
        fine = vnoise(w[:, 0], w[:, 2] + w[:, 1], 9.0, seed + 79)
        d[(broad > 0.75) & (fine > 0.55)] = -1
        return d
    return pat


def parking_kerb(axis, seed=1, length=1.0):
    """One metre of aged stone, 22 cm wide and 14 cm high.

    The origin and direction match kerb(): the stone runs from 0 to 1
    along its axis, with a small dark joint at either end.
    """
    if axis == "x":
        prims = [box(0.018, 0, -0.11, length - 0.018, 0.14, 0.11,
                     PARK_STONE, pattern=parking_stone_wear(seed))]
    else:
        prims = [box(-0.11, 0, 0.018, 0.11, 0.14, length - 0.018,
                     PARK_STONE, pattern=parking_stone_wear(seed))]
    cv = render(prims)
    finish(cv, outline_color=(53, 48, 61))
    return cv


def parking_wheel_stop(axis, seed=1):
    """Plain concrete stop: 1.6 m long, centred at the origin.

    The inset cap makes a one-pixel bevel and the shaded foot anchors the
    stop to the asphalt. It deliberately has no painted safety stripes.
    """
    group = object()
    if axis == "x":
        prims = [box(-0.8, 0, -0.13, 0.8, 0.105, 0.13,
                     PARK_CONCRETE, group=group, pattern=parking_stone_wear(seed)),
                 box(-0.77, 0.105, -0.10, 0.77, 0.16, 0.10,
                     PARK_CONCRETE, group=group, pattern=parking_stone_wear(seed))]
        shadow = [(-0.85, -0.13, 0.86, 0.23)]
    else:
        prims = [box(-0.13, 0, -0.8, 0.13, 0.105, 0.8,
                     PARK_CONCRETE, group=group, pattern=parking_stone_wear(seed)),
                 box(-0.10, 0.105, -0.77, 0.10, 0.16, 0.77,
                     PARK_CONCRETE, group=group, pattern=parking_stone_wear(seed))]
        shadow = [(-0.13, -0.85, 0.23, 0.86)]
    cv = render(prims, shadow=shadow, shadow_alpha=65)
    finish(cv, outline_color=(47, 43, 56))
    return cv


def parking_sign():
    """A blue P sign on a grey pole, facing the street."""
    blue = Mat("2c5cb0")

    def glyph(p, ln, w, n):
        # a white P on the face towards the street
        d = np.zeros(len(p), dtype=int)
        paint = np.zeros((len(p), 4), dtype=np.uint8)
        face = ln[:, 2] > 0.5
        u = (p[:, 0] + 0.22) / 0.44      # 0..1 across
        v = (p[:, 1] + 0.22) / 0.44      # 0..1 up
        col = np.floor(u * 5).astype(int)
        row = np.floor((1 - v) * 7).astype(int)
        P = ["11110", "10001", "10001", "11110", "10000", "10000", "10000"]
        mask = np.zeros(len(p), dtype=bool)
        for k in range(len(p)):
            if 0 <= col[k] < 5 and 0 <= row[k] < 7 and P[row[k]][col[k]] == "1":
                mask[k] = True
        edge = (u < 0.08) | (u > 0.92) | (v < 0.08) | (v > 0.92)
        paint[face & (mask | edge)] = (236, 238, 244, 255)
        return d, paint
    prims = [cyl(0, 0, 0, 0.04, 2.3, Mat("7a7884")),
             box(-0.26, 1.9, -0.03, 0.26, 2.42, 0.03, blue, pattern=glyph)]
    cv = render(prims, shadow=[(-0.12, -0.12, 0.12, 0.12)])
    finish(cv)
    return cv


# ------------------------------------------------------------------ weeds

def weed(seed):
    """A tuft of grass and weeds growing out of a crack or a kerb joint."""
    rng = np.random.default_rng(seed)
    w, h = 14, 12
    img = np.zeros((h, w, 4), dtype=np.uint8)
    ox, oy = 7, 11
    blades = rng.integers(3, 8)
    dry = rng.random() < 0.3
    for b in range(blades):
        x = ox + rng.integers(-3, 4)
        height = rng.integers(3, 9)
        lean = rng.uniform(-0.45, 0.45)
        col = DRY[rng.integers(0, 2)] if dry and rng.random() < 0.6 else GREENS[rng.integers(0, 4)]
        for k in range(height):
            px = int(round(x + lean * k))
            py = oy - k
            if 0 <= px < w and 0 <= py < h:
                shade = tuple(max(0, c - 18) for c in col) if k < 2 else col
                img[py, px] = shade + (255,)
    if rng.random() < 0.35:
        fx = ox + rng.integers(-2, 3)
        fy = oy - rng.integers(5, 9)
        flower = (236, 210, 80) if rng.random() < 0.5 else (236, 234, 226)
        if 0 <= fy < h:
            img[fy, fx] = flower + (255,)
    return img, ox, oy


def parking_weed(seed):
    """A small rooted tuft with bent blades, paired leaves and muted tips."""
    rng = np.random.default_rng(seed)
    img = Image.new("RGBA", (18, 15))
    draw = ImageDraw.Draw(img)
    ox, oy = 9, 13
    dark = (44, 56, 38, 255)
    shade = (56, 77, 40, 255)
    greens = [(77, 101, 44, 255), (96, 120, 48, 255), (118, 133, 57, 255)]
    # A low irregular base joins all the blades at the joint/crack.
    draw.line([(ox - 4, oy), (ox, oy - 1), (ox + 4, oy)], fill=dark)
    count = int(rng.integers(5, 9))
    for b in range(count):
        root = ox + int(rng.integers(-3, 4))
        height = int(rng.integers(4, 12))
        lean = int(rng.integers(-4, 5))
        bend = (root + int(lean * 0.4), oy - max(2, height // 2))
        tip = (max(1, min(16, root + lean)), oy - height)
        draw.line([(root, oy), bend, tip], fill=shade)
        colour = greens[(b + seed) % len(greens)]
        draw.line([bend, tip], fill=colour)
        if b % 2 == 0:
            side = -1 if lean < 0 else 1
            leaf = (bend[0] + side * 2, bend[1] - 1)
            draw.line([bend, leaf], fill=colour)
        # Only a few dull straw tips amongst the living grass.
        if b == 0 and seed % 3 == 0:
            draw.point(tip, fill=(149, 140, 72, 255))
    draw.point((ox, oy), fill=(71, 66, 42, 255))
    return np.asarray(img).copy(), ox, oy


def with_weeds(cv_rgba, ox, oy, seed, spots):
    """Plant tufts on a picture at world floor points (x, z)."""
    img = cv_rgba.copy()
    for k, (x, z) in enumerate(spots):
        tuft, tx, ty = weed(seed * 13 + k)
        sx, sy = screen((x, 0, z))
        X = int(round(sx)) + ox - tx
        Y = int(round(sy)) + oy - ty
        for yy in range(tuft.shape[0]):
            for xx in range(tuft.shape[1]):
                if tuft[yy, xx, 3] and 0 <= Y + yy < img.shape[0] and 0 <= X + xx < img.shape[1]:
                    img[Y + yy, X + xx] = tuft[yy, xx]
    return img


def grow(img, ox, oy, top, left, bottom, right):
    """Pad a picture (room for tufts sticking out)."""
    out = np.zeros((img.shape[0] + top + bottom, img.shape[1] + left + right, 4), dtype=np.uint8)
    out[top:top + img.shape[0], left:left + img.shape[1]] = img
    return out, ox + left, oy + top


# ------------------------------------------------------------------ export

def export():
    man = {}

    def put(name, img, ox, oy):
        path = f"street/{name}.png"
        save(img, path)
        man[name] = {"file": path, "ox": int(ox), "oy": int(oy)}

    for axis in ("x", "z"):
        for v in range(4):
            cv = kerb(axis, seed=v + 1)
            img, ox, oy = grow(cv.rgba, cv.ox, cv.oy, 10, 6, 2, 6)
            if v >= 2:
                spots = [(0.5, 0.12)] if axis == "x" else [(0.12, 0.5)]
                if v == 3:
                    spots += [(0.9, 0.14)] if axis == "x" else [(0.14, 0.9)]
                img = with_weeds(img, ox, oy, v * 7 + (1 if axis == "x" else 2), spots)
            put(f"kerb_{axis}_{v}", img, ox, oy)
        cv = kerb(axis, low=True, seed=9)
        put(f"kerb_low_{axis}", cv.rgba, cv.ox, cv.oy)
        cv = wheel_stop(axis)
        put(f"stop_{axis}", cv.rgba, cv.ox, cv.oy)
        for v in range(3):
            img, ox, oy = line(5.0, axis, 11 + v * 5 + (0 if axis == "x" else 50))
            put(f"line_{axis}_{v}", img, ox, oy)
        for v in range(4):
            cv = parking_kerb(axis, seed=420 + v)
            put(f"park_kerb_{axis}_{v}", cv.rgba, cv.ox, cv.oy)
            cv = parking_kerb(axis, seed=420 + v, length=0.5)
            put(f"park_kerb_half_{axis}_{v}", cv.rgba, cv.ox, cv.oy)
            img, ox, oy = parking_line(5.0, axis, 450 + v * 7 + (0 if axis == "x" else 50))
            put(f"park_line_{axis}_{v}", img, ox, oy)
        for v in range(3):
            cv = parking_wheel_stop(axis, seed=510 + v)
            put(f"park_stop_{axis}_{v}", cv.rgba, cv.ox, cv.oy)
    for v in range(3):
        img, ox, oy = line(3.0, "x", 71 + v, 0.14)
        put(f"dash_x_{v}", img, ox, oy)
        img, ox, oy = line(1.0, "x", 81 + v, 0.12)
        put(f"edge_x_{v}", img, ox, oy)
    for v in range(6):
        img, ox, oy = weed(100 + v)
        put(f"weed_{v}", img, ox, oy)
    for v in range(8):
        img, ox, oy = parking_weed(610 + v)
        put(f"park_weed_{v}", img, ox, oy)
    for v in range(3):
        img, ox, oy = stain(200 + v, 0.9 + 0.2 * v)
        put(f"stain_{v}", img, ox, oy)
    for v in range(4):
        img, ox, oy = crack(300 + v, 1.2 + 0.4 * v)
        put(f"crack_{v}", img, ox, oy)
    img, ox, oy = drain()
    put("drain", img, ox, oy)
    cv = parking_sign()
    put("sign_parking", cv.rgba, cv.ox, cv.oy)
    return man


def hatch_picture(w, d, seed=5):
    return hatch(w, d, seed)


if __name__ == "__main__":
    man = export()
    print(len(man), "street sprites")
