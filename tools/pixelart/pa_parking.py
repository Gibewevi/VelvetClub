"""Parking asphalt and kerbside soil, painted on the native 32 x 16 grid.

A large seamless field keeps the cracks from repeating under every bay.
The surface uses its own restrained RGBA palette: the standard six-tone
floor ramp is too contrasty for fine asphalt aggregate.
"""
from __future__ import annotations

import numpy as np

from pa_core import HALF_W, HALF_H, save
from pa_tiles import vnoise

PERIOD = 32


def grain(x, z, seed):
    a = np.asarray(x, dtype=np.int64)
    b = np.asarray(z, dtype=np.int64)
    h = (a * 374761393 + b * 668265263 + seed * 2654435761) & 0xFFFFFFFF
    h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
    return ((h ^ (h >> 16)) & 0xFFFF) / 65535.0


def fracture_gap(X, Z, cells, seed):
    """Distance and plate IDs for crisp native-pixel fracture contours."""
    step = PERIOD / cells
    gx, gz = np.floor(X / step).astype(int), np.floor(Z / step).astype(int)
    first = np.full(X.shape, 1e6)
    second = first.copy()
    ax, az, bx, bz = (np.zeros_like(X) for _ in range(4))
    plate = np.zeros(X.shape, dtype=np.int16)
    for dz in (-1, 0, 1):
        for dx in (-1, 0, 1):
            cx, cz = gx + dx, gz + dz
            px = (cx + 0.16 + grain(cx % cells, cz % cells, seed) * 0.68) * step
            pz = (cz + 0.16 + grain(cx % cells, cz % cells, seed + 1) * 0.68) * step
            dist = (X - px) ** 2 + (Z - pz) ** 2
            closer = dist < first
            runner_up = dist < second
            bx = np.where(closer, ax, np.where(runner_up, px, bx))
            bz = np.where(closer, az, np.where(runner_up, pz, bz))
            ax = np.where(closer, px, ax)
            az = np.where(closer, pz, az)
            plate = np.where(closer, cx % cells + (cz % cells) * cells, plate)
            second = np.minimum(second, np.maximum(first, dist))
            first = np.minimum(first, dist)
    # Normalising by centre separation prevents triangular black holes where
    # two nearby centres would otherwise give a very wide distance difference.
    return (second - first) / np.maximum(2 * np.hypot(ax - bx, az - bz), 0.001), plate


def asphalt():
    j, i = np.mgrid[0:16 * PERIOD, 0:32 * PERIOD]
    X = np.mod(((i + 0.5) / HALF_W + (j + 0.5) / HALF_H) / 2, PERIOD)
    Z = np.mod(((j + 0.5) / HALF_H - (i + 0.5) / HALF_W) / 2, PERIOD)
    fine = grain(np.floor(X * 32), np.floor(Z * 32), 309)
    cloud = vnoise(X, Z, 0.25, 312, PERIOD)
    wear = vnoise(X, Z, 1.0, 313, PERIOD)
    mottling = vnoise(X, Z, 3.0, 314, PERIOD)
    tone = np.floor((cloud - 0.5) * 11 + (wear - 0.5) * 5 + (mottling - 0.5) * 3)
    tone += np.where(fine > 0.84, 5, np.where(fine < 0.17, -4, 0))
    rgb = np.zeros(X.shape + (3,), dtype=np.int16)
    rgb[:] = (55, 53, 66)
    rgb += tone[..., None].astype(np.int16)
    # Quiet patches of oxidised binder, not high-contrast repeating speckles.
    warmth = np.maximum(0, np.floor((vnoise(X, Z, 0.5, 319, PERIOD) - 0.57) * 17))
    rgb[..., 0] += warmth.astype(np.int16)
    rgb[..., 2] -= (warmth * 0.5).astype(np.int16)

    # Irregular, angular plates with small meanders along the fractures.
    # Jittered cell centres wrap in world space, including negative UVs.
    wx = X + (vnoise(X, Z, 2.0, 321, PERIOD) - 0.5) * 0.5
    wz = Z + (vnoise(X, Z, 2.0, 322, PERIOD) - 0.5) * 0.5
    gap, plate = fracture_gap(wx, wz, 10, 327)
    age = vnoise(X, Z, 0.25, 332, PERIOD)
    active = age > 0.34
    rim = (gap < 0.13) & active
    # Trace the one-pixel contour directly. A distance threshold alone can
    # skip pixels on diagonals or make junctions too wide at this resolution.
    fissure = ((plate != np.roll(plate, 1, axis=0)) |
               (plate != np.roll(plate, 1, axis=1))) & active
    # Local secondary fractures crumble the shoulders of a few main cracks.
    # Most of the asphalt remains intact, so the pattern reads as wear.
    secondary, _ = fracture_gap(wx, wz, 26, 341)
    broken = (age > 0.53) & (gap < 0.70) & (wear > 0.28)
    rgb[broken & (secondary < 0.10)] -= 4
    rgb[broken & (secondary < 0.038)] = (32, 30, 39)
    rgb[rim] -= 4
    # Broken lit lip on one side, only a few subdued chips catch the light.
    lip = rim & ~fissure & (mottling > 0.56) & (fine > 0.55)
    rgb[lip] += (9, 8, 7)
    rgb[fissure] = (25, 24, 33)
    rgb[fissure & (fine > 0.72)] = (31, 29, 37)
    # Occasional crumbled shoulders around old cracks.
    crumbs = active & (age > 0.55) & (gap < 0.35) & (mottling > 0.55) & (fine > 0.66)
    rgb[crumbs] = (36, 33, 40)
    moss = rim & (age > 0.62) & (wear > 0.55) & (fine > 0.62)
    rgb[moss] = (80, 79, 43)
    rgb[moss & (fine > 0.88)] = (112, 105, 53)
    img = np.full(X.shape + (4,), 255, dtype=np.uint8)
    img[..., :3] = np.clip(rgb, 0, 255)
    return img


def shoulder(axis, side, seed, length=1.0):
    """One metre of irregular soil, moss and gravel on the inside of a kerb."""
    from pa_street import flat

    def paint(X, Z):
        along, across = (X, Z * side) if axis == "x" else (Z, X * side)
        fleck = grain(np.floor(X * 32), np.floor(Z * 32), seed)
        soil = vnoise(X, Z, 6.0, seed)
        width = 0.18 + vnoise(X, Z, 2.0, seed + 1) * 0.32
        mask = (along >= 0) & (along < length) & (across >= 0) & (across < width)
        img = np.zeros(X.shape + (4,), dtype=np.uint8)
        img[mask] = (28, 26, 32, 105)
        img[mask & (across < 0.14)] = (22, 22, 29, 150)
        chips = mask & (soil > 0.44) & (fleck > 0.72)
        img[chips] = (88, 78, 57, 200)
        img[chips & (fleck > 0.92)] = (135, 114, 69, 230)
        moss = mask & (soil > 0.62) & (fleck < 0.42)
        img[moss] = (69, 78, 43, 240)
        img[moss & (fleck < 0.12)] = (109, 119, 53, 255)
        return img

    lo, hi = (-0.6, 0) if side < 0 else (0, 0.6)
    return flat(0, lo, length, hi, paint) if axis == "x" else flat(lo, 0, hi, length, paint)


def export():
    man = {}

    def put(name, img, ox=0, oy=0):
        path = f"street/{name}.png"
        save(img, path)
        man[name] = {"file": path, "ox": int(ox), "oy": int(oy)}

    surface = asphalt()
    put("park_asphalt", surface)
    # Store a few actual moss locations so the game can plant tiny tufts at
    # fractures, instead of placing plants at random on unbroken asphalt.
    moss = (surface[..., 0] == 112) & (surface[..., 1] == 105)
    yy, xx = np.where(moss)
    tufts = []
    for idx in np.random.default_rng(417).permutation(len(xx)):
        x = ((xx[idx] + 0.5) / HALF_W + (yy[idx] + 0.5) / HALF_H) / 2 % PERIOD
        z = ((yy[idx] + 0.5) / HALF_H - (xx[idx] + 0.5) / HALF_W) / 2 % PERIOD
        if any(np.hypot(min(abs(x - a), PERIOD - abs(x - a)),
                        min(abs(z - b), PERIOD - abs(z - b))) < 4.5 for a, b in tufts):
            continue
        tufts.append([float(x), float(z)])
        if len(tufts) == 12:
            break
    man["park_asphalt"].update(period=PERIOD, tufts=tufts)
    for axis in ("x", "z"):
        for side in (-1, 1):
            for variant in range(4):
                put(f"park_soil_{axis}_{'neg' if side < 0 else 'pos'}_{variant}",
                    *shoulder(axis, side, 400 + variant * 11))
                put(f"park_soil_half_{axis}_{'neg' if side < 0 else 'pos'}_{variant}",
                    *shoulder(axis, side, 400 + variant * 11, length=0.5))
    return man


if __name__ == "__main__":
    print(len(export()), "parking surfaces")
