"""The lawn around the club, and the round bushes along the sidewalks.

The whole lot (48 x 48 m) is painted as one picture, pixel by pixel, so
nothing repeats: a deep green field whose tone drifts at three scales (a
few lighter, drier stretches, darker lush ones), short blades everywhere,
taller tufts, and little clusters of flowers (daisies, pink, lilac,
buttercups), denser in a few meadow spots and along the sidewalks. Where
the lawn meets a sidewalk the edge is darker (soil) and tufts grow over the
slabs. The picture is transparent over the street: the sidewalks and the
road are drawn under it, the rooms and car parks over it.

Bushes are mounds of leaf rosettes in the street trees' style, lit from the
upper left, with a soft shadow; one variant flowers.
"""
from __future__ import annotations

import math

import numpy as np

from pa_core import HALF_W, HALF_H, hexrgb, save

LOT = 24
WALK_NEAR = (8.0, 10.5)      # must match pixel/scripts/street.gd
WALK_FAR = (17.5, 20.0)
W, H = 4 * LOT * HALF_W, 4 * LOT * HALF_H      # 1536 x 768
OX, OY = W // 2, H // 2                        # world origin in the picture

# deep shade .. sunlit tips, a little blue in the shade, yellow in the light
GREENS = [hexrgb(c) for c in ("102a1a", "173a20", "1f4a25", "285a2a", "326b2e", "3f7c33", "52903a", "6ea743", "92bf4f", "b4d460")]
DRY = [tuple(int(round(c * 0.8 + y * 0.2)) for c, y in zip(g, (196, 196, 84))) for g in GREENS]
SOIL = hexrgb("1a1712")
FLOWERS = {
    "daisy": [hexrgb("f4f1e8"), hexrgb("f2cf45")],
    "pink": [hexrgb("f39ac4"), hexrgb("d65c98")],
    "lilac": [hexrgb("c2a6f0"), hexrgb("8c6cd0")],
    "butter": [hexrgb("f6d84c"), hexrgb("d8a832")],
    "poppy": [hexrgb("ee5a4e"), hexrgb("2a1418")],
}
BAYER = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0 - 0.47


def hash2(ix, iz, seed):
    v = (ix.astype(np.int64) * 374761393 + iz.astype(np.int64) * 668265263 + seed * 1442695041) & 0xFFFFFFFF
    v = ((v ^ (v >> 13)) * 1274126177) & 0xFFFFFFFF
    v = v ^ (v >> 16)
    return (v & 0xFFFF) / 65535.0


def vnoise(X, Z, scale, seed):
    x, z = X / scale, Z / scale
    ix, iz = np.floor(x), np.floor(z)
    fx, fz = x - ix, z - iz
    fx = fx * fx * (3 - 2 * fx)
    fz = fz * fz * (3 - 2 * fz)
    a, b = hash2(ix, iz, seed), hash2(ix + 1, iz, seed)
    c, d = hash2(ix, iz + 1, seed), hash2(ix + 1, iz + 1, seed)
    return (a + (b - a) * fx) + ((c + (d - c) * fx) - (a + (b - a) * fx)) * fz


def world_grid():
    j, i = np.mgrid[0:H, 0:W]
    px = i - OX + 0.5
    py = j - OY + 0.5
    X = (px / HALF_W + py / HALF_H) / 2
    Z = (py / HALF_H - px / HALF_W) / 2
    return X, Z


def to_px(x, z):
    return int(round(HALF_W * (x - z))) + OX, int(round(HALF_H * (x + z))) + OY


class Lawn:
    def __init__(self, seed=7):
        self.rng = np.random.default_rng(seed)
        X, Z = world_grid()
        self.X, self.Z = X, Z
        inside = (np.abs(X) < LOT) & (np.abs(Z) < LOT)
        self.mask = inside & ((Z <= WALK_NEAR[0]) | (Z >= WALK_FAR[1]))
        # tone: broad drifts, medium patches, fine grain
        n1 = vnoise(X, Z, 7.0, 11)
        n2 = vnoise(X, Z, 2.2, 23)
        n3 = vnoise(X, Z, 0.7, 37)
        tone = 0.44 + 0.30 * (n1 - 0.5) + 0.22 * (n2 - 0.5) + 0.14 * (n3 - 0.5)
        # a few drier, yellower stretches
        self.dry = np.clip((vnoise(X, Z, 5.0, 53) - 0.62) * 3.0, 0.0, 1.0) * np.clip((vnoise(X, Z, 1.1, 59) - 0.2) * 2.0, 0.0, 1.0)
        # meadow spots where flowers gather
        self.meadow = vnoise(X, Z, 3.5, 71)
        bay = BAYER[np.arange(H)[:, None] % 4, np.arange(W)[None, :] % 4]
        self.tone = np.clip(np.floor(1.0 + tone * 4.6 + bay * 0.6), 0, 9).astype(int)
        # darker soil where the lawn meets a sidewalk
        edge = ((Z > WALK_NEAR[0] - 0.09) & (Z <= WALK_NEAR[0])) | ((Z >= WALK_FAR[1]) & (Z < WALK_FAR[1] + 0.09))
        self.tone[edge] = np.maximum(self.tone[edge] - 3, 0)
        self.soil = edge & self.mask
        use_dry = (self.dry + bay * 0.9) > 0.55
        self.use_dry = use_dry
        self.img = np.zeros((H, W, 4), dtype=np.uint8)
        g = np.array(GREENS, dtype=np.uint8)
        d = np.array(DRY, dtype=np.uint8)
        rgb = np.where(use_dry[..., None], d[self.tone], g[self.tone])
        rgb[self.soil] = (rgb[self.soil] * 0.55 + np.array(SOIL) * 0.45).astype(np.uint8)
        self.img[..., :3] = rgb
        self.img[..., 3] = np.where(self.mask, 255, 0)

    # ---------------------------------------------------------------- painting

    def colour(self, x, y, tone):
        ramp = DRY if self.use_dry[y, x] else GREENS
        return ramp[max(0, min(9, tone))]

    def put(self, x, y, rgb, free=False):
        if 0 <= x < W and 0 <= y < H and (free or self.mask[y, x]):
            self.img[y, x, :3] = rgb
            self.img[y, x, 3] = 255

    def blade(self, x, y, height, lean, base, free=False):
        """A blade rising from (x, y): darker at the foot, lit at the tip."""
        for k in range(height):
            px = x + int(round(lean * k / max(1, height - 1)))
            tone = base + (1 if k > 0 else 0) + (2 if k == height - 1 else 0)
            if not (0 <= px < W and 0 <= y - k < H):
                continue
            self.put(px, y - k, self.colour(min(max(px, 0), W - 1), y - k if free else y - k, tone), free)

    def short_blades(self, density=1 / 26.0):
        """Small clumps all over: three to five short blades fanning from a
        dark foot, lit at the tips. They make the grain of the lawn."""
        n = int(self.mask.sum() * density)
        xs = self.rng.integers(0, W, n)
        ys = self.rng.integers(0, H, n)
        for x, y in zip(xs, ys):
            if not self.mask[y, x] or self.soil[y, x]:
                continue
            base = self.tone[y, x]
            blades = int(self.rng.integers(2, 5))
            for b in range(blades):
                dx = int(self.rng.integers(-2, 3))
                h = int(self.rng.choice([2, 2, 3, 3, 4]))
                lean = -1 if dx < 0 else (1 if dx > 0 else 0)
                self.blade(x + dx, y, h, lean if h > 2 else 0, base)
            if y + 1 < H and self.mask[y + 1, x]:
                self.put(x, y + 1, self.colour(x, y + 1, base - 2))

    def tuft(self, x, y, size, free=False):
        """A taller clump: blades fanning out from a dark root."""
        if not (0 <= x < W and 0 <= y < H):
            return
        base = max(3, min(5, self.tone[min(max(y, 0), H - 1), min(max(x, 0), W - 1)] + 1))
        for dx in range(-size // 2 - 1, size // 2 + 2):
            self.put(x + dx, y + 1, self.colour(min(max(x + dx, 0), W - 1), y, base - 2), free)
        for b in range(size + 2):
            root = x + int(self.rng.integers(-size // 2 - 1, size // 2 + 2))
            height = int(self.rng.integers(3, 5 + size))
            lean = float(self.rng.uniform(-1.0, 1.0)) * (1 + (root - x) * 0.5)
            self.blade(root, y, height, lean, base, free)

    def flowers(self, x, y, kind, count):
        petal, heart = FLOWERS[kind]
        for f in range(count):
            fx = x + int(self.rng.integers(-6, 7))
            fy = y + int(self.rng.integers(-3, 4))
            if not (0 <= fx < W and 0 <= fy < H) or not self.mask[fy, fx]:
                continue
            stem = int(self.rng.integers(1, 3))
            for k in range(1, stem + 1):
                self.put(fx, fy - k + 1, self.colour(fx, fy, 2))
            top = fy - stem
            if kind == "daisy" or (kind != "poppy" and self.rng.random() < 0.35):
                for ox, oy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
                    self.put(fx + ox, top + oy, petal)
                self.put(fx, top, heart)
            else:
                self.put(fx, top, petal)
                self.put(fx + (1 if self.rng.random() < 0.5 else -1), top, petal)
                self.put(fx, top + 1, heart)

    # ---------------------------------------------------------------- the whole lot

    def paint(self):
        self.short_blades()
        area = float(self.mask.sum()) / (2 * HALF_W * HALF_H)      # m2
        # tufts scattered on the lawn, thicker along the sidewalks
        for _ in range(int(area / 2.2)):
            x, z = self.rng.uniform(-LOT, LOT), self.rng.uniform(-LOT, LOT)
            px, py = to_px(x, z)
            if 0 <= px < W and 0 <= py < H and self.mask[py, px]:
                self.tuft(px, py, int(self.rng.integers(1, 4)))
        for edge, side in ((WALK_NEAR[0], -1), (WALK_FAR[1], 1)):
            x = -LOT + 0.1
            while x < LOT - 0.1:
                # the verge: tall clumps, some growing over the slabs
                z = edge + side * float(self.rng.uniform(0.05, 0.6))
                self.tuft(*to_px(x, z), int(self.rng.integers(1, 4)))
                if self.rng.random() < 0.55:
                    over = edge - side * float(self.rng.uniform(0.02, 0.16))
                    px, py = to_px(x + float(self.rng.uniform(-0.2, 0.2)), over)
                    self.tuft(px, py, int(self.rng.integers(1, 3)), free=True)
                x += float(self.rng.uniform(0.25, 0.7))
        # flower clusters: a few everywhere, many in the meadow spots and the verges
        kinds = ["daisy", "daisy", "daisy", "pink", "pink", "lilac", "butter", "butter", "poppy"]
        for _ in range(int(area * 0.5)):
            x, z = self.rng.uniform(-LOT, LOT), self.rng.uniform(-LOT, LOT)
            px, py = to_px(x, z)
            if not (0 <= px < W and 0 <= py < H) or not self.mask[py, px]:
                continue
            verge = (WALK_NEAR[0] - 1.6 < z <= WALK_NEAR[0]) or (WALK_FAR[1] <= z < WALK_FAR[1] + 1.6)
            chance = 0.07 + 0.5 * max(0.0, self.meadow[py, px] - 0.62) * 3.0 + (0.3 if verge else 0.0)
            if self.rng.random() < chance:
                kind = kinds[int(self.meadow[py, px] * 97 + x * 3) % len(kinds)] if self.rng.random() < 0.7 else kinds[int(self.rng.integers(0, len(kinds)))]
                self.flowers(px, py, kind, int(self.rng.integers(3, 9)))
        return self.img


def lawn():
    return Lawn().paint()


# ---------------------------------------------------------------- bushes

LEAVES = [hexrgb(c) for c in ("0f2618", "1b4322", "2a6226", "43822a", "74ae2e", "a9d140")]
INK = hexrgb("0a1c12")
SHADOW = (8, 18, 12, 120)
# width, height (px), shadow radii, footprint (m), blossoms
BUSHES = [
    {"rx": 15, "ry": 10, "top": 18, "shadow": (17, 7), "size": 0.9, "bloom": None},
    {"rx": 21, "ry": 13, "top": 24, "shadow": (23, 9), "size": 1.3, "bloom": None},
    {"rx": 29, "ry": 11, "top": 20, "shadow": (31, 9), "size": 1.8, "bloom": None},
    {"rx": 18, "ry": 12, "top": 21, "shadow": (20, 8), "size": 1.1, "bloom": "pink"},
]
BW, BH = 72, 44
BOX, BOY = 36, 38       # the foot of the bush in its picture


def h01(*k):
    v = 0
    for i, n in enumerate(k):
        v = (v * 1000003 + (int(n) + 7919) * (i + 1) * 2654435761) & 0xFFFFFFFF
    v ^= v >> 13
    v = (v * 1274126177) & 0xFFFFFFFF
    return ((v ^ (v >> 16)) & 0xFFFF) / 65536.0


def bush(variant):
    """A mound of leaf rosettes, lit from the upper left."""
    spec = BUSHES[variant]
    rng = np.random.default_rng(300 + variant)
    leaf = np.full((BH, BW), -1, dtype=int)
    cx, cy = 0.0, -spec["top"] * 0.5 - 1
    rx, ry = spec["rx"], spec["top"] * 0.5 + 1
    spots = []
    y = cy - ry + 3
    row = 0
    while y <= cy + ry:
        x = cx - rx + 4 + (4 if row % 2 else 0)
        while x <= cx + rx - 3:
            px, py = x + rng.uniform(-1.5, 1.5), y + rng.uniform(-1.2, 1.2)
            u, w = (px - cx) / rx, (py - cy) / ry
            if u * u + w * w <= 0.92:
                spots.append((py, px, rng.uniform(4.6, 6.4)))
            x += 8.0
        y += 6.0
        row += 1
    spots.sort()

    def set_leaf(x, y, tone):
        X, Y = int(x) + BOX, int(y) + BOY
        if 0 <= X < BW and 0 <= Y < BH:
            leaf[Y, X] = tone

    # deep shade first: it shows between the rosettes
    for py, px, r in spots:
        for yy in range(int(py - r), int(py + r) + 2):
            for xx in range(int(px - r), int(px + r) + 2):
                if (xx + 0.5 - px) ** 2 + (yy - py - 1.0) ** 2 <= (r * 0.95) ** 2 and yy < 0:
                    set_leaf(xx, yy, 1)
    for n, (py, px, r) in enumerate(spots):
        u, w = (px - cx) / rx, (py - cy) / ry
        light = -0.5 * u - 0.9 * w
        ph = h01(variant, n) * 6.28
        hx, hy = px - r * 0.22, py - r * 0.3
        for yy in range(int(py - r) - 1, int(py + r) + 2):
            for xx in range(int(px - r) - 1, int(px + r) + 2):
                dx, dy = xx + 0.5 - px, yy + 0.5 - py
                d = math.hypot(dx, dy)
                lobe = math.cos(6 * math.atan2(dy, dx) + ph)
                edge = r * (0.8 + 0.2 * lobe)
                if d > edge or yy >= 0:
                    continue
                ex, ey = xx + 0.5 - hx, yy + 0.5 - hy
                heart = r * (0.46 + 0.14 * math.cos(6 * math.atan2(ey, ex) + ph))
                tone = 3
                if math.hypot(ex, ey) < heart and light > -0.5:
                    tone = 4 if math.hypot(ex, ey) > heart * 0.45 or light <= 0.3 else 5
                elif d > edge - 1.4:
                    tone = 2
                if (dx + dy) / r > 0.7:
                    tone = min(tone, 1 if light < 0.2 else 2)
                if light < -0.35:
                    tone = max(tone - 1, 1)
                set_leaf(xx, yy, tone)
    img = np.zeros((BH, BW, 4), dtype=np.uint8)
    # soft shadow on the ground, under the leaves
    sx, sy = spec["shadow"]
    for yy in range(BH):
        for xx in range(BW):
            dx, dy = xx - BOX + 2, yy - BOY + 1
            if (dx / sx) ** 2 + (dy / sy) ** 2 <= 1.0:
                img[yy, xx] = SHADOW
    solid = leaf >= 0
    img[solid, :3] = np.array(LEAVES, dtype=np.uint8)[leaf[solid]]
    img[solid, 3] = 255
    for yy in range(BH):
        for xx in range(BW):
            if solid[yy, xx]:
                continue
            for ax, ay in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                X, Y = xx + ax, yy + ay
                if 0 <= X < BW and 0 <= Y < BH and solid[Y, X]:
                    img[yy, xx] = INK + (255,)
                    break
    if spec["bloom"]:
        petal, heart = FLOWERS[spec["bloom"]]
        for _ in range(14):
            fx, fy = int(rng.integers(-spec["rx"] + 4, spec["rx"] - 3)), int(rng.integers(-spec["top"] + 3, -3))
            X, Y = fx + BOX, fy + BOY
            if 0 < X < BW - 1 and 0 < Y < BH - 1 and solid[Y, X] and leaf[Y, X] >= 2:
                img[Y, X, :3] = petal
                img[Y, X + 1, :3] = petal if solid[Y, X + 1] else img[Y, X + 1, :3]
                img[Y + 1, X, :3] = heart if solid[Y + 1, X] else img[Y + 1, X, :3]
    return img


def export():
    """Saves the lawn and the bushes; returns {lawn, bushes} for tiles.json."""
    save(lawn(), "tiles/lawn.png")
    out = {"lawn": {"file": "tiles/lawn.png", "ox": OX, "oy": OY}, "bushes": {}}
    for v in range(len(BUSHES)):
        save(bush(v), f"props/lawn_bush_{v}.png")
        out["bushes"][f"lawn_bush_{v}"] = {"file": f"props/lawn_bush_{v}.png", "ox": BOX, "oy": BOY, "lights": [],
                                           "size": BUSHES[v]["size"]}
    return out


if __name__ == "__main__":
    import time
    t0 = time.time()
    export()
    print("LAWN_DONE %.1fs" % (time.time() - t0))
