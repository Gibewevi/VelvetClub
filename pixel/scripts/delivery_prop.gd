class_name DeliveryProp
extends Actor

# Uses the same depth list as people, but a full vehicle footprint and bounds.
var body = Sprite2D.new()
var footprint = Rect2(-2.94,-1.4,5.8,2.9)
var art: Dictionary = {}
var warnings: Array = []
var vehicle_frame = ""
var warning_enabled = false
var warning_paused = false
var warning_clock = 0.0
const WARNING_PERIOD = 2.6
var dust = DeliveryDust.new()
var requested_frame = ""
var moving_lights: Array = []
var motion_pitch = 0.0
var pitch_velocity = 0.0
var pitch_target = 0.0
const PITCH_LIMIT = PI/60.0

# The sprite generator supplies the visible lamps, in metres, so their halos
# stay on the fittings whenever the bodywork is redrawn.
const FALLBACK_LIGHTS = [
	{"x":-2.65,"y":.95,"z":1.02,"color":"ffad32","blink":true,"power":0.2},
	{"x":2.66,"y":.9,"z":.86,"color":"ffad32","blink":true,"power":0.2},
	{"x":2.66,"y":.9,"z":-.86,"color":"ffad32","blink":true,"power":0.2},
]

func _init() -> void:
	add_child(body)
	add_child(dust)
	body.centered = false
	art = Art.read("delivery.json")
	set_meta("delivery_vehicle",true)
	for lamp in art.get("_truck_lights",FALLBACK_LIGHTS):
		var p = Vector3(lamp.x,lamp.y,lamp.z)
		var tint = Color(lamp.get("color","ff8014"))
		tint.a = minf(float(lamp.get("power",0.2)),0.22 if lamp.get("blink",false) else 0.12)
		var glow = lamp_glow(tint)
		glow.position = (Iso.pixel(p.x,p.z)+Vector2(0,-p.y*24)).round()
		moving_lights.append({"node":glow,"point":p})
		if lamp.get("blink",false): register_warning(glow)
		if p.y < 1.5:
			# Low lamps reflect on the asphalt. Draw the pool behind the truck
			# instead of washing over the wheels and painted bodywork.
			tint.a *= 0.22
			var reflection = lamp_glow(tint)
			reflection.texture = Art.tex(Art.tiles.glows.glow_12_floor)
			reflection.position = Iso.pixel(p.x,p.z)
			move_child(reflection,0)
			if lamp.get("blink",false): register_warning(reflection)

func register_warning(light: Sprite2D) -> void:
	light.set_meta("warning_alpha",light.modulate.a)
	light.visible = false
	warnings.append(light)

func set_warning_lights(active: bool) -> void:
	if active and not warning_enabled: warning_clock = 0.0
	warning_enabled = active
	apply_warning_lights()

func apply_warning_lights() -> void:
	# Gentle continuous pulse; the painted van never switches between blink
	# sprites. This clock runs in real time, even at accelerated game speed.
	var strength = 0.15+0.85*(0.5-0.5*cos(TAU*warning_clock/WARNING_PERIOD))
	for light in warnings:
		light.visible = warning_enabled
		var tint: Color = light.modulate
		tint.a = float(light.get_meta("warning_alpha"))*strength
		light.modulate = tint

func lamp_glow(tint: Color) -> Sprite2D:
	var glow = Sprite2D.new()
	glow.texture = Art.tex(Art.tiles.glows.glow_12)
	glow.material = Art.add_material
	glow.modulate = tint
	add_child(glow)
	return glow

func show_frame(name: String) -> void:
	requested_frame = name
	apply_drive_frame()

func apply_drive_frame() -> void:
	var name = requested_frame
	if name == "": return
	# Only the closed vehicle rocks. These poses are drawn at native pixel
	# resolution with stationary wheels, rather than rotating a whole bitmap.
	if name.begins_with("truck_0_"):
		var pose = clampi(roundi(absf(rad_to_deg(motion_pitch))),0,3)
		if pose > 0:
			var candidate = "truck_%s_%d" % ["brake" if motion_pitch > 0 else "launch",pose]
			if art.has(candidate): name = candidate
	if name == vehicle_frame: return
	var info: Dictionary = art.get(name,{})
	if info.is_empty(): return
	vehicle_frame = name
	body.texture = Art.tex(info.file)
	body.offset = -Vector2(info.ox,info.oy)
	var bounds: Array = info.get("footprint",[-2.94,-1.4,5.8,2.9])
	footprint = Rect2(bounds[0],bounds[1],bounds[2],bounds[3])
	var angle = float(info.get("pitch",0.0))
	for lamp in moving_lights:
		var p: Vector3 = lamp.point
		var x = cos(angle)*p.x-sin(angle)*(p.y-.46)
		var y = .46+sin(angle)*p.x+cos(angle)*(p.y-.46)
		lamp.node.position = (Iso.pixel(x,p.z)+Vector2(0,-y*24)).round()

func set_drive_state(phase: String, speed_now: float, acceleration: float, _settle_age: float) -> void:
	# Acceleration compresses the rear suspension; braking dips the nose.
	pitch_target = clampf(-acceleration/14.0,-1.0,1.0)*deg_to_rad(2.5) if phase in ["arrive","depart"] else 0.0
	if phase in ["idle","waiting","unload","close"]:
		motion_pitch = 0.0
		pitch_velocity = 0.0
	if speed_now == 0 and phase == "arrive": pitch_target = 0.0
	dust.step(0.0,world)
	apply_drive_frame()

func step_effects(dt: float) -> void:
	if dt <= 0: return
	# Exact damped spring solution: stable at every game speed and frame rate.
	# The damped recoil settles during the pause before the rear doors open.
	const OMEGA = 16.0
	const DAMPING = 6.72
	var frequency = sqrt(OMEGA*OMEGA-DAMPING*DAMPING)
	var displacement = motion_pitch-pitch_target
	var decay = exp(-DAMPING*dt)
	var c = cos(frequency*dt)
	var s = sin(frequency*dt)
	var previous_velocity = pitch_velocity
	motion_pitch = pitch_target+decay*(displacement*c+(previous_velocity+DAMPING*displacement)*s/frequency)
	pitch_velocity = decay*(previous_velocity*c-(DAMPING*previous_velocity+OMEGA*OMEGA*displacement)*s/frequency)
	if absf(motion_pitch) > PITCH_LIMIT:
		motion_pitch = clampf(motion_pitch,-PITCH_LIMIT,PITCH_LIMIT)
		pitch_velocity = 0.0
	if absf(motion_pitch) < .0003 and absf(pitch_velocity) < .002 and pitch_target == 0:
		motion_pitch = 0.0
		pitch_velocity = 0.0
	dust.step(dt,world)
	apply_drive_frame()

func play_brake() -> void:
	dust.burst(world,false)

func play_launch() -> void:
	dust.burst(world,true)

func reset_drive_effects() -> void:
	motion_pitch = 0.0
	pitch_velocity = 0.0
	pitch_target = 0.0
	dust.clear_puffs()
	apply_drive_frame()

func pixel_bounds() -> Rect2:
	return Rect2(position+body.offset,body.texture.get_size()) if body.texture != null else Rect2()

func _process(delta: float) -> void:
	if not warning_enabled or not visible or warning_paused: return
	warning_clock = fmod(warning_clock+delta,WARNING_PERIOD)
	apply_warning_lights()
func hit(_p: Vector2) -> bool: return false
func set_outline(_color: Color) -> void: pass

