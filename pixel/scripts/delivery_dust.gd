class_name DeliveryDust
extends Node2D

# Brief comic-book puffs, drawn in discrete pixel poses. Each new puff starts
# at a tyre, then stays in the street when the parent vehicle moves away.
const MAX_PUFFS = 32
const WHEEL_X = [-1.9,1.74]
const WHEEL_Z = [-1.25,1.25]
var puffs: Array = []

func _init() -> void:
	z_index = -1
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func burst(vehicle_world: Vector2, launching: bool) -> void:
	var clouds = DeliverySmokeArt.clouds()
	var flecks = DeliverySmokeArt.flecks()
	for axle in range(WHEEL_X.size()):
		for side in range(WHEEL_Z.size()):
			var outward = -1.0 if side == 0 else 1.0
			# The rear wheels leave a fuller little trail when pulling away.
			var count = (4 if axle == 1 else 2) if launching else 3
			for i in range(count):
				var variant = (i+axle+side)%clouds.size()
				var delay = float(i)*(.10 if launching else .21)
				var wheel_offset = Vector2(WHEEL_X[axle]+.20+float(i)*.13,WHEEL_Z[side]+outward*(.18+float(i)*.08))
				add_puff(vehicle_world,wheel_offset,clouds[variant],Vector2(-12,-17),delay,
					.78+float(variant)*.06,Vector2(.35+float(i)*.09,outward*(.20+float(i)*.04)),
					4.0,side,i%2 == 1)
			# Detached dots and short comic accents separate the rounded clouds.
			for i in range(2):
				var wheel_offset = Vector2(WHEEL_X[axle]+.20+float(i)*.38,WHEEL_Z[side]+outward*(.43+float(i)*.16))
				add_puff(vehicle_world,wheel_offset,flecks,Vector2(-4,-6),.06+float(i)*.17,
					.48+float(i)*.07,Vector2(.68+float(i)*.22,outward*.52),6.0,side,i == 1)
	step(0.0,vehicle_world)

func add_puff(vehicle_world: Vector2, wheel_offset: Vector2, frames: Array, offset: Vector2,
		delay: float, lifetime: float, drift: Vector2, rise: float, side: int, mirrored: bool) -> void:
	if puffs.size() >= MAX_PUFFS: remove_puff(0)
	var s = Sprite2D.new()
	s.texture = frames[0]
	s.centered = false
	s.offset = offset
	s.flip_h = mirrored
	# Far-side smoke stays behind the van. Near-side clouds may cover only
	# the base of the tyre; all particles retain native-sized pixel edges.
	s.z_index = 2 if side == 1 else 0
	s.visible = false
	add_child(s)
	puffs.append({
		"sprite":s,"world":vehicle_world+wheel_offset,"wheel_offset":wheel_offset,
		"age":-delay,"pending":delay > 0.0,"lifetime":lifetime,"drift":drift,
		"rise":rise,"frames":frames,"stage":0,
	})

func step(dt: float, vehicle_world: Vector2) -> void:
	var vehicle_pixel = Iso.pixel(vehicle_world.x,vehicle_world.y)
	for i in range(puffs.size()-1,-1,-1):
		var puff: Dictionary = puffs[i]
		puff.age += maxf(dt,0.0)
		if puff.age >= puff.lifetime:
			remove_puff(i)
			continue
		var s: Sprite2D = puff.sprite
		s.visible = puff.age >= 0.0
		if not s.visible: continue
		if puff.pending:
			# Delayed puffs are born at the moving wheel, then detach from it.
			puff.world = vehicle_world+puff.wheel_offset
			puff.pending = false
		var progress = float(puff.age)/float(puff.lifetime)
		var frames: Array = puff.frames
		var stage = mini(frames.size()-1,int(progress*float(frames.size())))
		if stage != int(puff.stage):
			puff.stage = stage
			s.texture = frames[stage]
		var anchor: Vector2 = puff.world+puff.drift*float(puff.age)
		s.position = Iso.pixel(anchor.x,anchor.y)-vehicle_pixel+Vector2(0,-floorf(progress*float(puff.rise)))
		# The drawing breaks into little lobes before fading. Hold solid pastel
		# colours through the pop instead of producing a translucent grey haze.
		s.modulate.a = 1.0 if progress < .72 else (.70 if progress < .88 else .35)

func remove_puff(index: int) -> void:
	var s: Sprite2D = puffs[index].sprite
	remove_child(s)
	s.queue_free()
	puffs.remove_at(index)

func clear_puffs() -> void:
	for i in range(puffs.size()-1,-1,-1): remove_puff(i)

func active_count() -> int:
	return puffs.size()
