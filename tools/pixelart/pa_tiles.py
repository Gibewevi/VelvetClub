"""Floors, walls, openings, exterior props and light halos.

Floors and walls are exported as *tone maps* (R = tone index * 40) so the
game can colour them with any finish colour through a hue-shifted ramp;
fixed-colour parts (doors, windows, props) are plain RGBA.
"""
from __future__ import annotations

import math

import numpy as np

from pa_core import (HALF_W, HALF_H, PX_PER_M_Y, WALL_H, LOW_WALL_H, WALL_T, ramp, hexrgb, mix, INK,
                     save, write_json, preview, hash01)
from pa_iso import Mat, box, cyl, ell, lathe, rod, render, finish, screen, dot, turn, rot_y
from pa_draw2d import Pix, bush
import pa_trees

TONE_SCALE = 40
FLOOR_PERIOD = 4                   # metres; texture = 32P x 16P px
WALL_M = WALL_H / PX_PER_M_Y       # 2.333 m
LOW_M = LOW_WALL_H / PX_PER_M_Y    # 0.5 m


# ------------------------------------------------------------------ noise

def vnoise(X, Z, freq, seed, period=None):
    """Smooth value noise in [0, 1]; periodic when `period` (metres) is given."""
    x = X * freq
    z = Z * freq
    x0 = np.floor(x).astype(int)
    z0 = np.floor(z).astype(int)
    fx = x - x0
    fz = z - z0
    fx = fx * fx * (3 - 2 * fx)
    fz = fz * fz * (3 - 2 * fz)
    n = None if period is None else int(round(period * freq))

    def h(a, b):
        if n:
            a = np.mod(a, n)
            b = np.mod(b, n)
        v = (a * 374761393 + b * 668265263 + seed * 2654435761) & 0xFFFFFFFF
        v = (v ^ (v >> 13)) * 1274126177 & 0xFFFFFFFF
        return ((v ^ (v >> 16)) & 0xFFFF) / 65535.0
    a = h(x0, z0)
    b = h(x0 + 1, z0)
    c = h(x0, z0 + 1)
    d = h(x0 + 1, z0 + 1)
    return a + (b - a) * fx + (c - a) * fz + (a - b - c + d) * fx * fz


# ------------------------------------------------------------------ floors

def floor_pattern(name, X, Z, seed=0):
    """Tone (0..5) for world floor positions. Period FLOOR_PERIOD metres."""
    P = FLOOR_PERIOD
    tone = np.full(X.shape, 3, dtype=int)
    if name in ("boards", "boards_worn"):
        row = np.floor(Z * 4).astype(int)                         # 0.25 m planks along x
        fz = Z * 4 - row
        offset = np.array([hash01(r % (P * 4), 7) for r in range(P * 4)])[row % (P * 4)] * P
        length = 1.5
        u = np.mod(X + offset, length)
        idx = np.floor(np.mod(X + offset, P) / length).astype(int)
        var = np.array([[hash01(r, k, 11) for k in range(4)] for r in range(P * 4)])[row % (P * 4), idx % 4]
        tone[var > 0.72] = 4
        tone[var < 0.22] = 2
        tone[fz < 0.25] = 1                                       # seam between planks
        tone[(u < 1 / 16)] = 1                                    # butt joint
        grain = (np.mod(np.floor(X * 16) * 7 + row * 13, 23) == 0) & (fz > 0.4)
        tone[grain & (tone >= 3)] -= 1
        if name == "boards_worn":
            wear = (np.sin(X * 1.7 + np.sin(Z * 2.3)) * np.sin(Z * 1.3 + 1.1) > 0.55)
            tone[wear & (tone == 3)] = 4
            scratch = np.mod(np.floor(X * 16) + np.floor(Z * 16) * 3, 37) == 0
            tone[scratch & (fz > 0.3)] = 2
    elif name == "tile":
        gx = np.mod(X, 0.5)
        gz = np.mod(Z, 0.5)
        ti = np.floor(X / 0.5).astype(int) % (P * 2)
        tj = np.floor(Z / 0.5).astype(int) % (P * 2)
        var = np.vectorize(lambda a, b: hash01(a, b, 3))(ti, tj)
        tone[var > 0.8] = 4
        tone[var < 0.15] = 2
        tone[(gx < 1 / 16) | (gz < 1 / 16)] = 1
        tone[((gx < 3 / 16) & (gx >= 1 / 16) & (gz >= 1 / 16)) | ((gz < 3 / 16) & (gz >= 1 / 16) & (gx >= 1 / 16))] = np.minimum(
            tone[((gx < 3 / 16) & (gx >= 1 / 16) & (gz >= 1 / 16)) | ((gz < 3 / 16) & (gz >= 1 / 16) & (gx >= 1 / 16))] + 1, 5)
    elif name == "terrazzo":
        h = np.vectorize(lambda a, b: hash01(a, b, 19))(np.floor(X * 16).astype(int) % (P * 16), np.floor(Z * 16).astype(int) % (P * 16))
        tone[h > 0.93] = 1
        tone[(h > 0.86) & (h <= 0.93)] = 4
        tone[(h > 0.80) & (h <= 0.86)] = 2
        tone[h < 0.03] = 5
    elif name == "plain":
        h = np.vectorize(lambda a, b: hash01(a, b, 23))(np.floor(X * 8).astype(int) % (P * 8), np.floor(Z * 8).astype(int) % (P * 8))
        tone[h > 0.9] = 2
        tone[h < 0.08] = 4
        crack = np.abs(np.sin(X * 2.1) * 0.4 + 1.3 - Z) < 1 / 16
        tone[crack & (np.mod(X, 4) < 1.4)] = 1
    elif name == "carpet":
        d = np.mod(X + Z, 1.0)
        e = np.mod(X - Z, 1.0)
        tone[(d < 1 / 16) | (e < 1 / 16)] = 2
        checker = (np.floor(X * 16) + np.floor(Z * 16)) % 2 == 0
        h = np.vectorize(lambda a, b: hash01(a, b, 29))(np.floor(X * 16).astype(int) % (P * 16), np.floor(Z * 16).astype(int) % (P * 16))
        tone[(h > 0.9) & (tone == 3)] = 4
        tone[(h < 0.06) & (tone == 3)] = 2
    elif name == "carpet_worn":
        # Old fitted carpet: faint diamond weave, bald trodden paths, dark
        # stains, frayed seams and a few cigarette burns.
        weave = np.vectorize(lambda a, b: hash01(a, b, 50))(np.floor(X * 16).astype(int) % (P * 16), np.floor(Z * 16).astype(int) % (P * 16))
        tone[weave > 0.88] = 2
        tone[weave < 0.05] = 4
        bald = vnoise(X, Z, 1.1, 51, P) * 0.7 + vnoise(X, Z, 3.3, 52, P) * 0.3
        tone[(bald > 0.62) & (tone >= 2)] = 4
        tone[(bald > 0.72) & (tone >= 2)] = 5
        stain = vnoise(X, Z, 1.7, 53, P) * 0.6 + vnoise(X, Z, 5.0, 54, P) * 0.4
        tone[(stain > 0.64)] = 2
        tone[(stain > 0.73)] = 1
        seam = np.abs(np.mod(Z, 2.0) - 1.0) < 1 / 16
        fray = vnoise(X * 3, Z, 6.0, 55, P) > 0.55
        tone[seam & fray] = 1
        burns = np.vectorize(lambda a, b: hash01(a, b, 56))(np.floor(X * 8).astype(int) % (P * 8), np.floor(Z * 8).astype(int) % (P * 8)) > 0.985
        tone[burns] = 0
    elif name == "pavers":
        # 1 m slabs with a dark joint and a 1 px lit bevel on their far edges.
        gx = np.mod(X, 1.0)
        gz = np.mod(Z, 1.0)
        ti = np.floor(X).astype(int) % P
        tj = np.floor(Z).astype(int) % P
        var = np.vectorize(lambda a, b: hash01(a, b, 31))(ti, tj)
        tone[var < 0.18] = 2
        bevel = ((gx >= 1 / 16) & (gx < 2 / 16)) | ((gz >= 1 / 16) & (gz < 2 / 16))
        tone[bevel] = 4
        tone[(gx < 1 / 16) | (gz < 1 / 16)] = 1
        h = np.vectorize(lambda a, b: hash01(a, b, 37))(np.floor(X * 16).astype(int) % (P * 16), np.floor(Z * 16).astype(int) % (P * 16))
        tone[(h > 0.97) & (tone == 3)] = 2
    elif name == "boards_damaged":
        # Old planks: worn boards, large dark stains, a few missing strips.
        tone = floor_pattern("boards_worn", X, Z)
        stain = vnoise(X, Z, 1.3, 11, P) * 0.65 + vnoise(X, Z, 3.1, 12, P) * 0.35
        tone[(stain > 0.60) & (tone >= 2)] = 2
        tone[(stain > 0.70) & (tone >= 1)] = 1
        row = np.floor(Z * 4).astype(int)
        seg = np.floor(np.mod(X + row * 0.7, P) / 1.0).astype(int)
        gone = np.vectorize(lambda a, b: hash01(a % (P * 4), b % P, 13))(row, seg) > 0.94
        tone[gone] = 0
        grit = vnoise(X, Z, 9.0, 14, P) > 0.8
        tone[grit & (tone == 3)] = 2
        tone[(tone == 4) & (vnoise(X, Z, 5.0, 15, P) > 0.35)] = 3
    elif name == "tile_dirty":
        tone = floor_pattern("tile", X, Z)
        grime = vnoise(X, Z, 1.6, 21, P) * 0.6 + vnoise(X, Z, 4.3, 22, P) * 0.4
        tone[(grime > 0.58) & (tone >= 2)] -= 1
        tone[(grime > 0.72) & (tone >= 2)] = 1
        ti = np.floor(X / 0.5).astype(int) % (P * 2)
        tj = np.floor(Z / 0.5).astype(int) % (P * 2)
        chipped = np.vectorize(lambda a, b: hash01(a, b, 23))(ti, tj) > 0.82
        corner = (np.mod(X, 0.5) + np.mod(Z, 0.5)) < 0.19
        tone[chipped & corner] = 1
    elif name == "asphalt":
        h = np.vectorize(lambda a, b: hash01(a, b, 41))(np.floor(X * 16).astype(int) % (P * 16), np.floor(Z * 16).astype(int) % (P * 16))
        tone[h > 0.85] = 2
        tone[h < 0.07] = 4
    elif name == "asphalt_cracked":
        # old asphalt: grit, lighter worn stretches and darker tar repairs,
        # a network of fine cracks, a crazed area here and there, rare holes
        h = np.vectorize(lambda a, b: hash01(a, b, 61))(np.floor(X * 16).astype(int) % (P * 16), np.floor(Z * 16).astype(int) % (P * 16))
        tone[h > 0.88] = 2
        tone[h < 0.08] = 4
        wear = vnoise(X, Z, 0.75, 62, P) * 0.6 + vnoise(X, Z, 2.0, 63, P) * 0.4
        tone[(wear > 0.68) & (tone == 3)] = 2
        tone[(wear < 0.3) & (tone == 3) & (h > 0.55)] = 4
        c1 = np.abs(vnoise(X, Z, 1.25, 64, P) - 0.5)
        c2 = np.abs(vnoise(X, Z, 2.75, 65, P) - 0.5)
        crack = (c1 < 0.022) | ((c2 < 0.018) & (vnoise(X, Z, 1.5, 66, P) > 0.5))
        tone[crack] = 1
        edge = ((c1 >= 0.022) & (c1 < 0.034)) & (tone == 3)
        tone[edge & (h > 0.5)] = 4
        craze = vnoise(X, Z, 0.9, 67, P) > 0.74
        cells = (np.abs(vnoise(X, Z, 6.0, 68, P) - 0.5) < 0.045)
        tone[craze & cells] = 1
        hole = vnoise(X, Z, 1.9, 69, P) > 0.9
        tone[hole] = 1
        tone[hole & (vnoise(X, Z, 5.0, 70, P) > 0.6)] = 0
    elif name == "slabs":
        # 50 cm concrete slabs, joints, a few cracked or sunken ones
        gx = np.mod(X, 0.5)
        gz = np.mod(Z, 0.5)
        ti = np.floor(X / 0.5).astype(int) % (P * 2)
        tj = np.floor(Z / 0.5).astype(int) % (P * 2)
        var = np.vectorize(lambda a, b: hash01(a, b, 71))(ti, tj)
        tone[var < 0.14] = 2
        tone[var > 0.94] = 4
        tone[(gx < 1 / 32) | (gz < 1 / 32)] = 2
        broken = np.vectorize(lambda a, b: hash01(a, b, 72))(ti, tj) > 0.85
        diag = np.abs((gx - gz) - np.vectorize(lambda a, b: (hash01(a, b, 73) - 0.5) * 0.3)(ti, tj)) < 0.018
        tone[broken & diag] = 1
        grime = vnoise(X, Z, 1.4, 74, P) > 0.7
        tone[grime & (tone == 3)] = 2
    elif name == "concrete":
        # freshly poured slab: fine grit, trowel sweeps, a few darker patches
        h = np.vectorize(lambda a, b: hash01(a, b, 81))(np.floor(X * 16).astype(int) % (P * 16), np.floor(Z * 16).astype(int) % (P * 16))
        tone[h > 0.9] = 2
        tone[h < 0.05] = 4
        sweep = (np.abs(vnoise(X, Z, 1.6, 82, P) - 0.5) < 0.02) & (h > 0.35)
        tone[sweep & (tone == 3)] = 4
        patch = vnoise(X, Z, 0.9, 83, P) > 0.72
        tone[patch & (tone == 3)] = 2
    elif name == "dirt":
        # site ground: packed earth, clods and pebbles
        h = np.vectorize(lambda a, b: hash01(a, b, 85))(np.floor(X * 16).astype(int) % (P * 16), np.floor(Z * 16).astype(int) % (P * 16))
        clod = vnoise(X, Z, 2.2, 86, P)
        tone[clod > 0.64] = 2
        tone[clod < 0.22] = 4
        tone[h > 0.95] = 4
        tone[h > 0.985] = 5
        tone[h < 0.04] = 1
    elif name == "grass":
        h = np.vectorize(lambda a, b: hash01(a, b, 43))(np.floor(X * 16).astype(int) % (P * 16), np.floor(Z * 16).astype(int) % (P * 16))
        tone[h > 0.7] = 2
        tone[h < 0.12] = 4
        tone[h < 0.03] = 5
    return np.clip(tone, 0, 5)


def floor_texture(name):
    P = FLOOR_PERIOD
    W, H = 32 * P, 16 * P
    j, i = np.mgrid[0:H, 0:W]
    sx = i + 0.5
    sy = j + 0.5
    X = (sx / HALF_W + sy / HALF_H) / 2
    Z = (sy / HALF_H - sx / HALF_W) / 2
    X = np.mod(X, P)
    Z = np.mod(Z, P)
    tone = floor_pattern(name, X, Z)
    img = np.zeros((H, W, 4), dtype=np.uint8)
    img[..., 0] = tone * TONE_SCALE
    img[..., 3] = 255
    return img


FLOOR_PATTERNS = ["boards", "boards_worn", "boards_damaged", "tile", "tile_dirty", "terrazzo", "plain", "carpet", "carpet_worn", "pavers",
                  "asphalt", "grass", "asphalt_cracked", "slabs", "concrete", "dirt"]


# ------------------------------------------------------------------ walls

def idx_mat(slot, name=""):
    """A material whose 'colours' are palette indices (R = index * 4)."""
    tones = [((slot * 6 + t) * 4, 0, 0) for t in range(6)]
    m = Mat(tones=tones, name=name)
    m.slot = slot
    return m


WALL_FACE = idx_mat(0, "face")
WALL_CAP = idx_mat(1, "cap")
WALL_OUT = idx_mat(2, "outside")
WALL_BASE = idx_mat(3, "base")
INK_INDEX = 24
PLASTER_SLOT = 5          # indices 30..35: bare plaster behind peeled paint
WALL_VARIANTS = 4


def plaster(tone):
    return ((PLASTER_SLOT * 6 + tone) * 4, 0, 0, 255)


def wall_pattern(finish_name, axis, variant=0):
    """Pattern on a wall face in wall coordinates u (along) and v (height).
    `variant` shifts the pattern so neighbouring segments differ."""
    def pat(p, ln, w, n):
        u = (w[:, 0] if axis == "x" else w[:, 2]) + variant * 1.0 + (0.37 if axis == "z" else 0.0)
        v = w[:, 1]
        face = np.abs(ln[:, 1]) < 0.5
        d = np.zeros(len(p), dtype=int)
        paint = np.zeros((len(p), 4), dtype=np.uint8)
        if finish_name == "wallpaper_torn":
            # Old striped wallpaper with a small motif, torn strips hanging
            # off and bare plaster behind, water stains at the bottom.
            strip = np.floor(u / 0.5).astype(int) % 8
            local = np.mod(u, 0.5)
            stripe = np.abs(local - 0.25) < 0.07
            d[face & stripe] = 1
            motif = (np.abs(np.mod(local, 0.25) - 0.125) + np.abs(np.mod(v, 0.3) - 0.15) * 0.8) < 0.035
            d[face & motif & ~stripe] = -1
            seam = local < 1 / 32
            d[face & seam] = -1
            fade = vnoise(u, v, 1.5, 61, 4)
            d[face & (fade > 0.66)] -= 1
            torn_strip = np.array([hash01(int(k), 3, 62) for k in strip]) > 0.62
            edge_noise = vnoise(u, v, 8.0, 63, 4) * 0.25
            top_tear = torn_strip & (v > 1.45 + edge_noise * 2.4 - np.array([hash01(int(k), 5, 64) for k in strip]) * 0.7)
            patch = (vnoise(u, v, 2.6, 65, 4) * 0.7 + vnoise(u, v, 7.0, 66, 4) * 0.3) > 0.74
            hole = face & (top_tear | patch) & (v > 0.12)
            lip = face & ~hole & (v > 0.12) & (
                (torn_strip & (v > 1.39 + edge_noise * 2.4 - np.array([hash01(int(k), 5, 64) for k in strip]) * 0.7)) |
                ((vnoise(u, v, 2.6, 65, 4) * 0.7 + vnoise(u, v, 7.0, 66, 4) * 0.3) > 0.70))
            d[lip] = 2
            paint[hole] = plaster(3)
            paint[hole & (vnoise(u, v, 12.0, 67, 4) > 0.7)] = plaster(2)
            paint[hole & (np.abs(vnoise(u, v, 10.0, 68, 4) - 0.5) < 0.03)] = plaster(1)
            damp = face & ~hole & (v < 0.3 + 0.12 * vnoise(u, v, 4.0, 69, 4))
            d[damp] -= 1
            return d, paint
        if finish_name in ("decay", "tile_dirty"):
            if finish_name == "decay":
                mottle = vnoise(u, v, 7.0, 31, 4)
                d[face & (mottle > 0.78)] = -1
                d[face & (mottle < 0.12)] = 1
            else:
                mortar = (np.mod(v, 0.25) < 1 / 48) | (np.mod(u, 0.25) < 1 / 32)
                d[face & mortar] = 1
                tid = (np.floor(u / 0.25).astype(int) % 16) * 31 + np.floor(v / 0.25).astype(int)
                grimy = np.array([hash01(t, 3, 37) for t in tid])
                d[face & (grimy > 0.72) & ~mortar] = -1
            # peeled paint / missing tiles reveal bare plaster, with a dark rim
            peel = vnoise(u, v, 2.25, 32, 4) * 0.7 + vnoise(u, v, 6.0, 33, 4) * 0.3
            hole = face & (peel > (0.64 if finish_name == "decay" else 0.7)) & (v > 0.15)
            rim = face & (peel > (0.60 if finish_name == "decay" else 0.67)) & ~hole & (v > 0.12)
            d[rim] = -2
            lit = hole & (vnoise(u + 0.04, v - 0.04, 2.25, 32, 4) * 0.7 + vnoise(u + 0.04, v - 0.04, 6.0, 33, 4) * 0.3 < 0.66)
            paint[hole] = plaster(3)
            paint[lit] = plaster(4)
            crack = hole & (np.abs(vnoise(u, v, 11.0, 34, 4) - 0.5) < 0.03)
            paint[crack] = plaster(1)
            # damp band along the floor with a ragged top edge, and drips
            damp = face & (v < 0.28 + 0.14 * vnoise(u, v, 4.0, 35, 4)) & ~hole
            d[damp] -= 1
            drip_col = np.array([hash01(int(a) % 64, 5, 36) for a in np.floor(u * 16)]) > 0.93
            drip_len = np.array([hash01(int(a) % 64, 7, 38) for a in np.floor(u * 16)])
            d[face & drip_col & (v > 2.2 - drip_len * 1.2) & ~hole] -= 1
            fine = face & ~hole & (np.abs(vnoise(u, v, 9.0, 39, 4) - 0.5) < 0.012)
            d[fine] = -2
            return d, paint
        if finish_name == "brick":
            course = np.floor(v / 0.125).astype(int)
            off = (course % 2) * 0.125
            uu = np.mod(u + off, 0.25)
            bid = np.floor((u + off) / 0.25).astype(int) % 16
            var = np.array([hash01(a, b, 5) for a, b in zip(bid, course)])
            d[face & (var > 0.9)] = 1
            d[face & (var < 0.07)] = -1
            mortar = (np.mod(v, 0.125) < 1 / 48) | (uu < 1 / 32)
            d[face & mortar] = -1
        elif finish_name == "tile":
            mortar = (np.mod(v, 0.25) < 1 / 48) | (np.mod(u, 0.25) < 1 / 32)
            d[face & mortar] = 1
        elif finish_name == "paper":
            dd = np.mod(u * 4 + v * 2.4, 1.0)
            ee = np.mod(u * 4 - v * 2.4, 1.0)
            d[face & ((dd < 0.07) | (ee < 0.07))] = -1
            d[face & (np.abs(np.mod(v, 0.6) - 0.3) < 1 / 48) & (np.mod(u * 4, 1) < 0.2)] = 1
        elif finish_name == "peeling":
            patch = np.sin(u * 4.712 + np.sin(v * 3.1)) * np.sin(v * 4.7 + u * 1.571) > 0.62
            d[face & patch] = -1
            edge = np.sin(u * 4.712 + np.sin(v * 3.1)) * np.sin(v * 4.7 + u * 1.571) > 0.55
            d[face & edge & ~patch] = 1
        else:
            h = np.array([hash01(int(a) % 64, int(b), 9) for a, b in zip(np.floor(u * 16), np.floor(v * 24))])
            d[face & (h > 0.97)] = -1
        return d
    return pat


WALL_FINISH_PATTERNS = {"worn_plaster": "brick", "peeling_paint": "peeling", "paint": "plain", "wallpaper": "paper",
                        "wall_tile": "tile", "decay": "decay", "tile_dirty": "tile_dirty", "torn_wallpaper": "wallpaper_torn"}


def wall_prims(axis, kind, pattern_name, variant=0):
    """Prims for a 1 m wall segment starting at the origin along `axis`."""
    t2 = WALL_T / 2
    pat = wall_pattern(pattern_name, axis, variant)
    H = WALL_M if kind.startswith("full") else LOW_M
    face = WALL_FACE if kind.startswith("full") else WALL_OUT
    pieces = []
    if kind in ("full", "low"):
        pieces.append((0.0, 1.0, 0.0, H))
    elif kind == "full_door":
        pieces += [(0.0, 0.1, 0.0, H), (0.9, 1.0, 0.0, H), (0.1, 0.9, 2.1, H)]
    elif kind == "full_door_l":
        # first metre of a double door: the jamb on its left, the lintel runs on
        pieces += [(0.0, 0.1, 0.0, H), (0.1, 1.0, 2.1, H)]
    elif kind == "full_door_r":
        pieces += [(0.9, 1.0, 0.0, H), (0.0, 0.9, 2.1, H)]
    elif kind == "full_window":
        pieces += [(0.0, 0.15, 0.0, H), (0.85, 1.0, 0.0, H), (0.15, 0.85, 0.0, 0.95), (0.15, 0.85, 1.95, H)]
    elif kind == "low_window":
        pieces.append((0.0, 1.0, 0.0, H))
    prims = []
    for (a, b, y0, y1) in pieces:
        top = y1 >= H - 1e-6
        yb = y1 - (0.06 if top else 0.0)
        if axis == "x":
            prims.append(box(a, y0, -t2, b, yb, t2, face, pattern=pat))
            if top:
                prims.append(box(a, yb, -t2 - 0.02, b, y1, t2 + 0.02, WALL_CAP))
            if y0 == 0.0 and kind.startswith("full"):
                prims.append(box(a, 0.0, t2, b, 0.1, t2 + 0.03, WALL_BASE))
        else:
            prims.append(box(-t2, y0, a, t2, yb, b, face, pattern=pat))
            if top:
                prims.append(box(-t2 - 0.02, yb, a, t2 + 0.02, y1, b, WALL_CAP))
            if y0 == 0.0 and kind.startswith("full"):
                prims.append(box(t2, 0.0, a, t2 + 0.03, 0.1, b, WALL_BASE))
    return prims


def post_prims(kind):
    t2 = WALL_T / 2 + 0.01
    if kind == "full":
        return [box(-t2, 0, -t2, t2, WALL_M - 0.06, t2, WALL_FACE), box(-t2 - 0.02, WALL_M - 0.06, -t2 - 0.02, t2 + 0.02, WALL_M, t2 + 0.02, WALL_CAP)]
    # low wall end posts are darker and slightly taller, like the artwork
    return [box(-t2 - 0.01, 0, -t2 - 0.01, t2 + 0.01, LOW_M + 0.14, t2 + 0.01, WALL_BASE)]


def render_idx(prims, bounds=None):
    cv = render(prims, bounds=bounds, edge_light=True, lines=True)
    finish(cv, outline_color=(INK_INDEX * 4, 0, 0))
    return cv


def render_segment(axis, kind, pattern, variant, ends=""):
    """Render the segment between two plain neighbours, then keep only the
    columns of the middle metre: collinear segments join without a seam.
    `ends` names the ends where the wall stops ("0" its start, "1" its end):
    no neighbour there, so the wall shows its real end (edge, end face,
    cap) and the picture keeps those columns."""
    base = "full" if kind.startswith("full") else "low"
    prims = []
    for offset, k in ((-1, base), (0, kind), (1, base)):
        if (offset == -1 and "0" in ends) or (offset == 1 and "1" in ends):
            continue
        # the neighbours already sit at world u -1 / +1, so they share the
        # middle segment's variant offset and the pattern stays continuous
        part = wall_prims(axis, k, pattern, variant)
        shift = np.array([offset, 0, 0]) if axis == "x" else np.array([0, 0, offset])
        for p in part:
            p.T = p.T + shift
        prims += part
    cv = render_idx(prims)
    t2 = WALL_T / 2
    c0, c1 = (-HALF_W * t2 * 1.0, HALF_W * (1 - t2)) if axis == "x" else (HALF_W * (t2 - 1), HALF_W * t2)
    # a wall that stops: keep its outline at the start, its end face at the end
    if axis == "x":
        c0 -= 2 if "0" in ends else 0
        c1 = HALF_W * (1 + t2) + 2 if "1" in ends else c1
    else:
        c1 += 2 if "0" in ends else 0
        c0 = HALF_W * (-1 - t2) - 2 if "1" in ends else c0
    cols = np.arange(cv.w) - cv.ox
    drop = (cols < c0) | (cols >= c1)
    cv.rgba[:, drop] = 0
    return cv


# ------------------------------------------------------------------ door and window overlays (RGBA)

DOOR = Mat("5a3424")
DOOR_FRAME = Mat("2e2230")
GLASS = Mat("7fa7c8")
CURTAIN = Mat("a8203c")
BRASS = Mat("e0ae48")


DOOR_ANGLES = (0, 35, 80)      # closed, ajar, open: the frames of a swing
LEAF_T = 0.13                  # a leaf half as thick as the wall, set back in it


def door_frame_prims(axis, a0, a1, left=True, right=True):
    """The casing around a door: jambs and lintel through the whole wall,
    standing a little proud of both faces."""
    t2 = WALL_T / 2

    def B(a, y0, b, y1, z0, z1, mat, **kw):
        if axis == "x":
            return box(a, y0, z0, b, y1, z1, mat, **kw)
        return box(z0, y0, a, z1, y1, b, mat, **kw)
    prims = []
    if left:
        prims.append(B(0.07, 0, 0.13, 2.16, -t2 - 0.03, t2 + 0.03, DOOR_FRAME))
    if right:
        prims.append(B(0.87, 0, 0.93, 2.16, -t2 - 0.03, t2 + 0.03, DOOR_FRAME))
    prims.append(B(a0, 2.1, a1, 2.18, -t2 - 0.03, t2 + 0.03, DOOR_FRAME))
    return prims


def swing(prims, axis, hinge, toward, angle):
    """Turn a leaf about its hinge (vertical, on the front face of the leaf)
    so it opens into the room in front of the wall. toward = +1 when the
    leaf runs from its hinge towards +u, -1 towards -u."""
    if angle == 0:
        return prims
    t2 = WALL_T / 2
    front = -t2 + LEAF_T
    deg = (-angle if toward > 0 else angle) if axis == "x" else (angle if toward > 0 else -angle)
    pivot = (hinge, 0, front) if axis == "x" else (front, 0, hinge)
    return turn(prims, rot_y(deg), pivot)


def door_prims(axis, state=0):
    """A single door: casing through the wall, a solid leaf set back in the
    opening (its reveal shows), a glazed top and a panel, a brass knob.
    state 0 closed, 1 ajar, 2 open: the leaf swings into the room in front."""
    t2 = WALL_T / 2

    def B(a, y0, b, y1, z0, z1, mat, **kw):
        if axis == "x":
            return box(a, y0, z0, b, y1, z1, mat, **kw)
        return box(z0, y0, a, z1, y1, b, mat, **kw)

    def panel(p, ln, w, n):
        # in the leaf's own frame, so the pattern swings with it
        u = p[:, 0] if axis == "x" else p[:, 2]
        v = p[:, 1] + 1.045
        d = np.zeros(len(p), dtype=int)
        paint = np.zeros((len(p), 4), dtype=np.uint8)
        face = (np.abs(ln[:, 2]) > 0.5) if axis == "x" else (np.abs(ln[:, 0]) > 0.5)
        win = face & (np.abs(u) < 0.2) & (v > 1.45) & (v < 1.85)
        paint[win] = (138, 170, 200, 255)
        paint[win & (np.abs(u + (v - 1.65) * 0.8) < 0.04)] = (196, 222, 240, 255)
        ins = face & (np.abs(u) < 0.28) & (v > 0.2) & (v < 1.2)
        edge = ins & ((np.abs(np.abs(u) - 0.27) < 0.03) | (np.abs(v - 0.21) < 0.025) | (np.abs(v - 1.19) < 0.025))
        d[edge] = -1
        return d, paint
    front = -t2 + LEAF_T
    leaf = [B(0.13, 0.0, 0.87, 2.09, -t2, front, DOOR, pattern=panel),
            B(0.74, 0.98, 0.8, 1.02, front, front + 0.04, BRASS)]
    return door_frame_prims(axis, 0.07, 0.93) + swing(leaf, axis, 0.13, 1, DOOR_ANGLES[state])


STEEL = Mat("8e8c98")


def double_door_prims(axis, side, state=0):
    """One leaf of a double swing door, 2 m wide across two wall metres:
    'l' is hinged on the left jamb of the first metre, 'r' on the right jamb
    of the second, and they meet in the middle. Each leaf is a solid slab set
    back in the wall, with a round porthole, a brass push plate by the meeting
    edge and a steel kick plate. state 0 closed, 1 ajar, 2 open: both swing
    into the room in front of the wall."""
    t2 = WALL_T / 2

    def B(a, y0, b, y1, z0, z1, mat, **kw):
        if axis == "x":
            return box(a, y0, z0, b, y1, z1, mat, **kw)
        return box(z0, y0, a, z1, y1, b, mat, **kw)
    if side == "l":
        prims = door_frame_prims(axis, 0.07, 1.0, True, False)
        a0, a1, hinge, meet = 0.13, 0.99, 0.13, 1.0
    else:
        prims = door_frame_prims(axis, 0.0, 0.93, False, True)
        a0, a1, hinge, meet = 0.01, 0.87, 0.87, -1.0
    half = (a1 - a0) / 2

    def leaf(p, ln, w, n):
        # in the leaf's own frame, so the pattern turns with it when it swings
        u = p[:, 0] if axis == "x" else p[:, 2]
        v = p[:, 1]
        face = (np.abs(ln[:, 2]) > 0.5) if axis == "x" else (np.abs(ln[:, 0]) > 0.5)
        d = np.zeros(len(p), dtype=int)
        paint = np.zeros((len(p), 4), dtype=np.uint8)
        r = np.hypot(u, (v - 0.5) * 1.0)
        ring = face & (r >= 0.13) & (r < 0.17)
        glass = face & (r < 0.13)
        paint[ring] = (196, 150, 64, 255)
        paint[glass] = (126, 162, 196, 255)
        paint[glass & (np.abs(u + (v - 0.5) * 0.9) < 0.035)] = (200, 226, 242, 255)
        kick = face & (v < -0.74)
        paint[kick] = (150, 148, 160, 255)
        paint[face & (np.abs(v + 0.74) < 0.02)] = (98, 96, 108, 255)
        push = face & (np.abs(u - meet * (half - 0.12)) < 0.05) & (np.abs(v - 0.06) < 0.12)
        paint[push] = (224, 178, 74, 255)
        edge = face & ~glass & ~ring & ~kick & ((np.abs(np.abs(u) - (half - 0.06)) < 0.022) | (np.abs(v - 0.94) < 0.02))
        d[edge] = -1
        return d, paint
    panel = [B(a0, 0.02, a1, 2.08, -t2, -t2 + LEAF_T, DOOR, pattern=leaf)]
    return prims + swing(panel, axis, hinge, 1 if side == "l" else -1, DOOR_ANGLES[state])


JOINT_ARMS = ["".join(a for a in "xXzZ" if a in combo) for combo in
              ("xz", "xZ", "Xz", "XZ", "xXz", "xXZ", "xzZ", "XzZ", "xXzZ")]


def joint_cap(arms, height):
    """Where walls meet (a corner, a T, a crossing), each wall picture is
    cut from a straight wall, so their caps overlap with seams. This patch
    is the caps of all the walls meeting there traced together as one top
    (no line between them), kept only on the top of the caps, 0.3 m around
    the point: laid over the walls, the junction reads as one piece.
    arms: x/X = the wall leaves towards +x/-x, z/Z towards +z/-z."""
    t2 = WALL_T / 2
    H = WALL_M if height == "full" else LOW_M
    face = WALL_FACE if height == "full" else WALL_OUT
    yb = H - 0.06
    group = object()
    prims = []
    for a in arms:
        if a in "xX":
            x0, x1 = (-t2 - 0.02, 1.0) if a == "x" else (-1.0, t2 + 0.02)
            prims.append(box(x0, 0, -t2, x1, yb, t2, face, group=group))
            prims.append(box(x0, yb, -t2 - 0.02, x1, H, t2 + 0.02, WALL_CAP, group=group))
        else:
            z0, z1 = (-t2 - 0.02, 1.0) if a == "z" else (-1.0, t2 + 0.02)
            prims.append(box(-t2, 0, z0, t2, yb, z1, face, group=group))
            prims.append(box(-t2 - 0.02, yb, z0, t2 + 0.02, H, z1, WALL_CAP, group=group))
    cv = render(prims, edge_light=True, lines=True)
    caps = np.zeros(cv.pid.shape, dtype=bool)
    for k, p in enumerate(prims):
        if p.mat is WALL_CAP:
            caps |= cv.pid == k
    top = cv.normal[..., 1] > 0.8
    near = (np.abs(cv.world[..., 0]) <= t2 + 0.3) & (np.abs(cv.world[..., 2]) <= t2 + 0.3)
    keep = caps & top & near
    cv.rgba[~keep] = 0
    return cv


def window_prims(axis, low=False):
    t2 = WALL_T / 2
    prims = []

    def B(a, y0, b, y1, z0, z1, mat, **kw):
        if axis == "x":
            return box(a, y0, z0, b, y1, z1, mat, **kw)
        return box(z0, y0, a, z1, y1, b, mat, **kw)
    if low:
        prims.append(B(0.0, LOW_M, 1.0, LOW_M + 0.55, -0.015, 0.015, GLASS))
        prims.append(B(0.0, LOW_M + 0.55, 1.0, LOW_M + 0.59, -0.03, 0.03, DOOR_FRAME))
        return prims

    def glass(p, ln, w, n):
        u = (w[:, 0] if axis == "x" else w[:, 2]) - 0.5
        v = w[:, 1]
        paint = np.zeros((len(p), 4), dtype=np.uint8)
        face = np.abs(ln[:, 1]) < 0.5
        paint[face] = (44, 52, 86, 255)
        paint[face & (np.abs((u + v * 0.9) - 1.45) < 0.035)] = (120, 140, 190, 255)
        paint[face & (np.abs((u + v * 0.9) - 1.6) < 0.02)] = (96, 112, 164, 255)
        paint[face & (np.abs(u) < 0.012)] = (30, 26, 44, 255)
        return np.zeros(len(p), dtype=int), paint
    prims.append(B(0.15, 0.95, 0.85, 1.95, -0.01, 0.01, GLASS, pattern=glass))
    prims.append(B(0.12, 0.9, 0.88, 0.98, -t2 - 0.02, t2 + 0.06, DOOR_FRAME))
    prims.append(B(0.12, 1.93, 0.88, 2.0, -t2 - 0.02, t2 + 0.03, DOOR_FRAME))
    prims.append(B(0.12, 0.95, 0.17, 1.95, -t2 - 0.02, t2 + 0.03, DOOR_FRAME))
    prims.append(B(0.83, 0.95, 0.88, 1.95, -t2 - 0.02, t2 + 0.03, DOOR_FRAME))
    prims.append(B(0.17, 1.1, 0.3, 1.94, t2 + 0.01, t2 + 0.05, CURTAIN, pattern=folds(axis)))
    prims.append(B(0.7, 1.1, 0.83, 1.94, t2 + 0.01, t2 + 0.05, CURTAIN, pattern=folds(axis)))
    prims.append(B(0.14, 1.94, 0.86, 1.99, t2 + 0.01, t2 + 0.07, BRASS))
    return prims


def folds(axis):
    def pat(p, ln, w, n):
        u = w[:, 0] if axis == "x" else w[:, 2]
        d = np.zeros(len(p), dtype=int)
        d[np.mod(u * 32, 2) < 1] = -1
        return d
    return pat


# ------------------------------------------------------------------ exterior props

STREET = Mat("30303e")
LAMP_GLASS = Mat("ffe2a0", emissive=True, line=False)
POT = Mat("5c4a58")
BOLLARD = Mat("2a2834")
TRUNK = Mat("4a3830")


def street_lamp():
    prims = [cyl(0, 0, 0, 0.16, 0.12, STREET), cyl(0, 0.12, 0, 0.06, 3.1, STREET),
             cyl(0, 3.2, 0, 0.1, 0.05, STREET)]
    prims += lathe(0, 3.25, 0, [(0, 0.12), (0.3, 0.14), (0.34, 0.06)], LAMP_GLASS)
    prims += [cyl(0, 3.55, 0, 0.16, 0.04, STREET), cyl(0, 3.59, 0, 0.05, 0.06, STREET)]
    return prims


def planter_bush(seed):
    return [box(-0.4, 0, -0.4, 0.4, 0.45, 0.4, POT)], bush(seed, 26, 16)


DUMPSTER = Mat("2f6a4a")


def dumpster():
    lid = Mat("25563b")
    prims = [box(-0.66, 0.12, -0.38, 0.66, 1.0, 0.38, DUMPSTER),
             box(-0.7, 1.0, -0.42, 0.7, 1.08, 0.42, lid),
             box(-0.68, 0.7, 0.38, 0.68, 0.76, 0.42, lid),
             box(-0.62, 0.0, -0.34, 0.62, 0.12, 0.34, Mat("1c1f24"))]
    for x in (-0.5, 0.5):
        for z in (-0.28, 0.28):
            prims.append(cyl(x, 0.0, z, 0.07, 0.1, Mat("1c1f24")))
    return prims


def street_sign(lit):
    """Club sign on two posts: pink neon pin-up and hearts, lit when open."""
    board = Mat("16131e")
    post = Mat("2a2834")
    prims = [box(-0.9, 1.0, -0.06, 0.9, 2.1, 0.06, board), box(-0.94, 0.96, -0.08, 0.94, 1.0, 0.08, post),
             box(-0.94, 2.1, -0.08, 0.94, 2.14, 0.08, post)]
    for x in (-0.8, 0.8):
        prims.append(box(x - 0.04, 0, -0.04, x + 0.04, 1.0, 0.04, post))
    return prims


def sign_decals(cv, lit):
    """Neon strokes on the sign front (plane z = 0.06)."""
    from pa_draw2d import heart_points
    tube = (255, 120, 190, 255) if lit else (92, 64, 86, 255)
    halo = (255, 70, 150, 110) if lit else None
    figure = [(-0.42, 1.25), (-0.3, 1.3), (-0.14, 1.34), (0.02, 1.42), (0.12, 1.55), (0.1, 1.66), (0.02, 1.72), (-0.06, 1.8),
              (-0.02, 1.9), (0.08, 1.92), (0.14, 1.84), (0.1, 1.74), (0.2, 1.7), (0.3, 1.58), (0.26, 1.46), (0.16, 1.4),
              (0.28, 1.3), (0.44, 1.22)]
    strokes = [figure]
    strokes.append(heart_points(-0.62, 1.62, 0.012))
    strokes.append(heart_points(0.62, 1.5, 0.012))
    strokes.append(heart_points(0.55, 1.82, 0.008))
    pts_all = []
    for st in strokes:
        for a, b in zip(st[:-1], st[1:]):
            for k in range(12):
                t = k / 12
                pts_all.append((a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t))
    if halo:
        for (x, y) in pts_all:
            sx, sy = screen((x, y, 0.07))
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                i = int(np.floor(sx + cv.ox)) + dx
                j = int(np.floor(sy + cv.oy)) + dy
                if 0 <= i < cv.w and 0 <= j < cv.h and cv.rgba[j, i, 3] > 0 and tuple(cv.rgba[j, i, :3]) != tube[:3]:
                    cv.rgba[j, i] = (140, 40, 96, 255)
    for (x, y) in pts_all:
        dot(cv, (x, y, 0.07), tube, bias=1.0)


def bollard():
    return [cyl(0, 0, 0, 0.11, 0.62, BOLLARD), cyl(0, 0.62, 0, 0.12, 0.05, Mat("4a4658"))]


# ------------------------------------------------------------------ glow halos

def glow(radius, flat=False, bands=(1.0, 0.62, 0.32)):
    """Posterised halo: 3 concentric bands with a 1 px ordered-dither
    transition, alpha only (tinted and added in game)."""
    rx = radius
    ry = radius * (0.5 if flat else 1.0)
    W = int(rx * 2 + 2)
    H = int(ry * 2 + 2)
    img = np.zeros((H, W, 4), dtype=np.uint8)
    cx, cy = W / 2, H / 2
    alphas = (58, 40, 22)
    for y in range(H):
        for x in range(W):
            d = math.hypot((x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry)
            a = 0
            for b, al in zip(reversed(bands), reversed(alphas)):
                pass
            if d <= bands[2]:
                a = alphas[0] + alphas[1] + alphas[2]
            elif d <= bands[1]:
                a = alphas[1] + alphas[2]
                if d <= bands[2] + 0.05 and (x + y) % 2 == 0:
                    a += alphas[0]
            elif d <= bands[0]:
                a = alphas[2]
                if d <= bands[1] + 0.05 and (x + y) % 2 == 0:
                    a += alphas[1]
            img[y, x] = (255, 255, 255, a)
    return img


def puddle(urine=False):
    """Blue water puddle like the one the janitor mops in the artwork."""
    w, h = 22, 11
    img = np.zeros((h, w, 4), dtype=np.uint8)
    body = hexrgb("dcb937" if urine else "4f86d8")
    light = hexrgb("ffe78a" if urine else "8cc0f4")
    edge = hexrgb("94712b" if urine else "2c4c9a")
    for y in range(h):
        for x in range(w):
            u = (x + 0.5 - w / 2) / (w / 2)
            v = (y + 0.5 - h / 2) / (h / 2)
            wob = 0.12 * math.sin(x * 1.3) + 0.1 * math.cos(y * 2.1 + x * 0.5)
            d = u * u + v * v + wob
            if d < 0.55:
                img[y, x] = body + (220 if urine else 150,)
            elif d < 0.8:
                img[y, x] = edge + (205 if urine else 140,)
            if d < 0.55 and (x + y) % 7 == 0 and u < 0.2:
                img[y, x] = light + (235 if urine else 190,)
    return img


# ------------------------------------------------------------------ export

def export():
    man = {"floors": {}, "walls": {}, "posts": {}, "openings": {}, "props": {}, "glows": {}, "tone_scale": TONE_SCALE,
           "index_scale": 4, "wall_h": WALL_H, "low_h": LOW_WALL_H, "floor_period": FLOOR_PERIOD}
    for name in FLOOR_PATTERNS:
        save(floor_texture(name), f"tiles/floor_{name}.png")
        man["floors"][name] = f"tiles/floor_{name}.png"
    man["wall_variants"] = WALL_VARIANTS
    for pat in sorted(set(WALL_FINISH_PATTERNS.values())):
        for axis in ("x", "z"):
            for kind in ("full", "full_door", "full_door_l", "full_door_r", "full_window", "low", "low_window"):
                for variant in range(WALL_VARIANTS):
                    cv = render_segment(axis, kind, pat, variant)
                    path = f"tiles/wall_{pat}_{axis}_{kind}_{variant}.png"
                    save(cv.rgba, path)
                    entry = {"file": path, "ox": cv.ox, "oy": cv.oy}
                    man["walls"][f"{pat}:{axis}:{kind}:{variant}"] = entry
                    if variant == 0:
                        man["walls"][f"{pat}:{axis}:{kind}"] = entry
            # a high wall that stops (at a cut wall, a gap or nowhere): its real end
            for ends in ("0", "1", "01"):
                for variant in range(WALL_VARIANTS):
                    cv = render_segment(axis, "full", pat, variant, ends)
                    path = f"tiles/wall_{pat}_{axis}_full_e{ends}_{variant}.png"
                    save(cv.rgba, path)
                    entry = {"file": path, "ox": cv.ox, "oy": cv.oy}
                    man["walls"][f"{pat}:{axis}:full_e{ends}:{variant}"] = entry
                    if variant == 0:
                        man["walls"][f"{pat}:{axis}:full_e{ends}"] = entry
    man["joints"] = {}
    for height in ("full", "low"):
        for arms in JOINT_ARMS:
            cv = joint_cap(arms, height)
            # file names without capitals: Windows would mix up xz and XZ
            code = "".join({"x": "xp", "X": "xm", "z": "zp", "Z": "zm"}[a] for a in arms)
            path = f"tiles/joint_{height}_{code}.png"
            save(cv.rgba, path)
            man["joints"][f"{height}:{arms}"] = {"file": path, "ox": cv.ox, "oy": cv.oy}
    for kind in ("full", "low"):
        cv = render_idx(post_prims(kind))
        save(cv.rgba, f"tiles/post_{kind}.png")
        man["posts"][kind] = {"file": f"tiles/post_{kind}.png", "ox": cv.ox, "oy": cv.oy}
    for axis in ("x", "z"):
        for name, prims in (("door", door_prims(axis)), ("door_ajar", door_prims(axis, 1)), ("door_open", door_prims(axis, 2)),
                            ("door2_l", double_door_prims(axis, "l")), ("door2_l_ajar", double_door_prims(axis, "l", 1)), ("door2_l_open", double_door_prims(axis, "l", 2)),
                            ("door2_r", double_door_prims(axis, "r")), ("door2_r_ajar", double_door_prims(axis, "r", 1)), ("door2_r_open", double_door_prims(axis, "r", 2)),
                            ("window", window_prims(axis)), ("window_low", window_prims(axis, True))):
            cv = render(prims)
            finish(cv)
            path = f"tiles/{name}_{axis}.png"
            save(cv.rgba, path)
            man["openings"][f"{name}:{axis}"] = {"file": path, "ox": cv.ox, "oy": cv.oy}
    # exterior props
    cv = render(street_lamp(), shadow=[(-0.18, -0.18, 0.18, 0.18)])
    finish(cv)
    save(cv.rgba, "props/street_lamp.png")
    man["props"]["street_lamp"] = {"file": "props/street_lamp.png", "ox": cv.ox, "oy": cv.oy,
                                   "lights": [{"x": 0, "y": -3.4 * PX_PER_M_Y, "color": "ffd08a", "radius": 2.6, "power": 1.0}]}
    # street trees: three static silhouettes, each with its tree pit drawn
    # flat on the ground
    for v in range(len(pa_trees.VARIANTS)):
        save(pa_trees.tree_frame(v), f"props/tree_{v}.png")
        save(pa_trees.tree_pit(v), f"props/tree_pit_{v}.png")
        man["props"][f"tree_{v}"] = {"file": f"props/tree_{v}.png", "ox": pa_trees.OX, "oy": pa_trees.OY, "lights": [],
                                     "pit": {"file": f"props/tree_pit_{v}.png", "ox": pa_trees.PIT_OX, "oy": pa_trees.PIT_OY}}
    man["props"]["tree"] = man["props"]["tree_0"]
    for name, (prims, pix, top) in {"bush": (*planter_bush(2), 0.45)}.items():
        cv = render(prims, bounds=[(-1.4, 3.2, 0), (1.4, 0, 0)], shadow=[(-0.45, -0.45, 0.45, 0.45)] if name == "bush" else [(-0.8, -0.5, 0.8, 0.5)])
        finish(cv)
        ax, ay = screen((0, top, 0))
        h, w, _ = pix.img.shape
        for yy in range(h):
            for xx in range(w):
                c = pix.img[yy, xx]
                if c[3]:
                    X = int(round(ax)) + xx - pix.ox + cv.ox
                    Y = int(round(ay)) + yy - pix.oy + cv.oy
                    if 0 <= X < cv.w and 0 <= Y < cv.h:
                        cv.rgba[Y, X] = c
        save(cv.rgba, f"props/{name}.png")
        man["props"][name] = {"file": f"props/{name}.png", "ox": cv.ox, "oy": cv.oy, "lights": []}
    cv = render(dumpster(), shadow=[(-0.72, -0.44, 0.72, 0.44)])
    finish(cv)
    save(cv.rgba, "props/dumpster.png")
    man["props"]["dumpster"] = {"file": "props/dumpster.png", "ox": cv.ox, "oy": cv.oy, "lights": []}
    for lit in (True, False):
        name = "sign_on" if lit else "sign_off"
        cv = render(street_sign(lit), shadow=[(-0.95, -0.12, 0.95, 0.12)])
        finish(cv)
        sign_decals(cv, lit)
        save(cv.rgba, f"props/{name}.png")
        lights = [{"x": 0, "y": -1.6 * PX_PER_M_Y, "color": "ff4fa0", "radius": 2.6, "power": 1.1}] if lit else []
        man["props"][name] = {"file": f"props/{name}.png", "ox": cv.ox, "oy": cv.oy, "lights": lights}
    cv = render(bollard())
    finish(cv)
    save(cv.rgba, "props/bollard.png")
    man["props"]["bollard"] = {"file": "props/bollard.png", "ox": cv.ox, "oy": cv.oy, "lights": []}
    for r in (12, 20, 28, 40, 56, 72):
        for flat in (False, True):
            name = f"glow_{r}{'_floor' if flat else ''}"
            save(glow(r, flat), f"fx/{name}.png")
            man["glows"][name] = f"fx/{name}.png"
    import pa_street
    man["street"] = pa_street.export()
    import pa_parking
    man["street"].update(pa_parking.export())
    import pa_lawn
    lawn = pa_lawn.export()
    man["lawn"] = lawn["lawn"]
    man["props"].update(lawn["bushes"])
    man["fx"] = {"puddle": "fx/puddle.png", "urine": "fx/urine.png"}
    save(puddle(), "fx/puddle.png")
    save(puddle(urine=True), "fx/urine.png")
    write_json("tiles.json", man)
    return man


if __name__ == "__main__":
    export()
