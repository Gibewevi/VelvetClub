class_name DeliveryProp
extends Actor

# Uses the same depth list as people, but a full vehicle footprint and bounds.
var body = Sprite2D.new()
var footprint = Rect2(-3.7,-1.3,8.7,2.6)
var art: Dictionary = {}
var warnings: Array = []
var vehicle_frame = ""

# The sprite generator supplies the visible lamps, in metres, so their halos
# stay on the fittings whenever the bodywork is redrawn.
const FALLBACK_LIGHTS = [
	{"x":-3.2,"y":2.85,"z":1.18,"color":"ff8014","blink":true,"power":0.38},
	{"x":-1.6,"y":3.28,"z":1.18,"color":"ff8014","blink":true,"power":0.38},
	{"x":3.45,"y":3.28,"z":1.18,"color":"ff8014","blink":true,"power":0.38},
	{"x":3.45,"y":3.28,"z":-1.18,"color":"ff8014","blink":true,"power":0.38},
]

func _init() -> void:
	add_child(body)
	body.centered = false
	art = Art.read("delivery.json")
	set_meta("delivery_vehicle",true)
	for lamp in art.get("_truck_lights",FALLBACK_LIGHTS):
		var p = Vector3(lamp.x,lamp.y,lamp.z)
		var tint = Color(lamp.get("color","ff8014"))
		tint.a = float(lamp.get("power",0.38))
		var glow = lamp_glow(tint)
		glow.position = (Iso.pixel(p.x,p.z)+Vector2(0,-p.y*24)).round()
		if lamp.get("blink",false): warnings.append(glow)
		if p.y < 1.5:
			# Low lamps reflect on the asphalt. Draw the pool behind the truck
			# instead of washing over the wheels and painted bodywork.
			tint.a *= 0.22
			var reflection = lamp_glow(tint)
			reflection.texture = Art.tex(Art.tiles.glows.glow_12_floor)
			reflection.position = Iso.pixel(p.x,p.z)
			move_child(reflection,0)
			if lamp.get("blink",false): warnings.append(reflection)

func lamp_glow(tint: Color) -> Sprite2D:
	var glow = Sprite2D.new()
	glow.texture = Art.tex(Art.tiles.glows.glow_12)
	glow.material = Art.add_material
	glow.modulate = tint
	add_child(glow)
	return glow

func show_frame(name: String) -> void:
	if name == vehicle_frame: return
	var info: Dictionary = art.get(name,{})
	if info.is_empty(): return
	vehicle_frame = name
	body.texture = Art.tex(info.file)
	body.offset = -Vector2(info.ox,info.oy)
	var bounds: Array = info.get("footprint",[-3.7,-1.3,8.7,2.6])
	footprint = Rect2(bounds[0],bounds[1],bounds[2],bounds[3])
	for light in warnings: light.visible = name.get_slice("_",2) == "1"

func pixel_bounds() -> Rect2:
	return Rect2(position+body.offset,body.texture.get_size()) if body.texture != null else Rect2()

func _process(_delta: float) -> void: pass
func hit(_p: Vector2) -> bool: return false
func set_outline(_color: Color) -> void: pass

