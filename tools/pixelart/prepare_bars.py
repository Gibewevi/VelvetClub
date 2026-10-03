"""Prepare the approved paintings on the game's native furniture grid.

Run after changing a source atlas, then regenerate pa_furniture. Every stock
level uses the same empty cabinet painting; stocked bottles are rendered by
pa_bars at their fixed local positions. No filtering or temporal noise.
"""
from pathlib import Path
import json
from PIL import Image

ROOT = Path(__file__).parent / "sources" / "bars"
# Shared restrained ramps, close to the existing plum/red/brass furniture.
# The same colour is used in every orientation and inventory frame.
COLORS = ["1b101e","322032","422437","5e3552","85516e","af7889",
          "6a2234","922038","c42a40","e84d55","f47765",
          "735243","a97647","cca25f","e0bd79",
          "aca3ab","d2c2ba","f3e3c4","fff2d8",
          "244633","497342","7fa64d","233648","476b7b","7899a2",
          "83254f","d72c7b","ff62ad","ffbddb","fff3ed"]


def prepare(kind):
    atlas = Image.open(ROOT / f"{kind}_painting.png").convert("RGBA")
    geometry = json.loads((ROOT / f"{kind}_geometry.json").read_text())
    out = ROOT / "native"
    out.mkdir(exist_ok=True)
    cw,ch = atlas.width//2,atlas.height//2
    for r,g in enumerate(geometry):
        cell = atlas.crop((r%2*cw,r//2*ch,(r%2+1)*cw,(r//2+1)*ch))
        alpha = cell.getchannel("A").point(lambda v:255 if v>=160 else 0)
        bounds = alpha.getbbox()
        if bounds is None: raise ValueError(f"Missing orientation: {kind}/{r}")
        cell.putalpha(alpha)
        x0,y0,x1,y1 = g["body"]
        cell = cell.crop(bounds).resize((x1-x0,y1-y0),Image.Resampling.NEAREST)
        # No interpolated tones or dithering between the native pixel clusters.
        pal = Image.new("P",(1,1))
        colors = [tuple(bytes.fromhex(c)) for c in COLORS]
        colors += [colors[0]]*(256-len(colors))
        pal.putpalette([v for c in colors for v in c])
        native_alpha = cell.getchannel("A")
        cell = cell.convert("RGB").quantize(palette=pal,dither=Image.Dither.NONE).convert("RGBA")
        cell.putalpha(native_alpha)
        canvas = Image.new("RGBA",(g["w"],g["h"]))
        canvas.alpha_composite(cell,(x0,y0))
        canvas.save(out / f"{kind}_{r}.png")


if __name__ == "__main__":
    for p in sorted(ROOT.glob("*_painting.png")):
        prepare(p.stem.removesuffix("_painting"))
    print("BAR_PAINTINGS_PREPARED")
