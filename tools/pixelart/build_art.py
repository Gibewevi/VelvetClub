"""Regenerate every sprite of the pixel-art game into pixel/art.

Sprites are built at native resolution (tiles 32 x 16, characters 32 x 48).
Trees are prepared from their new source paintings on the native pixel grid;
the game only enlarges the resulting sprites by whole numbers.
"""
import time

import pa_charsheet
import pa_furniture
import pa_tiles
import pa_ui
import pa_delivery
import pa_sanitary
import pa_site
import pa_seasons
import prepare_bars
from pa_core import write_json, OUT


def main():
    t0 = time.time()
    for painting in prepare_bars.ROOT.glob("*_painting.png"):
        prepare_bars.prepare(painting.stem.removesuffix("_painting"))
    pa_charsheet.export()
    write_json("furniture.json", pa_furniture.export())
    pa_tiles.export()
    pa_seasons.export()
    pa_ui.export()
    pa_delivery.export()
    pa_sanitary.export()
    pa_site.export()
    print("ART_BUILD_DONE %.1fs -> %s" % (time.time() - t0, OUT))


if __name__ == "__main__":
    main()
