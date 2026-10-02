"""Characters painted directly on a 32 x 48 px frame.

Bodies come from a tiny skeleton whose joints are expressed in *pixels* of
the final frame; limbs, torso and head are filled pixel by pixel (tapered
limbs, row-profiled torso, row-profiled head). Faces, glasses and headwear
are hand-drawn pixel layouts. Clothing is a rule deciding, for each body
pixel, which palette role it takes. Sheets store palette *indices*
(R = index * 4) so the game recolours skin, hair and outfits at runtime.
"""
from __future__ import annotations

import math
from dataclasses import dataclass, field

import numpy as np

from pa_core import ramp, hexrgb

FW, FH = 32, 48
IDX_SCALE = 4

# ------------------------------------------------------------ palette roles
ROLES = {
    "clear": 0, "ink": 1,
    "skin": [2, 3, 4, 5], "hair": [6, 7, 8, 9],
    "g1": [10, 11, 12, 13], "g2": [14, 15, 16, 17], "g3": [18, 19, 20, 21],
    "eye_white": 22, "iris": 23, "lips": 24, "blush": 25,
    "shoe": [26, 27, 28, 28], "metal": [29, 29, 30, 30], "shine": 31,
    "prop": [32, 33, 34, 35], "wood": [36, 36, 37, 37], "lens": [38, 38, 39, 39],
}
HI, MID, SH, DEEP = 0, 1, 2, 3
PALETTE_SIZE = 40


def ri(role: str, tone: int = MID) -> int:
    v = ROLES[role]
    if isinstance(v, list):
        return v[max(0, min(tone, len(v) - 1))]
    return v


YY, XX = np.mgrid[0:FH, 0:FW]
PY = YY + 0.5
PX = XX + 0.5
N4 = ((0, 1), (0, -1), (1, 0), (-1, 0))


def capsule(a, b, ra, rb):
    ax, ay = a
    bx, by = b
    dx, dy = bx - ax, by - ay
    ll = dx * dx + dy * dy
    u = np.clip(((PX - ax) * dx + (PY - ay) * dy) / max(ll, 1e-9), 0, 1)
    cx = ax + u * dx
    cy = ay + u * dy
    r = ra + (rb - ra) * u
    dist = np.hypot(PX - cx, PY - cy)
    mask = dist <= r + 0.03
    # lateral offset: > 0 on the screen-right edge of the limb
    nx = PX - cx
    side = nx / np.maximum(r, 0.6)
    return mask, u, side


@dataclass
class Part:
    kind: str
    mask: np.ndarray
    order: float
    shade: np.ndarray
    t: np.ndarray
    side: str = ""
    rel: np.ndarray = None


def shade_from_side(side, lit=-0.45, dark=0.30):
    shade = np.ones((FH, FW), dtype=int)
    shade[side > dark] = SH
    shade[side < lit] = HI
    return shade


def limb(kind, a, b, ra, rb, order, side_name=""):
    m, u, s = capsule(a, b, ra, rb)
    return Part(kind, m, order, shade_from_side(s), u, side_name)


def blob(kind, cx, cy, rx, ry, order, side_name=""):
    d = ((PX - cx) / rx) ** 2 + ((PY - cy) / ry) ** 2
    m = d <= 1.0
    s = (PX - cx) / rx
    return Part(kind, m, order, shade_from_side(s, -0.5, 0.3), np.zeros((FH, FW)), side_name)


def rows_part(kind, rows, order, dx=0, dy=0):
    m = np.zeros((FH, FW), dtype=bool)
    shade = np.ones((FH, FW), dtype=int)
    rel = np.zeros((FH, FW))
    for y, (a, b) in rows.items():
        y += dy
        if not 0 <= y < FH:
            continue
        a += dx
        b += dx
        cols = np.arange(FW)
        row = (cols >= a) & (cols <= b)
        m[y] = row
        c = (a + b) / 2.0
        w = max((b - a) / 2.0, 0.5)
        nx = (cols - c) / w
        rel[y] = nx
        s = np.full(FW, MID)
        s[nx >= 0.55] = SH
        s[nx <= -0.75] = HI
        shade[y] = np.where(row, s, shade[y])
    return Part(kind, m, order, shade, np.zeros((FH, FW)), "", rel)


# ------------------------------------------------------------ body plans
# Heights: the head keeps its 16 rows while torso and legs are a little
# shorter than before (40-41 px tall figures), for a cute, caricatural look.
# Legs are drawn row by row with a fixed width profile, so every frame keeps
# exactly the same leg thickness and outline (no seams while walking).

PLANS = {
    "f": {
        "head": (9, 6),
        "torso": {22: (13, 19), 23: (11, 21), 24: (11, 21), 25: (11, 21), 26: (12, 20), 27: (13, 19),
                  28: (13, 19), 29: (12, 20), 30: (11, 21), 31: (11, 21), 32: (12, 20)},
        "neck": ((16.5, 20.6), (16.5, 23.0), 1.55, 1.6),
        "hip_y": 31.0, "hips": (14.5, 18.5), "ankles": (15.0, 18.0),
        "thigh_w": ((0.4, 5), (0.75, 4), (9, 3)), "shin_w": ((0.7, 3), (9, 2)),
        "knee_y": 37.4, "ankle_y": 43.6,
        "thigh": (2.55, 1.7), "calf": (1.8, 0.95),
        "shoulder": (11.9, 20.7, 23.7), "upper": (1.3, 1.1), "fore": (1.05, 0.85),
        "elbow_dy": 5.4, "wrist_dy": 10.2, "hand": (1.15, 1.45),
        "foot": (1.05, 0.95), "heels": True,
        "rows": {"strap": (0, 1), "bust": (2, 3), "hip": 8, "brief": (9, 10), "apron": 5, "skirt": 8},
    },
    "m": {
        "head": (9, 5),
        "torso": {21: (12, 20), 22: (10, 22), 23: (10, 22), 24: (10, 22), 25: (11, 21), 26: (11, 21),
                  27: (12, 20), 28: (12, 20), 29: (12, 20), 30: (12, 20), 31: (13, 19)},
        "neck": ((16.5, 19.6), (16.5, 22.0), 2.0, 2.1),
        "hip_y": 30.0, "hips": (14.5, 18.5), "ankles": (14.8, 18.2),
        "thigh_w": ((0.5, 5), (9, 4)), "shin_w": ((0.6, 4), (9, 3)),
        "knee_y": 36.9, "ankle_y": 43.6,
        "thigh": (2.65, 2.0), "calf": (2.0, 1.25),
        "shoulder": (11.0, 22.0, 22.8), "upper": (1.65, 1.4), "fore": (1.4, 1.1),
        "elbow_dy": 5.8, "wrist_dy": 10.8, "hand": (1.4, 1.55),
        "foot": (1.4, 1.3), "heels": False,
        "rows": {"chest": (1, 4), "belt": 8, "badge": 3, "pocket": (5, 6)},
    },
}

# The escorts' torso: silhouette and hand-placed shading (tone digits 0 light
# .. 3 deep) over columns x = 9..25, 11 rows from the shoulders, for three
# body shapes. "galbee": generous bust with cleavage, narrow waist, round
# hips. "genereuse": a very large, caricatural bust (two pixels wider each
# side, one row lower, deep cleavage). "fine": small bust, slimmer hips. From behind all
# three show shoulder blades, spine and hips.
CURVY_X0 = 9
BACK = [
    "....0111112......",
    "..01111111112....",
    "..01011210112....",
    "..01111211112....",
    "...011121112.....",
    "....0112112......",
    "....0112112......",
    "...011111112.....",
    "..01110211112....",
    "..011103111122...",
    "...1112311122....",
]
CURVY_SIL = {
    "galbee": {
        "front": [
            "....0111112......",
            "..01111111112....",
            "..110012100112...",
            "..1110131101112..",
            "..222123222222...",
            "....1222222......",
            "....0111112......",
            "...011111122.....",
            "..01111111122....",
            ".011111111122....",
            "..1111111122.....",
        ],
        "back": BACK,
    },
    "genereuse": {
        "front": [
            "....0111112......",
            "..0111111111112..",
            ".100001221000012.",
            "11001112311001112",
            "21111112311111112",
            ".222222333222222.",
            "....1222222......",
            "...011111122.....",
            "..01111111122....",
            ".011111111122....",
            "..1111111122.....",
        ],
        "back": BACK,
    },
    "fine": {
        "front": [
            "....0111112......",
            "..01111111112....",
            "..01101210112....",
            "..111112111122...",
            "...122222222.....",
            "....1111112......",
            "....0111112......",
            "...011111122.....",
            "..01111111122....",
            "..0111111122.....",
            "..1111111122.....",
        ],
        "back": BACK,
    },
}
SILHOUETTES = ["galbee", "genereuse", "fine"]
CURVY = CURVY_SIL["galbee"]


def plan_of(male):
    return PLANS["m" if male else "f"]


# ------------------------------------------------------------ poses
# New animations go at the end of each list: "push" walks behind a
# wheelbarrow; mop and work also exist from behind (facing a wall).
ANIMS_FRONT = [("idle", 2), ("walk", 4), ("sit", 1), ("dance", 4), ("mop", 4), ("work", 2), ("stand", 1), ("kneel", 6), ("push", 4)]
ANIMS_BACK = [("idle", 2), ("walk", 4), ("sit", 1), ("stand", 1), ("kneel", 6), ("mop", 4), ("work", 2), ("push", 4)]


def frame_list():
    out = []
    for view, anims in (("front", ANIMS_FRONT), ("back", ANIMS_BACK)):
        for anim, n in anims:
            for f in range(n):
                out.append((view, anim, f))
    return out


FRAMES = frame_list()


def pose(anim, f, view):
    """Joint offsets for one frame. Feet offsets are whole pixels (dx, dy)
    in the front view; the back view mirrors them."""
    p = dict(bob=0, sway=0, feet={"near": (0, 0), "far": (0, 0)}, knee={"near": 0, "far": 0},
             hand_n=(0, 0), hand_f=(0, 0), elbow_n=(0, 0), elbow_f=(0, 0), sit=False, drop=0, prop=None, lean=0)
    if anim == "idle":
        p["bob"] = 1 if f == 1 else 0
    elif anim == "walk":
        # contact (near forward) / passing (far swings) / contact (far forward) / passing (near swings)
        fwd, back, lift = (1, 1), (0, -1), (0, -2)
        p["feet"] = [{"near": fwd, "far": back}, {"near": (0, 0), "far": lift},
                     {"near": back, "far": fwd}, {"near": lift, "far": (0, 0)}][f]
        p["knee"] = [{"near": 0, "far": 0}, {"near": 0, "far": 1}, {"near": 0, "far": 0}, {"near": 1, "far": 0}][f]
        p["bob"] = -1 if f in (1, 3) else 0
        sw = [2, 0, -2, 0][f]
        p["hand_n"] = (-sw, 0)
        p["hand_f"] = (sw, 0)
        p["elbow_n"] = (-sw // 2, 0)
        p["elbow_f"] = (sw // 2, 0)
    elif anim == "sit":
        p["sit"] = True
        p["drop"] = 4
    elif anim == "kneel":
        # Neutral resting breath: the head, neck and torso rise together by one
        # native pixel. Folded shins and feet remain planted on the floor.
        p["drop"] = 7
        p["bob"] = -1 if f in (2, 3) else 0
        p["hand_n"] = (0, 1 if f == 5 else 0)
    elif anim == "dance":
        p["sway"] = [-1, 0, 1, 0][f]
        p["bob"] = [0, -1, 0, -1][f]
        p["hand_n"] = [(-2.5, -15), (-1.5, -12), (-2.0, -16), (-1.0, -12)][f]
        p["elbow_n"] = [(-2.5, -8), (-2.5, -6), (-2.0, -9), (-2.5, -6)][f]
        p["hand_f"] = [(1.5, -12), (2.5, -16), (1.0, -12), (2.0, -15)][f]
        p["elbow_f"] = [(2.5, -6), (2.0, -9), (2.5, -6), (2.5, -8)][f]
        p["feet"] = [{"near": (0, 0), "far": (0, 0)}, {"near": (0, -2), "far": (0, 0)},
                     {"near": (0, 0), "far": (0, 0)}, {"near": (0, 0), "far": (0, -2)}][f]
        p["knee"] = [{"near": 0, "far": 0}, {"near": 1, "far": 0}, {"near": 0, "far": 0}, {"near": 0, "far": 1}][f]
    elif anim == "mop":
        p["lean"] = 1
        sw = [0, 1.5, 0, -1.5][f]
        p["hand_n"] = (4.0 + sw, -3.0)
        p["elbow_n"] = (1.5 + sw * 0.4, -1.0)
        p["hand_f"] = (1.5 + sw, -7.0)
        p["elbow_f"] = (1.0 + sw * 0.4, -3.5)
        p["prop"] = ("mop", sw)
    elif anim == "push":
        # walking legs, both hands forward low on the wheelbarrow handles
        fwd, back, lift = (1, 1), (0, -1), (0, -2)
        p["feet"] = [{"near": fwd, "far": back}, {"near": (0, 0), "far": lift},
                     {"near": back, "far": fwd}, {"near": lift, "far": (0, 0)}][f]
        p["knee"] = [{"near": 0, "far": 0}, {"near": 0, "far": 1}, {"near": 0, "far": 0}, {"near": 1, "far": 0}][f]
        p["bob"] = -1 if f in (1, 3) else 0
        p["hand_n"] = (4.5, -3.0)
        p["elbow_n"] = (2.0, -1.0)
        p["hand_f"] = (3.5, -3.5)
        p["elbow_f"] = (1.0, -1.5)
    elif anim == "work":
        p["hand_n"] = [(4.5, -6.0), (5.5, -5.0)][f]
        p["elbow_n"] = [(2.0, -3.0), (2.2, -2.5)][f]
        p["hand_f"] = [(3.0, -6.5), (2.5, -7.5)][f]
        p["elbow_f"] = [(1.0, -3.0), (1.0, -3.5)][f]
    return p


# ------------------------------------------------------------ body

class Figure:
    pass


def snap(p):
    """Put a joint on a pixel centre so shapes repeat exactly between frames."""
    return (math.floor(p[0]) + 0.5, math.floor(p[1]) + 0.5)


def width_at(profile, u):
    for limit, w in profile:
        if u < limit:
            return w
    return profile[-1][1]


def leg_parts(P, hip, knee, ankle, order, side, far):
    """A standing leg as horizontal spans: the centre follows hip -> knee ->
    ankle, the width only depends on the position along the leg."""
    parts = {}
    for kind in ("thigh", "shin"):
        parts[kind] = Part(kind, np.zeros((FH, FW), dtype=bool), order, np.ones((FH, FW), dtype=int),
                           np.zeros((FH, FW)), side, np.zeros((FH, FW)))
    y0 = int(math.floor(hip[1]))
    y1 = int(math.floor(ankle[1]))
    last = None
    for y in range(y0, y1 + 1):
        yc = y + 0.5
        if yc <= knee[1]:
            u = min(max((yc - hip[1]) / max(knee[1] - hip[1], 0.5), 0.0), 1.0)
            cx = hip[0] + u * (knee[0] - hip[0])
            w = width_at(P["thigh_w"], u)
            kind, t = "thigh", u
        else:
            v = min(max((yc - knee[1]) / max(ankle[1] - knee[1], 0.5), 0.0), 1.0)
            cx = knee[0] + v * (ankle[0] - knee[0])
            w = width_at(P["shin_w"], v)
            kind, t = "shin", v
        left = int(math.floor(cx - w / 2.0 + 0.5))
        part = parts[kind]
        for i in range(w):
            x = left + i
            if not 0 <= x < FW or not 0 <= y < FH:
                continue
            tone = MID
            if i == 0 and w >= 3:
                tone = HI
            elif i == w - 1:
                tone = SH
            if far:
                tone = min(tone + 1, SH)
            part.mask[y, x] = True
            part.shade[y, x] = tone
            part.t[y, x] = t
            part.rel[y, x] = (i - (w - 1) / 2.0) / max((w - 1) / 2.0, 0.5)
        last = (left, w, y)
    return [parts["thigh"], parts["shin"]], last


# Shoes drawn as small pixel stamps under the ankle: a = light, s = mid,
# S = shade, h = stiletto heel. (column offset from the ankle's left pixel)
FEET = {
    ("f", "front"): (-1, [".aa.", ".sss", ".h.S"]),
    ("f", "back"): (0, ["aa", "sS", "h."]),
    ("m", "front"): (0, ["aaa.", "ssss", "SSSS"]),
    ("m", "back"): (0, ["aaa", "sss", "SSS"]),
}
FOOT_TONES = {"a": HI, "s": MID, "S": SH, "h": SH}


def foot_part(male, view, last, order, side):
    off, rows = FEET[("m" if male else "f", view)]
    left, w, y = last
    m = np.zeros((FH, FW), dtype=bool)
    shade = np.ones((FH, FW), dtype=int)
    for dy, line in enumerate(rows):
        for dx, ch in enumerate(line):
            if ch == ".":
                continue
            X, Y = left + off + dx, y + 1 + dy
            if 0 <= X < FW and 0 <= Y < FH:
                m[Y, X] = True
                shade[Y, X] = FOOT_TONES[ch]
    return Part("foot", m, order + 0.2, shade, np.zeros((FH, FW)), side)


def template_part(rows, x0, top, order):
    m = np.zeros((FH, FW), dtype=bool)
    shade = np.ones((FH, FW), dtype=int)
    rel = np.zeros((FH, FW))
    for i, line in enumerate(rows):
        y = top + i
        cols = [x0 + k for k, ch in enumerate(line) if ch != "."]
        if not cols or not 0 <= y < FH:
            continue
        a, b = min(cols), max(cols)
        c = (a + b) / 2.0
        w = max((b - a) / 2.0, 0.5)
        for k, ch in enumerate(line):
            if ch == ".":
                continue
            x = x0 + k
            m[y, x] = True
            shade[y, x] = int(ch)
            rel[y, x] = (x - c) / w
    return Part("torso", m, order, shade, np.zeros((FH, FW)), "", rel)


def build(male: bool, view: str, anim: str, f: int, curvy: bool = False, silhouette: str = "galbee") -> Figure:
    P = plan_of(male)
    j = pose(anim, f, view)
    fig = Figure()
    fig.male, fig.view, fig.anim, fig.frame, fig.pose, fig.curvy = male, view, anim, f, j, curvy
    fig.silhouette = silhouette
    parts = []
    bob, sway, drop = j["bob"], j["sway"], j["drop"]
    up = bob + drop           # vertical offset of the upper body
    hip_y = P["hip_y"] + up
    front = view == "front"
    near_x, far_x = P["hips"]
    near_a, far_a = P["ankles"]
    if not front:
        near_x, far_x = far_x, near_x
        near_a, far_a = far_a, near_a
    mirror = 1 if front else -1
    for side, hx0, ax0, order in (("far", far_x, far_a, 2.0), ("near", near_x, near_a, 4.0)):
        hx = hx0 + sway
        if anim == "kneel":
            hip = snap((hx, hip_y))
            knee = snap((hx + 2 * mirror, 44.0))
            ankle = snap((hx - 4 * mirror, 44.0))
            t0, t1 = P["thigh"]
            c0, c1 = P["calf"]
            parts.append(limb("thigh", hip, knee, t0, t1, order, side))
            parts.append(limb("shin", knee, ankle, t1, c1, order - 0.1, side))
            parts.append(limb("foot", ankle, (ankle[0] - mirror, 45.5), c1, 0.8, order - 0.05, side))
            continue
        if j["sit"]:
            kx = hx + (4.6 if front else 3.2)
            knee = snap((kx, hip_y + 2.0))
            ankle = snap((kx + 0.4, P["ankle_y"]))
            hip = snap((hx, hip_y))
            t0, t1 = P["thigh"]
            c0, c1 = P["calf"]
            parts.append(limb("thigh", hip, knee, t0, t1, order, side))
            parts.append(limb("shin", knee, ankle, t1 * 0.95, c1, order + 0.1, side))
            fx, fy = ankle
            f0, f1 = P["foot"]
            if front:
                toe = (fx + (1.6 if P["heels"] else 2.0), fy + 2.2)
                parts.append(limb("foot", (fx, fy + 0.5), toe, f0, f1, order + 0.2, side))
                if P["heels"]:
                    parts.append(limb("heel", (fx - 0.3, fy + 1.2), (fx - 0.4, fy + 2.4), 0.55, 0.5, order + 0.19, side))
            else:
                parts.append(limb("foot", (fx, fy + 0.6), (fx - 0.2, fy + 2.0), f0, f1, order + 0.2, side))
            continue
        # Seen from behind, forward is up-left and the trailing foot comes
        # nearer the camera; a lifted foot (dy = -2) rises in both views.
        dx, dy = j["feet"][side]
        ankle = (ax0 + dx * mirror, P["ankle_y"] + (dy if front or dy == -2 else -dy))
        # Idle breathing moves only the upper body; walking lifts the hips.
        leg_hip = (hx, P["hip_y"] + min(up, 0))
        bend = j["knee"][side]
        kt = (P["knee_y"] - P["hip_y"]) / (P["ankle_y"] - P["hip_y"])
        knee = (leg_hip[0] + (ankle[0] - leg_hip[0]) * kt + bend * mirror, P["knee_y"] - bend)
        legs, last = leg_parts(P, leg_hip, knee, ankle, order, side, side == "far")
        parts.extend(legs)
        parts.append(foot_part(male, view, last, order, side))
    top = min(P["torso"]) + up
    if curvy and not male:
        torso = template_part(CURVY_SIL[silhouette][view], CURVY_X0 + sway, top, 4.5)
    else:
        torso = rows_part("torso", P["torso"], 4.5, dx=sway, dy=up)
    parts.append(torso)
    fig.torso_x0 = CURVY_X0 + sway
    (nx0, ny0), (nx1, ny1), nr0, nr1 = P["neck"]
    parts.append(limb("neck", (nx0 + sway, ny0 + up), (nx1 + sway, ny1 + up), nr0, nr1, 3.4))
    sl, sr, sy = P["shoulder"]
    sy += up
    ua0, ua1 = P["upper"]
    fa0, fa1 = P["fore"]
    for side, hand, elbow_off, order in (("far", j["hand_f"], j["elbow_f"], 1.0),
                                         ("near", j["hand_n"], j["elbow_n"], 6.0)):
        if front:
            sx = (sr if side == "far" else sl) + sway
            out = 1 if side == "far" else -1
        else:
            sx = (sl if side == "far" else sr) + sway
            out = -1 if side == "far" else 1
        if anim == "mop":
            sw = j["prop"][1]
            a = (19.0 + sw, top + 1.0)
            b = (25.0 + sw * 1.6, 45.5)
            if not front:
                # facing away: the handle reaches up-left, its foot further back
                a = (13.0 - sw, top + 1.0)
                b = (7.0 - sw * 1.6, 43.5)
            u = 0.20 if side == "far" else 0.46
            hand_p = (a[0] + (b[0] - a[0]) * u - 0.5, a[1] + (b[1] - a[1]) * u - 0.9)
            mid = ((sx + hand_p[0]) / 2, (sy + hand_p[1]) / 2)
            elbow = (mid[0] + (1.2 if side == "far" else -0.6), mid[1] + 2.0)
            fig.mop = (a, b)
        elif anim == "kneel":
            elbow = (sx + out * 0.8, sy + 4.5)
            hand_p = (sx - out * 1.6, P["shoulder"][2] + up + 8.0 + hand[1])
        elif curvy and anim == "idle":
            # escorts pose with both hands on the hips, elbows out
            elbow = (sx + out * 2.6, sy + 4.0)
            hand_p = (sx - out * 0.6, sy + 6.6)
        elif j["sit"]:
            elbow = (sx + out * 0.4 + 1.2, sy + P["elbow_dy"] - 0.5)
            hand_p = (sx + 3.6 + (1 if side == "far" else 0), sy + P["wrist_dy"] - 2.0)
        else:
            elbow = (sx + out * 0.8 + elbow_off[0], sy + P["elbow_dy"] + elbow_off[1])
            hand_p = (sx + out * 0.7 + hand[0], sy + P["wrist_dy"] + hand[1])
            if not front:
                hand_p = (sx + out * 0.7 - hand[0], sy + P["wrist_dy"] + hand[1])
                elbow = (sx + out * 0.8 - elbow_off[0], sy + P["elbow_dy"] + elbow_off[1])
        shoulder = snap((sx, sy))
        elbow = snap(elbow)
        hand_p = snap(hand_p)
        parts.append(limb("upper_arm", shoulder, elbow, ua0, ua1, order, side))
        parts.append(limb("forearm", elbow, hand_p, fa0, fa1, order + 0.1, side))
        hr0, hr1 = P["hand"]
        parts.append(blob("hand", hand_p[0], hand_p[1] + 0.9, hr0, hr1, order + 0.2, side))
        if side == "near":
            fig.hand_near = hand_p
        else:
            fig.hand_far = hand_p
    hx, hy = P["head"]
    fig.head = (hx + sway, hy + up)
    fig.top = top
    fig.parts = parts
    return fig


# ------------------------------------------------------------ heads

HEAD_ROWS_F = [(5, 8), (3, 10), (2, 11), (1, 12), (1, 12), (0, 13), (0, 13), (0, 13), (0, 13), (0, 13),
               (0, 13), (0, 13), (1, 13), (2, 12), (3, 11), (5, 10)]
HEAD_ROWS_M = [(4, 9), (2, 11), (1, 12), (1, 12), (0, 13), (0, 13), (0, 13), (0, 13), (0, 13), (0, 13),
               (0, 13), (0, 13), (0, 13), (1, 13), (2, 12), (4, 11)]
HEAD_H = 16


def head_pixels(male, view):
    rows = HEAD_ROWS_M if male else HEAD_ROWS_F
    mask = np.zeros((HEAD_H, 14), dtype=bool)
    for y, (a, b) in enumerate(rows):
        mask[y, a:b + 1] = True
    out = {}
    for y in range(HEAD_H):
        for x in range(14):
            if not mask[y, x]:
                continue
            edge = any(not (0 <= y + dy < HEAD_H and 0 <= x + dx < 14 and mask[y + dy, x + dx]) for dy, dx in N4)
            if edge:
                out[(x, y)] = ("ink", 0)
                continue
            a, b = rows[y]
            tone = MID
            if x >= b - 1:
                tone = SH
            elif x <= a + 1 and y < 11:
                tone = HI
            if y >= 13 and x <= a + 2:
                tone = SH
            if y <= 2 and x < 9:
                tone = HI
            out[(x, y)] = ("skin", tone)
    # ear on the back side of the head (left) in the 3/4 front view
    if view == "front":
        for (x, y, t) in ((0, 9, SH), (0, 10, MID), (0, 11, SH)):
            out[(x, y)] = ("skin", t)
        for y in (9, 10, 11):
            out[(-1, y)] = ("ink", 0)
        out[(0, 12)] = ("ink", 0)
    return out


# Face layouts over the 14 x 14 head box (front view, looking down-right).
# k lash/brow (hair deep), w eye white, i iris, e eye shine, l lips, L lip shadow,
# b blush, n nose shadow, N nose light, m mouth line
FACES = {
    "f0": [
        "..............",
        "..............",
        "..............",
        "..............",
        "..............",
        "..............",
        "...kkk...kkk..",
        "..............",
        "..kkkk..kkkk..",
        "...wei...wei..",
        "...wii...wii..",
        "........N.....",
        "..b.....n..b..",
        ".......ll.....",
        "..............",
        "..............",
    ],
    "f1": [
        "..............",
        "..............",
        "..............",
        "..............",
        "..............",
        "...kkk...kkk..",
        "..............",
        "..............",
        "..kkkk..kkkk..",
        "...wei...wei..",
        "...kii...kii..",
        "..............",
        "..b.....n..b..",
        ".......lL.....",
        "..............",
        "..............",
    ],
    "f2": [
        "..............",
        "..............",
        "..............",
        "..............",
        "..............",
        "..kkkk..kkkk..",
        "..............",
        "..kkkk..kkkk..",
        "...wei...wei..",
        "...wii...wii..",
        "........N.....",
        "........n.....",
        "..............",
        "......lll.....",
        "..............",
        "..............",
    ],
    "f3": [  # glamour: arched brows, cat-eye liner, full lips, beauty mark
        "..............",
        "..............",
        "..............",
        "..............",
        "..............",
        "...kkk...kkk..",
        "..............",
        "..k.........k.",
        "..kkkk...kkkk.",
        "...wei...wei..",
        "...kii...kii..",
        "........N..m..",
        "..b.....n..b..",
        "......lll.....",
        ".......L......",
        "..............",
    ],
    "m": [
        "..............",
        "..............",
        "..............",
        "..............",
        "..............",
        "..............",
        "..kkkk..kkkk..",
        "..............",
        "...kkk...kkk..",
        "....wi....wi..",
        "..............",
        "........N.....",
        "........nn....",
        "..............",
        ".......mmm....",
        "..............",
    ],
}
FACE_LEGEND = {"w": ("eye_white", 0), "i": ("iris", 0), "k": ("hair", DEEP), "l": ("lips", 0),
               "L": ("skin", SH), "b": ("blush", 0), "n": ("skin", SH), "N": ("skin", HI),
               "m": ("skin", DEEP), "e": ("shine", 0)}

# Beards for the male face option: 0 full, 1 short, 2 clean shaven.
BEARDS = {
    0: [
        "..............",
        "..............",
        "..............",
        "..............",
        "..............",
        "..............",
        "..............",
        "..............",
        "..............",
        "..............",
        ".#...........#",
        ".##.........##",
        ".##-.-===-.##.",
        "..##-.....-##.",
        "...##-...-##..",
        ".....#####....",
    ],
    1: [
        "..............",
        "..............",
        "..............",
        "..............",
        "..............",
        "..............",
        "..............",
        "..............",
        "..............",
        "..............",
        "..............",
        "..............",
        "......-===-...",
        "..-.........-.",
        "...-.-...-.-..",
        ".....-.-.-....",
    ],
    2: ["." * 14] * 16,
}

GLASSES = {
    1: [  # sunglasses
        "...ooooo.oooo.",
        "...ossso.osso.",
        "....ooo...oo..",
    ],
    2: [  # clear glasses
        "...ooooo.oooo.",
        "...o...o.o..o.",
        "....ooo...oo..",
    ],
}


def ascii_points(rows, origin, legend):
    ox, oy = origin
    for yy, line in enumerate(rows):
        for xx, ch in enumerate(line):
            if ch in legend:
                yield (ox + xx, oy + yy) + tuple(legend[ch])


HAIR_LEGEND = {"+": ("hair", HI), "#": ("hair", MID), "-": ("hair", SH), "=": ("hair", DEEP), "o": ("ink", 0)}
