class_name PlaceDust
extends Node2D

# A quick, soft puff of dust round the foot of an object just set down,
# moved or turned: the delivery van's tyre smoke, kept small and short so it
# reads as a little "pouf" and never hides the room. Two of these nodes live
# in the view: one under the furniture (puffs behind the object), one over it
# (puffs in front). Real time, so it plays even while the game is paused.

const MAX_PUFFS = 48
const SMALL_STEPS = [0,1,4,5]   # pop, small billow, wisps, last flecks
var puffs: Array = []

func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

static func points(r: Rect2) -> Array:
	# Where puffs start: the corners of the footprint, plus the middle of
	# long sides, each with the direction it drifts (outwards).
	var c = r.get_center()
	var inset = r.grow(-minf(0.08,minf(r.size.x,r.size.y)*0.2))
	var out: Array = []
	for corner in [inset.position,Vector2(inset.end.x,inset.position.y),inset.end,Vector2(inset.position.x,inset.end.y)]:
		out.append({"at":corner,"dir":(corner-c).normalized()})
	if r.size.x >= 1.5:
		out.append({"at":Vector2(c.x,inset.position.y),"dir":Vector2(0,-1)})
		out.append({"at":Vector2(c.x,inset.end.y),"dir":Vector2(0,1)})
	if r.size.y >= 1.5:
		out.append({"at":Vector2(inset.position.x,c.y),"dir":Vector2(-1,0)})
		out.append({"at":Vector2(inset.end.x,c.y),"dir":Vector2(1,0)})
	return out

func add(world: Vector2, frames: Array, offset: Vector2, delay: float, lifetime: float, drift: Vector2, rise: float, mirrored: bool) -> void:
	if puffs.size() >= MAX_PUFFS:
		puffs[0].sprite.queue_free()
		puffs.remove_at(0)
	var s = Sprite2D.new()
	s.texture = frames[0]
	s.centered = false
	s.offset = offset
	s.flip_h = mirrored
	s.visible = false
	add_child(s)
	puffs.append({"sprite":s,"world":world,"age":-delay,"lifetime":lifetime,"drift":drift,"rise":rise,"frames":frames,"stage":-1})

func _process(delta: float) -> void:
	for i in range(puffs.size()-1,-1,-1):
		var p: Dictionary = puffs[i]
		p.age += delta
		var s: Sprite2D = p.sprite
		if p.age >= p.lifetime:
			s.queue_free()
			puffs.remove_at(i)
			continue
		s.visible = p.age >= 0.0
		if not s.visible: continue
		var progress = float(p.age)/float(p.lifetime)
		var frames: Array = p.frames
		var stage = mini(frames.size()-1,int(progress*float(frames.size())))
		if stage != int(p.stage):
			p.stage = stage
			s.texture = frames[stage]
		# a short ease-out: quick at the start, settling at the end
		var travel = 1.0-pow(1.0-progress,2.0)
		var anchor: Vector2 = p.world+p.drift*travel
		s.position = Iso.pixel(anchor.x,anchor.y)+Vector2(0,-floorf(travel*float(p.rise)))
		s.modulate.a = .85 if progress < .6 else (.55 if progress < .82 else .25)

func clear() -> void:
	for p in puffs: p.sprite.queue_free()
	puffs.clear()
