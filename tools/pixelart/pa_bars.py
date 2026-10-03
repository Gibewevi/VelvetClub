"""Bars and visible bottle stock, drawn on the game's native isometric grid."""
import math
import numpy as np
from pathlib import Path
from PIL import Image
from pa_iso import box, cyl, rod, ell, Mat, stroke
from pa_draw2d import heart_points
from pa_furniture import Item, M, bottle, panels, tag, combine, grain

COUNTERS = ["bar_module", "bar_round", "bar_l", "bar_luxe"]
SHELVES = {"backbar": (2, .5, 8, 2), "bottles_small": (1.2, .5, 3, 4),
           "bottles_arch": (2.4, .55, 9, 3), "bottles_luxe": (2.6, .6, 12, 3)}
STOCK = list(SHELVES) + ["bottle_crate"]
SOURCES = Path(__file__).parent / "sources" / "bars"
NEON = Mat(tones=["72133d", "ff278f", "ff73c5", "fff3ed", "fff9f4", "ffffff"], emissive=True, line=False)
STONE = Mat(tones=["262337", "443a55", "635471", "82748e", "ae9ab6", "d0bdcf"])
BOTTLES = [Mat(tones=["1b101e","244633","244633","497342","497342","7fa64d"]),
           Mat(tones=["1b101e","735243","735243","a97647","a97647","cca25f"]),
           Mat(tones=["1b101e","6a2234","6a2234","922038","922038","c42a40"])]
LABEL = Mat(tones=["735243","aca3ab","aca3ab","d2c2ba","d2c2ba","f3e3c4"])


def plant(x,y,z):
    p=[cyl(x,y,z,.13,.16,M["terracotta"]),cyl(x,y+.15,z,.15,.04,M["gold"])]
    for i in range(6):
        a=i*math.pi/3
        tip=(x+math.cos(a)*.22,y+.40+(i%2)*.1,z+math.sin(a)*.18)
        p += [rod((x,y+.17,z),tip,.014,M["bottle_g"]),ell(*tip,.08,.1,.04,M["bottle_g"])]
    return p


def table_lamp(x,y,z):
    return [cyl(x,y,z,.1,.035,M["gold"]),cyl(x,y,z,.023,.24,M["gold"]),
            ell(x,y+.32,z,.13,.11,.13,M["shade"]),cyl(x,y+.23,z,.145,.055,M["shade"])]


def inventory(*prims):
    for p in prims: p.stock_bottle = True
    return list(prims)


def paint(cv,it,kind,r):
    """Paintings retain native geometry; only stocked bottle pixels change.

    Never recolour the cabinet as stock changes. The four paintings share
    exactly the same anchors/extent across every inventory level.
    """
    base=kind.split("_fill_")[0]
    path=SOURCES / "native" / f"{base}_{r}.png"
    if not path.exists(): return
    pic=np.array(Image.open(path).convert("RGBA"))
    if pic.shape != cv.rgba.shape: raise ValueError(f"Painting geometry changed: {path}")
    native=cv.rgba.copy()
    # Keep the old contact shadow, replace the whole solid furniture.
    under=native.copy();under[under[...,3]>128]=0
    alpha=pic[...,3:4].astype(float)/255
    under[...,:3]=(pic[...,:3]*alpha+under[...,:3]*(1-alpha)).astype(np.uint8)
    under[...,3]=np.maximum(under[...,3],pic[...,3])
    owned=[i for i,p in enumerate(it.prims) if getattr(p,"stock_bottle",False)]
    mask=np.isin(cv.pid,owned) if owned else np.zeros(cv.pid.shape,dtype=bool)
    # A one-pixel ink contour belongs to the bottle, never an adjacent shelf.
    outline=np.zeros_like(mask)
    for dy,dx in [(0,1),(0,-1),(1,0),(-1,0)]:
        shifted=np.roll(mask,(dy,dx),(0,1))
        outline |= shifted & (cv.pid<0) & (native[...,3]>128)
    under[mask|outline]=native[mask|outline]
    cv.rgba=under


def rounded(x, z, w, d, y, h, mat, radius=.2):
    r = min(radius, w/2-.01, d/2-.01)
    out = [box(x-w/2+r,y,z-d/2,x+w/2-r,y+h,z+d/2,mat),
           box(x-w/2,y,z-d/2+r,x+w/2,y+h,z+d/2-r,mat)]
    for a in (-1,1):
        for b in (-1,1): out.append(cyl(x+a*(w/2-r),y,z+b*(d/2-r),r,h,mat))
    return out


def counter_segment(x,z,w,d,prestige=False,soft=False):
    # A shaped worktop, recessed plinth, fluted timber and two steady neon strips.
    radius=.48 if soft else .22
    p = rounded(x,z,w-.12,d-.12,.04,.1,M["dark"],radius)
    p += rounded(x,z,w-.08,d-.09,.14,.82,M["wood_red"] if prestige else M["wood"],radius)
    for xx in range(int(w/.18)):
        q=x-w/2+.16+xx*.18
        p.append(box(q,.22,z+d/2-.035,q+.025,.88,z+d/2-.01,M["plum"]))
    p += rounded(x,z,w,d,.95,.055,NEON,radius)
    p += rounded(x,z,w-.01,d-.01,.88,.025,NEON,radius)
    p += rounded(x,z,w+.04,d+.04,1.01,.1,M["cream"] if prestige else STONE,radius)
    p += rounded(x,z,w-.1,d-.05,.1,.025,M["gold"])
    p.append(rod((x-w/2+.16,.24,z+d/2+.07),(x+w/2-.16,.24,z+d/2+.07),.026,M["gold"]))
    return p


def make(kind):
    base = kind.split("_fill_")[0]
    if base in COUNTERS:
        sizes = {"bar_module":(1.5,1),"bar_round":(3.2,1.2),"bar_l":(3.4,2.4),"bar_luxe":(3.6,1.2)}
        w,d=sizes[base]
        prestige=base=="bar_luxe"
        if base == "bar_l":
            p=tag("front",*counter_segment(0,d/2-.45,w,.9))
            p+=tag("wing_a",*counter_segment(-w/2+.45,-.45,.9,d-.9))
            topz=d/2-.45
        else:
            p=counter_segment(0,0,w,d,prestige,base=="bar_round")
            topz=0
        # Display bottles on the tray are props; serving inventory lives on the shelves.
        for x in (-.28,.05):
            p += [rod((x,1.11,topz),(x,1.48,topz),.025,M["gold"]),
                  rod((x,1.48,topz),(x,1.48,topz+.12),.025,M["gold"]),
                  cyl(x,1.45,topz+.13,.04,.07,M["wood_red"])]
        p += [box(.45,1.115,topz-.16,.88,1.12,topz+.14,M["gold"]),
              box(.49,1.12,topz-.13,.84,1.13,topz+.1,M["dark"]),
              box(w/2-.5,1.11,topz-.18,w/2-.2,1.21,topz+.08,M["cream"])]
        for x in (-w/2+.22,-w/2+.42): p.append(cyl(x,1.11,topz,.04,.12,M["glass"]))
        if base != "bar_module":
            for i,x in enumerate(np.linspace(-w/2+.55,-.5,4)):
                p += bottle(x,1.11,topz-.15,M[["bottle_g","bottle_a","bottle_p","bottle_r"][i]],.28,.055)
                p.append(cyl(x,1.18,topz-.15,.057,.08,M["cream"]))
        else:
            p += bottle(-.12,1.11,topz,M["bottle_p"],.32,.07)
        p+=table_lamp(w/2-.25,1.11,topz-.02)
        p+=plant(-w/2+.2,1.11,topz-.22)
        if base=="bar_l":
            for prim in p:
                if not getattr(prim,"part",None): prim.part="front"
        def details(cv,T):
            if prestige:
                pts=[T((x,y,d/2+.015)) for x,y in heart_points(0,.55,.022)]
                for a,b in zip(pts,pts[1:]+pts[:1]): stroke(cv,a,b,(255,128,183,255),bias=.15)
                # Two broad veins across the marble; fixed pixels, no shimmer.
                for x in (-1.25,.7): stroke(cv,T((x,1.116,-d/2+.15)),T((x+.4,1.116,d/2-.15)),(208,191,190,255),bias=.07)
        lights=[dict(p=(x,.98,d/2),color="ff62ad",radius=1.3,power=.3) for x in (-w/3,0,w/3)]
        return Item(p,(w,d),decals=details,lights=lights)
    if base in SHELVES:
        w,d,cols,rows=SHELVES[base]
        n=int(kind.split("_fill_")[1]) if "_fill_" in kind else cols*rows
        tall=2.1 if base=="bottles_small" else (2.2 if base=="backbar" else 2.7)
        # Leave the lower stemware rail separate from the bottle slots.
        bottom=.18 if base=="bottles_small" else .98
        step=(tall-.28-bottom)/rows
        p=[box(-w/2+.03,.06,-d/2,w/2-.03,bottom,-d/2+.43,M["wood"],pattern=panels([-w/2,0,w/2],.14,bottom-.08)),
           box(-w/2,.06,-d/2,w/2,.12,d/2,M["gold"]),
           box(-w/2,bottom,-d/2,w/2,tall,-d/2+.06,M["plum"])]
        for x in (-w/2,w/2-.09): p.append(box(x,bottom,-d/2,x+.09,tall,d/2,M["wood_red"]))
        for row in range(rows+1):
            y=bottom+row*step
            p += [box(-w/2,y-.035,-d/2,w/2,y+.025,d/2,M["wood_top"]),
                  box(-w/2+.1,y+.025,d/2-.05,w/2-.1,y+.045,d/2-.03,M["gold"])]
        p.append(box(-w/2,tall-.12,-d/2,w/2,tall,d/2,M["wood_top"]))
        if base not in ("bottles_arch","backbar"):
            for x in ([0] if base=="bottles_small" else [-w/3,w/3]): p+=plant(x,tall,0)
        if base in ("bottles_arch","bottles_luxe"):
            p.append(box(-w/2,tall-.1,d/2-.035,w/2,tall-.065,d/2-.01,NEON))
            for x in (-w/2+.04,w/2-.04): p.append(rod((x,bottom,d/2+.008),(x,tall-.06,d/2+.008),.016,NEON))
        if base=="bottles_arch":
            # A true round arch with a fine light on its rim, not a glowing roof.
            p.append(ell(0,tall-.08,0,w/2,.65,d/2,M["wood_red"],ylim=(0,1)))
            pts=[(math.cos(t)*w/2,tall-.08+math.sin(t)*.65,d/2+.012) for t in np.linspace(0,math.pi,26)]
            for a,b in zip(pts,pts[1:]): p.append(rod(a,b,.017,NEON))
        if base=="backbar":
            for x in (-w/4,w/4):
                p.append(ell(x,tall-.06,0,w/4,.42,d/2,M["wood_red"],ylim=(0,1)))
                pts=[(x+math.cos(t)*w/4,tall-.06+math.sin(t)*.42,d/2+.012) for t in np.linspace(0,math.pi,18)]
                for a,b in zip(pts,pts[1:]): p.append(rod(a,b,.017,M["neon_red"]))
        # A bottle vanishes as it empties. New stock fills bottom shelf to top, one slot at a time.
        for i in range(n):
            row,col=divmod(i,cols)
            x=-w/2+.18+(w-.36)*col/max(1,cols-1)
            y=bottom+row*step+.03
            h=min(.30,step-.09)
            p += inventory(*bottle(x,y,.04,BOTTLES[(col//3+row)%3],h,.055))
            p += inventory(cyl(x,y+h*.26,.04,.057,h*.16,LABEL))
        lights=[dict(p=(x,1.8,.18),color="ff4d57" if base=="backbar" else "ff62ad",radius=1.3,power=.3) for x in (-w/3,w/3)]
        return Item(p,(w,d),lights=lights if base in ("bottles_arch","bottles_luxe","backbar") else [])
    if base=="bottle_crate":
        if kind.endswith("_fill_0"):
            p=[box(-.34,.02,-.3,.34,.055,.3,M["cardboard"]),
               box(-.34,.055,-.3,-.31,.14,.3,M["cardboard"]),box(.31,.055,-.3,.34,.14,.3,M["cardboard"]),
               box(-.31,.055,-.3,.31,.14,-.27,M["cardboard"]),box(-.31,.055,.27,.31,.14,.3,M["cardboard"])]
            return Item(p,(.8,.8))
        p=rounded(0,0,.72,.65,.03,.48,M["cardboard"],.03)
        p += [box(-.075,.51,-.33,.075,.53,.33,M["cream"]),box(-.075,.1,.325,.075,.53,.34,M["cream"]),
              box(-.29,.15,.343,-.14,.3,.351,M["paper"])]
        return Item(p,(.8,.8))
    return None


def kinds():
    out=COUNTERS+["bottle_crate","bottle_crate_fill_0"]
    for kind,(_,_,cols,rows) in SHELVES.items():
        out.append(kind)
        out.extend(f"{kind}_fill_{i}" for i in range(cols*rows+1))
    return out
