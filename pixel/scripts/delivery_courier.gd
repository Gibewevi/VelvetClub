class_name DeliveryCourier
extends Actor

var parcel = Sprite2D.new()
var parcel_size = 0
var carrying = false
var unpacking = false
var art: Dictionary = {}
var simulation: ClubSim

func setup(index: int) -> void:
	kind = "courier"
	set_meta("courier",true)
	var app = Characters.defaults("janitor")
	app.outfit = "2469b0"
	app.glasses = 0
	app.face = 2
	app.skin = "e0ae8c" if index == 0 else "b98266"
	configure(app)
	speed = 3.4
	art = Art.read("delivery.json")
	parcel.centered = false
	add_child(parcel)
	parcel.visible = false

func cargo(size: int, carry: bool, opening: bool = false) -> void:
	parcel_size = size
	carrying = carry
	unpacking = opening
	parcel.visible = carry
	if not carry: return
	var name = "box_%d_%d" % [size,int(opening)] if size == 0 or opening else "cart_%d" % size
	var info: Dictionary = art[name]
	parcel.texture = Art.tex(info.file)
	parcel.offset = -Vector2(info.ox,info.oy)
	update_cargo()

func update_cargo() -> void:
	if not carrying: return
	var dir = Vector2(-1,0) if view == "back" else Vector2(0,1)
	if flip: dir = Vector2(0,-1) if view == "back" else Vector2(1,0)
	parcel.position = Iso.pixel(dir.x*.55,dir.y*.55)+Vector2(0,-21 if parcel_size == 0 and not unpacking else 0)
	parcel.z_index = -1 if view == "back" else 1

func _process(delta: float) -> void:
	super._process(delta*(simulation.speed if simulation != null else 1))
	update_cargo()

func hit(_p: Vector2) -> bool: return false

