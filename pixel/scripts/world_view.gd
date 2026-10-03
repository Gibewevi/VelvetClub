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
var rain: RainOverlay
var rain_ground: RainGround
var seasons: SeasonEnvironment
var weather_surfaces: Array = []
var weather_intensity = 0.0
var club_open = false
var signs: Array = []
var animated: Array = []       # looping props (sprite sheets with several frames)
var bed_looks: Dictionary = {}  # bed id -> {fps, frame, clothes} while a couple is under the covers
var clothes: Dictionary = {}    # bed id -> clothes sprite dropped by the bed
var puffs: Array = []           # floating bubbles above rooms (hearts, steam)
var anim_items: Array = []      # objects with a loop of pictures (dance floor, lit palm)
var clock = 0.0
var rebuild_pending = false     # several changes in one frame: one redraw
var dust_back: PlaceDust        # puffs behind a placed object (under the furniture)
var dust_front: PlaceDust       # and in front of it (over the furniture)
static var small_clouds: Array = []
var construction: Construction   # building sites draw themselves after the finished walls

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
	rain = RainOverlay.new()
	rain.setup(model)
	rain.world = self
	overlay.add_child(rain)
	rain_ground = RainGround.new()
	rain_ground.z_index = -240
	add_child(rain_ground)
	rain_ground.setup(model)
	seasons = SeasonEnvironment.new()
	add_child(seasons)
	seasons.setup(self)
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
	# outside the layers a rebuild clears: a puff outlives the redraw it follows
	dust_back = PlaceDust.new()
	dust_back.z_index = -195
	add_child(dust_back)
	dust_front = PlaceDust.new()
	dust_front.z_index = 3990
	add_child(dust_front)
	rebuild()

# ------------------------------------------------------------------ build

func clear_node(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()

func rebuild() -> void:
	var p0 = Prof.t("view.rebuild")
	_timed_rebuild()
	Prof.add("view.rebuild",p0)

func request_rebuild() -> void:
	# Redraw the building once, at the start of the next frame, however many
	# changes come in meanwhile.
	rebuild_pending = true

func _timed_rebuild() -> void:
	rebuild_pending = false
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
	weather_surfaces.clear()
	seasons.begin_layout()
	var p0 = Prof.t()
	compute_bounds()
	build_ground()
	for room in model.rooms:
		if not SitePlan.building(room): build_floor(room)
	Prof.add("rb.floors",p0)
	p0 = Prof.t()
	build_walls()
	Prof.add("rb.walls",p0)
	p0 = Prof.t()
	if construction != null: construction.build_view()
	Prof.add("rb.sites",p0)
	p0 = Prof.t()
	for item in model.furniture:
		if Catalog.is_character(item.kind): continue
		build_item(item)
	Prof.add("rb.items",p0)
	p0 = Prof.t()
	street_blocked.clear()
	parking_layouts.clear()
	for pk in model.parkings: build_parking(pk)
	build_street()
	Prof.add("rb.street",p0)
	p0 = Prof.t()
	build_exterior()
	Prof.add("rb.exterior",p0)
	p0 = Prof.t()
	rain_ground.layout_changed(statics)
	seasons.layout_changed()
	rain.layout_changed()
	rain.drawn_key = []
	shaded_at = -1.0   # the new surfaces take the current weather
	weather_shade(weather_intensity)
	Prof.add("rb.rain",p0)
	for a in actors:
		if is_instance_valid(a) and a.get_parent() != sorted: sorted.add_child(a)
	p0 = Prof.t()
	prepare_depth()
	Prof.add("rb.depth",p0)
	selection(selected_item)

func compute_bounds() -> void:
	if model.rooms.is_empty():
		bounds = Rect2(-6,-6,12,12)
		return
	var r: Rect2 = model.bounds(model.rooms[0])
	for room in model.rooms: r = r.merge(model.bounds(room))
	bounds = r

func weather_surface(node: CanvasItem) -> void:
	weather_surfaces.append({"node":node,"base":node.modulate})

var shaded_at = -1.0

func weather_shade(intensity: float) -> void:
	# called on every simulation step: only repaint when the rain changes
	if absf(clampf(intensity,0,1)-shaded_at) < 0.005: return
	shaded_at = clampf(intensity,0,1)
	weather_intensity = clampf(intensity,0,1)
	ground.modulate = Color.WHITE.lerp(Color(.84,.86,.91),weather_intensity)
	for surface in weather_surfaces:
		if is_instance_valid(surface.node): surface.node.modulate = surface.base*Color.WHITE.lerp(Color(.87,.89,.94),weather_intensity)

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
	# The lawn: one picture of the whole lot, nothing repeats. It is clear
	# over the street (its verge grows over the slabs); rooms and car parks
	# are drawn over it.
	var lawn: Dictionary = Art.tiles.get("lawn",{})
	if not lawn.is_empty():
		var meadow = sprite(Art.tex(lawn.file),Vector2.ZERO,Vector2(lawn.ox,lawn.oy),Art.rgba_material())
		ground.add_child(meadow)
		seasons.register(meadow,"lawn")

func build_floor(room: Dictionary) -> void:
	# one polygon per rectangle of the room; the texture is laid in screen
	# space, so the pieces of an extended room join without a seam
	var tex = Art.tex(Art.tiles.floors[Finishes.floor_pattern(room)])
	for r in BuildingModel.parts_of(room):
		var poly = textured_polygon(Iso.diamond(r.position.x,r.position.y,r.end.x,r.end.y),tex,Palette.floor_palette(Color(room.floor_color)))
		floors.add_child(poly)

func room_side(axis: String, x: int, z: int, positive: bool) -> Dictionary:
	# A room still under construction has no finished walls yet: its own
	# walls are drawn by the site, a wall it shares stays as it was.
	var room = model.room_at(Vector2(x+0.5,z+(0.5 if positive else -0.5))) if axis == "x" else model.room_at(Vector2(x+(0.5 if positive else -0.5),z+0.5))
	return {} if SitePlan.building(room) else room

func add_static(node: Node2D, rect: Rect2, kind: String, data: Dictionary = {}) -> Dictionary:
	sorted.add_child(node)
	var entry = {"node":node,"rect":rect,"kind":kind,"rank":0,"extra":[]}
	entry.merge(data)
	statics.append(entry)
	if kind == "prop": weather_surface(node)
	return entry

func sprite(tex: Texture2D, pos: Vector2, offset: Vector2, mat: Material = null) -> Sprite2D:
	var s = Sprite2D.new()
	s.texture = tex
	s.centered = false
	s.position = pos
	s.offset = -offset
	if mat != null: s.material = mat
	return s

func door_pairs() -> Dictionary:
	# Doors side by side on one wall line become double doors, two by two
	# from the start of the run: door key -> "l" (first metre) or "r".
	var out: Dictionary = {}
	for key in model.openings:
		if model.openings[key] != "door": continue
		var c = key.split(":")
		var step = Vector2i(1,0) if c[0] == "x" else Vector2i(0,1)
		var at = Vector2i(int(c[1]),int(c[2]))
		if model.openings.get(BuildingModel.edge_key(c[0],at.x-step.x,at.y-step.y),"") == "door": continue
		var n = 0
		while model.openings.get(BuildingModel.edge_key(c[0],at.x+step.x*n,at.y+step.y*n),"") == "door": n += 1
		for i in range(0,n-1,2):
			out[BuildingModel.edge_key(c[0],at.x+step.x*i,at.y+step.y*i)] = "l"
			out[BuildingModel.edge_key(c[0],at.x+step.x*(i+1),at.y+step.y*(i+1))] = "r"
	return out

func wall_full(front_room: Dictionary, back_room: Dictionary) -> bool:
	# Back walls stand full height, front walls are cut away. A wall between
	# two public spaces (lounge and corridor) stays low so the bar stays in view.
	var full = not front_room.is_empty() and wall_mode == 0
	if full and not back_room.is_empty() and int(front_room.type) == 0 and int(back_room.type) == 0: full = false
	return full

func build_walls() -> void:
	var walls: Dictionary = model.edges()
	var segs: Dictionary = {}
	var pairs = door_pairs()
	# High walls meeting at each grid point: where a high wall meets no other
	# one, it stops there and is drawn with its real end (no post).
	var high_at: Dictionary = {}
	for key in walls:
		var e: Dictionary = walls[key]
		var front_room = room_side(e.axis,e.x,e.z,true)
		var back_room = room_side(e.axis,e.x,e.z,false)
		if front_room.is_empty() and back_room.is_empty(): continue
		if not wall_full(front_room,back_room): continue
		var a = Vector2i(e.x,e.z)
		for q in [a,a+(Vector2i(1,0) if e.axis == "x" else Vector2i(0,1))]:
			high_at[q] = int(high_at.get(q,0))+1
	for key in walls:
		var e: Dictionary = walls[key]
		var axis: String = e.axis
		var x: int = e.x
		var z: int = e.z
		var front_room = room_side(axis,x,z,true)
		var back_room = room_side(axis,x,z,false)
		if front_room.is_empty() and back_room.is_empty(): continue
		var full = wall_full(front_room,back_room)
		var owner = front_room if not front_room.is_empty() else back_room
		var opening: String = model.openings.get(key,"")
		var pair: String = pairs.get(key,"")
		var kind = "full" if full else "low"
		if opening == "door": kind = ("full_door"+("_"+pair if pair != "" else "")) if full else ""
		elif opening == "window": kind = "full_window" if full else "low_window"
		var ends = ""
		if kind == "full":
			var a = Vector2i(x,z)
			if int(high_at.get(a,0)) <= 1: ends += "0"
			if int(high_at.get(a+(Vector2i(1,0) if axis == "x" else Vector2i(0,1)),0)) <= 1: ends += "1"
		segs[key] = {"axis":axis,"x":x,"z":z,"full":full,"kind":kind,"owner":owner,"opening":opening,"ends":ends}
		var rect = Rect2(x,z,1,0) if axis == "x" else Rect2(x,z,0,1)
		var pos = Iso.pixel(x,z)
		var node = Node2D.new()
		var entry = add_static(node,rect,"wall",{"key":key,"high":full and kind != ""})
		if kind != "":
			# Variants follow the position so the pattern runs on along a wall.
			var variant = posmod(x if axis == "x" else z,int(Art.tiles.get("wall_variants",1)))
			var wkey = "%s:%s:%s" % [Finishes.wall_pattern(owner),axis,kind+("_e"+ends if ends != "" and Art.tiles.walls.has("%s:%s:full_e%s" % [Finishes.wall_pattern(owner),axis,ends]) else "")]
			var info: Dictionary = Art.tiles.walls.get("%s:%d" % [wkey,variant],Art.tiles.walls[wkey])
			var s = sprite(Art.tex(info.file),pos,Vector2(info.ox,info.oy),Art.material(Palette.wall_palette(Color(owner.wall_color))))
			node.add_child(s)
			entry.sprite = s
			entry.file = info.file
		if opening != "":
			var okey = ""
			if opening == "door" and full: okey = ("door2_%s:" % pair if pair != "" else "door:")+axis
			elif opening == "window": okey = ("window:" if full else "window_low:")+axis
			if okey != "":
				var info: Dictionary = Art.tiles.openings[okey]
				var s = sprite(Art.tex(info.file),pos,Vector2(info.ox,info.oy),Art.rgba_material())
				node.add_child(s)
				entry.opening_sprite = s
				entry.opening_file = info.file
				if opening == "door":
					var open_info: Dictionary = Art.tiles.openings[okey.replace(":","_open:")]
					var ajar_info: Dictionary = Art.tiles.openings.get(okey.replace(":","_ajar:"),open_info)
					var center = Vector2(x+0.5,z) if axis == "x" else Vector2(x,z+0.5)
					# both leaves of a double door swing together, from its middle
					if pair == "l": center = Vector2(x+1,z) if axis == "x" else Vector2(x,z+1)
					elif pair == "r": center = Vector2(x,z)
					var frames = [Art.tex(info.file),Art.tex(ajar_info.file),Art.tex(open_info.file)]
					s.set_meta("frames",frames)
					doors.append({"sprite":s,"closed":frames[0],"open":frames[2],"frames":frames,"swing":0.0,"center":center,"key":key,"reach":1.3 if pair != "" else 0.9})
			var beyond = Vector2(x+0.5,z+(0.5 if front_room.is_empty() else -0.5)) if axis == "x" else Vector2(x+(0.5 if front_room.is_empty() else -0.5),z+0.5)
			if opening == "door" and pair != "r" and (front_room.is_empty() or back_room.is_empty()) and model.room_at(beyond).is_empty():
				street_doors.append({"key":key,"axis":axis,"x":x,"z":z,"outside_positive":front_room.is_empty(),"room":owner,"double":pair == "l"})
	# Posts close the corners, ends and door gaps of cut walls (and a door
	# or window at the very end of a high wall).
	var points: Dictionary = {}
	for key in segs:
		var s: Dictionary = segs[key]
		var a = Vector2i(s.x,s.z)
		var b = a+(Vector2i(1,0) if s.axis == "x" else Vector2i(0,1))
		for p in [a,b]:
			if not points.has(p): points[p] = []
			points[p].append(s)
	var joint_points: Dictionary = {}
	for p in points:
		var list: Array = points[p]
		# where walls of one height meet (corner, T, crossing), their caps
		# are traced as one top and laid over the junction: no seam
		for height in ["full","low"]:
			var arms = ""
			for q in list:
				if q.kind == "" or (q.full if height == "low" else not q.full): continue
				var starts = Vector2i(q.x,q.z) == p
				var dir = ("x" if starts else "X") if q.axis == "x" else ("z" if starts else "Z")
				if not arms.contains(dir): arms += dir
			var canon = ""
			for c in "xXzZ":
				if arms.contains(c): canon += c
			if canon.length() >= 2 and canon != "xX" and canon != "zZ": joint_points[p] = joint_points.get(p,[])+[[height,canon,list]]
	for p in points:
		var list: Array = points[p]
		# the middle of a double doorway in a cut wall: one wide passage
		if list.size() == 2 and list[0].axis == list[1].axis and list[0].kind == "" and list[1].kind == "" and list[0].opening == "door" and list[1].opening == "door": continue
		var need = list.size() != 2 or list[0].axis != list[1].axis
		var any_full = false
		var any_gap = false
		for s in list:
			any_full = any_full or (s.full and s.kind != "")
			# a gap in a cut wall needs its end posts; a door in a high wall
			# has its own frame and the wall runs on around it
			any_gap = any_gap or s.kind == ""
		if any_gap: need = true
		if list.size() == 2 and list[0].axis == list[1].axis and list[0].full != list[1].full: need = true
		if not need: continue
		# High walls need no post: where they meet they join by themselves,
		# where one stops it is drawn with its real end. Only a door or a
		# window right at the end of a high wall keeps one to close it.
		if any_full:
			if list.size() >= 2 and list.all(func(q): return q.full and q.kind != ""): continue
			var open_end = list.any(func(q): return q.full and q.kind.begins_with("full_") and int(high_at.get(p,0)) <= 1)
			if not open_end: continue
		var post_kind = "full" if any_full else "low"
		# The dark low posts mark corners, wall ends and door frames. Where a
		# low wall runs straight on (a T or a crossing), the wall that meets
		# it simply butts against it: no post.
		if post_kind == "low" and list.size() >= 3 and runs_through(list): continue
		var owner: Dictionary = list[0].owner
		for s in list:
			if s.full: owner = s.owner
		var info: Dictionary = Art.tiles.posts[post_kind]
		var node = sprite(Art.tex(info.file),Iso.pixel(p.x,p.y),Vector2(info.ox,info.oy),Art.material(Palette.wall_palette(Color(owner.wall_color))))
		var entry = add_static(node,Rect2(p.x,p.y,0,0),"post")
		entry.sprite = node
		entry.file = info.file
		joint_points.erase(p)    # a post covers the corner already
	for p in joint_points:
		for joint in joint_points[p]:
			var jinfo: Dictionary = Art.tiles.get("joints",{}).get("%s:%s" % [joint[0],joint[1]],{})
			if jinfo.is_empty(): continue
			var owner: Dictionary = joint[2][0].owner
			var node = sprite(Art.tex(jinfo.file),Iso.pixel(p.x,p.y),Vector2(jinfo.ox,jinfo.oy),Art.material(Palette.wall_palette(Color(owner.wall_color))))
			var entry = add_static(node,Rect2(p.x,p.y,0,0),"joint")
			entry.sprite = node
			entry.file = jinfo.file

static func runs_through(list: Array) -> bool:
	# two walls (not openings) on either side of a point, on the same line
	var solid = {"x":0,"z":0}
	for s in list:
		if s.kind != "" and not s.kind.ends_with("door"): solid[s.axis] += 1
	return solid.x >= 2 or solid.z >= 2

const DOOR_SWING = 14.0   # door pictures per second: closed to open in about 0.15 s

var cloak_fill: Dictionary = {}   # rack / locker id -> share of its places taken
var containers: Array = []         # dumpsters by the street: {pos, away} (where the maids empty the bins)

func item_variant(item: Dictionary) -> String:
	if item.get("kind","") == "bottle_crate" and int(item.get("stock",48)) == 0 and not item.get("delivery_pending",false): return "bottle_crate_fill_0"
	if Catalog.bottle_shelf(item.get("kind","")) and not item.get("delivery_pending",false):
		return "%s_fill_%d" % [item.kind,ceili(int(item.get("stock",0))/4.0)]
	# The picture an item shows right now: a bed in use or unmade, a shower door ajar,
	# a coat rack or lockers as full as the cloakroom is.
	if item.kind in ClubSim.BED_KINDS: return bed_variant(item)
	if item.kind == "coat_rack" and not item.get("delivery_pending",false):
		return "coat_rack_c%d" % clampi(ceili(float(cloak_fill.get(int(item.id),0.0))*7.0-0.001),0,7)
	if item.kind == "cloak_locker" and not item.get("delivery_pending",false):
		return "cloak_locker_o%d" % clampi(ceili(float(cloak_fill.get(int(item.id),0.0))*9.0-0.001),0,9)
	if item.kind == "bin" and not item.get("delivery_pending",false): return "bin_f%d" % Waste.level(item)
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

func set_cloak_fill(id: int, share: float) -> void:
	# a coat hung or taken back: the rack or the lockers show it
	var before = item_variant(model.item_by_id(id))
	cloak_fill[id] = clampf(share,0.0,1.0)
	var item = model.item_by_id(id)
	if item.is_empty() or not item_entries.has(id): return
	var look = item_variant(item)
	if look == before: return
	var info = Art.furniture_entry(look,int(item.rot))
	if not info.is_empty(): apply_look(item_entries[id],info,item)

func refresh_bin(id: int) -> void:
	# something thrown in or the bin emptied: it shows how full it is
	var item = model.item_by_id(id)
	if item.is_empty() or not item_entries.has(id): return
	var info = Art.furniture_entry(item_variant(item),int(item.rot))
	if not info.is_empty(): apply_look(item_entries[id],info,item)

func refresh_stock(id: int) -> void:
	var item = model.item_by_id(id)
	if item.is_empty() or not item_entries.has(id) or Catalog.stock_capacity(item.kind) == 0: return
	var info = Art.furniture_entry(item_variant(item),int(item.rot))
	if not info.is_empty(): apply_look(item_entries[id],info,item)

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
		var inner = model.shape(room).grow(-0.35)
		for local in [Vector2(size.x/2.0+0.45,0.5),Vector2(-size.x/2.0-0.45,0.5),Vector2(0.3,size.y/2.0+0.4),Vector2(-0.4,size.y/2.0+0.4)]:
			var p = Catalog.local_to_world(item,local)
			if inner.has_point(p):
				at = p
				break
	if clothes_at.has(id): at = clothes_at[id]
	var s = sprite(Art.tex(info.file),Iso.pixel(at.x,at.y),Vector2(info.ox,info.oy),Art.rgba_material())
	floor_fx.add_child(s)
	clothes[id] = s

func place_dust(item: Dictionary, light: bool = false) -> void:
	# A small "pouf" round the foot of an object set down or moved (light:
	# only a few flecks, for an object turned on the spot).
	if item.is_empty() or not Catalog.ITEMS.has(item.kind) or Catalog.is_character(item.kind): return
	if small_clouds.is_empty():
		for frames in DeliverySmokeArt.clouds():
			var picked: Array = []
			for k in PlaceDust.SMALL_STEPS: picked.append(frames[k])
			small_clouds.append(picked)
	var flecks: Array = DeliverySmokeArt.flecks()
	var r = model.item_rect(item)
	var c = r.get_center()
	var i = 0
	for pt in PlaceDust.points(r):
		var layer: PlaceDust = dust_front if pt.at.x+pt.at.y >= c.x+c.y else dust_back
		if not light:
			layer.add(pt.at,small_clouds[i % small_clouds.size()],Vector2(-12,-17),i*0.03,0.5+0.05*(i % 3),pt.dir*0.32,3.0,i % 2 == 1)
		if light or i % 2 == 0:
			layer.add(pt.at+pt.dir*0.1,flecks,Vector2(-4,-6),0.04+i*0.02,0.4,pt.dir*0.5,4.0,i % 2 == 0)
		i += 1

func outfit_poof(at: Vector2) -> void:
	# a little cloud round her feet as she slips into (or out of) her lingerie
	place_dust({"kind":"stool","x":at.x,"z":at.y,"rot":0})

func puff(at: Vector2, icon: String, seconds: float) -> void:
	# A bubble rising from a spot where the characters are out of sight.
	var tex = Art.ui_texture("emotes",icon)
	if tex == null: return
	var s = Sprite2D.new()
	s.texture = tex
	s.position = Iso.pixel(at.x,at.y)+Vector2(0,-40)
	overlay.add_child(s)
	puffs.append({"sprite":s,"time":seconds,"start":s.position})

func float_text(at: Vector2, text: String, color: Color, seconds: float) -> void:
	# A small line of text rising from a spot: what a service was paid, a tip.
	var l = Label.new()
	var ls = LabelSettings.new()
	ls.font = UiKit.font
	ls.font_size = 10
	ls.font_color = color
	ls.outline_size = 2
	ls.outline_color = Color("140c18")
	l.label_settings = ls
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size = Vector2(160,14)
	l.position = Iso.pixel(at.x,at.y)+Vector2(-80,-78)
	overlay.add_child(l)
	puffs.append({"sprite":l,"time":seconds,"start":l.position})

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
	if item.kind in Sanitation.SINKS and item.get("soap",false):
		# Tiny native-resolution dispenser attached to the basin, sorted with it.
		var bottle = Image.create(5,8,false,Image.FORMAT_RGBA8)
		var rows = [".ddd.","..d..",".www.","dwwwd","dwgwd","dwgwd","dwwwd",".ddd."]
		var colors = {"d":Color("373448"),"w":Color("e5f3df"),"g":Color("6dbba6")}
		for y in range(rows.size()):
			for x in range(5):
				var ch = rows[y][x]
				if colors.has(ch): bottle.set_pixel(x,y,colors[ch])
		var dispenser = Sprite2D.new()
		dispenser.texture = ImageTexture.create_from_image(bottle)
		var at = Catalog.local_to_world(item,Vector2(-.25,-.1))
		dispenser.position = (Iso.pixel(at.x,at.y)-entry.node.position+Vector2(0,-24)).round()
		dispenser.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		entry.node.add_child(dispenser)
	for light in info.get("lights",[]):
		glows.append_array(add_glow(entry,pos+Vector2(light.x,light.y),Color(light.color),float(light.radius),float(light.power)))
	var anim: Dictionary = Catalog.ITEMS[item.kind].get("anim",{})
	if not anim.is_empty():
		anim_items.append({"id":int(item.id),"entry":entry,"frames":int(anim.frames),"fps":float(anim.fps),"frame":-1,"glows":glows,
			"phase":float(posmod(int(item.id)*7,int(anim.frames)))})
	refresh_sanitary(item,0.0)

func refresh_sanitary(item: Dictionary, time: float) -> void:
	if not item.kind in Plumbing.KINDS or item.get("delivery_pending",false): return
	var entry: Dictionary = item_entries.get(int(item.id),{})
	if entry.is_empty(): return
	if not entry.has("sanitary_fx"):
		var info = Art.furniture_entry(item.kind,int(item.rot))
		var effects: Dictionary = {}
		for key in ["soil","drops","smell","fault"]:
			var node = Sprite2D.new()
			node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			entry.node.add_child(node)
			effects[key] = node
		effects.soil.centered = false
		effects.soil.offset = -Vector2(info.ox,info.oy)
		effects.soil.material = Art.rgba_material()
		effects.smell.position = Vector2(-7,-minf(info.oy,60)-3)
		effects.fault.position = Vector2(10,-minf(info.oy,60)-7)
		effects.fault.texture = Art.tex(Art.sanitary.repair)
		var s = Plumbing.service_spot(item)
		if not s.is_empty(): effects.drops.position = (Iso.pixel(s.pos.x,s.pos.y)-entry.node.position+Vector2(0,-10)).round()
		entry.sanitary_fx = effects
	var fx: Dictionary = entry.sanitary_fx
	var soil = float(item.get("soil",0))
	var level = 0 if soil < 15 else (1 if soil < 50 else (2 if soil < 100 else 3))
	fx.soil.visible = level > 0
	if level > 0: fx.soil.texture = Art.tex(Art.sanitary.soil[item.kind][str(posmod(int(item.rot),4))][level-1])
	var frame = int(time*3.0) % 4
	fx.smell.visible = level == 3
	fx.smell.texture = Art.tex(Art.sanitary.smell[frame])
	fx.drops.visible = item.get("leaking",false)
	fx.drops.texture = Art.tex(Art.sanitary.drops[frame])
	fx.fault.visible = item.get("leaking",false)

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
	containers.clear()
	# Street lamps and trees stand on the sidewalks, never in the screen
	# column of a room (the tall posts would hide it), never on a driveway.
	var cmin = INF
	var cmax = -INF
	for room in model.rooms:
		for r in BuildingModel.parts_of(room):
			cmin = minf(cmin,r.position.x-r.end.y)
			cmax = maxf(cmax,r.end.x-r.position.y)
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
	var paths: Array = []
	for d in street_doors:
		var half = 1.0 if d.get("double",false) else 0.5   # a double door is 2 m wide
		# a paved path across the lawn, from a front door to the sidewalk
		if d.axis == "x" and d.outside_positive and float(d.z) < Street.WALK_NEAR.x:
			var path = Rect2(d.x-0.25,d.z,half*2.0+0.5,Street.WALK_NEAR.x-d.z)
			var free = true
			var pz = float(d.z)+0.5
			while pz < Street.WALK_NEAR.x:
				if not model.room_at(Vector2(d.x+half,pz)).is_empty(): free = false
				pz += 1.0
			if free:
				ground.add_child(textured_polygon(Iso.diamond(path.position.x,path.position.y,path.end.x,path.end.y),Art.tex(Art.tiles.floors.slabs),Palette.floor_palette(WALK_COLOR)))
				paths.append(path)
		var out = Vector2(d.x+half,d.z+1.2) if d.axis == "x" else Vector2(d.x+1.2,d.z+half)
		if not d.outside_positive: out = Vector2(d.x+half,d.z-1.2) if d.axis == "x" else Vector2(d.x-1.2,d.z+half)
		var side = Vector2(1,0) if d.axis == "x" else Vector2(0,1)
		var away = (out-Vector2(d.x+half,d.z)).normalized() if d.axis == "x" else (out-Vector2(d.x,d.z+half)).normalized()
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
		props.append(["dumpster",out.x-side.x*3.6+away.x*0.2,out.y-side.y*3.6+away.y*0.2,away])
		props.append(["dumpster",out.x-side.x*5.2+away.x*0.2,out.y-side.y*5.2+away.y*0.2,away])
		props.append(["bush",out.x+side.x*3.6,out.y+side.y*3.6])
	# round bushes along the sidewalks, at irregular intervals, off the paths
	for edge in [[Street.WALK_NEAR.x,-1.0],[Street.WALK_FAR.y,1.0]]:
		var wx = -L+1.0+mix_hash(edge[0],3,5)*2.0
		while wx < L-1.0:
			var kind = "lawn_bush_%d" % mini(3,int(mix_hash(wx,edge[0],31)*4.0))
			var size = float(Art.tiles.props.get(kind,{}).get("size",1.0))
			var wz = edge[0]+edge[1]*(size*0.5+0.22+mix_hash(wx,7,41)*0.3)
			if not paths.any(func(r): return r.grow(size*0.5+0.2).has_point(Vector2(wx,wz))): props.append([kind,wx,wz])
			wx += size+1.2+mix_hash(wx,edge[0],43)*3.8
	for p in props:
		if model.room_at(Vector2(p[1],p[2])) != {}: continue
		if absf(p[1]) > Iso.LOT-1 or absf(p[2]) > Iso.LOT-1: continue
		var size = float(Art.tiles.props.get(p[0],{}).get("size",{"tree":1.2,"dumpster":1.3}.get(p[0],0.4)))
		if p[0].begins_with("lawn_bush"):
			var spot = Rect2(p[1]-size/2,p[2]-size/2,size,size)
			if model.rooms.any(func(r): return model.overlaps(r,spot)): continue
		if off_limits(Vector2(p[1],p[2]),size/2.0+0.2,p[0] in ["street_lamp","tree"]): continue
		var info: Dictionary = Art.tiles.props[p[0]]
		var key = int(round(p[1]*7.0+p[2]*13.0))
		if p[0] == "tree" and Art.tiles.props.has("tree_%d" % posmod(key,3)): info = Art.tiles.props["tree_%d" % posmod(key,3)]
		var s = sprite(Art.tex(info.file),Iso.pixel(p[1],p[2]),Vector2(info.ox,info.oy),Art.rgba_material())
		var season_key: String = "tree_%d" % posmod(key,3) if p[0] == "tree" else p[0]
		seasons.register(s,season_key,Vector2(p[1],p[2]))
		if info.has("pit"):
			var pit = sprite(Art.tex(info.pit.file),Iso.pixel(p[1],p[2]),Vector2(info.pit.ox,info.pit.oy),Art.rgba_material())
			ground.add_child(pit)
			seasons.register(pit,"tree_pit_%d" % posmod(key,3))
		if int(info.get("frames",1)) > 1:
			# each animated prop runs on its own beat
			s.hframes = int(info.frames)
			animated.append({"sprite":s,"frames":int(info.frames),"fps":float(info.fps)*(0.85+posmod(key,5)*0.07),"phase":float(posmod(key*3,int(info.frames)))})
		var entry = add_static(s,Rect2(p[1]-size/2,p[2]-size/2,size,size),"prop")
		if p[0] == "dumpster": containers.append({"pos":Vector2(p[1],p[2]),"away":p[3]})
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
	weather_surface(s)
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
	var parking_surface = textured_polygon(Iso.diamond(r.position.x,r.position.y,r.end.x,r.end.y),asphalt)
	floors.add_child(parking_surface)
	weather_surface(parking_surface)
	street_blocked.append(r)
	var aprons: Array = Street.aprons(lay) if lay.ok else []
	for a in aprons:
		var apron_surface = textured_polygon(Iso.diamond(a.position.x,a.position.y,a.end.x,a.end.y),asphalt)
		floors.add_child(apron_surface)
		weather_surface(apron_surface)
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
	var weedy = r.grow(-0.8) if r.size.x > 1.6 and r.size.y > 1.6 else Rect2()
	for tx in range(int(floor(r.position.x/period)),int(floor(r.end.x/period))+1):
		for tz in range(int(floor(r.position.y/period)),int(floor(r.end.y/period))+1):
			for spot in surface.tufts:
				var at = Vector2(float(spot[0])+tx*period,float(spot[1])+tz*period)
				if weedy.has_area() and weedy.has_point(at):
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
	# a door: every picture of its swing counts (they share one canvas)
	var u = Rect2()
	for tex in (s.get_meta("frames") if s.has_meta("frames") else [s.texture]):
		var key = tex.resource_path
		if not used_rects.has(key):
			var img = tex.get_image()
			used_rects[key] = Rect2(img.get_used_rect()) if img != null else Rect2(Vector2.ZERO,size)
		u = used_rects[key] if u.size == Vector2.ZERO else u.merge(used_rects[key])
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
	# A post caps the ends of the walls that meet at it: it is drawn after
	# them, else the wall leaving towards the viewer cuts the post in half.
	if a.kind in ["post","joint"] and b.kind == "wall" and wall_ends_at(b.rect,a.rect.position): return -1
	if b.kind in ["post","joint"] and a.kind == "wall" and wall_ends_at(a.rect,b.rect.position): return 1
	var order = rect_order(a.rect,b.rect)
	# A high wall that stops where a cut wall passes: the cut wall runs in
	# front of the high wall's end (they only touch, on a diagonal).
	if order == 0 and a.kind == "wall" and b.kind == "wall" and bool(a.get("high",false)) != bool(b.get("high",false)) and a.rect.grow(0.001).intersects(b.rect.grow(0.001)):
		return 1 if a.get("high",false) else -1
	return order

static func wall_ends_at(r: Rect2, p: Vector2) -> bool:
	return r.position.is_equal_approx(p) or r.end.is_equal_approx(p)

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
	var p0 = Prof.t("depth")
	_timed_depth_sort()
	Prof.add("depth",p0)

func _timed_depth_sort() -> void:
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
		if i < n and statics[i].get("dead",false): continue
		var node: Node2D = statics[i].node if i < n else act[i-n]
		if node.z_index != z: node.z_index = z

# ------------------------------------------------------------------ small objects
# Tissues dropped after a service, rubbish swept up: these come and go all
# night. They are drawn and slotted into the depth order on their own, so
# the whole building is not redrawn each time (that cost up to a quarter of
# a second per object and could snowball at high speed).

static func quick_kind(kind: String) -> bool:
	if not Catalog.is_debris(kind) or Catalog.ITEMS[kind].has("anim"): return false
	for rot in range(4):
		var info = Art.furniture_entry(kind,rot)
		if not info.get("lights",[]).is_empty() or not info.get("parts",[]).is_empty(): return false
	return true

func add_item_quick(item: Dictionary) -> bool:
	if item.is_empty() or not quick_kind(item.kind) or item_entries.has(int(item.id)): return false
	var before = statics.size()
	build_item(item)
	append_depth(before)
	return true

func remove_item_quick(id: int) -> bool:
	if not item_entries.has(id): return true
	var entry: Dictionary = item_entries[id]
	var kind = ""
	for item in model.furniture:
		if int(item.id) == id: kind = item.kind
	if entry.has("parts") or (kind != "" and not quick_kind(kind)): return false
	if hovered_item == id: hovered_item = -1
	if outline_sprites.has(id):
		if is_instance_valid(outline_sprites[id]): outline_sprites[id].queue_free()
		outline_sprites.erase(id)
	if entry.get("flat",false):
		if is_instance_valid(entry.node): entry.node.queue_free()
	else: retire_static(entry)
	item_entries.erase(id)
	return true

func append_depth(from: int) -> void:
	# New statics join the depth order without recomputing the others.
	var n = statics.size()
	s_after.resize(n)
	s_before.resize(n)
	s_px.resize(n)
	s_indeg.resize(n)
	s_depth.resize(n)
	for i in range(from,n):
		var e: Dictionary = statics[i]
		e.index = i
		s_after[i] = []
		s_before[i] = []
		s_indeg[i] = 0
		s_px[i] = node_rect(e.node)
		var c: Vector2 = e.rect.get_center()
		s_depth[i] = c.x+c.y
		for cell in cells_of(s_px[i]):
			if not s_cells.has(cell): s_cells[cell] = []
			s_cells[cell].append(i)
	for i in range(from,n): link_static(i)

func retire_static(e: Dictionary) -> void:
	# A static leaves the picture: its slot stays (indices do not move) but
	# it has no order and no node any more.
	var i = int(e.get("index",-1))
	e.dead = true
	if i >= 0 and i < statics.size() and statics[i] == e:
		for j in s_after[i]:
			s_indeg[j] -= 1
			s_before[j].erase(i)
		for j in s_before[i]: s_after[j].erase(i)
		s_after[i] = []
		s_before[i] = []
		s_indeg[i] = 0
		for cell in cells_of(s_px[i]):
			if s_cells.has(cell): s_cells[cell].erase(i)
		s_px[i] = Rect2()
	if is_instance_valid(e.node): e.node.queue_free()

func add_actor(actor: Node2D) -> void:
	actors.append(actor)
	sorted.add_child(actor)

func remove_actor(actor: Node2D) -> void:
	actors.erase(actor)
	if actor.get_parent() == sorted: sorted.remove_child(actor)
	actor.queue_free()

func _process(delta: float) -> void:
	var p0 = Prof.t("view")
	_timed_process(delta)
	Prof.add("view",p0)

func _timed_process(delta: float) -> void:
	if rebuild_pending: rebuild()
	rain.refresh()
	rain_ground.refresh()
	seasons.refresh()
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
			if is_instance_valid(a) and not a.has_meta("season_leaf") and not a.has_meta("bar_parcel") and a.world.distance_to(d.center) < float(d.get("reach",0.9)):
				open = true
				break
		# the leaf swings through its pictures: closed, ajar, open (and back)
		d.swing = move_toward(float(d.swing),2.0 if open else 0.0,delta*DOOR_SWING)
		d.sprite.texture = d.frames[int(round(d.swing))]

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
	# The front-most wall under the pointer. A door or a window counts as
	# its wall: the wall picture has a hole where the door stands.
	var best = ""
	var best_z = -100000
	for e in statics:
		if e.kind != "wall": continue
		var z: int = e.node.z_index
		if best != "" and z < best_z: continue
		for part in [["sprite","file"],["opening_sprite","opening_file"]]:
			if not e.has(part[0]): continue
			var s: Sprite2D = e[part[0]]
			var local = Vector2i((p-s.position-s.offset).floor())
			if Art.alpha_at(e[part[1]],local):
				best = e.key
				best_z = z
				break
	return best

func opening_near(p: Vector2, reach: float = 0.35) -> String:
	# The door or window closest to a floor point: a door in a cut wall has
	# no picture to click, only the gap between two posts.
	var best = ""
	var best_d = reach
	for key in model.openings:
		var c = key.split(":")
		var a = Vector2(int(c[1]),int(c[2]))
		var b = a+(Vector2(1,0) if c[0] == "x" else Vector2(0,1))
		var d = Geometry2D.get_closest_point_to_segment(p,a,b).distance_to(p)
		if d < best_d:
			best_d = d
			best = key
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
		room_outline.points = BuildingModel.outline_points(room)
		for h in handles(room):
			var r = ColorRect.new()
			r.color = ACCENT
			r.size = Vector2(5,5)
			r.position = Iso.pixel(h.x,h.y)-Vector2(2,2)
			handles_node.add_child(r)
	show_edge(edge,ACCENT,true)

func show_edge(edge: String, color: Color = ACCENT, whole: bool = false) -> void:
	# One metre of wall; with whole, a selected partition shows from end to end.
	edge_marker.visible = edge != ""
	if edge == "": return
	var run: Array = model.partition_run(edge) if whole and not model.openings.has(edge) else []
	if run.is_empty(): run = [edge]
	var lo = Vector2(INF,INF)
	var hi = Vector2(-INF,-INF)
	for k in run:
		var parts = k.split(":")
		var a = Vector2(int(parts[1]),int(parts[2]))
		var b = a+(Vector2(1,0) if parts[0] == "x" else Vector2(0,1))
		lo = lo.min(a)
		hi = hi.max(b)
	edge_marker.default_color = color
	edge_marker.points = PackedVector2Array([Iso.to_screen(lo.x,lo.y),Iso.to_screen(hi.x,hi.y)])

func preview_partition(a: Vector2i, b: Vector2i, valid: bool) -> void:
	# the line a partition being drawn will follow
	clear_preview()
	edge_marker.visible = true
	edge_marker.default_color = Color("7dffa8") if valid else Color("ff6070")
	var pa = Iso.to_screen(a.x,a.y)
	var pb = Iso.to_screen(b.x,b.y)
	if pa == pb: edge_marker.points = PackedVector2Array([pa-Vector2(2,0),pa+Vector2(2,0)])
	else: edge_marker.points = PackedVector2Array([pa,pb])

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
	# an extended room grows by drawing from one of its walls, not by handles
	if not room.get("parts",[]).is_empty(): return []
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

func price_tag(area: Rect2, size_line: String, price_line: String, affordable: bool = true) -> void:
	# A small label on the ground being drawn: its size, then what it costs
	# (in red when the money is not there).
	if preview_node == null: return
	var tag = Node2D.new()
	var lines: Array = []
	for i in range(2):
		var ls = LabelSettings.new()
		ls.font = UiKit.font
		ls.font_size = 10 if i == 0 else 16
		ls.font_color = UiKit.INK if i == 0 else (UiKit.GOLD if affordable else UiKit.RED)
		ls.outline_size = 3
		ls.outline_color = Color("140c18")
		var l = Label.new()
		l.label_settings = ls
		l.text = size_line if i == 0 else price_line
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lines.append(l)
	var w = 0.0
	var h = 0.0
	for l in lines:
		var m: Vector2 = l.get_minimum_size()
		w = maxf(w,m.x)
		h += m.y
	var back = Panel.new()
	var box = StyleBoxFlat.new()
	box.bg_color = Color(0.08,0.05,0.1,0.82)
	box.border_color = UiKit.GOLD if affordable else UiKit.RED
	box.set_border_width_all(1)
	box.set_corner_radius_all(3)
	back.add_theme_stylebox_override("panel",box)
	back.size = Vector2(w+12,h+4)
	back.position = -back.size/2.0
	tag.add_child(back)
	var y = -h/2.0
	for l in lines:
		var m: Vector2 = l.get_minimum_size()
		l.size = Vector2(w,m.y)
		l.position = Vector2(-w/2.0,y)
		y += m.y
		tag.add_child(l)
	var c = area.get_center()
	tag.position = (Iso.pixel(c.x,c.y)-preview_node.position).round()
	preview_node.add_child(tag)

func preview_parts(rects: Array, valid: bool, outline_room: Dictionary = {}) -> void:
	# An extension: the new ground in green (red when refused), the room it
	# joins outlined.
	clear_preview()
	var root = Node2D.new()
	for r in rects:
		var poly = Polygon2D.new()
		poly.polygon = Iso.diamond(r.position.x,r.position.y,r.end.x,r.end.y)
		poly.color = Color(0.5,1.0,0.65,0.26) if valid else Color(1.0,0.3,0.35,0.3)
		root.add_child(poly)
		var line = Line2D.new()
		line.points = poly.polygon
		line.closed = true
		line.width = 1
		line.antialiased = false
		line.default_color = Color("7dffa8") if valid else Color("ff5a6a")
		root.add_child(line)
	if not outline_room.is_empty():
		var line = Line2D.new()
		line.points = BuildingModel.outline_points(outline_room)
		line.closed = true
		line.width = 1
		line.antialiased = false
		line.default_color = ACCENT
		root.add_child(line)
	preview_node = root
	overlay.add_child(root)

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
