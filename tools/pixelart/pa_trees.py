"""Street trees, drawn pixel by pixel after the reference picture.

A broad crown of leaf rosettes (star-shaped clusters with a bright
yellow-green heart and darker jagged lobes) over a deep green shadow that
shows between them; the lower middle of the crown opens on thick branches
spreading from a flared reddish trunk with roots. A square tree pit (stone
kerb, soil, grass and small plants) is drawn apart, flat on the ground.
The trees are static."""
from __future__ import annotations

import math

import numpy as np

from pa_core import hexrgb

FRAMES = 1
W, H = 144, 140
OX, OY = 72, 134          # the foot of the trunk
# Leaves: deep shadow .. sunlit heart, hue-shifted (bluish shade, yellow light).
LEAVES = [hexrgb(c) for c in ("0f2618", "1b4322", "2a6226", "43822a", "74ae2e", "a9d140")]
LEAF_INK = hexrgb("0a1c12")
BARK = [hexrgb(c) for c in ("22100c", "3e1c14", "5e2c1c", "7e4024", "a45a30", "c67c44")]
BARK_INK = hexrgb("1e0c0a")

# Three silhouettes: crown centre and radii (px above the foot of the trunk),
# trunk height, branches (from, to, width), gap under the crown for the fork.
VARIANTS = [
    {"crown": (0, -74, 52, 34), "trunk": 36, "gap": 12,
     "branches": [((0, -30), (-26, -58), 3.8), ((-13, -44), (-38, -60), 2.2), ((1, -32), (24, -60), 3.6),
                  ((12, -46), (36, -62), 2.1), ((0, -34), (1, -70), 3.2), ((-6, -38), (-14, -66), 2.0)]},
    {"crown": (0, -78, 44, 38), "trunk": 40, "gap": 10,
     "branches": [((0, -34), (-20, -62), 3.4), ((1, -36), (20, -64), 3.4), ((0, -38), (-1, -76), 3.0),
                  ((-10, -48), (-30, -66), 2.0), ((10, -50), (28, -68), 1.9)]},
    {"crown": (0, -68, 58, 30), "trunk": 30, "gap": 14,
     "branches": [((0, -24), (-30, -50), 4.0), ((-15, -37), (-44, -54), 2.2), ((1, -26), (29, -52), 3.8),
                  ((15, -39), (44, -56), 2.2), ((0, -28), (3, -62), 3.2)]},
]


def h01(*k):
    """Deterministic hash in [0, 1)."""
    v = 0
    for i, n in enumerate(k):
        v = (v * 1000003 + (int(n) + 7919) * (i + 1) * 2654435761) & 0xFFFFFFFF
    v ^= v >> 13
    v = (v * 1274126177) & 0xFFFFFFFF
    return ((v ^ (v >> 16)) & 0xFFFF) / 65536.0


class Canvas:
    def __init__(self):
        self.leaf = np.full((H, W), -1, dtype=int)      # leaf tone, -1 = none
        self.bark = np.full((H, W), -1, dtype=int)      # bark tone, -1 = none

    def inside(self, x, y):
        return 0 <= x + OX < W and 0 <= y + OY < H

    def set_bark(self, x, y, tone):
        if self.inside(x, y):
            self.bark[y + OY, x + OX] = tone

    def set_leaf(self, x, y, tone):
        if self.inside(x, y):
            self.leaf[y + OY, x + OX] = tone


# ------------------------------------------------------------------ trunk and branches

def limb(c, a, b, r0, r1):
    """A tapered piece of wood, lit on its left side, with bark furrows."""
    (x0, y0), (x1, y1) = a, b
    n = int(max(abs(x1 - x0), abs(y1 - y0)) * 2) + 1
    for i in range(n + 1):
        t = i / n
        cx, cy, r = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t, r0 + (r1 - r0) * t
        for y in range(int(cy - r) - 1, int(cy + r) + 2):
            for x in range(int(cx - r) - 1, int(cx + r) + 2):
                if (x + 0.5 - cx) ** 2 + (y + 0.5 - cy) ** 2 > r * r:
                    continue
                side = (x + 0.5 - cx) / max(r, 0.8)
                tone = 4 if side < -0.55 else (3 if side < -0.05 else (2 if side < 0.6 else 1))
                if side < -0.62 and r > 3.5 and (y % 5) in (1, 2):
                    tone = 5
                if not c.inside(x, y):
                    continue
                old = c.bark[y + OY, x + OX]
                c.bark[y + OY, x + OX] = max(old, tone) if old >= 0 else tone


def draw_wood(c, v):
    top = v["trunk"]
    for (a, b, w) in v["branches"]:
        limb(c, a, b, w, max(w * 0.45, 1.0))
    limb(c, (0, 0), (0, -top), 7.0, 4.4)
    # flared foot and roots spreading on the soil
    for x, y, r in ((-7.5, -1.0, 3.0), (7.0, -0.8, 2.8), (-3.0, 0.2, 2.4), (3.5, 0.3, 2.2), (0, -2.5, 8.0)):
        for yy in range(int(y - r) - 1, 2):
            for xx in range(int(x - r) - 1, int(x + r) + 2):
                if (xx + 0.5 - x) ** 2 + ((yy + 0.5 - y) * 1.7) ** 2 <= r * r and c.inside(xx, yy) and c.bark[yy + OY, xx + OX] < 0:
                    c.bark[yy + OY, xx + OX] = 3 if xx < -1 else 2
    # furrows: dark vertical streaks, a few knots
    for y in range(H):
        for x in range(W):
            t = c.bark[y, x]
            if t < 0:
                continue
            if (x * 5 + (y // 4) * 3) % 7 == 0 and t > 1:
                c.bark[y, x] = t - 2 if t >= 3 else t - 1
            elif h01(x, y, 3) > 0.97 and t > 1:
                c.bark[y, x] = 1


# ------------------------------------------------------------------ crown

def rosette(c, cx, cy, r, light, seed, painted):
    """One leaf cluster: a six-lobed star, bright yellow-green at its heart,
    darker on the lobes and along the lower right."""
    ph = h01(seed, 1) * 6.28
    pts = []
    for y in range(int(cy - r) - 2, int(cy + r) + 3):
        for x in range(int(cx - r) - 2, int(cx + r) + 3):
            dx, dy = x + 0.5 - cx, y + 0.5 - cy
            d = math.hypot(dx, dy)
            a = math.atan2(dy, dx)
            lobe = math.cos(6 * a + ph)
            edge = r * (0.8 + 0.2 * lobe) + (0.6 if h01(x, y, seed) > 0.8 else 0.0)
            if d <= edge:
                pts.append((x, y, dx, dy, d, lobe, edge))
    # its shadow on the leaves behind, down and to the right
    mine = {(x, y) for x, y, *_ in pts}
    for x, y, *_ in pts:
        for sx, sy in ((x + 1, y + 1), (x + 1, y + 2), (x, y + 2)):
            if (sx, sy) not in mine and (sx, sy) in painted and c.inside(sx, sy):
                c.set_leaf(sx, sy, min(c.leaf[sy + OY, sx + OX], 1))
    hx, hy = cx - r * 0.22, cy - r * 0.3             # the sunlit heart sits up-left
    for x, y, dx, dy, d, lobe, edge in pts:
        # the lit part repeats the star shape, smaller and shifted up-left
        ex, ey = x + 0.5 - hx, y + 0.5 - hy
        hd = math.hypot(ex, ey)
        ha = math.atan2(ey, ex)
        heart = r * (0.46 + 0.14 * math.cos(6 * ha + ph))
        tone = 3
        if hd < heart and light > -0.5:
            tone = 4
            if hd < heart * 0.45 and light > 0.35:
                tone = 5
        elif d > edge - 1.6:
            tone = 2
        if lobe < -0.55 and d > r * 0.45:
            tone = min(tone, 2)                        # notches between the lobes
        if (dx + dy) / r > 0.7:
            tone = min(tone, 1 if light < 0.2 else 2)  # shaded lower right
        if light < -0.35:
            tone = max(tone - 1, 1)
        c.set_leaf(x, y, tone)
        painted.add((x, y))


def draw_crown(c, v, variant):
    ccx, ccy, rx, ry = v["crown"]
    rng = np.random.default_rng(40 + variant)
    spots = []
    step_x, step_y = 13.0, 9.5
    row = 0
    y = ccy - ry
    while y <= ccy + ry + 4:
        x = ccx - rx + (step_x / 2 if row % 2 else 0)
        while x <= ccx + rx:
            px, py = x + rng.uniform(-2.2, 2.2), y + rng.uniform(-1.8, 1.8)
            u, w = (px - ccx) / rx, (py - ccy) / ry
            inside = u * u + w * w <= 1.0
            # the lower middle stays open: the fork of the branches shows there
            fork = abs(px - ccx) < v["gap"] + (py - ccy) * 0.35 and py > ccy + ry * 0.22
            if inside and not fork:
                spots.append((py, px, rng.uniform(7.2, 10.2)))
            x += step_x
        y += step_y
        row += 1
    spots.sort()
    painted = set()
    # deep shade under the whole crown first: it shows between the rosettes
    for py, px, r in spots:
        for yy in range(int(py - r), int(py + r) + 3):
            for xx in range(int(px - r), int(px + r) + 2):
                if (xx + 0.5 - px - 0.5) ** 2 + (yy + 0.5 - py - 1.5) ** 2 <= (r * 0.95) ** 2:
                    c.set_leaf(xx, yy, 1)
                    painted.add((xx, yy))
    for n, (py, px, r) in enumerate(spots):
        u, w = (px - ccx) / rx, (py - ccy) / ry
        light = -0.45 * u - 0.9 * w                    # sun from the upper left
        rosette(c, px, py, r, light, variant * 101 + n, painted)


def tree_frame(variant, frame=0):
    v = VARIANTS[variant]
    c = Canvas()
    draw_wood(c, v)
    draw_crown(c, v, variant)
    img = np.zeros((H, W, 4), dtype=np.uint8)
    leaf = c.leaf >= 0
    bark = (c.bark >= 0) & ~leaf
    img[leaf, :3] = np.array(LEAVES, dtype=np.uint8)[c.leaf[leaf]]
    img[bark, :3] = np.array(BARK, dtype=np.uint8)[c.bark[bark]]
    img[leaf | bark, 3] = 255
    solid = leaf | bark
    for y in range(H):
        for x in range(W):
            if solid[y, x]:
                continue
            near_leaf = near_bark = False
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                X, Y = x + dx, y + dy
                if 0 <= X < W and 0 <= Y < H:
                    near_leaf |= bool(leaf[Y, X])
                    near_bark |= bool(bark[Y, X])
            if near_leaf or near_bark:
                img[y, x, :3] = LEAF_INK if near_leaf else BARK_INK
                img[y, x, 3] = 255
    return img


def tree_sheet(variant):
    return tree_frame(variant)


# ------------------------------------------------------------------ tree pit

PIT_W, PIT_H = 56, 30
PIT_OX, PIT_OY = 28, 15


def tree_pit(seed=0):
    """A square pit in the pavement (1.5 m): stone kerb, soil, grass tufts,
    small leafy plants and a few yellow flowers, as a flat iso diamond."""
    kerb = [hexrgb(c) for c in ("2e2a36", "4a4656", "6a6878", "8a8a98", "b4b4c0", "d6d6de")]
    soil = [hexrgb(c) for c in ("140c10", "22161a", "30211f", "3e2c26")]
    img = np.zeros((PIT_H, PIT_W, 4), dtype=np.uint8)
    half = 0.75

    def put(x, y, col):
        X, Y = x + PIT_OX, y + PIT_OY
        if 0 <= X < PIT_W and 0 <= Y < PIT_H:
            img[Y, X, :3] = col
            img[Y, X, 3] = 255
    for y in range(-PIT_OY, PIT_H - PIT_OY):
        for x in range(-PIT_OX, PIT_W - PIT_OX):
            # screen -> ground (metres): x = 16 (a - b), y = 8 (a + b)
            px, py = x + 0.5, y + 0.5
            a = (px / 16.0 + py / 8.0) / 2.0
            b = (py / 8.0 - px / 16.0) / 2.0
            m = max(abs(a), abs(b))
            if m > half:
                continue
            if m > half - 0.14:
                # kerb stones: lit on the far edges, shaded on the near ones, joints
                near = a > 0.0 and abs(a) >= abs(b) or b > 0.0 and abs(b) > abs(a)
                tone = 2 if near else 4
                if m > half - 0.05:
                    tone -= 1
                if int((a + b + 3) * 5) % 4 == 0 and m > half - 0.1:
                    tone = 1 if near else 2
                put(x, y, kerb[tone])
                continue
            put(x, y, soil[1 if h01(x, y, seed, 1) > 0.65 else 2])
    # grass tufts, small plants and flowers
    for i in range(30):
        a = (h01(i, seed, 2) - 0.5) * 2 * (half - 0.2)
        b = (h01(i, seed, 3) - 0.5) * 2 * (half - 0.2)
        if abs(a) < 0.25 and abs(b) < 0.25:
            continue                      # the trunk stands there
        x = int(round(16 * (a - b)))
        y = int(round(8 * (a + b)))
        g = 2 + int(h01(i, seed, 4) * 3)
        put(x, y, LEAVES[g])
        put(x, y - 1, LEAVES[min(g + 1, 5)])
        put(x - 1, y - 1, LEAVES[g])
        if h01(i, seed, 5) > 0.45:
            put(x + 1, y - 2, LEAVES[min(g + 1, 5)])
            put(x + 1, y - 1, LEAVES[g])
            put(x + 1, y, LEAVES[max(g - 1, 1)])
        if h01(i, seed, 6) > 0.82:
            put(x, y - 3, hexrgb("f0d050"))
    return img
