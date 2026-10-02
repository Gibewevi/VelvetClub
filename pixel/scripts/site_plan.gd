class_name SitePlan
extends RefCounted

# A room the player draws is first a building site. How far the works have
# gone lives in room.build, so it is saved, undone and redone with the room;
# the view never decides anything, it only shows what this says is done.
#
# Work is counted in crew minutes (the three workers together, one per game
# minute) and spent on elements in a fixed order:
#   slab   concrete poured cell by cell from the back corner
#   walls  block courses laid all round, one course after the other
#   paint  each wall segment painted from end to end
#   floor  the floor covering laid cell by cell
#   finish clean-up: equipment carried out, workers leave
# The current phase is the phase of the first unfinished element, so cells
# added by enlarging the site send the crew back to pour them first, while
# everything already built stays.

const PHASES = ["slab","walls","paint","floor","finish"]
const NAMES = {"slab":"Dalle de béton","walls":"Montée des murs","paint":"Peinture des murs","floor":"Pose du sol","finish":"Finitions"}
const SLAB = 1.2          # crew minutes per m² of slab
const ROW = 0.35          # one course of blocks along one metre of wall
const PAINT_FULL = 3.0    # painting one metre of full-height wall
const PAINT_LOW = 1.0     # one metre of cut-away front wall
const FLOOR = 1.5         # floor covering, per m²
const FINISH = 10.0       # cleaning up and carrying the equipment out
const FULL_ROWS = 14      # block courses in a full wall (4 px each)
const LOW_ROWS = 3        # in a cut-away front wall
const DRY = 45.0          # minutes for fresh concrete to dry out

static func start() -> Dictionary:
	return {"done":{},"clock":0.0,"wet":{}}

static func building(room: Dictionary) -> bool:
	return room.get("build") is Dictionary

static func cell_key(prefix: String, c: Vector2i) -> String:
	return "%s:%d:%d" % [prefix,c.x,c.y]

static func cells(room: Dictionary) -> Array:
	# From the back corner towards the camera, in diagonal bands.
	var out: Array = BuildingModel.cells_of(room).keys()
	out.sort_custom(func(a,b): return a.x+a.y < b.x+b.y or (a.x+a.y == b.x+b.y and a.x < b.x))
	return out

static func segments(model: BuildingModel, room: Dictionary) -> Array:
	# The site's own wall segments round the perimeter, starting at the back
	# corner. A wall already standing (shared with a finished room) or that
	# an older site builds is left out.
	var out: Array = []
	for e in BuildingModel.outline(room): out.append(segment(model,room,e.axis,e.x,e.z,e.front))
	return out.filter(func(s): return not s.is_empty())

static func segment(model: BuildingModel, room: Dictionary, axis: String, x: int, z: int, front: bool) -> Dictionary:
	# front: the edge on the room's +x / +z side, a cut-away wall in this view
	var beyond = Vector2(x+0.5,z+(0.5 if front else -0.5)) if axis == "x" else Vector2(x+(0.5 if front else -0.5),z+0.5)
	var other = model.room_at(beyond)
	if not other.is_empty():
		if not building(other) or int(other.id) < int(room.id): return {}
	var key = BuildingModel.edge_key(axis,x,z)
	var opening: String = model.openings.get(key,"")
	var full = not front or not other.is_empty()
	var kind = "plain"
	if opening == "door": kind = "door"
	elif opening == "window" and full: kind = "window"
	var rows = FULL_ROWS if full else LOW_ROWS
	if opening == "door" and not full: rows = 0
	var inward = Vector2(0,1) if axis == "x" else Vector2(1,0)
	if front: inward = -inward
	return {"key":key,"axis":axis,"x":x,"z":z,"front":front,"full":full,"kind":kind,"opening":opening,"rows":rows,"inward":inward}

static func elements(model: BuildingModel, room: Dictionary) -> Array:
	var out: Array = []
	var cs = cells(room)
	for c in cs: out.append({"phase":"slab","key":cell_key("s",c),"base":0,"cost":SLAB,"cell":c})
	var segs = segments(model,room)
	var top = 0
	for s in segs: top = maxi(top,int(s.rows))
	for row in range(top):
		for s in segs:
			if row < int(s.rows): out.append({"phase":"walls","key":"w:"+s.key,"base":row,"cost":ROW,"seg":s})
	for s in segs:
		if int(s.rows) > 0: out.append({"phase":"paint","key":"p:"+s.key,"base":0,"cost":PAINT_FULL if s.full else PAINT_LOW,"seg":s})
	for c in cs: out.append({"phase":"floor","key":cell_key("f",c),"base":0,"cost":FLOOR,"cell":c})
	out.append({"phase":"finish","key":"fin","base":0,"cost":FINISH})
	return out

static func fraction(build: Dictionary, e: Dictionary) -> float:
	return clampf(float(build.done.get(e.key,0.0))-float(e.base),0.0,1.0)

static func first_open(build: Dictionary, els: Array, from: int = 0) -> int:
	var i = clampi(from,0,els.size())
	while i < els.size() and fraction(build,els[i]) >= 1.0: i += 1
	return i

static func work(build: Dictionary, els: Array, minutes: float, from: int = 0) -> int:
	# Spend crew minutes on the first unfinished elements, in order. Returns
	# the index of the first element still open (els.size() once done).
	build.clock = float(build.get("clock",0.0))+minutes
	var left = minutes
	var i = first_open(build,els,from)
	while i < els.size() and left > 0.0:
		var e: Dictionary = els[i]
		var f = fraction(build,e)
		var spent = minf(left,(1.0-f)*float(e.cost))
		left -= spent
		f += spent/float(e.cost)
		if f >= 1.0-1e-6:
			build.done[e.key] = float(e.base)+1.0
			if e.phase == "slab": build.wet[cell_key("c",e.cell)] = float(build.clock)-left
			i = first_open(build,els,i+1)
		else: build.done[e.key] = float(e.base)+f
	return i

static func totals(build: Dictionary, els: Array) -> Vector2:
	# (work done, total work) in crew minutes
	var done = 0.0
	var total = 0.0
	for e in els:
		total += float(e.cost)
		done += fraction(build,e)*float(e.cost)
	return Vector2(done,total)

static func progress(build: Dictionary, els: Array) -> float:
	var t = totals(build,els)
	return t.x/t.y if t.y > 0.0 else 1.0

static func remaining(build: Dictionary, els: Array) -> float:
	var t = totals(build,els)
	return maxf(t.y-t.x,0.0)

static func phase(build: Dictionary, els: Array) -> String:
	var i = first_open(build,els)
	return "done" if i >= els.size() else String(els[i].phase)

static func rows(build: Dictionary, seg: Dictionary) -> int:
	return clampi(floori(float(build.done.get("w:"+seg.key,0.0))+1e-6),0,int(seg.rows))

static func painted(build: Dictionary, seg: Dictionary) -> float:
	return clampf(float(build.done.get("p:"+seg.key,0.0)),0.0,1.0)

static func wetness(build: Dictionary, c: Vector2i) -> float:
	# 1 just poured, 0 dry
	var at = build.wet.get(cell_key("c",c))
	if at == null: return 0.0
	return clampf(1.0-(float(build.clock)-float(at))/DRY,0.0,1.0)

static func tidy(build: Dictionary, els: Array) -> void:
	# Forget work on elements the site no longer has (a side moved away) and
	# concrete that has dried.
	var keep: Dictionary = {}
	for e in els: keep[e.key] = true
	for k in build.done.keys():
		if not keep.has(k): build.done.erase(k)
	for k in build.wet.keys():
		if float(build.clock)-float(build.wet[k]) > DRY or not keep.has("s"+String(k).substr(1)): build.wet.erase(k)

static func merge(live: Dictionary, saved: Dictionary) -> Dictionary:
	# Undo/redo restores an older plan, never older progress: keep the most
	# advanced work of both.
	var out = saved.duplicate(true)
	for k in live.done:
		out.done[k] = maxf(float(out.done.get(k,0.0)),float(live.done[k]))
	for k in live.wet:
		if not out.wet.has(k): out.wet[k] = live.wet[k]
	out.clock = maxf(float(out.get("clock",0.0)),float(live.get("clock",0.0)))
	return out

static func sanitize(value: Variant) -> Dictionary:
	# A saved site; {} when the data cannot be trusted.
	if not value is Dictionary: return {}
	var clock = value.get("clock",0.0)
	if not (clock is float or clock is int) or not is_finite(float(clock)) or float(clock) < 0.0: return {}
	var out = {"done":{},"clock":float(clock),"wet":{}}
	for field in ["done","wet"]:
		var d = value.get(field,{})
		if not d is Dictionary or d.size() > 20000: return {}
		for k in d:
			if not k is String or k.length() > 40: return {}
			var v = d[k]
			if not (v is float or v is int) or not is_finite(float(v)) or float(v) < 0.0: return {}
			if field == "done" and float(v) > FULL_ROWS+1: return {}
			out[field][k] = float(v)
	return out

static func duration_text(minutes: float) -> String:
	var m = ceili(minutes)
	if m < 60: return "%d min" % m
	return "%d h %02d" % [m/60,m%60]
