"""Compact yellow delivery van on the native pixel grid.

Broad enamel colours, rounded shoulders and quiet wheels replace the large
box truck. Historical frame names preserve compatibility with deliveries.
"""
import math
import numpy as np
from pa_iso import Mat, Prim, box, cyl, ell, rod, render, finish, rot_x, rot_y, rot_z
from pa_truck_patterns import body_side, roof_pattern, glass_pattern

YELLOW = Mat(tones=['74402e','ac6624','d68b20','efa920','ffc539','ffe074'])
ROOF = Mat(tones=['875224','b87621','e5a129','f4b52d','ffd247','ffe77c'])
EDGE = Mat(tones=['815124','b57824','dc9825','f3b732','ffcf51','ffe685'],line=False)
SEAL = Mat(tones=['24202e','302a3b','3b3546','4b4455','645b6b','827488'])
RUBBER = Mat(tones=['211d2b','2d2937','393343','463e51','5a5063','776b80'])
TRIM = Mat(tones=['28232f','36313f','474051','5a5364','756c7d','918394'])
RIM = Mat(tones=['403447','655869','837687','a3929e','bcadb3','d7c8c8'])
GLASS = Mat(tones=['172336','26344b','344660','4a5c79','677b99','8e9cb0'])
INNER = Mat(tones=['25202d','39323f','4d4350','685762','84707a','a68d94'])
DOOR_IN = Mat(tones=['724024','965721','ba7922','d99825','ecb541','ffd16c'])
RED = Mat(tones=['421c30','6a2330','902b35','ac3038','c44842','e67b53'],line=False)
WHITE = Mat(tones=['867d83','a99ba0','c6b5ae','ded0bc','f7e4c5','fff0d9'],line=False)
AMBER = Mat(tones=['9c571d','b77521','d79328','edb348','ffd86e','ffe899'],line=False)
LIGHT = Mat(tones=['a26b31','c99b55','ecc878','f9dd9c','ffedbd','fff4d3'],flat=3,line=False)
TAIL = Mat(tones=['682b31','983439','c44840','e56b49','f98a5d','ffa16a'],flat=3,line=False)

SUSPENSION_PIVOT = np.array([0.0, .46, 0.0])
# All closed suspension frames share a canvas and anchor. These corners cover
# the body at both ±3 degree limits without rescaling a single painted pixel.
CLOSED_BOUNDS = [(x,y,z) for x in [-3.08,3.08] for y in [0,2.92] for z in [-1.40,1.49]]


def rounded_block(lo, hi, radii, material, group=None, pattern=None):
    """Elliptical corners and continuous edges, sampled directly at 1 pixel.

    The union of three cores, twelve edge cylinders and eight corner ellipsoids
    has an actual curved silhouette. Grouping prevents outlines between parts.
    """
    a=np.asarray(lo,dtype=float); b=np.asarray(hi,dtype=float)
    r=np.minimum(np.asarray(radii,dtype=float),(b-a)*.49)
    c=a+r; d=b-r
    group=object() if group is None else group
    kw={'group':group,'pattern':pattern}
    out=[box(a[0],c[1],c[2],b[0],d[1],d[2],material,**kw),
         box(c[0],a[1],c[2],d[0],b[1],d[2],material,**kw),
         box(c[0],c[1],a[2],d[0],d[1],b[2],material,**kw)]
    for axis in range(3):
        other=[i for i in range(3) if i != axis]
        for first in [c[other[0]],d[other[0]]]:
            for second in [c[other[1]],d[other[1]]]:
                t=c.copy(); t[other[0]]=first; t[other[1]]=second
                matrix=np.zeros((3,3))
                matrix[axis,1]=d[axis]-c[axis]
                matrix[other[0],0]=r[other[0]]
                matrix[other[1],2]=r[other[1]]
                out.append(Prim('cyl',matrix,t,material,**kw))
    for x in [c[0],d[0]]:
        for y in [c[1],d[1]]:
            for z in [c[2],d[2]]:
                out.append(ell(x,y,z,*r,material,**kw))
    return out


def pitch_body(prims, pitch):
    """Tilt sprung parts while keeping surface paint in the van's own frame.

    Pitch is in degrees. Positive z rotation lowers the nose at negative x.
    Marked wheel parts stay stationary, preserving the original draw order.
    """
    angle = max(-3.0, min(3.0, float(pitch)))
    if abs(angle) < 1e-8:
        return prims
    rotation = rot_z(angle)
    result = []
    for original in prims:
        if getattr(original, 'suspension_static', False):
            result.append(original)
            continue
        part = original.transformed(rotation, pivot=SUSPENSION_PIVOT)
        if original.pattern is not None:
            pattern = original.pattern

            def anchored(local, normal, world, world_normal, callback=pattern):
                # Row vectors use R to invert the R @ column-vector transform.
                surface_world = (world - SUSPENSION_PIVOT) @ rotation + SUSPENSION_PIVOT
                surface_normal = world_normal @ rotation
                return callback(local, normal, surface_world, surface_normal)

            part.pattern = anchored
        result.append(part)
    return result

def profile(points,z0,z1,material,group=None,pattern=None):
    """Shaped sheet with all scan bands in one continuous painted surface."""
    out=[]
    group=object() if group is None else group
    low,high=min(p[1] for p in points),max(p[1] for p in points)
    count=max(1,math.ceil((high-low)*36))
    for index in range(count):
        y0=low+(high-low)*index/count; y1=low+(high-low)*(index+1)/count
        ym=(y0+y1)/2; crossings=[]
        for a,b in zip(points,points[1:]+points[:1]):
            if min(a[1],b[1]) <= ym < max(a[1],b[1]):
                crossings.append(a[0]+(b[0]-a[0])*(ym-a[1])/(b[1]-a[1]))
        if len(crossings)>=2:
            out.append(box(min(crossings),y0,z0,max(crossings),y1,z1,material,group=group,pattern=pattern))
    return out

def disk(x,y,z,r,depth,material,group):
    p=cyl(0,0,0,r,depth,material,group=group).transformed(rot_x(90))
    p.T += [x,y,z]
    return p

def wheel(x,z):
    group=object()
    # Three broad rings remain readable without checkerboard bolts or tread.
    return [disk(x,.48,z,.48,.24,RUBBER,group),
            disk(x,.48,z+.245,.335,.015,SEAL,group),
            disk(x,.48,z+.265,.28,.018,RIM,group),
            disk(x,.48,z+.29,.195,.016,TRIM,group),
            disk(x,.48,z+.309,.115,.018,RIM,group)]

def arch(x,z):
    p=[]; group=object()
    for i in range(16):
        a=math.pi*i/16; b=math.pi*(i+1)/16
        p += [rod((x+.56*math.cos(a),.48+.56*math.sin(a),z),
                  (x+.56*math.cos(b),.48+.56*math.sin(b),z),.066,SEAL,group=group),
              rod((x+.625*math.cos(a),.48+.625*math.sin(a),z-.018),
                  (x+.625*math.cos(b),.48+.625*math.sin(b),z-.018),.041,EDGE,group=group)]
    return p

def cab(group):
    p=[]
    # The nose narrows in plan as well as in profile, avoiding a squared-off
    # front. Its upper edge joins the single roof shared with the cargo body;
    # there is no second cab cap under the front of that roof.
    for x0 in np.arange(-2.78,-.83,.04):
        x1=min(x0+.04,-.83); xm=(x0+x1)/2
        if xm < -2.53: top=1.15+(xm+2.78)*1.15
        elif xm < -1.96: top=1.4375+(xm+2.53)*1.58
        elif xm < -1.80: top=2.338+(xm+1.96)*.36
        else: top=2.3956
        width=1.085-.18*max(0,(-2.44-xm)/.34)**2
        bottom=.50; dx=xm+1.90
        if abs(dx)<.57: bottom=max(bottom,.48+math.sqrt(.57**2-dx**2))
        if top>bottom:
            p.append(box(x0,bottom,-width,x1,top,width,YELLOW,group=group))
    p += [ell(-2.53,1.19,0,.27,.27,1.045,YELLOW,group=group),
          box(-.96,.64,1.089,-.934,2.34,1.101,DOOR_IN)]
    p += rounded_block((-1.32,1.065,1.103),(-1.09,1.19,1.15),(.035,.035,.018),SEAL)
    p += [box(-1.275,1.135,1.154,-1.135,1.158,1.16,TRIM)]
    p += rounded_block((-1.30,.49,1.01),(-.88,.64,1.17),(.05,.045,.045),TRIM)
    p += profile([(-2.44,1.43),(-2.40,1.34),(-1.15,1.34),(-1.07,1.42),
                  (-1.07,2.20),(-1.15,2.29),(-1.87,2.29)],1.090,1.110,SEAL)
    p += profile([(-2.32,1.44),(-2.29,1.41),(-1.21,1.41),(-1.17,1.45),
                  (-1.17,2.15),(-1.22,2.20),(-1.84,2.20)],1.113,1.127,GLASS,pattern=glass_pattern)
    p += [box(-1.28,1.45,1.13,-1.24,2.17,1.135,TRIM)]
    for y0 in np.arange(1.50,2.25,.032):
        xx=-2.53+(y0-1.4375)/1.58-.018
        p += [box(xx-.025,y0,-.98,xx+.015,y0+.032,.98,SEAL,group=group),
              box(xx-.031,y0+.008,-.88,xx-.027,y0+.029,.88,GLASS,group=group)]
    p += rounded_block((-2.88,.43,-1.075),(-2.64,.70,1.075),(.105,.105,.18),TRIM)
    p += [box(-2.792,.83,-.58,-2.78,1.02,.58,SEAL),
          box(-2.884,.50,-.29,-2.873,.62,.29,WHITE),
          box(-2.800,.88,-.48,-2.795,.915,.48,TRIM)]
    for sign in [-1,1]:
        z=sign*.84
        p += rounded_block((-2.795,.91,z-.145),(-2.750,1.145,z+.145),(.02,.055,.065),LIGHT)
        p += [box(-2.779,.77,z-.14,-2.751,.86,z+.14,AMBER)]
    p += [rod((-2.28,1.46,1.13),(-2.31,1.48,1.36),.040,SEAL)]
    p += rounded_block((-2.43,1.39,1.32),(-2.19,1.86,1.45),(.055,.08,.045),SEAL)
    p += [box(-2.39,1.49,1.457,-2.32,1.76,1.464,TRIM)]
    return p

def rear_doors(opening):
    out=[]
    angle=0 if opening==0 else (64 if opening==1 else 155)
    for sign in [-1,1]:
        lo,hi=(-1.055,-.018) if sign<0 else (.018,1.055)
        group=object()
        p=rounded_block((2.53,.58,lo),(2.635,2.355,hi),(.045,.12,.105),YELLOW,group=group)
        p += rounded_block((2.505,.70,lo+.085),(2.526,2.23,hi-.085),(.009,.085,.075),DOOR_IN,group=group)
        p += [
           box(2.627,.89,lo,2.637,1.055,hi,RED,group=group),
           box(2.64,.56,lo,2.655,.75,hi,TRIM,group=group)]
        for y in [.70,2.23]:
            p.append(box(2.491,y,lo+.08,2.504,y+.035,hi-.08,EDGE,group=group))
        p += [box(2.64,1.15,sign*.22-.05,2.67,1.28,sign*.22+.05,SEAL,group=group)]
        if angle: p=[q.transformed(rot_y(-sign*angle),pivot=(2.575,0,sign*1.079)) for q in p]
        out += p
        for y in [.86,1.99]:
            out += rounded_block((2.53,y,sign*1.075-.055),(2.67,y+.14,sign*1.075+.055),(.025,.025,.025),TRIM)
    return out

def truck(opening,blink,load,carton,pitch=0):
    if opening != 0 and abs(float(pitch)) > 1e-8:
        raise ValueError('Suspension poses require closed cargo doors')
    # Variants are pixel-identical: runtime owns the gentle amber pulse.
    group=object()
    p=[box(-2.63,.36,-.94,2.57,.58,.94,TRIM)]
    p += cab(group)
    for sign in [-1,1]:
        # Slightly barrel-shaped flanks tuck in at the sill and shoulder.
        # The material pattern paints across the construction bands as one
        # surface, so none of the small horizontal ledges can shimmer.
        for y0 in np.arange(.53,2.3956,.04):
            y1=min(y0+.04,2.3956); ym=(y0+y1)/2
            if ym < .75: width=1.045+.115*(ym-.53)/.22
            elif ym < 1.80: width=1.16
            else: width=1.16-.075*((ym-1.80)/.5956)**1.3
            z0,z1=sorted([sign*(width-.085),sign*width])
            spans=[(-.88,2.40)]
            if ym < 1.05:
                half=math.sqrt(max(0,.57**2-(ym-.48)**2))
                spans=[(-.88,1.74-half),(1.74+half,2.40)]
            for xa,xb in spans:
                if xb>xa: p.append(box(xa,y0,z0,xb,y1,z1,YELLOW,group=group,pattern=body_side))
            p.append(cyl(2.40,y0,sign*(width-.15),.15,y1-y0,YELLOW,group=group,pattern=body_side))
        for xa,xb in [(-.90,1.16),(2.34,2.53)]:
            z0,z1=sorted([sign*1.025,sign*1.17])
            p += rounded_block((xa,.49,z0),(xb,.75,z1),(.08,.065,.05),TRIM)
    # One shallow roof continues from the windshield to the rear doors.
    # Its lower half is buried in the body: the curved shoulder ends flush
    # with the flanks instead of overhanging them like an added roof box.
    p += rounded_block((-2.04,2.26,-1.085),(2.62,2.53,1.085),(.24,.134,.20),ROOF,group=group,pattern=roof_pattern)
    p += [box(-.86,.58,-1.035,2.55,.67,1.035,INNER),
          box(-.88,.67,-1.035,-.81,2.36,1.035,INNER),
          box(-.85,.67,-1.041,2.5,2.30,-1.013,INNER)]
    for x in [.15,1.2,2.15]: p.append(box(x,.74,-1.01,x+.04,2.28,-.99,DOOR_IN))
    for sign in [-1,1]:
        z=sign*1.11
        p += [box(2.49,.62,z-.035,2.585,2.295,z+.035,SEAL),
              box(2.57,.78,z-.075,2.635,1.17,z+.075,TAIL),
              box(2.637,.95,z-.068,2.65,1.04,z+.068,LIGHT),
              box(2.51,2.31,z-.07,2.60,2.39,z+.07,AMBER)]
    # Recess the seal under the curved lip; otherwise its straight top
    # intersects the cap and leaves a row of dark pixels on the paint.
    p += [box(2.49,2.245,-.99,2.55,2.295,.99,SEAL)]
    p += rounded_block((2.60,2.365,-.21),(2.655,2.475,.21),(.022,.03,.065),TAIL)
    p += rounded_block((2.47,.36,-1.17),(2.80,.63,1.17),(.11,.10,.18),TRIM)
    p += [box(2.802,.435,-.27,2.813,.555,.27,WHITE)]
    p += rear_doors(opening)
    if opening==0:
        p.append(box(2.658,.62,-.022,2.669,2.33,.022,SEAL))
    if opening==2:
        # Short folding step, without the industrial hydraulic frame.
        p += rounded_block((2.59,.28,-1.04),(3.35,.40,1.04),(.08,.04,.12),TRIM)
        p += [box(2.66,.40,-.96,3.26,.415,.96,RIM),
              box(3.30,.30,-.96,3.35,.36,.96,RED)]
        for x in [2.79,3.02]: p.append(box(x,.417,-.92,x+.026,.426,.92,TRIM))
    if opening:
        slots=[(2.16,-.40,.69,.66,.67,.67),(2.17,.39,.49,.66,.62,.67),(2.16,-.40,.57,.63,.64,1.36)]
        for x,z,h,w,d,y in slots[:load]:
            p += carton(w,h,d,(x,y,z))
            front=x+w/2+.012
            p += [box(front,y+.018,z-.034,front+.01,y+h+.008,z+.034,WHITE),
                  box(front+.012,y+h*.28,z+.11,front+.021,y+h*.52,z+.24,WHITE)]
    for x in [-1.90,1.74]:
        for z in [-1.26,1.045]:
            wheels=wheel(x,z)
            for part in wheels: part.suspension_static=True
            p += wheels
        p += arch(x,1.185)
    p = pitch_body(p,pitch)
    return finish(render(p,bounds=CLOSED_BOUNDS if opening==0 else None,
                         shadow=[(-2.88,-1.30,2.78,1.33)],shadow_alpha=65,edge_light=False))

LIGHTS=[
    {'x':-2.77,'y':1.01,'z':.84,'color':'ffd28a','blink':False,'power':.10},
    {'x':2.57,'y':2.35,'z':1.11,'color':'ffab32','blink':True,'power':.14},
    {'x':2.57,'y':2.35,'z':-1.11,'color':'ffab32','blink':True,'power':.14},
    {'x':-2.77,'y':.81,'z':.91,'color':'ffab32','blink':True,'power':.10},
    {'x':2.63,'y':.86,'z':1.11,'color':'ff7253','blink':False,'power':.08},
]
FOOTPRINTS=[[-2.94,-1.40,5.80,2.90],[-2.94,-1.40,6.70,2.90],[-2.94,-2.14,6.40,4.28]]

