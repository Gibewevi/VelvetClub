"""Tiny 2D pixel drawing helpers (lines, discs, outlines) for billboard details
such as palm fronds, flames and neon strokes. Everything is plotted pixel by
pixel at native resolution."""
from __future__ import annotations

import math

import numpy as np

from pa_core import ramp, hexrgb


class Pix:
    def __init__(self, w, h, ox, oy):
        self.img = np.zeros((h, w, 4), dtype=np.uint8)
        self.w, self.h, self.ox, self.oy = w, h, ox, oy

    def set(self, x, y, color, alpha=255):
        x = int(round(x)) if isinstance(x, float) else x
        y = int(round(y)) if isinstance(y, float) else y
        X, Y = x + self.ox, y + self.oy
        if 0 <= X < self.w and 0 <= Y < self.h:
            if len(color) == 4:
                self.img[Y, X] = color
            else:
                self.img[Y, X, :3] = color
                self.img[Y, X, 3] = alpha

    def get_alpha(self, x, y):
        X, Y = x + self.ox, y + self.oy
        if 0 <= X < self.w and 0 <= Y < self.h:
            return self.img[Y, X, 3]
        return 0

    def line(self, x0, y0, x1, y1, color):
        x0, y0, x1, y1 = int(round(x0)), int(round(y0)), int(round(x1)), int(round(y1))
        dx, dy = abs(x1 - x0), -abs(y1 - y0)
        sx = 1 if x0 < x1 else -1
        sy = 1 if y0 < y1 else -1
        err = dx + dy
        while True:
            self.set(x0, y0, color)
            if x0 == x1 and y0 == y1:
                break
            e2 = 2 * err
            if e2 >= dy:
                err += dy
                x0 += sx
            if e2 <= dx:
                err += dx
                y0 += sy

    def disc(self, cx, cy, r, color, ry=None):
        ry = ry or r
        for y in range(int(math.floor(cy - ry)) - 1, int(math.ceil(cy + ry)) + 2):
            for x in range(int(math.floor(cx - r)) - 1, int(math.ceil(cx + r)) + 2):
                if ((x + 0.5 - cx) / r) ** 2 + ((y + 0.5 - cy) / ry) ** 2 <= 1.0:
                    self.set(x, y, color)

    def outline(self, color):
        a = self.img[..., 3] > 0
        out = self.img.copy()
        h, w = a.shape
        for y in range(h):
            for x in range(w):
                if a[y, x]:
                    continue
                for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0)):
                    yy, xx = y + dy, x + dx
                    if 0 <= yy < h and 0 <= xx < w and a[yy, xx] and self.img[yy, xx, 3] == 255:
                        out[y, x, :3] = color
                        out[y, x, 3] = 255
                        break
        self.img = out


def palm(seed=0, fronds=7, green="4f9a3c", reach=1.0):
    """Palm canopy: tapered, serrated blades fanning upwards and drooping at
    the tips. Each blade is outlined on its own before being stacked, so
    overlapping fronds stay readable. Origin at the top of the trunk."""
    rng = np.random.default_rng(seed)
    g = ramp(green)
    W, H, OX, OY = 72, 60, 36, 36
    angles = [math.radians(-170 + 160 * i / (fronds - 1)) + rng.uniform(-0.1, 0.1) for i in range(fronds)]
    depth = rng.permutation(fronds)
    out = Pix(W, H, OX, OY)
    for i in sorted(range(fronds), key=lambda k: depth[k]):
        a = angles[i]
        dark = depth[i] < fronds // 3
        up = -math.sin(a)
        length = rng.uniform(15, 19) * reach
        blade = Pix(W, H, OX, OY)
        pts = []
        for k in range(int(length * 2) + 1):
            t = k / (length * 2)
            d = t * length
            x = math.cos(a) * d * 1.2
            y = math.sin(a) * d * 0.95 + t * t * length * (0.3 + 0.6 * (1 - up))
            pts.append((x, y, t))
        for k in range(1, len(pts)):
            x, y, t = pts[k]
            px, py, _ = pts[k - 1]
            dx, dy = x - px, y - py
            n = math.hypot(dx, dy) or 1
            nx, ny = -dy / n, dx / n
            width = 2.1 * math.sin(math.pi * min(1.0, 0.1 + t)) ** 0.9
            serr = 0.7 if (k // 3) % 2 == 0 else 0.0
            for s in (-1, 1):
                w = width + serr
                j = 0.5
                while j <= w:
                    cx = x + s * nx * j
                    cy = y + s * ny * j
                    upper = (s * ny) < 0
                    if dark:
                        col = g[2] if upper else g[1]
                    else:
                        col = (g[4] if j < w - 0.7 else g[3]) if upper else g[3] if j < 1.0 else g[2]
                    blade.set(int(round(cx)), int(round(cy)), col)
                    j += 0.5
            blade.set(int(round(x)), int(round(y)), g[3] if dark else g[2])
        blade.outline(g[0])
        m = blade.img[..., 3] > 0
        out.img[m] = blade.img[m]
    return out


def monstera(seed=0, green="2f7a44"):
    """Big split leaves of a monstera on long stems. Origin at the soil."""
    g = ramp(green)
    out = Pix(52, 44, 26, 38)
    leaves = [(-11, -12, 7, 5, -0.7), (11, -13, 7, 5, 0.7), (-7, -22, 8, 6, -0.35), (8, -24, 8, 6, 0.35), (0, -30, 8, 6, 0.0)]
    for n, (cx, cy, rx, ry, tilt) in enumerate(leaves):
        out.line(0, 0, cx * 0.8, cy + ry * 0.5, g[1])
        leaf = Pix(52, 44, 26, 38)
        c, s_ = math.cos(tilt), math.sin(tilt)
        for y in range(int(cy - ry - 2), int(cy + ry + 3)):
            for x in range(int(cx - rx - 2), int(cx + rx + 3)):
                dx, dy = x + 0.5 - cx, y + 0.5 - cy
                u = dx * c + dy * s_
                v = -dx * s_ + dy * c
                d = (u / rx) ** 2 + (v / ry) ** 2
                if d > 1.0:
                    continue
                # the typical slits, cut from the edge towards the midrib
                ang = math.atan2(v, u)
                if d > 0.35 and abs(math.sin(ang * 3.0 + n)) < 0.18:
                    continue
                col = g[3] if v < 0 else g[2]
                if abs(v) < 0.6:
                    col = g[1]
                if d < 0.25 and v < 0:
                    col = g[4]
                leaf.set(x, y, col)
        leaf.outline(g[0])
        m = leaf.img[..., 3] > 0
        out.img[m] = leaf.img[m]
    return out


def strelitzia_flowers(pix, spots):
    """Bird-of-paradise heads on tall stalks: an orange crest, a blue tongue,
    a green beak."""
    for (x, y) in spots:
        pix.line(0, 2, x - 1, y + 1, (52, 96, 52))
        pix.line(1, 2, x, y + 1, (70, 124, 64))
        for dx, dy, col in ((0, 0, (60, 110, 60)), (1, 0, (60, 110, 60)), (2, -1, (60, 110, 60)), (0, -1, (255, 150, 40)),
                            (-1, -2, (255, 170, 60)), (0, -3, (255, 120, 30)), (1, -2, (255, 190, 80)), (1, -1, (70, 110, 230))):
            pix.set(x + dx, y + dy, col)
    return pix


def fairy_lights(pix, frame, seed=5, count=20):
    """Small bulbs scattered along the leaves; each frame lights a different
    two thirds of them, in warm white, pink and blue."""
    rng = np.random.default_rng(seed)
    solid = np.argwhere(pix.img[..., 3] > 0)
    if len(solid) == 0:
        return pix
    picks = solid[rng.choice(len(solid), size=min(count, len(solid)), replace=False)]
    colors = [(255, 226, 140), (255, 140, 210), (140, 216, 255)]
    for i, (y, x) in enumerate(picks):
        lit = (i + frame) % 3 != 0
        c = colors[(i + frame) % 3] if lit else (90, 70, 60)
        pix.img[y, x, :3] = c
        pix.img[y, x, 3] = 255
        if lit and 0 < x < pix.w - 1:
            glow = tuple(min(255, int(v * 0.6 + 60)) for v in c)
            for xx in (x - 1, x + 1):
                if pix.img[y, xx, 3] > 0:
                    pix.img[y, xx, :3] = glow
    return pix


def bush(seed=0, w=18, h=12, green="3f7e3a"):
    rng = np.random.default_rng(seed)
    g = ramp(green)
    pix = Pix(w + 6, h + 6, (w + 6) // 2, h + 3)
    for k in range(34):
        cx = rng.uniform(-w / 2 + 3, w / 2 - 3)
        cy = rng.uniform(-h + 3, -2)
        r = rng.uniform(2.2, 3.6)
        pix.disc(cx, cy, r, g[2])
    for k in range(40):
        cx = rng.uniform(-w / 2 + 2, w / 2 - 2)
        cy = rng.uniform(-h + 2, -3)
        top = (cy + h) / h
        pix.set(cx, cy, g[4] if cy < -h * 0.55 and cx < 1 else g[3])
        pix.set(cx + 1, cy, g[3])
    pix.outline(g[0])
    return pix


def tree(seed=0, w=44, h=40, green="2f5e36"):
    """Bushy night-time tree: a bumpy silhouette of leaf clumps, each shaded
    dark at the lower right and lit at the upper left, drawn back to front."""
    rng = np.random.default_rng(seed)
    g = ramp(green)
    pix = Pix(w + 10, h + 10, (w + 10) // 2, h + 5)
    cx0, cy0 = 0.0, -h / 2
    clumps = []
    step = 5.2
    y = cy0 - h / 2 + 5
    while y <= cy0 + h / 2 - 4:
        x = cx0 - w / 2 + 5 + (rng.uniform(0, step) if True else 0)
        while x <= cx0 + w / 2 - 5:
            u = (x - cx0) / (w / 2 - 3)
            v = (y - cy0) / (h / 2 - 3)
            if u * u + v * v <= 1.0:
                clumps.append((y + rng.uniform(-1.5, 1.5), x + rng.uniform(-1.5, 1.5), rng.uniform(4.6, 6.4)))
            x += step
        y += step * 0.8
    clumps.sort()
    # dark underlayer so gaps read as depth
    for cy, cx, r in clumps:
        pix.disc(cx + 1, cy + 1.5, r, g[0])
    for cy, cx, r in clumps:
        u = (cx - cx0) / (w / 2)
        v = (cy - cy0) / (h / 2)
        light = -u * 0.6 - v * 0.8
        mid = g[1] if light < -0.45 else (g[2] if light < 0.15 else g[3])
        pix.disc(cx, cy, r, g[1] if light < 0.15 else g[2])
        pix.disc(cx - 0.8, cy - 0.9, r - 1.1, mid)
        if light > -0.3:
            pix.disc(cx - 1.6, cy - 2.0, max(r - 3.4, 1.0), g[3] if light < 0.35 else g[4])
    pix.outline(g[0])
    return pix


def heart_points(cx, cy, scale):
    pts = []
    for i in range(200):
        t = i / 200 * 2 * math.pi
        x = 16 * math.sin(t) ** 3
        y = 13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t)
        pts.append((cx + x * scale, cy + y * scale))
    return pts
