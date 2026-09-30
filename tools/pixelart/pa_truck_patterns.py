"""Clean native-pixel paint for the compact yellow DLH delivery van.

Callbacks follow ``pa_iso.Prim.pattern(local, normal, world, world_normal)``
and return ``(None, rgba)``. Transparent pixels leave the primitive's shaded
material intact. Coordinates are truck-local metres, before any world motion;
the visible flank is +z, the cargo rear +x and the cab front -x. There is no
grain, random wear or subpixel texture: broad enamel and glass areas remain
quiet when the van moves or its warning lights blink.
"""
from __future__ import annotations

import numpy as np


def _paint(world):
    return np.zeros((len(world), 4), dtype=np.uint8)


WINE = (126, 37, 51, 255)

# Five-column bold letters leave a real open counter in D and readable arms
# in L/H. Each cell covers more than one native pixel in both panel axes.
LETTERS = (
    ("11110", "11011", "11001", "11001", "11001", "11011", "11110"),
    ("11000", "11000", "11000", "11000", "11000", "11111", "11111"),
    ("11011", "11011", "11011", "11111", "11011", "11011", "11011"),
)


def _polygon(x, y, vertices):
    """Point-in-convex-polygon mask, independent of vertex winding."""
    positive = np.ones(x.shape, dtype=bool)
    negative = np.ones(x.shape, dtype=bool)
    for a, b in zip(vertices, vertices[1:] + vertices[:1]):
        cross = (b[0] - a[0]) * (y - a[1]) - (b[1] - a[1]) * (x - a[0])
        positive &= cross >= 0
        negative &= cross <= 0
    return positive | negative


def _stroke(x, y, a, b, radius):
    """A single clean panel stroke with short round caps, sampled natively."""
    dx, dy = b[0] - a[0], b[1] - a[1]
    t = np.clip(((x - a[0]) * dx + (y - a[1]) * dy) / (dx * dx + dy * dy), 0, 1)
    return (x - a[0] - t * dx) ** 2 + (y - a[1] - t * dy) ** 2 <= radius * radius


def body_side(local, normal, world, world_normal):
    """DLH wordmark, continuous bordeaux band and two quiet door seams.

    Cargo panel: x=-.90..2.50, y=.60..2.40. Letters span x=-.56..1.48 and
    y=1.39..2.09, with three speed bars at x=1.70..2.27. The band occupies
    y=.90..1.07. Door joints at x=-.73 and 2.37 sit clear of the printing.
    Three broad warm gold areas unify every construction facet on the +z
    bodywork. Sampling world z rather than normal direction also paints the
    thin horizontal ledges used to build its curved belly.
    """
    paint = _paint(world)
    x, y = world[:, 0], world[:, 1]
    side = ((world[:, 2] > .90) & (x >= -.90) & (x <= 2.50)
            & (y >= .60) & (y <= 2.40))
    paint[side] = (239, 169, 32, 255)
    paint[side & (y < .88)] = (222, 152, 35, 255)
    paint[side & (y >= 2.10)] = (243, 179, 43, 255)
    # Short rounded shoulders make these read as pressed van door joints.
    # Keep the centre entirely clean; this is panel structure, not wear.
    seams = np.zeros(x.shape, dtype=bool)
    for a, b in [
        ((-.73, .73), (-.73, 2.20)), ((-.73, 2.20), (-.66, 2.28)),
        ((2.37, .73), (2.37, 2.18)), ((2.37, 2.18), (2.31, 2.25)),
    ]:
        seams |= _stroke(x, y, a, b, .033)
    paint[side & seams] = (194, 128, 31, 255)
    paint[side & (y >= .90) & (y <= 1.07)] = WINE

    emblem = np.zeros(x.shape, dtype=bool)
    for letter_index, rows in enumerate(LETTERS):
        left = -.56 + letter_index * .72
        for row_index, row in enumerate(rows):
            top = 2.09 - row_index * .10
            for column, ink in enumerate(row):
                if ink == "1":
                    x0 = left + column * .12
                    emblem |= ((x >= x0) & (x < x0 + .12)
                               & (y > top - .10) & (y <= top))
    for yy in [1.52, 1.72, 1.92]:
        emblem |= (x >= 1.70) & (x <= 2.27) & (np.abs(y - yy) <= .055)
    paint[side & emblem] = WINE
    return None, paint


def roof_pattern(local, normal, world, world_normal):
    """Single enamel roof, with a narrow shoulder matching the upper flank.

    Cab and cargo share this surface. Its three broad tones follow the
    actual rounded surface; no dark stripe or bright rail outlines a cap.
    Grooves remain shallow paint details confined to the nearly flat top.
    """
    paint = _paint(world)
    x, z = world[:, 0], world[:, 2]
    up = world_normal[:, 1]
    paint[:] = (243, 179, 43, 255)
    paint[up > .38] = (250, 192, 45, 255)
    paint[up > .82] = (255, 204, 57, 255)
    for centre in [-.53, .53]:
        groove = _stroke(x, z, (-1.53, centre), (2.17, centre), .040)
        paint[groove & (up > .82)] = (244, 190, 46, 255)
    return None, paint


def glass_pattern(local, normal, world, world_normal):
    """Quiet navy glass with two broad reflection masses and a dark sill.

    Window geometry clips the paint in x=-2.55..-1.08, y=1.25..2.05. The
    reflection boundaries use no isolated bright pixels or thin hatch marks.
    """
    paint = _paint(world)
    x, y = world[:, 0], world[:, 1]
    side = world_normal[:, 2] > .75
    paint[side] = (38, 48, 64, 255)

    broad = _polygon(x, y, [(-2.62, 2.08), (-1.96, 2.08),
                             (-2.23, 1.39), (-2.62, 1.35)])
    paint[side & broad] = (67, 86, 105, 255)
    rear = _polygon(x, y, [(-1.91, 2.08), (-1.15, 2.08),
                            (-1.49, 1.59), (-2.11, 1.51)])
    paint[side & rear] = (48, 61, 79, 255)
    paint[side & (y < 1.35)] = (30, 39, 55, 255)
    return None, paint
