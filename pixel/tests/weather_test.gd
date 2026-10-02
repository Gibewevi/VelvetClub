extends SceneTree

var checks = 0
var failures = 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+message)

func _init() -> void:
	run.call_deferred()

func covered_area(weather: RainGround) -> int:
	var total = 0
	for patch in weather.patches:
		if patch.exposed: total += weather.stage(patch)
	return total

func run() -> void:
	Art.load_all()
	var model = BuildingModel.new()
	model.add_room(-5,-4,10,8,0)
	var view = WorldView.new()
	root.add_child(view)
	view.setup(model)
	var sim = ClubSim.new()
	root.add_child(sim)
	sim.setup(model,view)
	sim.active = false
	var water = view.rain_ground
	check(water.patches.size() == RainGround.PATCH_COUNT,"Fixed bounded puddle pool")
	var falling = view.rain
	falling.phase = 2.0
	var visible = falling.drops.filter(func(d): return falling.drop_position(d).is_finite())
	check(visible.size() > 50,"Random drops have independently staggered falls")
	var drop: Dictionary = visible[0]
	var fixed: Vector2 = falling.drop_position(drop)
	var original_transform = root.canvas_transform
	root.canvas_transform = Transform2D(0,Vector2(-91,53))
	check(falling.drop_position(drop) == fixed,"Moving camera never changes drop world positions")
	root.canvas_transform = original_transform
	var periods: Dictionary = {}
	var positions: Dictionary = {}
	for d in falling.drops:
		periods[int(d.period*1000)] = true
		positions[d.base] = true
	check(periods.size() > 100 and positions.size() > 850,"Random spacing and fall rhythms prevent ordered rain lines")
	falling.phase = 0
	check(water.impacts.size() == RainGround.IMPACT_COUNT,"Fixed bounded impact pool")
	check(covered_area(water) == 0,"Dry weather starts without water")
	check(not water.exposed(Vector2.ZERO,.1),"Interior has no ground rain")
	check(not water.exposed(Vector2(5.1,0),.8),"Puddle footprint cannot cross a wall")
	check(water.exposed(Vector2(15,14),.8),"Street is exposed")
	var original: Vector2 = water.patches[0].pixel
	view.rain.step(4,.8)
	var early = covered_area(water)
	check(early > 0 and water.wetness > 0,"Early rain creates small scattered puddles")
	view.rain.step(20,.8)
	check(covered_area(water) > early*2,"Puddles grow and more patches fill during rain")
	check(water.patches[0].pixel == original,"Water stays anchored to the world")
	check(view.ground.modulate.r < 1 and view.ground.modulate.r > .8,"Exterior is gently darkened")
	check(view.floors.modulate == Color.WHITE and view.floors.get_child(0).modulate == Color.WHITE,"Interior lighting stays unchanged")
	check(sim.dirt.is_empty(),"Weather water creates no indoor cleaning jobs")
	var grown = water.wetness
	view.rain.step(12,0)
	check(water.wetness < grown and water.wetness > 0,"Water dries gradually after the shower")
	check(view.ground.modulate == Color.WHITE,"Outdoor light returns when rain stops")
	sim.rain_strength = .7
	sim.weather_remaining = 150
	var saved = sim.to_dict()
	var saved_phase = water.phase
	var saved_wetness = water.wetness
	water.step(10,1)
	sim.from_dict(saved)
	check(is_equal_approx(water.wetness,saved_wetness) and water.phase == saved_phase,"Save restores wetness and impact animation phase")
	check(sim.rain_strength == .7 and sim.weather_remaining == 150,"Save preserves current weather and next change")
	sim.active = true
	sim.speed = 0
	sim._process(10)
	check(water.wetness == saved_wetness and water.phase == saved_phase,"Pause freezes water and impacts")
	sim.speed = 1
	sim._process(1)
	check(water.wetness > saved_wetness and water.phase > saved_phase,"Normal simulation advances weather effects")
	var wet_before_fast = water.wetness
	sim.speed = 3
	sim._process(1)
	check(is_equal_approx(water.wetness-wet_before_fast,.7*3/36.0),"Fast forward uses game time")
	var usable = water.patches.filter(func(p): return p.exposed and p.world.y < 6)
	check(not usable.is_empty(),"Random puddles exist on private outdoor land")
	var candidate: Dictionary = usable[0]
	var p: Vector2 = candidate.world
	model.add_room(floor(p.x)-1,floor(p.y)-1,3,3,0)
	var wet_before_rebuild = water.wetness
	view.rebuild()
	check(not candidate.exposed,"Building over a puddle immediately shelters it")
	check(water.wetness == wet_before_rebuild,"Construction retains weather accumulation")
	check(water.patches[0].pixel == original,"Construction keeps random positions stable")
	water.from_dict({"wetness":NAN,"phase":"bad"})
	check(water.wetness == 0 and water.phase == 0,"Malformed weather ground save is rejected")
	water.from_dict({"wetness":100,"phase":-1})
	check(water.wetness == 1 and water.phase == 0,"Loaded effects stay within bounds")
	sim.from_dict({"weather":{"rain":.5}})
	check(water.wetness == 0,"Older weather saves start with dry ground")
	water.step(200,0)
	check(water.wetness == 0,"Puddles eventually disappear")
	var pixel_counts: Array = []
	for tex in RainGround.pictures[0]:
		var img: Image = tex.get_image()
		var count = 0
		for y in range(img.get_height()):
			for x in range(img.get_width()):
				if img.get_pixel(x,y).a > 0: count += 1
		pixel_counts.append(count)
	for i in range(1,pixel_counts.size()): check(pixel_counts[i] > pixel_counts[i-1],"Native pixel puddle silhouettes grow monotonically")
	check(RainGround.pictures.size() == 8,"Eight asymmetric puddle shapes")
	print("WEATHER_CHECKS: %d failures: %d" % [checks,failures])
	if failures == 0: print("WEATHER_TESTS_PASSED")
	quit(0 if failures == 0 else 1)
