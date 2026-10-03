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

func run() -> void:
	check(ClubSeasons.date(1) == {"day":1,"month":4,"year":1},"A new club begins on 1 April")
	check(ClubSeasons.date(31).month == 5 and ClubSeasons.date(62).month == 6,"Month lengths follow the real calendar")
	check(ClubSeasons.date(276) == {"day":1,"month":1,"year":2},"December rolls into the next year")
	check(ClubSeasons.month_days(2,4) == 29 and ClubSeasons.month_days(2,100) == 28 and ClubSeasons.month_days(2,400) == 29,"Leap years include century exceptions")
	check(ClubSeasons.date(146098) == {"day":1,"month":4,"year":401},"Long-running clubs use bounded 400-year calendar cycles")
	for d in range(1,733):
		var before = ClubSeasons.state(d,1439.999)
		var after = ClubSeasons.state(d+1,0)
		for key in ["autumn","loss","snow"]:
			check(absf(before[key]-after[key]) < .00001,"Daily and monthly transitions are continuous")
	check(ClubSeasons.state(1).loss == 0 and ClubSeasons.state(1).snow == 0,"Spring starts green and snow-free")
	check(ClubSeasons.state(300).loss == 1 and ClubSeasons.state(300).snow == 1,"Midwinter has full snow and dormant trees")
	Art.load_all()
	var manifest = Art.read("seasons.json")
	check(manifest.size() == 12,"Every lawn, tree, pit and shrub has a seasonal layer")
	for name_key in manifest:
		var spec: Dictionary = manifest[name_key]
		for path in [spec.mask,spec.snow]+([spec.bare] if spec.has("bare") else []):
			check(Art.tex(path) != null,"Seasonal native texture imports: "+path)
	var model = BuildingModel.new()
	model.starter()
	var view = WorldView.new()
	root.add_child(view)
	view.setup(model)
	var env = view.seasons
	check(env.plants.size() > 10 and env.plants.any(func(p): return p.tree),"Imported JSON kinds register real trees and shrubs for leaf fall")
	var plant_count = env.plants.size()
	env.step(0,195,1080)
	check(env.fallen.size() > 20 and env.fallen.size() <= SeasonEnvironment.MAX_LEAVES,"Autumn progressively accumulates visible outdoor leaves")
	check(env.fallen.all(func(l): return model.room_at(Vector2(l.x,l.z)).is_empty()),"Deposits never appear inside a room")
	var saved = JSON.parse_string(JSON.stringify(env.to_dict()))
	var positions = env.fallen.map(func(l): return Vector2(l.x,l.z))
	view.rebuild()
	check(env.plants.size() == plant_count and env.fallen.map(func(l): return Vector2(l.x,l.z)) == positions,"Rebuilding preserves exact leaf positions and does not multiply emitters")
	check(env.materials.all(func(mat): return is_equal_approx(float(mat.get_shader_parameter("autumn")),float(env.current.autumn))),"Newly rebuilt surfaces retain the current seasonal colors")
	env.from_dict(saved)
	env.step(0,195,1080)
	check(env.fallen.size() == positions.size(),"Loading does not deposit the same autumn leaves twice")
	check(env.fallen.map(func(l): return Vector2(l.x,l.z)) == positions,"Leaf positions survive the real JSON representation")
	var before = env.fallen.size()
	env.step(0,215,1080)
	check(env.fallen.size() > before,"Later autumn accumulates more leaves")
	env.step(.5,220,1080)
	check(env.falling.size() > 0 and env.falling.size() <= SeasonEnvironment.MAX_FALLING,"A few leaves visibly fall with a bounded particle count")
	var during_fall = JSON.parse_string(JSON.stringify(env.to_dict()))
	check(during_fall.fallen.size() >= env.fallen.size(),"Saving accounts for leaves still in flight")
	var actor = env.falling[0]
	var footprint: Rect2 = actor.pixel_bounds()
	check(footprint.size.x <= 8 and not actor.hit(Vector2.ZERO),"Falling leaf sprites are tiny and cannot intercept player selections")
	env.step(20,220,1100)
	check(env.falling.is_empty(),"Fallen leaf actors land and leave the depth-order actor list")
	env.step(0,300,1080)
	check(not env.fallen.is_empty(),"Winter snow hides leaves without deleting their persistent locations")
	env.step(0,500,1080)
	check(env.fallen.is_empty(),"Old leaf litter decomposes gradually by the next summer")
	env.from_dict({"year":"bad","counts":{"x":"wrong"},"fallen":[null,{}, {"x":INF,"z":0,"day":1,"variant":0}]})
	check(env.fallen.is_empty() and env.counts.is_empty(),"Malformed optional seasonal save data is ignored safely")
	env.step(0,195,0)
	var cash = ClubSim.new()
	cash.day = 195
	cash.minute = 0
	cash.saved_seasons = env.to_dict()
	var restored = ClubSim.new()
	restored.from_dict(JSON.parse_string(JSON.stringify(cash.to_dict())))
	check(restored.day == 195 and restored.saved_seasons.fallen.size() == env.fallen.size(),"Club save links the month and accumulated exterior leaves")
	cash.free()
	restored.free()
	env.reset()
	env.update_date(1,1080)
	check(env.fallen.is_empty() and env.falling.is_empty() and env.current.snow == 0,"New club clears previous winter and leaf litter")
	print("SEASONS_TESTS: %d checks, %d failures" % [checks,failures])
	if failures == 0: print("SEASONS_TESTS_PASSED")
	quit(1 if failures else 0)
