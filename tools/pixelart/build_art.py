"""Regenerate every sprite of the pixel-art game into pixel/art.

All art is painted at its final resolution (tiles 32 x 16, characters
32 x 48 frames); the game only enlarges it by whole numbers.
"""
import time

import pa_charsheet
import pa_furniture
import pa_tiles
import pa_ui
import pa_delivery
import pa_sanitary
import pa_site
from pa_core import write_json, OUT


def main():
    t0 = time.time()
    pa_charsheet.export()
    write_json("furniture.json", pa_furniture.export())
    pa_tiles.export()
    pa_ui.export()
    pa_delivery.export()
    pa_sanitary.export()
    pa_site.export()
    print("ART_BUILD_DONE %.1fs -> %s" % (time.time() - t0, OUT))


if __name__ == "__main__":
    main()
