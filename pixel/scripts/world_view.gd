class_name WorldView
extends Node2D

# Draws the building from pre-rendered pixel art. Everything lives in native
# pixels (1 m = 32 x 16 px); the parent viewport is scaled by an integer.

const ACCENT = Color("ff7fb2")
const HOVER = Color("ffd0e4")
var model: BuildingModel
var ground: Node2D
var floors: Node2D
var floor_fx: Node2D
var sorted: Node2D
var overlay: Node2D
var grid: Node2D
var statics: Array = []
var item_entries: Dictionary = {}
var doors: Array = []
var actors: Array = []
var wall_mode = 0
var selected_item = -1
var hovered_item = -1
var selected_edge = ""
var preview_node: Node2D
var room_outline: Line2D
var edge_marker: Line2D
var handles_node: Node2D
var street_doors: Array = []
var bounds = Rect2(-8,-6,18,17)
var dirt_layer: Node2D
var club_open = false
var signs: Array = []
var animated: Array = []       # looping props (sprite sheets with several frames)
var bed_looks: Dictionary = {}  # bed id -> {fps, frame, clothes} while a couple is under the covers
var clothes: Dictionary = {}    # bed id -> clothes sprite dropped by the bed
var puffs: Array = []           # floating bubbles above rooms (hearts, steam)
var anim_items: Array = []      # objects with a loop of pictures (dance floor, lit palm)
var clock = 0.0

func setup(building: BuildingModel) -> void:
	model = building
	for n in ["ground","floors","floor_fx","dirt_layer","sorted","overlay"]:
		var node = Node2D.new()
		node.name = n
		add_child(node)
		set(n,node)
	ground.z_index = -300
	floors.z_index = -250
	floor_fx.z_index = -200
	dirt_layer.z_index = -190
	sorted.z_index = 0
	overlay.z_index = 4000
	grid = GridLines.new()
	grid.z_index = -180
	grid.visible = false
	add_child(grid)
	room_outline = Line2D.new()
	room_outline.width = 1
	room_outline.antialiased = false
	room_outline.default_color = ACCENT
	room_outline.closed = true
	room_outline.visible = false
	overlay.add_child(room_outline)
	edge_marker = Line2D.new()
	edge_marker.width = 2
	edge_marker.antialiased = false
	edge_marker.default_color = ACCENT
	edge_marker.visible = false
	overlay.add_child(edge_marker)
	handles_node = Node2D.new()
	overlay.add_child(handles_node)
	rebuild()

# ------------------------------------------------------------------ build

func clear_node(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()

func rebuild() -> void:
	for outline in outline_sprites.values():
		if is_instance_valid(outline): outline.queue_free()
	outline_sprites.clear()
	# Characters survive a rebuild: only the building is redrawn.
	for a in actors:
		if is_instance_valid(a) and a.get_parent() == sorted: sorted.remove_child(a)
	for n in [ground,floors,floor_fx,sorted]: clear_node(n)
	statics.clear()
	item_entries.clear()
	doors.clear()
	street_doors.clear()
	signs.clear()
	animated.clear()
	anim_items.clear()
	compute_bounds()
	build_ground()
	for room in model.rooms: build_floor(room)
	build_walls()
	for item in model.furniture:
		if Catalog.is_character(item.kind): continue
		build_item(item)
	street_blocked.clear()
	parking_layouts.clear()
	for pk in model.parkings: build_parking(pk)
	build_street()
	build_exterior()
	for a in actors:
		if is_instance_valid(a) and a.get_parent() != sorted: sorted.add_child(a)
	prepare_depth()
	selection(selected_item)

func compute_bounds() -> void:
	if model.rooms.is_empty():
		bounds = Rect2(-6,-6,12,12)
		return
	var r: Rect2 = model.rect(model.rooms[0])
	for room in model.rooms: r = r.merge(model.rect(room))
	bounds = r

func textured_polygon(points: PackedVector2Array, tex: Texture2D, palette: Texture2D = null) -> Polygon2D:
	var poly = Polygon2D.new()
	poly.polygon = points
	poly.texture = tex
	poly.uv = points
	poly.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	poly.material = Art.material(palette,40.0,8.0) if palette != null else Art.rgba_material()
	return poly

func build_ground() -> void:
	var L = Iso.LOT
	var tex = Art.tex(Art.tiles.floors.pavers)
	ground.add_child(textured_polygon(Iso.diamond(-L,-L,L,L),tex,Palette.floor_palette(Color("23243a"))))
	# The street runs along the front of the lot, whatever is built: slab
	# sidewalks either side of a two-lane road of old cracked asphalt.
	var slabs = Art.tex(Art.tiles.floors.slabs)
	for band in [Street.WALK_NEAR,Street.WALK_FAR]:
		ground.add_child(textured_polygon(Iso.diamond(-L,band.x,L,band.y),slabs,Palette.floor_palette(WALK_COLOR)))
	ground.add_child(textured_polygon(Iso.diamond(-L,Street.ROAD.x,L,Street.ROAD.y),Art.tex(Art.tiles.floors.asphalt_cracked),Palette.floor_palette(ROAD_COLOR)))

func build_floor(room: Dictionary) -> void:
	var tex = Art.tex(Art.tiles.floors[Finishes.floor_pattern(room)])
	var poly = textured_polygon(Iso.diamond(room.x,room.z,room.x+room.w,room.z+room.h),tex,Palette.floor_palette(Color(room.floor_color)))
	floors.add_child(poly)

func room_side(axis: String, x: int, z: int, positive: bool) -> Dictionary:
	if axis == "x": return model.room_at(Vector2(x+0.5,z+(0.5 if positive else -0.5)))
	return model.room_at(Vector2(x+(0.5 if positive else -0.5),z+0.5))

func add_static(node: Node2D, rect: Rect2, kind: String, data: Dictionary = {}) -> Dictionary:
	sorted.add_child(node)
	var entry = {"node":node,"rect":rect,"kind":kind,"rank":0,"extra":[]}
	entry.merge(data)
	statics.append(entry)
	return entry

func sprite(tex: Texture2D, pos: Vector2, offset: Vector2, mat: Material = null) -> Sprite2D:
	var s = Sprite2D.new()
	s.texture = tex
	s.centered = false
	s.position = pos
	s.offset = -offset
	if mat != null: s.material = mat
	return s

func build_walls() -> void:
	var walls: Dictionary = model.edges()
	var segs: Dictionary = {}
	for key in walls:
		var e: Dictionary = walls[key]
		var axis: String = e.axis
		var x: int = e.x
		var z: int = e.z
		var front_room = room_side(axis,x,z,true)
		var back_room = room_side(axis,x,z,false)
		# Back walls stand full height, front walls are cut away. A wall between
		# two public spaces (lounge and corridor) stays low so the bar stays in view.
		var full = not front_room.is_empty() and wall_mode == 0
		if full and not back_room.is_empty() and int(front_room.type) == 0 and int(back_room.type) == 0: full = false
		var owner = front_room if not front_room.is_empty() else back_room
		var opening: String = model.openings.get(key,"")
		var kind = "full" if full else "low"
		if opening == "door": kind = "full_door" if full else ""
		elif opening == "window": kind = "full_window" if full else "low_window"
		segs[key] = {"axis":axis,"x":x,"z":z,"full":full,"kind":kind,"owner":owner,"opening":opening}
		var rect = Rect2(x,z,1,0) if axis == "x" else Rect2(x,z,0,1)
		var pos = Iso.pixel(x,z)
		var node = Node2D.new()
		var entry = add_static(node,rect,"wall",{"key":key})
		if kind != "":
			# Variants follow the position so the pattern runs on along a wall.
			var variant = posmod(x if axis == "x" else z,int(Art.tiles.get("wall_variants",1)))
			var wkey = "%s:%s:%s" % [Finishes.wall_pattern(owner),axis,kind]
			var info: Dictionary = Art.tiles.walls.get("%s:%d" % [wkey,variant],Art.tiles.walls[wkey])
			var s = sprite(Art.tex(info.file),pos,Vector2(info.ox,info.oy),Art.material(Palette.wall_palette(Color(owner.wall_color))))
			node.add_child(s)
			entry.sprite = s
			entry.file = info.file
		if opening != "":
			var okey = ""
			if opening == "door" and full: okey = "door:"+axis
			elif opening == "window": okey = ("window:" if full else "window_low:")+axis
			if okey != "":
				var info: Dictionary = Art.tiles.openings[okey]
				var s = sprite(Art.tex(info.file),pos,Vector2(info.ox,info.oy),Art.rgba_material())
				node.add_child(s)
				if opening == "door":
					var open_info: Dictionary = Art.tiles.openings["door_open:"+axis]
					var center = Vector2(x+0.5,z) if axis == "x" else Vector2(x,z+0.5)
					doors.append({"sprite":s,"closed":Art.tex(info.file),"open":Art.tex(open_info.file),"center":center,"key":key})
			if opening == "door" and (front_room.is_empty() or back_room.is_empty()):
				street_doors.append({"key":key,"axis":axis,"x":x,"z":z,"outside_positive":front_room.is_empty(),"room":owner})
	# Posts close corners, wall ends and door gaps.
	var points: Dictionary = {}
	for key in segs:
		var s: Dictionary = segs[key]
		var a = Vector2i(s.x,s.z)
		var b = a+(Vector2i(1,0) if s.axis == "x" else Vector2i(0,1))
		for p in [a,b]:
			if not points.has(p): points[p] = []
			points[p].append(s)
	for p in points:
		var list: Array = points[p]
		var need = list.size() != 2 or list[0].axis != list[1].axis
		var any_full = false
		var any_gap = false
		for s in list:
			any_full = any_full or (s.full and s.kind != "")
			any_gap = any_gap or s.kind == "" or s.kind.ends_with("door")
		if any_gap: need = true
		if list.size() == 2 and list[0].axis == list[1].axis and list[0].full != list[1].full: need = true
		if not need: continue
		var post_kind = "full" if any_full else "low"
		var owner: Dictionary = list[0].owner
		for s in list:
			if s.full: owner = s.owner
		var info: Dictionary = Art.tiles.posts[post_kind]
		var node = sprite(Art.tex(info.file),Iso.pixel(p.x,p.y),Vector2(info.ox,info.oy),Art.material(Palette.wall_palette(Color(owner.wall_color))))
		var entry = add_static(node,Rect2(p.x,p.y,0,0),"post")
		entry.sprite = node
		entry.file = info.file

func item_variant(item: Dictionary) -> String:
	# The picture an item shows right now: a bed in use or unmade, a shower door ajar.
	if item.kind in ["bed","old_bed"]: return bed_variant(item)
	if item.kind == "shower":
		var frame = int(shower_doors.get(int(item.id),{}).get("shown",0))
		if frame > 0: return "shower_f%d" % frame
	return item.kind

func apply_look(entry: Dictionary, info: Dictionary, item: Dictionary, nudge: Vector2 = Vector2.ZERO) -> void:
	# Swap the picture of an item, part by part; parts whose floor rectangle
	# moved are ordered again.
	var list: Array = entry.get("parts",[entry])
	var parts: Array = info.get("parts",[])
	var pos = Iso.pixel(item.x,item.z)+nudge
	for k in range(list.size()):
		var e: Dictionary = list[k]
		var src: Dictionary = parts[k] if k < parts.size() else info
		var s: Sprite2D = e.sprite
		s.texture = Art.tex(src.file)
		s.offset = -Vector2(src.ox,src.oy)
		s.position = pos
		e.file = src.file
		if k == 0 and outline_sprites.has(int(item.id)) and is_instance_valid(outline_sprites[int(item.id)]):
			var o: Sprite2D = outline_sprites[int(item.id)]
			o.texture = Art.tex(info.file)
			o.offset = -Vector2(info.ox,info.oy)
			o.position = pos
		if src.has("rect"):
			var rc: Array = src.rect
			var r = Rect2(item.x+float(rc[0]),item.z+float(rc[1]),float(rc[2])-float(rc[0]),float(rc[3])-float(rc[1]))
			if r != e.rect:
				e.rect = r
				relink_static(e)

func bed_variant(item: Dictionary) -> String:
	# Beds show who is in them and whether they were made again.
	if bed_looks.has(int(item.id)):
		var frame = int(bed_looks[int(item.id)].get("frame",0))
		var busy = "%s_busy" % item.kind if frame == 0 else "%s_busy_%d" % [item.kind,frame]
		if Art.furniture.has(busy): return busy
	if item.get("unmade",false) and Art.furniture.has("%s_unmade" % item.kind): return "%s_unmade" % item.kind
	return item.kind

func set_bed_look(id: int, look: String, fps: float = 0.0) -> void:
	# "busy": the lumps under the covers heave at `fps` frames a second (0 = still)
	if look == "busy":
		var old: Dictionary = bed_looks.get(id,{})
		bed_looks[id] = {"fps":fps,"frame":int(old.get("frame",0)),"clothes":old.get("clothes",false)}
	else:
		bed_looks.erase(id)
		show_clothes(id,false)
	refresh_bed(id)

func refresh_bed(id: int) -> void:
	var item = model.item_by_id(id)
	var entry: Dictionary = item_entries.get(id,{})
	if item.is_empty() or entry.is_empty(): return
	var info = Art.furniture_entry(bed_variant(item),int(item.rot))
	if info.is_empty(): return
	var look: Dictionary = bed_looks.get(id,{})
	# the bed shakes when the rhythm is fast
	var shake = 1 if float(look.get("fps",0.0)) >= 6.0 and int(look.get("frame",0)) % 2 == 1 else 0
	apply_look(entry,info,item,Vector2(shake,0))

var shower_doors: Dictionary = {}  # shower id -> {open, frame, shown, close_in}

func set_shower_door(id: int, open: bool, close_after: float = -1.0, at_once: bool = false) -> void:
	# The glass door swings open (or shut) over a few frames; close_after shuts
	# it again by itself, at_once throws it wide open (someone called away
	# from the shower in a hurry).
	var d: Dictionary = shower_doors.get(id,{"frame":0.0,"shown":0})
	d.open = open
	d.close_in = close_after
	if at_once and open: d.frame = 3.0
	shower_doors[id] = d
	if at_once: step_shower_doors(0.0)

func shower_door_open(id: int) -> bool:
	return int(shower_doors.get(id,{}).get("shown",0)) >= 3

func shower_door_shut(id: int) -> bool:
	return int(shower_doors.get(id,{}).get("shown",0)) == 0

func step_shower_doors(delta: float) -> void:
	for id in shower_doors.keys():
		var d: Dictionary = shower_doors[id]
		if float(d.get("close_in",-1.0)) >= 0.0 and d.open and int(d.shown) >= 3:
			d.close_in = float(d.close_in)-delta
			if d.close_in < 0.0: d.open = false
		d.frame = clampf(float(d.frame)+(1.0 if d.open else -1.0)*delta*9.0,0.0,3.0)
		var shown = int(floor(float(d.frame)+0.001)) if d.open else int(ceil(float(d.frame)-0.001))
		if shown != int(d.shown):
			d.shown = shown
			var item = model.item_by_id(id)
			var entry: Dictionary = item_entries.get(id,{})
			if item.is_empty() or entry.is_empty():
				shower_doors.erase(id)
				continue
			var info = Art.furniture_entry(item_variant(item),int(item.rot))
			if not info.is_empty(): apply_look(entry,info,item)
		if not d.open and int(d.shown) == 0: shower_doors.erase(id)

var clothes_at: Dictionary = {}   # bed id -> floor point chosen by the simulation

func show_clothes(id: int, visible_now: bool, at_point: Vector2 = Vector2.INF) -> void:
	# Clothes dropped on the floor beside the bed while the couple is busy.
	if clothes.has(id):
		if is_instance_valid(clothes[id]): clothes[id].queue_free()
		clothes.erase(id)
	if bed_looks.has(id): bed_looks[id].clothes = visible_now
	if not visible_now:
		clothes_at.erase(id)
		return
	if at_point != Vector2.INF: clothes_at[id] = at_point
	var item = model.item_by_id(id)
	var info = Art.furniture_entry("clothes_pile",int(item.get("rot",0)))
	if item.is_empty() or info.is_empty(): return
	# on the floor of the bedroom, beside or at the foot of the bed
	var size: Vector2 = Catalog.ITEMS[item.kind].size
	var room = model.room_at(Vector2(item.x,item.z))
	var at = Catalog.local_to_world(item,Vector2(size.x/2.0+0.45,0.5))
	if not room.is_empty():
		var inner = model.rect(room).grow(-0.35)
		for local in [Vector2(size.x/2.0+0.45,0.5),Vector2(-size.x/2.0-0.45,0.5),Vector2(0.3,size.y/2.0+0.4),Vector2(-0.4,size.y/2.0+0.4)]:
			var p = Catalog.local_to_world(item,local)
			if inner.has_point(p):
				at = p
				break
	if clothes_at.has(id): at = clothes_at[id]
	var s = sprite(Art.tex(info.file),Iso.pixel(at.x,at.y),Vector2(info.ox,info.oy),Art.rgba_material())
	floor_fx.add_child(s)
	clothes[id] = s

func puff(at: Vector2, icon: String, seconds: float) -> void:
	# A bubble rising from a spot where the characters are out of sight.
	var tex = Art.ui_texture("emotes",icon)
	if tex == null: return
	var s = Sprite2D.new()
	s.texture = tex
	s.position = Iso.pixel(at.x,at.y)+Vector2(0,-40)
	overlay.add_child(s)
	puffs.append({"sprite":s,"time":seconds,"start":s.position})

func build_item(item: Dictionary) -> void:
	var info = Art.furniture_entry(item_variant(item),int(item.rot))
	if bed_looks.get(int(item.id),{}).get("clothes",false): show_clothes.call_deferred(int(item.id),true)
	if info.is_empty(): return
	var pos = Iso.pixel(item.x,item.z)
	var entry: Dictionary
	var parts: Array = info.get("parts",[])
	if Catalog.ITEMS[item.kind].get("flat",false):
		var s = sprite(Art.tex(info.file),pos,Vector2(info.ox,info.oy),Art.rgba_material())
		floor_fx.add_child(s)
		entry = {"node":s,"rect":model.item_rect(item),"kind":"item","rank":-1,"extra":[],"flat":true,"sprite":s,"file":info.file}
	elif parts.is_empty():
		var s = sprite(Art.tex(info.file),pos,Vector2(info.ox,info.oy),Art.rgba_material())
		entry = add_static(s,model.item_rect(item),"item",{"sprite":s,"file":info.file})
	else:
		# seat and backrest, bed and headboard, stage and pole, shower tiles and glass:
		# each part is sorted on its own floor rectangle
		var list: Array = []
		for k in range(parts.size()):
			var pi: Dictionary = parts[k]
			var rc: Array = pi.rect
			var ps = sprite(Art.tex(pi.file),pos,Vector2(pi.ox,pi.oy),Art.rgba_material())
			var r = Rect2(item.x+float(rc[0]),item.z+float(rc[1]),float(rc[2])-float(rc[0]),float(rc[3])-float(rc[1]))
			list.append(add_static(ps,r,"item",{"sprite":ps,"file":pi.file,"part":pi.name,"id":int(item.id),"separate":info.get("split","") == "separate"}))
		entry = list[0]
		entry.parts = list
	entry.id = int(item.id)
	item_entries[int(item.id)] = entry
	if item.get("delivery_pending",false):
		for part in entry.get("parts",[entry]):
			part.node.modulate = Color(1.0,1.0,1.0,.48)
			part.sprite.material.set_shader_parameter("tint",Color(.55,.8,1.0,.55))
		return # no working light or furniture animation before unpacking
	var glows: Array = []
	for light in info.get("lights",[]):
		glows.append_array(add_glow(entry,pos+Vector2(light.x,light.y),Color(light.color),float(light.radius),float(light.power)))
	var anim: Dictionary = Catalog.ITEMS[item.kind].get("anim",{})
	if not anim.is_empty():
		anim_items.append({"id":int(item.id),"entry":entry,"frames":int(anim.frames),"fps":float(anim.fps),"frame":-1,"glows":glows,
			"phase":float(posmod(int(item.id)*7,int(anim.frames)))})

func add_glow(entry: Dictionary, at: Vector2, color: Color, radius_m: float, power: float) -> Array:
	var r = radius_m*18.0
	var best = 12
	for size in [12,20,28,40,56,72]:
		if absf(size-r) < absf(best-r): best = size
	var g = Sprite2D.new()
	g.texture = Art.tex(Art.tiles.glows["glow_%d" % best])
	g.material = Art.add_material
	g.modulate = Color(color.r,color.g,color.b,clampf(power,0.0,1.4))
	if entry.get("flat",false):
		g.position = at.round()
		floor_fx.add_child(g)
	else:
		g.position = (at-entry.node.position).round()
		entry.node.add_child(g)
		g.z_as_relative = true
		g.z_index = 1
	# A soft pool of light on the floor below.
	var f = Sprite2D.new()
	var fr = mini(best+16,72)
	var fkey = "glow_%d_floor" % fr
	if not Art.tiles.glows.has(fkey): fkey = "glow_72_floor"
	f.texture = Art.tex(Art.tiles.glows[fkey])
	f.material = Art.add_material
	f.modulate = Color(color.r,color.g,color.b,clampf(power*0.55,0.0,1.0))
	var foot = entry.node.position if entry.node is Sprite2D else at
	f.position = foot.round()
	floor_fx.add_child(f)
	return [g,f]

func build_exterior() -> void:
	var b = bounds
	var props: Array = []
	# Street lamps and trees stand on the sidewalks, never in the screen
	# column of a room (the tall posts would hide it), never on a driveway.
	var cmin = INF
	var cmax = -INF
	for r in model.rooms:
		cmin = minf(cmin,r.x-(r.z+r.h))
		cmax = maxf(cmax,r.x+r.w-r.z)
	var clear = func(px: float, pz: float) -> bool: return px-pz < cmin-0.8 or px-pz > cmax+0.8
	var L = Iso.LOT
	var x = -L+3.0
	while x < L-2.0:
		if clear.call(x,Street.WALK_FAR.x+0.7): props.append(["street_lamp",x,Street.WALK_FAR.x+0.7])
		if clear.call(x+5.0,Street.WALK_FAR.x+1.5) and x+5.0 < L-2.0: props.append(["tree",x+5.0,Street.WALK_FAR.x+1.5])
		x += 10.0
	x = -L+7.0
	while x < L-2.0:
		if clear.call(x,Street.WALK_NEAR.y-0.45): props.append(["street_lamp",x,Street.WALK_NEAR.y-0.45])
		x += 12.0
	# lamps light the car parks from the sidewalk, at their corners
	for pk in model.parkings:
		if not is_equal_approx(float(pk.z+pk.h),Street.LOT_FRONT): continue
		for px in [pk.x+0.6,pk.x+pk.w-0.6]:
			if clear.call(px,Street.WALK_NEAR.y-0.45): props.append(["street_lamp",px,Street.WALK_NEAR.y-0.45])
	props.append(["tree",b.position.x-3.0,b.end.y-1.0])
	props.append(["tree",b.end.x-1.0,b.position.y-3.0])
	props.append(["tree",b.position.x-2.5,b.position.y+2.0])
	var bx = b.position.x+3.5
	while bx < b.end.x:
		props.append(["bollard",bx,b.end.y+0.6])
		bx += 2.0
	for d in street_doors:
		var out = Vector2(d.x+0.5,d.z+1.2) if d.axis == "x" else Vector2(d.x+1.2,d.z+0.5)
		if not d.outside_positive: out = Vector2(d.x+0.5,d.z-1.2) if d.axis == "x" else Vector2(d.x-1.2,d.z+0.5)
		var side = Vector2(1,0) if d.axis == "x" else Vector2(0,1)
		var away = (out-Vector2(d.x+0.5,d.z)).normalized() if d.axis == "x" else (out-Vector2(d.x,d.z+0.5)).normalized()
		# an old red carpet at the door, the club sign beside it, dumpsters further on
		var carpet = Art.furniture_entry("rug",0 if d.axis == "x" else 1)
		var cs = sprite(Art.tex(carpet.file),Iso.pixel(out.x,out.y+(0.4 if d.axis == "x" else 0.0)),Vector2(carpet.ox,carpet.oy),Art.rgba_material())
		ground.add_child(cs)
		var sp = out+side*2.4+away*0.2
		if not off_limits(sp,0.9):
			var on: Dictionary = Art.tiles.props.sign_on
			var off: Dictionary = Art.tiles.props.sign_off
			var ss = sprite(Art.tex(on.file if club_open else off.file),Iso.pixel(sp.x,sp.y),Vector2(on.ox,on.oy),Art.rgba_material())
			var sentry = add_static(ss,Rect2(sp.x-0.9,sp.y-0.1,1.8,0.2) if d.axis == "x" else Rect2(sp.x-0.1,sp.y-0.9,0.2,1.8),"prop")
			var glows: Array = []
			for light in on.get("lights",[]):
				glows.append_array(add_glow(sentry,ss.position+Vector2(light.x,light.y),Color(light.color),float(light.radius),float(light.power)))
			for g in glows: g.visible = club_open
			signs.append({"sprite":ss,"on":Art.tex(on.file),"off":Art.tex(off.file),"glows":glows})
		# the bins stand a little aside: the entrance line runs along the facade on this side
		props.append(["dumpster",out.x-side.x*3.6+away.x*0.2,out.y-side.y*3.6+away.y*0.2])
		props.append(["dumpster",out.x-side.x*5.2+away.x*0.2,out.y-side.y*5.2+away.y*0.2])
		props.append(["bush",out.x+side.x*3.6,out.y+side.y*3.6])
	for p in props:
		if model.room_at(Vector2(p[1],p[2])) != {}: continue
		if absf(p[1]) > Iso.LOT-1 or absf(p[2]) > Iso.LOT-1: continue
		var size = {"tree":1.2,"dumpster":1.3}.get(p[0],0.4)
		if off_limits(Vector2(p[1],p[2]),size/2.0+0.2,p[0] in ["street_lamp","tree"]): continue
		var info: Dictionary = Art.tiles.props[p[0]]
		var key = int(round(p[1]*7.0+p[2]*13.0))
		if p[0] == "tree" and Art.tiles.props.has("tree_%d" % posmod(key,3)): info = Art.tiles.props["tree_%d" % posmod(key,3)]
		var s = sprite(Art.tex(info.file),Iso.pixel(p[1],p[2]),Vector2(info.ox,info.oy),Art.rgba_material())
		if info.has("pit"):
			ground.add_child(sprite(Art.tex(info.pit.file),Iso.pixel(p[1],p[2]),Vector2(info.pit.ox,info.pit.oy),Art.rgba_material()))
		if int(info.get("frames",1)) > 1:
			# each animated prop runs on its own beat
			s.hframes = int(info.frames)
			animated.append({"sprite":s,"frames":int(info.frames),"fps":float(info.fps)*(0.85+posmod(key,5)*0.07),"phase":float(posmod(key*3,int(info.frames)))})
		var entry = add_static(s,Rect2(p[1]-size/2,p[2]-size/2,size,size),"prop")
		for light in info.get("lights",[]):
			add_glow(entry,s.position+Vector2(light.x,light.y),Color(light.color),float(light.radius),float(light.power))

func off_limits(p: Vector2, radius: float, on_sidewalk: bool = false) -> bool:
	# Kept clear of props: the roadway, the car parks and their driveways;
	# only lamps and trees may stand on the sidewalks.
	var box = Rect2(p-Vector2(radius,radius),Vector2(radius,radius)*2)
	if box.end.y > Street.ROAD.x and box.position.y < Street.ROAD.y: return true
	if not on_sidewalk and box.end.y > Street.WALK_NEAR.x and box.position.y < Street.WALK_FAR.y: return true
	for r in street_blocked:
		if box.intersects(r): return true
	return false

# ------------------------------------------------------------------ street and car parks

const WALK_COLOR = Color("4a4960")
const ROAD_COLOR = Color("2d2c38")
var street_blocked: Array = []   # car parks and their driveways (no props there)
var decal_mat: ShaderMaterial
var parking_layouts: Dictionary = {}   # car park id -> Street layout

func decal(name: String, x: float, z: float, parent: Node = null) -> Sprite2D:
	# A flat or low street sprite (paint, kerb, stain, weed) on the ground.
	var info: Dictionary = Art.tiles.street.get(name,{})
	if info.is_empty(): return null
	if decal_mat == null: decal_mat = Art.rgba_material()
	var s = sprite(Art.tex(info.file),Iso.pixel(x,z),Vector2(info.ox,info.oy),decal_mat)
	(floor_fx if parent == null else parent).add_child(s)
	return s

static func mix_hash(a: float, b: float, seed: int) -> float:
	var v = int(floor(a*7.13)*73856093) ^ int(floor(b*5.71)*19349663) ^ (seed*83492791)
	v = (v ^ (v >> 13))*1274126177
	return float(posmod(v ^ (v >> 16),10007))/10007.0

func build_street() -> void:
	# The street along the front of the lot: kerbs (lowered where a driveway
	# crosses), worn lane markings, drains, weeds along the kerbs, cracks.
	var aprons: Array = []
	for pk in model.parkings:
		var lay = parking_layouts.get(int(pk.id),{})
		if lay.get("ok",false): aprons.append_array(Street.aprons(lay))
	var L = int(Iso.LOT)
	var crossing = func(x: float) -> bool:
		for a in aprons:
			if x >= a.position.x-0.01 and x <= a.end.x+0.01: return true
		return false
	for x in range(-L,L):
		var cx = x+0.5
		var across = crossing.call(cx)
		decal("edge_x_%d" % posmod(x,3),x,Street.ROAD.y-0.35)
		if not across: decal("edge_x_%d" % posmod(x*7,3),x,Street.ROAD.x+0.35)
		if posmod(x+L,6) == 0: decal("dash_x_%d" % posmod(x,3),x,(Street.ROAD.x+Street.ROAD.y)/2.0)
		if not across and posmod(x+L,11) == 4: decal("drain",cx,Street.ROAD.x+0.4)
		if mix_hash(x,1,3) > 0.93: decal("crack_%d" % posmod(x,4),cx,Street.ROAD.x+1.0+mix_hash(x,2,5)*5.0)
	for x in range(-L,L):
		var across = crossing.call(x+0.5)
		decal("kerb_low_x" if across else "kerb_x_%d" % (2+posmod(x,2) if mix_hash(x,3,7) > 0.72 else posmod(x,2)),x,Street.ROAD.x)
		decal("kerb_x_%d" % (2+posmod(x,2) if mix_hash(x,4,9) > 0.75 else posmod(x,2)),x,Street.ROAD.y)
		# tufts along the kerbs, on the sidewalk side
		if not across and mix_hash(x,5,11) > 0.6: decal("weed_%d" % posmod(x,6),x+mix_hash(x,6,1),Street.ROAD.x-0.12)
		if mix_hash(x,7,13) > 0.62: decal("weed_%d" % posmod(x+3,6),x+mix_hash(x,8,1),Street.ROAD.y+0.14)

	# Adjacent crossings form a single opening and share one parking sign.
	aprons.sort_custom(func(a,b): return a.position.x < b.position.x)
	var entrances: Array = []
	for apron in aprons:
		if not entrances.is_empty() and apron.position.x <= entrances[-1].end.x+0.01:
			entrances[-1] = entrances[-1].merge(apron)
		else: entrances.append(apron)
	for entrance in entrances:
		var sp = Vector2(entrance.position.x-0.35,Street.WALK_NEAR.x+0.45)
		if sp.x < -Iso.LOT+0.2: sp.x = entrance.end.x+0.35
		if sp.x > Iso.LOT-0.2: continue
		var info: Dictionary = Art.tiles.street.sign_parking
		var ss = sprite(Art.tex(info.file),Iso.pixel(sp.x,sp.y),Vector2(info.ox,info.oy),Art.rgba_material())
		add_static(ss,Rect2(sp.x-0.15,sp.y-0.15,0.3,0.3),"prop")

func build_parking(pk: Dictionary) -> void:
	# Cracked asphalt, the driveway through the sidewalk, worn white bay
	# lines, a wheel stop at the head of each bay, kerbs all round (open at
	# the driveway), weeds along them, oil stains and the P sign.
	var r = model.rect(pk)
	var lay = model.parking_layout(pk)
	parking_layouts[int(pk.id)] = lay
	# One large, seamless field in world coordinates: bays and driveway share
	# continuous fractures, without the old 4 m repeating crack pattern.
	var asphalt = Art.tex(Art.tiles.street.park_asphalt.file)
	floors.add_child(textured_polygon(Iso.diamond(r.position.x,r.position.y,r.end.x,r.end.y),asphalt))
	street_blocked.append(r)
	var aprons: Array = Street.aprons(lay) if lay.ok else []
	for a in aprons:
		floors.add_child(textured_polygon(Iso.diamond(a.position.x,a.position.y,a.end.x,a.end.y),asphalt))
		street_blocked.append(a)
	var seed = int(r.position.x*131.0+r.position.y*17.0+r.size.x*7.0+r.size.y)
	var edges = model.parking_edges(pk)
	for edge in edges:
		var axis = "x" if edge.a.x != edge.b.x else "z"
		var inward = -edge.normal.y if axis == "x" else -edge.normal.x
		var variant = int(mix_hash(edge.a.x,edge.a.y,seed)*4.0)
		decal("park_soil_half_%s_%s_%d" % [axis,"pos" if inward > 0 else "neg",variant],edge.a.x,edge.a.y)
	# Stains sit below the paint and concrete, never on top of them.
	for bay in lay.bays:
		if mix_hash(bay.mouth.x,bay.mouth.y,seed) > 0.55:
			var at: Vector2 = bay.mouth+bay.n*(2.2+mix_hash(bay.mouth.y,bay.mouth.x,seed)*0.8)
			decal("stain_%d" % int(mix_hash(bay.mouth.x,1,seed)*3.0),at.x,at.y)
	for s in lay.lines:
		var p0: Vector2 = s[0]
		var p1: Vector2 = s[1]
		var axis = "x" if absf(p1.x-p0.x) > 0.01 else "z"
		decal("park_line_%s_%d" % [axis,int(mix_hash(p0.x,p0.y,seed)*4.0)],minf(p0.x,p1.x),minf(p0.y,p1.y))
	for bay in lay.bays:
		var head: Vector2 = bay.mouth+bay.n*(Street.BAY_D-0.45)
		decal("park_stop_%s_%d" % ["z" if bay.n.x != 0 else "x",int(mix_hash(head.x,head.y,seed)*3.0)],head.x,head.y)
	for edge in edges:
		var axis = "x" if edge.a.x != edge.b.x else "z"
		var variant = int(mix_hash(edge.a.x,edge.a.y,seed)*4.0)
		decal("park_kerb_half_%s_%d" % [axis,variant],edge.a.x,edge.a.y)
		if mix_hash(edge.a.x,edge.a.y,seed+9) > 0.78:
			var at: Vector2 = edge.a.lerp(edge.b,0.3)-edge.normal*0.19
			decal("park_weed_%d" % int(mix_hash(at.x,at.y,seed)*8.0),at.x,at.y)
	var surface: Dictionary = Art.tiles.street.park_asphalt
	var period = float(surface.period)
	for tx in range(int(floor(r.position.x/period)),int(floor(r.end.x/period))+1):
		for tz in range(int(floor(r.position.y/period)),int(floor(r.end.y/period))+1):
			for spot in surface.tufts:
				var at = Vector2(float(spot[0])+tx*period,float(spot[1])+tz*period)
				if r.grow(-0.8).has_point(at):
					decal("park_weed_%d" % (4+int(mix_hash(at.x,at.y,seed)*4.0)),at.x,at.y)

func preview_parking(r: Rect2, lay: Dictionary, valid: bool) -> void:
	# While dragging: the zone, and when it works its bays, aisles and driveways.
	clear_preview()
	var root = Node2D.new()
	root.set_meta("bay_count",lay.get("bays",[]).size())
	var poly = Polygon2D.new()
	poly.polygon = Iso.diamond(r.position.x,r.position.y,r.end.x,r.end.y)
	poly.color = Color(0.5,1.0,0.65,0.18) if valid else Color(1.0,0.3,0.35,0.28)
	root.add_child(poly)
	var outline = func(rc: Rect2, color: Color, width: int = 1) -> void:
		var line = Line2D.new()
		line.points = Iso.diamond(rc.position.x,rc.position.y,rc.end.x,rc.end.y)
		line.closed = true
		line.width = width
		line.antialiased = false
		line.default_color = color
		root.add_child(line)
	outline.call(r,Color("7dffa8") if valid else Color("ff5a6a"))
	if lay.get("ok",false):
		for a in lay.aisles: outline.call(a,Color(1,1,1,0.35))
		for a in Street.aprons(lay): outline.call(a,Color("7dffa8") if valid else Color(1,1,1,0.4))
		for bay in lay.bays:
			var color = Color("7dffa8") if valid else Color("ff5a6a")
			outline.call(bay.rect,color)
			# A wheel stop and entry arrow make the chosen facing unambiguous.
			var n: Vector2 = bay.n
			var tangent = Vector2(-n.y,n.x)
			var head: Vector2 = bay.mouth+n*(Street.BAY_D-0.45)
			var stop = Line2D.new()
			stop.points = PackedVector2Array([Iso.pixel(head.x-tangent.x*0.8,head.y-tangent.y*0.8),Iso.pixel(head.x+tangent.x*0.8,head.y+tangent.y*0.8)])
			stop.width = 3
			stop.default_color = color
			root.add_child(stop)
			var arrow = Line2D.new()
			var tip: Vector2 = bay.mouth+n*1.1
			var tail: Vector2 = bay.mouth+n*0.2
			var left = tip-n*0.4+tangent*0.25
			var right = tip-n*0.4-tangent*0.25
			arrow.points = PackedVector2Array([Iso.pixel(tail.x,tail.y),Iso.pixel(tip.x,tip.y),Iso.pixel(left.x,left.y),Iso.pixel(tip.x,tip.y),Iso.pixel(right.x,right.y)])
			arrow.width = 1
			arrow.default_color = color
			root.add_child(arrow)
	elif not lay.is_empty():
		# Show the full missing footprint, including the part outside the zone.
		var normal = Vector2(Street.BAY_W,Street.BAY_D)
		var rotated = Vector2(Street.BAY_D,Street.BAY_W)
		var shortage = (normal-r.size).max(Vector2.ZERO)
		var other = (rotated-r.size).max(Vector2.ZERO)
		var needed = rotated if other.x+other.y < shortage.x+shortage.y else normal
		outline.call(Rect2(r.position,needed),Color("ff5a6a"))
	preview_node = root
	overlay.add_child(root)

var ghost_node: Node2D
var route_node: Strokes

func show_route(route: Array) -> void:
	# The path of a car's rear axle, as a thin line over the ground (tests and captures).
	if route_node == null:
		route_node = Strokes.new()
		route_node.color = Color(0.55,0.95,1.0,0.85)
		overlay.add_child(route_node)
	var dots = PackedVector2Array()
	for pose in route: dots.append(Iso.to_screen(pose.p.x,pose.p.y).round())
	route_node.dots = dots
	route_node.queue_redraw()

func show_ghost_car(p: Vector2, d: Vector2, reversing: bool = false) -> void:
	# A see-through box the size of the cars to come (4.4 x 1.8 x 1.45 m):
	# body up to the waist, a narrower cabin on top, headlights at the front.
	if ghost_node != null: ghost_node.queue_free()
	ghost_node = Node2D.new()
	overlay.add_child(ghost_node)
	var cs = Street.corners(p,d)
	var right = Vector2(-d.y,d.x)
	var front = p+d*(Street.CAR_L-Street.REAR)
	var back = p-d*Street.REAR
	var cabin = [back+d*0.9-right*0.72,back+d*0.9+right*0.72,back+d*2.9+right*0.72,back+d*2.9-right*0.72]
	var col = Color(0.55,0.95,1.0) if not reversing else Color(1.0,0.8,0.45)
	var box = func(base: Array, y0: float, y1: float, fill: float) -> void:
		var low = PackedVector2Array()
		var high = PackedVector2Array()
		for q in base:
			low.append(Iso.to_screen(q.x,q.y,y0).round())
			high.append(Iso.to_screen(q.x,q.y,y1).round())
		for i in range(4):
			var side = Polygon2D.new()
			side.polygon = PackedVector2Array([low[i],low[(i+1)%4],high[(i+1)%4],high[i]])
			side.color = Color(col.r,col.g,col.b,fill)
			ghost_node.add_child(side)
		var top = Polygon2D.new()
		top.polygon = high
		top.color = Color(col.r,col.g,col.b,fill*1.6)
		ghost_node.add_child(top)
		for ring in [low,high]:
			var line = Line2D.new()
			line.points = ring
			line.closed = true
			line.width = 1
			line.antialiased = false
			line.default_color = col
			ghost_node.add_child(line)
		for i in range(4):
			var line = Line2D.new()
			line.points = PackedVector2Array([low[i],high[i]])
			line.width = 1
			line.antialiased = false
			line.default_color = col
			ghost_node.add_child(line)
	box.call(cs,0.15,0.8,0.10)
	box.call(cabin,0.8,1.45,0.08)
	for k in [-0.6,0.6]:
		var lamp = Polygon2D.new()
		var q = front+right*k
		var c = Iso.to_screen(q.x,q.y,0.55).round()
		lamp.polygon = PackedVector2Array([c+Vector2(-1,-1),c+Vector2(1,-1),c+Vector2(1,1),c+Vector2(-1,1)])
		lamp.color = Color("fff2b0")
		ghost_node.add_child(lamp)

var street_hint: Strokes

func show_street_line(visible_now: bool) -> void:
	# In car-park mode: the edge of the sidewalk a car park must reach, dashed.
	if street_hint == null:
		street_hint = Strokes.new()
		street_hint.color = Color("7dffa8")
		street_hint.width = 2.0
		var segs = PackedVector2Array()
		for x in range(-int(Iso.LOT),int(Iso.LOT)):
			segs.append(Iso.to_screen(x,Street.LOT_FRONT))
			segs.append(Iso.to_screen(x+0.6,Street.LOT_FRONT))
		street_hint.segs = segs
		overlay.add_child(street_hint)
	street_hint.visible = visible_now

func set_club_open(value: bool) -> void:
	# The club sign lights up only while the club is open.
	club_open = value
	for s in signs:
		s.sprite.texture = s.on if value else s.off
		for g in s.glows: g.visible = value

# ------------------------------------------------------------------ depth sort
# Walls, posts, furniture parts, props and characters are drawn in one order:
# A before B whenever their pictures overlap and A stands behind B on the floor.
# Statics against statics are worked out once per rebuild; characters are
# slotted in every frame. Furniture comes in parts (seat, backrest, armrests,
# headboard, pole, shower glass), so someone sitting on a sofa is drawn over
# the seat and, depending on where the sofa faces, over or under the backrest.

const DEPTH_CELL = 32.0
var s_after: Array = []          # static index -> statics drawn after it
var s_before: Array = []         # static index -> statics drawn before it
var s_indeg: PackedInt32Array = PackedInt32Array()
var s_depth: PackedFloat32Array = PackedFloat32Array()
var s_px: Array = []             # static index -> Rect2 of its picture on screen
var s_cells: Dictionary = {}     # screen cell -> static indices whose picture covers it
var _heap: PackedInt32Array = PackedInt32Array()
var _key: PackedFloat32Array = PackedFloat32Array()

static func rect_order(a: Rect2, b: Rect2) -> int:
	# 1: a stands behind b, -1: in front, 0: side by side on a diagonal (then
	# they cannot cover each other in this view).
	var e = 0.0001
	var ab = a.end.x <= b.position.x+e or a.end.y <= b.position.y+e
	var ba = b.end.x <= a.position.x+e or b.end.y <= a.position.y+e
	if ab and ba: return 0
	if ab: return 1
	if ba: return -1
	var ca = a.get_center()
	var cb = b.get_center()
	return 1 if ca.x+ca.y < cb.x+cb.y else -1

static func behind_point(r: Rect2, p: Vector2) -> bool:
	# Is this floor rectangle behind someone standing at p? Yes once p is past
	# one of its front faces, or on it (sitting on the seat, dancing on the stage).
	var e = 0.02
	if p.x >= r.end.x-e or p.y >= r.end.y-e: return true
	return p.x > r.position.x+e and p.y > r.position.y+e

static var used_rects: Dictionary = {}

static func sprite_rect(s: Sprite2D, origin: Vector2) -> Rect2:
	# Where the sprite really has pixels (the pictures carry margins).
	if s.texture == null: return Rect2()
	var size = s.texture.get_size()/Vector2(maxi(s.hframes,1),maxi(s.vframes,1))
	if s.hframes > 1 or s.vframes > 1: return Rect2(origin+s.position+s.offset,size)
	var key = s.texture.resource_path
	if not used_rects.has(key):
		var img = s.texture.get_image()
		used_rects[key] = Rect2(img.get_used_rect()) if img != null else Rect2(Vector2.ZERO,size)
	var u: Rect2 = used_rects[key]
	return Rect2(origin+s.position+s.offset+u.position,u.size)

func node_rect(node: Node2D) -> Rect2:
	# The picture of a static on screen (its glows left out).
	var r = Rect2()
	var first = true
	var list: Array = [node] if node is Sprite2D else []
	for child in node.get_children():
		if child is Sprite2D and child.material != Art.add_material: list.append(child)
	for s in list:
		var sr = sprite_rect(s,Vector2.ZERO if s == node else node.position)
		if sr.size == Vector2.ZERO: continue
		r = sr if first else r.merge(sr)
		first = false
	return r

func cells_of(r: Rect2) -> Array:
	var out: Array = []
	for cx in range(floori(r.position.x/DEPTH_CELL),floori(r.end.x/DEPTH_CELL)+1):
		for cy in range(floori(r.position.y/DEPTH_CELL),floori(r.end.y/DEPTH_CELL)+1):
			out.append(Vector2i(cx,cy))
	return out

func static_order(i: int, j: int) -> int:
	# 1: i drawn before j, -1: after, 0: their pictures do not meet.
	if not (s_px[i] as Rect2).intersects(s_px[j]): return 0
	var a: Dictionary = statics[i]
	var b: Dictionary = statics[j]
	# parts cut from one picture never cover each other: no order needed
	if a.has("part") and b.has("part") and int(a.id) == int(b.id) and not a.get("separate",false): return 0
	return rect_order(a.rect,b.rect)

func link_static(i: int) -> void:
	# Order static i against every static its picture touches.
	var seen: Dictionary = {}
	for cell in cells_of(s_px[i]):
		for j in s_cells.get(cell,[]):
			if j == i or seen.has(j): continue
			seen[j] = true
			var o = static_order(i,j)
			if o == 0: continue
			var first = i if o > 0 else j
			var second = j if o > 0 else i
			if (s_after[first] as Array).has(second): continue
			s_after[first].append(second)
			s_before[second].append(first)
			s_indeg[second] += 1

func prepare_depth() -> void:
	var n = statics.size()
	s_after.resize(n)
	s_before.resize(n)
	s_px.resize(n)
	s_indeg = PackedInt32Array()
	s_indeg.resize(n)
	s_depth = PackedFloat32Array()
	s_depth.resize(n)
	s_cells.clear()
	for i in range(n):
		var e: Dictionary = statics[i]
		e.index = i
		s_after[i] = []
		s_before[i] = []
		s_px[i] = node_rect(e.node)
		var c: Vector2 = e.rect.get_center()
		s_depth[i] = c.x+c.y
		for cell in cells_of(s_px[i]):
			if not s_cells.has(cell): s_cells[cell] = []
			s_cells[cell].append(i)
	for i in range(n): link_static(i)
	depth_sort()

func relink_static(e: Dictionary) -> void:
	# A static changed shape (a shower door swinging): order it again.
	var i = int(e.get("index",-1))
	if i < 0 or i >= statics.size() or statics[i] != e: return
	for j in s_after[i]:
		s_indeg[j] -= 1
		s_before[j].erase(i)
	for j in s_before[i]: s_after[j].erase(i)
	s_after[i] = []
	s_before[i] = []
	s_indeg[i] = 0
	for cell in cells_of(s_px[i]):
		if s_cells.has(cell): s_cells[cell].erase(i)
	s_px[i] = node_rect(e.node)
	var c: Vector2 = e.rect.get_center()
	s_depth[i] = c.x+c.y
	for cell in cells_of(s_px[i]):
		if not s_cells.has(cell): s_cells[cell] = []
		s_cells[cell].append(i)
	link_static(i)

static func actor_rect(a: Node2D) -> Rect2:
	if a.has_method("pixel_bounds"): return a.pixel_bounds()
	# The body of a character on screen (feet at the anchor).
	return Rect2(a.position+Vector2(-10,-46),Vector2(20,48))

func heap_push(x: int) -> void:
	_heap.append(x)
	var c = _heap.size()-1
	while c > 0:
		var p = (c-1) >> 1
		var hc = _heap[c]
		var hp = _heap[p]
		if _key[hc] < _key[hp] or (_key[hc] == _key[hp] and hc < hp):
			_heap[c] = hp
			_heap[p] = hc
			c = p
		else: break

func heap_pop() -> int:
	var top = _heap[0]
	var last = _heap[_heap.size()-1]
	_heap.resize(_heap.size()-1)
	var n = _heap.size()
	if n == 0: return top
	_heap[0] = last
	var c = 0
	while true:
		var l = c*2+1
		if l >= n: break
		var best = l
		var r = l+1
		if r < n and (_key[_heap[r]] < _key[_heap[l]] or (_key[_heap[r]] == _key[_heap[l]] and _heap[r] < _heap[l])): best = r
		var hb = _heap[best]
		var hc = _heap[c]
		if _key[hb] < _key[hc] or (_key[hb] == _key[hc] and hb < hc):
			_heap[best] = hc
			_heap[c] = hb
			c = best
		else: break
	return top

func depth_sort() -> void:
	var n = statics.size()
	var act: Array = []
	for a in actors:
		if is_instance_valid(a) and a.visible and a.get_parent() == sorted: act.append(a)
	var m = act.size()
	var total = n+m
	var indeg: PackedInt32Array = s_indeg.duplicate()
	indeg.resize(total)
	_key = s_depth.duplicate()
	_key.resize(total)
	var extra: Dictionary = {}
	var boxes: Array = []
	for k in range(m):
		var a: Node2D = act[k]
		var p: Vector2 = a.world
		var ak = n+k
		_key[ak] = p.x+p.y
		var r = actor_rect(a)
		boxes.append(r)
		var seen: Dictionary = {}
		for cell in cells_of(r):
			for i in s_cells.get(cell,[]):
				if seen.has(i): continue
				seen[i] = true
				if not r.intersects(s_px[i]): continue
				var behind = behind_point(statics[i].rect,p)
				if a.has_meta("delivery_vehicle"):
					var order = rect_order(statics[i].rect,Rect2(a.world+a.footprint.position,a.footprint.size))
					if order != 0: behind = order > 0
				var first = i if behind else ak
				var second = ak if first == i else i
				if not extra.has(first): extra[first] = []
				extra[first].append(second)
				indeg[second] += 1
	# characters among themselves: the one further back first
	for k in range(m):
		for l in range(k+1,m):
			if not (boxes[k] as Rect2).intersects(boxes[l]): continue
			var first = n+k if _key[n+k] <= _key[n+l] else n+l
			var second = n+l if first == n+k else n+k
			if not extra.has(first): extra[first] = []
			extra[first].append(second)
			indeg[second] += 1
	# Kahn's algorithm, the shallowest ready node first; a cycle is broken by
	# forcing the shallowest node left.
	var queued = PackedByteArray()
	queued.resize(total)
	_heap = PackedInt32Array()
	for i in range(total):
		if indeg[i] == 0:
			queued[i] = 1
			heap_push(i)
	var order: Array = []
	while order.size() < total:
		if _heap.is_empty():
			var pick_i = -1
			for i in range(total):
				if queued[i] == 0 and (pick_i < 0 or _key[i] < _key[pick_i]): pick_i = i
			queued[pick_i] = 1
			heap_push(pick_i)
		var i = heap_pop()
		order.append(i)
		if i < n:
			for j in s_after[i]:
				indeg[j] -= 1
				if indeg[j] <= 0 and queued[j] == 0:
					queued[j] = 1
					heap_push(j)
		if extra.has(i):
			for j in extra[i]:
				indeg[j] -= 1
				if indeg[j] <= 0 and queued[j] == 0:
					queued[j] = 1
					heap_push(j)
	for rank in range(order.size()):
		var i: int = order[rank]
		var z = mini(10+rank*2,3900)
		var node: Node2D = statics[i].node if i < n else act[i-n]
		if node.z_index != z: node.z_index = z

func add_actor(actor: Node2D) -> void:
	actors.append(actor)
	sorted.add_child(actor)

func remove_actor(actor: Node2D) -> void:
	actors.erase(actor)
	if actor.get_parent() == sorted: sorted.remove_child(actor)
	actor.queue_free()

func _process(delta: float) -> void:
	clock += delta
	for a in anim_items:
		# dance floor tiles and neon, fairy lights: the next picture of the loop
		var frame = int(clock*float(a.fps)+float(a.phase)) % int(a.frames)
		if frame == int(a.frame): continue
		a.frame = frame
		var item = model.item_by_id(int(a.id))
		if item.is_empty() or not is_instance_valid(a.entry.sprite): continue
		var info = Art.furniture_entry(Catalog.anim_kind(item,frame),int(item.rot))
		if info.is_empty(): continue
		apply_look(a.entry,info,item)
		if item.kind in Catalog.COLOR_KINDS:
			var col = Color(Catalog.DANCE_SCHEMES[clampi(int(item.get("scheme",0)),0,Catalog.DANCE_SCHEMES.size()-1)].colors[frame % 4])
			for g in a.glows:
				if is_instance_valid(g): g.modulate = Color(col.r,col.g,col.b,g.modulate.a)
	for id in bed_looks.keys():
		var look: Dictionary = bed_looks[id]
		var fps = float(look.get("fps",0.0))
		var frame = int(clock*fps) % 4 if fps > 0.0 else 0
		if frame != int(look.get("frame",-1)):
			look.frame = frame
			refresh_bed(id)
	for p in puffs.duplicate():
		p.time -= delta
		if not is_instance_valid(p.sprite) or p.time <= 0:
			if is_instance_valid(p.sprite): p.sprite.queue_free()
			puffs.erase(p)
			continue
		p.sprite.position = (p.start+Vector2(0,-8.0*(1.0-p.time/2.5))).round()
	for e in animated:
		if is_instance_valid(e.sprite): e.sprite.frame = int(clock*e.fps+e.phase) % e.frames
	depth_sort()
	for d in doors:
		var open = false
		for a in actors:
			if is_instance_valid(a) and a.world.distance_to(d.center) < 0.9:
				open = true
				break
		d.sprite.texture = d.open if open else d.closed

# ------------------------------------------------------------------ picking and feedback

func pick(p: Vector2) -> Dictionary:
	# Front-most opaque pixel wins: actors, then furniture (walls ignored).
	var best: Dictionary = {}
	var best_z = -100000
	for a in actors:
		if not is_instance_valid(a) or not a.visible: continue
		if a.z_index > best_z and a.hit(p):
			best = {"actor":a}
			best_z = a.z_index
	for id in item_entries:
		for e in item_entries[id].get("parts",[item_entries[id]]):
			var s: Sprite2D = e.sprite
			var z = s.z_index if not e.get("flat",false) else -1000
			if z <= best_z: continue
			var local = Vector2i((p-s.position-s.offset).floor())
			if Art.alpha_at(e.file,local):
				best = {"item":id}
				best_z = z
	return best

func pick_wall(p: Vector2) -> String:
	var best = ""
	var best_z = -100000
	for e in statics:
		if e.kind != "wall" or not e.has("sprite"): continue
		var s: Sprite2D = e.sprite
		if s.z_index < best_z and best != "": continue
		var local = Vector2i((p-s.position-s.offset).floor())
		if Art.alpha_at(e.file,local):
			best = e.key
			best_z = e.node.z_index
	return best

func nearest_edge(p: Vector2) -> String:
	var key = pick_wall(p)
	if key != "": return key
	var w = Iso.to_world(p)
	var walls = model.edges()
	var best = ""
	var best_d = 0.45
	for k in walls:
		var e: Dictionary = walls[k]
		var d = 99.0
		if e.axis == "x":
			if w.x >= e.x-0.1 and w.x <= e.x+1.1: d = absf(w.y-e.z)
		elif w.y >= e.z-0.1 and w.y <= e.z+1.1: d = absf(w.x-e.x)
		if d < best_d:
			best_d = d
			best = k
	return best

var outline_sprites: Dictionary = {}   # item id -> outline of an item drawn in parts

func set_outline(id: int, color: Color) -> void:
	if not item_entries.has(id): return
	if color.a <= 0.0 and model.item_by_id(id).get("delivery_pending",false): color = Color(.6,.85,1,.65)
	var entry: Dictionary = item_entries[id]
	if not entry.has("parts"):
		(entry.sprite.material as ShaderMaterial).set_shader_parameter("outline_color",color)
		return
	# drawn in parts: the outline follows the whole item, above the scene
	# (part by part it would also trace the seams between backrest and seat)
	if outline_sprites.has(id):
		if is_instance_valid(outline_sprites[id]): outline_sprites[id].queue_free()
		outline_sprites.erase(id)
	if color.a <= 0.0: return
	var item = model.item_by_id(id)
	var info = Art.furniture_entry(item_variant(item),int(item.rot))
	if item.is_empty() or info.is_empty(): return
	var mat = Art.rgba_material()
	mat.set_shader_parameter("outline_color",color)
	mat.set_shader_parameter("outline_only",true)
	var s = sprite(Art.tex(info.file),entry.sprite.position,Vector2(info.ox,info.oy),mat)
	overlay.add_child(s)
	outline_sprites[id] = s

func selection(item_id: int, room: Dictionary = {}, edge: String = "", parking: Dictionary = {}) -> void:
	for id in item_entries: set_outline(id,Color(0,0,0,0))
	for a in actors:
		if is_instance_valid(a): a.set_outline(Color(0,0,0,0))
	selected_item = item_id
	selected_edge = edge
	if item_id >= 0:
		set_outline(item_id,ACCENT)
		for a in actors:
			if is_instance_valid(a) and a.item_id == item_id: a.set_outline(ACCENT)
	if hovered_item >= 0 and hovered_item != item_id: hover_item(hovered_item)
	room_outline.visible = not room.is_empty() or not parking.is_empty()
	if not parking.is_empty():
		room_outline.points = Iso.diamond(parking.x,parking.z,parking.x+parking.w,parking.z+parking.h)
	clear_node(handles_node)
	if not room.is_empty():
		room_outline.points = Iso.diamond(room.x,room.z,room.x+room.w,room.z+room.h)
		for h in handles(room):
			var r = ColorRect.new()
			r.color = ACCENT
			r.size = Vector2(5,5)
			r.position = Iso.pixel(h.x,h.y)-Vector2(2,2)
			handles_node.add_child(r)
	show_edge(edge)

func show_edge(edge: String, color: Color = ACCENT) -> void:
	edge_marker.visible = edge != ""
	if edge == "": return
	var parts = edge.split(":")
	var x = int(parts[1])
	var z = int(parts[2])
	var b = Vector2(x+1,z) if parts[0] == "x" else Vector2(x,z+1)
	edge_marker.default_color = color
	edge_marker.points = PackedVector2Array([Iso.to_screen(x,z),Iso.to_screen(b.x,b.y)])

func hover_item(id: int) -> void:
	if hovered_item >= 0 and hovered_item != selected_item:
		set_outline(hovered_item,Color(0,0,0,0))
		for a in actors:
			if is_instance_valid(a) and a.item_id == hovered_item: a.set_outline(Color(0,0,0,0))
	hovered_item = id
	if id >= 0 and id != selected_item:
		set_outline(id,HOVER)
		for a in actors:
			if is_instance_valid(a) and a.item_id == id: a.set_outline(HOVER)

func handles(room: Dictionary) -> Array:
	return [Vector2(room.x,room.z+room.h/2.0),Vector2(room.x+room.w,room.z+room.h/2.0),Vector2(room.x+room.w/2.0,room.z),Vector2(room.x+room.w/2.0,room.z+room.h)]

func clear_preview() -> void:
	if preview_node != null:
		preview_node.queue_free()
		preview_node = null

func preview_item(item: Dictionary, valid: bool) -> void:
	clear_preview()
	var tint = Color(0.45,1.0,0.6,0.35) if valid else Color(1.0,0.25,0.3,0.55)
	if Catalog.is_character(item.kind):
		var actor = Actor.new()
		actor.configure(Characters.normalize(item.get("appearance",{}),item.kind))
		actor.set_world(Vector2(item.x,item.z))
		actor.face(Catalog.direction_to_world(item,Vector2(0,1)))
		actor.set_tint(tint)
		preview_node = actor
	else:
		var info = Art.furniture_entry(item.kind,int(item.rot))
		var mat = Art.rgba_material()
		mat.set_shader_parameter("tint",tint)
		preview_node = sprite(Art.tex(info.file),Iso.pixel(item.x,item.z),Vector2(info.ox,info.oy),mat)
		preview_node.modulate.a = 0.9
	var foot = Line2D.new()
	var r = model.item_rect(item)
	foot.points = Iso.diamond(r.position.x,r.position.y,r.end.x,r.end.y)
	foot.closed = true
	foot.width = 1
	foot.antialiased = false
	foot.default_color = Color("7dffa8") if valid else Color("ff5a6a")
	foot.position = -preview_node.position
	preview_node.add_child(foot)
	foot.show_behind_parent = true
	overlay.add_child(preview_node)

func preview_room(r: Dictionary, valid: bool) -> void:
	clear_preview()
	var poly = Polygon2D.new()
	poly.polygon = Iso.diamond(r.x,r.z,r.x+r.w,r.z+r.h)
	poly.color = Color(0.5,1.0,0.65,0.22) if valid else Color(1.0,0.3,0.35,0.3)
	var line = Line2D.new()
	line.points = poly.polygon
	line.closed = true
	line.width = 1
	line.antialiased = false
	line.default_color = Color("7dffa8") if valid else Color("ff5a6a")
	poly.add_child(line)
	preview_node = poly
	overlay.add_child(poly)

func preview_edge(edge: String, kind: String) -> void:
	clear_preview()
	show_edge(edge,Color("7dffa8") if kind == "door" else Color("7fd4ff"))
	if edge == "": edge_marker.visible = false


class Strokes:
	# Thin pixel lines drawn by hand (pairs of points).
	extends Node2D
	var segs = PackedVector2Array()
	var dots = PackedVector2Array()
	var color = Color.WHITE
	var width = 1.0
	func _draw() -> void:
		for i in range(0,segs.size()-1,2): draw_line(segs[i],segs[i+1],color,width,false)
		for d in dots: draw_rect(Rect2(d,Vector2(1,1)),color)

class GridLines:
	extends Node2D
	func _draw() -> void:
		var L = Iso.LOT
		var c = Color(1,1,1,0.10)
		for i in range(-L,L+1):
			draw_line(Iso.to_screen(i,-L),Iso.to_screen(i,L),c,1.0,false)
			draw_line(Iso.to_screen(-L,i),Iso.to_screen(L,i),c,1.0,false)
