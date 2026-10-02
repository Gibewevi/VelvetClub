extends SceneTree

# Measures what one frame of rain costs on a given save (--probe-save=path):
# the shelter test of every falling drop, done for each drawn frame.

func _init() -> void:
	Art.load_all()
	var path = ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--probe-save="): path = arg.trim_prefix("--probe-save=")
	var model = BuildingModel.new()
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	print("RAIN_PROBE load ", model.load_checked(data.get("model")), " rooms ", model.rooms.size())
	var rain = RainOverlay.new()
	rain.setup(model)
	rain.strength = 1.0
	for round in range(3):
		var t0 = Time.get_ticks_usec()
		var tests = 0
		var sheltered = 0
		for drop in rain.drops:
			var p = rain.drop_position(drop)
			if not p.is_finite(): continue
			tests += 1
			if rain.sheltered(p): sheltered += 1
		print("RAIN_PROBE frame %.1f ms for %d falling drops (%d under a roof)" % [(Time.get_ticks_usec()-t0)/1000.0,tests,sheltered])
		rain.phase += 0.37
	rain.free()
	quit()
