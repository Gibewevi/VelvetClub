"""The lawn around the club, and the round bushes along the sidewalks.

The whole lot (48 x 48 m) is painted as one picture, pixel by pixel, so
nothing repeats: an olive-green field with broad shaded patches and
irregular groups of yellow-green blades, without a repeating dither grid,
taller tufts, and sparse little clusters of pink flowers, daisies and
buttercups, denser in a few meadow spots and along the sidewalks. Where
the lawn meets a sidewalk the edge is darker (soil) and tufts grow over the
slabs. The picture is transparent over the street: the sidewalks and the
road are drawn under it, the rooms and car parks over it.

Bushes use new reference paintings: broad pointed leaves, yellow-green
highlights and deep shaded bases, with compact and spreading flowered forms.
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image

import numpy as np

from pa_core import HALF_W, HALF_H, hexrgb, save

LOT = 24
WALK_NEAR = (8.0, 10.5)      # must match pixel/scripts/street.gd
WALK_FAR = (17.5, 20.0)
W, H = 4 * LOT * HALF_W, 4 * LOT * HALF_H      # 1536 x 768
OX, OY = W // 2, H // 2                        # world origin in the picture

# deep shade .. sunlit tips, a little blue in the shade, yellow in the light
GREENS = [hexrgb(c) for c in ("112c21", "173721", "1f4221", "294c22", "325523", "3a5f23", "436824", "4c7225", "597d29", "668a2d", "749733", "86a637", "9ab642", "b0c647", "c3d452", "d7df6b")]
DRY = [tuple(int(round(c * 0.88 + y * 0.12)) for c, y in zip(g, (177, 160, 58))) for g in GREENS]
SOIL = hexrgb("1a1712")
FLOWERS = {
    "daisy": [hexrgb("f4f1e8"), hexrgb("f2cf45")],
    "pink": [hexrgb("f39ac4"), hexrgb("d65c98")],
    "lilac": [hexrgb("c2a6f0"), hexrgb("8c6cd0")],
    "butter": [hexrgb("f6d84c"), hexrgb("d8a832")],
    "poppy": [hexrgb("ee5a4e"), hexrgb("2a1418")],
}


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
        # Solid colour clusters at three scales. No screen-space stippling:
        # the visible texture comes from irregular blades, not a dot grid.
        n1 = vnoise(X, Z, 7.0, 11)
        n2 = vnoise(X, Z, 2.2, 23)
        n3 = vnoise(X, Z, 0.7, 37)
        tone = 4.4 + 3.0 * (n1 - 0.5) + 4.0 * (n2 - 0.5) + 2.0 * (n3 - 0.5)
        # a few drier, yellower stretches
        self.dry = np.clip((vnoise(X, Z, 5.0, 53) - 0.62) * 3.0, 0.0, 1.0) * np.clip((vnoise(X, Z, 1.1, 59) - 0.2) * 2.0, 0.0, 1.0)
        # meadow spots where flowers gather
        self.meadow = vnoise(X, Z, 3.5, 71)
        self.growth = vnoise(X, Z, 0.65, 83)
        self.tone = np.clip(np.floor(tone), 2, 10).astype(int)
        # darker soil where the lawn meets a sidewalk
        edge = ((Z > WALK_NEAR[0] - 0.09) & (Z <= WALK_NEAR[0])) | ((Z >= WALK_FAR[1]) & (Z < WALK_FAR[1] + 0.09))
        self.tone[edge] = np.maximum(self.tone[edge] - 3, 0)
        self.soil = edge & self.mask
        use_dry = self.dry > 0.28
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
        return ramp[max(0, min(len(ramp)-1, tone))]

    def put(self, x, y, rgb, free=False):
        if 0 <= x < W and 0 <= y < H and (free or self.mask[y, x]):
            self.img[y, x, :3] = rgb
            self.img[y, x, 3] = 255

    def blade(self, x, y, height, lean, base, free=False):
        """A blade rising from (x, y): darker at the foot, lit at the tip."""
        for k in range(height):
            px = x + int(round(lean * k / max(1, height - 1)))
            tone = base + (2 if k > 0 else 0) + (4 if k == height - 1 else 0)
            if not (0 <= px < W and 0 <= y - k < H):
                continue
            self.put(px, y - k, self.colour(px, y - k, tone), free)

    def short_blades(self, density=1 / 23.0):
        """Small clumps all over: two or three short blades fanning from a
        dark foot, lit at the tips. They make the grain of the lawn."""
        n = int(self.mask.sum() * density)
        ys, xs = np.where(self.mask)
        choices = self.rng.integers(0, len(xs), n)
        for idx in choices:
            x, y = int(xs[idx]), int(ys[idx])
            if self.soil[y, x] or self.rng.random() > 0.18 + 0.85*self.growth[y, x]:
                continue
            base = int(self.tone[y, x]) + int(self.rng.choice([0, 1, 1, 2]))
            blades = int(self.rng.integers(2, 4))
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
        base = max(5, min(9, int(self.tone[y, x]) + 2))
        for dx in range(-size // 2 - 1, size // 2 + 2):
            self.put(x + dx, y + 1, self.colour(min(max(x + dx, 0), W - 1), y, base - 2), free)
        for b in range(size + 1):
            root = x + int(self.rng.integers(-size // 2 - 1, size // 2 + 2))
            height = int(self.rng.integers(2, 4 + size))
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
        for _ in range(int(area / 2.7)):
            x, z = self.rng.uniform(-LOT, LOT), self.rng.uniform(-LOT, LOT)
            px, py = to_px(x, z)
            if 0 <= px < W and 0 <= py < H and self.mask[py, px] and self.rng.random() < 0.2 + self.growth[py, px]:
                self.tuft(px, py, int(self.rng.integers(1, 4)))
        for edge, side in ((WALK_NEAR[0], -1), (WALK_FAR[1], 1)):
            x = -LOT + 0.1
            while x < LOT - 0.1:
                # the verge: tall clumps, some growing over the slabs
                z = edge + side * float(self.rng.uniform(0.05, 0.6))
                self.tuft(*to_px(x, z), int(self.rng.integers(1, 4)))
                if self.rng.random() < 0.38:
                    over = edge - side * float(self.rng.uniform(0.02, 0.16))
                    px, py = to_px(x + float(self.rng.uniform(-0.2, 0.2)), over)
                    self.tuft(px, py, int(self.rng.integers(1, 3)), free=True)
                x += float(self.rng.uniform(0.3, 0.85))
        # flower clusters: a few everywhere, many in the meadow spots and the verges
        kinds = ["daisy", "pink", "pink", "pink", "butter"]
        for _ in range(int(area * 0.5)):
            x, z = self.rng.uniform(-LOT, LOT), self.rng.uniform(-LOT, LOT)
            px, py = to_px(x, z)
            if not (0 <= px < W and 0 <= py < H) or not self.mask[py, px]:
                continue
            verge = (WALK_NEAR[0] - 1.6 < z <= WALK_NEAR[0]) or (WALK_FAR[1] <= z < WALK_FAR[1] + 1.6)
            chance = 0.025 + 0.35 * max(0.0, self.meadow[py, px] - 0.62) * 3.0 + (0.16 if verge else 0.0)
            if self.rng.random() < chance:
                kind = kinds[int(self.meadow[py, px] * 97 + x * 3) % len(kinds)] if self.rng.random() < 0.7 else kinds[int(self.rng.integers(0, len(kinds)))]
                self.flowers(px, py, kind, int(self.rng.integers(2, 6)))
        return self.img


def lawn():
    return Lawn().paint()


# ---------------------------------------------------------------- bushes

# New source paintings based on the player's reference. All four native
# sprites retain their existing footprint, and are static at every zoom.
SOURCE_DIR = Path(__file__).resolve().parent / "sources" / "bushes"
BUSHES = [
    {"source": "green.png", "width": 34, "height": 26, "shadow": (17, 7), "size": 0.9},
    {"source": "green.png", "width": 46, "height": 34, "shadow": (23, 9), "size": 1.3},
    {"source": "wide_flowers.png", "width": 62, "height": 34, "shadow": (31, 9), "size": 1.8},
    {"source": "round_flowers.png", "width": 40, "height": 34, "shadow": (20, 8), "size": 1.1},
]
BW, BH = 80, 56
BOX, BOY = 40, 44


def bush(variant):
    """Fit a reference-painted leafy bush to its native game footprint.

    Cutout alpha is binary, colours undithered, sampling nearest-neighbour.
    Only the separate ground shadow uses transparent shading; source halos
    and marginal alpha are excluded from the foliage cutout.
    """
    spec = BUSHES[variant]
    source = Image.open(SOURCE_DIR / spec["source"]).convert("RGBA")
    alpha = np.array(source.getchannel("A"))
    ys, xs = np.where(alpha >= 128)
    if not len(xs):
        raise ValueError(f"Empty bush source: {spec['source']}")
    source = source.crop((int(xs.min()), int(ys.min()), int(xs.max())+1, int(ys.max())+1))
    scale = min(spec["width"] / source.width, spec["height"] / source.height)
    width, height = round(source.width*scale), round(source.height*scale)
    pixels = np.array(source.resize((width, height), Image.Resampling.NEAREST))
    pixels[:, :, 3] = np.where(pixels[:, :, 3] >= 128, 255, 0)
    pixels[pixels[:, :, 3] == 0] = 0
    native = np.array(Image.fromarray(pixels).quantize(
        colors=32, method=Image.Quantize.FASTOCTREE,
        dither=Image.Dither.NONE).convert("RGBA"))
    img = np.zeros((BH, BW, 4), dtype=np.uint8)
    # A compact two-tone contact shadow, complete inside the canvas.
    yy, xx = np.mgrid[0:BH, 0:BW]
    sx, sy = spec["shadow"]
    distance = ((xx-BOX-2)/sx)**2 + ((yy-BOY+1)/sy)**2
    img[distance <= 1.0] = (8, 22, 16, 48)
    img[distance <= 0.55] = (8, 22, 16, 96)
    left = BOX-width//2
    top = BOY+4-height
    region = img[top:top+height, left:left+width]
    solid = native[:, :, 3] > 0
    region[solid] = native[solid]
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
