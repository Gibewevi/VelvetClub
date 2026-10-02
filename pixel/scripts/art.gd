class_name Art
extends RefCounted

# Loads the generated pixel art (res://art, produced by tools/pixelart) and
# keeps textures, pixel data for picking and shared materials.

static var chars: Dictionary = {}
static var furniture: Dictionary = {}
static var tiles: Dictionary = {}
static var ui: Dictionary = {}
static var sanitary: Dictionary = {}
static var site: Dictionary = {}
static var textures: Dictionary = {}
static var images: Dictionary = {}
static var palette_shader: Shader
static var add_material: CanvasItemMaterial
static var ready = false

static func load_all() -> void:
	if ready: return
	chars = read("chars.json")
	furniture = read("furniture.json")
	tiles = read("tiles.json")
	ui = read("ui.json")
	sanitary = read("sanitary.json")
	site = read("site.json")
	palette_shader = load("res://shaders/palette.gdshader")
	add_material = CanvasItemMaterial.new()
	add_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	ready = true

static func read(name: String) -> Dictionary:
	var text = FileAccess.get_file_as_string("res://art/"+name)
	var data = JSON.parse_string(text)
	return data if data is Dictionary else {}

static func tex(path: String) -> Texture2D:
	if not textures.has(path): textures[path] = load("res://art/"+path)
	return textures[path]

static func image(path: String) -> Image:
	if not images.has(path):
		var t = tex(path)
		images[path] = t.get_image() if t != null else null
	return images[path]

static func alpha_at(path: String, p: Vector2i) -> bool:
	var img = image(path)
	if img == null or p.x < 0 or p.y < 0 or p.x >= img.get_width() or p.y >= img.get_height(): return false
	return img.get_pixel(p.x,p.y).a > 0.5

static func material(palette: Texture2D, index_scale: float = 4.0, size: float = 64.0) -> ShaderMaterial:
	var m = ShaderMaterial.new()
	m.shader = palette_shader
	m.set_shader_parameter("palette",palette)
	m.set_shader_parameter("index_scale",index_scale)
	m.set_shader_parameter("palette_size",size)
	m.set_shader_parameter("indexed",true)
	return m

static func rgba_material() -> ShaderMaterial:
	var m = ShaderMaterial.new()
	m.shader = palette_shader
	m.set_shader_parameter("indexed",false)
	return m

static func furniture_entry(kind: String, rot: int) -> Dictionary:
	if not furniture.has(kind): return {}
	return furniture[kind].get(str(posmod(rot,4)),{})

static func ui_texture(group: String, name: String, scale: int = 1) -> Texture2D:
	var key = "ui:%s:%s:%d" % [group,name,scale]
	if textures.has(key): return textures[key]
	var path: String = ui.get(group,{}).get(name,"")
	if path == "": return null
	var img: Image = image(path).duplicate()
	if scale > 1: img.resize(img.get_width()*scale,img.get_height()*scale,Image.INTERPOLATE_NEAREST)
	textures[key] = ImageTexture.create_from_image(img)
	return textures[key]
