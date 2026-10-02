"""Export character sprite sheets (palette indices) and their manifest."""
from __future__ import annotations

import numpy as np

from pa_core import save, write_json, preview, OUT
from pa_chars import build, pose, FRAMES, FH, FW, IDX_SCALE, ROLES, PALETTE_SIZE, ANIMS_FRONT, ANIMS_BACK
from pa_dress import body_layer, face_layer, glasses_layer
from pa_hair import hair_layers, hat_layer
from pa_palette import OUTFITS, FIXED, palette
from pa_escort import CURVY_OUTFITS
from pa_chars import SILHOUETTES

# Order matters: saved appearances store the index (0-4 are the historic ones).
FEMALE_OUTFITS = ["lingerie", "body", "dress", "blazer", "maid", "tube", "bodycon", "corset", "cocktail", "gown", "sequin",
                  "string", "balconnet", "babydoll", "bijoux"]
MALE_OUTFITS = ["security", "janitor", "casual", "suit", "bartender"]
FEMALE_HAIR = ["long", "bob", "bun", "waves", "pony"]
MALE_HAIR = ["fade", "short", "shaved", "short", "curly"]   # index 1 = short hair under a cap
HATS = {"security": "police", "maid": "headband"}
WORKER_OUTFITS = ["hivis", "hivis_roller"]   # shovel and trowel / paint roller


def to_rgba(idx):
    img = np.zeros((FH, FW, 4), dtype=np.uint8)
    on = idx > 0
    img[..., 0] = np.where(on, idx * IDX_SCALE, 0)
    img[..., 3] = np.where(on, 255, 0)
    return img


def sheet(fn, head_layer=False):
    frames = []
    for (view, anim, f) in FRAMES:
        if head_layer and anim == "kneel":
            # Keep face and hair details rigid during the neutral resting breath.
            # Re-shading at a different absolute Y would make small pixels flicker.
            base = fn(view, anim, 0)
            dy = pose(anim, f, view)["bob"]
            idx = np.roll(base, dy, axis=0)
            if dy < 0:
                idx[dy:] = 0
            elif dy > 0:
                idx[:dy] = 0
        else:
            idx = fn(view, anim, f)
        frames.append(to_rgba(idx))
    return np.concatenate(frames, axis=1)


_figs = {}


def fig(male, view, anim, f, curvy=False, sil="galbee"):
    key = (male, view, anim, f, curvy, sil)
    if key not in _figs:
        _figs[key] = build(male, view, anim, f, curvy, sil)
    return _figs[key]


def export():
    files = {}
    for male, outfits in ((False, FEMALE_OUTFITS), (True, MALE_OUTFITS)):
        b = "m" if male else "f"
        for outfit in outfits:
            curvy = outfit in CURVY_OUTFITS
            for sil in (SILHOUETTES if curvy else ["galbee"]):
                # escort outfits exist on each body shape: body_f_<outfit>[_genereuse|_fine]
                suffix = "" if sil == "galbee" else "_" + sil
                path = f"chars/body_{b}_{outfit}{suffix}.png"
                save(sheet(lambda v, a, f: body_layer(fig(male, v, a, f, curvy, sil), outfit)), path)
                files[f"body_{b}_{outfit}{suffix}"] = path
        if male:
            # construction workers only (not offered in the outfit editor)
            for outfit in WORKER_OUTFITS:
                path = f"chars/body_m_{outfit}.png"
                save(sheet(lambda v, a, f: body_layer(fig(male, v, a, f), outfit)), path)
                files[f"body_m_{outfit}"] = path
        for style in sorted(set(MALE_HAIR if male else FEMALE_HAIR)):
            back = sheet(lambda v, a, f: hair_layers(style, fig(male, v, a, f))[0], head_layer=True)
            front = sheet(lambda v, a, f: hair_layers(style, fig(male, v, a, f))[1], head_layer=True)
            save(back, f"chars/hairb_{b}_{style}.png")
            save(front, f"chars/hairf_{b}_{style}.png")
            files[f"hairb_{b}_{style}"] = f"chars/hairb_{b}_{style}.png"
            files[f"hairf_{b}_{style}"] = f"chars/hairf_{b}_{style}.png"
        faces = [0, 1, 2] if male else ["f0", "f1", "f2", "f3"]
        for face in faces:
            name = f"face_{b}_{face}"
            save(sheet(lambda v, a, f: face_layer(fig(male, v, a, f), "f0" if male else face, face if male else None), head_layer=True),
                 f"chars/{name}.png")
            files[name] = f"chars/{name}.png"
        for hat in (["police", "cap", "hardhat"] if male else ["headband"]):
            name = f"hat_{b}_{hat}"
            save(sheet(lambda v, a, f: hat_layer(hat, fig(male, v, a, f)), head_layer=True), f"chars/{name}.png")
            files[name] = f"chars/{name}.png"
        for g in (1, 2):
            name = f"glasses_{b}_{g}"
            save(sheet(lambda v, a, f: glasses_layer(fig(male, v, a, f), g), head_layer=True), f"chars/{name}.png")
            files[name] = f"chars/{name}.png"
    anims = {}
    for i, (view, anim, f) in enumerate(FRAMES):
        anims.setdefault(f"{view}:{anim}", []).append(i)
    write_json("chars.json", {
        "frame": [FW, FH], "anchor": [16, 46], "index_scale": IDX_SCALE, "palette_size": PALETTE_SIZE,
        "frames": len(FRAMES), "anims": anims, "files": files, "roles": ROLES,
        "female_outfits": FEMALE_OUTFITS, "male_outfits": MALE_OUTFITS,
        "female_hair": FEMALE_HAIR, "male_hair": MALE_HAIR, "hats": HATS, "silhouettes": SILHOUETTES,
        "outfits": OUTFITS, "fixed": {k: (list(v) if isinstance(v, tuple) else v) for k, v in FIXED.items()},
    })
    return files


if __name__ == "__main__":
    export()
    print("chars exported to", OUT / "chars")
