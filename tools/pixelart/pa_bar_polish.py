"""Small finishing corrections to the approved bar paintings.

The cabinet, worktop, accessories and silhouette stay in the source painting.
Only the straight neon rim and the bottle compartments are drawn on the native
pixel grid. Fewer tablets leave room for counter-sized inventory bottles.
"""
import math
import numpy as np


def rgba(hex_color):
    return tuple(bytes.fromhex(hex_color)) + (255,)


# Front shelf lips in the approved native paintings, bottom row first.
# A bottle rests above its lip with a margin matching the view's slope.
# The other two views show the back.
SLOTS = {
    "backbar": {0: (9, 29, [39.5]), 3: (16, 34, [62])},
    "bottles_small": {0: (7, 15, [62, 39.5]), 3: (15, 23, [79, 56.5])},
    "bottles_arch": {0: (11, 35, [58.5, 42]), 3: (19, 40, [86, 70])},
    "bottles_luxe": {0: (9, 36, [53.5, 38]), 3: (18, 44, [84, 68.5])},
}
# Only the recess that held the small bottles is re-spaced. Posts, header,
# arches, neon, stemware, drawers, plants and the outer silhouette stay painted.
INTERIORS = {
    "backbar": {0: (8, 33, 22.5, 39.5), 3: (15, 38, 45, 62)},
    "bottles_small": {0: (6, 19, 18, 62), 3: (14, 27, 33.5, 79)},
    "bottles_arch": {0: (10, 39, 27, 58.5), 3: (18, 44, 54.5, 86)},
    "bottles_luxe": {0: (8, 40, 24, 53.5), 3: (17, 48, 54.5, 84)},
}

# Narrow straight portions only; leave curved ends and corner joins intact.
# Each tuple is slope, intercept, first column, last column (inclusive).
RIMS = {
    "bar_module": {0: [( .5, 24, 9, 29), (-.5, 54.5, 34, 39)],
                   1: [(-.5, 45.5, 19, 38)],
                   2: [( .5, 18, 9, 29)],
                   3: [(-.5, 44, 20, 37), (.5, 25, 9, 17)]},
    "bar_round": {0: [( .5, 27, 13, 53)],
                  1: [(-.5, 63, 23, 63)],
                  2: [( .5, 20.5, 14, 50)],
                  3: [(-.5, 61.5, 30, 64)]},
    "bar_l": {0: [( .5, 24.5, 10, 62), (-.5, 39, 38, 45)],
              1: [(-.5, 62.5, 22, 61)],
              2: [( .5, 8.5, 34, 62), (-.5, 90.5, 63, 89)],
              3: [(-.5, 67.5, 35, 89), (.5, 23.5, 9, 19)]},
    "bar_luxe": {0: [( .5, 25.5, 12, 59)],
                 3: [(-.5, 68.5, 32, 71)]},
}
HOT = {rgba(c) for c in ("d72c7b", "ff62ad", "ffbddb", "fff3ed")}


def remove_islands(pic):
    """Discard tiny detached source artefacts, keeping the continuous sprite."""
    pixels = {(int(x), int(y)) for y, x in zip(*np.nonzero(pic[..., 3]))}
    components = []
    while pixels:
        pending = [pixels.pop()]
        component = []
        while pending:
            x, y = pending.pop()
            component.append((x, y))
            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1):
                    p = (x + dx, y + dy)
                    if p in pixels:
                        pixels.remove(p)
                        pending.append(p)
        components.append(component)
    components.sort(key=len, reverse=True)
    for component in components[1:]:
        if len(component) <= 40:
            for x, y in component:
                pic[y, x] = 0


def finish_rims(pic, kind, rotation):
    """Regular 2:1 stair steps within the existing, three-pixel rim band."""
    original = pic.copy()
    for slope, intercept, x0, x1 in RIMS.get(kind, {}).get(rotation, []):
        for x in range(x0, x1 + 1):
            y = math.floor(slope * x + intercept)
            # Remove only displaced neon pixels next to the corrected line;
            # keep upholstery, stone, hearts and all pixels outside this band.
            for offset in (-2, 2):
                if tuple(original[y + offset, x]) in HOT:
                    sample = original[y + offset + (-1 if offset < 0 else 1), x]
                    if tuple(sample) not in HOT:
                        pic[y + offset, x] = sample
            for offset, color in [(-1, "422437"), (0, "ffbddb"), (1, "d72c7b")]:
                if original[y + offset, x, 3] == 255:
                    pic[y + offset, x] = rgba(color)


def shelf_interior(pic, kind, rotation):
    """Fewer, taller compartments for bottles at the counter's pixel scale."""
    face = INTERIORS.get(kind, {}).get(rotation)
    if face is None:
        return
    x0, x1, top, bottom = face
    slope = .5 if rotation == 0 else -.5
    for x in range(x0, x1 + 1):
        for y in range(math.ceil(slope * x + top), math.floor(slope * x + bottom)):
            # Broad recessed shade, with one steady edge shadow, no grain.
            pic[y, x] = rgba("1b101e" if x in (x0, x1) else "322032")
    for lip in SLOTS[kind][rotation][2]:
        for x in range(x0, x1 + 1):
            y = math.floor(slope * x + lip)
            for offset, color in [(-2,"83254f"),(-1,"83254f"),(0,"cca25f"),(1,"1b101e")]:
                pic[y + offset, x] = rgba(color)


def stock_bottles(pic, kind, rotation, count, columns):
    """4 x 11 px bottles: counter-sized neck, shoulders and broad labels."""
    layout = SLOTS.get(kind, {}).get(rotation)
    if layout is None:
        return
    x0, x1, lips = layout
    slope = .5 if rotation == 0 else -.5
    # These silhouettes match the counter bottles rather than tiny stock ticks.
    # A fixed 2 x 2 label and two grouped glass tones stay readable at game scale.
    colors = [("244633", "497342"), ("735243", "a97647"), ("6a2234", "c42a40")]
    shape = [".cc.", ".dB.", ".dB.", ".dB.", "odBB", "oBBB",
             "oBBB", "oLLB", "oLLB", "odBB", ".dd."]
    for i in range(count):
        row, column = divmod(i, columns)
        x = math.floor(x0 + (x1 - x0) * column / max(1, columns - 1))
        y = math.floor(slope * x + lips[row]) - 3
        dark, body = colors[(column + row) % len(colors)]
        ink = {"o":rgba("1b101e"), "d":rgba(dark), "B":rgba(body),
               "L":rgba("f3e3c4"), "c":rgba("a97647")}
        for dy, line in enumerate(shape):
            for dx, token in enumerate(line):
                if token != ".":
                    pic[y - len(shape) + 1 + dy, x + dx] = ink[token]
