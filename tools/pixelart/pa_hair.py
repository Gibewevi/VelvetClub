"""Hair and headwear painted on the 32 x 48 character frame."""
from __future__ import annotations

import numpy as np

from pa_chars import FH, FW, PX, PY, XX, YY, N4, HI, MID, SH, DEEP, ri


def ellipse(cx, cy, rx, ry):
    return ((PX - cx) / rx) ** 2 + ((PY - cy) / ry) ** 2 <= 1.0


def polygon(points):
    """Even-odd point in polygon test at pixel centres."""
    inside = np.zeros((FH, FW), dtype=bool)
    n = len(points)
    for i in range(n):
        x1, y1 = points[i]
        x2, y2 = points[(i + 1) % n]
        cond = (y1 > PY) != (y2 > PY)
        dy = (y2 - y1) if y2 != y1 else 1e-9
        xint = (x2 - x1) * (PY - y1) / dy + x1
        inside ^= cond & (PX < xint)
    return inside


def line_above(x0, y0, x1, y1):
    return PY < y0 + (PX - x0) * (y1 - y0) / (x1 - x0)


# Styles return (back_mask, front_mask). Back hair is drawn before the body,
# front hair after the head.

def hair_masks(style, fig):
    hx, hy = fig.head
    cx = hx + 6.5
    front = fig.view == "front"
    bm = np.zeros((FH, FW), dtype=bool)
    fm = np.zeros((FH, FW), dtype=bool)
    if style == "long":
        crown = ellipse(cx - 0.2, hy + 6.3, 7.9, 7.4)
        if front:
            bm |= ellipse(cx - 0.3, hy + 7.0, 8.6, 8.4)
            bm |= polygon([(hx - 2.0, hy + 8), (hx + 15.5, hy + 8), (hx + 15.8, hy + 22), (hx + 14.0, hy + 27),
                           (hx + 11.5, hy + 25.5), (hx + 8.5, hy + 27.5), (hx + 5.0, hy + 26), (hx + 1.5, hy + 27.5),
                           (hx - 1.8, hy + 24)])
            fm |= crown & line_above(hx + 1.0, hy + 8.2, hx + 13.5, hy + 4.4)
            fm |= polygon([(hx - 1.6, hy + 4.5), (hx + 3.0, hy + 5.0), (hx + 3.6, hy + 12.0), (hx + 3.4, hy + 18.5),
                           (hx + 3.8, hy + 25.0), (hx + 1.2, hy + 26.2), (hx - 1.0, hy + 22.0), (hx - 1.8, hy + 14.0)])
            fm |= polygon([(hx + 12.2, hy + 3.8), (hx + 14.6, hy + 4.8), (hx + 15.4, hy + 11.5), (hx + 15.2, hy + 19.5),
                           (hx + 13.6, hy + 20.5), (hx + 12.9, hy + 13.0), (hx + 12.6, hy + 8.0)])
        else:
            fm |= ellipse(cx, hy + 6.8, 7.9, 7.8)
            # falls between the shoulder blades so the arms stay visible
            fm |= polygon([(hx - 0.6, hy + 8), (hx + 13.6, hy + 8), (hx + 12.6, hy + 14), (hx + 11.8, hy + 23.0),
                           (hx + 9.6, hy + 22.2), (hx + 7.0, hy + 24.0), (hx + 4.4, hy + 22.4), (hx + 2.2, hy + 23.2),
                           (hx + 1.4, hy + 14)])
    elif style == "bob":
        crown = ellipse(cx - 0.2, hy + 6.3, 8.0, 7.4)
        if front:
            bm |= ellipse(cx - 0.3, hy + 7.4, 8.6, 8.0)
            bm |= polygon([(hx - 1.8, hy + 8), (hx + 15.4, hy + 8), (hx + 15.4, hy + 15.5), (hx - 1.8, hy + 15.5)])
            fm |= crown & line_above(hx + 0.5, hy + 6.8, hx + 13.5, hy + 6.0)
            fm |= polygon([(hx - 1.8, hy + 4.5), (hx + 3.2, hy + 5.5), (hx + 3.6, hy + 11.5), (hx + 4.4, hy + 15.8),
                           (hx + 0.5, hy + 16.2), (hx - 1.9, hy + 14.5)])
            fm |= polygon([(hx + 12.4, hy + 4.4), (hx + 15.0, hy + 5.0), (hx + 15.6, hy + 12.0), (hx + 15.2, hy + 15.6),
                           (hx + 12.8, hy + 15.2), (hx + 12.9, hy + 9.0)])
        else:
            fm |= ellipse(cx, hy + 6.8, 8.3, 8.0)
            fm |= polygon([(hx - 1.8, hy + 8), (hx + 14.8, hy + 8), (hx + 14.8, hy + 15.8), (hx - 1.8, hy + 15.8)])
    elif style == "bun":
        crown = ellipse(cx - 0.1, hy + 6.4, 7.6, 7.0)
        bun = ellipse(hx + 3.5, hy - 0.2, 3.6, 3.2) if front else ellipse(cx, hy - 0.5, 3.8, 3.3)
        if front:
            bm |= bun
            fm |= crown & line_above(hx + 0.5, hy + 5.6, hx + 13.5, hy + 4.2)
            fm |= polygon([(hx - 1.0, hy + 4.5), (hx + 2.4, hy + 5.0), (hx + 2.2, hy + 11.5), (hx + 0.6, hy + 12.0),
                           (hx - 1.0, hy + 10.0)])
            fm |= polygon([(hx + 12.8, hy + 5.0), (hx + 14.2, hy + 5.4), (hx + 14.4, hy + 13.5), (hx + 13.2, hy + 12.8)])
        else:
            fm |= ellipse(cx, hy + 6.6, 7.9, 7.6) & (PY < hy + 13.5)
            fm |= bun
    elif style == "waves":
        # glamour: big side-parted waves falling over the shoulders
        crown = ellipse(cx - 0.2, hy + 6.0, 8.3, 7.6)
        if front:
            bm |= ellipse(cx - 0.3, hy + 7.0, 9.0, 8.6)
            bm |= polygon([(hx - 2.6, hy + 8), (hx + 16.2, hy + 8), (hx + 16.6, hy + 19), (hx + 15.2, hy + 24),
                           (hx + 13.0, hy + 25.5), (hx + 10.5, hy + 24.2), (hx + 7.5, hy + 25.8), (hx + 4.5, hy + 24.5),
                           (hx + 1.5, hy + 25.8), (hx - 2.4, hy + 22)])
            fm |= crown & line_above(hx + 0.5, hy + 4.4, hx + 13.8, hy + 6.8)
            fm |= polygon([(hx - 2.2, hy + 4.5), (hx + 2.8, hy + 5.0), (hx + 3.4, hy + 12.0), (hx + 3.2, hy + 16.5),
                           (hx + 2.0, hy + 19.5), (hx - 0.4, hy + 19.0), (hx - 2.0, hy + 16.0), (hx - 2.4, hy + 11.0)])
            fm |= polygon([(hx + 12.0, hy + 4.0), (hx + 15.0, hy + 5.0), (hx + 16.0, hy + 12.0), (hx + 15.8, hy + 17.5),
                           (hx + 16.4, hy + 20.5), (hx + 13.8, hy + 19.8), (hx + 13.0, hy + 14.0), (hx + 12.4, hy + 8.0)])
        else:
            fm |= ellipse(cx, hy + 6.8, 8.4, 8.0)
            fm |= polygon([(hx - 1.4, hy + 8), (hx + 14.4, hy + 8), (hx + 13.6, hy + 15), (hx + 13.0, hy + 23.5),
                           (hx + 10.6, hy + 22.6), (hx + 8.0, hy + 24.4), (hx + 5.4, hy + 22.8), (hx + 2.6, hy + 23.8),
                           (hx + 0.4, hy + 15)])
    elif style == "pony":
        # sleek high ponytail
        crown = ellipse(cx - 0.2, hy + 6.2, 7.7, 7.2)
        if front:
            bm |= polygon([(hx - 0.5, hy - 1.5), (hx + 4.0, hy - 2.0), (hx + 3.0, hy + 3.0), (hx + 0.5, hy + 8.0),
                           (hx - 1.5, hy + 14.0), (hx - 2.8, hy + 18.5), (hx - 3.6, hy + 14.5), (hx - 3.2, hy + 8.0),
                           (hx - 1.8, hy + 2.0)])
            fm |= crown & line_above(hx + 0.5, hy + 4.0, hx + 13.5, hy + 3.2)
            fm |= crown & (PX < hx + 2.4) & (PY < hy + 9.5)
        else:
            fm |= ellipse(cx, hy + 6.2, 7.8, 7.2) & (PY < hy + 11.0)
            fm |= polygon([(cx - 2.2, hy + 0.5), (cx + 2.2, hy + 0.5), (cx + 2.6, hy + 8.0), (cx + 1.8, hy + 16.0),
                           (cx, hy + 19.0), (cx - 1.8, hy + 16.0), (cx - 2.6, hy + 8.0)])
    elif style == "fade":
        top = ellipse(cx - 0.2, hy + 5.8, 7.6, 6.4)
        if front:
            fm |= top & line_above(hx + 0.5, hy + 5.2, hx + 13.5, hy + 3.4)
            fm |= top & (PX < hx + 2.6) & (PY < hy + 9.5)
        else:
            fm |= ellipse(cx, hy + 6.0, 7.8, 7.0) & (PY < hy + 10.5)
    elif style == "short":
        top = ellipse(cx - 0.2, hy + 5.8, 7.8, 6.8)
        if front:
            fm |= top & line_above(hx + 0.5, hy + 6.0, hx + 13.5, hy + 3.8)
            fm |= top & (PX < hx + 3.0) & (PY < hy + 10.5)
        else:
            fm |= ellipse(cx, hy + 6.2, 8.0, 7.4) & (PY < hy + 12.0)
    elif style == "shaved":
        top = ellipse(cx - 0.2, hy + 6.0, 7.0, 6.0)
        if front:
            fm |= top & line_above(hx + 0.5, hy + 4.2, hx + 13.5, hy + 2.8)
        else:
            fm |= ellipse(cx, hy + 6.0, 7.0, 6.5) & (PY < hy + 9.5)
    elif style == "curly":
        if front:
            fm |= ellipse(cx - 0.4, hy + 4.8, 8.4, 6.2) & line_above(hx + 0.5, hy + 6.4, hx + 13.5, hy + 4.4)
            fm |= ellipse(hx + 1.2, hy + 7.5, 2.6, 4.2)
        else:
            fm |= ellipse(cx, hy + 5.8, 8.6, 7.6) & (PY < hy + 12.5)
    return bm, fm


def hair_tones(style, fig):
    hx, hy = fig.head
    cx = hx + 6.5
    tones = np.full((FH, FW), MID)
    nx = (PX - cx) / 8.0
    ny = (PY - (hy + 6.5)) / 8.0
    r = np.hypot(nx, ny)
    tones[nx > 0.45] = SH
    long_part = PY > hy + 10
    tones[((XX + (YY // 5)) % 4 == 0) & long_part] = SH
    if fig.view == "back":
        # the parting and a soft shine band read from behind
        tones[(np.abs(PX - cx) < 0.6) & (PY < hy + 4) & (PY > hy + 0.5)] = DEEP
        tones[(np.abs(PY - (hy + 5.5)) < 0.6) & (np.abs(PX - cx) > 1.5) & (np.abs(PX - cx) < 5)] = HI
    arc = (r > 0.55) & (r < 0.78) & (ny < -0.15) & (nx < 0.25) & (nx > -0.75)
    if style == "shaved":
        tones[:] = SH
        tones[((XX + YY) % 2) == 0] = DEEP
    elif style == "fade":
        tones[arc] = HI
        side = (PY > hy + 5) & ((PX < hx + 3) | (PX > hx + 11))
        tones[side & (((XX + YY) % 2) == 0)] = DEEP
        tones[side & (((XX + YY) % 2) == 1)] = SH
    elif style == "waves":
        tones[arc] = HI
        wave = (YY + (XX // 2)) % 5
        tones[long_part & (wave == 0)] = SH
        tones[long_part & (wave == 2) & (nx < 0.35)] = HI
    elif style == "pony":
        tones[arc] = HI
        tie = (np.abs(PY - (hy + 1.0)) < 0.6) & (np.abs(PX - (hx + 1.5 if fig.view == "front" else cx)) < 2.6)
        tones[tie] = DEEP
        tones[(PY > hy + 3) & ((XX + YY) % 3 == 0) & (np.abs(PX - cx) > 7)] = SH
    elif style == "curly":
        curls = (XX * 3 + YY * 5) % 7 < 2
        tones[curls] = SH
        tones[arc & ~curls] = HI
    else:
        tones[arc] = HI
        tones[long_part & ((XX + (YY // 6)) % 6 == 2) & (nx < 0.2)] = HI
    tips = PY > hy + 23
    tones[tips] = np.maximum(tones[tips], SH)
    return tones


def hair_layers(style, fig):
    """(back_idx, front_idx) index arrays for one frame; 0 = transparent."""
    back = np.zeros((FH, FW), dtype=int)
    front = np.zeros((FH, FW), dtype=int)
    if not style:
        return back, front
    bm, fm = hair_masks(style, fig)
    both = bm | fm
    tones = hair_tones(style, fig)
    for y in range(FH):
        for x in range(FW):
            if fm[y, x]:
                front[y, x] = ri("hair", tones[y, x])
            elif bm[y, x]:
                back[y, x] = ri("hair", tones[y, x])
    hx, hy = fig.head
    for y in range(FH):
        for x in range(FW):
            if both[y, x]:
                continue
            touch_f = touch_b = False
            for dy, dx in N4:
                yy, xx = y + dy, x + dx
                if 0 <= yy < FH and 0 <= xx < FW:
                    touch_f |= bool(fm[yy, xx])
                    touch_b |= bool(bm[yy, xx])
            if touch_f:
                # The fringe edge over the face reads softer in the deepest hair tone.
                over_face = fig.view == "front" and hy + 3 < y < hy + 11 and hx + 3 < x < hx + 12 and fm[y - 1, x]
                front[y, x] = ri("hair", DEEP) if over_face else ri("ink")
            elif touch_b:
                back[y, x] = ri("ink")
    return back, front


def hat_layer(hat, fig):
    out = np.zeros((FH, FW), dtype=int)
    if not hat:
        return out
    hx, hy = fig.head
    cx = hx + 6.5
    front = fig.view == "front"
    mask = np.zeros((FH, FW), dtype=bool)
    tone = np.full((FH, FW), MID)
    role = np.full((FH, FW), "g1", dtype=object)
    if hat == "police":
        crown = ellipse(cx + (0.5 if front else 0), hy + 1.6, 8.6, 3.6)
        band = (PY >= hy + 2.5) & (PY < hy + 5.5) & ellipse(cx, hy + 3.0, 7.9, 6.0)
        mask |= crown | band
        tone[crown & (PX < cx - 3)] = HI
        tone[crown & (PX > cx + 4)] = SH
        tone[band] = DEEP
        if front:
            visor = polygon([(hx + 4.5, hy + 5.0), (hx + 16.8, hy + 5.4), (hx + 16.2, hy + 7.4), (hx + 5.0, hy + 6.6)])
            mask |= visor
            role[visor] = "shoe"
            tone[visor] = SH
            tone[visor & (PY < hy + 6.0)] = HI
            badge = (XX == int(hx + 8)) & (YY >= int(hy + 1)) & (YY <= int(hy + 2))
            role[badge] = "metal"
            tone[badge] = HI
    elif hat == "cap":
        dome = ellipse(cx - 0.3, hy + 4.8, 7.8, 5.0) & (PY < hy + 5.6)
        mask |= dome
        tone[dome & (PX < cx - 2)] = HI
        tone[dome & (PX > cx + 3)] = SH
        if front:
            brim = polygon([(hx + 7.0, hy + 4.4), (hx + 17.2, hy + 5.6), (hx + 16.8, hy + 7.3), (hx + 7.4, hy + 6.4)])
            mask |= brim
            tone[brim] = SH
            tone[brim & (PY < hy + 5.6)] = MID
        else:
            tone[(PY >= hy + 4.5) & (PY < hy + 6) & (np.abs(PX - cx) < 2)] = DEEP
        tone[(XX == int(cx - 0.5)) & (YY == int(hy))] = HI
    elif hat == "headband":
        band = ellipse(cx - 0.2, hy + 5.0, 8.0, 6.4) & (PY >= hy - 0.5) & (PY < hy + 2.2)
        mask |= band
        role[band] = "g2"
        tone[band & (PY < hy + 1.0) & (XX % 2 == 0)] = HI
        tone[band & (PX > cx + 4)] = SH
    for y in range(FH):
        for x in range(FW):
            if mask[y, x]:
                out[y, x] = ri(role[y, x], tone[y, x])
    for y in range(FH):
        for x in range(FW):
            if not mask[y, x] and any(0 <= y + dy < FH and 0 <= x + dx < FW and mask[y + dy, x + dx] for dy, dx in N4):
                out[y, x] = ri("ink")
    return out
