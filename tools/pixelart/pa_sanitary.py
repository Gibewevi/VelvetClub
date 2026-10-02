"""Native pixel overlays and comic plumbing effects; stable clusters, no noise animation."""
import json
import random
from PIL import Image, ImageDraw
from pa_core import OUT, write_json

KINDS = ("toilet", "old_toilet", "urinal", "sink", "old_sink", "shower")


def save_image(image, name):
    path = OUT / name
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path)
    return name


def stains(info, level, seed):
    base = Image.open(OUT / info["file"]).convert("RGBA")
    result = Image.new("RGBA", base.size)
    candidates = []
    for y in range(base.height):
        for x in range(base.width):
            r, g, b, a = base.getpixel((x, y))
            if a > 200 and r > 115 and g > 105 and abs(r-g) < 65 and b < r*1.25:
                candidates.append((x, y))
    mask = set(candidates)
    rng = random.Random(seed)
    rng.shuffle(candidates)
    count = min(len(candidates), max(3, len(candidates)//80)*level*2)
    for n, (x, y) in enumerate(candidates[:count]):
        # Ochre crusts and olive specks, clipped to the porcelain silhouette.
        for dx, dy, color in [(0, 0, "#8b794b"), (1, 0, "#b0a16b"), (0, 1, "#736544"), (-1, 0, "#c1b47b")]:
            if (x+dx, y+dy) in mask and (level > 1 or dy == 0): result.putpixel((x+dx, y+dy), tuple(bytes.fromhex(color[1:]))+(225,))
    return result


def puddle(kind, size):
    im = Image.new("RGBA", (22, 12))
    d = ImageDraw.Draw(im)
    colors = ("#ad832f", "#eac843", "#fff09b") if kind == "urine" else ("#407da3", "#72c7da", "#d3f7ed")
    if size == 0:
        d.rectangle((7, 4, 9, 5), fill=colors[0])
        d.rectangle((8, 3, 10, 4), fill=colors[1])
        d.point((8, 3), fill=colors[2])
        d.rectangle((13, 7, 15, 8), fill=colors[1])
        d.point((4, 7), fill=colors[1])
    else:
        # Stepped isometric silhouette fits a half-metre floor cell; dense puddles join.
        pts = [(10,1),(13,1),(13,2),(16,2),(16,3),(18,3),(18,4),(20,4),(20,7),(17,7),(17,8),(14,8),(14,9),(9,9),(9,8),(6,8),(6,7),(3,7),(3,5),(5,5),(5,4),(7,4),(7,3),(10,3)]
        d.polygon(pts, fill=colors[0])
        d.polygon([(10,2),(13,2),(13,3),(16,3),(16,4),(18,4),(18,6),(15,6),(15,7),(10,8),(7,7),(5,6),(8,4)], fill=colors[1])
        d.line((9,4,12,3), fill=colors[2])
        d.line((14,6,16,5), fill=colors[2])
        if size == 2:
            d.rectangle((1,5,3,6), fill=colors[1])
            d.rectangle((18,8,20,9), fill=colors[1])
            d.line((7,7,10,8), fill=colors[2])
    return im


def droplet(frame):
    im = Image.new("RGBA", (16, 24))
    d = ImageDraw.Draw(im)
    for i in range(2):
        x, y = 5+i*6, 2+(frame*4+i*7)%16
        d.polygon([(x,y),(x-2,y+3),(x-2,y+5),(x,y+6),(x+2,y+5),(x+2,y+3)], fill="#316c99")
        d.polygon([(x,y+1),(x-1,y+3),(x-1,y+4),(x+1,y+4)], fill="#81e3ef")
        d.point((x,y+2), fill="#f4fff6")
    d.line((2,21,5,22,11,22,14,20), fill="#b7f4f3")
    if frame % 2: d.line((1,18,3,20), fill="#72c7da")
    else: d.line((12,18,14,17), fill="#72c7da")
    return im


def badge():
    im = Image.new("RGBA", (16, 16))
    d = ImageDraw.Draw(im)
    d.polygon([(3,1),(13,1),(15,3),(15,12),(12,14),(7,14),(4,15),(4,14),(1,12),(1,3)], fill="#29263d")
    d.polygon([(3,2),(12,2),(14,4),(14,11),(12,13),(6,13),(4,14),(4,13),(2,11),(2,4)], fill="#f5a04b")
    d.polygon([(8,4),(9,3),(11,3),(10,5),(12,7),(13,6),(13,8),(11,9),(9,8),(5,12),(3,10),(7,6),(7,5)], fill="#fff3cf")
    d.point((5,10), fill="#805b62")
    return im


def smell(frame):
    im = Image.new("RGBA", (14, 15))
    d = ImageDraw.Draw(im)
    for i in range(2):
        x = 3+i*6
        shift = frame % 2
        d.line([(x,13),(x-1,11),(x-1,9),(x+shift,7),(x+1,5),(x+1,3),(x,1)], fill="#98ad60")
        d.point((x,6), fill="#c8d582")
    return im


def export():
    furniture = json.loads((OUT / "furniture.json").read_text())
    data = {"soil": {}, "drops": [], "smell": [], "puddles": {}}
    for k, kind in enumerate(KINDS):
        data["soil"][kind] = {}
        for rot in range(4):
            info = furniture[kind][str(rot)]
            data["soil"][kind][str(rot)] = [save_image(stains(info, level, 810+k*10+rot), f"fx/sanitary/{kind}_{rot}_soil{level}.png") for level in range(1, 4)]
    for kind in ("water", "urine"):
        data["puddles"][kind] = [save_image(puddle(kind, n), f"fx/sanitary/{kind}_{n}.png") for n in range(3)]
    for frame in range(4):
        data["drops"].append(save_image(droplet(frame), f"fx/sanitary/drop_{frame}.png"))
        data["smell"].append(save_image(smell(frame), f"fx/sanitary/smell_{frame}.png"))
    data["repair"] = save_image(badge(), "fx/sanitary/repair.png")
    write_json("sanitary.json", data)
    # Keep the repair thought bubble in the normal character emote registry.
    ui = json.loads((OUT / "ui.json").read_text())
    ui["emotes"]["repair"] = data["repair"]
    write_json("ui.json", ui)
    return data


if __name__ == "__main__":
    export()
