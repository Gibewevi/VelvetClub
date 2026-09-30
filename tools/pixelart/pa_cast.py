"""A reference cast of characters, composited in full colour, for previews
and documentation boards (the game composes the same layers at runtime)."""
import numpy as np

from pa_chars import build, FH, FW
from pa_dress import body_layer, face_layer, glasses_layer
from pa_hair import hair_layers, hat_layer
from pa_palette import palette

CAST = [
    dict(male=False, outfit="lingerie", hair="long", face="f0", skin="c58f73", hc="2b2030", oc="e0609a"),
    dict(male=False, outfit="dress", hair="bob", face="f1", skin="f0c3a4", hc="c0482c", oc="c01e44"),
    dict(male=False, outfit="body", hair="long", face="f2", skin="8a5a44", hc="1a1418", oc="2a1d30"),
    dict(male=False, outfit="blazer", hair="long", face="f1", skin="f2c9ab", hc="e2b25a", oc="6a3a8c"),
    dict(male=False, outfit="maid", hair="bun", face="f0", skin="e8b896", hc="6a3c24", oc="1e1a22", hat="headband"),
    dict(male=True, outfit="security", hair="fade", beard=1, skin="b98266", hc="231a16", oc="232a44", hat="police", glasses=1),
    dict(male=True, outfit="janitor", hair="short", beard=2, skin="d6a383", hc="2b1f18", oc="2e3c6e", hat="cap", glasses=2),
    dict(male=True, outfit="bartender", hair="short", beard=1, skin="e0ae8c", hc="8a4a2a", oc="1c1a20"),
    dict(male=True, outfit="suit", hair="short", beard=2, skin="c99273", hc="2a2226", oc="272838"),
    dict(male=True, outfit="casual", hair="curly", beard=0, skin="7a4a34", hc="161214", oc="8a2a3a"),
]


ESCORTS = [
    # débutante
    dict(male=False, outfit="lingerie", hair="long", face="f0", skin="c58f73", hc="2b2030", oc="e0609a"),
    dict(male=False, outfit="tube", hair="pony", face="f2", skin="f0c3a4", hc="e2b25a", oc="ff4f8a"),
    # confirmée
    dict(male=False, outfit="body", hair="waves", face="f3", skin="8a5a44", hc="1a1418", oc="8a2a8a"),
    dict(male=False, outfit="bodycon", hair="bob", face="f1", skin="e0ae8c", hc="c0482c", oc="c01e44"),
    # élégante
    dict(male=False, outfit="corset", hair="waves", face="f3", skin="f2c9ab", hc="8a2e24", oc="7a1030"),
    dict(male=False, outfit="cocktail", hair="long", face="f1", skin="b98266", hc="2b2030", oc="2a6a5a"),
    # prestige
    dict(male=False, outfit="gown", hair="bun", face="f3", skin="f0c3a4", hc="e2b25a", oc="a01030"),
    dict(male=False, outfit="sequin", hair="waves", face="f3", skin="7a4a34", hc="1a1418", oc="d0a040"),
    # hotter lingerie, one per standing
    dict(male=False, outfit="string", hair="pony", face="f2", skin="e0ae8c", hc="c0482c", oc="ff4f8a"),
    dict(male=False, outfit="balconnet", hair="long", face="f3", skin="f0c3a4", hc="1a1418", oc="1c1a20"),
    dict(male=False, outfit="babydoll", hair="waves", face="f1", skin="b98266", hc="e2b25a", oc="d02a5a"),
    dict(male=False, outfit="bijoux", hair="bun", face="f3", skin="8a5a44", hc="1a1418", oc="a01030"),
]


def frame_img(c, view, anim, f):
    """One 32 x 48 frame of a cast member, all layers flattened in colour."""
    from pa_escort import CURVY_OUTFITS
    fig = build(c["male"], view, anim, f, c["outfit"] in CURVY_OUTFITS, c.get("sil", "galbee"))
    hb, hf = hair_layers(c["hair"], fig)
    layers = [hb, body_layer(fig, c["outfit"]), face_layer(fig, c.get("face", "f0"), c.get("beard")), hf,
              hat_layer(c.get("hat"), fig), glasses_layer(fig, c.get("glasses"))]
    idx = np.zeros((FH, FW), dtype=int)
    for layer in layers:
        idx = np.where(layer > 0, layer, idx)
    pal = np.array(palette(c["skin"], c["hc"], c["oc"], c["outfit"]), dtype=np.uint8)
    img = np.zeros((FH, FW, 4), dtype=np.uint8)
    on = idx > 0
    img[on, :3] = pal[idx[on]]
    img[on, 3] = 255
    return img
