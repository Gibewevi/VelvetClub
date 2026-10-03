"""New reference-based tree sprites, independent of the old tree model.

The source paintings are kept in sources/trees so a full art rebuild always
uses the new tree designs. Sprite preparation only fits these paintings to
the game's native pixel grid; it never synthesizes or reuses an old crown,
leaf pattern, branch or trunk. Tree pits remain separate ground tiles.
"""
from pathlib import Path

import numpy as np
from PIL import Image

from pa_core import hexrgb

FRAMES = 1
W, H = 160, 192
OX, OY = 80, 178
# The world position is the middle of the root fan, not its lowest tip.
ROOT_FRONT = 6
SOURCE_DIR = Path(__file__).resolve().parent / "sources" / "trees"
# Keep all placement IDs stable; the former leaning variant now uses the
# upright full crown, including when rebuilding assets or loading old clubs.
VARIANTS = [
    {"source": "tree_full.png", "height": 160},
    {"source": "tree_tall.png", "height": 168},
    {"source": "tree_full.png", "height": 160},
]
# Only the flat planting pit uses this ramp; no old tree pixels are retained.
LEAVES = [hexrgb(c) for c in ("0f2618", "1b4322", "2a6226", "43822a", "74ae2e", "a9d140")]


def h01(*k):
    """Stable placement of small ground plants inside the planting pit."""
    v = 0
    for i, n in enumerate(k):
        v = (v * 1000003 + (int(n) + 7919) * (i + 1) * 2654435761) & 0xFFFFFFFF
    v ^= v >> 13
    v = (v * 1274126177) & 0xFFFFFFFF
    return ((v ^ (v >> 16)) & 0xFFFF) / 65536.0


def tree_frame(variant, frame=0):
    """Fit a new source painting to an opaque/transparent native sprite.

    Nearest-neighbor sampling and a binary cutout keep the rendered edges
    stable at every integer game zoom. There is no frame animation or noise.
    """
    spec = VARIANTS[variant]
    source = Image.open(SOURCE_DIR / spec["source"]).convert("RGBA")
    alpha = np.array(source.getchannel("A"))
    ys, xs = np.where(alpha >= 128)
    if not len(xs):
        raise ValueError(f"Empty tree source: {spec['source']}")
    bounds = (int(xs.min()), int(ys.min()), int(xs.max())+1, int(ys.max())+1)
    source = source.crop(bounds)
    height = spec["height"]
    width = round(source.width * height / source.height)
    if width > W-12:
        height = round(height * (W-12) / width)
        width = W-12
    native = np.array(source.resize((width, height), Image.Resampling.NEAREST))
    native[:, :, 3] = np.where(native[:, :, 3] >= 128, 255, 0)
    native[native[:, :, 3] == 0] = 0
    # A compact, undithered game palette keeps nearby source shades from
    # turning into tiny noisy speckles at native resolution.
    native = np.array(Image.fromarray(native).quantize(
        colors=48, method=Image.Quantize.FASTOCTREE,
        dither=Image.Dither.NONE).convert("RGBA"))
    # Align the trunk/root junction, rather than centering the canopy: this
    # keeps asymmetrical trees correctly planted on their world position.
    root_rows = native[max(0,height-10):height-3, :, 3] > 0
    root_x = np.where(root_rows)[1]
    foot = round(float(np.median(root_x))) if len(root_x) else width//2
    left = max(4, min(W-width-4, OX-foot))
    top = OY-height+1+ROOT_FRONT
    img = np.zeros((H, W, 4), dtype=np.uint8)
    img[top:top+height, left:left+width] = native
    return img


def tree_sheet(variant):
    return tree_frame(variant)


# ------------------------------------------------------------------ tree pit

PIT_W, PIT_H = 80, 44
PIT_OX, PIT_OY = 40, 22
PIT_HALF = 1.125


def tree_pit(seed=0):
    """A square pit in the pavement (2.25 m): stone kerb, soil, grass tufts,
    small leafy plants and a few yellow flowers, as a flat iso diamond."""
    kerb = [hexrgb(c) for c in ("2e2a36", "4a4656", "6a6878", "8a8a98", "b4b4c0", "d6d6de")]
    soil = [hexrgb(c) for c in ("140c10", "22161a", "30211f", "3e2c26")]
    img = np.zeros((PIT_H, PIT_W, 4), dtype=np.uint8)
    half = PIT_HALF

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
