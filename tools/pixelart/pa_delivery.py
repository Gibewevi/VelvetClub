"""Delivery props at native pixel resolution, using the game's own painter.

Compact yellow van, taped kraft cartons and a yellow hand truck, using the
supplied artwork's shapes and palette at the existing game scale.
"""
from pa_core import save, write_json
from pa_iso import Mat, box, cyl, render, finish, rot_x
import math
import numpy as np

IVORY = Mat(tones=['37303e','69606e','a398aa','bdb2c1','d7c9ce','f7e5d7'])
TRIM = Mat('797a89')
DARK = Mat('282432')
TYRE = Mat('292631')
GLASS = Mat(tones=['141d30','24334b','374d66','586b87','8fa3b0','c3d0d5'])
KRAFT = Mat(tones=['3d2530','704337','996140','bf894e','dbac68','f3cb8b'])
TAPE = Mat('ecd5a4')
YELLOW = Mat('e9ac24')
WHITE = Mat('e9ddd3')
RED = Mat('ea3843',emissive=True)
ORANGE = Mat('ffaf24',emissive=True)


def carton(w=0.6,h=0.5,d=0.5,at=(0,0,0),opened=False):
    x,y,z = at
    p=[box(x-w/2,y,z-d/2,x+w/2,y+h,z+d/2,KRAFT)]
    for zz in [-d/2,d/2]:
        p.append(box(x-.055,y+.02,z+zz-.008,x+.055,y+h+.008,z+zz+.008,TAPE))
    p += [box(x-.055,y+h,z-d/2,x+.055,y+h+.012,z+d/2,TAPE),
          box(x+w*.1,y+h*.22,z+d/2,x+w*.38,y+h*.53,z+d/2+.012,WHITE)]
    for k in range(4):
        p.append(box(x+w*.13+k*.03,y+h*.26,z+d/2+.013,x+w*.14+k*.03,y+h*.44,z+d/2+.018,DARK))
    if opened:
        p += [box(x-w*.7,y+h,z-d*.48,x,y+h+.04,z+d*.48,KRAFT),
              box(x,y+h+.05,z-d*.48,x+w*.7,y+h+.09,z+d*.48,KRAFT)]
    return p


def wheel(x,y,z,r=.42):
    # Transform explicitly: cylinder's axis points across the vehicle.
    a=cyl(0,0,0,r,.24,TYRE).transformed(rot_x(90)); a.T += [x,y,z]
    b=cyl(0,0,0,r*.57,.255,TRIM).transformed(rot_x(90)); b.T += [x,y,z]
    c=cyl(0,0,0,r*.22,.27,DARK).transformed(rot_x(90)); c.T += [x,y,z]
    return [a,b,c]


def truck(opening,blink,load=3,pitch=0):
    from pa_truck import truck as constructed_truck
    return constructed_truck(opening,blink,load,carton,pitch=pitch)


def export():
    from pa_truck import LIGHTS, FOOTPRINTS
    manifest={"_truck_lights":LIGHTS}
    def put(name,prims,opening=0,pitch=0.0):
        cv=prims if hasattr(prims,'rgba') else finish(render(prims))
        path=f'delivery/{name}.png'; save(cv.rgba,path)
        manifest[name]={'file':path,'ox':int(cv.ox),'oy':int(cv.oy)}
        if name.startswith('truck_'):
            manifest[name]['footprint']=FOOTPRINTS[opening]
            manifest[name]['pitch']=pitch
    for opening in range(3):
        cv=truck(opening,False)
        for blink in range(2): put(f'truck_{opening}_{blink}',cv,opening=opening)
    for opening in [1,2]:
        for load in range(4):
            cv=truck(opening,False,load)
            for blink in range(2): put(f'truck_{opening}_{blink}_load{load}',cv,opening=opening)
    for phase,sign in [('brake',1),('launch',-1)]:
        for level in range(1,4):
            angle=sign*level
            put(f'truck_{phase}_{level}',truck(0,False,pitch=angle),pitch=math.radians(angle))
    for size,(w,h,d) in enumerate([(.48,.4,.4),(.85,.8,.65),(1.65,1.05,.8)]):
        for opened in [False,True]: put(f'box_{size}_{int(opened)}',carton(w,h,d,opened=opened))
        p=[box(-w/2-.08,.16,-d/2-.1,w/2+.08,.22,d/2+.1,YELLOW),
           box(-.4,.2,-d/2-.13,-.34,1.4,-d/2-.07,DARK),box(.34,.2,-d/2-.13,.4,1.4,-d/2-.07,DARK),
           box(-.4,1.34,-d/2-.13,.4,1.4,-d/2-.07,DARK)]
        for x in [-.43,.43]: p+=wheel(x,.17,-d/2-.16,.17)
        put(f'cart_{size}',p+carton(w,h,d,(0,.23,0)))
    p=[box(-.24,0,-.24,.24,.05,.24,YELLOW)]
    for i in range(10):
        r=.18-i*.015
        p.append(box(-r,.05+i*.045,-r,r,.095+i*.045,r,WHITE if i in [3,4,7] else YELLOW))
    put('cone',p)
    write_json('delivery.json',manifest)
    return manifest

if __name__=='__main__': export()
