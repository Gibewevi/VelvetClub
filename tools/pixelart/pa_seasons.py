"""Native seasonal layers for the existing exterior art.

No frame noise or moving texture coordinates: masks partition foliage into
stable irregular clusters. Bare branches use a new reference-based painting;
snow is built at native resolution with a small, undithered blue-white ramp.
"""
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

import pa_lawn
import pa_trees
from pa_core import OUT, hexrgb, save, write_json

SOURCE = Path(__file__).resolve().parent / "sources/seasons/tree_bare.png"
SNOW = [hexrgb(c) for c in ("7f99bc", "a1b9d4", "c4d6e6", "e5edf4", "f5f6f0")]


def clusters(width, height, seed=41):
    """Jittered Voronoi masses, avoiding a regular square/checkerboard mask."""
    y, x = np.mgrid[0:height, 0:width]
    distance = np.full((height, width), np.inf)
    rank = np.zeros((height, width), dtype=np.uint8)
    variant = rank.copy()
    rng = np.random.default_rng(seed)
    for gy in range(-1, height//10+2):
        for gx in range(-1, width//10+2):
            cx, cy = gx*10+rng.uniform(-3, 3), gy*10+rng.uniform(-3, 3)
            d = (x-cx)**2+(y-cy)**2*1.3
            take = d < distance
            distance[take] = d[take]
            rank[take] = rng.integers(15, 240)
            variant[take] = rng.integers(0, 256)
    return rank, variant


def foliage(image, flowers=False):
    rgb = image[:, :, :3].astype(float)
    r, g, b = rgb[:, :, 0], rgb[:, :, 1], rgb[:, :, 2]
    solid = image[:, :, 3] >= 128
    leaves = solid & ((g > r*1.03) | ((b > r*1.1) & (g > r*.7)))
    if flowers:
        leaves |= solid & (r > g*1.1) & (b > g*1.05)
    # Include dark outlines touching a leaf cluster, but keep warm bark intact.
    near = np.array(Image.fromarray((leaves*255).astype(np.uint8)).filter(ImageFilter.MaxFilter(3))) > 0
    leaves |= solid & near & (np.maximum.reduce([r, g, b]) < 52)
    return leaves


def mask(image, flowers=False):
    h, w = image.shape[:2]
    rank, variation = clusters(w, h)
    result = np.zeros_like(image)
    result[:, :, 0] = foliage(image, flowers)*255
    result[:, :, 1] = rank
    result[:, :, 2] = variation
    result[:, :, 3] = 255
    return result


def bare_tree(variant):
    source = Image.open(SOURCE).convert("RGBA")
    a = np.array(source.getchannel("A"))
    ys, xs = np.where(a >= 128)
    source = source.crop((int(xs.min()), int(ys.min()), int(xs.max())+1, int(ys.max())+1))
    height = pa_trees.VARIANTS[variant]["height"]
    width = round(source.width*height/source.height)
    native = np.array(source.resize((width, height), Image.Resampling.NEAREST))
    native[:, :, 3] = np.where(native[:, :, 3] >= 128, 255, 0)
    native[native[:, :, 3] == 0] = 0
    native = np.array(Image.fromarray(native).quantize(colors=32, method=Image.Quantize.FASTOCTREE, dither=Image.Dither.NONE).convert("RGBA"))
    foot_x = np.where(native[height-10:height-3, :, 3] > 0)[1]
    foot = round(float(np.median(foot_x)))
    left = max(4, min(pa_trees.W-width-4, pa_trees.OX-foot))
    top = pa_trees.OY-height+1+pa_trees.ROOT_FRONT
    result = np.zeros((pa_trees.H, pa_trees.W, 4), dtype=np.uint8)
    result[top:top+height, left:left+width] = native
    return result


def branch_snow(bare):
    result = bare.copy()
    result[:, :, :3] = np.rint(result[:, :, :3]*np.array([.85,.9,.98])).astype(np.uint8)
    solid = bare[:, :, 3] >= 128
    h, w = solid.shape
    for y in range(3, min(h-24, pa_trees.OY-25)):
        top = solid[y] & ~solid[y-1]
        edges = np.where(np.diff(np.r_[False, top, False].astype(np.int8)) != 0)[0]
        for start, end in zip(edges[::2], edges[1::2]):
            if end-start < 2:
                continue
            # Two readable stepped snow pixels, never a smooth white stroke.
            result[y, start:end] = (*SNOW[2], 255)
            result[y-1, start:end] = (*SNOW[4], 255)
            if end-start >= 5:
                result[y-2, start+1:end-1] = (*SNOW[3], 255)
        # Sloping branches have single stepped edge pixels. Their supported
        # upper faces receive snow too, rather than just the horizontal tips.
        for x in np.where(top)[0]:
            if x <= 2 or x >= w-3: continue
            if solid[y,x-1] or solid[y,x+1]:
                result[y-1,x] = (*SNOW[4],255)
                result[y,x] = (*SNOW[2],255)
    return result


def shrub_snow(original):
    h, w = original.shape[:2]
    solid = foliage(original, True)
    ys, xs = np.where(solid)
    result = Image.new("RGBA", (w, h))
    draw = ImageDraw.Draw(result)
    if not len(xs): return np.array(result)
    x0, x1, y0, y1 = int(xs.min()), int(xs.max()), int(ys.min()), int(ys.max())
    rng = np.random.default_rng(47+w+h+x0)
    centers = []
    for x in range(x0+3, x1-2, 8):
        column = np.where(solid[:, x])[0]
        if len(column): centers.append((x, int(column[0])+1))
    for y in range(y0+9, y1-5, 8):
        for x in range(x0+5+(y%3), x1-3, 10):
            if solid[y, x] and rng.random() > .25: centers.append((x, y))
    for x, y in centers:
        radius = int(rng.integers(3, 6))
        draw.polygon([(x-radius,y),(x-radius+1,y-2),(x-1,y-3),(x+radius-2,y-2),(x+radius,y),(x+radius-1,y+2),(x-radius+1,y+2)],fill=(*SNOW[1],255))
        draw.polygon([(x-radius+1,y-1),(x-1,y-3),(x+radius-2,y-2),(x+radius-1,y),(x+1,y+1),(x-radius+1,y)],fill=(*SNOW[4],255))
    return np.array(result)


def winter_lawn(original):
    X, Z = pa_lawn.world_grid()
    noise = pa_lawn.vnoise(X, Z, .72, 83)*.65+pa_lawn.vnoise(X, Z, 2.8, 84)*.35
    idx = np.clip(np.floor(noise*5+1), 1, 4).astype(int)
    result = original.copy()
    result[:, :, :3] = np.array(SNOW, dtype=np.uint8)[idx]
    # Sparse blue-grey grass tufts poking through the snow, clustered in
    # meadow patches rather than copying every summer blade as white noise.
    rng = np.random.default_rng(20261003)
    pil = Image.fromarray(result)
    draw = ImageDraw.Draw(pil)
    for _ in range(650):
        x, z = rng.uniform(-23.5,23.5,2)
        if pa_lawn.WALK_NEAR[0]-.5 < z < pa_lawn.WALK_FAR[1]+.5: continue
        if pa_lawn.vnoise(np.array(x),np.array(z),4,91) < .45: continue
        px, py = pa_lawn.to_px(x,z)
        for dx, rise in [(-2,3),(0,5),(2,3)]:
            draw.line([(px+dx,py),(px+dx-(1 if dx < 0 else -1),py-rise)],fill=(*SNOW[0],255),width=1)
        draw.line([(px-3,py+1),(px+3,py+1)],fill=(*SNOW[3],255),width=1)
    result = np.array(pil)
    result[:, :, 3] = original[:, :, 3]
    result[result[:, :, 3] == 0] = 0
    return result


def pit_snow(original):
    result = np.zeros_like(original)
    for y in range(original.shape[0]):
        for x in range(original.shape[1]):
            wx = ((x-pa_trees.PIT_OX)/16+(y-pa_trees.PIT_OY)/8)/2
            wz = ((y-pa_trees.PIT_OY)/8-(x-pa_trees.PIT_OX)/16)/2
            if max(abs(wx),abs(wz)) < pa_trees.PIT_HALF-.15 and original[y,x,3] >= 128:
                result[y,x] = (*SNOW[3 if (x//5+y//3)%4 else 2],255)
    return result


def export():
    manifest = {}
    def emit(name, original, kind, snow, bare=None, flowers=False):
        prefix = "seasons/"+name
        # Ground snow uses a full-lot blend and needs no leaf partition.
        # Avoid building thousands of canopy Voronoi cells for the meadow.
        ground_mask = np.zeros_like(original)
        ground_mask[:, :, 3] = 255
        save(ground_mask if kind == 0 else mask(original, flowers), prefix+"_mask.png")
        save(snow, prefix+"_snow.png")
        spec = {"kind":kind,"mask":prefix+"_mask.png","snow":prefix+"_snow.png"}
        if bare is not None:
            save(bare,prefix+"_bare.png")
            spec["bare"] = prefix+"_bare.png"
        manifest[name] = spec
    lawn = np.array(Image.open(OUT/"tiles/lawn.png").convert("RGBA"))
    emit("lawn",lawn,0,winter_lawn(lawn))
    for v in range(3):
        original = np.array(Image.open(OUT/f"props/tree_{v}.png").convert("RGBA"))
        bare = bare_tree(v)
        emit(f"tree_{v}",original,1,branch_snow(bare),bare)
        pit = np.array(Image.open(OUT/f"props/tree_pit_{v}.png").convert("RGBA"))
        emit(f"tree_pit_{v}",pit,3,pit_snow(pit))
    for name in ["bush"]+[f"lawn_bush_{v}" for v in range(4)]:
        original = np.array(Image.open(OUT/f"props/{name}.png").convert("RGBA"))
        emit(name,original,2,shrub_snow(original),flowers=True)
    write_json("seasons.json",manifest)
    print("SEASON_ART_EXPORTED",len(manifest),"native layers")


if __name__ == "__main__": export()
