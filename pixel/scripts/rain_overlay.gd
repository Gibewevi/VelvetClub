class_name RainOverlay
extends Node2D

var model: BuildingModel
var phase = 0.0
var strength = 0.0
var drawn_particles = 0
var world: Node2D
var drops: Array = []

func setup(building: BuildingModel) -> void:
	model = building
	var rng = RandomNumberGenerator.new()
	rng.seed = 20260957
	drops.clear()
	for i in range(900):
		var p = Vector2(rng.randf_range(-Iso.LOT,Iso.LOT),rng.randf_range(-Iso.LOT,Iso.LOT))
		drops.append({"base":Iso.pixel(p.x,p.y),"offset":rng.randf_range(0,3),"period":rng.randf_range(1.35,2.8),"flight":rng.randf_range(.65,1.15),"height":rng.randf_range(60,92),"wind":rng.randf_range(5,12),"rank":rng.randf()})

func drop_position(drop: Dictionary) -> Vector2:
	# This is a WORLD pixel position. The camera only projects/culls it.
	# An idle gap between falls also prevents a regularly spaced dotted curtain.
	var time = floor(phase*24.0)/24.0
	var age = fposmod(time+float(drop.offset),float(drop.period))
	if age >= float(drop.flight): return Vector2.INF
	var progress = age/float(drop.flight)
	return (drop.base+Vector2(float(drop.wind)*(1-progress),-float(drop.height)*(1-progress))).round()

func step(seconds: float, intensity: float) -> void:
	phase = fposmod(phase+seconds,960.0)
	strength = intensity
	if world != null:
		world.rain_ground.step(seconds,intensity)
		world.weather_shade(intensity)
	queue_redraw()

func sheltered(pixel: Vector2) -> bool:
	# The cutaway interior includes objects above the floor, up to wall height.
	for height in range(0,Iso.WALL_H+1,8):
		if not model.room_at(Iso.to_world(pixel+Vector2(0,height))).is_empty(): return true
	return false

func _draw() -> void:
	drawn_particles = 0
	if model == null or strength <= 0: return
	var screen = get_viewport_rect().size
	var inverse = get_canvas_transform().affine_inverse()
	var visible_box = Rect2(inverse*Vector2.ZERO,inverse*screen-inverse*Vector2.ZERO).grow(5)
	for drop in drops:
		if drop.rank > strength: continue
		var p = drop_position(drop)
		if not p.is_finite() or not visible_box.has_point(p) or sheltered(p): continue
		drawn_particles += 1
		# Whole-pixel rectangles stay visible with snapped canvas vertices.
		draw_rect(Rect2(p,Vector2(1,2)),Color(.65,.75,.88,.55))
		draw_rect(Rect2(p+Vector2(-1,2),Vector2(1,2)),Color(.65,.75,.88,.55))
