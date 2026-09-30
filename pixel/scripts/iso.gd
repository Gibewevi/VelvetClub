class_name Iso
extends RefCounted

# One 1 m floor cell is a 32 x 16 px diamond; one metre of height is 24 px.
# Must match tools/pixelart/pa_core.py.
const HW := 16.0
const HH := 8.0
const PY := 24.0
const WALL_H := 56
const LOW_H := 12
const LOT := 24

static func to_screen(x: float, z: float, y: float = 0.0) -> Vector2:
	return Vector2(HW*(x-z), HH*(x+z)-PY*y)

static func pixel(x: float, z: float, y: float = 0.0) -> Vector2:
	return to_screen(x,z,y).round()

static func to_world(p: Vector2) -> Vector2:
	# Screen pixel position -> (x, z) on the floor plane.
	return Vector2((p.x/HW+p.y/HH)/2.0,(p.y/HH-p.x/HW)/2.0)

static func diamond(x0: float, z0: float, x1: float, z1: float) -> PackedVector2Array:
	return PackedVector2Array([to_screen(x0,z0),to_screen(x1,z0),to_screen(x1,z1),to_screen(x0,z1)])
