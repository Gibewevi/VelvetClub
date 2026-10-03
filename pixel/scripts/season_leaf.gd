class_name SeasonLeaf
extends Node2D

# A tiny world-space actor, participating in the existing depth order.
var world = Vector2.ZERO
var item_id = -2
var age = 0.0
var duration = 4.0
var height = 100.0
var variant = 0
var seed = 0
var land: Dictionary = {}

func advance(seconds: float) -> void:
	age += maxf(seconds,0)
	position = Iso.pixel(world.x,world.y)
	queue_redraw()

func offset() -> Vector2:
	var t = clampf(age/duration,0,1)
	return Vector2(round(sin(t*TAU+seed)*5.0*(1.0-t)),round(-height*(1.0-t)))

func pixel_bounds() -> Rect2:
	return Rect2(position+offset()-Vector2(4,3),Vector2(8,6))

func hit(_p: Vector2) -> bool: return false
func set_outline(_color: Color) -> void: pass

func _draw() -> void:
	SeasonEnvironment.draw_leaf(self,offset(),variant,int(age*3)%3)
