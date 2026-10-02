class_name RoomShape
extends RefCounted

# The floor of a room: its first rectangle plus every extension merged into
# it (an L, a T…). It answers the questions code used to ask a Rect2
# (has_point, grow, position / end / size, get_center), so an extended room
# works wherever a rectangular one did. grow(-m) keeps the points at least m
# metres from the outline of the whole union, not of each rectangle.

const AROUND = [Vector2(1,0),Vector2(-1,0),Vector2(0,1),Vector2(0,-1),Vector2(1,1),Vector2(1,-1),Vector2(-1,1),Vector2(-1,-1)]
var rects: Array = []
var margin = 0.0
var position = Vector2.ZERO
var end = Vector2.ZERO
var size = Vector2.ZERO

static func of(room: Dictionary) -> RoomShape:
	var s = RoomShape.new()
	s.rects = BuildingModel.parts_of(room)
	s.update_bounds()
	return s

func update_bounds() -> void:
	var b: Rect2 = rects[0]
	for r in rects: b = b.merge(r)
	b = b.grow(-margin)
	position = b.position
	end = b.end
	size = b.size

func covers(p: Vector2) -> bool:
	for r in rects:
		if (r as Rect2).has_point(p): return true
	return false

func has_point(p: Vector2) -> bool:
	if not covers(p): return false
	if margin <= 0.0: return true
	for d in AROUND:
		if not covers(p+d*margin): return false
	return true

func grow(by: float) -> RoomShape:
	var s = RoomShape.new()
	s.rects = rects
	s.margin = margin-by
	s.update_bounds()
	return s

func get_center() -> Vector2:
	# the centre of the largest rectangle: always on the floor
	var best: Rect2 = rects[0]
	for r in rects:
		if (r as Rect2).get_area() > best.get_area(): best = r
	return best.get_center()

func intersects(r: Rect2) -> bool:
	for q in rects:
		if (q as Rect2).grow(-margin).intersects(r): return true
	return false
