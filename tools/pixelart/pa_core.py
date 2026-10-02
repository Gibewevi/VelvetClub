"""Shared pixel-art helpers: colours, hue-shifted ramps, outlines, image IO.

Everything in this package paints sprites directly at their final, native
resolution (floor tile 32 x 16 px, character frame 32 x 48 px). Nothing is ever
rendered large and reduced: each output pixel is decided exactly once.
"""
from __future__ import annotations

import colorsys
import json
import os
import time
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "pixel" / "art"

# World -> screen projection shared with the game (scripts/iso.gd).
TILE_W = 32          # a 1 m floor cell is a 32 x 16 diamond
HALF_W = 16          # +1 m along x moves (+16, +8); +1 m along z moves (-16, +8)
HALF_H = 8
PX_PER_M_Y = 24      # +1 m of height moves 24 px up
WALL_H = 56          # full back wall height in pixels
LOW_WALL_H = 12      # cut-away front wall height in pixels
WALL_T = 0.25        # wall thickness in metres

INK = (27, 16, 30)   # global darkest outline tone


def hexrgb(value: str) -> tuple[int, int, int]:
    value = value.lstrip("#")
    return tuple(int(value[i:i + 2], 16) for i in (0, 2, 4))


def rgbhex(rgb) -> str:
    return "%02x%02x%02x" % tuple(int(c) for c in rgb[:3])


def _toward(h: float, target: float, amount: float) -> float:
    d = (target - h + 0.5) % 1.0 - 0.5
    if abs(d) <= amount:
        return target % 1.0
    return (h + amount * (1 if d > 0 else -1)) % 1.0


def ramp(base, n: int = 6, mid: int = 3) -> list[tuple[int, int, int]]:
    """Hue-shifted ramp, darkest first. Shadows drift to violet, lights to amber.

    The same formula lives in scripts/palette.gd so runtime recolouring of
    floors, walls and characters matches the baked art exactly.
    """
    if isinstance(base, str):
        base = hexrgb(base)
    r, g, b = [c / 255.0 for c in base]
    h, s, v = colorsys.rgb_to_hsv(r, g, b)
    out = []
    grey = s <= 0.08
    for i in range(n):
        k = i - mid
        if k < 0:
            t = -k
            if grey:
                hh, ss = 0.70, min(0.4, s + 0.06 * t)
            else:
                hh, ss = _toward(h, 0.75, 0.03 * t), min(1.0, s + 0.05 * t)
            vv = v * (1.0 - 0.21 * t)
        elif k > 0:
            t = k
            hh = h if grey else _toward(h, 0.11, 0.025 * t)
            ss = max(0.0, s - 0.09 * t)
            vv = min(1.0, v + (min(v * 0.35, (1.0 - v) * 0.55) + 0.03) * t)
        else:
            hh, ss, vv = h, s, v
        rr, gg, bb = colorsys.hsv_to_rgb(hh, ss, vv)
        out.append((round(rr * 255), round(gg * 255), round(bb * 255)))
    return out


def mix(a, b, t: float):
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))


def rgba_array(w: int, h: int) -> np.ndarray:
    return np.zeros((h, w, 4), dtype=np.uint8)


def outline(img: np.ndarray, color=None, diagonal: bool = False, darken: float | None = None) -> np.ndarray:
    """Add a 1 px outline outside the opaque silhouette.

    With darken set, each outline pixel takes a darkened version of the
    opaque neighbour it touches (selective outline); otherwise ``color``.
    """
    a = img[..., 3] > 0
    h, w = a.shape
    res = img.copy()
    offsets = [(0, 1), (0, -1), (1, 0), (-1, 0)]
    if diagonal:
        offsets += [(1, 1), (1, -1), (-1, 1), (-1, -1)]
    for dy, dx in offsets:
        shifted = np.zeros_like(a)
        src = np.zeros_like(img)
        ys = slice(max(dy, 0), h + min(dy, 0))
        yd = slice(max(-dy, 0), h + min(-dy, 0))
        xs = slice(max(dx, 0), w + min(dx, 0))
        xd = slice(max(-dx, 0), w + min(-dx, 0))
        shifted[yd, xd] = a[ys, xs]
        src[yd, xd] = img[ys, xs]
        target = shifted & ~a & (res[..., 3] == 0)
        if darken is not None:
            col = (src[..., :3].astype(np.float32) * darken).astype(np.uint8)
            res[target, :3] = col[target]
        else:
            res[target, :3] = color if color is not None else INK
        res[target, 3] = 255
    return res


def pad(img: np.ndarray, n: int) -> np.ndarray:
    h, w, _ = img.shape
    out = np.zeros((h + 2 * n, w + 2 * n, 4), dtype=np.uint8)
    out[n:n + h, n:n + w] = img
    return out


def crop_alpha(img: np.ndarray, margin: int = 0):
    ys, xs = np.nonzero(img[..., 3])
    if len(xs) == 0:
        return img[:1, :1], (0, 0)
    x0, x1 = max(xs.min() - margin, 0), min(xs.max() + 1 + margin, img.shape[1])
    y0, y1 = max(ys.min() - margin, 0), min(ys.max() + 1 + margin, img.shape[0])
    return img[y0:y1, x0:x1], (x0, y0)


def replace_complete(temporary: Path, path: Path) -> None:
    # Windows live importers/virus scanners can briefly hold a picture open.
    for attempt in range(12):
        try:
            os.replace(temporary,path)
            return
        except PermissionError:
            if attempt == 11: raise
            time.sleep(.1)


def save(img: np.ndarray, rel: str) -> Path:
    path = OUT / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    # Replace only a complete picture, so live imports cannot read a half-
    # written sprite (or keep a handle open while Pillow truncates it).
    temporary = path.with_suffix(path.suffix + ".tmp")
    Image.fromarray(img).save(temporary, format="PNG")
    replace_complete(temporary, path)
    return path


def preview(img: np.ndarray, path, scale: int = 4, bg=(40, 36, 52)) -> None:
    """Nearest-neighbour enlargement for inspection only (never shipped)."""
    h, w, _ = img.shape
    base = Image.new("RGBA", (w, h), bg + (255,))
    base.alpha_composite(Image.fromarray(img))
    base = base.resize((w * scale, h * scale), Image.NEAREST)
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    base.save(path)


def write_json(rel: str, data) -> None:
    path = OUT / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(json.dumps(data, indent=1, ensure_ascii=False), encoding="utf-8")
    replace_complete(temporary,path)


def rng(seed: int) -> np.random.Generator:
    return np.random.default_rng(seed)


def hash01(*vals) -> float:
    """Deterministic pseudo-random value in [0, 1) from integers."""
    x = 0x9E3779B1
    for v in vals:
        x ^= (int(v) + 0x7F4A7C15 + (x << 6) + (x >> 2)) & 0xFFFFFFFF
        x = (x * 0x85EBCA6B) & 0xFFFFFFFF
        x ^= x >> 13
    return (x & 0xFFFFFF) / float(0x1000000)
