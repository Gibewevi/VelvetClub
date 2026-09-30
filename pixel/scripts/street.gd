class_name Street
extends RefCounted

# The public street along the front of the lot and the car parks the player
# lays out behind it. Everything is in real metres at the game's scale (a
# floor cell is 1 m, a character stands 1.7 m tall), sized for the cars to
# come: a 4.4 x 1.8 m car, 2.5 x 5 m bays, a 6 m two-way aisle, a 7 m road.
#
# World axes: x runs along the street, z grows towards it. Cars drive on
# the right: the near lane (club side) heads -x, the far lane heads +x.
# A car pose is its rear axle (p) and heading (d); right of d is (-d.y, d.x).
#
# Construction uses extensible rows with a fixed facing and separate lanes.
# Bay entrances need free manoeuvring space but a single bay is sufficient.
# The optional traffic planner below remains separate from construction.

const LOT = 24.0
const LOT_FRONT = 8.0                    # private land ends: rooms and car parks stay behind
const WALK_NEAR = Vector2(8.0,10.5)      # public sidewalk, club side (z from, to)
const ROAD = Vector2(10.5,17.5)          # two 3.5 m lanes
const WALK_FAR = Vector2(17.5,20.0)
const LANE_WEST = 12.25                  # near lane, heading -x
const LANE_EAST = 15.75                  # far lane, heading +x

const CAR_L = 4.4
const CAR_W = 1.8
const WHEELBASE = 2.7
const TRACK = 1.55                       # between the wheel centres
const REAR = 0.8                         # rear axle to rear bumper
const PARK_NOSE = 1.2                    # rear axle depth into a bay, parked nose in (bumper 0.2 m off the kerb)
const PARK_BACK = 4.0                    # rear axle depth, backed in (rear bumper 0.2 m off the kerb)
const ROAD_RADII = [5.5,6.0,5.0,7.0,4.5] # rear-axle turning radii on the street, the easiest first
const BAY_RADII = [4.5,4.0,5.0]          # 4 m is a small car on full lock
const BAY_ENDS = [0.0,0.5,-0.5,1.0]      # where the turn into a bay ends, from its mouth
const MARGIN = 0.05                      # kept around parked cars

const BAY_W = 2.5
const BAY_D = 5.0
const AISLE = 6.0
const DRIVE = 6.0                        # driveway through the sidewalk
const FLARE = 1.5                        # the lowered kerb opens wider on each side
const MIN_TRAFFIC_BAYS = 2
const PRICE_M2 = 30
const STEP = 0.35

static var cache: Dictionary = {}
static var why = ""          # why the last check failed (tests and tuning)

# ------------------------------------------------------------------ layout

static func row_size(rotation: int, count: int = 1) -> Vector2:
	return Vector2(BAY_D,BAY_W*count) if posmod(rotation,2) == 1 else Vector2(BAY_W*count,BAY_D)

static func row_normal(rotation: int) -> Vector2:
	return [Vector2(0,-1),Vector2(-1,0),Vector2(0,1),Vector2(1,0)][posmod(rotation,4)]

static func row_axis(rotation: int) -> Vector2:
	return Vector2(0,1) if posmod(rotation,2) == 1 else Vector2(1,0)

static func price(r: Rect2) -> int:
	return roundi(r.get_area()*PRICE_M2)

static func bay_access(bay: Dictionary) -> Rect2:
	# Free manoeuvring space, shared by facing rows. It is not charged as
	# part of a place and can later be surfaced with the lane tool.
	var r: Rect2 = bay.rect
	if bay.n == Vector2(-1,0): return Rect2(r.end.x,r.position.y,AISLE,r.size.y)
	if bay.n == Vector2(1,0): return Rect2(r.position.x-AISLE,r.position.y,AISLE,r.size.y)
	if bay.n == Vector2(0,-1): return Rect2(r.position.x,r.end.y,r.size.x,AISLE)
	return Rect2(r.position.x,r.position.y-AISLE,r.size.x,AISLE)

static func layout(r: Rect2, rotation: int = -1, kind: String = "legacy") -> Dictionary:
	# A single extensible row. Extra depth in an old rectangular car park is
	# left open as an aisle; never put a second bay behind the first one.
	var key = ["row",r,rotation,kind]
	if cache.has(key): return cache[key]
	if rotation < 0:
		var along_x = int(floor(r.size.x/BAY_W)) if r.size.y >= BAY_D else 0
		var along_z = int(floor(r.size.y/BAY_W)) if r.size.x >= BAY_D else 0
		rotation = 1 if along_z > along_x else 0
	var n = row_normal(rotation)
	var along_z = n.x != 0
	var span = r.size.y if along_z else r.size.x
	var depth = r.size.x if along_z else r.size.y
	var count = int(floor(span/BAY_W)) if depth >= BAY_D else 0
	var lay = {"ok":false,"rect":r,"kind":kind,"rotation":rotation,"bays":[],"aisles":[],"drives":[],"lines":[],"error":""}
	if kind == "lane":
		lay.ok = r.size.x >= 0.5 and r.size.y >= 0.5
		lay.aisles.append(r)
	else:
		for i in range(count):
			var pos = r.position
			if along_z:
				pos.y += i*BAY_W
				if n.x > 0: pos.x = r.end.x-BAY_D
			else:
				pos.x += i*BAY_W
				if n.y > 0: pos.y = r.end.y-BAY_D
			var box = Rect2(pos,row_size(rotation))
			lay.bays.append({"rect":box,"mouth":box.get_center()-n*(BAY_D/2.0),"n":n,
				"index":i,"ways_in":[],"ways_out":[]})
		lay.ok = count > 0
		if lay.ok and depth > BAY_D:
			var lane = r
			if along_z:
				lane.size.x -= BAY_D
				if n.x < 0: lane.position.x += BAY_D
			else:
				lane.size.y -= BAY_D
				if n.y < 0: lane.position.y += BAY_D
			lay.aisles.append(lane)
	if not lay.ok: lay.error = "Trop petit : une place entière mesure 2,5 × 5 m. R pour tourner."
	if lay.ok and absf(r.end.y-LOT_FRONT) < 0.01:
		# Open only where a mouth or an aisle actually reaches the sidewalk.
		var fronts: Array = lay.aisles.duplicate()
		if n == Vector2(0,-1):
			for bay in lay.bays: fronts.append(bay.rect)
		for part in fronts:
			if absf(part.end.y-LOT_FRONT) < 0.01:
				lay.drives.append({"x0":part.position.x,"x1":part.end.x,"cx":part.get_center().x,"flare":0.0})
	build_lines(lay)
	if cache.size() > 300: cache.clear()
	cache[key] = lay
	return lay

static func traffic_layout(r: Rect2) -> Dictionary:
	# Bays, aisle(s), driveway(s) and the car routes for a zone the player
	# dragged, for the traffic demonstration only. Construction uses layout().
	var key = ["traffic",r]
	if cache.has(key): return cache[key]
	var best: Dictionary = {}
	var designs: Array = []
	for kind in ["across","along_left","along_right","along_mid"]:
		var lay = design(r,kind)
		if not lay.is_empty(): designs.append(lay)
	designs.sort_custom(func(a,b): return a.bound > b.bound)
	for lay in designs:
		if not best.is_empty() and lay.bound <= best.bays.size(): continue
		plan_bays(lay)
		if best.is_empty() or lay.bays.size() > best.bays.size(): best = lay
	if best.is_empty() or best.bays.size() < MIN_TRAFFIC_BAYS:
		best = {"ok":false,"rect":r,"kind":"","bays":[],"aisles":[],"drives":[],"lines":[],
			"error":"Trop petit : il faut au moins 12 × 12 m (l'allée de 6 m, une rangée de places et de quoi manœuvrer)."}
	else: best.ok = true
	if cache.size() > 300: cache.clear()
	cache[key] = best
	return best

static func design(r: Rect2, kind: String) -> Dictionary:
	# "across": aisles run from the street into the lot, one driveway each,
	# bays on both sides (16 m modules) or on one side with a metre of kerb
	# strip on the other (12 m: the bonnet swings over it).
	# "along_*": a row on the street side, the aisle, a row behind (16 m deep),
	# entered through a gap in the front row at the left, right or middle.
	var x0 = r.position.x
	var z0 = r.position.y
	var z1 = r.end.y
	var lay = {"kind":kind,"rect":r,"aisles":[],"drives":[],"bays":[],"lines":[],"memo":{}}
	if kind == "across":
		var n2 = int(r.size.x/16.0)
		var rest = r.size.x-n2*16.0
		var mods: Array = []
		for i in range(n2): mods.append(2)
		if rest >= 12.0: mods.append(1)
		var count = int(r.size.y/BAY_W)
		if mods.is_empty() or count < 1: return {}
		var used = n2*16.0+(12.0 if rest >= 12.0 else 0.0)
		var x = x0+floorf((r.size.x-used)/2.0)
		for m in mods:
			var ax = x+BAY_D
			var di = lay.drives.size()
			lay.aisles.append(Rect2(ax,z0,AISLE,r.size.y))
			lay.drives.append({"x0":ax,"x1":ax+AISLE,"cx":ax+AISLE/2.0})
			for side in ([-1,1] if m == 2 else [-1]):
				var mouth_x = ax if side < 0 else ax+AISLE
				for i in range(count):
					var cz = z1-BAY_W*(i+0.5)
					var bx = mouth_x-BAY_D if side < 0 else mouth_x
					lay.bays.append({"rect":Rect2(bx,cz-BAY_W/2.0,BAY_D,BAY_W),"mouth":Vector2(mouth_x,cz),"n":Vector2(side,0),
						"t":Vector2(0,-1),"drive":di,"deep":z1-cz})
			x += 16.0 if m == 2 else 12.0
	else:
		# the aisle along the street, a row behind it and, 16 m deep or more,
		# a row on the street side with a gap for the driveway
		if r.size.y < BAY_D+AISLE or r.size.x < DRIVE+2*BAY_W: return {}
		var front_row = r.size.y >= 2*BAY_D+AISLE
		var count_x = int(r.size.x/BAY_W)
		var bx0 = x0+(r.size.x-count_x*BAY_W)/2.0
		var zf = z1-BAY_D if front_row else z1   # front row mouth, or the sidewalk
		var zb = zf-AISLE                        # back row mouth
		var cx = {"along_left":x0+DRIVE/2.0,"along_right":r.end.x-DRIVE/2.0}.get(kind,snappedf(x0+r.size.x/2.0,0.5))
		lay.aisles.append(Rect2(x0,zb,r.size.x,AISLE))
		if front_row: lay.aisles.append(Rect2(cx-DRIVE/2.0,zf,DRIVE,BAY_D))   # the gap in the front row
		lay.drives.append({"x0":cx-DRIVE/2.0,"x1":cx+DRIVE/2.0,"cx":cx})
		for i in range(count_x):
			var bcx = bx0+BAY_W*(i+0.5)
			var t = Vector2(1,0) if bcx > cx else Vector2(-1,0)
			lay.bays.append({"rect":Rect2(bcx-BAY_W/2.0,zb-BAY_D,BAY_W,BAY_D),"mouth":Vector2(bcx,zb),"n":Vector2(0,-1),"t":t,"drive":0,
				"deep":absf(bcx-cx)+BAY_D})
			if front_row and absf(bcx-cx) >= DRIVE/2.0+BAY_W/2.0-0.01:
				lay.bays.append({"rect":Rect2(bcx-BAY_W/2.0,zf,BAY_W,BAY_D),"mouth":Vector2(bcx,zf),"n":Vector2(0,1),"t":t,"drive":0,
					"deep":absf(bcx-cx)})
	for i in range(lay.bays.size()):
		var b: Dictionary = lay.bays[i]
		b.index = i
		# where the parked car stands (nose in or backed in, the same place)
		var cs = corners(b.mouth+b.n*PARK_NOSE,b.n,MARGIN)
		b.car = Rect2(cs[0],Vector2.ZERO).expand(cs[1]).expand(cs[2]).expand(cs[3])
		b.active = true
	for b in lay.bays:
		# the parked cars a manoeuvre into this bay could touch
		b.near = []
		for o in lay.bays:
			if o != b and (o.mouth as Vector2).distance_to(b.mouth) < 12.0: b.near.append(int(o.index))
	# the street runs on past the ends of the lot, where the cars come from
	lay.wheels = [Rect2(-LOT-10,ROAD.x,2*LOT+20,ROAD.y-ROAD.x),r]+aprons(lay)
	lay.areas = lay.wheels+[Rect2(-LOT,WALK_NEAR.x,2*LOT,WALK_NEAR.y-WALK_NEAR.x),Rect2(-LOT,WALK_FAR.x,2*LOT,WALK_FAR.y-WALK_FAR.x)]
	# at most this many bays: a car must at least fit where it stops to back in
	lay.bound = 0
	var rmin = BAY_RADII.min()
	for b in lay.bays:
		b.room = clear(lay,[{"p":b.mouth+b.n*1.0+(b.t-b.n)*rmin,"d":b.t}],-2)
		if b.room and kind != "across":
			# along the street, the way back to the gap needs a turn out of
			# the bay and a turn into the gap, unless the bay faces the gap
			var d: Dictionary = lay.drives[0]
			var t_out = exit_heading(b)
			var from_x = b.mouth.x+rmin*t_out.x
			var gap_x = d.x0+CAR_W/2.0+0.2 if t_out.x < 0 else d.x1-CAR_W/2.0-0.2
			var facing = b.n == Vector2(0,-1) and b.mouth.x > d.x0+CAR_W/2.0 and b.mouth.x < d.x1-CAR_W/2.0
			b.room = facing or (gap_x-from_x)*t_out.x >= rmin-0.01
		if b.room: lay.bound += 1
	return lay

static func aprons(lay: Dictionary) -> Array:
	# The sidewalk crossings, as floor rectangles.
	var out: Array = []
	for d in lay.drives:
		var flare = float(d.get("flare",FLARE))
		out.append(Rect2(d.x0-flare,WALK_NEAR.x,d.x1-d.x0+2*flare,WALK_NEAR.y-WALK_NEAR.x))
	return out

# ------------------------------------------------------------------ car geometry

static func corners(p: Vector2, d: Vector2, grow: float = 0.0) -> Array:
	var right = Vector2(-d.y,d.x)
	var back = p-d*(REAR+grow)
	var front = p+d*(CAR_L-REAR+grow)
	var w = CAR_W/2.0+grow
	return [back-right*w,back+right*w,front+right*w,front-right*w]

static func hits(p: Vector2, d: Vector2, cs: Array, box: Rect2) -> bool:
	# The car against an axis-aligned rectangle: their boxes, then the car's
	# own two axes.
	var lo = Vector2(INF,INF)
	var hi = Vector2(-INF,-INF)
	for q in cs:
		lo = lo.min(q)
		hi = hi.max(q)
	if hi.x <= box.position.x or lo.x >= box.end.x or hi.y <= box.position.y or lo.y >= box.end.y: return false
	var right = Vector2(-d.y,d.x)
	var pts = [box.position,Vector2(box.end.x,box.position.y),box.end,Vector2(box.position.x,box.end.y)]
	for axis in [d,right]:
		var c = axis.dot(p)
		var a0 = c-REAR if axis == d else c-CAR_W/2.0
		var a1 = c+CAR_L-REAR if axis == d else c+CAR_W/2.0
		var bmin = INF
		var bmax = -INF
		for q in pts:
			var v = axis.dot(q)
			bmin = minf(bmin,v)
			bmax = maxf(bmax,v)
		if a1 <= bmin or bmax <= a0: return false
	return true

static func inside(areas: Array, q: Vector2) -> bool:
	for a in areas:
		if (a as Rect2).grow(0.01).has_point(q): return true
	return false

static func clear(lay: Dictionary, poses: Array, own: int = -1, blockers: Dictionary = {}) -> bool:
	# Every pose keeps the wheels on the roadway (street, driveway, car park)
	# and the body over it or over a sidewalk (a bumper may swing over a low
	# kerb, never through a wall), and misses every parked car; the parked
	# cars in the way are noted in blockers.
	for pose in poses:
		var right = Vector2(-pose.d.y,pose.d.x)*TRACK/2.0
		var front = pose.p+pose.d*WHEELBASE
		for q in [pose.p-right,pose.p+right,front+right,front-right]:
			if not inside(lay.wheels,q):
				why = "wheel off at %s" % str(q)
				return false
		var cs = corners(pose.p,pose.d)
		for i in range(4):
			if not inside(lay.areas,cs[i]) or not inside(lay.areas,cs[i].lerp(cs[(i+1)%4],0.5)):
				why = "body off at %s" % str(cs[i])
				return false
		if own == -2: continue
		for k in (lay.bays[own].near if own >= 0 else range(lay.bays.size())):
			var b: Dictionary = lay.bays[k]
			if b.active and hits(pose.p,pose.d,cs,b.car):
				why = "hits bay %d" % k
				blockers[int(k)] = true
				return false
	return true

# ------------------------------------------------------------------ moves

static func straight(route: Array, p: Vector2, d: Vector2, dist: float, rev: bool) -> Vector2:
	var n = maxi(int(ceil(absf(dist)/STEP)),1)
	var s = -1.0 if rev else 1.0
	for i in range(1,n+1): route.append({"p":p+d*(dist*i/n)*s,"d":d,"rev":rev})
	return p+d*dist*s

static func turn(route: Array, p: Vector2, d0: Vector2, d1: Vector2, radius: float, rev: bool) -> Vector2:
	# A quarter turn from heading d0 to d1, forwards or backwards; the rear
	# axle moves by radius * (d0 + d1), negated when reversing.
	var phi = d0.angle_to(d1)
	var c = p+Vector2(-d0.y,d0.x)*radius*signf(phi)*(-1.0 if rev else 1.0)
	var n = maxi(int(ceil(radius*absf(phi)/STEP)),2)
	for i in range(1,n+1):
		var a = phi*i/n
		route.append({"p":c+(p-c).rotated(a),"d":d0.rotated(a),"rev":rev})
	return c+(p-c).rotated(phi)

static func lane(east: bool) -> Dictionary:
	# The lane a car drives when heading east (+x) or west (-x), and where it
	# comes from or goes to at the end of the lot.
	return {"z":LANE_EAST if east else LANE_WEST,"d":Vector2(1,0) if east else Vector2(-1,0),"end":LOT if east else -LOT}

static func bay_in(bay: Dictionary, radius: float, e: float, mode: String) -> Dictionary:
	# From where the car stops in the aisle to parked. "back": past the bay,
	# a reversing quarter turn, back up to the kerb. "nose": a forward quarter
	# turn straight in. The rear axle ends the turn e metres into the bay.
	var t: Vector2 = bay.t
	var n: Vector2 = bay.n
	var end = bay.mouth+n*e
	var poses: Array = []
	if mode == "back":
		var start = end+(t-n)*radius
		poses.append({"p":start,"d":t,"rev":false})
		var p = turn(poses,start,t,-n,radius,true)
		straight(poses,p,-n,PARK_BACK-e,true)
		return {"start":start,"poses":poses}
	var start = end-(t+n)*radius
	poses.append({"p":start,"d":t,"rev":false})
	var p = turn(poses,start,t,n,radius,false)
	straight(poses,p,n,PARK_NOSE-e,false)
	return {"start":start,"poses":poses}

static func bay_out(bay: Dictionary, radius: float, e: float, mode: String) -> Dictionary:
	# Leaving: backed in, drive out and turn towards the way out; nose in,
	# back out turning. Ends in the aisle facing the way out.
	var n: Vector2 = bay.n
	var t_out = exit_heading(bay)
	var poses: Array = []
	if mode == "back":
		var p = straight(poses,bay.mouth+n*PARK_BACK,-n,PARK_BACK-e,false)
		p = turn(poses,p,-n,t_out,radius,false)
		return {"end":p,"poses":poses}
	var p = straight(poses,bay.mouth+n*PARK_NOSE,n,PARK_NOSE-e,true)
	p = turn(poses,p,n,t_out,radius,true)
	return {"end":p,"poses":poses}

static func exit_heading(bay: Dictionary) -> Vector2:
	# Towards the driveway: out to the street across, back to the gap along.
	return Vector2(0,1) if bay.t == Vector2(0,-1) else -bay.t

static func in_aisle(lay: Dictionary, p: Vector2, d: Vector2, from: Vector2) -> bool:
	# A straight run along an aisle stays inside it (bays are never in aisles).
	for q in corners(p,d)+corners(from,d):
		if not inside(lay.aisles,q): return false
	return true

# ------------------------------------------------------------------ street <-> aisle

static func approach(lay: Dictionary, bay: Dictionary, start: Vector2, east: bool, want_poses: bool = false) -> Dictionary:
	# From the end of the street to where the car stops in the aisle (start,
	# heading bay.t). The street part is worked out once per line and cached.
	var ln = lane(east)
	var drive: Dictionary = lay.drives[int(bay.drive)]
	var down = Vector2(0,-1)
	for rr in ROAD_RADII:
		if lay.kind == "across":
			var e_r = Vector2(start.x,ln.z-rr)
			if e_r.y < start.y-0.01: continue
			var key = "in:%.2f:%s:%.1f" % [start.x,east,rr]
			var poses: Array = []
			var s_r = e_r-(ln.d+down)*rr
			var p = straight(poses,Vector2(ln.end*-1.0,ln.z),ln.d,absf(s_r.x+ln.end),false) if want_poses else s_r
			var skip = poses.size()
			p = turn(poses,s_r,ln.d,down,rr,false)
			var cut = maxf(start.y,LOT_FRONT-BAY_D)
			straight(poses,p,down,e_r.y-cut,false)
			if not lay.memo.has(key+":%.2f" % cut): lay.memo[key+":%.2f" % cut] = clear(lay,poses.slice(skip))
			if not lay.memo[key+":%.2f" % cut]: continue
			if start.y < cut and not in_aisle(lay,start,down,Vector2(start.x,cut)): continue
			if want_poses: straight(poses,Vector2(start.x,cut),down,cut-start.y,false)
			return {"poses":poses,"radius":rr}
		else:
			for rg in BAY_RADII:
				for xg in gap_lines(drive,[start.x-rg*bay.t.x]):
					var g_end = Vector2(xg+rg*bay.t.x,start.y)
					if (start.x-g_end.x)*bay.t.x < -0.01: continue
					var g_start = Vector2(xg,start.y+rg)
					var e_r = Vector2(xg,ln.z-rr)
					if e_r.y < g_start.y-0.01: continue
					var key = "ing:%.2f:%.2f:%.1f:%.1f:%s:%.1f" % [xg,start.y,rg,bay.t.x,east,rr]
					var poses: Array = []
					var s_r = e_r-(ln.d+down)*rr
					var p = straight(poses,Vector2(ln.end*-1.0,ln.z),ln.d,absf(s_r.x+ln.end),false) if want_poses else s_r
					var skip = poses.size()
					p = turn(poses,s_r,ln.d,down,rr,false)
					p = straight(poses,p,down,e_r.y-g_start.y,false)
					p = turn(poses,p,down,bay.t,rg,false)
					if not lay.memo.has(key): lay.memo[key] = clear(lay,poses.slice(skip))
					if not lay.memo[key]: continue
					if not in_aisle(lay,start,bay.t,g_end): continue
					if want_poses: straight(poses,g_end,bay.t,absf(start.x-g_end.x),false)
					return {"poses":poses,"radius":rr}
	return {}

static func leave(lay: Dictionary, bay: Dictionary, from: Vector2, east: bool, want_poses: bool = false) -> Dictionary:
	# From the end of the way out of the bay (from, facing the way out) to
	# the end of the street.
	var ln = lane(east)
	var t_out = exit_heading(bay)
	var up = Vector2(0,1)
	for rr in ROAD_RADII:
		if lay.kind == "across":
			var s_r = Vector2(from.x,ln.z-rr)
			if s_r.y < from.y-0.01: continue
			var cut = maxf(from.y,LOT_FRONT-BAY_D)
			if from.y < cut and not in_aisle(lay,from,up,Vector2(from.x,cut)): continue
			var key = "out:%.2f:%s:%.1f:%.2f" % [from.x,east,rr,cut]
			var poses: Array = []
			if want_poses: straight(poses,from,up,cut-from.y,false)
			var skip = poses.size()
			var p = straight(poses,Vector2(from.x,cut),up,s_r.y-cut,false)
			p = turn(poses,p,up,ln.d,rr,false)
			if not lay.memo.has(key): lay.memo[key] = clear(lay,poses.slice(skip))
			if not lay.memo[key]: continue
			if want_poses: straight(poses,p,ln.d,absf(ln.end-p.x),false)
			return {"poses":poses,"radius":rr}
		else:
			var drive: Dictionary = lay.drives[int(bay.drive)]
			for rg in BAY_RADII:
				for xo in gap_lines(drive,[from.x+rg*t_out.x]):
					var q = Vector2(xo-rg*t_out.x,from.y)
					if (q.x-from.x)*t_out.x < -0.01: continue
					var s_r = Vector2(xo,ln.z-rr)
					if s_r.y < from.y+rg-0.01: continue
					if not in_aisle(lay,q,t_out,from): continue
					var key = "outg:%.2f:%.2f:%.1f:%.1f:%s:%.1f" % [xo,from.y,rg,t_out.x,east,rr]
					var poses: Array = []
					if want_poses: straight(poses,from,t_out,absf(q.x-from.x),false)
					var skip = poses.size()
					var p = turn(poses,q,t_out,up,rg,false)
					p = straight(poses,p,up,s_r.y-p.y,false)
					p = turn(poses,p,up,ln.d,rr,false)
					if not lay.memo.has(key): lay.memo[key] = clear(lay,poses.slice(skip))
					if not lay.memo[key]: continue
					if want_poses: straight(poses,p,ln.d,absf(ln.end-p.x),false)
					return {"poses":poses,"radius":rr}
	return {}

static func straight_out(lay: Dictionary, bay: Dictionary, east: bool, want_poses: bool = false) -> Dictionary:
	# Backed into a bay facing the gap: drive straight up to the street.
	var ln = lane(east)
	var up = Vector2(0,1)
	var from = bay.mouth+bay.n*PARK_BACK
	for rr in ROAD_RADII:
		var s_r = Vector2(from.x,ln.z-rr)
		if s_r.y < from.y: continue
		var poses: Array = []
		var p = straight(poses,from,up,s_r.y-from.y,false)
		p = turn(poses,p,up,ln.d,rr,false)
		if not clear(lay,poses,int(bay.index)): continue
		if want_poses: straight(poses,p,ln.d,absf(ln.end-p.x),false)
		return {"poses":poses,"radius":rr}
	return {}

# ------------------------------------------------------------------ planning

static func plan_bay(lay: Dictionary, bay: Dictionary, mode: String, blockers: Dictionary) -> bool:
	# The first way in and the first way out that clear everything, from
	# either end of the street.
	var found = false
	for radius in BAY_RADII:
		for e in BAY_ENDS:
			var bi = bay_in(bay,radius,e,mode)
			if not clear(lay,bi.poses,int(bay.index),blockers): continue
			var ways_in: Array = []
			for east in [true,false]:
				if not approach(lay,bay,bi.start,east).is_empty(): ways_in.append(east)
			if ways_in.is_empty(): continue
			bay.in_r = radius
			bay.in_e = e
			bay.ways_in = ways_in
			found = true
			break
		if found: break
	if not found: return false
	if mode == "back" and lay.kind != "across" and bay.n == Vector2(0,-1):
		# a back-row bay facing the driveway gap: straight out to the street
		var drive: Dictionary = lay.drives[int(bay.drive)]
		if bay.mouth.x >= drive.x0+CAR_W/2.0+0.1 and bay.mouth.x <= drive.x1-CAR_W/2.0-0.1:
			var ways_out: Array = []
			for east in [true,false]:
				if not straight_out(lay,bay,east).is_empty(): ways_out.append(east)
			if not ways_out.is_empty():
				bay.out_r = 0.0
				bay.out_e = 0.0
				bay.ways_out = ways_out
				bay.mode = mode
				return true
	for radius in BAY_RADII:
		for e in BAY_ENDS:
			var bo = bay_out(bay,radius,e,mode)
			if not clear(lay,bo.poses,int(bay.index),blockers): continue
			var ways_out: Array = []
			for east in [true,false]:
				if not leave(lay,bay,bo.end,east).is_empty(): ways_out.append(east)
			if ways_out.is_empty(): continue
			bay.out_r = radius
			bay.out_e = e
			bay.ways_out = ways_out
			bay.mode = mode
			return true
	return false

static func alone(lay: Dictionary, bay: Dictionary) -> bool:
	# Nobody parked in the next bay along: a car can then turn in nose first
	# (its bonnet swings over that bay, and swings back over it backing out).
	var beyond = bay.mouth+bay.t*BAY_W
	for k in bay.near:
		var o: Dictionary = lay.bays[k]
		if o.active and o.n == bay.n and (o.mouth as Vector2).distance_to(beyond) < 0.1: return false
	return true

static func gap_lines(drive: Dictionary, extra: Array = []) -> Array:
	# Where a car can run up or down the driveway gap, its body inside it.
	var out: Array = []
	for x in [drive.cx+1.5,drive.cx,drive.cx-1.5,drive.x0+CAR_W/2.0+0.2,drive.x1-CAR_W/2.0-0.2]+extra:
		if x >= drive.x0+CAR_W/2.0+0.1 and x <= drive.x1-CAR_W/2.0-0.1 and not out.has(snappedf(x,0.05)): out.append(snappedf(x,0.05))
	return out

static func plan_bays(lay: Dictionary) -> void:
	# Every bay needs a way in and out with all the others taken. When some
	# cannot, the deepest of them is given up (its space becomes room to
	# manoeuvre) and the others are tried again.
	# A bay that fails with nobody in its way never will: out at once.
	# Otherwise the deepest failing one goes, and only the bays it was in the
	# way of are tried again.
	for b in lay.bays: b.ok = false
	var pending: Array = lay.bays.duplicate()
	while true:
		var failing: Array = []
		for b in pending:
			if not b.active: continue
			if b.has("blockers"):
				# still blocked by the same parked cars: no need to try again
				var freed = false
				for k in b.blockers:
					if not lay.bays[k].active: freed = true
				if not freed:
					failing.append(b)
					continue
			var blockers: Dictionary = {}
			if (b.room and plan_bay(lay,b,"back",blockers)) or (alone(lay,b) and plan_bay(lay,b,"nose",blockers)): b.ok = true
			elif blockers.is_empty(): b.active = false
			else:
				b.blockers = blockers
				failing.append(b)
		if failing.is_empty(): break
		var worst = failing[0]
		for b in failing:
			if float(b.deep) > float(worst.deep): worst = b
		worst.active = false
		# ways found stay good with a car less; ways refused may now be free
		for k in lay.memo.keys():
			if not lay.memo[k]: lay.memo.erase(k)
		failing.erase(worst)
		pending = failing
	var kept: Array = []
	for b in lay.bays:
		if b.active and b.ok: kept.append(b)
	lay.bays = kept
	for i in range(kept.size()):
		kept[i].index = i
		kept[i].erase("blockers")
	for b in kept:
		b.near = []
		for o in kept:
			if o != b and (o.mouth as Vector2).distance_to(b.mouth) < 12.0: b.near.append(int(o.index))
	lay.memo.clear()
	build_lines(lay)

static func build_lines(lay: Dictionary) -> void:
	# the white lines: both long sides of every bay, shared ones once
	lay.lines.clear()
	var seen: Dictionary = {}
	for bay in lay.bays:
		var r: Rect2 = bay.rect
		var sides = [[r.position,Vector2(r.end.x,r.position.y)],[Vector2(r.position.x,r.end.y),r.end]] if bay.n.x != 0 else [[r.position,Vector2(r.position.x,r.end.y)],[Vector2(r.end.x,r.position.y),r.end]]
		for s in sides:
			var k = "%.2f:%.2f:%.2f:%.2f" % [s[0].x,s[0].y,s[1].x,s[1].y]
			if seen.has(k): continue
			seen[k] = true
			lay.lines.append(s)

# ------------------------------------------------------------------ routes for the cars to come

static func route_in(lay: Dictionary, bay_index: int, east: bool) -> Array:
	# The whole way from the end of the street to parked in the bay.
	var bay: Dictionary = lay.bays[bay_index]
	if not east in bay.ways_in: return []
	var bi = bay_in(bay,bay.in_r,bay.in_e,bay.mode)
	return approach(lay,bay,bi.start,east,true).poses+bi.poses

static func route_out(lay: Dictionary, bay_index: int, east: bool) -> Array:
	# Out of the bay, along the aisle and off down the street.
	var bay: Dictionary = lay.bays[bay_index]
	if not east in bay.ways_out: return []
	if float(bay.out_r) == 0.0: return straight_out(lay,bay,east,true).poses
	var bo = bay_out(bay,bay.out_r,bay.out_e,bay.mode)
	return bo.poses+leave(lay,bay,bo.end,east,true).poses
