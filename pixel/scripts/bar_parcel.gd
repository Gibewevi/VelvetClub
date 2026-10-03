class_name BarParcel
extends Node2D

var world = Vector2.ZERO
var item_id = -3
func _init() -> void: set_meta("bar_parcel",true)
func set_world(at: Vector2) -> void:
	world = at
	position = Iso.pixel(at.x,at.y)
func _ready() -> void:
	var info: Dictionary = Art.read("delivery.json").box_0_1
	var sprite = Sprite2D.new()
	sprite.centered = false
	sprite.texture = Art.tex(info.file)
	sprite.offset = -Vector2(info.ox,info.oy)
	add_child(sprite)
func hit(_p: Vector2) -> bool: return false
func set_outline(_color: Color) -> void: pass
func pixel_bounds() -> Rect2: return Rect2(position-Vector2(10,14),Vector2(20,16))
