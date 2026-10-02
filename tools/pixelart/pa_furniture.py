"""Furniture and fittings, painted at native resolution for the four
orientations. Local space: footprint centred on the origin, front towards +z,
back against -z, y up (metres). Rotation r matches the game (rot 3 faces +x).
"""
from __future__ import annotations

import math

import numpy as np

from pa_core import ramp, hexrgb, mix, INK, save, write_json, preview
from pa_iso import (Mat, box, boxc, cyl, ell, triangle, lathe, rod, rot_x, rot_y, rot_z, turn, render, finish, screen, dot, stroke,
                    ray_t, V)
from pa_draw2d import palm, heart_points, Pix, monstera, strelitzia_flowers, fairy_lights

# ------------------------------------------------------------------ materials
# Dance floor colour schemes (name, four tile colours); the game offers them in its panel.
DANCE_SCHEMES = [
    ("Arc-en-ciel", ["ff4fa0", "8a4ae0", "3ad0e0", "f0d050"]),
    ("Rose & violet", ["ff4fa0", "c04ae0", "ff8ad0", "7a3ad0"]),
    ("Bleu glacier", ["3ad0e0", "3a78f0", "a0f0ff", "5a4ae0"]),
    ("Or & rouge", ["f0d050", "ff5a3a", "ffa040", "d02a4a"]),
    ("Vert acide", ["7af05a", "3ad0a0", "d0f05a", "2a9a6a"]),
]
M = {
    "wood": Mat("4b2a3e"), "wood_top": Mat("5e3552"), "wood_warm": Mat("8c5a3c"), "wood_red": Mat("6a2234"),
    "red": Mat("c42a40"), "magenta": Mat("cf3677"), "pink": Mat("e8508c"), "rose": Mat("f08cb0"),
    "white": Mat("efebe4"), "ceramic": Mat("e9e8e6"), "chrome": Mat("a9aebb"), "gold": Mat("e0ae48"),
    "black": Mat("2b2531"), "dark": Mat("221d2a"), "cream": Mat("f3e3c4"), "purple": Mat("6b2b72"),
    "stage": Mat("e0407f"), "velvet": Mat("a41d3a"), "headboard": Mat("c11f44"), "cardboard": Mat("c9914e"),
    "steel": Mat("8e8e9c"), "teal": Mat("4c7f7c"), "fridge": Mat("d6d6e0"), "terracotta": Mat("b9653f"),
    "soil": Mat("3c2a24"), "trunk": Mat("7b5a3a"), "navy": Mat("2c3350"), "grey": Mat("5a6070"),
    "shade": Mat("ffd889", emissive=True, line=False), "flame": Mat("ffe27a", emissive=True, line=False),
    "screen": Mat("5fb0ee", emissive=True), "screen_g": Mat("7fe0b0", emissive=True),
    "glass": Mat("8ec3e0"), "water": Mat("6f93a8"), "led": Mat("ff6fb0", emissive=True, line=False),
    "neon_pink": Mat("ff4fa0", emissive=True, line=False), "neon_red": Mat("ff4d57", emissive=True, line=False),
    "neon_purple": Mat("b476ff", emissive=True, line=False), "rug": Mat("a51e36"), "canvas": Mat("7a3a6a"),
    "plum": Mat("3c2336"), "bottle_g": Mat("4f9a5a"), "bottle_a": Mat("d88a3a"), "bottle_r": Mat("c23a4a"),
    "bottle_c": Mat("dfe8ee"), "bottle_b": Mat("4a78c0"), "bottle_p": Mat("c870d8"), "paper": Mat("f1ece0"),
}


# ------------------------------------------------------------------ patterns

def _top(ln):
    return ln[:, 1] > 0.5


def _front(ln):
    return ln[:, 2] > 0.5


def _side(ln):
    return np.abs(ln[:, 0]) > 0.5


def near(v, targets, w=1 / 32):
    m = np.zeros(v.shape, dtype=bool)
    for t in targets:
        m |= np.abs(v - t) < w
    return m


def panels(xs, y0, y1, face="front", inset=0.06):
    """Recessed door/drawer panels on a box face: dark lines at the panel
    borders, a lit line on the upper-left edges."""
    def pat(p, ln, w, n):
        d = np.zeros(len(p), dtype=int)
        f = _front(ln) if face == "front" else _side(ln)
        x = p[:, 0] if face == "front" else p[:, 2]
        y = p[:, 1]
        edges = sorted(xs)
        for a, b in zip(edges[:-1], edges[1:]):
            ax, bx = a + inset, b - inset
            inside = (x > ax) & (x < bx) & (y > y0 + inset * 0.7) & (y < y1 - inset * 0.7)
            border_dark = inside & ((np.abs(x - bx) < 1 / 30) | (np.abs(y - (y0 + inset * 0.7)) < 1 / 46))
            border_lit = inside & ((np.abs(x - ax) < 1 / 30) | (np.abs(y - (y1 - inset * 0.7)) < 1 / 46))
            d[f & border_dark] = -1
            d[f & border_lit] = 1
        return d
    return pat


def seams_top(xs, w=1 / 30):
    def pat(p, ln, wp, n):
        d = np.zeros(len(p), dtype=int)
        d[_top(ln) & near(p[:, 0], xs, w)] = -2
        d[(_front(ln)) & near(p[:, 0], xs, w)] = -1
        return d
    return pat


def tufts(xs, ys, face="front"):
    def pat(p, ln, w, n):
        d = np.zeros(len(p), dtype=int)
        f = _front(ln)
        for x in xs:
            for y in ys:
                d[f & (np.abs(p[:, 0] - x) < 1 / 28) & (np.abs(p[:, 1] - y) < 1 / 44)] = -1
        return d
    return pat


def stripes_y(ys, delta=-1, w=1 / 46):
    def pat(p, ln, wp, n):
        d = np.zeros(len(p), dtype=int)
        side = ~_top(ln)
        d[side & near(p[:, 1], ys, w)] = delta
        return d
    return pat


def combine(*pats):
    def pat(p, ln, w, n):
        d = np.zeros(len(p), dtype=int)
        for q in pats:
            r = q(p, ln, w, n)
            if isinstance(r, tuple):
                r = r[0]
            d += r
        return d
    return pat


def grain(seed=1, amount=0.18):
    def pat(p, ln, w, n):
        h = np.sin(p[:, 0] * 91.7 + p[:, 2] * 47.3 + seed) * np.sin(p[:, 1] * 67.1 + p[:, 0] * 13.1 + seed * 3)
        d = np.zeros(len(p), dtype=int)
        d[h > 1 - amount] = -1
        return d
    return pat


def tape():
    def pat(p, ln, w, n):
        d = np.zeros(len(p), dtype=int)
        d[_top(ln) & (np.abs(p[:, 0]) < 1 / 18)] = 1
        d[_front(ln) & (np.abs(p[:, 0]) < 1 / 18) & (p[:, 1] > 0.0)] = 1
        return d
    return pat


# ------------------------------------------------------------------ items

class Item:
    def __init__(self, prims, size, bills=(), decals=None, lights=(), shadow=True, flat=False, extent=(), split="pixels"):
        self.prims = prims
        # Sort parts (see split_parts): "pixels" cuts the finished picture by
        # part, "separate" renders each part on its own (moving parts).
        self.split = split
        self.size = size
        self.bills = list(bills)          # (local point, Pix)
        self.decals = decals              # callable(cv, T)
        self.lights = list(lights)        # dict(p=(x,y,z), color, radius)
        self.shadow = shadow
        self.flat = flat
        self.extent = list(extent)


def tag(name, *prims):
    """Marks prims as a sort part: a tall piece (backrest, armrest, headboard,
    pole, glass) that someone sitting or standing on the item can be in front
    of or behind, depending on where the item faces."""
    for p in prims:
        p.part = name
    return list(prims)


def legs4(w, d, h, r, mat, inset=0.06):
    out = []
    for x in (-w / 2 + inset, w / 2 - inset):
        for z in (-d / 2 + inset, d / 2 - inset):
            out.append(cyl(x, 0, z, r, h, mat))
    return out


def rounded_slab(cx, cy, cz, w, h, d, mat, radius=0.14, pattern=None):
    """A solid with rounded footprint corners, painted on the native grid."""
    r = min(radius, w / 2 - .01, d / 2 - .01)
    group = object()
    out = [boxc(cx, cy-h/2, cz, w-2*r, h, d, mat, group=group, pattern=pattern),
           boxc(cx, cy-h/2, cz, w, h, d-2*r, mat, group=group, pattern=pattern)]
    for x in (-w/2+r, w/2-r):
        for z in (-d/2+r, d/2-r):
            out.append(cyl(cx+x, cy-h/2, cz+z, r, h, mat, group=group, pattern=pattern))
    return out


def rounded_panel(cx, cy, cz, w, h, depth, radius, mat):
    # Turn a rounded horizontal slab into an upholstered vertical panel.
    return [p.transformed(rot_x(90)) for p in rounded_slab(cx, cz, -cy, w, depth, h, mat, radius)]


def heart_upholstery(cx, cy):
    def pattern(p,ln,w,n):
        x,y = p[:,0]+cx,p[:,1]+cy
        front = ln[:,2] > .5
        tone = np.zeros(len(p),dtype=int)
        for bx,by in [(-.53,1.23),(.53,1.23),(0,.91)]:
            dx,dy = x-bx,y-by
            nearby = dx*dx+(dy*.8)**2 < .085
            # Large, quiet folds around the upholstery buttons, no noise.
            crease = (np.abs(dx-1.1*dy)<.026) | (np.abs(dx+1.1*dy)<.026)
            tone[front & nearby & crease] = -1
            arc = (dx/.45)**2+((dy-.13)/.32)**2
            tone[front & (arc>.72) & (arc<1.05) & (dy>.12)] = 1
        return tone
    return pattern


def bed_head(used=False, heart=False):
    if used:
        wood = Mat("5c3b2a")
        panel = rounded_panel(0, .38, -1.17, 1.86, .66, .12, .12, wood)
        for p in panel: p.pattern = stains(22, .35)
        return tag("head", *panel)
    trim = Mat("682536")
    velvet = Mat("ad2b42")
    if not heart:
        outer = rounded_panel(0, .70, -1.27, 2.18, 1.28, .18, .22, trim)
        inset = rounded_panel(0, .83, -1.155, 1.97, .87, .065, .20, velvet)
        for p in inset: p.pattern = tufts([-.62, 0, .62], [.0])
        return tag("head", *(outer+inset))
    # Extrude a heart profile as native-height strips sharing one outline group.
    trim = Mat(tones=["301a27","461b2c","582231","6c2334","8b2e43","a73b4c"])
    gold = Mat(tones=["5b3334","815335","b98340","dfa54f","f3ce7d","ffe6a4"])
    velvet = Mat(tones=["5d192b","811b32","9f2437","bd2d42","d34253","e76565"])
    profile = np.array(heart_points(0, 0, 1))
    profile[:, 0] /= 16
    profile[:, 1] = (profile[:, 1]-profile[:, 1].min()) / np.ptp(profile[:, 1])
    out = []
    for width, bottom, top, z, depth, mat in [(2.18,.32,1.78,-1.27,.20,trim), (2.04,.40,1.70,-1.152,.06,gold), (1.90,.47,1.64,-1.106,.04,velvet)]:
        points = profile.copy()
        points[:, 0] *= width/2
        points[:, 1] = bottom+points[:, 1]*(top-bottom)
        group = object()
        step = 1/48
        for y in np.arange(bottom, top, step):
            ym = y+step/2
            xs = []
            for a, b in zip(points, np.roll(points,-1,axis=0)):
                if (a[1] <= ym < b[1]) or (b[1] <= ym < a[1]):
                    xs.append(a[0]+(b[0]-a[0])*(ym-a[1])/(b[1]-a[1]))
            xs.sort()
            for left, right in zip(xs[::2],xs[1::2]):
                if right-left > .002:
                    pat = heart_upholstery((left+right)/2,y+step/2) if mat is velvet else None
                    out.append(box(left,y,z-depth/2,right,min(y+step,top),z+depth/2,mat,group=group,lit=False,pattern=pat))
    out += [cyl(x,.06,-1.27,.06,.65,trim) for x in (-.48,.48)]
    return tag("head", *out)


def cloth_grid(rows, mat, group):
    out = []
    for row,next_row in zip(rows,rows[1:]):
        for a,b,c,d in zip(row,row[1:],next_row,next_row[1:]):
            out += [triangle(a,b,c,mat,group=group),triangle(b,d,c,mat,group=group)]
    return out


def heart_duvet():
    # Broad folds and an uneven hanging hem, shaped as actual cloth instead
    # of a rectangular slab. The final sprite still uses one native pixel grid.
    red = Mat(tones=["481726","6a1d30","92243a","b52d42","ce4354","dd6065"],name="heart_cloth")
    group = object()
    xs = np.linspace(-1.045,1.045,17)
    zs = np.linspace(-.29,1.25,15)
    def height(x,z):
        fold = .027*math.sin(x*7.5+z*2)+.016*math.sin(x*12-z*5)
        gather = .055*math.exp(-((z-1.16)/.25)**2)*math.sin(x*8+1)
        return max(.565,.63+fold+gather)
    rows = [[(x,height(x,z),z) for x in xs] for z in zs]
    out = cloth_grid(rows,red,group)
    # The foot drapes in loose scallops; thicker folds gather at the corners.
    front = [rows[-1]]
    for t in [.35,.7,1.0]:
        front.append([(x,height(x,1.25)*(1-t)+(.22+.075*math.cos(x*8+1))*t,1.25+.075*math.sin(t*math.pi/2)+.025*math.sin(x*8)*t) for x in xs])
    out += cloth_grid(front,red,group)
    for sign in [-1,1]:
        side = [[(sign*1.045,height(sign*1.045,z),z) for z in zs]]
        for t in [.35,.7,1.0]:
            side.append([(sign*(1.045+.04*math.sin(t*math.pi/2)),height(sign*1.045,z)*(1-t)+(.24+.07*math.cos(z*9))*t,z) for z in zs])
        out += cloth_grid(side,red,group)
    # Rolled-back top edge, with a soft upper highlight.
    out += rounded_slab(0,.63,-.285,2.05,.105,.20,Mat("bc3d51"),.09)
    return out


def heart_bed_details():
    def dec(cv,T):
        for x,y in [(-.53,1.23),(.53,1.23),(0,.91),(-.68,.81),(.68,.81)]:
            dot(cv,T((x,y,-1.08)),(105,55,39,255),bias=.10)
            dot(cv,T((x-.015,y+.045,-1.08)),(246,201,112,255),bias=.10)
    return dec


def luxury_heart_bed(original, made):
    gold = Mat("d6a559",bias=1)
    burgundy = Mat("542133")
    base = rounded_slab(0,.18,.03,2.16,.22,2.56,burgundy,.18)
    base += rounded_slab(0,.285,.03,2.17,.035,2.57,gold,.18)
    base += rounded_slab(0,.095,.03,2.17,.03,2.57,gold,.18)
    base += legs4(2.02,2.42,.12,.065,gold,.10)
    if made:
        ivory = Mat(tones=["665060","977d88","c6aba7","eadbca","f7efde","fff6e6"])
        base += rounded_slab(0,.425,.035,2.03,.235,2.47,ivory,.18)
        for x in [-.49,.49]:
            pillow = rounded_slab(x,.56,-.91,.86,.11,.60,ivory,.14)
            pillow.append(ell(x,.62,-.91,.44,.14,.31,ivory,group=object()))
            base += pillow
            red = Mat("b82940")
            cushion = rounded_slab(x,.675,-.65,.49,.09,.31,red,.10)
            cushion.append(ell(x,.70,-.65,.25,.095,.17,red))
            base += cushion
        base += heart_duvet()
    else:
        # Keep existing state-specific linen and its anchors, with the same
        # upholstered base and headboard as the made model.
        base += [p for p in original.prims if getattr(p,"part",None) != "head" and p.mat is not M["wood"] and p.mat is not M["dark"]]
    original.prims = base+bed_head(heart=True)
    original.decals = heart_bed_details()
    return original


def polish_bed(prims, used=False, heart=False):
    """Soften the furniture geometry without changing its placement/anchors."""
    result = bed_head(used,heart)
    for p in prims:
        if getattr(p,"part",None) == "head": continue
        if not used:
            if p.mat is M["pink"]: p.mat = Mat(tones=["421b29","642038","85273f","aa3045","bf4552","cc6068"],name="bed_duvet")
            elif p.mat is M["rose"]: p.mat = Mat(tones=["65243a","7e2a3e","a43c50","be5360","d4777d","dfa09a"])
        if p.kind != "box":
            result.append(p)
            continue
        w, h, d = np.linalg.norm(p.A,axis=0)*2
        # Leave small details and vertical draped fabric intact.
        if w < .4 or d < .12 or h > .4:
            result.append(p)
            continue
        pillow = w < 1.1 and d < .65 and h >= .09
        mat = p.mat
        if not used and h > .25 and d > .5 and w > 1.5 and mat.name == "bed_duvet":
            # A thinner, draped duvet rather than a thick rectangular block.
            if h > .25:
                old_h = h
                h = .20
                p.T[1] += (old_h-h)/2
        if pillow:
            group = object()
            soft = rounded_slab(0,-h*.20,0,w*.92,h*.3,d*.94,mat,.1,p.pattern)
            soft.append(ell(0,0,0,w/2,h*.55,d/2,mat,group=group,pattern=p.pattern))
            for piece in soft: piece.group = group
        else:
            soft = rounded_slab(0,0,0,w,h,d,mat,.21 if d > .5 else .07,p.pattern)
        R = getattr(p,"R_total",np.eye(3))
        for piece in soft:
            piece = piece.transformed(R)
            piece.T += p.T
            result.append(piece)
    return result


def bed_details(heart=False):
    def dec(cv,T):
        # Upholstery buttons and tiny curved fabric creases. Depth-tested so
        # details never paint over a pillow or a nearer piece of the bed.
        buttons = [(0,1.02)] if heart else [(-.62,.83),(0,.83),(.62,.83)]
        for x,y in buttons:
            dot(cv,T((x,y,-1.118)),(115,43,76,255),bias=.12)
            dot(cv,T((x-.015,y+.045,-1.118)),(192,92,103,255),bias=.12)
        for x,z in [(-.67,.65),(.64,1.03)]:
            points = [(x-.08,.622,z-.11),(x-.025,.622,z-.015),(x+.09,.622,z+.05)]
            for a,b in zip(points,points[1:]): stroke(cv,T(a),T(b),(164,60,80,255),bias=.05)
        # The hem breaks gently around the rounded foot corners.
        stroke(cv,T((-.86,.49,1.325)),T((.86,.49,1.325)),(201,104,116,255),bias=.07)
    return dec


def bottle(x, y, z, mat, h=0.26, r=0.05):
    return [cyl(x, y, z, r, h * 0.7, mat), cyl(x, y + h * 0.7, z, r * 0.45, h * 0.3, mat),
            cyl(x, y + h, z, r * 0.5, 0.02, M["dark"])]


def candle(x, y, z):
    prims = [cyl(x, y, z, 0.045, 0.1, M["cream"])]

    def dec(cv, T):
        dot(cv, T((x, y + 0.13, z)), (255, 246, 190), bias=0.4)
        dot(cv, T((x, y + 0.17, z)), (255, 214, 110), bias=0.4)
        dot(cv, T((x, y + 0.21, z)), (255, 150, 70), bias=0.4)
    return prims, dec


def stains(seed=1, amount=0.3, scale=5.0, depth=-1):
    """Irregular blotches (tone offset) for worn fabric, wood and metal."""
    def pat(p, ln, w, n):
        from pa_tiles import vnoise
        a = vnoise(w[:, 0] + w[:, 1] * 0.7, w[:, 2] + w[:, 1] * 0.4, scale, 50 + seed)
        d = np.zeros(len(p), dtype=int)
        d[a > 1 - amount] = depth
        d[a > 1 - amount * 0.45] = depth * 2
        return d
    return pat


def blotches(seed, color_rgb, amount=0.25, scale=6.0):
    """Painted stains of a fixed colour (brown marks on a mattress)."""
    def pat(p, ln, w, n):
        from pa_tiles import vnoise
        a = vnoise(w[:, 0] * 1.3 + w[:, 1], w[:, 2] * 1.3 + w[:, 1] * 0.5, scale, 70 + seed)
        paint = np.zeros((len(p), 4), dtype=np.uint8)
        top = ln[:, 1] > 0.5
        paint[(a > 1 - amount) & top] = tuple(color_rgb) + (255,)
        paint[(a > 1 - amount * 0.5) & top] = tuple(int(c * 0.78) for c in color_rgb) + (255,)
        return np.zeros(len(p), dtype=int), paint
    return pat


def mattress_pattern():
    """Worn mattress: quilting lines on top, brown and wine stains."""
    base = blotches(31, (150, 104, 74), 0.22, 3.4)
    wine = blotches(32, (128, 52, 62), 0.12, 4.0)

    def pat(p, ln, w, n):
        _, paint = base(p, ln, w, n)
        _, paint2 = wine(p, ln, w, n)
        use2 = paint2[:, 3] > 0
        paint[use2] = paint2[use2]
        top = ln[:, 1] > 0.5
        quilt = top & (near(p[:, 0], [-0.45, 0.0, 0.45], 1 / 32) | near(p[:, 2], [-0.55, 0.0, 0.55], 1 / 32))
        d = np.zeros(len(p), dtype=int)
        d[quilt & (paint[:, 3] == 0)] = -1
        return d, paint
    return pat


def item(kind: str, r: int = 0) -> Item:
    m = M
    if kind == "bar":
        prims = [
            box(-1.44, 0.0, -0.22, 1.44, 1.0, 0.40, m["wood"],
                pattern=combine(panels([-1.44, -0.96, -0.48, 0.0, 0.48, 0.96, 1.44], 0.12, 0.92))),
            box(-1.44, 0.0, 0.34, 1.44, 0.08, 0.44, m["dark"]),
            box(-1.5, 1.0, -0.40, 1.5, 1.09, 0.50, m["wood_top"]),
            box(-1.40, 0.70, -0.49, 1.40, 0.76, -0.22, m["wood"]),
            rod((-1.36, 0.2, 0.47), (1.36, 0.2, 0.47), 0.022, m["gold"]),
        ]
        for x in (-1.2, 0.0, 1.2):
            prims.append(rod((x, 0.08, 0.45), (x, 0.2, 0.47), 0.018, m["gold"]))
        prims += bottle(-0.95, 1.09, 0.05, m["bottle_g"], 0.22, 0.04)
        prims += [cyl(-0.55, 1.09, 0.22, 0.035, 0.09, m["glass"]), cyl(0.35, 1.09, 0.25, 0.035, 0.09, m["glass"]),
                  cyl(0.95, 1.09, 0.12, 0.05, 0.07, m["gold"])]
        return Item(prims, (3, 1), lights=[dict(p=(0, 1.1, 0.4), color="ff9ac8", radius=1.4, power=0.35)])
    if kind == "backbar":
        prims = [box(-0.98, 0.0, -0.24, 0.98, 0.86, 0.22, m["wood"], pattern=panels([-0.98, -0.49, 0.0, 0.49, 0.98], 0.08, 0.8)),
                 box(-1.0, 0.86, -0.25, 1.0, 0.92, 0.24, m["wood_top"]),
                 box(-0.98, 0.92, -0.25, 0.98, 2.2, -0.19, m["plum"]),
                 box(-1.0, 0.92, -0.25, -0.92, 2.2, 0.2, m["wood"]), box(0.92, 0.92, -0.25, 1.0, 2.2, 0.2, m["wood"]),
                 box(-1.0, 2.2, -0.25, 1.0, 2.3, 0.22, m["wood_top"])]
        for y in (1.36, 1.8):
            prims.append(box(-0.92, y - 0.04, -0.19, 0.92, y, 0.18, m["wood_top"]))
        cols = ["bottle_g", "bottle_a", "bottle_c", "bottle_r", "bottle_p", "bottle_b", "bottle_a", "bottle_g", "bottle_c", "bottle_r"]
        for row, y in enumerate((0.92, 1.36, 1.8)):
            for i in range(8):
                x = -0.8 + i * 0.228
                c = cols[(i * 3 + row * 5) % len(cols)]
                prims += bottle(x, y, -0.02 + 0.06 * ((i + row) % 2), m[c], 0.28 if (i + row) % 3 else 0.22, 0.052)
        return Item(prims, (2, 0.5), lights=[dict(p=(0, 1.6, 0.1), color="ffb0d0", radius=1.2, power=0.3)])
    if kind == "stool":
        prims = [cyl(0, 0, 0, 0.19, 0.035, m["dark"]), cyl(0, 0.035, 0, 0.035, 0.6, m["chrome"]),
                 cyl(0, 0.26, 0, 0.14, 0.025, m["chrome"]), cyl(0, 0.6, 0, 0.21, 0.05, m["dark"]),
                 cyl(0, 0.65, 0, 0.22, 0.09, m["red"])]
        return Item(prims, (0.7, 0.7))
    if kind == "table":
        prims = [cyl(0, 0, 0, 0.3, 0.04, m["dark"]), cyl(0, 0.04, 0, 0.06, 0.68, m["dark"]),
                 cyl(0, 0.72, 0, 0.56, 0.06, m["wood"], pattern=None)]
        cp, cd = candle(0, 0.78, 0)
        prims += cp
        prims += [cyl(0.22, 0.78, 0.18, 0.04, 0.1, m["glass"]), cyl(-0.2, 0.78, 0.2, 0.035, 0.12, m["bottle_c"])]
        return Item(prims, (1.3, 1.3), decals=cd, lights=[dict(p=(0, 0.95, 0), color="ffb060", radius=1.0, power=0.8)])
    if kind == "coffee":
        prims = legs4(1.4, 0.7, 0.38, 0.035, m["dark"]) + [box(-0.72, 0.38, -0.36, 0.72, 0.45, 0.36, m["wood"])]
        cp, cd = candle(-0.3, 0.45, 0.0)
        cp2, cd2 = candle(0.25, 0.45, -0.1)
        prims += cp + cp2 + [cyl(0.05, 0.45, 0.15, 0.04, 0.09, m["glass"])]

        def dec(cv, T):
            cd(cv, T)
            cd2(cv, T)
        return Item(prims, (1.5, 0.8), decals=dec, lights=[dict(p=(0, 0.6, 0), color="ffb060", radius=1.0, power=0.7)])
    if kind == "chair":
        prims = legs4(0.5, 0.46, 0.42, 0.025, m["black"], 0.04)
        prims += [box(-0.26, 0.42, -0.24, 0.26, 0.54, 0.26, m["magenta"])]
        prims += tag("back", box(-0.26, 0.54, -0.28, 0.26, 1.02, -0.16, m["magenta"], pattern=tufts([-0.12, 0.12], [0.2])))
        return Item(prims, (0.7, 0.7))
    if kind == "sofa":
        prims = [box(-1.28, 0.08, -0.46, 1.28, 0.42, 0.46, m["red"])]
        prims += tag("back", box(-1.28, 0.42, -0.48, 1.28, 0.98, -0.2, m["red"], pattern=tufts([-0.85, -0.3, 0.3, 0.85], [0.1])))
        prims += tag("arm_a", box(-1.30, 0.42, -0.46, -1.06, 0.68, 0.46, m["red"]))
        prims += tag("arm_b", box(1.06, 0.42, -0.46, 1.30, 0.68, 0.46, m["red"]))
        prims += [box(-1.06, 0.42, -0.2, 1.06, 0.56, 0.44, m["red"], pattern=seams_top([-0.353, 0.353]))]
        for x in (-1.18, 1.18):
            for z in (-0.38, 0.38):
                prims.append(cyl(x, 0, z, 0.05, 0.08, m["dark"]))
        return Item(prims, (2.6, 1))
    if kind == "armchair":
        prims = [box(-0.42, 0.08, -0.42, 0.42, 0.4, 0.42, m["magenta"])]
        prims += tag("back", box(-0.44, 0.4, -0.46, 0.44, 0.98, -0.22, m["magenta"], pattern=tufts([-0.15, 0.15], [0.12])))
        prims += tag("arm_a", box(-0.46, 0.4, -0.44, -0.3, 0.66, 0.42, m["magenta"]))
        prims += tag("arm_b", box(0.3, 0.4, -0.44, 0.46, 0.66, 0.42, m["magenta"]))
        prims += [box(-0.3, 0.4, -0.22, 0.3, 0.52, 0.4, m["magenta"])]
        prims += legs4(0.8, 0.8, 0.08, 0.04, m["dark"])
        return Item(prims, (1, 1))
    if kind == "dance" or kind.startswith("dance_s"):
        # dance_s<scheme>_f<frame>: LEDs chasing around the rim, neon rings and a
        # sweeping spot on the stage, rings of light climbing the pole
        scheme, frame = 0, 0
        if kind.startswith("dance_s"):
            scheme = int(kind.split("_s")[1].split("_")[0])
            frame = int(kind.split("_f")[1])
        cols = [hexrgb(c) for c in DANCE_SCHEMES[scheme][1]]

        def bright(c, k=50):
            return tuple(min(255, v + k) for v in c) + (255,)

        def dim(c, f=0.45):
            return tuple(int(v * f) for v in c) + (255,)

        def rim(p, ln, w, n):
            d = np.zeros(len(p), dtype=int)
            paint = np.zeros((len(p), 4), dtype=np.uint8)
            ang = np.arctan2(p[:, 2], p[:, 0]) + math.pi
            side = np.abs(ln[:, 1]) < 0.5
            bins = np.floor(ang / (2 * math.pi) * 28).astype(int)
            dots = np.mod(ang * 14 / math.pi, 1.0) < 0.5
            led = side & (np.abs(p[:, 1] - 0.14) < 0.035) & dots
            for k in range(4):
                sel = led & (np.mod(bins + frame, 4) == k)
                lit = np.mod(bins + frame, 3) != 0
                paint[sel & lit] = bright(cols[k])
                paint[sel & ~lit] = dim(cols[k])
            led2 = side & (np.abs(p[:, 1] - 0.225) < 0.02) & dots
            on2 = np.mod(bins - frame, 4) == 0
            paint[led2 & on2] = (255, 245, 235, 255)
            paint[led2 & ~on2] = dim(cols[(frame + 1) % 4], 0.35)
            d[side & (p[:, 1] > 0.24)] = 1
            return d, paint

        def top(p, ln, w, n):
            r = np.hypot(p[:, 0], p[:, 2])
            ang = np.arctan2(p[:, 2], p[:, 0]) + math.pi
            d = np.zeros(len(p), dtype=int)
            paint = np.zeros((len(p), 4), dtype=np.uint8)
            paint[(r > 1.04) & (r < 1.14)] = bright(cols[frame % 4], 40)
            paint[(r > 0.52) & (r < 0.6)] = bright(cols[(frame + 2) % 4], 20)
            sweep = np.abs(np.mod(ang - frame * math.pi / 2 + math.pi, 2 * math.pi) - math.pi) < 0.45
            d[sweep & (r < 1.0) & (r > 0.15)] = 1
            return d, paint
        base = cols[0]
        floor_hex = "%02x%02x%02x" % tuple(int(v * 0.55 + t * 0.45) for v, t in zip(base, (52, 22, 60)))
        neon_a = Mat("%02x%02x%02x" % cols[(frame + 1) % 4], emissive=True, line=False)
        neon_b = Mat("%02x%02x%02x" % cols[(frame + 3) % 4], emissive=True, line=False)
        climb = 0.5 + (frame % 4) / 4.0 * 1.9
        prims = [cyl(0, 0, 0, 1.44, 0.26, m["purple"], pattern=rim), cyl(0, 0.26, 0, 1.38, 0.03, Mat(floor_hex), pattern=top)]
        prims += tag("pole", cyl(0, 0.29, 0, 0.12, 0.03, neon_a), cyl(0, 0.29, 0, 0.034, 2.45, m["chrome"]),
                     cyl(0, climb, 0, 0.05, 0.05, neon_b), cyl(0, climb + 0.95 if climb < 1.4 else climb - 0.95, 0, 0.05, 0.05, neon_a),
                     cyl(0, 2.66, 0, 0.07, 0.04, neon_a), cyl(0, 2.74, 0, 0.09, 0.05, m["chrome"]))
        return Item(prims, (3, 3), lights=[dict(p=(0, 0.35, 0), color=DANCE_SCHEMES[scheme][1][frame % 4], radius=2.2, power=0.95),
                                            dict(p=(0, 2.0, 0), color=DANCE_SCHEMES[scheme][1][(frame + 1) % 4], radius=1.0, power=0.35)])
    if kind == "plant":
        prims = lathe(0, 0, 0, [(0, 0.19), (0.04, 0.21), (0.38, 0.25), (0.42, 0.27), (0.47, 0.27)], m["terracotta"])
        prims += [cyl(0, 0.43, 0, 0.22, 0.02, m["soil"]), rod((0, 0.44, 0), (0.02, 0.95, 0.0), 0.035, m["trunk"]),
                  rod((0.02, 0.95, 0), (-0.02, 1.25, 0.02), 0.03, m["trunk"])]
        return Item(prims, (0.8, 0.8), bills=[((0.0, 1.28, 0.02), palm(seed=3))])
    if kind == "plant_big":
        prims = lathe(0, 0, 0, [(0, 0.24), (0.05, 0.27), (0.5, 0.32), (0.55, 0.34), (0.6, 0.34)], m["terracotta"])
        prims += [cyl(0, 0.56, 0, 0.29, 0.02, m["soil"]), rod((0, 0.57, 0), (0.03, 1.2, 0.0), 0.045, m["trunk"]),
                  rod((0.03, 1.2, 0), (-0.03, 1.6, 0.02), 0.04, m["trunk"])]
        return Item(prims, (1.0, 1.0), bills=[((0.0, 1.62, 0.02), palm(seed=5, fronds=12, reach=1.25))])
    if kind == "sconce":
        prims = [box(-0.07, 1.42, -0.3, 0.07, 1.72, -0.26, m["gold"]),
                 rod((0, 1.55, -0.26), (0, 1.55, -0.16), 0.02, m["gold"])]
        prims += lathe(0, 1.5, -0.14, [(0, 0.14), (0.22, 0.09)], m["shade"])
        prims += [cyl(0, 1.48, -0.14, 0.05, 0.03, m["gold"])]
        return Item(prims, (0.6, 0.6), shadow=False,
                    lights=[dict(p=(0, 1.6, -0.12), color="ffb866", radius=2.4, power=1.25, wall=True)])
    if kind == "neon":
        def dec(cv, T):
            strokes = []
            for cx, cy, s in ((-0.38, 1.74, 0.027), (0.26, 1.82, 0.024)):
                strokes.append([T((x, y, -0.22)) for (x, y) in heart_points(cx, cy, s)])
            strokes.append([T((-0.9 + 1.7 * t, 1.5 + 0.5 * t, -0.22)) for t in np.linspace(0, 1, 120)])
            halo = (255, 70, 150, 120)
            for pts in strokes:
                for p in pts:
                    sx, sy = screen(p)
                    for ddx, ddy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        i = int(np.floor(sx + cv.ox)) + ddx
                        j = int(np.floor(sy + cv.oy)) + ddy
                        if 0 <= i < cv.w and 0 <= j < cv.h and cv.rgba[j, i, 3] == 0:
                            cv.rgba[j, i] = halo
            for pts in strokes:
                for p in pts:
                    dot(cv, p, (255, 150, 205, 255), bias=1.0)
        mount = [box(-0.9, 1.5, -0.25, -0.86, 1.54, -0.23, m["chrome"]), box(0.84, 1.5, -0.25, 0.88, 1.54, -0.23, m["chrome"])]
        return Item(mount, (2, 0.5), decals=dec, shadow=False, extent=[(-1.0, 2.3, -0.25), (1.0, 1.2, -0.25), (-1.0, 1.2, -0.25), (1.0, 2.3, -0.25)],
                    lights=[dict(p=(0, 1.72, -0.15), color="ff4fa0", radius=2.4, power=1.1, wall=True)])
    if kind == "heart_bed" or kind.startswith("heart_bed_"):
        original = item(kind.replace("heart_bed", "bed", 1), r)
        return luxury_heart_bed(original,kind == "heart_bed")
    if kind == "bed":
        head = combine(panels([-1.08, -0.36, 0.36, 1.08], 0.3, 1.26), tufts([-0.72, 0.0, 0.72], [0.8]))
        prims = [box(-1.08, 0.06, -1.24, 1.08, 0.3, 1.33, m["wood"]),
                 box(-1.0, 0.3, -1.2, 1.0, 0.5, 1.28, m["white"]),
                 box(-1.06, 0.26, -0.42, 1.06, 0.62, 1.32, m["pink"], pattern=stripes_y([0.44], 1)),
                 box(-1.06, 0.62, -0.46, 1.06, 0.66, -0.3, m["rose"])]
        prims += tag("head", box(-1.1, 0.06, -1.35, 1.1, 1.32, -1.2, m["headboard"], pattern=head))
        for x in (-0.5, 0.5):
            prims.append(box(x - 0.4, 0.5, -1.16, x + 0.4, 0.72, -0.72, m["white"]))
        prims += legs4(2.1, 2.6, 0.06, 0.05, m["dark"])
        return Item(polish_bed(prims), (2.2, 2.7), decals=bed_details())
    if kind == "nightstand":
        prims = [box(-0.27, 0.06, -0.27, 0.27, 0.56, 0.27, m["wood"], pattern=panels([-0.27, 0.27], 0.08, 0.3)),
                 box(-0.3, 0.56, -0.3, 0.3, 0.62, 0.3, m["wood_top"])]
        prims += [cyl(0, 0.32, 0.28, 0.03, 0.03, m["gold"])] if False else []
        prims += legs4(0.5, 0.5, 0.06, 0.03, m["dark"])

        def dec(cv, T):
            dot(cv, T((0, 0.44, 0.275)), (240, 200, 110, 255), bias=0.2)
            dot(cv, T((0, 0.20, 0.275)), (240, 200, 110, 255), bias=0.2)
        return Item(prims, (0.7, 0.7), decals=dec)
    if kind == "lamp":
        prims = [box(-0.24, 0.0, -0.24, 0.24, 0.52, 0.24, m["wood"], pattern=panels([-0.24, 0.24], 0.06, 0.46)),
                 box(-0.26, 0.52, -0.26, 0.26, 0.58, 0.26, m["wood_top"])]
        prims += lathe(0, 0.58, 0, [(0, 0.09), (0.03, 0.1), (0.06, 0.04), (0.22, 0.03)], m["gold"])
        prims += lathe(0, 0.8, 0, [(0, 0.16), (0.2, 0.1)], m["shade"])
        return Item(prims, (0.6, 0.6), lights=[dict(p=(0, 0.9, 0), color="ffc36a", radius=1.3, power=1.0)])
    if kind == "mirror":
        def glass(p, ln, w, n):
            d = np.zeros(len(p), dtype=int)
            paint = np.zeros((len(p), 4), dtype=np.uint8)
            f = _front(ln)
            inner = f & (np.abs(p[:, 0]) < 0.27) & (np.abs(p[:, 1]) < 0.8)
            base = np.array([126, 150, 178, 255], dtype=np.uint8)
            paint[inner] = base
            streak = inner & (np.abs((p[:, 0] * 1.6 + p[:, 1]) - 0.3) < 0.05)
            paint[streak] = (190, 214, 232, 255)
            streak2 = inner & (np.abs((p[:, 0] * 1.6 + p[:, 1]) - 0.5) < 0.025)
            paint[streak2] = (170, 196, 222, 255)
            return d, paint
        prims = [box(-0.34, 0.06, -0.2, 0.34, 1.84, -0.12, m["gold"], pattern=glass),
                 box(-0.36, 0.0, -0.24, 0.36, 0.06, 0.12, m["gold"])]
        return Item(prims, (0.9, 0.5))
    if kind == "toilet":
        prims = [box(-0.23, 0.42, -0.49, 0.23, 0.86, -0.3, m["ceramic"]), box(-0.25, 0.86, -0.5, 0.25, 0.9, -0.28, m["ceramic"]),
                 cyl(0, 0, -0.02, 0.13, 0.3, m["ceramic"], rz=0.17),
                 cyl(0, 0.3, 0.02, 0.21, 0.1, m["ceramic"], rz=0.27), cyl(0, 0.4, 0.02, 0.22, 0.035, m["white"], rz=0.28),
                 cyl(0, 0.41, 0.03, 0.14, 0.03, m["water"], rz=0.19)]
        return Item(prims, (0.7, 1), decals=lambda cv, T: dot(cv, T((0.12, 0.9, -0.39)), (180, 184, 196, 255), bias=0.2))
    if kind == "urinal":
        prims = [box(-0.19, 0.4, -0.225, 0.19, 1.16, -0.18, m["ceramic"]),
                 ell(0, 0.72, -0.12, 0.17, 0.26, 0.12, m["ceramic"]),
                 ell(0, 0.78, -0.07, 0.11, 0.16, 0.07, m["water"]),
                 rod((0, 1.16, -0.2), (0, 1.3, -0.2), 0.02, m["chrome"]), cyl(0, 1.26, -0.19, 0.035, 0.06, m["chrome"]),
                 box(0.22, 0.3, -0.225, 0.245, 1.45, 0.18, m["grey"])]
        return Item(prims, (0.5, 0.45))
    if kind == "sink":
        def glass(p, ln, w, n):
            paint = np.zeros((len(p), 4), dtype=np.uint8)
            f = _front(ln)
            inner = f & (np.abs(p[:, 0]) < 0.24) & (np.abs(p[:, 1]) < 0.27)
            paint[inner] = (130, 158, 184, 255)
            paint[inner & (np.abs((p[:, 0] + p[:, 1]) - 0.1) < 0.04)] = (192, 216, 234, 255)
            return np.zeros(len(p), dtype=int), paint
        prims = [box(-0.42, 0.0, -0.3, 0.42, 0.78, 0.28, m["wood"], pattern=panels([-0.42, 0.0, 0.42], 0.08, 0.7)),
                 box(-0.44, 0.78, -0.31, 0.44, 0.84, 0.3, m["white"]),
                 cyl(0, 0.84, 0.0, 0.2, 0.02, m["ceramic"], rz=0.16), cyl(0, 0.845, 0.0, 0.15, 0.02, m["water"], rz=0.11),
                 rod((0, 0.84, -0.22), (0, 1.0, -0.22), 0.02, m["chrome"]), rod((0, 1.0, -0.22), (0, 1.0, -0.12), 0.018, m["chrome"]),
                 box(-0.3, 1.12, -0.325, 0.3, 1.8, -0.3, m["chrome"], pattern=glass)]
        return Item(prims, (0.9, 0.65))
    if kind == "bin":
        prims = lathe(0, 0, 0, [(0, 0.16), (0.48, 0.19)], m["black"]) + [cyl(0, 0.48, 0, 0.2, 0.03, m["steel"])]
        return Item(prims, (0.5, 0.5))
    if kind == "shelf":
        prims = []
        for x in (-0.86, 0.86):
            for z in (-0.3, 0.3):
                prims.append(box(x - 0.025, 0, z - 0.025, x + 0.025, 2.0, z + 0.025, m["steel"]))
        for y in (0.12, 0.72, 1.32, 1.92):
            prims.append(box(-0.88, y, -0.32, 0.88, y + 0.05, 0.32, m["steel"]))
        for y in (0.17, 0.77, 1.37):
            for i, x in enumerate((-0.52, 0.0, 0.52)):
                h = 0.34 if (i + int(y * 10)) % 2 else 0.4
                prims.append(box(x - 0.22, y, -0.24, x + 0.22, y + h, 0.24, m["cardboard"], pattern=tape()))
        return Item(prims, (1.8, 0.7))
    if kind == "crate":
        prims = [box(-0.42, 0, -0.42, 0.2, 0.44, 0.22, m["cardboard"], pattern=tape()),
                 box(0.2, 0, -0.42, 0.44, 0.34, -0.02, m["cardboard"], pattern=tape()),
                 box(-0.38, 0.44, -0.4, 0.12, 0.78, 0.12, m["cardboard"], pattern=tape()),
                 box(-0.3, 0, 0.22, 0.3, 0.3, 0.44, m["cardboard"], pattern=tape())]
        return Item(prims, (0.9, 0.9))
    if kind == "fridge":
        prims = [box(-0.42, 0.04, -0.4, 0.42, 1.92, 0.38, m["fridge"], pattern=combine(stripes_y([1.3], -2), panels([-0.42, 0.42], 0.06, 1.86))),
                 box(-0.4, 0, -0.38, 0.4, 0.04, 0.36, m["dark"]),
                 rod((-0.3, 1.4, 0.41), (-0.3, 1.7, 0.41), 0.018, m["chrome"]), rod((-0.3, 0.9, 0.41), (-0.3, 1.2, 0.41), 0.018, m["chrome"])]
        return Item(prims, (0.9, 0.9))
    if kind == "locker":
        def lock(p, ln, w, n):
            d = np.zeros(len(p), dtype=int)
            f = _front(ln)
            d[f & near(p[:, 0], [-0.24, 0.24], 1 / 30)] = -2
            for x0 in (-0.49, 0.0, 0.49):
                vent = f & (np.abs(p[:, 0] - x0) < 0.12) & near(p[:, 1], [1.65, 1.72, 1.79], 1 / 48)
                d[vent] = -1
            return d
        prims = [box(-0.73, 0.04, -0.33, 0.73, 1.96, 0.3, m["teal"], pattern=lock),
                 box(-0.72, 0, -0.32, 0.72, 0.04, 0.29, m["dark"])]
        for x in (-0.36, 0.13, 0.62):
            prims.append(rod((x, 0.95, 0.32), (x, 1.12, 0.32), 0.016, m["chrome"]))
        return Item(prims, (1.5, 0.7))
    if kind == "desk":
        prims = [box(-0.78, 0.72, -0.38, 0.78, 0.78, 0.38, m["dark"]),
                 box(0.2, 0, -0.36, 0.76, 0.72, 0.34, m["black"], pattern=panels([0.2, 0.76], 0.06, 0.66))]
        prims += [box(-0.76, 0, -0.36, -0.7, 0.72, 0.34, m["black"])]
        prims += [box(-0.3, 0.78, -0.25, 0.1, 0.8, -0.18, m["dark"]), box(-0.08, 0.8, -0.24, -0.02, 0.92, -0.2, m["dark"]),
                  box(-0.34, 0.9, -0.26, 0.26, 1.24, -0.2, m["dark"], pattern=screen_face((80, 160, 230)))]
        prims += [box(-0.3, 0.78, 0.0, 0.2, 0.8, 0.14, m["grey"]), box(0.35, 0.78, 0.0, 0.62, 0.79, 0.24, m["paper"])]
        return Item(prims, (1.6, 0.8), lights=[dict(p=(-0.04, 1.05, -0.1), color="7fc0ff", radius=0.8, power=0.35)])
    if kind == "reception":
        prims = [box(-0.98, 0.0, 0.08, 0.98, 1.06, 0.36, m["wood_red"], pattern=panels([-0.98, -0.33, 0.33, 0.98], 0.1, 0.96)),
                 box(-1.0, 1.06, 0.04, 1.0, 1.13, 0.4, m["plum"]),
                 box(-0.98, 0.72, -0.38, 0.98, 0.78, 0.08, m["wood"]),
                 box(-0.98, 0.0, -0.38, -0.9, 0.72, 0.08, m["wood"]), box(0.9, 0.0, -0.38, 0.98, 0.72, 0.08, m["wood"]),
                 box(-0.58, 0.78, -0.2, -0.3, 0.8, -0.1, m["dark"]), box(-0.47, 0.8, -0.18, -0.41, 0.9, -0.14, m["dark"]),
                 box(-0.62, 0.88, -0.14, -0.26, 1.2, -0.08, m["dark"], pattern=back_screen()),
                 box(0.25, 1.13, 0.14, 0.43, 1.16, 0.32, m["dark"]), box(0.28, 1.16, 0.17, 0.4, 1.19, 0.25, m["screen_g"]),
                 cyl(0.72, 1.13, 0.24, 0.05, 0.04, m["gold"]), box(-0.1, 1.13, 0.16, 0.12, 1.14, 0.32, m["paper"])]
        return Item(prims, (2.0, 0.8), lights=[dict(p=(-0.44, 1.05, -0.2), color="7fc0ff", radius=0.8, power=0.3)])
    if kind == "coat_rack":
        prims = [box(-0.6, 0.36, -0.2, 0.6, 0.42, 0.2, m["wood_warm"]),
                 box(-0.58, 0, -0.18, -0.52, 0.36, 0.18, m["wood_warm"]), box(0.52, 0, -0.18, 0.58, 0.36, 0.18, m["wood_warm"]),
                 rod((-0.56, 0.42, -0.02), (-0.56, 1.66, -0.02), 0.025, m["dark"]), rod((0.56, 0.42, -0.02), (0.56, 1.66, -0.02), 0.025, m["dark"]),
                 rod((-0.56, 1.62, -0.02), (0.56, 1.62, -0.02), 0.02, m["chrome"])]
        coats = ["navy", "purple", "black", "velvet", "grey", "purple", "navy"]
        for i, c in enumerate(coats):
            x = -0.44 + i * 0.147
            length = 0.72 + 0.14 * ((i * 5) % 3) / 2
            prims.append(box(x - 0.055, 1.58 - length, -0.17, x + 0.055, 1.58, 0.15, m[c]))
            prims.append(box(x - 0.065, 1.5, -0.18, x + 0.065, 1.6, 0.16, m[c]))
        prims += [box(-0.4, 0.42, -0.1, -0.22, 0.5, 0.12, m["black"]), box(0.2, 0.42, -0.08, 0.4, 0.49, 0.12, m["velvet"])]
        return Item(prims, (1.25, 0.5))
    if kind == "cloak_locker":
        def grid(p, ln, w, n):
            d = np.zeros(len(p), dtype=int)
            paint = np.zeros((len(p), 4), dtype=np.uint8)
            f = _front(ln)
            d[f & near(p[:, 0], [-0.16, 0.16], 1 / 30)] = -2
            d[f & near(p[:, 1], [-0.3, 0.3], 1 / 46)] = -2
            for cx in (-0.32, 0.0, 0.32):
                for cy in (-0.6, 0.0, 0.6):
                    lab = f & (np.abs(p[:, 0] - cx) < 0.05) & (np.abs(p[:, 1] - (cy + 0.18)) < 0.025)
                    paint[lab] = (232, 222, 196, 255)
                    key = f & (np.abs(p[:, 0] - (cx + 0.1)) < 0.03) & (np.abs(p[:, 1] - cy) < 0.03)
                    paint[key] = (230, 190, 90, 255)
            return d, paint
        prims = [box(-0.48, 0.06, -0.24, 0.48, 1.86, 0.2, m["grey"], pattern=grid), box(-0.46, 0, -0.22, 0.46, 0.06, 0.18, m["dark"])]
        return Item(prims, (1.0, 0.5))
    if kind == "rope":
        prims = []
        for x in (-0.44, 0.44):
            prims += [cyl(x, 0, 0, 0.1, 0.03, m["gold"]), cyl(x, 0.03, 0, 0.028, 0.86, m["gold"]), ell(x, 0.93, 0, 0.05, 0.05, 0.05, m["gold"])]
        pts = []
        for i in range(13):
            t = i / 12
            x = -0.4 + 0.8 * t
            y = 0.84 - 0.2 * math.sin(math.pi * t)
            pts.append((x, y, 0.0))
        for a, b in zip(pts[:-1], pts[1:]):
            prims.append(rod(a, b, 0.03, m["velvet"]))
        return Item(prims, (1.0, 0.3))
    if kind == "rug":
        def border(p, ln, w, n):
            d = np.zeros(len(p), dtype=int)
            paint = np.zeros((len(p), 4), dtype=np.uint8)
            edge = (np.abs(np.abs(p[:, 0]) - 0.5) < 0.035) | (np.abs(np.abs(p[:, 2]) - 0.9) < 0.035)
            paint[_top(ln) & edge] = (224, 176, 80, 255)
            return d, paint
        prims = [box(-0.58, 0, -0.98, 0.58, 0.02, 0.98, m["rug"], pattern=border)]
        return Item(prims, (1.2, 2.0), shadow=False, flat=True)
    if kind == "frame":
        def art(p, ln, w, n):
            paint = np.zeros((len(p), 4), dtype=np.uint8)
            f = _front(ln)
            inner = f & (np.abs(p[:, 0]) < 0.28) & (np.abs(p[:, 1]) < 0.22)
            paint[inner] = (122, 44, 92, 255)
            r1 = inner & ((p[:, 0] + 0.08) ** 2 + (p[:, 1] - 0.02) ** 2 < 0.012)
            r2 = inner & ((p[:, 0] - 0.1) ** 2 + (p[:, 1] + 0.04) ** 2 < 0.008)
            paint[r1] = (236, 104, 150, 255)
            paint[r2] = (40, 20, 40, 255)
            return np.zeros(len(p), dtype=int), paint
        prims = [box(-0.34, 1.25, -0.1, 0.34, 1.83, -0.06, m["gold"], pattern=art)]
        return Item(prims, (0.8, 0.2), shadow=False)
    if kind == "cabinet":
        def glassfront(p, ln, w, n):
            paint = np.zeros((len(p), 4), dtype=np.uint8)
            f = _front(ln)
            inner = f & (np.abs(p[:, 0]) < 0.33) & (p[:, 1] > -0.55) & (p[:, 1] < 0.72)
            paint[inner & (np.abs((p[:, 0] + p[:, 1]) - 0.2) < 0.03)] = (200, 220, 236, 160)
            return np.zeros(len(p), dtype=int), paint
        prims = [box(-0.38, 0, -0.2, 0.38, 0.52, 0.2, m["wood"], pattern=panels([-0.38, 0.0, 0.38], 0.06, 0.46)),
                 box(-0.38, 0.52, -0.2, -0.34, 1.62, 0.2, m["wood"]), box(0.34, 0.52, -0.2, 0.38, 1.62, 0.2, m["wood"]),
                 box(-0.38, 0.52, -0.2, 0.38, 1.62, -0.16, m["plum"]), box(-0.38, 1.62, -0.2, 0.38, 1.68, 0.2, m["wood_top"]),
                 box(-0.34, 1.07, -0.16, 0.34, 1.1, 0.16, m["wood_top"])]
        cols = ["bottle_a", "bottle_c", "bottle_r", "bottle_g", "bottle_p"]
        for row, y in enumerate((0.52, 1.1)):
            for i in range(4):
                prims += bottle(-0.24 + i * 0.16, y, 0.0, m[cols[(i + row * 2) % 5]], 0.26, 0.045)
        return Item(prims, (0.8, 0.45))
    if kind in ("pink", "red", "purple"):
        mat = m["neon_" + kind]
        color = {"pink": "ff4fa0", "red": "ff4d57", "purple": "b476ff"}[kind]
        prims = lathe(0, 0, 0, [(0, 0.2), (0.03, 0.2), (0.06, 0.12), (0.1, 0.05)], m["black"])
        prims += [cyl(0, 0.1, 0, 0.04, 1.9, mat), cyl(0, 2.0, 0, 0.05, 0.03, m["black"])]
        return Item(prims, (0.5, 0.5), lights=[dict(p=(0, 1.1, 0), color=color, radius=1.8, power=1.0)])
    # ---------------------------------------------------- salvaged, worn furniture
    if kind in ("old_toilet", "old_sink"):
        it = item(kind[4:])
        for k, p in enumerate(it.prims):
            if p.pattern is None:
                p.pattern = stains(40 + k, 0.38, 6.0)
        return it
    if kind == "old_sofa":
        worn = Mat("a23a44")
        prims = [box(-1.08, 0.07, -0.42, 1.08, 0.4, 0.42, worn, pattern=stains(1, 0.35))]
        prims += tag("back", box(-1.08, 0.4, -0.44, 1.08, 0.9, -0.18, worn, pattern=stains(2, 0.3)))
        prims += tag("arm_a", box(-1.1, 0.4, -0.42, -0.88, 0.62, 0.42, worn, pattern=stains(3, 0.4)))
        prims += tag("arm_b", box(0.88, 0.4, -0.42, 1.1, 0.6, 0.42, worn, pattern=stains(4, 0.4)))
        prims += [box(-0.88, 0.4, -0.18, 0.0, 0.53, 0.4, worn, pattern=stains(5, 0.3)),
                 box(0.0, 0.4, -0.18, 0.88, 0.49, 0.4, worn, pattern=stains(6, 0.3)),
                 box(0.3, 0.49, 0.05, 0.52, 0.52, 0.22, Mat("d8c096")),
                 ell(-0.5, 0.57, -0.02, 0.2, 0.08, 0.14, Mat("c9a24a"))]
        for x in (-1.0, 1.0):
            for z in (-0.34, 0.34):
                prims.append(cyl(x, 0, z, 0.04, 0.07, m["dark"]))
        return Item(prims, (2.2, 0.9))
    if kind == "old_bed":
        frame_w = Mat("5c3b2a")
        prims = [box(-0.95, 0.05, -1.15, 0.95, 0.26, 1.15, frame_w, pattern=stains(7, 0.3)),
                 box(-0.9, 0.26, -1.1, 0.9, 0.46, 1.1, Mat("d9cfbf"), pattern=mattress_pattern())]
        prims += tag("head", box(-0.93, 0.05, -1.22, 0.93, 0.7, -1.12, frame_w, pattern=stains(22, 0.35)))
        prims += [box(-0.6, 0.46, -1.05, -0.05, 0.56, -0.72, Mat("cfc5b0"), pattern=stains(9, 0.3)),
                 box(-0.85, 0.46, 0.45, 0.8, 0.52, 1.02, Mat("6a6e7a"), pattern=stains(10, 0.3))]
        prims += legs4(1.8, 2.2, 0.05, 0.04, m["dark"])
        return Item(polish_bed(prims,used=True), (2.0, 2.4))
    if kind == "old_lamp":
        wood = Mat("5a3a2c")
        prims = [box(-0.22, 0.0, -0.22, 0.22, 0.48, 0.22, wood, pattern=combine(panels([-0.22, 0.22], 0.06, 0.42), stains(11, 0.35))),
                 box(-0.24, 0.48, -0.24, 0.24, 0.53, 0.24, wood)]
        prims += lathe(0, 0.53, 0, [(0, 0.07), (0.03, 0.08), (0.05, 0.03), (0.2, 0.025)], Mat("a88a4a"))
        prims += lathe(0, 0.73, 0, [(0, 0.14), (0.17, 0.09)], Mat("f2d28a", emissive=True, line=False))
        prims.append(cyl(0.12, 0.53, 0.1, 0.035, 0.12, m["bottle_g"]))
        return Item(prims, (0.6, 0.6), lights=[dict(p=(0, 0.82, 0), color="ffb35a", radius=1.2, power=0.85)])
    if kind == "old_table":
        wood = Mat("6a4632")
        prims = legs4(0.6, 0.6, 0.5, 0.035, Mat("4a3024")) + [box(-0.34, 0.5, -0.34, 0.34, 0.56, 0.34, wood, pattern=stains(12, 0.4))]
        prims += bottle(-0.12, 0.56, -0.08, m["bottle_g"], 0.24, 0.045) + bottle(0.12, 0.56, 0.1, m["bottle_a"], 0.2, 0.045)
        prims.append(rod((0.02, 0.585, -0.2), (0.24, 0.585, -0.1), 0.035, m["bottle_g"]))
        return Item(prims, (0.8, 0.8))
    if kind == "old_locker":
        body = Mat("4f7470")

        def dents(p, ln, w, n):
            d = stains(13, 0.3, 7.0)(p, ln, w, n)
            f = ln[:, 2] > 0.5
            d[f & near(p[:, 0], [0.0], 1 / 30)] = -2
            d[f & near(p[:, 1], [0.62, 0.68, 0.74], 1 / 48) & (np.abs(np.abs(p[:, 0]) - 0.22) < 0.12)] = -1
            return d
        prims = [box(-0.46, 0.04, -0.28, 0.46, 1.84, 0.26, body, pattern=dents),
                 box(-0.44, 0, -0.26, 0.44, 0.04, 0.24, m["dark"]),
                 box(0.02, 0.1, 0.26, 0.44, 1.78, 0.28, Mat("26302f")),
                 box(0.44, 0.1, 0.26, 0.47, 1.78, 0.33, body, pattern=stains(14, 0.4))]
        return Item(prims, (1.0, 0.7))
    if kind == "old_fridge":
        prims = [box(-0.37, 0.04, -0.36, 0.37, 1.7, 0.34, Mat("cbc6b8"), pattern=combine(stripes_y([1.2], -2), stains(15, 0.3, 6.0))),
                 box(-0.35, 0, -0.34, 0.35, 0.04, 0.32, m["dark"]),
                 rod((-0.27, 1.3, 0.37), (-0.27, 1.55, 0.37), 0.016, m["steel"]), rod((-0.27, 0.8, 0.37), (-0.27, 1.1, 0.37), 0.016, m["steel"])]
        return Item(prims, (0.8, 0.8))
    if kind == "old_shelf":
        rust = Mat("7a6258")
        prims = []
        for x in (-0.76, 0.76):
            for z in (-0.26, 0.26):
                prims.append(box(x - 0.025, 0, z - 0.025, x + 0.025, 1.8, z + 0.025, rust))
        for y in (0.1, 0.65, 1.2, 1.75):
            prims.append(box(-0.78, y, -0.28, 0.78, y + 0.04, 0.28, rust, pattern=stains(16, 0.4)))
        prims += [box(-0.6, 0.14, -0.2, -0.2, 0.44, 0.2, m["cardboard"], pattern=tape()),
                  box(0.15, 0.69, -0.2, 0.55, 0.95, 0.18, m["cardboard"], pattern=stains(17, 0.3)),
                  box(-0.55, 1.24, -0.18, -0.25, 1.36, 0.16, Mat("5a6070"))]
        prims += bottle(0.4, 1.24, 0.0, m["bottle_c"], 0.22, 0.04)
        return Item(prims, (1.6, 0.6))
    if kind == "pillar":
        col = Mat("7a2432")
        prims = [box(-0.19, 0, -0.19, 0.19, 0.14, 0.19, Mat("2b2531")),
                 box(-0.16, 0.14, -0.16, 0.16, 2.1, 0.16, col, pattern=stains(18, 0.3, 4.0)),
                 box(-0.2, 2.1, -0.2, 0.2, 2.3, 0.2, Mat("2b2531"))]
        return Item(prims, (0.5, 0.5))
    if kind == "poster":
        def art(p, ln, w, n):
            paint = np.zeros((len(p), 4), dtype=np.uint8)
            f = _front(ln)
            x = p[:, 0]
            y = p[:, 1]
            inner = f & (np.abs(x) < 0.24) & (np.abs(y) < 0.32)
            paint[inner] = (232, 138, 178, 255)
            head = (x + 0.02) ** 2 + (y - 0.2) ** 2 < 0.0035
            body = (np.abs(x - 0.01 + 0.05 * np.sin(y * 9)) < 0.045) & (y < 0.16) & (y > -0.06)
            legs = (np.abs(np.abs(x - 0.01) - 0.04 + (y + 0.06) * 0.2) < 0.022) & (y <= -0.06) & (y > -0.27)
            arm = (np.abs(y - 0.1 - (x - 0.02) * 0.9) < 0.022) & (x > 0.02) & (x < 0.13)
            paint[inner & (head | body | legs | arm)] = (24, 14, 26, 255)
            torn = inner & (x + y > 0.44)
            paint[torn] = (196, 170, 150, 255)
            return np.zeros(len(p), dtype=int), paint
        prims = [box(-0.26, 1.2, -0.1, 0.26, 1.88, -0.08, m["cream"], pattern=art)]
        return Item(prims, (0.6, 0.2), shadow=False)
    if kind == "boards":
        plank = Mat("a07a52")
        prims = [box(-0.45, 0.9, -0.1, 0.45, 2.0, -0.07, Mat("3a2c34")),
                 box(-0.4, 0.95, -0.075, 0.4, 1.95, -0.065, Mat("22202c"))]
        for (y, ang) in ((1.2, 14), (1.5, -10), (1.78, 8)):
            prims.append(box(-0.5, y - 0.05, -0.06, 0.5, y + 0.05, -0.02, plank, pattern=stains(19, 0.35)).transformed(rot_z(ang), (0, y, -0.04)))
        return Item(prims, (1.2, 0.2), shadow=False)
    if kind == "old_armchair":
        worn = Mat("7a5a86")
        prims = [box(-0.4, 0.06, -0.4, 0.4, 0.34, 0.4, worn, pattern=stains(23, 0.35))]
        prims += tag("back", box(-0.42, 0.34, -0.44, 0.42, 0.9, -0.2, worn, pattern=stains(24, 0.3)).transformed(rot_x(-6), (0, 0.34, -0.32)))
        prims += tag("arm_a", box(-0.44, 0.34, -0.42, -0.28, 0.58, 0.4, worn, pattern=stains(25, 0.4)))
        prims += tag("arm_b", box(0.28, 0.34, -0.42, 0.44, 0.55, 0.4, worn, pattern=stains(26, 0.4)))
        prims += [box(-0.28, 0.3, -0.2, 0.28, 0.4, 0.38, Mat("6a4c76"), pattern=stains(27, 0.3)),
                 ell(0.1, 0.42, 0.1, 0.1, 0.05, 0.08, Mat("d8c096"))]
        prims += legs4(0.74, 0.74, 0.06, 0.035, m["dark"])
        return Item(prims, (1, 1))
    if kind == "old_rug":
        def worn_rug(p, ln, w, n):
            from pa_tiles import vnoise
            d = np.zeros(len(p), dtype=int)
            paint = np.zeros((len(p), 4), dtype=np.uint8)
            top = ln[:, 1] > 0.5
            border = (np.abs(np.abs(p[:, 0]) - 0.52) < 0.04) | (np.abs(np.abs(p[:, 2]) - 0.86) < 0.04)
            paint[top & border] = (176, 138, 70, 255)
            medallion = (np.abs(p[:, 0]) * 1.6 + np.abs(p[:, 2]) < 0.34) & (np.abs(p[:, 0]) * 1.6 + np.abs(p[:, 2]) > 0.26)
            paint[top & medallion] = (176, 138, 70, 255)
            bald = vnoise(p[:, 0] * 2, p[:, 2] * 2, 2.0, 81) > 0.66
            d[top & bald] = 1
            paint[top & bald & (paint[:, 3] > 0)] = (140, 116, 76, 255)
            stain = vnoise(p[:, 0], p[:, 2], 3.0, 82) > 0.74
            d[top & stain] = -2
            fringe = top & (np.abs(p[:, 2]) > 0.94) & (np.mod(p[:, 0] * 16, 2) < 1)
            paint[fringe] = (214, 198, 164, 255)
            return d, paint
        prims = [box(-0.58, 0, -0.98, 0.58, 0.02, 0.98, Mat("6e2a3a"), pattern=worn_rug)]
        return Item(prims, (1.2, 2.0), shadow=False, flat=True)
    if kind == "old_wardrobe":
        wood = Mat("5e4030")

        def doors(p, ln, w, n):
            d = stains(28, 0.35, 5.0)(p, ln, w, n)
            f = ln[:, 2] > 0.5
            d[f & near(p[:, 0], [0.0], 1 / 30)] = -2
            d[f & near(p[:, 1], [-0.95], 1 / 46)] = -2
            return d
        prims = [box(-0.56, 0.08, -0.28, 0.56, 1.95, 0.26, wood, pattern=doors),
                 box(-0.6, 1.95, -0.3, 0.6, 2.05, 0.28, Mat("4a3226")),
                 box(-0.56, 0.0, -0.26, -0.48, 0.08, 0.24, m["dark"]), box(0.48, 0.0, -0.26, 0.56, 0.08, 0.24, m["dark"]),
                 box(0.02, 0.35, 0.26, 0.54, 1.9, 0.28, Mat("2a1e1a")),
                 box(0.5, 0.35, 0.28, 0.54, 1.9, 0.62, wood, pattern=stains(29, 0.4)),
                 box(0.1, 1.4, 0.0, 0.46, 1.44, 0.24, m["steel"]),
                 box(0.14, 0.9, -0.1, 0.3, 1.4, 0.2, Mat("8a3a4a")), box(0.32, 1.0, -0.1, 0.44, 1.4, 0.2, Mat("3a4a6a")),
                 cyl(-0.08, 1.0, 0.27, 0.02, 0.03, m["gold"])]
        return Item(prims, (1.2, 0.7))
    # ---------------------------------------------------- beds in use, unmade (sprites swapped by the game)
    if kind.startswith("bed_busy") or kind == "bed_unmade":
        frame = int(kind[-1]) if kind[-1].isdigit() else 0
        head = combine(panels([-1.08, -0.36, 0.36, 1.08], 0.3, 1.26), tufts([-0.72, 0.0, 0.72], [0.8]))
        prims = [box(-1.08, 0.06, -1.24, 1.08, 0.3, 1.33, m["wood"]),
                 box(-1.0, 0.3, -1.2, 1.0, 0.5, 1.28, m["white"], pattern=stains(41, 0.25) if kind == "bed_unmade" else None)]
        prims += tag("head", box(-1.1, 0.06, -1.35, 1.1, 1.32, -1.2, m["headboard"], pattern=head))
        prims += legs4(2.1, 2.6, 0.06, 0.05, m["dark"])
        if kind.startswith("bed_busy"):
            # two people under the duvet: only their hair shows on the pillows
            for x in (-0.5, 0.5):
                prims.append(box(x - 0.4, 0.5, -1.16, x + 0.4, 0.72, -0.72, m["white"]))
            # the lumps under the duvet heave in turn (frames 0-3)
            ly, ry_, lz = [(0.64, 0.64, 0.3), (0.74, 0.6, 0.24), (0.8, 0.8, 0.16), (0.6, 0.76, 0.26)][frame]
            prims += [box(-1.06, 0.26, -0.62, 1.06, 0.62, 1.32, m["pink"], pattern=stripes_y([0.44], 1)),
                      box(-1.06, 0.62, -0.66, 1.06, 0.66, -0.5, m["rose"]),
                      ell(-0.42, ly, lz, 0.38, 0.2 + 0.04 * (frame == 2), 0.66, m["pink"]),
                      ell(0.44, ry_, lz - 0.05, 0.38, 0.19 + 0.04 * (frame == 2), 0.62, m["pink"]),
                      ell(-0.46 + 0.04 * (frame % 2), 0.8, -0.8, 0.16, 0.13, 0.15, Mat("3a2a22")),
                      ell(0.46 - 0.04 * (frame % 2), 0.8, -0.82, 0.16, 0.13, 0.15, Mat("e2b25a"))]
        else:
            # duvet thrown back to the foot and over the side, pillows askew
            prims += [box(-0.9, 0.5, -1.16, -0.1, 0.72, -0.72, m["white"]).transformed(rot_y(18), (-0.5, 0.5, -0.94)),
                      box(0.05, 0.5, -0.4, 0.85, 0.7, 0.04, m["white"]).transformed(rot_y(-28), (0.45, 0.5, -0.2)),
                      box(-1.06, 0.5, 0.55, 0.95, 0.68, 1.34, m["pink"], pattern=stripes_y([0.58], 1)),
                      box(0.95, 0.12, 0.2, 1.14, 0.66, 1.3, m["pink"]),
                      ell(-0.3, 0.66, 0.75, 0.42, 0.1, 0.3, m["rose"])]
        return Item(polish_bed(prims), (2.2, 2.7), decals=bed_details())
    if kind.startswith("old_bed_busy") or kind == "old_bed_unmade":
        frame = int(kind[-1]) if kind[-1].isdigit() else 0
        frame_w = Mat("5c3b2a")
        prims = [box(-0.95, 0.05, -1.15, 0.95, 0.26, 1.15, frame_w, pattern=stains(7, 0.3)),
                 box(-0.9, 0.26, -1.1, 0.9, 0.46, 1.1, Mat("d9cfbf"), pattern=mattress_pattern())]
        prims += tag("head", box(-0.93, 0.05, -1.22, 0.93, 0.7, -1.12, frame_w, pattern=stains(22, 0.35)))
        prims += legs4(1.8, 2.2, 0.05, 0.04, m["dark"])
        blanket = Mat("6a6e7a")
        if kind.startswith("old_bed_busy"):
            ly, ry_, lz = [(0.6, 0.6, 0.25), (0.7, 0.56, 0.2), (0.76, 0.76, 0.12), (0.56, 0.72, 0.22)][frame]
            prims += [box(-0.6, 0.46, -1.05, 0.6, 0.56, -0.72, Mat("cfc5b0"), pattern=stains(9, 0.3)),
                      box(-0.88, 0.44, -0.6, 0.88, 0.6, 1.12, blanket, pattern=stains(10, 0.3)),
                      ell(-0.38, ly, lz, 0.34, 0.17 + 0.04 * (frame == 2), 0.6, blanket),
                      ell(0.4, ry_, lz - 0.05, 0.34, 0.16 + 0.04 * (frame == 2), 0.56, blanket),
                      ell(-0.4, 0.66, -0.86, 0.15, 0.12, 0.14, Mat("3a2a22")), ell(0.42, 0.66, -0.88, 0.15, 0.12, 0.14, Mat("e2b25a"))]
        else:
            prims += [box(-0.6, 0.46, -1.05, -0.05, 0.56, -0.72, Mat("cfc5b0"), pattern=stains(9, 0.3)).transformed(rot_y(22), (-0.3, 0.46, -0.9)),
                      box(-0.85, 0.46, 0.55, 0.7, 0.6, 1.12, blanket, pattern=stains(10, 0.3)),
                      box(0.86, 0.1, 0.1, 1.0, 0.56, 1.05, blanket)]
        return Item(polish_bed(prims,used=True), (2.0, 2.4))
    # ---------------------------------------------------- shower, dance floor
    if kind == "shower" or kind.startswith("shower_f"):
        # shower_f<n>: the glass door swinging open on its left hinge (0 shut .. 3 open)
        door_frame = int(kind[-1]) if kind.startswith("shower_f") else 0
        tiles = Mat("dfe6ea")

        def tile_grid(p, ln, w, n):
            d = np.zeros(len(p), dtype=int)
            u = p[:, 0] + p[:, 2]
            d[near(np.mod(u, 0.25), [0.0], 1 / 40) | near(np.mod(p[:, 1], 0.25), [0.0], 1 / 50)] = -1
            return d

        def frosted(p, ln, w, n):
            d = np.zeros(len(p), dtype=int)
            u = p[:, 0] - p[:, 2]
            d[near(np.mod(u + p[:, 1] * 0.3, 0.42), [0.0, 0.05], 1 / 36)] = 1
            d[p[:, 1] < 0.35] = -1
            return d
        frost = Mat("bcd8e6")
        # every wall is its own sort part: turned around, a tiled wall can stand
        # between the viewer and whoever is inside
        prims = [box(-0.44, 0.0, -0.44, 0.44, 0.1, 0.44, m["ceramic"])]
        prims += tag("tiles_a", box(-0.45, 0.1, -0.45, 0.45, 2.05, -0.41, tiles, pattern=tile_grid),
                     rod((-0.37, 0.9, -0.37), (-0.37, 1.85, -0.37), 0.02, m["chrome"]),
                     rod((-0.37, 1.85, -0.37), (-0.2, 1.85, -0.2), 0.02, m["chrome"]),
                     cyl(-0.18, 1.8, -0.18, 0.09, 0.04, m["chrome"]))
        prims += tag("tiles_b", box(-0.45, 0.1, -0.45, -0.41, 2.05, 0.45, tiles, pattern=tile_grid))
        prims += tag("side", box(0.4, 0.1, -0.41, 0.44, 1.95, 0.44, frost, pattern=frosted),
                     box(0.4, 1.95, -0.45, 0.45, 2.0, 0.45, m["chrome"]))
        prims += tag("rail", box(-0.45, 1.95, 0.4, 0.45, 2.0, 0.45, m["chrome"]))
        # the door panel, its handle and the towel over it turn on the hinge together
        # facing right (rot 3) the hinge goes on the other side, so the open
        # door never hides the way in
        side = -1 if r == 3 else 1
        hinge = (-0.41 * side, 0.0, 0.42)
        swing = rot_y(-side * [0, 32, 62, 88][door_frame])
        door = [box(-0.41, 0.1, 0.4, 0.4, 1.94, 0.44, frost, pattern=frosted),
                rod((0.3 * side, 0.9, 0.45), (0.3 * side, 1.3, 0.45), 0.015, m["chrome"]),
                box(-0.1, 1.62, 0.44, 0.12, 1.93, 0.47, m["rose"])]
        prims += tag("door", *[p.transformed(swing, hinge) for p in door])
        return Item(prims, (0.9, 0.9), split="separate")
    if kind.startswith("dancefloor"):
        # dancefloor_s<scheme>_f<frame>: tiles light up in turn, a neon rim chases around
        scheme, frame = 0, 0
        if "_s" in kind:
            scheme = int(kind.split("_s")[1].split("_")[0])
            frame = int(kind.split("_f")[1])
        cols = [hexrgb(c) for c in DANCE_SCHEMES[scheme][1]]

        def disco(p, ln, w, n):
            d = np.zeros(len(p), dtype=int)
            paint = np.zeros((len(p), 4), dtype=np.uint8)
            top = ln[:, 1] > 0.5
            gx = np.floor((p[:, 0] + 1.5) / 0.5).astype(int)
            gz = np.floor((p[:, 2] + 1.5) / 0.5).astype(int)
            fx = np.mod(p[:, 0] + 1.5, 0.5)
            fz = np.mod(p[:, 2] + 1.5, 0.5)
            grout = (fx < 0.05) | (fz < 0.05)
            lit = np.mod(gx + gz + frame, 3) == 0
            for k, col in enumerate(cols):
                sel = top & ~grout & (np.mod(gx * 3 + gz * 2 + gx * gz + frame, 4) == k)
                c = np.array(col, dtype=int)
                paint[sel & lit] = np.append(np.minimum(c + 50, 255), 255).astype(np.uint8)
                paint[sel & ~lit] = np.append((c * 0.62).astype(int), 255).astype(np.uint8)
                spot = sel & lit & (np.abs(fx - 0.27) < 0.09) & (np.abs(fz - 0.27) < 0.09)
                paint[spot] = (255, 250, 235, 255)
            paint[top & grout] = (30, 20, 40, 255)
            return d, paint

        def rim(p, ln, w, n):
            d = np.zeros(len(p), dtype=int)
            paint = np.zeros((len(p), 4), dtype=np.uint8)
            u = np.floor((p[:, 0] + p[:, 2] + 3.0) / 0.25).astype(int)
            on = np.mod(u + frame, 2) == 0
            c = np.array(cols[frame % 4], dtype=int)
            paint[on] = np.append(np.minimum(c + 60, 255), 255).astype(np.uint8)
            paint[~on] = np.append((c * 0.45).astype(int), 255).astype(np.uint8)
            return d, paint
        neon = Mat(DANCE_SCHEMES[scheme][1][0], emissive=True, line=False)
        prims = [box(-1.5, 0.0, -1.5, 1.5, 0.04, 1.5, Mat("2a2032"), pattern=disco),
                 box(-1.5, 0.0, -1.5, 1.5, 0.06, -1.44, neon, pattern=rim), box(-1.5, 0.0, 1.44, 1.5, 0.06, 1.5, neon, pattern=rim),
                 box(-1.5, 0.0, -1.5, -1.44, 0.06, 1.5, neon, pattern=rim), box(1.44, 0.0, -1.5, 1.5, 0.06, 1.5, neon, pattern=rim)]
        return Item(prims, (3.0, 3.0), shadow=False, flat=True,
                    lights=[dict(p=(0, 0.1, 0), color=DANCE_SCHEMES[scheme][1][frame % 4], radius=2.6, power=0.9)])
    # ---------------------------------------------------- small plants
    if kind in ("fern", "aloe", "palm_small", "strelitzia", "monstera", "cactus") or kind.startswith("palm_lights"):
        white = kind in ("monstera", "strelitzia", "palm_lights") or kind.startswith("palm_lights")
        pot_mat = m["ceramic"] if white else m["terracotta"]
        r = 0.2 if kind in ("fern", "aloe", "cactus") else 0.25
        h = 0.28 if kind in ("fern", "aloe", "cactus") else 0.36
        prims = lathe(0, 0, 0, [(0, r * 0.75), (0.03, r * 0.82), (h - 0.04, r), (h, r + 0.02)], pot_mat)
        prims += [cyl(0, h - 0.03, 0, r * 0.92, 0.02, m["soil"])]
        size = (0.5, 0.5) if r < 0.22 else (0.6, 0.6)
        if kind == "cactus":
            ribs = lambda p, ln, w, n: np.where(np.mod(np.arctan2(p[:, 2], p[:, 0]) * 3.0, 1.0) < 0.2, -1, 0)
            green = Mat("4f8a3a")
            prims += [cyl(0, h, 0, 0.09, 0.42, green, pattern=ribs), ell(0, h + 0.42, 0, 0.09, 0.06, 0.09, green),
                      cyl(0.12, h + 0.16, 0, 0.05, 0.16, green, pattern=ribs), rod((0.02, h + 0.14, 0), (0.12, h + 0.16, 0), 0.045, green),
                      ell(0.12, h + 0.32, 0, 0.05, 0.04, 0.05, green),
                      cyl(-0.11, h + 0.24, 0.02, 0.045, 0.12, green, pattern=ribs), rod((-0.02, h + 0.22, 0.01), (-0.11, h + 0.24, 0.02), 0.04, green),
                      ell(0.0, h + 0.48, 0.0, 0.05, 0.035, 0.05, Mat("ff5fa0")), ell(0.12, h + 0.36, 0.0, 0.035, 0.025, 0.035, Mat("ffd050"))]
            return Item(prims, size)
        top = (0.0, h, 0.02)
        if kind == "fern":
            return Item(prims, size, bills=[(top, palm(seed=11, fronds=9, green="5aa84a", reach=0.5))])
        if kind == "aloe":
            return Item(prims, size, bills=[(top, palm(seed=13, fronds=8, green="6aa88a", reach=0.42))])
        if kind == "monstera":
            return Item(prims, size, bills=[(top, monstera(seed=3))])
        if kind == "strelitzia":
            leaves = palm(seed=17, fronds=7, green="3f8a4a", reach=0.85)
            return Item(prims, size, bills=[(top, strelitzia_flowers(leaves, [(-4, -14), (5, -17)]))])
        prims += [rod((0, h, 0), (0.02, h + 0.55, 0), 0.05, m["trunk"]), rod((0.02, h + 0.55, 0), (-0.01, h + 0.78, 0.01), 0.045, m["trunk"])]
        crown = palm(seed=7, fronds=8, reach=0.75)
        if kind.startswith("palm_lights"):
            frame = int(kind[-1]) if kind[-1].isdigit() else 0
            crown = fairy_lights(crown, frame, seed=5, count=22)

            def string_lights(cv, T):
                # a string of bulbs wound around the trunk
                for k in range(7):
                    y = h + 0.1 + k * 0.1
                    a = k * 2.3 + frame
                    lit = (k + frame) % 3 != 0
                    col = [(255, 226, 140, 255), (255, 140, 210, 255), (140, 216, 255, 255)][(k + frame) % 3] if lit else (90, 70, 60, 255)
                    dot(cv, T((0.06 * math.cos(a), y, 0.06 * math.sin(a) + 0.02)), col, bias=0.3)
            return Item(prims, size, bills=[((0.0, h + 0.8, 0.02), crown)], decals=string_lights,
                        lights=[dict(p=(0, h + 0.8, 0), color="ffcf8a", radius=1.4, power=0.8)])
        return Item(prims, size, bills=[((0.0, h + 0.8, 0.02), crown)])
    # ---------------------------------------------------- debris cleaned by technicians
    if kind == "clothes_pile":
        # jeans, a shirt, a bra and a pair of red heels dropped by the bed
        prims = [box(-0.36, 0.0, -0.1, 0.1, 0.07, 0.2, Mat("3a5a9a")).transformed(rot_y(25), (-0.13, 0, 0.05)),
                 box(-0.3, 0.0, -0.08, -0.12, 0.05, 0.3, Mat("3a5a9a")).transformed(rot_y(-10), (-0.2, 0, 0.1)),
                 box(0.02, 0.0, -0.28, 0.34, 0.05, 0.02, Mat("efebe4")).transformed(rot_y(-30), (0.18, 0, -0.13)),
                 ell(0.14, 0.03, 0.2, 0.07, 0.04, 0.06, Mat("e8508c")), ell(0.28, 0.03, 0.18, 0.07, 0.04, 0.06, Mat("e8508c")),
                 rod((0.2, 0.03, 0.2), (0.22, 0.03, 0.19), 0.015, Mat("e8508c")),
                 box(0.26, 0.0, 0.28, 0.4, 0.06, 0.33, Mat("c42a40")), box(0.3, 0.0, 0.36, 0.44, 0.06, 0.41, Mat("c42a40"))]
        prims = [q.transformed(np.diag([1.6, 1.6, 1.6])) for q in prims]
        return Item(prims, (1.4, 1.3), shadow=False)
    if kind == "trash_tissues":
        prims = [box(-0.22, 0.0, -0.08, 0.12, 0.035, 0.14, m["rose"]).transformed(rot_y(20), (-0.05, 0, 0.03))]
        rng = np.random.default_rng(17)
        for i in range(7):
            x, z = rng.uniform(-0.24, 0.24), rng.uniform(-0.22, 0.22)
            r = rng.uniform(0.05, 0.08)
            prims.append(ell(x, r * 0.6, z, r, r * 0.7, r, Mat("f2eee8")))
        return Item(prims, (0.6, 0.6), shadow=False)

    if kind == "trash_rubble":
        chunks = []
        rng = np.random.default_rng(9)
        for i in range(9):
            x, z = rng.uniform(-0.3, 0.3), rng.uniform(-0.25, 0.25)
            s_ = rng.uniform(0.05, 0.11)
            chunks.append(box(x - s_, 0.0, z - s_ * 0.8, x + s_, s_ * 0.7, z + s_ * 0.8, Mat("cfc2a8" if i % 3 else "b9a98e")).transformed(rot_y(rng.uniform(0, 90)), (x, 0, z)))
        chunks.append(box(-0.34, 0.0, -0.3, 0.34, 0.012, 0.3, Mat("dcd2bc")))
        return Item(chunks, (0.8, 0.7), shadow=False)
    if kind == "trash_papers":
        paper = Mat("e6e0d2")
        prims = []
        rng = np.random.default_rng(3)
        for i in range(10):
            x, z = rng.uniform(-0.28, 0.28), rng.uniform(-0.28, 0.28)
            sheet = box(x - 0.13, 0.0, z - 0.09, x + 0.13, 0.012, z + 0.09, paper if i % 3 else Mat("c9d3dc"))
            prims.append(sheet.transformed(rot_y(rng.uniform(0, 180)), (x, 0, z)))
        for i in range(4):
            prims.append(ell(rng.uniform(-0.28, 0.28), 0.06, rng.uniform(-0.28, 0.28), 0.08, 0.06, 0.08, paper))
        return Item(prims, (0.8, 0.8), shadow=False)
    if kind == "trash_bottles":
        prims = [rod((-0.28, 0.055, -0.12), (0.08, 0.055, 0.06), 0.055, m["bottle_g"]), rod((0.08, 0.055, 0.06), (0.17, 0.055, 0.1), 0.024, m["bottle_g"]),
                 rod((0.08, 0.05, -0.24), (0.27, 0.05, 0.06), 0.05, m["bottle_a"])]
        prims += bottle(-0.12, 0.0, 0.18, m["bottle_g"], 0.34, 0.06) + bottle(0.2, 0.0, 0.22, m["bottle_c"], 0.3, 0.055)
        return Item(prims, (0.7, 0.7), shadow=False)
    if kind == "trash_planks":
        prims = [box(-0.6, 0.0, -0.06, 0.6, 0.05, 0.06, Mat("8c6a48"), pattern=stains(20, 0.3)).transformed(rot_y(18)),
                 box(-0.5, 0.05, -0.05, 0.45, 0.1, 0.05, Mat("7a5a3c")).transformed(rot_y(-35)),
                 box(-0.2, 0.0, -0.05, 0.25, 0.04, 0.05, Mat("9a7652")).transformed(rot_y(80), (0.2, 0, 0.2))]
        return Item(prims, (1.4, 0.8), shadow=False)
    if kind == "trash_bags":
        bag = Mat("25232c")
        prims = [ell(-0.12, 0.2, 0.0, 0.24, 0.22, 0.22, bag, ylim=(-0.9, 1.0)), ell(0.2, 0.15, 0.1, 0.18, 0.16, 0.17, bag, ylim=(-0.9, 1.0)),
                 ell(-0.12, 0.44, 0.0, 0.05, 0.06, 0.05, bag), ell(0.2, 0.33, 0.1, 0.04, 0.05, 0.04, bag)]
        return Item(prims, (0.8, 0.7))
    if kind == "trash_cardboard":
        prims = [box(-0.32, 0.0, -0.25, 0.28, 0.02, 0.2, m["cardboard"], pattern=stains(21, 0.3)).transformed(rot_y(12)),
                 box(-0.1, 0.02, -0.15, 0.3, 0.03, 0.28, Mat("b98244")).transformed(rot_y(-20)),
                 box(-0.25, 0.0, 0.05, 0.05, 0.22, 0.32, m["cardboard"], pattern=tape()).transformed(rot_z(-12), (-0.1, 0, 0.18))]
        return Item(prims, (0.9, 0.9), shadow=False)
    raise KeyError(kind)


def screen_face(color):
    def pat(p, ln, w, n):
        paint = np.zeros((len(p), 4), dtype=np.uint8)
        f = _front(ln)
        inner = f & (np.abs(p[:, 0]) < 0.26) & (np.abs(p[:, 1]) < 0.13)
        paint[inner] = color + (255,)
        rows = inner & (np.mod(p[:, 1] * 24, 2.2) < 0.6) & (p[:, 0] < 0.1)
        paint[rows] = (200, 230, 255, 255)
        return np.zeros(len(p), dtype=int), paint
    return pat


def back_screen():
    def pat(p, ln, w, n):
        d = np.zeros(len(p), dtype=int)
        paint = np.zeros((len(p), 4), dtype=np.uint8)
        back = ln[:, 2] < -0.5
        inner = back & (np.abs(p[:, 0]) < 0.14) & (np.abs(p[:, 1]) < 0.12)
        paint[inner] = (90, 170, 235, 255)
        return d, paint
    return pat


# ------------------------------------------------------------------ baking

ROT_DEG = {0: 0, 1: -90, 2: -180, 3: -270}


def rotation(r):
    """Rotation used by the game: rot 1 faces -x, rot 3 faces +x."""
    return rot_y(-90 * r)


def bake(kind, r):
    it = item(kind, r)
    R = rotation(r)
    prims = turn(it.prims, R)

    def T(p):
        return tuple(R @ np.array(p, dtype=float))
    sx, sz = it.size
    if r % 2:
        sx, sz = sz, sx
    shadow = [(-sx / 2 + 0.02, -sz / 2 + 0.02, sx / 2 - 0.02, sz / 2 - 0.02)] if it.shadow else None
    bounds = [(-sx / 2, 0, -sz / 2), (sx / 2, 0, sz / 2), (-sx / 2, 0, sz / 2), (sx / 2, 0, -sz / 2)]
    bounds += [T(p) for p in it.extent]
    for (anchor, pix) in it.bills:
        a = np.array(anchor)
        bounds += [T((a[0] - 1.1, a[1] + 1.0, a[2])), T((a[0] + 1.1, a[1] - 0.6, a[2]))]
    cv = render(prims, bounds=bounds, shadow=shadow, shadow_alpha=64)
    finish(cv)
    if it.decals:
        it.decals(cv, T)
    for (anchor, pix) in it.bills:
        a = T(anchor)
        ax, ay = screen(a)
        h, w, _ = pix.img.shape
        for yy in range(h):
            for xx in range(w):
                c = pix.img[yy, xx]
                if c[3] == 0:
                    continue
                X = int(round(ax)) + xx - pix.ox + cv.ox
                Y = int(round(ay)) + yy - pix.oy + cv.oy
                if 0 <= X < cv.w and 0 <= Y < cv.h:
                    cv.rgba[Y, X] = c
    lights = []
    for L in it.lights:
        p = T(L["p"])
        sxp, syp = screen(p)
        lights.append({"x": round(sxp, 1), "y": round(syp, 1), "color": L["color"], "radius": L["radius"],
                       "power": L.get("power", 1.0), "wall": L.get("wall", False)})
    return cv, lights, it


KINDS = ["bar", "backbar", "stool", "table", "coffee", "chair", "sofa", "armchair", "dance", "plant", "plant_big", "sconce", "neon",
         "bed", "nightstand", "lamp", "mirror", "toilet", "urinal", "sink", "bin", "shelf", "crate", "fridge", "locker",
         "desk", "reception", "coat_rack", "cloak_locker", "rope", "rug", "frame", "cabinet", "pink", "red", "purple",
         "old_sofa", "old_bed", "old_lamp", "old_table", "old_locker", "old_fridge", "old_shelf", "pillar", "poster", "boards",
         "old_toilet", "old_sink", "old_armchair", "old_rug", "old_wardrobe",
         "trash_papers", "trash_bottles", "trash_planks", "trash_bags", "trash_cardboard", "trash_rubble",
         "trash_tissues", "shower", "dancefloor", "bed_busy", "bed_unmade", "old_bed_busy", "old_bed_unmade",
         "bed_busy_1", "bed_busy_2", "bed_busy_3", "old_bed_busy_1", "old_bed_busy_2", "old_bed_busy_3", "clothes_pile",
         "fern", "cactus", "aloe", "monstera", "strelitzia", "palm_small", "palm_lights", "palm_lights_f1", "palm_lights_f2",
         "shower_f1", "shower_f2", "shower_f3"]
KINDS += [f"{k}_s{s}_f{f}" for k in ("dancefloor", "dance") for s in range(len(DANCE_SCHEMES)) for f in range(4)]
KINDS += ["heart_bed", "heart_bed_unmade", "heart_bed_busy", "heart_bed_busy_1", "heart_bed_busy_2", "heart_bed_busy_3"]


def part_names(prims):
    names = ["base"]
    for p in prims:
        n = getattr(p, "part", None)
        if n and n not in names:
            names.append(n)
    return names


def part_rect(prims, name, footprint):
    """Floor rectangle (x0, z0, x1, z1) of a part, already turned: the base
    keeps the whole footprint (people sit or stand on it)."""
    if name == "base":
        return footprint
    pts = [c for p in prims if getattr(p, "part", None) == name for c in p.corners()]
    xs = [q[0] for q in pts]
    zs = [q[2] for q in pts]
    return tuple(round(float(v), 3) for v in (min(xs), min(zs), max(xs), max(zs)))


def split_parts(kind, r, cv, it):
    """Cuts an item into sort parts so the game can slip a character between
    them: sitting on a sofa means in front of the seat, and in front of or
    behind the backrest depending on where the sofa faces. "pixels" gives each
    pixel of the finished picture to the part it shows; "separate" renders
    each part alone (the shower door moves, so the tiles behind it must exist)."""
    names = part_names(cv.prims)
    if len(names) < 2:
        return []
    sx, sz = it.size
    if r % 2:
        sx, sz = sz, sx
    footprint = tuple(round(float(v), 3) for v in (-sx / 2, -sz / 2, sx / 2, sz / 2))
    out = []
    if it.split == "separate":
        R = rotation(r)
        prims = turn(it.prims, R)
        for k, name in enumerate(names):
            sub = [p for p in prims if (getattr(p, "part", None) or "base") == name]
            shadow = [(footprint[0] + 0.02, footprint[1] + 0.02, footprint[2] - 0.02, footprint[3] - 0.02)] if name == "base" and it.shadow else None
            pc = render(sub, shadow=shadow, shadow_alpha=64)
            finish(pc)
            path = f"furniture/{kind}_{r}_{name}.png"
            save(pc.rgba, path)
            out.append({"name": name, "file": path, "ox": pc.ox, "oy": pc.oy, "w": pc.w, "h": pc.h,
                        "rect": part_rect(prims, name, footprint)})
        return out
    H, W = cv.h, cv.w
    owner_of = np.array([names.index(getattr(p, "part", None) or "base") for p in cv.prims] + [0])
    pid = cv.pid
    owner = np.where(pid >= 0, owner_of[np.where(pid >= 0, pid, -1)], -1)
    # outline pixels belong to the part they outline (the nearest one in front)
    best_t = np.full((H, W), -1e9)
    for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0)):
        ys = slice(max(dy, 0), H + min(dy, 0))
        yd = slice(max(-dy, 0), H + min(-dy, 0))
        xs = slice(max(dx, 0), W + min(dx, 0))
        xd = slice(max(-dx, 0), W + min(-dx, 0))
        npid = np.full((H, W), -1)
        nt = np.full((H, W), -1e9)
        npid[yd, xd] = pid[ys, xs]
        nt[yd, xd] = cv.t[ys, xs]
        upd = (owner < 0) & (npid >= 0) & (nt > best_t)
        owner[upd] = owner_of[npid[upd]]
        best_t[upd] = nt[upd]
    # anything else drawn (floor shadow, decals) goes with the base
    owner[(owner < 0) & (cv.rgba[..., 3] > 0)] = 0
    for k, name in enumerate(names):
        img = cv.rgba.copy()
        img[owner != k] = 0
        # cropped to its own pixels: the game orders parts by where they really show
        ys, xs = np.nonzero(img[..., 3])
        x0, y0 = (int(xs.min()), int(ys.min())) if len(xs) else (0, 0)
        x1, y1 = (int(xs.max()) + 1, int(ys.max()) + 1) if len(xs) else (1, 1)
        img = img[y0:y1, x0:x1]
        path = f"furniture/{kind}_{r}_{name}.png"
        save(img, path)
        out.append({"name": name, "file": path, "ox": cv.ox - x0, "oy": cv.oy - y0, "w": x1 - x0, "h": y1 - y0,
                    "rect": part_rect(cv.prims, name, footprint)})
    return out


def export(kinds=None, previews=None):
    manifest = {}
    for kind in kinds or KINDS:
        entry = {}
        for r in range(4):
            cv, lights, it = bake(kind, r)
            path = f"furniture/{kind}_{r}.png"
            save(cv.rgba, path)
            entry[str(r)] = {"file": path, "ox": cv.ox, "oy": cv.oy, "w": cv.w, "h": cv.h, "lights": lights}
            parts = split_parts(kind, r, cv, it)
            if parts:
                entry[str(r)]["parts"] = parts
                entry[str(r)]["split"] = it.split
            if previews:
                preview(cv.rgba, f"{previews}/{kind}_{r}.png", 4)
        entry["flat"] = it.flat
        manifest[kind] = entry
    return manifest


if __name__ == "__main__":
    import sys
    kinds = sys.argv[1:] or None
    man = export(kinds, previews="../../tests/artifacts/pixel/furn")
    if kinds is None:
        write_json("furniture.json", man)
