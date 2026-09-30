"""Native-pixel paint for the delivery truck's broad metal and glass panels.

Callbacks follow ``pa_iso.Prim.pattern(local, normal, world, world_normal)``
and return ``(None, rgba)``. Transparent pixels leave the primitive's shaded
material intact. Coordinates are truck-local metres, before any world motion;
the visible flank is +z, the cargo rear +x and the cab front -x.
"""
from __future__ import annotations

import numpy as np


def _paint(world):
    return np.zeros((len(world), 4), dtype=np.uint8)


def _segment(x, y, a, b, radius):
    """A crisp capsule in panel space; the painter samples at native pixels."""
    dx, dy = b[0] - a[0], b[1] - a[1]
    t = np.clip(((x - a[0]) * dx + (y - a[1]) * dy) / (dx * dx + dy * dy), 0, 1)
    return (x - a[0] - t * dx) ** 2 + (y - a[1] - t * dy) ** 2 <= radius * radius


def _polygon(x, y, vertices):
    """Point-in-convex-polygon mask, independent of vertex winding."""
    positive = np.ones(x.shape, dtype=bool)
    negative = np.ones(x.shape, dtype=bool)
    for a, b in zip(vertices, vertices[1:] + vertices[:1]):
        cross = (b[0] - a[0]) * (y - a[1]) - (b[1] - a[1]) * (x - a[0])
        positive &= cross >= 0
        negative &= cross <= 0
    return positive | negative


def body_side(local, normal, world, world_normal):
    """Quiet edge wear and a wine-red parcel emblem on the +z cargo side.

    The panel occupies x=-1.55..3.48, y=1.10..3.20. The cube is 1.60 m wide
    and .96 m high, centred at (0.60, 2.05), with three delivery marks to its
    right. These panel-space proportions compensate for the isometric view.
    """
    paint = _paint(world)
    x, y = world[:, 0], world[:, 1]
    side = (world_normal[:, 2] > .8) & (x >= -1.55) & (x <= 3.48) & (y >= 1.10) & (y <= 3.20)

    # A few grouped, shallow stains sit under fittings and along the lower
    # rail. Nothing adds noise across the clean centre of the enamel panel.
    stains = np.zeros(x.shape, dtype=bool)
    for left, bottom, width, height in [
        (-1.36, 2.88, .065, .22), (-1.22, 3.02, .035, .10),
        (3.17, 2.91, .055, .21), (3.29, 3.03, .04, .10),
        (-.83, 1.16, .16, .07), (-.69, 1.14, .07, .10),
        (1.65, 1.15, .17, .06), (2.76, 1.15, .12, .10),
        (2.86, 1.14, .09, .05),
    ]:
        stains |= (x >= left) & (x < left + width) & (y >= bottom) & (y < bottom + height)
    paint[side & stains] = (169, 153, 160, 255)

    scuffs = _segment(x, y, (-.96, 1.34), (-.58, 1.36), .018)
    scuffs |= _segment(x, y, (2.77, 2.80), (3.01, 2.79), .015)
    paint[side & scuffs] = (175, 161, 168, 255)

    # Nine connected segments make three faces of a printed cube. Keeping
    # this a surface decal avoids the heavy relief/outlines of tiny boxes.
    top = (.60, 2.53)
    left_top, right_top = (-.20, 2.32), (1.40, 2.32)
    centre = (.60, 2.11)
    left_bottom, right_bottom = (-.20, 1.78), (1.40, 1.78)
    bottom = (.60, 1.57)
    emblem = np.zeros(x.shape, dtype=bool)
    for a, b in [
        (top, left_top), (top, right_top),
        (left_top, centre), (right_top, centre),
        (left_top, left_bottom), (right_top, right_bottom),
        (left_bottom, bottom), (right_bottom, bottom), (centre, bottom),
    ]:
        emblem |= _segment(x, y, a, b, .056)
    for yy in [1.88, 2.06, 2.24]:
        emblem |= (x >= 1.63) & (x <= 2.24) & (np.abs(y - yy) <= .052)
    paint[side & emblem] = (119, 71, 74, 255)
    return None, paint


def roof_pattern(local, normal, world, world_normal):
    """Sparse shallow seams on the warm ivory roof, without stippling."""
    paint = _paint(world)
    x, z = world[:, 0], world[:, 2]
    roof = world_normal[:, 1] > .8
    # The material owns the overall warm ivory tone; these are deliberately
    # only a handful of subdued clusters over its otherwise uninterrupted top.
    seam = ((np.abs(x - 1.70) < .022) & (z > -.98) & (z < .92))
    seam |= ((np.abs(z + 1.02) < .018) & (x > -1.33) & (x < 3.28))
    paint[roof & seam] = (203, 187, 193, 255)
    worn = _segment(x, z, (-.55, .62), (-.24, .62), .025)
    worn |= _segment(x, z, (2.44, -.45), (2.68, -.43), .022)
    paint[roof & worn] = (206, 191, 196, 255)
    return None, paint


def glass_pattern(local, normal, world, world_normal):
    """Three readable blue reflection masses on the shaped +z cab window.

    Clip the primitive itself to the desired trapezoid in x=-3.4..-1.9,
    y=1.65..2.48. The pattern deliberately paints no frame or window outline.
    """
    paint = _paint(world)
    x, y = world[:, 0], world[:, 1]
    side = world_normal[:, 2] > .8
    paint[side] = (34, 45, 63, 255)

    broad = _polygon(x, y, [(-3.40, 2.48), (-2.84, 2.48), (-3.13, 1.78), (-3.40, 1.74)])
    paint[side & broad] = (65, 87, 108, 255)
    narrow = _polygon(x, y, [(-3.31, 2.48), (-3.20, 2.48), (-3.42, 1.97), (-3.47, 2.06)])
    paint[side & narrow] = (100, 124, 141, 255)

    # The rear part of the window stays dark enough to suggest the seat.
    rear = _polygon(x, y, [(-2.81, 2.48), (-2.14, 2.48), (-2.56, 1.96), (-2.98, 1.92)])
    paint[side & rear] = (45, 58, 79, 255)
    bottom = side & (y < 1.78)
    paint[bottom] = (26, 35, 51, 255)
    return None, paint
