class_name RainGround
extends Node2D

# Weather water is scenery, separate from indoor plumbing/cleaning jobs.
# Fixed world positions and native-sized growth pictures avoid crawling noise.
const SEED = 20260956
const PATCH_COUNT = 260
const IMPACT_COUNT = 950
static var pictures: Array = []
var model: BuildingModel
var patches: Array = []
var impacts: Array = []
var blocked: Array = []
var buckets: Dictionary = {}   # 2 m cell -> rectangles (roofs, objects) touching it
const BUCKET = 2.0
var wetness = 0.0
var phase = 0.0
var strength = 0.0
var drawn_puddles = 0
var drawn_impacts = 0

func setup(building: BuildingModel) -> void:
	model = building
	make_pictures()
	var rng = RandomNumberGenerator.new()
	rng.seed = SEED
	for i in range(PATCH_COUNT+IMPACT_COUNT):
		var p = Vector2(rng.randf_range(-Iso.LOT+1,Iso.LOT-1),rng.randf_range(-Iso.LOT+1,Iso.LOT-1))
		if i < PATCH_COUNT:
			patches.append({"world":p,"pixel":Iso.pixel(p.x,p.y),"variant":rng.randi_range(0,7),"threshold":rng.randf_range(.015,.42),"exposed":false})
		else:
			impacts.append({"world":p,"pixel":Iso.pixel(p.x,p.y),"beat":rng.randf_range(0,2.4),"rank":rng.randf(),"exposed":false})

func exposed(p: Vector2, radius: float) -> bool:
	if buckets.is_empty() and model != null:
		# asked before any layout: roofs at least
		for room in model.rooms:
			for part in BuildingModel.parts_of(room): file_rect((part as Rect2).grow(.15))
	var box = Rect2(p-Vector2.ONE*radius,Vector2.ONE*radius*2)
	for cx in range(floori(box.position.x/BUCKET),floori(box.end.x/BUCKET)+1):
		for cz in range(floori(box.position.y/BUCKET),floori(box.end.y/BUCKET)+1):
			for r in buckets.get(Vector2i(cx,cz),[]):
				if (r as Rect2).intersects(box): return false
	return true

func file_rect(r: Rect2) -> void:
	for cx in range(floori(r.position.x/BUCKET),floori(r.end.x/BUCKET)+1):
		for cz in range(floori(r.position.y/BUCKET),floori(r.end.y/BUCKET)+1):
			var k = Vector2i(cx,cz)
			if not buckets.has(k): buckets[k] = []
			buckets[k].append(r)

func layout_changed(entries: Array) -> void:
	blocked.clear()
	buckets.clear()
	for room in model.rooms:
		for part in BuildingModel.parts_of(room): file_rect((part as Rect2).grow(.15))
	for e in entries:
		if e.kind == "prop" or e.kind == "item":
			var r: Rect2 = e.rect.grow(.15)
			blocked.append(r)
			file_rect(r)
	for patch in patches: patch.exposed = exposed(patch.world,1.1)
	for impact in impacts: impact.exposed = exposed(impact.world,.45)
	queue_redraw()

func step(seconds: float, intensity: float) -> void:
	strength = clampf(intensity,0,1)
	phase = fposmod(phase+maxf(0,seconds),960.0)
	# Full saturation takes ~90 game minutes; drying takes ~five game hours.
	wetness = clampf(wetness+maxf(0,seconds)*(strength/36.0 if strength > 0 else -1.0/120.0),0,1)
	queue_redraw()

func to_dict() -> Dictionary:
	return {"wetness":wetness,"phase":phase}

func from_dict(data: Variant) -> void:
	wetness = 0
	phase = 0
	if data is Dictionary:
		for key in ["wetness","phase"]:
			var n = data.get(key)
			if (n is int or n is float) and is_finite(float(n)):
				set(key,clampf(float(n),0,1 if key == "wetness" else 960))
	queue_redraw()

func stage(patch: Dictionary) -> int:
	var growth = (wetness-float(patch.threshold))/(1.0-float(patch.threshold))
	return clampi(int(ceil(growth*5)),0,5)

func _draw() -> void:
	drawn_puddles = 0
	drawn_impacts = 0
	if model == null: return
	var inverse = get_canvas_transform().affine_inverse()
	var screen = get_viewport_rect().size
	var visible_box = Rect2(inverse*Vector2.ZERO,inverse*screen-inverse*Vector2.ZERO).grow(40)
	for patch in patches:
		if not patch.exposed or not visible_box.has_point(patch.pixel): continue
		var size = stage(patch)
		if size == 0: continue
		draw_texture(pictures[int(patch.variant)][size-1],patch.pixel-Vector2(20,10))
		drawn_puddles += 1
	if strength <= 0: return
	for impact in impacts:
		if not impact.exposed or impact.rank > strength or not visible_box.has_point(impact.pixel): continue
		var age = fposmod(phase+float(impact.beat),2.4)
		if age >= .5: continue
		draw_impact(impact.pixel,int(age*8))
		drawn_impacts += 1

func dot(p: Vector2, x: int, y: int, w: int, color: Color) -> void:
	draw_rect(Rect2(p+Vector2(x,y),Vector2(w,1)),color)

func draw_impact(p: Vector2, frame: int) -> void:
	var light = Color("a1b4c4") * Color(1,1,1,.65)
	var shade = Color("637b96") * Color(1,1,1,.7)
	# Small crowns, lifted droplets, then an isometric broken ripple.
	match frame:
		0:
			dot(p,-1,0,3,light)
			dot(p,0,-2,1,light)
		1:
			dot(p,-3,-2,1,light)
			dot(p,2,-3,1,light)
			dot(p,-2,1,5,shade)
			dot(p,-1,0,3,light)
		2:
			dot(p,-4,0,2,shade)
			dot(p,3,0,2,light)
			dot(p,-2,-1,4,light)
			dot(p,-2,2,4,shade)
		3:
			dot(p,-5,0,2,shade)
			dot(p,4,0,2,shade)
			dot(p,-2,2,3,shade)

static func make_pictures() -> void:
	if not pictures.is_empty(): return
	for variant in range(8):
		var sizes: Array = []
		for level in range(1,6):
			var img = Image.create(40,20,false,Image.FORMAT_RGBA8)
			var mask: Dictionary = {}
			var growth = .24+level*.15
			# A fixed scalloped shoreline, varied in width/depth between patches.
			# Growth reveals more native pixels rather than scaling a texture.
			for y in range(20):
				for x in range(40):
					var dx = (x-19.5)/growth
					var dy = (y-9.5)/growth
					var nx = dx/(10.0+variant%4*2)
					var ny = dy/(4.0+variant%3)
					var angle = atan2(ny,nx)
					var shore = 1.0+.18*sin(angle*3+variant*1.7)+.12*cos(angle*5+variant*.9)
					if nx*nx+ny*ny <= shore*shore: mask[Vector2i(x,y)] = true
			for p in mask:
				var edge = not mask.has(p+Vector2i(0,1)) or not mask.has(p+Vector2i(1,0)) or not mask.has(p-Vector2i(1,0))
				var col = Color("354353") if edge else Color("485b70")
				if not mask.has(p-Vector2i(0,1)) and p.x%5 != 0: col = Color("657d92")
				col.a = .64 if edge else .58
				img.set_pixelv(p,col)
			# Restrained broken sky reflections, kept fixed through growth stages.
			for x in range(12+variant%6,17+variant%6):
				var p = Vector2i(x,7+variant%4)
				if mask.has(p) and mask.has(p+Vector2i(0,-1)): img.set_pixelv(p,Color(.48,.58,.67,.5))
			sizes.append(ImageTexture.create_from_image(img))
		pictures.append(sizes)
