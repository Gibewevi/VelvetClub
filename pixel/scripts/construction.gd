class_name Construction
extends Node

# Building sites. Each room still under construction gets a crew of three
# workers and its equipment. Time is spent on the site by SitePlan (the
# logical side: minutes, %, phases); here the sprites of the elements it
# reports done are revealed (concrete cells, block courses, painted strips,
# floor cells) and the workers act out the current phase near the element
# being built.

const CREW = 3
# equipment along the back walls, most useful first (small sites get less)
const PROPS = ["pallet_blocks","mixer","light","bags","barrow_parked","sawhorse","rebar","bucket","blocks"]
const FOOT = {"pallet_blocks":Vector2(1.0,0.8),"mixer":Vector2(0.85,0.85),"light":Vector2(0.6,0.6),"bags":Vector2(0.9,0.7),
	"barrow_parked":Vector2(1.0,0.8),"sawhorse":Vector2(1.3,0.55),"rebar":Vector2(1.2,0.6),"bucket":Vector2(0.4,0.4),"blocks":Vector2(0.6,0.5)}
const CONCRETE_DRY = Color("8a8c93")
const CONCRETE_WET = Color("50535e")
const DIRT = Color("5e4a3c")
const TAPE = Color("ff8a3a")

var game
var model: BuildingModel
var view: WorldView
var sim: ClubSim
var sites: Dictionary = {}       # room id -> site
var enabled = true
var frozen = false              # captures: the crew moves, the works do not advance
var clock = 0.0
var wet_timer = 0.0
var rgba: ShaderMaterial
var wet_mats: Array = []
var dirt_mat: ShaderMaterial

func setup(main) -> void:
	game = main
	model = main.model
	view = main.view
	sim = main.sim
	view.construction = self
	rgba = Art.rgba_material()
	for k in range(5):
		wet_mats.append(Art.material(Palette.floor_palette(CONCRETE_DRY.lerp(CONCRETE_WET,k/4.0)),40.0,8.0))
	dirt_mat = Art.material(Palette.floor_palette(DIRT),40.0,8.0)

# ------------------------------------------------------------------ sites

func site_of(room_id: int) -> Dictionary:
	return sites.get(room_id,{})

func sync_sites() -> void:
	# Follow the plan: new sites get their crew, an enlarged site its new
	# cells and walls, a removed or finished one loses its workers.
	var seen: Dictionary = {}
	for room in model.rooms:
		if not SitePlan.building(room): continue
		var id = int(room.id)
		seen[id] = true
		var s: Dictionary = sites.get(id,{})
		var fresh = s.is_empty()
		if fresh:
			s = {"id":id,"workers":[],"phase":"","vis":{}}
			sites[id] = s
		s.room = room
		if room.has("merge_into"):
			# an extension is painted and floored like the room it joins
			var target = model.room_by_id(int(room.merge_into))
			if not target.is_empty():
				room.type = target.type
				for key in ["floor_finish","floor_color","wall_finish","wall_color"]: room[key] = target[key]
		s.rect = model.bounds(room)
		s.shape = model.shape(room)
		s.els = SitePlan.elements(model,room)
		SitePlan.tidy(room.build,s.els)
		s.cursor = SitePlan.first_open(room.build,s.els)
		s.segs = SitePlan.segments(model,room)
		s.cells = SitePlan.cells(room)
		s.props = layout_props(room)
		s.grid = make_grid(s)
		s.phase = SitePlan.phase(room.build,s.els)
		while s.workers.size() < CREW: s.workers.append(hire(s,s.workers.size()))
		for w in s.workers:
			w.site_id = id
			w.tasks.clear()
			w.task = {}
			w.path = []
			if not standable(s,w.world,0.1): w.set_world(free_spot(s,w.world))
	for id in sites.keys():
		if seen.has(id): continue
		for w in sites[id].workers:
			if is_instance_valid(w): view.remove_actor(w)
		sites.erase(id)

func hire(s: Dictionary, index: int) -> SiteWorker:
	var w = SiteWorker.new()
	w.simulation = sim
	w.setup(index+int(s.id))
	w.role = index
	var r: Rect2 = s.rect
	# they come in on the front side of the site
	var start = Vector2(r.position.x+r.size.x*(0.3+0.2*index),r.end.y-0.4)
	w.set_world(free_spot(s,start))
	w.face(Vector2(-1,-1))
	view.add_actor(w)
	return w

func layout_props(room: Dictionary) -> Array:
	var b = model.bounds(room)
	var x0 = int(b.position.x)
	var z0 = int(b.position.y)
	var cells: Array = BuildingModel.cells_of(room).keys()
	# along the back walls, from the back corner outwards
	var back = func(c: Vector2i) -> int: return mini(c.x-x0,c.y-z0)*100+(c.x-x0)+(c.y-z0)
	cells.sort_custom(func(a,c): return back.call(a) < back.call(c))
	var area = cells.size()
	var n = mini(clampi(area/3,2,PROPS.size()),maxi(area/2,1))
	var out: Array = []
	for i in range(mini(n,cells.size())):
		var c: Vector2i = cells[i]
		var name: String = PROPS[i]
		var pos = Vector2(c)+Vector2(0.5,0.5)
		# long pieces lie along the back wall they stand against
		var size: Vector2 = FOOT[name]
		out.append({"name":name,"cell":c,"pos":pos,"rect":Rect2(pos-size/2.0,size)})
	return out

func make_grid(s: Dictionary) -> AStarGrid2D:
	var g = AStarGrid2D.new()
	var r: Rect2 = s.rect
	g.region = Rect2i(int(r.position.x)*2,int(r.position.y)*2,int(r.size.x)*2,int(r.size.y)*2)
	g.cell_size = Vector2(0.5,0.5)
	g.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	g.update()
	for cx in range(g.region.position.x,g.region.end.x):
		for cy in range(g.region.position.y,g.region.end.y):
			if not standable(s,Vector2(cx*0.5+0.25,cy*0.5+0.25),0.0): g.set_point_solid(Vector2i(cx,cy))
	return g

func standable(s: Dictionary, p: Vector2, margin: float) -> bool:
	# On the site's own ground (an extension may be an L), clear of equipment.
	var shape: RoomShape = s.shape if margin <= 0.0 else s.shape.grow(-margin)
	return shape.has_point(p) and not blocked(s,p)

func blocked(s: Dictionary, p: Vector2) -> bool:
	for prop in s.get("props",[]):
		if (prop.rect as Rect2).grow(0.05).has_point(p): return true
	return false

func free_spot(s: Dictionary, p: Vector2) -> Vector2:
	# The nearest point inside the site that no equipment stands on.
	var r: Rect2 = s.rect.grow(-0.3)
	var q = p.clamp(r.position,r.end)
	if standable(s,q,0.3): return q
	for radius in [0.5,1.0,1.5,2.0,3.0,4.5]:
		var best = Vector2.INF
		for k in range(16):
			var a = TAU*k/16.0
			var c = (q+Vector2(cos(a),sin(a))*radius).clamp(r.position,r.end)
			if standable(s,c,0.3) and (best == Vector2.INF or c.distance_to(p) < best.distance_to(p)): best = c
		if best != Vector2.INF: return best
	for c in s.get("cells",[]):
		var center = Vector2(c)+Vector2(0.5,0.5)
		if not blocked(s,center): return center
	return q

func site_path(s: Dictionary, from: Vector2, to: Vector2) -> Array:
	var g: AStarGrid2D = s.grid
	var a = Vector2i(floori(from.x*2),floori(from.y*2)).clamp(g.region.position,g.region.end-Vector2i.ONE)
	var b = Vector2i(floori(to.x*2),floori(to.y*2)).clamp(g.region.position,g.region.end-Vector2i.ONE)
	var out: Array = []
	if not g.is_point_solid(a) and not g.is_point_solid(b):
		var pts = g.get_point_path(a,b)
		for i in range(1,pts.size()-1): out.append(pts[i]+Vector2(0.25,0.25))
	out.append(to)
	return out

# ------------------------------------------------------------------ time

func _process(delta: float) -> void:
	var p0 = Prof.t("sites")
	_timed_process(delta)
	Prof.add("sites",p0)

func _timed_process(delta: float) -> void:
	if sites.is_empty(): return
	var running = enabled and sim.active and not sim.paused_for_report and sim.speed > 0
	step(minf(delta,ClubSim.MAX_FRAME) if running else 0.0)

func step(delta: float) -> void:
	var minutes = delta*sim.speed*ClubSim.MINUTES_PER_SECOND
	clock += delta*sim.speed
	wet_timer -= delta
	var done: Array = []
	for s in sites.values():
		if minutes > 0.0 and not frozen: advance(s,minutes)
		for w in s.workers:
			if is_instance_valid(w): run_worker(s,w,delta,minutes)
		animate(s)
		if s.cursor >= s.els.size(): done.append(s)
	if wet_timer <= 0.0:
		wet_timer = 1.0
		for s in sites.values(): show_slab(s)
	for s in done: complete(s)

func advance(s: Dictionary, minutes: float) -> void:
	var b: Dictionary = s.room.build
	var before = int(s.cursor)
	s.cursor = SitePlan.work(b,s.els,minutes,s.cursor)
	var ph = SitePlan.phase(b,s.els) if s.cursor < s.els.size() else "done"
	if ph != s.phase:
		s.phase = ph
		for w in s.workers:
			w.tasks.clear()
			w.wait = 0.0
	if s.cursor != before or ph in ["paint","finish"]: refresh(s)

func complete(s: Dictionary) -> void:
	# The room is ready: equipment and workers go, the room is usable. An
	# extension joins its room: the wall between them comes down.
	for w in s.workers:
		if is_instance_valid(w): view.remove_actor(w)
	s.workers.clear()
	sites.erase(s.id)
	var room: Dictionary = s.room
	var works: Dictionary = room.build
	room.erase("build")
	var joined = -1
	if room.has("merge_into"):
		var target = model.room_by_id(int(room.merge_into))
		# into a room still being built: the work done comes along
		if SitePlan.building(target): target.build = SitePlan.merge(works,target.build)
		joined = model.merge_extension(int(room.id))
	if game != null: game.site_finished(room,joined)

func fast_forward(room_id: int, minutes: float) -> void:
	# Tests and captures: spend site time at once (the crew does not walk).
	var s = site_of(room_id)
	if s.is_empty(): return
	advance(s,minutes)
	show_slab(s)
	if s.cursor >= s.els.size(): complete(s)

# ------------------------------------------------------------------ status (interface)

func status(room: Dictionary) -> Dictionary:
	var s = site_of(int(room.id))
	if s.is_empty() or not SitePlan.building(room): return {}
	var b: Dictionary = room.build
	var p = SitePlan.progress(b,s.els)
	var left = SitePlan.remaining(b,s.els)
	return {"progress":p,"percent":floori(p*100.0+1e-6),"phase":s.phase,"phase_name":SitePlan.NAMES.get(s.phase,"Terminé"),
		"minutes":left,"real_seconds":left/ClubSim.MINUTES_PER_SECOND/maxf(float(sim.speed),1.0)}

# ------------------------------------------------------------------ view

func build_view() -> void:
	# Called by every rebuild of the view, after the finished walls.
	sync_sites()
	for s in sites.values(): build_site(s)

func floor_poly(points: PackedVector2Array, tex: Texture2D, mat: Material) -> Polygon2D:
	var poly = Polygon2D.new()
	poly.polygon = points
	poly.texture = tex
	poly.uv = points
	poly.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	poly.material = mat
	return poly

func build_site(s: Dictionary) -> void:
	var room: Dictionary = s.room
	var r: Rect2 = s.rect
	var vis = {"slab":{},"floor":{},"walls":{},"posts":[],"tape":{},"props":[],"glows":[]}
	s.vis = vis
	for part in BuildingModel.parts_of(room):
		view.floors.add_child(floor_poly(Iso.diamond(part.position.x,part.position.y,part.end.x,part.end.y),Art.tex(Art.tiles.floors.dirt),dirt_mat))
	var concrete = Art.tex(Art.tiles.floors.concrete)
	for c in s.cells:
		var poly = floor_poly(Iso.diamond(c.x,c.y,c.x+1,c.y+1),concrete,wet_mats[0])
		view.floors.add_child(poly)
		vis.slab[c] = poly
	var finish_tex = Art.tex(Art.tiles.floors[Finishes.floor_pattern(room)])
	var finish_mat = Art.material(Palette.floor_palette(Color(room.floor_color)),40.0,8.0)
	for c in s.cells:
		var poly = floor_poly(Iso.diamond(c.x,c.y,c.x+1,c.y+1),finish_tex,finish_mat)
		view.floors.add_child(poly)
		vis.floor[c] = poly
	# the zone is marked out on the ground as soon as it is ordered
	var line = WorldView.Strokes.new()
	line.color = TAPE
	var corners: Array = []
	var loop = BuildingModel.outline(room)
	for i in range(loop.size()):
		if i == 0 or loop[i].axis != loop[i-1].axis: corners.append(Vector2(loop[i].a))
	for i in range(corners.size()):
		var a: Vector2 = corners[i]
		var b: Vector2 = corners[(i+1) % corners.size()]
		var n = int(a.distance_to(b)*4)
		for k in range(0,n,2):
			line.segs.append(Iso.to_screen(lerpf(a.x,b.x,float(k)/n),lerpf(a.y,b.y,float(k)/n)).round())
			line.segs.append(Iso.to_screen(lerpf(a.x,b.x,float(k+1)/n),lerpf(a.y,b.y,float(k+1)/n)).round())
	view.floor_fx.add_child(line)
	vis.line = line
	var wall_mat = Art.material(Palette.wall_palette(Color(room.wall_color)))
	vis.wall_mat = wall_mat
	for seg in s.segs:
		var rect = Rect2(seg.x,seg.z,1,0) if seg.axis == "x" else Rect2(seg.x,seg.z,0,1)
		var pos = Iso.pixel(seg.x,seg.z)
		var node = Node2D.new()
		node.position = pos
		var entry = view.add_static(node,rect,"site_wall",{"key":seg.key})
		var block = Sprite2D.new()
		block.centered = false
		block.material = rgba
		node.add_child(block)
		var paint = Sprite2D.new()
		paint.centered = false
		paint.material = wall_mat
		paint.region_enabled = true
		paint.visible = false
		node.add_child(paint)
		vis.walls[seg.key] = {"entry":entry,"block":block,"paint":paint,"rows":-1,"kind":"","seg":seg}
		var tinfo: Dictionary = Art.site["tape_"+seg.axis]
		var tape = view.sprite(Art.tex(tinfo.file),pos,Vector2(tinfo.ox,tinfo.oy),rgba)
		view.add_static(tape,rect,"site_tape")
		vis.tape[seg.key] = tape
	# block posts at corners and wall ends, unless a finished wall meets there
	var finished_points: Dictionary = {}
	var walls = model.edges()
	for k in walls:
		var e: Dictionary = walls[k]
		var owners = e.rooms.filter(func(id): return not SitePlan.building(model.room_by_id(int(id))))
		if owners.is_empty(): continue
		finished_points[Vector2i(e.x,e.z)] = true
		finished_points[Vector2i(e.x,e.z)+(Vector2i(1,0) if e.axis == "x" else Vector2i(0,1))] = true
	var points: Dictionary = {}
	for seg in s.segs:
		var a = Vector2i(seg.x,seg.z)
		for p in [a,a+(Vector2i(1,0) if seg.axis == "x" else Vector2i(0,1))]:
			if not points.has(p): points[p] = []
			points[p].append(seg)
	for p in points:
		if finished_points.has(p): continue
		var list: Array = points[p]
		var need = list.size() != 2 or list[0].axis != list[1].axis or list.any(func(q): return q.kind == "door")
		if not need: continue
		var node = Node2D.new()
		node.position = Iso.pixel(p.x,p.y)
		var entry = view.add_static(node,Rect2(p.x,p.y,0,0),"site_post")
		var block = Sprite2D.new()
		block.centered = false
		block.material = rgba
		node.add_child(block)
		var paint = Sprite2D.new()
		paint.centered = false
		paint.material = wall_mat
		paint.visible = false
		node.add_child(paint)
		vis.posts.append({"entry":entry,"block":block,"paint":paint,"segs":list,"rows":-1})
	for prop in s.props:
		var spr = Sprite2D.new()
		spr.centered = false
		spr.material = rgba
		spr.position = Iso.pixel(prop.pos.x,prop.pos.y)
		var entry = view.add_static(spr,prop.rect,"prop")
		entry.sprite = spr
		var p = {"prop":prop,"entry":entry,"sprite":spr,"shown":"?","glows":[]}
		if prop.name == "light":
			var g: Dictionary = Art.site.light.glow
			p.glows = view.add_glow(entry,spr.position+Vector2(0,float(g.y)),Color(g.color),float(g.radius),float(g.power))
		vis.props.append(p)
	refresh(s)
	show_slab(s)

func refresh(s: Dictionary) -> void:
	# Show exactly what SitePlan says is done.
	if s.get("vis",{}).is_empty(): return
	var b: Dictionary = s.room.build
	var vis: Dictionary = s.vis
	for c in s.cells:
		vis.slab[c].visible = float(b.done.get(SitePlan.cell_key("s",c),0.0)) >= 1.0
		vis.floor[c].visible = float(b.done.get(SitePlan.cell_key("f",c),0.0)) >= 1.0
	vis.line.visible = s.phase == "slab"
	for key in vis.walls: show_wall(s,vis.walls[key])
	for p in vis.posts: show_post(s,p)
	for key in vis.tape:
		var seg: Dictionary = vis.walls[key].seg
		vis.tape[key].visible = s.phase in ["slab","walls"] and SitePlan.rows(b,seg) == 0
	for p in vis.props: show_prop(s,p)

func shown_rows(seg: Dictionary, b: Dictionary) -> int:
	var top = int(seg.rows) if view.wall_mode == 0 else mini(int(seg.rows),SitePlan.LOW_ROWS)
	return mini(SitePlan.rows(b,seg),top)

func final_kind(seg: Dictionary) -> String:
	var full = seg.full and view.wall_mode == 0
	if seg.opening == "door": return "full_door" if full else ""
	if seg.opening == "window": return "full_window" if full else "low_window"
	return "full" if full else "low"

func show_wall(s: Dictionary, v: Dictionary) -> void:
	var b: Dictionary = s.room.build
	var seg: Dictionary = v.seg
	var rows = shown_rows(seg,b)
	var changed = false
	if rows != int(v.rows):
		v.rows = rows
		changed = true
		if rows > 0:
			var info: Dictionary = Art.site["wall:%s:%s:%d" % [seg.axis,seg.kind,rows]]
			v.block.texture = Art.tex(info.file)
			v.block.offset = -Vector2(info.ox,info.oy)
		else: v.block.texture = null
	var f = SitePlan.painted(b,seg)
	var kind = final_kind(seg)
	if f > 0.0 and kind != "":
		if v.kind != kind:
			v.kind = kind
			var variant = posmod(seg.x if seg.axis == "x" else seg.z,int(Art.tiles.get("wall_variants",1)))
			var wkey = "%s:%s:%s" % [Finishes.wall_pattern(s.room),seg.axis,kind]
			var info: Dictionary = Art.tiles.walls.get("%s:%d" % [wkey,variant],Art.tiles.walls[wkey])
			v.paint.texture = Art.tex(info.file)
			v.paint.offset = -Vector2(info.ox,info.oy)
		# painted in vertical strips with the roller, end to end
		var size: Vector2 = v.paint.texture.get_size()
		v.paint.region_rect = Rect2(0,0,ceilf(size.x*f),size.y)
		v.paint.visible = true
	else: v.paint.visible = false
	if changed: view.relink_static(v.entry)

func show_post(s: Dictionary, p: Dictionary) -> void:
	var b: Dictionary = s.room.build
	var rows = 0
	var painted = true
	var full = false
	for seg in p.segs:
		rows = maxi(rows,shown_rows(seg,b))
		painted = painted and (int(seg.rows) == 0 or SitePlan.painted(b,seg) >= 1.0)
		full = full or final_kind(seg).begins_with("full")
	if rows != int(p.rows):
		p.rows = rows
		if rows > 0:
			var info: Dictionary = Art.site["post:%d" % rows]
			p.block.texture = Art.tex(info.file)
			p.block.offset = -Vector2(info.ox,info.oy)
		else: p.block.texture = null
		view.relink_static(p.entry)
	p.paint.visible = painted and rows > 0
	if p.paint.visible and p.paint.texture == null:
		var info: Dictionary = Art.tiles.posts["full" if full else "low"]
		p.paint.texture = Art.tex(info.file)
		p.paint.offset = -Vector2(info.ox,info.oy)

func phase_done(s: Dictionary, ph: String) -> float:
	# How far one phase has gone, 0..1.
	var done = 0.0
	var total = 0.0
	for e in s.els:
		if e.phase != ph: continue
		total += float(e.cost)
		done += SitePlan.fraction(s.room.build,e)*float(e.cost)
	return done/total if total > 0.0 else 1.0

func prop_look(s: Dictionary, name: String) -> String:
	var ph: String = s.phase
	var fin = phase_done(s,"finish") if ph == "finish" else 0.0
	match name:
		"pallet_blocks":
			if ph in ["slab","walls"]: return "pallet_blocks_%d" % clampi(ceili(4.0*(1.0-phase_done(s,"walls"))),1,4)
			return ""
		"mixer":
			if ph in ["slab","walls"]: return "mixer_%d" % (int(clock*7.0) % 4 if ph == "slab" or s.workers.any(func(w): return w.task.get("at","") == "mixer") else 0)
			if ph == "paint": return "paint"
			if ph == "floor": return "parquet_%d" % clampi(ceili(3.0*(1.0-phase_done(s,"floor"))),0,3)
			return "parquet_0" if fin < 0.2 else ""
		"rebar": return "rebar" if ph == "slab" else ""
		"bags": return "bags" if ph in ["slab","walls"] else ""
		"light": return "light" if fin < 0.92 else ""
		"barrow_parked":
			if s.workers.any(func(w): return w.barrow_state >= 0): return ""
			return "barrow_parked" if fin < 0.5 else ""
		"sawhorse": return "sawhorse" if fin < 0.65 else ""
		"bucket": return "bucket" if fin < 0.35 else ""
		"blocks": return "blocks" if fin < 0.8 else ""
	return ""

func show_prop(s: Dictionary, p: Dictionary) -> void:
	var look = prop_look(s,p.prop.name)
	if look == p.shown: return
	var resized = not (look.begins_with("mixer") and String(p.shown).begins_with("mixer"))
	p.shown = look
	p.sprite.visible = look != ""
	for g in p.glows:
		if is_instance_valid(g): g.visible = look != ""
	if look == "": return
	var info: Dictionary = Art.site[look]
	p.sprite.texture = Art.tex(info.file)
	p.sprite.offset = -Vector2(info.ox,info.oy)
	if resized: view.relink_static(p.entry)

func show_slab(s: Dictionary) -> void:
	# Fresh concrete is dark and wet, and dries out over the next minutes.
	if s.get("vis",{}).is_empty(): return
	var b: Dictionary = s.room.build
	for c in s.cells:
		var wet = SitePlan.wetness(b,c)
		vis_mat(s.vis.slab[c],wet_mats[clampi(roundi(wet*4.0),0,4)])

func vis_mat(poly: Polygon2D, mat: Material) -> void:
	if poly.material != mat: poly.material = mat

func animate(s: Dictionary) -> void:
	if s.get("vis",{}).is_empty(): return
	for p in s.vis.props:
		if p.prop.name in ["mixer","barrow_parked"]: show_prop(s,p)

# ------------------------------------------------------------------ the crew

func element_at(s: Dictionary, offset: int, ph: String) -> Dictionary:
	# The element `offset` places after the one in hand, in the same phase.
	var i = int(s.cursor)
	if i >= s.els.size(): return {}
	var found = 0
	var last: Dictionary = {}
	while i < s.els.size() and s.els[i].phase == ph:
		var e: Dictionary = s.els[i]
		if not last.is_empty() and e.has("seg") and last.has("seg") and e.seg.key == last.seg.key and e.phase == "walls":
			i += 1
			continue
		last = e
		if found == offset: return e
		found += 1
		i += 1
	return last if not last.is_empty() else s.els[mini(int(s.cursor),s.els.size()-1)]

func cell_spot(s: Dictionary, c: Vector2i, role: int) -> Dictionary:
	# Stand beside the cell, on ground not yet done, facing it.
	var center = Vector2(c)+Vector2(0.5,0.5)
	var sides = [Vector2(0.62,0),Vector2(0,0.62),Vector2(-0.62,0),Vector2(0,-0.62)]
	if role % 2 == 1: sides = [Vector2(0,0.62),Vector2(0.62,0),Vector2(0,-0.62),Vector2(-0.62,0)]
	for d in sides:
		var p = center+d
		if standable(s,p,0.2): return {"to":p,"face":-d}
	return {"to":free_spot(s,center),"face":Vector2(-1,0)}

func wall_spot(s: Dictionary, seg: Dictionary, along: float = 0.5) -> Dictionary:
	var mid = Vector2(seg.x+along,seg.z) if seg.axis == "x" else Vector2(seg.x,seg.z+along)
	var p = free_spot(s,mid+seg.inward*0.55)
	return {"to":p,"face":-seg.inward}

func prop_spot(s: Dictionary, name: String) -> Dictionary:
	for prop in s.props:
		if prop.name != name: continue
		var to_center = s.rect.get_center()-prop.pos
		var d = Vector2(signf(to_center.x),0) if absf(to_center.x) >= absf(to_center.y) else Vector2(0,signf(to_center.y))
		if d == Vector2.ZERO: d = Vector2(1,0)
		var reach = (prop.rect.size.x if d.x != 0 else prop.rect.size.y)/2.0+0.38
		return {"to":free_spot(s,prop.pos+d*reach),"face":-d,"at":name}
	return {}

func task(spot: Dictionary, anim: String, minutes: float, extra: Dictionary = {}) -> Dictionary:
	if spot.is_empty(): return {}
	var t = {"to":spot.to,"face":spot.face,"anim":anim,"time":minutes,"tool":"hivis","at":spot.get("at","")}
	t.merge(extra,true)
	return t

func plan(s: Dictionary, w: SiteWorker) -> Array:
	var rng = randf_range(0.8,1.25)
	var e: Dictionary = s.els[mini(int(s.cursor),s.els.size()-1)]
	var out: Array = []
	match String(s.phase):
		"slab":
			match w.role:
				0:
					if randf() < 0.3 and not prop_spot(s,"bags").is_empty():
						out.append(task(prop_spot(s,"bags"),"work",0.8,{"then_hold":"bag"}))
						out.append(task(prop_spot(s,"mixer"),"work",0.8,{"then_hold":""}))
					else: out.append(task(prop_spot(s,"mixer"),"mop",5.0*rng))
				1:
					out.append(task(prop_spot(s,"mixer"),"idle",1.4,{"barrow":0,"then_barrow":1}))
					var c = element_at(s,2,"slab")
					out.append(task(cell_spot(s,c.get("cell",e.cell),1),"work",0.9,{"barrow":1,"then_barrow":0}))
				_:
					out.append(task(cell_spot(s,e.cell,2),"mop",2.5*rng))
		"walls":
			var seg: Dictionary = e.seg
			match w.role:
				0:
					var ahead = element_at(s,1,"walls")
					out.append(task(prop_spot(s,"pallet_blocks"),"work",0.6,{"then_hold":"block"}))
					out.append(task(wall_spot(s,ahead.get("seg",seg),0.3),"work",0.5,{"hold":"block","then_hold":""}))
				1:
					out.append(task(wall_spot(s,seg),"work",2.5*rng))
				_:
					if w.brain.get("mortar",false) and not prop_spot(s,"mixer").is_empty():
						out.append(task(prop_spot(s,"mixer"),"mop",2.5*rng))
					else:
						var far = element_at(s,maxi(s.segs.size()/2,2),"walls")
						out.append(task(wall_spot(s,far.get("seg",seg),0.7),"work",2.5*rng))
					w.brain.mortar = not w.brain.get("mortar",false)
		"paint":
			var seg: Dictionary = e.seg
			match w.role:
				0: out.append(task(wall_spot(s,seg),"work",2.0*rng,{"tool":"hivis_roller"}))
				1:
					var nxt = element_at(s,1,"paint")
					out.append(task(wall_spot(s,nxt.get("seg",seg),0.4),"work",2.0*rng,{"tool":"hivis_roller"}))
				_:
					out.append(task(prop_spot(s,"mixer"),"work",0.8,{"then_hold":"bucket"}))
					out.append(task(wall_spot(s,seg,0.9),"idle",0.6,{"hold":"bucket","then_hold":""}))
		"floor":
			match w.role:
				0: out.append(task(cell_spot(s,e.cell,0),"kneel",1.5*rng,{"board":true}))
				1:
					var c = element_at(s,2,"floor")
					out.append(task(cell_spot(s,c.get("cell",e.cell),1),"kneel",1.5*rng,{"board":true}))
				_:
					if randf() < 0.35 and not prop_spot(s,"sawhorse").is_empty():
						out.append(task(prop_spot(s,"sawhorse"),"work",2.0*rng))
					else:
						var c = element_at(s,4,"floor")
						out.append(task(prop_spot(s,"mixer"),"work",0.7,{"then_hold":"planks"}))
						out.append(task(cell_spot(s,c.get("cell",e.cell),2),"work",0.5,{"hold":"planks","then_hold":""}))
		"finish":
			# carry the equipment out, towards the front of the site
			var left: Array = s.vis.get("props",[]).filter(func(p): return p.shown != "")
			var exit_to = {"to":free_spot(s,Vector2(s.rect.get_center().x+(w.role-1)*0.8,s.rect.end.y-0.35)),"face":Vector2(0,1)}
			if left.is_empty(): out.append(task(exit_to,"idle",2.0))
			else:
				var p: Dictionary = left[(w.role+int(clock)) % left.size()]
				out.append(task(prop_spot(s,p.prop.name),"work",0.8,{"then_hold":["bag","block","planks"][w.role]}))
				out.append(task(exit_to,"idle",0.5,{"hold":["bag","block","planks"][w.role],"then_hold":""}))
	return out.filter(func(t): return not t.is_empty())

func run_worker(s: Dictionary, w: SiteWorker, delta: float, minutes: float) -> void:
	if not w.path.is_empty():
		if delta > 0.0 and w.step(delta,sim.speed): arrive(w)
		return
	if not w.task.is_empty():
		w.wait -= minutes
		if w.wait > 0.0: return
		if w.task.has("then_hold"): w.hold(w.task.then_hold)
		if w.task.has("then_barrow"): w.push(int(w.task.then_barrow))
		w.task = {}
	if minutes <= 0.0: return
	if w.tasks.is_empty(): w.tasks = plan(s,w)
	if w.tasks.is_empty():
		w.play("idle")
		return
	var t: Dictionary = w.tasks.pop_front()
	w.task = t
	w.lay_board(false)
	# hands are free unless the task says what they carry
	w.hold(t.get("hold",""))
	w.push(int(t.get("barrow",-1)))
	t.to = spread(s,w,t.to)
	w.path = site_path(s,w.world,t.to)
	if w.world.distance_to(t.to) < 0.05:
		w.path = []
		arrive(w)

func spot_taken(s: Dictionary, w: SiteWorker, q: Vector2) -> bool:
	for o in s.workers:
		if o == w or not is_instance_valid(o): continue
		var there: Vector2 = o.task.get("to",o.world) if not o.task.is_empty() else o.world
		if q.distance_to(there) < 0.6: return true
	return false

func spread(s: Dictionary, w: SiteWorker, p: Vector2) -> Vector2:
	# Two workers never stand on the same spot: the second one steps aside.
	if not spot_taken(s,w,p): return p
	for d in [Vector2(0.65,0),Vector2(0,0.65),Vector2(-0.65,0),Vector2(0,-0.65),Vector2(0.65,0.65),Vector2(-0.65,0.65),Vector2(0.65,-0.65),Vector2(-0.65,-0.65)]:
		var q = p+d
		if standable(s,q,0.25) and not spot_taken(s,w,q): return q
	return p

func arrive(w: SiteWorker) -> void:
	var t: Dictionary = w.task
	if t.is_empty(): return
	w.face(t.face)
	w.use_tool(t.get("tool","hivis"))
	w.play(t.anim)
	w.lay_board(t.get("board",false))
	w.wait = float(t.time)
