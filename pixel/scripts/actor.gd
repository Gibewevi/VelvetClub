class_name Actor
extends Node2D

# A character made of stacked 32 x 48 px layers sharing one palette.
# World position is (x, z) in metres; the sprite anchor is the feet.
const FPS = {"idle":2.0,"walk":8.0,"sit":1.0,"dance":6.0,"mop":5.0,"work":3.0,"stand":0.0,"kneel":1.5}
var item_id = -1
var brain: Dictionary = {}
var kind = ""
var appearance: Dictionary = {}
var world = Vector2.ZERO
var view = "front"
var flip = false
var anim = "idle"
var frame_i = 0
var clock = 0.0
var layers: Array = []
var files: Array = []
var mat: ShaderMaterial
var path: Array = []
var speed = 1.7
var lift = 0
var moving = false
var bubble: Sprite2D
var bubble_time = 0.0
var shadow: Sprite2D
static var shadow_tex: Texture2D
var carry: Sprite2D               # a rubbish bag in hand (a maid on her way to the containers)
static var bag_tex: Texture2D

func configure(app: Dictionary) -> void:
	appearance = app
	for s in layers:
		remove_child(s)
		s.queue_free()
	layers.clear()
	if shadow == null:
		shadow = Sprite2D.new()
		shadow.texture = shadow_texture()
		shadow.position = Vector2(0,-1)
		add_child(shadow)
	mat = Art.material(Characters.palette(app))
	files = Characters.layers(app)
	for file in files:
		var s = Sprite2D.new()
		s.texture = Art.tex(file)
		s.hframes = int(Art.chars.frames)
		s.centered = false
		s.offset = Vector2(-16,-46)
		s.material = mat
		add_child(s)
		layers.append(s)
	apply_frame()

static func shadow_texture() -> Texture2D:
	if shadow_tex == null:
		var img = Image.create(14,5,false,Image.FORMAT_RGBA8)
		for y in range(5):
			for x in range(14):
				if pow((x+0.5-7.0)/7.0,2)+pow((y+0.5-2.5)/2.5,2) <= 1.0: img.set_pixel(x,y,Color(0.08,0.04,0.1,0.38))
		shadow_tex = ImageTexture.create_from_image(img)
	return shadow_tex

func set_world(p: Vector2) -> void:
	world = p
	position = Iso.pixel(p.x,p.y)+Vector2(0,-lift)
	if shadow != null:
		# on the floor only: sitting or dancing up on furniture, that casts its own
		shadow.position = Vector2(0,lift-1)
		shadow.visible = lift <= 0

func face(dir: Vector2) -> void:
	if dir.length() < 0.001: return
	if absf(dir.x) >= absf(dir.y):
		view = "front" if dir.x >= 0 else "back"
		flip = dir.x < 0
	else:
		view = "front" if dir.y >= 0 else "back"
		flip = dir.y >= 0
	apply_frame()

func play(name: String) -> void:
	if anim == name: return
	anim = name
	frame_i = 0
	clock = 0.0
	apply_frame()

func frames() -> Array:
	var key = "%s:%s" % [view,anim]
	if Art.chars.anims.has(key): return Art.chars.anims[key]
	if Art.chars.anims.has("front:"+anim): return Art.chars.anims["front:"+anim]
	return Art.chars.anims["%s:idle" % view]

func current_frame() -> int:
	var list = frames()
	return int(list[frame_i % list.size()])

func apply_frame() -> void:
	var f = current_frame()
	for s in layers:
		s.frame = f
		s.flip_h = flip
	# Flipped sprites mirror around the anchor column.
	for s in layers: s.offset = Vector2(-16 if not flip else -16,-46)
	place_carry()

func set_carry(on: bool) -> void:
	# a rubbish bag in hand, on the way to the containers outside
	if not on:
		if carry != null: carry.visible = false
		return
	if carry == null:
		carry = Sprite2D.new()
		carry.texture = bag_texture()
		carry.centered = false
		add_child(carry)
	carry.visible = true
	place_carry()

func place_carry() -> void:
	# held at her side, down by the hip, on the side away from the viewer's
	# eye line so it always shows beside her
	if carry == null or not carry.visible: return
	carry.position = Vector2(4 if not flip else -11,-17)
	move_child(carry,get_child_count()-1)

static func bag_texture() -> Texture2D:
	if bag_tex == null:
		var rows = ["..t.t..","...t...",".#####.","##hh##o","#hh###o","#h####o","######o","######o",".ooooo."]
		var colors = {"#":Color("56627a"),"h":Color("8c98ae"),"o":Color("2c3242"),"t":Color("e8c440")}
		var img = Image.create(7,rows.size(),false,Image.FORMAT_RGBA8)
		for y in range(rows.size()):
			for x in range(7):
				var ch = rows[y][x]
				if colors.has(ch): img.set_pixel(x,y,colors[ch])
		bag_tex = ImageTexture.create_from_image(img)
	return bag_tex

func advance_animation(delta: float) -> void:
	clock += delta*FPS.get(anim,2.0)
	if clock >= 1.0:
		var count = floori(clock)
		clock = fmod(clock,1.0)
		frame_i = (frame_i+count) % frames().size()
		apply_frame()

func _process(delta: float) -> void:
	# The resting kneel follows simulation time, including pause and speed controls.
	if anim != "kneel": advance_animation(delta)
	if bubble != null:
		bubble_time -= delta
		bubble.position.y = -54-lift*0+sin(bubble_time*4.0)*1.0
		bubble.position = bubble.position.round()
		if bubble_time <= 0:
			bubble.queue_free()
			bubble = null

func step(delta: float, time_scale: float) -> bool:
	# Advance along the path; returns true when the path is finished.
	if anim == "kneel": advance_animation(delta*time_scale)
	if path.is_empty():
		moving = false
		return true
	moving = true
	lift = 0
	var remaining = speed*delta*time_scale
	while remaining > 0 and not path.is_empty():
		var target: Vector2 = path[0]
		var d = world.distance_to(target)
		if d <= remaining:
			face(target-world)
			set_world(target)
			remaining -= d
			path.remove_at(0)
		else:
			var dir = (target-world)/d
			face(dir)
			set_world(world+dir*remaining)
			remaining = 0
	play("walk")
	if path.is_empty():
		moving = false
		return true
	return false

func hit(p: Vector2) -> bool:
	var local = p-position+Vector2(16,46)
	var lx = int(floor(local.x))
	var ly = int(floor(local.y))
	if lx < 0 or ly < 0 or lx >= 32 or ly >= 48: return false
	if flip: lx = 31-lx
	var f = current_frame()
	for file in files:
		if Art.alpha_at(file,Vector2i(f*32+lx,ly)): return true
	return false

func set_outline(color: Color) -> void:
	if mat != null: mat.set_shader_parameter("outline_color",color)

func set_tint(color: Color) -> void:
	if mat != null: mat.set_shader_parameter("tint",color)

func emote(icon: String, seconds: float = 2.5) -> void:
	if bubble != null: bubble.queue_free()
	bubble = Sprite2D.new()
	bubble.texture = Art.ui_texture("emotes",icon)
	if bubble.texture == null:
		bubble.queue_free()
		bubble = null
		return
	bubble.position = Vector2(0,-54)
	# bubbles float above everything, never cut by a wall or a backrest
	bubble.z_as_relative = false
	bubble.z_index = 3950
	add_child(bubble)
	bubble_time = seconds
