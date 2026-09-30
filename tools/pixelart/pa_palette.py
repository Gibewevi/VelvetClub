"""Character palettes (mirrored by scripts/palette.gd in the game)."""
from __future__ import annotations

from pa_core import ramp, hexrgb
from pa_chars import ROLES, PALETTE_SIZE

# Fixed secondary colours per outfit; g1 comes from the appearance "outfit".
OUTFITS = {
    "lingerie": {"g2": "1c1620", "g3": "f6c9dc", "shoe": "c8336a", "lips": "d23a64"},
    "body": {"g2": "1d1519", "g3": "3a2630", "shoe": "1c1418", "lips": "b02a4a"},
    "dress": {"g2": "1a1418", "g3": "f0d080", "shoe": "b8264e"},
    "blazer": {"g2": "2b2233", "g3": "f2e6c8", "shoe": "2a1c24"},
    "maid": {"g2": "f5f1ec", "g3": "231b25", "shoe": "1a1418"},
    "suit": {"g2": "e9e4dc", "g3": "a0263e", "shoe": "1c1616"},
    "casual": {"g2": "3b5382", "g3": "4a3426", "shoe": "e5e1d8"},
    "security": {"g2": "17171c", "g3": "35302e", "shoe": "121216"},
    "janitor": {"g2": "d8c79c", "g3": "e9b92c", "shoe": "3a2a20"},
    "bartender": {"g2": "f2efe9", "g3": "b3203c", "shoe": "161416"},
    # escorts: g2 = stockings / gloves / skirt, g3 = lace or lacing, per-outfit lipstick
    "tube": {"g2": "1a1a24", "g3": "ece4f4", "shoe": "e0609a", "lips": "e0507a"},
    "bodycon": {"g2": "1a1418", "g3": "f0d080", "shoe": "c01e44", "lips": "c8284e"},
    "corset": {"g2": "15121a", "g3": "f0d080", "shoe": "1a1418", "lips": "a01838"},
    "cocktail": {"g2": "1a1418", "g3": "f0d080", "shoe": "d8b060", "lips": "b8284a"},
    "gown": {"g2": "141018", "g3": "f0d080", "shoe": "d8b060", "lips": "a0102e"},
    "sequin": {"g2": "1a1418", "g3": "f6e6b0", "shoe": "e0c070", "lips": "b0203c"},
    "string": {"g2": "1a1418", "g3": "f6c9dc", "shoe": "e0609a", "lips": "e0507a"},
    "balconnet": {"g2": "15121a", "g3": "f2d6e4", "shoe": "1a1418", "lips": "c8284e"},
    "babydoll": {"g2": "1a1418", "g3": "f6e6b0", "shoe": "c01e44", "lips": "b8284a"},
    "bijoux": {"g2": "1a1418", "g3": "f0d080", "shoe": "d8b060", "lips": "a0102e"},
}
FIXED = {
    "ink": "1b101e",
    "eye_white": "f6f0ec",
    "iris": "2e1e2c",
    "lips": "c9506c",
    "metal": ("f2d67e", "b07e3a"),
    "shine": "ffffff",
    "prop": "b9c3cf",
    "wood": ("b0875a", "7a5536"),
    "lens": ("7b8aa6", "15151c"),
}


def ramp4(base):
    r = ramp(base)
    return [r[4], r[3], r[2], r[1]]


def palette(skin, hair, outfit_color, outfit):
    pal = [(0, 0, 0)] * PALETTE_SIZE
    extra = OUTFITS[outfit]
    pal[ROLES["ink"]] = hexrgb(FIXED["ink"])
    for key, base in (("skin", skin), ("hair", hair), ("g1", outfit_color), ("g2", extra["g2"]), ("g3", extra["g3"])):
        for i, ix in enumerate(ROLES[key]):
            pal[ix] = ramp4(base)[i]
    pal[ROLES["eye_white"]] = hexrgb(FIXED["eye_white"])
    pal[ROLES["iris"]] = hexrgb(FIXED["iris"])
    pal[ROLES["lips"]] = hexrgb(extra.get("lips", FIXED["lips"]))
    pal[ROLES["blush"]] = ramp(skin)[2] if False else _blush(skin)
    s = ramp(extra["shoe"])
    pal[26], pal[27], pal[28] = s[4], s[3], s[1]
    pal[29], pal[30] = hexrgb(FIXED["metal"][0]), hexrgb(FIXED["metal"][1])
    pal[31] = hexrgb(FIXED["shine"])
    for i, c in enumerate(ramp4(FIXED["prop"])):
        pal[32 + i] = c
    pal[36], pal[37] = hexrgb(FIXED["wood"][0]), hexrgb(FIXED["wood"][1])
    pal[38], pal[39] = hexrgb(FIXED["lens"][0]), hexrgb(FIXED["lens"][1])
    return pal


def _blush(skin):
    r, g, b = hexrgb(skin)
    return (min(255, int(r * 0.92 + 40)), int(g * 0.72), int(b * 0.78))
