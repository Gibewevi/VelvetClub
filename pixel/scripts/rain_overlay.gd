class_name RainOverlay
extends Node2D

var model: BuildingModel
var phase = 0.0
var strength = 0.0
var drawn_particles = 0
var world: Node2D
var drops: Array = []
var covered: Dictionary = {}    # metre cells under a roof: a drop over one is hidden
var drawn_key = []              # what the last drawing showed (drop time, camera, rain)

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

func layout_changed() -> void:
	covered.clear()
	if model == null: return
	for room in model.rooms:
		for c in BuildingModel.cells_of(room): covered[c] = true

func refresh() -> void:
	# Drops move 24 times a second: drawing them again in between (or while
	# paused, with nothing moving) only cost time.
	var key = [floori(phase*24.0) if strength > 0 else -1,get_canvas_transform().origin.round(),snappedf(strength,.01)]
	if key == drawn_key: return
	drawn_key = key
	queue_redraw()

func sheltered(pixel: Vector2) -> bool:
	# The cutaway interior includes objects above the floor, up to wall height.
	# (900 drops a frame: one lookup per height instead of a search of every room)
	if covered.is_empty() and model != null and not model.rooms.is_empty(): layout_changed()
	for height in range(0,Iso.WALL_H+1,8):
		var w = Iso.to_world(pixel+Vector2(0,height))
		if covered.has(Vector2i(floori(w.x),floori(w.y))): return true
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
