"""Escort outfits on the curvy figure: hand-placed torso coverage maps.

Each map covers the curvy torso (pa_chars.CURVY, columns x = 9..23, 11 rows)
and says, pixel by pixel, what covers the body. The tone comes from the
figure's shading (bust, cleavage, waist, hips) unless the letter forces it.

    s skin      d skin, deep (cleavage, navel)
    a outfit    A outfit, lighter      k outfit, deep (seams, lacing)
    b second    B second, lighter      c third        C third, lighter
    m gold      M gold, shaded         l lace (outfit / skin)
    n lace (second colour / skin)      q sequins (outfit with sparkles)     v sheer voile (outfit weave over skin)

Outfits go by standing: the more prestigious the club, the classier the
escorts it attracts (see scripts/characters.gd STANDINGS).
"""
from __future__ import annotations

from pa_chars import HI, MID, SH, DEEP, FH, CURVY_X0

T = {
    # ---------------------------------------------------------------- standing 1 · débutante
    "lingerie": {  # push-up bra with lace trim, garter belt, briefs, stockings
        "front": ["....sAssssA....", "..sssAssssAss..", "..scccssscccss.", "..saaaadaaaaaaa", "..saaaakaaaaaa.",
                  "....aaaaaaa....", "....sssssss....", "...sssdsssss...", "..bbbbbbbbbbb..", ".ssbaaaaaabss..",
                  "..sbsaaaasbs..."],
        "back": ["....sAssssA....", "..sssAssssAss..", "..sssAssssAss..", "..aaaaaaaaaaa..", "...sssssssss...",
                 "....sssssss....", "....sssssss....", "...sssssssss...", "..bbbbbbbbbbb..", "..sbaaaaaaabss.",
                 "...baaaaaaabs.."],
    },
    "tube": {  # bandeau top, bare midriff, vinyl micro skirt, fishnets
        "front": ["....sssssss....", "..sssssssssss..", "..sAAAAdAAAAAA.", "..saaaakaaaaaaa", "..saaaaaaaaaaa.",
                  "....sssssss....", "....sssssss....", "...sssdsssss...", "..ccccccccccc..", ".bbbbbbbbbbbb..",
                  "..bbbbbbbbbb..."],
        "back": ["....sssssss....", "..sssssssssss..", "..sssssssssss..", "..AAAAAAAAAAA..", "...aaaaaaaaa...",
                 "....sssssss....", "....sssssss....", "...sssssssss...", "..ccccccccccc..", "..bbbbbbbbbbbb.",
                 "...bbbbbbbbbb.."],
    },
    # ---------------------------------------------------------------- standing 2 · confirmée
    "body": {  # lace bodysuit plunging to the waist, high-cut legs, thigh-high stockings
        "front": ["....asssssa....", "..aaasssssaaa..", "..allAsssAllaa.", "..alllAdAllllaa", "..alllAsAlllla.",
                  "....aaAsAaa....", "....aaaAaaa....", "...allllllla...", "..ssaaaaaaass..", ".ssssaaaaasss..",
                  "..ssssaaasss..."],
        "back": ["....asssssa....", "..aaasssssaaa..", "..aasssssssaa..", "..aasssssssaa..", "...asssssssa...",
                 "....aasssaa....", "....aaaaaaa....", "...allllllla...", "..aaaaaaaaaaa..", "..ssaaaaaaasss.",
                 "...ssaaaaasss.."],
    },
    "bodycon": {  # tight mini dress, deep neckline, thin straps
        "front": ["....asssssa....", "..ssasssssass..", "..aaaAsssAaaaa.", "..aaaaAdAaaaaaa", "..aaaaakaaaaaa.",
                  "....aaaaaaa....", "....aaaaaaa....", "...aaaaaaaaa...", "..aaaaaaaaaaa..", ".aaaaaaaaaaaa..",
                  "..aaaaaaaaaa..."],
        "back": ["....asssssa....", "..ssasssssass..", "..ssasssssass..", "..sasssssssas..", "...aasssssaa...",
                 "....aaaaaaa....", "....aaaaaaa....", "...aaaaaaaaa...", "..aaaaaaaaaaa..", "..aaaaaaaaaaaa.",
                 "...aaaaaaaaaa.."],
    },
    # ---------------------------------------------------------------- standing 3 · élégante
    "corset": {  # satin corset with gold lacing, garters, stockings, opera gloves
        "front": ["....sssssss....", "..sssssssssss..", "..sbbbsssbbbss.", "..aaAaadaAaaaaa", "..aaaaakaaaaaa.",
                  "....akacaka....", "....akacaka....", "...aakacakaa...", "..bbbbbbbbbbb..", ".ssbaaaaaabss..",
                  "..sbsaaaasbs..."],
        "back": ["....sssssss....", "..sssssssssss..", "..sssssssssss..", "..aaaaaaaaaaa..", "...aaaacaaaa...",
                 "....aacacaa....", "....aaacaaa....", "...aaacacaaa...", "..bbbbbbbbbbb..", "..sbaaaaaaabss.",
                 "...baaaaaaabs.."],
    },
    "cocktail": {  # satin slip dress, deep V, gold pendant in the cleavage
        "front": ["....asssssa....", "..ssamsssmass..", "..aaaAmsmAaaaa.", "..aaAaAMAaAaaaa", "..aaaaadaaaaaa.",
                  "....aAaaaaa....", "....aAaaaaa....", "...aaAaaaaaa...", "..aaaAaaaaaaa..", ".aaaaAaaaaaaa..",
                  "..aaaaAaaaaa..."],
        "back": ["....asssssa....", "..ssasssssass..", "..ssasssssass..", "..saasssssaas..", "...aasssssaa...",
                 "....aaaaaaa....", "....aAaaaaa....", "...aaAaaaaaa...", "..aaaAaaaaaaa..", "..aaaaAaaaaaaa.",
                 "...aaaaAaaaaa.."],
    },
    # ---------------------------------------------------------------- standing 4 · prestige
    "gown": {  # halter evening gown plunging to the gold belt, bare back, high slit
        "front": ["....sasssas....", "..sssamMmasss..", "..aaaAsssAaaaa.", "..aaaaAdAaaaaaa", "..aaaaAsAaaaaa.",
                  "....aaAsAaa....", "....aaaAaaa....", "...mMmMmMmMm...", "..aaaAaaaaaaa..", ".aaaaAaaaaaaa..",
                  "..aaaaAaaaaa..."],
        "back": ["....sasssas....", "..sssssssssss..", "..asssssssssa..", "..asssssssssa..", "...asssssssa...",
                 "....asssssa....", "....aasssaa....", "...mMmMmMmMm...", "..aaaaaaaaaaa..", "..aaaaaaaaaaaa.",
                 "...aaaaaaaaaa.."],
    },
    "sequin": {  # sparkling halter mini dress, plunging neckline, open back
        "front": ["....sqsssqs....", "..sssqsssqsss..", "..sqqqsssqqqss.", "..qqqqqdqqqqqqq", "..qqqqqsqqqqqq.",
                  "....qqqsqqq....", "....qqqqqqq....", "...qqqqqqqqq...", "..qqqqqqqqqqq..", ".qqqqqqqqqqqq..",
                  "..qqqqqqqqqq..."],
        "back": ["....sqsssqs....", "..sssssssssss..", "..sssssssssss..", "..qsssssssssq..", "...qsssssssq...",
                 "....qsssssq....", "....qqsssqq....", "...qqqqqqqqq...", "..qqqqqqqqqqq..", "..qqqqqqqqqqqq.",
                 "...qqqqqqqqqq.."],
    },
    # ---------------------------------------------------------------- hotter lingerie, one per standing
    "string": {  # débutante: little triangle bra and a string
        "front": ["....sAssssA....", "..sssAssssAss..", "..sssassssasss.", "..ssaAadaAaasss", "..skaaakaaaaks.",
                  "....sssssss....", "....sssssss....", "...sssdsssss...", "..aasssssssaa..", ".ssAaaaaaaaAs..",
                  "..sssaaaasss..."],
        "back": ["....sAssssA....", "..sssAssssAss..", "..sssAssssAss..", "..aaaaaaaaaaa..", "...sssssssss...",
                 "....sssssss....", "....sssssss....", "...sssssssss...", "..aaaaaaaaaaa..", "..sssssassssss.",
                 "...ssssasssss.."],
    },
    "balconnet": {  # confirmée: lace push-up balconette, lace string, garter belt, fishnet stockings
        "front": ["....sAssssA....", "..sssAssssAss..", "..scCcssscCccs.", "..sllaadalllaas", "..saaaakaaaaas.",
                  "....sssssss....", "....sssssss....", "...nnnnnnnnn...", "..bbbbbbbbbbb..", ".ssbslllllsbs..",
                  "..sbsslllsbs..."],
        "back": ["....sAssssA....", "..sssAssssAss..", "..sssAssssAss..", "..aaaaaaaaaaa..", "...sssssssss...",
                 "....sssssss....", "....sssssss....", "...nnnnnnnnn...", "..bbbbbbbbbbb..", "..sbsssasssbss.",
                 "...bsssasssbs.."],
    },
    "babydoll": {  # élégante: sheer babydoll over a bra and a string, stockings
        "front": ["....sAssssA....", "..sssAssssAss..", "..scaasssaaccs.", "..saaAadaAaaaas", "..cccccccccccc.",
                  "....vvvvvvv....", "....vvvvvvv....", "...vvvvvvvvv...", "..vbvvvvvvvbv..", ".vvvvbbbbbvvv..",
                  "..vvvbbbbvvv..."],
        "back": ["....sAssssA....", "..sssAssssAss..", "..sssAssssAss..", "..vvvvvvvvvvv..", "...ccccccccc...",
                 "....vvvvvvv....", "....vvvvvvv....", "...vvvvvvvvv...", "..vvvvvvvvvvv..", "..vvvvvbvvvvvv.",
                 "...vvvvbvvvvv.."],
    },
    "bijoux": {  # prestige: satin bra and string dressed in gold chains, body chain
        "front": ["....sMssssM....", "..sssMmsmsMss..", "..smmmsMsmmmss.", "..saAaadaAaaass", "..sMMMMMMMMMMs.",
                  "....sssmsss....", "....sssMsss....", "...sssmMmsss...", "..mMmsssssmMm..", ".ssmMaaaaaMms..",
                  "..sssaaaasss..."],
        "back": ["....sMssssM....", "..sssMssssMss..", "..sssMssssMss..", "..MMMMMMMMMMM..", "...sssssssss...",
                 "....sssssss....", "....sssssss....", "...sssssssss...", "..mMmMmMmMmMm..", "..sssssassssss.",
                 "...ssssasssss.."],
    },
}

# Legs: stockings (with lace tops and garters), fishnets or bare legs.
LEGS = {"lingerie": "garters", "tube": "fishnet", "body": "stockings", "bodycon": "bare",
        "corset": "garters", "cocktail": "bare", "gown": "bare", "sequin": "bare",
        "string": "bare", "balconnet": "fishnet_garters", "babydoll": "stockings", "bijoux": "bare"}
# Arms: opera gloves and gold bracelets.
GLOVES = {"corset", "gown"}
BRACELETS = {"bodycon", "cocktail", "gown", "sequin", "bijoux"}
# Skirts: (rows, flare, fabric); the gown falls to the ankles with a slit.
SKIRTS = {"tube": (3, 0.6, "b"), "bodycon": (4, 0.6, "a"), "cocktail": (6, 1.2, "a"),
          "gown": ("long", 2.4, "a"), "sequin": (4, 0.8, "q"), "babydoll": (3, 1.4, "v")}
CURVY_OUTFITS = list(T)


def lighter(tone):
    return max(tone - 1, HI)


def code_role(code, tone, x, y):
    """(role, tone) for one coverage letter at pixel (x, y)."""
    if code == "s":
        return "skin", tone
    if code == "d":
        return "skin", DEEP
    if code == "a":
        return "g1", tone
    if code == "A":
        return "g1", lighter(tone)
    if code == "k":
        return "g1", DEEP
    if code == "b":
        return "g2", tone
    if code == "B":
        return "g2", lighter(tone)
    if code == "c":
        return "g3", tone
    if code == "C":
        return "g3", lighter(tone)
    if code == "m":
        return "metal", HI
    if code == "M":
        return "metal", SH
    if code == "l":
        return ("g1", tone) if (x + y) % 2 == 0 else ("skin", tone)
    if code == "n":
        return ("g2", tone) if (x + y) % 2 == 0 else ("skin", tone)
    if code == "q":
        return sequin(tone, x, y)
    if code == "v":
        # sheer voile: a light weave over the skin
        return ("g1", lighter(tone)) if (x + 2 * y) % 4 == 0 else ("skin", tone)
    return "skin", tone


def sequin(tone, x, y):
    # a shimmering checker with a few scattered sparkles
    if (x * 7 + y * 3) % 13 == 0:
        return "shine", 0
    if (x + y) % 2 == 0:
        return "g1", lighter(tone)
    return "g1", tone


_derived = {}


def template(outfit, view, sil="galbee"):
    """The coverage map of an outfit on one body shape. The hand-drawn maps
    fit the "galbee" torso; for the others each pixel takes the letter of the
    matching pixel of the original. On the very generous bust the cups are
    stretched over the wider bust and reach one row lower (the waist keeps
    its first row)."""
    key = (outfit, view, sil)
    if key in _derived:
        return _derived[key]
    from pa_chars import CURVY_SIL
    shade = CURVY_SIL[sil][view]
    base = [r + "." * (len(shade[0]) - len(r)) for r in T[outfit][view]]
    rows = []
    for i, srow in enumerate(shade):
        busty = view == "front" and sil == "genereuse"
        src = base[{4: 3, 5: 4, 6: 5}.get(i, i) if busty else i]
        stretch = busty and 1 <= i <= 5
        out = ""
        for j, ch in enumerate(srow):
            if ch == ".":
                out += "."
                continue
            x = CURVY_X0 + j
            sx = x
            if stretch:
                # the cups stretch over the bigger bust, cleavage x16 -> x17
                if x <= 16:
                    sx = 11 + (x - 9) * 5 // 8
                elif x == 17:
                    sx = 16
                else:
                    sx = 17 + (x - 18) * 7 // 8
            sj = sx - CURVY_X0
            c = src[sj] if 0 <= sj < len(src) else "."
            if c == ".":
                near = [(abs(k - sj), src[k]) for k in range(len(src)) if src[k] != "."]
                c = min(near)[1] if near else "s"
            out += c
        rows.append(out)
    _derived[key] = rows
    return rows


def torso_code(fig, x, y):
    if fig.outfit_name not in T:
        return None
    rows = template(fig.outfit_name, fig.view, getattr(fig, "silhouette", "galbee"))
    cx, cy = x - fig.torso_x0, y - fig.top
    if 0 <= cy < len(rows) and 0 <= cx < len(rows[cy]):
        ch = rows[cy][cx]
        return None if ch == "." else ch
    return None


def garment(outfit, part, x, y, fig, tone):
    """(role, tone) for a pixel of an escort outfit."""
    k = part.kind
    t = float(part.t[y, x]) if part.t is not None else 0.0
    if k in ("foot", "heel"):
        return "shoe", tone
    if k == "torso":
        code = torso_code(fig, x, y)
        return code_role(code or "s", tone, x, y)
    if k == "skirt":
        fabric = SKIRTS[outfit][2]
        if fabric == "q":
            return sequin(tone, x, y)
        if fabric in ("l", "v"):
            # a solid hem keeps the shape of a sheer skirt
            if part.shade is not None and (y + 1 >= FH or not part.mask[y + 1, x]):
                return "g1", tone
            return code_role(fabric, tone, x, y)
        return ("g2" if fabric == "b" else "g1"), tone
    if k in ("thigh", "shin"):
        legs = LEGS[outfit]
        if legs == "fishnet":
            return ("g2", SH) if (x + y) % 2 == 0 else ("skin", tone)
        if legs == "fishnet_garters":
            # fishnet stockings with a lace top, held by garter straps
            if k == "shin" or t >= 0.6:
                return ("g2", SH) if (x + y) % 2 == 0 else ("skin", tone)
            if t >= 0.5:
                return "g3", tone
            centre = abs(float(part.rel[y, x])) < 0.34 if part.rel is not None else False
            if centre and fig.view == "front":
                return "g2", SH
            return "skin", tone
        if legs in ("stockings", "garters"):
            if k == "shin" or t >= 0.62:
                # sheer: the lit edge lets the skin show through
                return ("skin", SH) if tone == HI else ("g2", tone)
            if t >= 0.5:
                return ("g3" if legs == "garters" else "g2"), (tone if legs == "garters" else HI)
            centre = abs(float(part.rel[y, x])) < 0.34 if part.rel is not None else False
            if legs == "garters" and centre and fig.view == "front":
                return "g2", SH
        return "skin", tone
    if k in ("upper_arm", "forearm", "hand"):
        if outfit in BRACELETS and k == "forearm" and 0.78 <= t < 0.92:
            return "metal", HI
        if outfit in GLOVES and (k in ("forearm", "hand") or (k == "upper_arm" and t > 0.45)):
            return "g2", tone
        return "skin", tone
    return "skin", tone


def check_templates():
    from pa_chars import CURVY, CURVY_SIL, SILHOUETTES
    for name, views in T.items():
        for view, rows in views.items():
            shade = CURVY[view]
            assert len(rows) == len(shade), (name, view)
            for i, (a, b) in enumerate(zip(rows, shade)):
                assert len(a) == 15, (name, view, i, a)
                for ca, cb in zip(a, b[:15]):
                    assert (ca == ".") == (cb == "."), (name, view, i, a, b)
            for sil in SILHOUETTES:
                for a, b in zip(template(name, view, sil), CURVY_SIL[sil][view]):
                    assert len(a) == len(b) and all((ca == ".") == (cb == ".") for ca, cb in zip(a, b)), (name, view, sil)
