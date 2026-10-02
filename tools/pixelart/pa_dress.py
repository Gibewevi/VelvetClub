"""Outfits, faces and small props for the 32 x 48 characters."""
from __future__ import annotations

import numpy as np

from pa_chars import (plan_of, FH, FW, N4, HI, MID, SH, DEEP, ri, Part, limb, blob,
                      head_pixels, FACES, FACE_LEGEND, BEARDS, GLASSES, HAIR_LEGEND, ascii_points)
import pa_escort


def garment(outfit, part, x, y, fig):
    """Return (role, tone override or None) for one body pixel."""
    k = part.kind
    t = float(part.t[y, x]) if part.t is not None else 0.0
    rel = y - fig.top
    r = float(part.rel[y, x]) if part.rel is not None else 0.0
    back = fig.view == "back"
    R = plan_of(fig.male)["rows"]
    if k in ("foot", "heel"):
        return "shoe", None
    if k in ("mop_handle", "shovel_handle", "roller_pole"):
        return "wood", None
    if k == "mop_head":
        return "prop", None
    if k in ("shovel_blade", "trowel"):
        return "metal", None
    if k == "roller":
        return "g3", None
    if outfit == "dress":
        b0, b1 = R["bust"]
        if k == "torso":
            if rel < b0 - 1:
                return ("g1", HI) if abs(abs(r) - 0.45) < 0.18 else ("skin", None)
            if rel == b0 - 1 and abs(r) < 0.3 and not back:
                return "skin", SH
            return "g1", (SH if rel == b1 + 1 else None)
        if k == "skirt":
            return "g1", None
        return "skin", None
    if outfit == "blazer":
        if k == "torso":
            if not back and rel <= 4 and abs(r) < 0.36 - rel * 0.03:
                return ("skin", None) if rel <= 3 else ("g3", None)
            if not back and rel <= 5 and abs(abs(r) - (0.42 - rel * 0.03)) < 0.12:
                return "g1", HI
            if rel >= R["skirt"]:
                return "g2", None
            return "g1", None
        if k == "skirt":
            return "g2", None
        if k == "upper_arm":
            return "g1", None
        if k == "forearm":
            return ("g1", None) if t < 0.78 else ("skin", None)
        return "skin", None
    if outfit == "maid":
        if k == "torso":
            if not back and rel <= 1 and abs(r) < 0.55:
                return "g2", HI
            if not back and rel >= R["apron"] and abs(r) < 0.62:
                return "g2", (SH if rel == R["apron"] else None)
            if back and rel == R["apron"] + 2 and abs(r) < 0.3:
                return "g2", None
            return "g1", None
        if k == "skirt":
            if not back and abs(r) < 0.55:
                return "g2", None
            return "g1", None
        if k == "upper_arm":
            if t < 0.35:
                return "g1", None
            return ("g2", HI) if t < 0.5 else ("skin", None)
        if k in ("thigh", "shin"):
            return "g3", None
        return "skin", None
    # ------------------------------------------------ men
    if outfit == "suit":
        if k == "torso":
            if not back and rel <= 6 and abs(r) < 0.34 - rel * 0.035:
                if abs(r) < 0.12 and rel >= 1:
                    return "g3", (SH if rel % 3 == 2 else None)
                return "g2", None
            if not back and rel <= 7 and abs(abs(r) - (0.42 - rel * 0.035)) < 0.1:
                return "g1", HI
            return "g1", (SH if rel >= 10 else None)
        if k == "upper_arm":
            return "g1", None
        if k == "forearm":
            return ("g1", None) if t < 0.82 else ("g2", HI)
        if k in ("thigh", "shin"):
            return "g1", (SH if k == "shin" and t > 0.7 else None)
        if k == "neck" and not back and y >= fig.top - 1:
            return "g2", None
        return "skin", None
    if outfit == "casual":
        if k == "torso":
            if rel <= 1 and abs(r) < 0.35 and not back:
                return "skin", None
            if rel == R["belt"] + 1:
                return "g3", None
            return ("g1", None) if rel <= R["belt"] else ("g2", None)
        if k == "upper_arm":
            return ("g1", None) if t < 0.55 else ("skin", None)
        if k in ("thigh", "shin"):
            return "g2", None
        return "skin", None
    if outfit == "security":
        if k == "torso":
            if rel == R["belt"] + 1:
                return "g3", None
            if not back and rel == R["badge"] and -0.52 < r < -0.2:
                return "metal", HI
            if not back and rel in (R["badge"] - 1, R["badge"] + 1) and -0.62 < r < -0.1:
                return "g1", HI
            if not back and abs(r) < 0.09 and rel <= R["belt"]:
                return "g1", SH
            return "g1", None
        if k == "upper_arm":
            return "g1", None
        if k == "forearm":
            return ("g1", None) if t < 0.85 else ("g2", None)
        if k in ("thigh", "shin"):
            return "g1", (SH if k == "shin" and t > 0.75 else None)
        if k == "hand":
            return "g2", None
        return "skin", None
    if outfit == "janitor":
        if k == "torso":
            if rel <= R["belt"] + 1 and abs(abs(r) - 0.42) < 0.13:
                return "g3", None
            if not back and R["pocket"][0] <= rel <= R["pocket"][1] and -0.3 < r < 0.2:
                return "g1", HI
            return "g1", None
        if k == "upper_arm":
            return "g1", None
        if k == "forearm":
            return ("g1", None) if t < 0.5 else ("skin", None)
        if k in ("thigh", "shin"):
            return "g1", (SH if k == "shin" and t > 0.8 else None)
        if k == "hand":
            return "g2", None
        return "skin", None
    if outfit.startswith("hivis"):
        # site worker: orange high-visibility vest with two reflective bands
        # over a dark T-shirt, dark work trousers
        if k == "torso":
            if rel > R["belt"]:
                return "g2", (SH if rel == R["belt"] + 1 else None)
            if not back and rel <= 1 and abs(r) < 0.3:
                return "g2", None
            if rel in (4, 6):
                return "g3", HI
            if not back and abs(r) < 0.08 and rel >= 2:
                return "g1", SH
            return "g1", None
        if k == "upper_arm":
            return "g2", None
        if k in ("thigh", "shin"):
            return "g2", (SH if k == "shin" and t > 0.8 else None)
        return "skin", None
    if outfit == "bartender":
        if k == "torso":
            if not back and abs(r) < 0.30 and rel <= R["belt"]:
                if rel == 1 and abs(r) < 0.25:
                    return "g3", None
                return "g2", None
            if rel == R["belt"] + 1:
                return "g3", DEEP
            return "g1", None
        if k == "upper_arm":
            return "g2", None
        if k == "forearm":
            return ("g2", None) if t < 0.55 else ("skin", None)
        if k in ("thigh", "shin"):
            return "g1", None
        return "skin", None
    return "skin", None


def skirt_part(fig, length, flare, order=4.6):
    """A skirt hanging from the hips: widens by `flare` px over `length` rows
    ("long" falls to the ankles). It covers the legs, which walk beneath."""
    hip_row = fig.top + plan_of(fig.male)["rows"].get("skirt", 9)
    if length == "long":
        length = int(plan_of(fig.male)["ankle_y"]) - hip_row
    base = [p for p in fig.parts if p.kind == "torso"][0]
    cols = np.nonzero(base.mask[hip_row])[0]
    if len(cols) == 0:
        return None
    a, b = cols.min(), cols.max()
    m = np.zeros((FH, FW), dtype=bool)
    shade = np.ones((FH, FW), dtype=int)
    rel = np.zeros((FH, FW))
    xs = np.arange(FW)
    for i in range(length):
        y = hip_row + i
        grow = flare * i / max(length - 1, 1)
        aa, bb = int(round(a - grow)), int(round(b + grow))
        m[y, aa:bb + 1] = True
        c = (aa + bb) / 2
        w = max((bb - aa) / 2, 0.5)
        nx = (xs - c) / w
        rel[y] = nx
        s = np.full(FW, MID)
        s[nx >= 0.55] = SH
        s[nx <= -0.7] = HI
        s[((xs - aa) % 3 == 2) & (i > 1) & (nx < 0.55)] = SH
        if i == length - 1:
            s[:] = SH
        shade[y] = np.where(m[y], s, shade[y])
    return Part("skirt", m, order, shade, np.zeros((FH, FW)), "", rel)


OUTFIT_SKIRTS = {"dress": (6, 1.6), "blazer": (6, 0.6), "maid": (6, 2.2)}
for _name, (_len, _flare, _fabric) in pa_escort.SKIRTS.items():
    OUTFIT_SKIRTS[_name] = (_len, _flare)
# Parts that belong to one continuous body: no dark crease where they meet.
SEAMLESS = {"torso", "thigh", "shin", "foot", "heel"}


def body_layer(fig, outfit):
    fig.outfit_name = outfit
    parts = list(fig.parts)
    if outfit in OUTFIT_SKIRTS:
        length, flare = OUTFIT_SKIRTS[outfit]
        if fig.anim == "sit":
            length, flare = (7, 2.0) if length == "long" else (3, 1.0)
        elif fig.anim == "kneel":
            length, flare = (9, 1.0) if length == "long" else (min(length, 7), 1.0)
        sk = skirt_part(fig, length, flare)
        if sk is not None:
            if outfit == "gown" and fig.anim not in ("sit", "kneel"):
                # the high slit shows the near leg
                slit_from = fig.top + plan_of(fig.male)["rows"]["skirt"] + 3
                for p in fig.parts:
                    if p.kind in ("thigh", "shin") and p.side == "near":
                        cut = p.mask.copy()
                        cut[:slit_from] = False
                        sk.mask &= ~cut
            parts.append(sk)
    behind = fig.view != "front"
    if getattr(fig, "mop", None):
        a, b = fig.mop
        o = 0.5 if behind else 5.0
        if outfit.startswith("hivis"):
            # a site shovel: wooden handle, steel blade on the ground
            parts.append(limb("shovel_handle", a, b, 0.55, 0.55, o))
            parts.append(blob("shovel_blade", b[0] + (-0.5 if behind else 0.5), b[1] - 1.0, 2.2, 1.7, o + 0.1))
        else:
            parts.append(limb("mop_handle", a, b, 0.55, 0.55, o))
            parts.append(blob("mop_head", b[0] + 0.3, b[1] - 0.3, 3.4, 1.3, o + 0.1))
    if outfit.startswith("hivis") and fig.anim == "work":
        # the hand reaching furthest forward holds the tool
        hands = sorted([fig.hand_near, fig.hand_far], key=lambda h: h[0])
        hx, hy = hands[0] if behind else hands[-1]
        o = 0.5 if behind else 6.5
        d = -1 if behind else 1
        if outfit == "hivis_roller":
            # paint roller on a short pole, pressed against the wall ahead
            top = (hx + 4.0 * d, hy - 10.0)
            parts.append(limb("roller_pole", (hx, hy + 0.5), top, 0.55, 0.55, o))
            parts.append(limb("roller", (top[0] - 2.5, top[1] - 0.5), (top[0] + 2.5, top[1] + 0.5), 1.1, 1.1, o + 0.1))
        else:
            # mason's trowel held out ahead
            parts.append(limb("trowel", (hx + 0.5 * d, hy + 1.0), (hx + 3.0 * d, hy + 2.0), 0.9, 0.6, o))
    order = sorted(range(len(parts)), key=lambda k: parts[k].order)
    owner = np.full((FH, FW), -1)
    for k in order:
        owner[parts[k].mask] = k
    idx = np.zeros((FH, FW), dtype=int)
    for y in range(FH):
        for x in range(FW):
            k = owner[y, x]
            if k < 0:
                continue
            p = parts[k]
            if outfit in pa_escort.T:
                role, tn = pa_escort.garment(outfit, p, x, y, fig, int(p.shade[y, x]))
            else:
                role, tone = garment(outfit, p, x, y, fig)
                tn = p.shade[y, x] if tone is None else tone
            for dy, dx in N4:
                yy, xx = y + dy, x + dx
                if 0 <= yy < FH and 0 <= xx < FW:
                    k2 = owner[yy, xx]
                    if k2 < 0 or k2 == k or parts[k2].order <= p.order + 0.5:
                        continue
                    other = parts[k2].kind
                    if other in ("neck", "skirt") or (p.kind in SEAMLESS and other in SEAMLESS and "torso" in (p.kind, other)):
                        continue
                    tn = DEEP
                    break
            idx[y, x] = ri(role, tn)
    solid = owner >= 0
    out = idx.copy()
    for y in range(FH):
        for x in range(FW):
            if not solid[y, x] and any(0 <= y + dy < FH and 0 <= x + dx < FW and solid[y + dy, x + dx] for dy, dx in N4):
                out[y, x] = ri("ink")
    hx, hy = fig.head
    for (x, y), (role, tn) in head_pixels(fig.male, fig.view).items():
        X, Y = hx + x, hy + y
        if 0 <= X < FW and 0 <= Y < FH:
            out[Y, X] = ri(role, tn)
    return out


def face_layer(fig, face, beard=None):
    out = np.zeros((FH, FW), dtype=int)
    if fig.view != "front":
        return out
    hx, hy = fig.head
    rows = FACES["m" if fig.male else face]
    for (x, y, role, tn) in ascii_points(rows, (hx, hy), FACE_LEGEND):
        if 0 <= x < FW and 0 <= y < FH:
            out[y, x] = ri(role, tn)
    if fig.male and beard is not None:
        for (x, y, role, tn) in ascii_points(BEARDS[beard], (hx, hy), HAIR_LEGEND):
            if 0 <= x < FW and 0 <= y < FH:
                out[y, x] = ri(role, tn)
    return out


def glasses_layer(fig, kind):
    out = np.zeros((FH, FW), dtype=int)
    if not kind or fig.view != "front":
        return out
    hx, hy = fig.head
    row = hy + 8
    legend = {"o": ("ink", 0), "s": ("lens", MID)}
    for (x, y, role, tn) in ascii_points(GLASSES[kind], (hx, row), legend):
        if 0 <= x < FW and 0 <= y < FH:
            out[y, x] = ri(role, tn)
    if kind == 1:
        out[row + 1, hx + 4] = ri("lens", HI)
        out[row + 1, hx + 10] = ri("lens", HI)
    return out
