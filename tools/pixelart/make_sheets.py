"""Preview boards for the build folder: the native sprites, enlarged with
nearest neighbour only (each art pixel becomes an exact square)."""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

from pa_core import OUT, hexrgb, ramp
from pa_cast import frame_img, CAST, ESCORTS
from pa_chars import FRAMES

DEST = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("../../build/Apercus-V17")
BG = (30, 26, 48, 255)


def enlarge(img, s):
    return img.resize((img.width * s, img.height * s), Image.NEAREST)


def characters():
    kinds = [dict(c) for c in CAST]
    cells = []
    for c in kinds:
        row = []
        for sel in (("front", "idle", 0), ("front", "walk", 0), ("front", "walk", 2), ("back", "walk", 1),
                    ("front", "sit", 0), ("front", "dance", 1), ("front", "work", 0)):
            row.append(frame_img(c, *sel))
        cells.append(np.concatenate(row, axis=1))
    sheet = np.concatenate(cells, axis=0)
    base = Image.new("RGBA", (sheet.shape[1], sheet.shape[0]), BG)
    base.alpha_composite(Image.fromarray(sheet))
    enlarge(base, 4).save(DEST / "sprites-personnages-32x48.png")
    lineup = np.concatenate([frame_img(c, "front", "idle", 0) for c in kinds], axis=1)
    base = Image.new("RGBA", (lineup.shape[1], lineup.shape[0]), BG)
    base.alpha_composite(Image.fromarray(lineup))
    enlarge(base, 6).save(DEST / "sprites-equipe-x6.png")


def escorts():
    """The eight escort outfits by standing: front, walk, back and seated."""
    cells = []
    for c in ESCORTS:
        col = [frame_img(c, *sel) for sel in (("front", "idle", 0), ("front", "walk", 0), ("front", "walk", 2),
                                             ("back", "idle", 0), ("front", "sit", 0))]
        cells.append(np.concatenate(col, axis=0))
    pad = np.zeros((cells[0].shape[0], 4, 4), dtype=np.uint8)
    sheet = np.concatenate([np.concatenate([c, pad], axis=1) for c in cells], axis=1)
    base = Image.new("RGBA", (sheet.shape[1], sheet.shape[0]), BG)
    base.alpha_composite(Image.fromarray(sheet))
    enlarge(base, 5).save(DEST / "sprites-escorts-standings-x5.png")


def silhouettes():
    """The three escort body shapes (fine, galbée, très généreuse) on a few outfits."""
    rows = []
    for c in ESCORTS[:12:3] + ESCORTS[8:12]:
        row = []
        for sil in ("fine", "galbee", "genereuse"):
            cc = dict(c, sil=sil)
            row.append(frame_img(cc, "front", "idle", 0))
            row.append(np.zeros((48, 3, 4), dtype=np.uint8))
        rows.append(np.concatenate(row, axis=1))
    pad = np.zeros((4, rows[0].shape[1], 4), dtype=np.uint8)
    sheet = np.concatenate([np.concatenate([r, pad], axis=0) for r in rows], axis=0)
    # two columns of outfits side by side
    half = len(rows) // 2 * (48 + 4)
    sheet = np.concatenate([sheet[:half], sheet[half:half * 2]], axis=1)
    base = Image.new("RGBA", (sheet.shape[1], sheet.shape[0]), BG)
    base.alpha_composite(Image.fromarray(sheet))
    enlarge(base, 5).save(DEST / "sprites-escorts-silhouettes-x5.png")


def furniture():
    man = json.loads((OUT / "furniture.json").read_text(encoding="utf-8"))
    imgs = [Image.open(OUT / man[k]["0"]["file"]).convert("RGBA") for k in man]
    cols = 7
    cw = max(i.width for i in imgs) + 6
    ch = max(i.height for i in imgs) + 6
    rows = (len(imgs) + cols - 1) // cols
    board = Image.new("RGBA", (cols * cw, rows * ch), BG)
    for n, im in enumerate(imgs):
        x = (n % cols) * cw + (cw - im.width) // 2
        y = (n // cols) * ch + (ch - im.height)
        board.alpha_composite(im, (x, y - 3))
    enlarge(board, 3).save(DEST / "sprites-mobilier-x3.png")


def tiles():
    man = json.loads((OUT / "tiles.json").read_text(encoding="utf-8"))
    parts = []
    colors = {"boards": "c07a4a", "boards_worn": "9a6440", "carpet": "9c2e4c", "tile": "8a8c98", "terrazzo": "a89a90",
              "plain": "7e8290", "pavers": "23243a", "asphalt": "1d1e2c", "grass": "3f7e3a"}
    for name, rel in man["floors"].items():
        t = np.array(Image.open(OUT / rel).convert("RGBA"))
        lut = np.array(ramp(colors.get(name, "888888")), dtype=np.uint8)
        idx = np.clip(np.round(t[..., 0] / 40).astype(int), 0, 5)
        rgb = np.zeros_like(t)
        rgb[..., :3] = lut[idx]
        rgb[..., 3] = 255
        parts.append(Image.fromarray(rgb[:32, :64]))
    board = Image.new("RGBA", (len(parts) * 68, 36), BG)
    for n, p in enumerate(parts):
        board.alpha_composite(p, (n * 68 + 2, 2))
    enlarge(board, 4).save(DEST / "sprites-sols-32x16-x4.png")


def comparison():
    ref_path = Path(sys.argv[2]) if len(sys.argv) > 2 else None
    shot = DEST / "02-salon-bar-x3.png"
    if ref_path is None or not ref_path.exists() or not shot.exists():
        return
    ref = Image.open(ref_path).convert("RGBA")
    game = Image.open(shot).convert("RGBA")
    h = 720
    ref = ref.resize((int(ref.width * h / ref.height), h), Image.NEAREST)
    game = game.resize((int(game.width * h / game.height), h), Image.NEAREST)
    board = Image.new("RGBA", (ref.width + game.width + 24, h + 60), BG)
    board.alpha_composite(ref, (8, 52))
    board.alpha_composite(game, (ref.width + 16, 52))
    d = ImageDraw.Draw(board)
    d.text((12, 16), "Artwork de reference", fill=(244, 236, 246, 255))
    d.text((ref.width + 20, 16), "Construction V17 - pixel art natif (x3)", fill=(255, 127, 178, 255))
    board.save(DEST / "comparaison-artwork.png")


if __name__ == "__main__":
    DEST.mkdir(parents=True, exist_ok=True)
    characters()
    escorts()
    silhouettes()
    furniture()
    tiles()
    comparison()
    print("SHEETS_DONE", DEST)
