class_name SeasonEnvironment
extends Node2D

const MAX_LEAVES = 2200
const MAX_FALLING = 18
const TREE_LEAVES = 120
const SHRUB_LEAVES = 24
const COLORS = [Color("dc7427"),Color("e7a632"),Color("b9412b"),Color("a95825")]
static var manifest: Dictionary = {}
static var shader: Shader
var world: WorldView
var materials: Array = []
var plants: Array = []
var fallen: Array = []
var falling: Array = []
var counts: Dictionary = {}
var fall_year = 0
var day = 1
var minute = 1080.0
var current = ClubSeasons.state(1,1080)
var drawn_key: Array = []
var material_key: Array = []

func setup(view: WorldView) -> void:
	world = view
	if manifest.is_empty(): manifest = Art.read("seasons.json")
	if shader == null: shader = load("res://shaders/seasons.gdshader")
	z_index = -235

func begin_layout() -> void:
	materials.clear()
	plants.clear()

func register(sprite: Sprite2D, name_key: String, spot: Vector2 = Vector2.INF) -> void:
	var spec: Dictionary = manifest.get(name_key,{})
	if spec.is_empty(): return
	var mat = ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("kind",int(spec.kind))
	mat.set_shader_parameter("leaf_mask",Art.tex(spec.mask))
	mat.set_shader_parameter("winter_texture",Art.tex(spec.get("bare",spec.snow)))
	mat.set_shader_parameter("snow_texture",Art.tex(spec.snow))
	sprite.material = mat
	materials.append(mat)
	set_uniforms(mat)
	if int(spec.kind) in [1,2] and spot != Vector2.INF:
		plants.append({"world":spot,"key":"%.3f:%.3f" % [spot.x,spot.y],"tree":int(spec.kind) == 1})

func set_uniforms(mat: ShaderMaterial) -> void:
	mat.set_shader_parameter("autumn",float(current.autumn))
	mat.set_shader_parameter("leaf_loss",float(current.loss))
	mat.set_shader_parameter("snow",float(current.snow))

func update_date(new_day: int, new_minute: float) -> void:
	day = maxi(new_day,1)
	minute = clampf(new_minute,0,1440)
	current = ClubSeasons.state(day,minute)
	var key = [snappedf(current.autumn,.001),snappedf(current.loss,.001),snappedf(current.snow,.001)]
	if key != material_key:
		material_key = key
		for mat in materials: set_uniforms(mat)
		queue_redraw()

func exposed(p: Vector2) -> bool:
	return absf(p.x) < Iso.LOT-.3 and absf(p.y) < Iso.LOT-.3 and world.model.room_at(p).is_empty() and not world.model.furniture.any(func(i): return not Catalog.is_character(i.kind) and world.model.item_rect(i).has_point(p))

func layout_changed() -> void:
	for leaf in fallen: leaf.exposed = exposed(Vector2(float(leaf.x),float(leaf.z)))
	drawn_key = []
	queue_redraw()

func step(game_minutes: float, new_day: int, new_minute: float) -> void:
	update_date(new_day,new_minute)
	var seconds = maxf(game_minutes,0)/ClubSim.MINUTES_PER_SECOND
	for leaf in falling.duplicate():
		if not is_instance_valid(leaf):
			falling.erase(leaf)
			continue
		leaf.advance(seconds)
		if leaf.age >= leaf.duration:
			deposit(leaf.land)
			falling.erase(leaf)
			world.remove_actor(leaf)
	# Only autumn produces litter. Snow hides it, spring decomposes it;
	# repainting the club or panning the camera never redistributes it.
	var month = int(current.date.month)
	if month in [9,10,11,12]:
		if fall_year != int(current.date.year):
			fall_year = int(current.date.year)
			counts.clear()
		for plant in plants:
			var limit = TREE_LEAVES if plant.tree else SHRUB_LEAVES
			var target = int(float(current.loss)*limit)
			var count = int(counts.get(plant.key,0))
			while count < target:
				make_leaf(plant,count,seconds > 0 and target-count <= 2)
				count += 1
			counts[plant.key] = count
	var before = fallen.size()
	fallen = fallen.filter(func(leaf): return day-int(leaf.day) < 230)
	if fallen.size() != before: queue_redraw()
	refresh()

func make_leaf(plant: Dictionary, number: int, animate: bool) -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = hash(plant.key)+number*7919+fall_year*104729
	var radius = 2.7 if plant.tree else .9
	var p: Vector2 = plant.world+Vector2(rng.randf_range(-radius,radius),rng.randf_range(-radius,radius))
	if not exposed(p): return
	var entry = {"x":p.x,"z":p.y,"day":day,"variant":rng.randi_range(0,3)}
	if not animate or falling.size() >= MAX_FALLING:
		deposit(entry)
		return
	var leaf = SeasonLeaf.new()
	leaf.world = p
	leaf.variant = int(entry.variant)
	leaf.seed = number
	leaf.height = rng.randf_range(65,125) if plant.tree else rng.randf_range(9,23)
	leaf.duration = rng.randf_range(3.4,5.2)
	leaf.land = entry
	leaf.set_meta("season_leaf",true)
	world.add_actor(leaf)
	leaf.advance(0)
	falling.append(leaf)

func deposit(entry: Dictionary) -> void:
	if fallen.size() >= MAX_LEAVES: fallen.pop_front()
	entry.exposed = exposed(Vector2(float(entry.x),float(entry.z)))
	fallen.append(entry)
	queue_redraw()

func refresh() -> void:
	var key = [get_canvas_transform().origin.round(),day,snappedf(current.snow,.01),fallen.size()]
	if drawn_key == key: return
	drawn_key = key
	queue_redraw()

func _draw() -> void:
	if world == null: return
	var inverse = get_canvas_transform().affine_inverse()
	var visible_box = Rect2(inverse*Vector2.ZERO,inverse*get_viewport_rect().size-inverse*Vector2.ZERO).grow(8)
	for leaf in fallen:
		var p = Vector2(float(leaf.x),float(leaf.z))
		var pixel = Iso.pixel(p.x,p.y)
		if not visible_box.has_point(pixel) or not leaf.get("exposed",false): continue
		var fade = 1.0-clampf((day-int(leaf.day)-130)/100.0,0,1)
		fade *= 1.0-smoothstep(.25,.85,float(current.snow))
		if fade <= .02: continue
		draw_leaf(self,pixel,int(leaf.variant),0,fade)

static func draw_leaf(node: Node2D, pixel: Vector2, variant: int, pose: int = 0, opacity: float = 1.0) -> void:
	var c: Color = COLORS[posmod(variant,COLORS.size())]
	c.a = opacity
	var shadow = c.darkened(.32)
	shadow.a = opacity
	var width = 3 if pose == 1 else 5
	node.draw_rect(Rect2(pixel+Vector2(-width/2,-1),Vector2(width,2)),c)
	node.draw_rect(Rect2(pixel+Vector2(-1,-2),Vector2(2,1)),c.lightened(.16)*Color(1,1,1,opacity))
	node.draw_rect(Rect2(pixel+Vector2(0,1),Vector2(2,1)),shadow)

func to_dict() -> Dictionary:
	# Save a falling leaf at its eventual landing point so it cannot disappear
	# from the accumulated litter when loading in the middle of its flight.
	var all = fallen.duplicate(true)
	for leaf in falling:
		if is_instance_valid(leaf): all.append(leaf.land.duplicate())
	return {"year":fall_year,"counts":counts.duplicate(),"fallen":all.slice(maxi(0,all.size()-MAX_LEAVES))}

func from_dict(data: Variant) -> void:
	reset()
	if not data is Dictionary: return
	var year = data.get("year",0)
	if (year is int or year is float) and is_finite(float(year)): fall_year = clampi(int(year),0,1000000)
	var saved_counts = data.get("counts",{})
	if saved_counts is Dictionary:
		for key in saved_counts:
			var n = saved_counts[key]
			if key is String and key.length() <= 64 and (n is int or n is float) and is_finite(float(n)) and counts.size() < 400:
				counts[key] = clampi(int(n),0,TREE_LEAVES)
	var entries = data.get("fallen",[])
	if entries is Array:
		for leaf in entries.slice(0,MAX_LEAVES):
			if not leaf is Dictionary: continue
			var valid = true
			for key in ["x","z","day","variant"]:
				var n = leaf.get(key)
				if not (n is int or n is float) or not is_finite(float(n)): valid = false
			if not valid or absf(float(leaf.x)) > Iso.LOT or absf(float(leaf.z)) > Iso.LOT: continue
			fallen.append({"x":float(leaf.x),"z":float(leaf.z),"day":maxi(1,int(leaf.day)),"variant":clampi(int(leaf.variant),0,3)})
	layout_changed()
	queue_redraw()

func reset() -> void:
	for leaf in falling:
		if is_instance_valid(leaf): world.remove_actor(leaf)
	falling.clear()
	fallen.clear()
	counts.clear()
	fall_year = 0
	drawn_key = []
	queue_redraw()
