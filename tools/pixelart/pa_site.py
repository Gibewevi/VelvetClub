"""Building site: block walls rising course by course, site equipment and
what the workers carry, at native pixel resolution with the game's painter.

Look taken from the reference photo: grey concrete blocks, wooden pallets,
an orange concrete mixer and wheelbarrow, cement bags, rusty rebar cages,
a sawhorse with planks, a tripod work light and red-and-white tape.
"""
import math

import numpy as np

from pa_core import save, write_json, hash01, WALL_T, WALL_H, PX_PER_M_Y, HALF_W
from pa_iso import Mat, box, boxc, cyl, rod, lathe, render, finish, turn, rot_y, rot_x, rot_z

ROWS = 14                          # block courses in a full wall: 4 px each
WALL_M = WALL_H / PX_PER_M_Y       # 2.333 m
ROW_M = WALL_M / ROWS

BLOCK = Mat(tones=['3a3640', '5b5860', '7a7880', '989794', 'b5b2ab', 'd1cdc3'])
CORE = Mat(tones=['1f1b24', '2c2830', '38343c', '45414a', '524e57', '5f5b63'])
WOOD = Mat(tones=['3a2826', '5f4231', '87613f', 'aa8152', 'c9a36b', 'e2c389'])
PALE_WOOD = Mat(tones=['4a3a32', '76603f', '9f8456', 'c2a46c', 'dcc187', 'efdaa6'])
ORANGE = Mat(tones=['5e2a24', '93401f', 'c85a1e', 'e8762a', 'f69a45', 'ffc274'])
STEEL = Mat(tones=['26242e', '40404c', '5d606c', '7d8290', 'a0a6b2', 'c8ccd4'])
DARK = Mat(tones=['15131a', '211e27', '2d2a33', '3a3640', '4a4650', '5a5660'])
TYRE = Mat(tones=['121016', '1c1a22', '26232c', '322e38', '3e3a44', '4a4650'])
YELLOW = Mat(tones=['5a3a1c', '9a6a1e', 'd09a22', 'f0bc30', 'ffd85a', 'fff09a'])
LENS = Mat('fff1c0', emissive=True)
WET = Mat(tones=['2c2c34', '44454e', '5a5c66', '6c6e78', '80828c', '9a9ca4'])
BAG = Mat(tones=['4a3c34', '7a6a58', 'a8987e', 'cdbf9f', 'e2d6b8', 'f2e8d0'])
PRINT = Mat(tones=['3a1414', '6a1c1c', '9a2420', 'c03024', 'd85438', 'ec7c58'])
RUST = Mat(tones=['2e1810', '4e2616', '74361c', '944a26', 'b06636', 'c88650'])
WHITE = Mat(tones=['55505c', '8d8794', 'b7b0b8', 'd8d2d0', 'eee8e2', 'fffaf2'])
TAPE_RED = Mat(tones=['4a1418', '7a1c22', 'b0242c', 'd8343a', 'ee5a58', 'ff8a80'])
KRAFT = Mat(tones=['3d2530', '704337', '996140', 'bf894e', 'dbac68', 'f3cb8b'])
LIDS = [Mat('e05a8a'), Mat('5a8ac0'), Mat('e8d8b0')]


# ------------------------------------------------------------------ block walls

def masonry(axis):
    """Concrete blocks 50 x 16.7 cm, staggered courses, mortar joints, two
    hollow cores showing on the top of the last course."""
    def pat(p, ln, w, n):
        u = (w[:, 0] if axis == "x" else w[:, 2]) + 4.0
        across = w[:, 2] if axis == "x" else w[:, 0]
        v = w[:, 1]
        row = np.floor((v - 1e-4) / ROW_M).astype(int)
        uu = u + np.where(row % 2 == 0, 0.0, 0.25)
        bi = np.floor(uu / 0.5).astype(int)
        fu = uu - bi * 0.5
        fv = v - row * ROW_M
        side = np.abs(ln[:, 1]) < 0.5
        top = ln[:, 1] > 0.5
        d = np.zeros(len(p), dtype=int)
        var = np.array([hash01(int(a), int(b), 91) for a, b in zip(bi, row)])
        d[side & (var > 0.78)] += 1
        d[side & (var < 0.16)] -= 1
        grain = np.array([hash01(int(a), int(b), 92) for a, b in zip(np.floor(u * 16), np.floor(v * 24))])
        d[side & (grain > 0.93)] -= 1
        d[side & ((fv < 1 / 24 + 1e-4) | (fu < 1 / 16))] = -1
        cores = top & (np.abs(across) < 0.055) & (((fu > 0.07) & (fu < 0.2)) | ((fu > 0.3) & (fu < 0.43)))
        d[cores] = -2
        d[top & ~cores & (fu < 1 / 16)] = -1
        return d, None
    return pat


def wall_pieces(kind, h):
    """Pieces (u0, u1, y0, y1) of one 1 m segment holding the same holes as
    the finished wall (door, window), cut at height h."""
    if kind == "door":
        base = [(0.0, 0.1, 0.0, h), (0.9, 1.0, 0.0, h), (0.1, 0.9, 2.1, h)]
    elif kind == "window":
        base = [(0.0, 0.15, 0.0, h), (0.85, 1.0, 0.0, h), (0.15, 0.85, 0.0, min(h, 0.95)), (0.15, 0.85, 1.95, h)]
    else:
        base = [(0.0, 1.0, 0.0, h)]
    return [q for q in base if q[3] - q[2] > 1e-6]


def wall_prims(axis, kind, h):
    t2 = WALL_T / 2
    pat = masonry(axis)
    out = []
    for (a, b, y0, y1) in wall_pieces(kind, h):
        if axis == "x":
            out.append(box(a, y0, -t2, b, y1, t2, BLOCK, pattern=pat))
        else:
            out.append(box(-t2, y0, a, t2, y1, b, BLOCK, pattern=pat))
    return out


def block_segment(axis, kind, rows):
    """Like the finished walls: render between two plain neighbours of the
    same height, keep the middle metre so segments join without a seam."""
    h = rows * ROW_M
    prims = []
    for offset, k in ((-1, "plain"), (0, kind), (1, "plain")):
        part = wall_prims(axis, k, h)
        shift = np.array([offset, 0, 0]) if axis == "x" else np.array([0, 0, offset])
        for p in part:
            p.T = p.T + shift
        prims += part
    cv = finish(render(prims, bounds=[(0, WALL_M, 0)]))
    t2 = WALL_T / 2
    c0, c1 = (-HALF_W * t2, HALF_W * (1 - t2)) if axis == "x" else (HALF_W * (t2 - 1), HALF_W * t2)
    cols = np.arange(cv.w) - cv.ox
    cv.rgba[:, (cols < c0) | (cols >= c1)] = 0
    return cv


def block_post(rows):
    t2 = WALL_T / 2 + 0.01
    return finish(render([box(-t2, 0, -t2, t2, rows * ROW_M, t2, BLOCK, pattern=masonry("x"))], bounds=[(0, WALL_M, 0)]))


# ------------------------------------------------------------------ equipment

def block(x, y, z, along="x", cores=True):
    """One 50 x 20 x 20 cm concrete block, hollow cores on top."""
    L, H, D = 0.46, 0.19, 0.19
    if along == "x":
        p = [box(x - L / 2, y, z - D / 2, x + L / 2, y + H, z + D / 2, BLOCK)]
        if cores:
            for c in (-0.11, 0.11):
                p.append(box(x + c - 0.06, y + H - 0.01, z - 0.05, x + c + 0.06, y + H + 0.002, z + 0.05, CORE))
    else:
        p = [box(x - D / 2, y, z - L / 2, x + D / 2, y + H, z + L / 2, BLOCK)]
        if cores:
            for c in (-0.11, 0.11):
                p.append(box(x - 0.05, y + H - 0.01, z + c - 0.06, x + 0.05, y + H + 0.002, z + c + 0.06, CORE))
    return p


def pallet(w=1.0, d=0.8, mat=WOOD):
    p = []
    for z in (-d / 2 + 0.06, 0.0, d / 2 - 0.06):
        p.append(box(-w / 2, 0.0, z - 0.05, w / 2, 0.09, z + 0.05, mat))
    for i in range(5):
        x = -w / 2 + 0.07 + i * (w - 0.14) / 4
        p.append(box(x - 0.055, 0.09, -d / 2, x + 0.055, 0.125, d / 2, mat))
    return p


def pallet_blocks(layers):
    """Pallet of blocks: 2 x 4 per course, courses crossed; fewer as the
    walls go up."""
    p = pallet()
    for k in range(layers):
        y = 0.125 + k * 0.195
        if k % 2 == 0:
            for ix in (-0.24, 0.24):
                for iz in (-0.3, -0.1, 0.1, 0.3):
                    p += block(ix, y, iz, "x", cores=k == layers - 1)
        else:
            for ix in (-0.375, -0.125, 0.125, 0.375):
                for iz in (-0.2, 0.2):
                    p += block(ix, y, iz, "z", cores=k == layers - 1)
    return p


def mixer(frame):
    """Orange concrete mixer: tilted drum on a stand with two wheels."""
    p = []
    # stand: A legs, an axle with two wheels at the back
    p.append(rod((0.25, 0.0, -0.32), (0.0, 0.62, 0.0), 0.035, STEEL))
    p.append(rod((0.25, 0.0, 0.32), (0.0, 0.62, 0.0), 0.035, STEEL))
    p.append(rod((-0.35, 0.16, -0.36), (0.0, 0.62, 0.0), 0.035, STEEL))
    p.append(rod((-0.35, 0.16, 0.36), (0.0, 0.62, 0.0), 0.035, STEEL))
    for z in (-0.4, 0.4):
        w = cyl(0, 0, 0, 0.16, 0.08, TYRE).transformed(rot_x(90))
        w.T += [-0.35, 0.16, z + (0.04 if z > 0 else -0.04)]
        hub = cyl(0, 0, 0, 0.07, 0.09, YELLOW).transformed(rot_x(90))
        hub.T += [-0.35, 0.16, z + (0.045 if z > 0 else -0.045)]
        p += [w, hub]
    p.append(box(-0.22, 0.42, -0.14, 0.02, 0.62, 0.14, DARK))      # motor
    p.append(box(-0.2, 0.62, -0.12, 0.0, 0.66, 0.12, ORANGE))

    def stripes(pt, ln, w, n):
        a = np.arctan2(pt[:, 2], pt[:, 0])
        # two welded ribs going round with the drum
        band = np.mod(a / math.pi + frame * 0.25, 1.0) < 0.12
        side = np.abs(ln[:, 1]) < 0.5
        d = np.zeros(len(pt), dtype=int)
        d[band & side] = 1
        return d, None
    profile = [(0.0, 0.1), (0.08, 0.26), (0.2, 0.33), (0.38, 0.33), (0.52, 0.27), (0.62, 0.17), (0.68, 0.14)]
    drum = lathe(0, 0, 0, profile, ORANGE, pattern=stripes)
    mouth = [cyl(0, 0.7, 0, 0.12, 0.012, DARK)]
    rim = lathe(0, 0.66, 0, [(0.0, 0.16), (0.04, 0.16)], ORANGE)
    parts = turn(turn(drum + rim + mouth, rot_z(-42)), rot_y(-40))
    for q in parts:
        q.T = q.T + np.array([0.02, 0.66, 0.0])
    p += parts
    return p


def wheelbarrow(full):
    """Orange tub, black wheel ahead (+x), handles behind."""
    p = []
    p.append(box(-0.28, 0.32, -0.21, 0.26, 0.46, 0.21, ORANGE))
    p.append(box(-0.38, 0.46, -0.28, 0.36, 0.6, 0.28, ORANGE))
    p.append(box(-0.4, 0.58, -0.3, 0.38, 0.62, 0.3, ORANGE))
    if full:
        p.append(box(-0.34, 0.62, -0.25, 0.32, 0.665, 0.25, WET))
    w = cyl(0, 0, 0, 0.18, 0.09, TYRE).transformed(rot_x(90))
    w.T += [0.52, 0.18, 0.045]
    hub = cyl(0, 0, 0, 0.06, 0.1, STEEL).transformed(rot_x(90))
    hub.T += [0.52, 0.18, 0.05]
    p += [w, hub]
    for z in (-0.2, 0.2):
        p.append(rod((0.52, 0.18, z * 0.5), (-0.3, 0.42, z), 0.022, STEEL))
        p.append(rod((-0.3, 0.42, z), (-0.92, 0.58, z * 1.15), 0.022, STEEL))
        p.append(box(-0.98, 0.555, z * 1.15 - 0.03, -0.84, 0.605, z * 1.15 + 0.03, DARK))
        p.append(rod((-0.3, 0.42, z), (-0.36, 0.0, z * 1.05), 0.022, STEEL))
    return p


def work_light():
    """Tripod site light: three legs, a mast and a yellow lamp head."""
    p = []
    top = (0.0, 0.85, 0.0)
    for k in range(3):
        a = math.radians(90 + k * 120)
        p.append(rod((0.36 * math.cos(a), 0.0, 0.36 * math.sin(a)), top, 0.02, DARK))
    p.append(rod((0, 0.8, 0), (0, 1.55, 0), 0.025, STEEL))
    head = [box(-0.17, -0.12, -0.06, 0.17, 0.12, 0.06, YELLOW),
            box(-0.14, -0.09, 0.06, 0.14, 0.09, 0.075, LENS),
            box(-0.19, 0.12, -0.08, 0.19, 0.145, 0.08, YELLOW)]
    head = turn(head, rot_y(45))
    for q in head:
        q.T = q.T + np.array([0.0, 1.62, 0.0])
    return p + head


def sawhorse():
    """Two trestles with planks laid across."""
    p = []
    for x in (-0.48, 0.48):
        for z in (-0.22, 0.22):
            p.append(rod((x - 0.12, 0.0, z), (x, 0.66, z * 0.4), 0.025, PALE_WOOD))
            p.append(rod((x + 0.12, 0.0, z), (x, 0.66, z * 0.4), 0.025, PALE_WOOD))
        p.append(box(x - 0.06, 0.62, -0.28, x + 0.06, 0.7, 0.28, PALE_WOOD))
    for i, z in enumerate((-0.17, 0.0, 0.17)):
        p.append(box(-0.82 + i * 0.05, 0.7 + i * 0.001, z - 0.075, 0.78 + i * 0.03, 0.73 + i * 0.001, z + 0.075, PALE_WOOD))
    p.append(box(-0.6, 0.73, -0.06, 0.65, 0.76, 0.08, WOOD))
    return p


def mortar_bucket():
    p = lathe(0, 0, 0, [(0.0, 0.15), (0.24, 0.19)], DARK)
    p.append(cyl(0, 0.2, 0, 0.17, 0.02, BLOCK))
    p.append(rod((0.02, 0.21, 0.0), (0.16, 0.36, -0.05), 0.016, PALE_WOOD))
    p.append(box(-0.12, 0.215, -0.05, 0.02, 0.225, 0.07, STEEL))
    return p


def cement_bags():
    p = pallet(0.9, 0.7)
    for k in range(2):
        y = 0.125 + k * 0.13
        for (x, z) in ((-0.22, -0.17), (0.22, -0.17), (-0.22, 0.17), (0.22, 0.17)):
            if k == 1 and (x, z) == (0.22, 0.17):
                continue
            p.append(box(x - 0.2, y, z - 0.15, x + 0.2, y + 0.12, z + 0.15, BAG))
            p.append(box(x - 0.07, y + 0.12, z - 0.15, x + 0.07, y + 0.123, z + 0.15, PRINT))
    return p


def rebar_cage():
    """Two rusty reinforcement cages lying on wooden blocks."""
    p = [box(-0.55, 0.0, -0.3, -0.45, 0.06, 0.3, WOOD), box(0.45, 0.0, -0.3, 0.55, 0.06, 0.3, WOOD)]
    for zc in (-0.15, 0.15):
        for dy in (0.0, 0.16):
            for dz in (-0.07, 0.07):
                p.append(rod((-0.7, 0.07 + dy, zc + dz), (0.7, 0.07 + dy, zc + dz), 0.012, RUST))
        for x in np.arange(-0.6, 0.65, 0.2):
            p.append(box(x - 0.01, 0.06, zc - 0.085, x + 0.01, 0.245, zc - 0.07, RUST))
            p.append(box(x - 0.01, 0.06, zc + 0.07, x + 0.01, 0.245, zc + 0.085, RUST))
            p.append(box(x - 0.01, 0.23, zc - 0.085, x + 0.01, 0.245, zc + 0.085, RUST))
    return p


def paint_pots():
    p = []
    for i, (x, z) in enumerate(((-0.14, -0.1), (0.14, -0.08), (0.0, 0.16))):
        p += lathe(x, 0, z, [(0.0, 0.11), (0.22, 0.12)], WHITE)
        p.append(cyl(x, 0.22, z, 0.12, 0.02, LIDS[i]))
        p.append(box(x - 0.12, 0.08, z - 0.02, x - 0.115, 0.14, z + 0.02, LIDS[i]))
    p.append(box(0.2, 0.0, 0.05, 0.5, 0.05, 0.3, DARK))
    p.append(box(0.23, 0.05, 0.08, 0.47, 0.055, 0.27, LIDS[0]))
    return p


def parquet_stack(layers):
    """Packs of parquet boards on two battens, used as the floor is laid."""
    p = [box(-0.5, 0.0, -0.3, 0.5, 0.05, -0.2, WOOD), box(-0.5, 0.0, 0.2, 0.5, 0.05, 0.3, WOOD)]
    for k in range(layers):
        y = 0.05 + k * 0.08
        for z in (-0.17, 0.1):
            p.append(box(-0.46, y, z - 0.12, 0.46, y + 0.075, z + 0.12, KRAFT))
            p.append(box(-0.2, y + 0.075, z - 0.12, -0.14, y + 0.078, z + 0.12, WHITE))
    return p


def loose_blocks():
    return block(-0.25, 0.0, 0.05, "x") + block(0.2, 0.0, -0.12, "z") + block(-0.22, 0.19, 0.05, "x")


def tape(axis):
    """Red-and-white tape between two stakes along one metre."""
    def stripes(pt, ln, w, n):
        u = w[:, 0] if axis == "x" else w[:, 2]
        d = np.zeros(len(pt), dtype=int)
        paint = np.zeros((len(pt), 4), dtype=np.uint8)
        white = np.mod(u, 0.24) < 0.12
        paint[white] = (236, 230, 222, 255)
        return d, paint
    p = []
    for u in (0.0, 1.0):
        x, z = (u, 0.0) if axis == "x" else (0.0, u)
        p.append(box(x - 0.025, 0.0, z - 0.025, x + 0.025, 0.86, z + 0.025, PALE_WOOD))
        p.append(box(x - 0.03, 0.86, z - 0.03, x + 0.03, 0.92, z + 0.03, TAPE_RED))
    if axis == "x":
        p.append(box(0.025, 0.74, -0.006, 0.975, 0.8, 0.006, TAPE_RED, pattern=stripes))
    else:
        p.append(box(-0.006, 0.74, 0.025, 0.006, 0.8, 0.975, TAPE_RED, pattern=stripes))
    return p


# ------------------------------------------------------------------ carried

def carried(name):
    if name == "block":
        return block(0, 0, 0, "x")
    if name == "planks":
        return [box(-0.36, k * 0.03, -0.09 + k * 0.01, 0.36, k * 0.03 + 0.028, 0.09 + k * 0.01, KRAFT if k == 1 else PALE_WOOD) for k in range(3)]
    if name == "bucket":
        p = lathe(0, 0, 0, [(0.0, 0.1), (0.2, 0.11)], WHITE)
        p.append(cyl(0, 0.2, 0, 0.11, 0.015, LIDS[0]))
        return p
    if name == "bag":
        return [box(-0.2, 0, -0.14, 0.2, 0.12, 0.14, BAG), box(-0.07, 0.12, -0.14, 0.07, 0.123, 0.14, PRINT)]
    return []


def put(man, name, prims, shadow=None, edge_light=True):
    cv = finish(render(prims, shadow=shadow, edge_light=edge_light))
    path = f"site/{name}.png"
    save(cv.rgba, path)
    man[name] = {"file": path, "ox": int(cv.ox), "oy": int(cv.oy)}
    return man[name]


def export():
    man = {"rows": ROWS, "row_px": WALL_H // ROWS}
    for axis in ("x", "z"):
        for kind in ("plain", "door", "window"):
            for rows in range(1, ROWS + 1):
                cv = block_segment(axis, kind, rows)
                path = f"site/wall_{axis}_{kind}_{rows}.png"
                save(cv.rgba, path)
                man[f"wall:{axis}:{kind}:{rows}"] = {"file": path, "ox": int(cv.ox), "oy": int(cv.oy)}
    for rows in range(1, ROWS + 1):
        cv = block_post(rows)
        path = f"site/post_{rows}.png"
        save(cv.rgba, path)
        man[f"post:{rows}"] = {"file": path, "ox": int(cv.ox), "oy": int(cv.oy)}
    for n in range(5):
        put(man, f"pallet_blocks_{n}", pallet_blocks(n), shadow=[(-0.5, -0.4, 0.5, 0.4)])
    for f in range(4):
        put(man, f"mixer_{f}", mixer(f), shadow=[(-0.45, -0.42, 0.4, 0.42)])
    for r in range(4):
        for full in (0, 1):
            put(man, f"barrow_{r}_{full}", turn(wheelbarrow(full), rot_y(-90 * r)))
    put(man, "barrow_parked", turn(wheelbarrow(False), rot_y(-30)))
    light = put(man, "light", work_light(), shadow=[(-0.3, -0.3, 0.3, 0.3)])
    light["glow"] = {"y": round(-1.62 * PX_PER_M_Y), "color": "ffe6a8", "radius": 2.4, "power": 0.55}
    put(man, "sawhorse", sawhorse(), shadow=[(-0.75, -0.3, 0.75, 0.3)])
    put(man, "bucket", mortar_bucket())
    put(man, "bags", cement_bags(), shadow=[(-0.45, -0.35, 0.45, 0.35)])
    put(man, "rebar", rebar_cage())
    put(man, "paint", paint_pots())
    for n in range(4):
        put(man, f"parquet_{n}", parquet_stack(n), shadow=[(-0.5, -0.32, 0.5, 0.32)])
    put(man, "blocks", loose_blocks())
    for axis in ("x", "z"):
        put(man, f"tape_{axis}", tape(axis), edge_light=False)
    for name in ("block", "planks", "bucket", "bag"):
        put(man, f"carry_{name}", carried(name))
    put(man, "plank_x", [box(-0.3, 0, -0.06, 0.3, 0.025, 0.06, KRAFT)])
    put(man, "plank_z", [box(-0.06, 0, -0.3, 0.06, 0.025, 0.3, KRAFT)])
    write_json("site.json", man)
    return man


if __name__ == "__main__":
    export()
    print("site art exported")
