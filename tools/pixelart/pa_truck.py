"""Constructed two-axle delivery truck, painted at the native 32 x 16 grid.

The body is assembled from continuous panels rather than nested plain boxes:
sculpted cab and wheel cutouts, rubber seals, locking gear, reflective rails,
recessed cargo bay and a ribbed hydraulic tail lift. No resampling is used.
"""
import math
import numpy as np
from pa_iso import Mat, box, cyl, rod, render, finish, rot_x, rot_y
from pa_truck_patterns import body_side, roof_pattern, glass_pattern

CAB = Mat(tones=['51404b','786471','a795a2','c8b8bf','e3d2d0','ffead9'])
BODY = Mat(tones=['514450','776876','988995','b4a4af','cfbbc1','ead3cb'])
ROOF = Mat(tones=['564652','85707e','b39aa6','c8adb6','e1c4c7','ffe2d4'])
EDGE = Mat(tones=['39323d','645865','8a7f8d','afa2ae','d5c5cb','f7e1d4'])
CHROME = Mat(tones=['282432','514958','746b7b','a99ca8','d2c8ca','f3e8dc'])
SEAL = Mat(tones=['181720','252330','34313e','484450','68616b','92818a'])
RUBBER = Mat(tones=['14131c','25212c','332e3b','46404b','625a65','8e808b'])
CHASSIS = Mat(tones=['171620','2c2732','443946','625463','847582','b5a0a7'])
STEEL = Mat(tones=['33303b','514b5c','716779','958798','b9a6b5','dfc7cb'])
GLASS = Mat(tones=['121b29','202c40','2d3d52','435870','637c94','9ab0c0'])
INNER = Mat(tones=['23202c','38303c','51414b','6b5660','8c7379','baa09e'])
WOOD = Mat(tones=['28222b','49333a','66474a','87645b','ab8370','d4ae8c'])
WHITE = Mat(tones=['71646a','a49499','cbb9bc','ead8d2','fff0d9','fff6e6'],line=False)
RED = Mat(tones=['401f32','752433','af313d','e4473c','ff7250','ffc17e'],line=False)
AMBER = Mat(tones=['743129','bb4921','ef751b','ff9b25','ffd25d','fff0ae'],emissive=True,line=False)
AMBER_OFF = Mat(tones=['462a2c','70402e','a3572c','c98440','e7ad5d','ffcf85'],line=False)
BRAKE = Mat(tones=['51192d','a01e32','e23434','ff5d43','ff9660','ffd1a0'],emissive=True,bias=1,line=False)
LAMP = Mat(tones=['a57045','dd9b55','f3c17d','ffe8af','fff5d6','fffbea'],emissive=True,bias=1,line=False)


def profile(points, z0, z1, material, group=None, pattern=None):
    """A continuous cab/window profile extruded in z; thin grouped scan bands.

    Shared grouping suppresses artificial outlines between the construction
    bands, leaving only the silhouette and the deliberate panel seams.
    """
    out = []
    group = object() if group is None else group
    low,high=min(p[1] for p in points),max(p[1] for p in points)
    count=max(1,math.ceil((high-low)*40))
    for index in range(count):
        y0=low+(high-low)*index/count
        y1=low+(high-low)*(index+1)/count
        ym=(y0+y1)/2
        crossings=[]
        for a,b in zip(points,points[1:]+points[:1]):
            if min(a[1],b[1]) <= ym < max(a[1],b[1]):
                crossings.append(a[0]+(b[0]-a[0])*(ym-a[1])/(b[1]-a[1]))
        if len(crossings)>=2:
            out.append(box(min(crossings),y0,z0,max(crossings),y1,z1,material,group=group,pattern=pattern))
    return out


def disk(x,y,z,r,depth,material):
    p=cyl(0,0,0,r,depth,material).transformed(rot_x(90))
    p.T += [x,y,z]
    return p


def road_wheel(x,z):
    y=.55
    p=[disk(x,y,z,.535,.30,RUBBER),disk(x,y,z+.30,.438,.012,SEAL),
       disk(x,y,z+.314,.315,.018,CHROME),disk(x,y,z+.335,.24,.022,CHASSIS),
       disk(x,y,z+.36,.16,.035,CHROME),disk(x,y,z+.398,.075,.014,STEEL)]
    # Valve holes and bolts read as separate dark/light pixel clusters.
    for i in range(5):
        a=2*math.pi*i/5
        p.append(disk(x+math.cos(a)*.21,y+math.sin(a)*.21,z+.358,.039,.015,SEAL))
        p.append(disk(x+math.cos(a)*.12,y+math.sin(a)*.12,z+.402,.025,.018,WHITE))
    # Quiet tread shoulders; retain the broad dark rubber silhouette.
    for a in np.linspace(.3,math.pi-.3,5):
        xx=x+math.cos(a)*.5; yy=y+math.sin(a)*.5
        p.append(rod((xx,yy,z+.08),(xx,yy,z+.28),.015,CHASSIS))
    # One physical wheel: no artificial outline around every concentric disc.
    group=object()
    for part in p: part.group=group
    return p


def fender(x,z,r=.635):
    p=[]
    for i in range(20):
        a=math.pi*i/20; b=math.pi*(i+1)/20
        p.append(rod((x+r*math.cos(a),.55+r*math.sin(a),z),
                     (x+r*math.cos(b),.55+r*math.sin(b),z),.062,SEAL))
        p.append(rod((x+(r+.055)*math.cos(a),.55+(r+.055)*math.sin(a),z-.035),
                     (x+(r+.055)*math.cos(b),.55+(r+.055)*math.sin(b),z-.035),.024,EDGE))
    return p


def marker(x,y,z,blink):
    mat=AMBER if blink else AMBER_OFF
    return [box(x-.145,y-.12,z-.105,x+.145,y+.11,z+.105,SEAL),
            box(x-.125,y-.089,z-.118,x+.125,y+.094,z+.125,mat),
            box(x-.047,y-.035,z+.128,x+.047,y+.049,z+.132,LAMP if blink else mat)]


def cab(blink):
    p=[]
    group=object()
    # Wheel cutout is real empty space, not a black disc painted on a box.
    for x0 in np.arange(-3.76,-1.68,.045):
        x1=min(x0+.045,-1.68); xm=(x0+x1)/2
        top=min(2.57,1.53+(xm+3.76)*2.04)
        bottom=.68
        dx=xm+2.77
        if abs(dx)<.66: bottom=max(bottom,.55+math.sqrt(.66*.66-dx*dx))
        if top>bottom: p.append(box(x0,bottom,-1.07,x1,top,1.07,CAB,group=group))
    # Roof cap, rain gutter, rear cab seam and separate door skin.
    p += [box(-3.21,2.565,-1.115,-1.65,2.635,1.115,CAB),
          box(-3.2,2.54,1.09,-1.67,2.58,1.13,EDGE),
          box(-1.78,.8,1.072,-1.75,2.52,1.09,CHASSIS)]
    door=[(-3.39,1.19),(-1.91,.79),(-1.83,.85),(-1.83,2.47),(-3.05,2.47),(-3.42,1.76)]
    p += profile(door,1.073,1.082,CAB)
    # Thick rubber window seal followed by an inset blue trapezoid.
    p += profile([(-3.43,1.67),(-1.87,1.67),(-1.87,2.48),(-3.06,2.48)],1.085,1.113,SEAL)
    p += profile([(-3.31,1.77),(-1.96,1.77),(-1.96,2.38),(-3.035,2.38)],1.115,1.13,GLASS,pattern=glass_pattern)
    p += [box(-2.03,1.77,1.134,-2.005,2.39,1.14,CHROME),
          box(-2.15,1.435,1.10,-1.94,1.545,1.15,SEAL),
          box(-2.10,1.49,1.153,-1.98,1.52,1.17,STEEL),
          box(-1.98,.58,.8,-1.70,.74,1.23,CHASSIS),
          box(-2.05,.68,1.08,-1.73,.73,1.25,CHROME)]
    # Raked front windscreen and its dark gasket (also visible in other views).
    for y0 in np.arange(1.74,2.42,.035):
        xx=-3.76+(y0-1.53)/2.04-.025
        p.append(box(xx-.026,y0,-.97,xx+.02,y0+.035,.97,SEAL))
        p.append(box(xx-.029,y0+.012,-.86,xx-.027,y0+.033,.86,GLASS))
    # Mirror on two arms; bright outer rim and inset glass.
    p += [rod((-3.28,1.89,1.10),(-3.35,1.91,1.48),.028,CHASSIS),
          rod((-3.19,2.27,1.10),(-3.27,2.29,1.48),.027,CHASSIS),
          box(-3.43,1.83,1.43,-3.22,2.36,1.53,SEAL),
          box(-3.41,1.87,1.535,-3.25,2.32,1.55,GLASS),
          box(-3.425,1.86,1.552,-3.399,2.32,1.56,CHROME)]
    # Front bumper, grille, lower step and number plate.
    p += [box(-3.88,.51,-1.13,-3.65,.75,1.13,SEAL),
          box(-3.9,.69,-1.15,-3.76,.78,1.15,CHROME),
          box(-3.789,1.05,-.63,-3.766,1.42,.63,SEAL),
          box(-3.902,.53,-.31,-3.89,.66,.31,WHITE)]
    for y in [1.10,1.20,1.30]: p.append(box(-3.80,y,-.6,-3.79,y+.025,.6,CHROME))
    for sign in [-1,1]:
        z=sign*.83
        p += [box(-3.82,.94,z-.16,-3.77,1.32,z+.16,CHASSIS),
              box(-3.836,1.10,z-.125,-3.823,1.29,z+.125,LAMP),
              box(-3.837,.96,z-.12,-3.824,1.07,z+.12,AMBER if blink else AMBER_OFF)]
        p += marker(-2.72,2.67,sign*.96,blink)
    # Side indicator remains visible from the rear-quarter game camera.
    p += [box(-3.64,1.02,1.08,-3.48,1.28,1.12,AMBER if blink else AMBER_OFF),
          box(-3.63,.79,1.08,-3.47,.96,1.125,WHITE)]
    p += fender(-2.77,1.12)
    return p


def door_leaf(sign,opening):
    lo,hi=(-1.08,-.02) if sign<0 else (.02,1.08)
    group=object()
    p=[box(3.51,1.045,lo,3.625,3.18,hi,EDGE,group=group),
       box(3.627,1.14,lo+.075,3.65,3.075,hi-.075,BODY,group=group),
       box(3.494,1.14,lo+.07,3.508,3.075,hi-.07,INNER,group=group)]
    # Framing and top/bottom rails, lock bar, brackets and lever.
    for y in [1.065,3.145]: p.append(box(3.65,y,lo,3.683,y+.036,hi,CHROME))
    z=sign*.42
    p.append(rod((3.705,1.14,z),(3.705,3.09,z),.033,CHROME))
    for y in [1.2,1.68,2.6,3.0]: p.append(box(3.697,y,z-.074,3.739,y+.057,z+.074,STEEL))
    p += [box(3.744,1.52,z-.13,3.77,1.60,z+.13,CHROME),
          box(3.771,1.535,z-.04,3.794,1.57,z+.16,SEAL)]
    angle=0 if not opening else (60 if opening==1 else 155)
    if angle: p=[q.transformed(rot_y(-sign*angle),pivot=(3.56,0,sign*1.105)) for q in p]
    return p


def truck(opening,blink,load,carton):
    p=[box(-3.67,.48,-.88,3.5,.80,.88,CHASSIS)]
    p += cab(blink)
    # Chassis with a tank, retaining straps, protective rails and mudflaps.
    p += [box(-1.5,.35,.73,.49,.81,1.06,SEAL),box(-1.38,.42,1.07,.42,.74,1.115,STEEL),
          box(-1.38,.69,1.12,.42,.735,1.14,CHROME),box(-1.38,.40,1.12,.42,.435,1.14,CHROME),
          box(.61,.49,1.02,1.1,.86,1.19,CHASSIS),box(.68,.59,1.195,1.00,.8,1.21,STEEL)]
    for x in [-1.1,.13]: p.append(box(x,.37,1.118,x+.1,.77,1.16,CHASSIS))
    for x in [-2.02,2.93]: p.append(box(x,.13,1.06,x+.13,.80,1.20,RUBBER))
    for x in [-2.77,2.19]:
        for z in [-1.24,.93]: p += road_wheel(x,z)
    p += fender(2.19,1.13)
    # A box with visible panel thickness, separate interior and top cap.
    p += [box(-1.55,.94,-1.23,3.49,1.085,1.23,EDGE),
          box(-1.55,1.085,1.105,3.48,3.23,1.22,BODY,pattern=body_side),
          box(-1.55,1.085,-1.22,3.48,3.23,-1.105,BODY),
          box(-1.55,1.085,-1.10,-1.42,3.23,1.10,INNER),
          box(-1.49,1.08,-1.099,3.43,3.17,-1.06,INNER),
          box(-1.49,1.085,-1.09,3.47,1.11,1.09,WOOD),
          box(-1.57,3.23,-1.25,3.53,3.335,1.25,ROOF,pattern=roof_pattern)]
    # Recessed vertical liners and restrained floorboards inside the cargo bay.
    for x in np.arange(-1.35,3.43,.62): p.append(box(x,1.14,-1.058,x+.04,3.14,-1.02,STEEL))
    for z in np.arange(-1.0,1.09,.24): p.append(box(-1.4,1.112,z,3.45,1.119,z+.014,INNER))
    for sign in [-1,1]:
        z=sign*1.22
        p += [box(-1.57,1.02,z-.025,3.53,1.105,z+.025,CHROME),
              box(-1.57,3.17,z-.025,3.54,3.23,z+.025,CHROME),
              box(-1.52,3.31,z-.026,3.49,3.345,z+.026,WHITE)]
        for x in [-1.52,3.45]:
            p.append(box(x-.035,1.11,z-.033,x+.035,3.21,z+.033,EDGE))
            for y in [1.26,1.83,2.39,3.05]: p.append(box(x-.016,y,z+.035,x+.017,y+.026,z+.045,WHITE))
            p += marker(x,3.28,sign*1.20,blink)
        # Safety tape sits on the lower metal rail, like the reference sheet.
        for i,x in enumerate(np.arange(-1.5,3.5,.32)):
            p.append(box(x,.955,z-.027,min(x+.22,3.5),1.005,z+.027,RED if i%2==0 else WHITE))
        for x in [-1.43,3.37]: p += marker(x,1.21,z,blink)
    # Black rear seal makes the door panels and the open interior legible.
    p += [box(3.475,1.06,-1.16,3.505,3.21,1.16,INNER)] if not opening else []
    for z in [-1.135,1.135]:
        p.append(box(3.46,1.055,z-.045,3.585,3.24,z+.045,SEAL))
        p.append(box(3.59,1.065,z-.021,3.623,3.21,z+.021,CHROME))
    p += [box(3.49,3.18,-1.15,3.605,3.27,1.15,CHROME),
          box(3.49,1.02,-1.15,3.64,1.08,1.15,CHROME)]
    for sign in [-1,1]:
        p += door_leaf(sign,opening)
        for y in [1.27,2.02,2.89]:
            z=sign*1.107
            p += [box(3.57,y,z-.064,3.70,y+.12,z+.064,CHROME),
                  rod((3.68,y-.027,z),(3.68,y+.15,z),.038,STEEL)]
    # Underrun bar, distinct taillamp clusters, reverse lamps and plate.
    p += [box(3.48,.34,-1.22,3.68,.58,1.22,CHASSIS),
          box(3.686,.365,-.32,3.705,.49,.32,SEAL),box(3.707,.385,-.26,3.716,.475,.26,WHITE)]
    for i,z in enumerate(np.arange(-1.19,1.20,.24)):
        p.append(box(3.69,.52,z,3.71,.58,min(z+.19,1.20),RED if i%2==0 else WHITE))
    for sign in [-1,1]:
        z=sign*.96
        p += [box(3.50,.64,z-.20,3.65,.86,z+.20,SEAL),
              box(3.653,.68,z-.15,3.67,.82,z+.015,BRAKE),
              box(3.673,.716,z-.105,3.68,.784,z-.025,LAMP),
              box(3.653,.68,z+.04,3.67,.82,z+.13,AMBER if blink else AMBER_OFF),
              box(3.27,.70,sign*1.20-.035,3.43,.86,sign*1.20+.035,BRAKE)]
    if opening==2:
        # Hydraulic arms actually connect the lowered, ribbed lift to the frame.
        for z in [-.76,.76]:
            p += [rod((3.5,.8,z),(4.48,.23,z),.065,CHASSIS),rod((3.85,.59,z),(4.52,.25,z),.038,CHROME)]
        p += [box(3.58,.215,-1.14,5.0,.31,1.14,CHASSIS),box(3.63,.31,-1.09,4.96,.355,1.09,STEEL)]
        for x in np.arange(3.65,4.95,.14): p.append(box(x,.358,-1.04,x+.028,.371,1.04,CHROME))
        for z in [-1.105,1.075]: p.append(box(3.59,.32,z,5.0,.395,z+.035,EDGE))
        p.append(box(4.94,.30,-1.14,5.0,.39,1.14,CHROME))
    elif not opening:
        p.append(box(3.52,.59,-1.07,3.58,.63,1.07,CHROME))
    if opening:
        # Boxes shrink with the remaining load; labels and tape face the doors.
        slots=[(3.03,-.48,.85,.72,.79,1.12),(3.10,.44,.55,.68,.73,1.12),(3.03,-.48,.56,.69,.76,1.97)]
        for x,z,h,w,d,y in slots[:load]:
            p += carton(w,h,d,(x,y,z))
            # The camera sees the rear (+x) face: tape and labels belong here
            # as well as on the side faces of the carried parcel sprites.
            front=x+w/2+.012
            p += [box(front,y+.015,z-.044,front+.013,y+h+.01,z+.044,WHITE),
                  box(front+.015,y+h*.24,z+.12,front+.026,y+h*.56,z+.30,WHITE)]
            for zz in [z+.15,z+.20,z+.245]:
                p.append(box(front+.028,y+h*.30,zz,front+.035,y+h*.48,zz+.014,CHASSIS))
    return finish(render(p,shadow=[(-3.85,-1.36,3.74,1.40)],shadow_alpha=90))


LIGHTS=[
    {'x':-2.72,'y':2.67,'z':.96,'color':'ff861b','blink':True,'power':.30},
    {'x':-1.52,'y':3.28,'z':1.20,'color':'ff861b','blink':True,'power':.36},
    {'x':3.45,'y':3.28,'z':1.20,'color':'ff861b','blink':True,'power':.36},
    {'x':3.45,'y':3.28,'z':-1.20,'color':'ff861b','blink':True,'power':.30},
    {'x':-3.56,'y':1.14,'z':1.14,'color':'ffd898','blink':False,'power':.30},
    {'x':-1.43,'y':1.21,'z':1.25,'color':'ff9b29','blink':True,'power':.35},
    {'x':3.37,'y':1.21,'z':1.25,'color':'ff9b29','blink':True,'power':.35},
    {'x':3.68,'y':.74,'z':.91,'color':'ff4937','blink':False,'power':.4},
    {'x':3.68,'y':.74,'z':-1.01,'color':'ff4937','blink':False,'power':.35},
]
