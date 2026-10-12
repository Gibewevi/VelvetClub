extends SceneTree

var checks = 0
var failures = 0
var test_saves = ClubSaves.new()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+message)

func write_fixture(path: String, data: Dictionary) -> void:
	var file = FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var folder = "user://front-end-tests-%d" % Time.get_ticks_usec()
	test_saves.folder = folder+"/clubs"
	test_saves.legacy_path = folder+"/pixel_club.json"
	var first = test_saves.new_path()
	check(first != "" and not FileAccess.file_exists(first),"New path does not overwrite or create a save prematurely")
	check(test_saves.new_path() != first,"Two new clubs get distinct paths")
	check(test_saves.list_saves().is_empty(),"Empty computer has no saves")
	check(ClubSaves.bypass_menu(PackedStringArray(["--capture=test.png"])),"Existing captures bypass the menu")
	check(ClubSaves.bypass_menu(PackedStringArray(["--smoke-test"])),"Existing smoke tests bypass the menu")
	check(not ClubSaves.bypass_menu(PackedStringArray([])),"Ordinary launch shows the intro")
	check(not ClubSaves.bypass_menu(PackedStringArray(["--front-end-test"])),"Menu test reaches the real menu")
	var boot = FrontEnd.new()
	boot.saves = test_saves
	root.add_child(boot)
	current_scene = boot
	await process_frame
	check(boot.phase == "intro" and boot.intro.visible,"Real intro appears at launch")
	check(not boot.menu.visible,"Menu stays hidden during the intro")
	check(boot.load_button.disabled,"Loading is disabled when no save exists")
	check(root.get_children().all(func(n): return not n.get_script() == load("res://scripts/main.gd")),"No club simulation is loaded behind the intro")
	boot.intro_time = FrontEnd.INTRO_SECONDS-.03
	await create_timer(.45).timeout
	check(boot.phase == "menu" and boot.menu.visible,"Intro automatically reaches the menu after its short duration")
	boot.phase = "intro"
	boot.intro.show()
	boot.intro.modulate.a = 1
	boot.intro_time = 0
	boot.menu.hide()
	var key = InputEventKey.new()
	key.pressed = true
	key.keycode = KEY_SPACE
	Input.parse_input_event(key)
	Input.flush_buffered_events()
	await create_timer(.45).timeout
	check(boot.phase == "menu" and not boot.intro.visible,"Any key skips the intro and completes its transition")
	check(boot.buttons[0].has_focus(),"Keyboard focus starts on New game")
	check(boot.menu_column.position.x+boot.menu_column.size.x <= boot.backdrop.position.x+213*boot.pixel_scale,"Menu buttons fit entirely inside the text panel at this resolution")
	# A click follows the same path and must not activate a menu action.
	boot.phase = "intro"
	boot.intro.show()
	boot.intro.modulate.a = 1
	boot.menu.hide()
	var click = InputEventMouseButton.new()
	click.pressed = true
	click.button_index = MOUSE_BUTTON_LEFT
	Input.parse_input_event(click)
	Input.flush_buffered_events()
	await create_timer(.45).timeout
	check(boot.phase == "menu" and boot.saves.list_saves().is_empty(),"Click skips without also starting a club")
	var model = BuildingModel.new()
	model.starter()
	var legacy = {"model":model.snapshot(),"club":{"day":8,"money":12345},"deliveries":{}}
	write_fixture(test_saves.legacy_path,legacy)
	var legacy_text = FileAccess.get_file_as_string(test_saves.legacy_path)
	var broken = test_saves.new_path()
	write_fixture(broken,{"model":null})
	var ignored = test_saves.folder+"/club_ignored.json.tmp"
	write_fixture(ignored,legacy)
	var entries = test_saves.list_saves()
	check(entries.size() == 2,"Only final saves and the legacy save are listed")
	check(entries.any(func(e): return e.path == test_saves.legacy_path and e.valid and e.day == 8 and e.money == 12345),"Legacy save is discoverable with its actual club statistics")
	check(entries.any(func(e): return e.path == broken and not e.valid),"Corrupt save is shown without silently replacing it")
	boot.refresh_saves()
	check(not boot.load_button.disabled,"Loading becomes available once a save exists")
	boot.show_load()
	check(boot.load_overlay != null,"Load button opens the save chooser")
	if "--front-end-ui-capture" in OS.get_cmdline_user_args():
		await create_timer(.2).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../build/Apercus-Accueil/chargement.png")
	check(not boot.load_saved(broken) and boot.phase == "menu","Corrupt save cannot launch a fresh club in its place")
	check(boot.last_error != "" and FileAccess.get_file_as_string(broken) == '{"model":null}',"Failed load displays an error and leaves the file untouched")
	check(not boot.load_saved(folder+"/missing.json"),"Save removed after listing is rejected without creating a club")
	boot.close_load()
	check(boot.load_overlay == null,"Return closes the chooser")
	check(boot.start_new(),"New game accepts a separate save path")
	check(not boot.start_new(),"Rapid repeated clicks cannot create another club during transition")
	await create_timer(.8).timeout
	var game = current_scene
	check(game != null and game.get_script() == load("res://scripts/main.gd"),"New game opens the real game scene")
	if game == null or game.get_script() != load("res://scripts/main.gd"):
		finish()
		return
	check(game.initialized,"Real game fully initializes")
	check(game.sim.money == ClubSim.START_MONEY and game.sim.day == 1,"New game starts with the balanced starter club")
	check(game.save_path.begins_with(test_saves.folder) and game.save_path != test_saves.legacy_path,"New game saves into its own slot")
	check(FileAccess.file_exists(game.save_path),"New club is saved immediately")
	check(FileAccess.get_file_as_string(test_saves.legacy_path) == legacy_text,"Starting a new club preserves the existing legacy save")
	var new_path: String = game.save_path
	game.sim.money = 17321
	game.sim.day = 12
	game.view.wall_mode = 1
	await game.set_zoom(3)
	game.return_to_menu()
	await create_timer(.2).timeout
	boot = current_scene
	check(boot is FrontEnd and boot.phase == "menu","Returning to the menu saves and skips the studio intro")
	boot.saves = test_saves
	boot.refresh_saves()
	var saved = test_saves.read(new_path)
	check(saved.has("data") and int(saved.data.club.money) == 17321,"Return to menu saved the latest balance")
	check(saved.has("data") and int(saved.data.club.day) == 12,"Return to menu saved the latest game day")
	check(boot.load_saved(new_path),"Saved new club can be selected")
	await create_timer(.8).timeout
	game = current_scene
	check(game.get_script() == load("res://scripts/main.gd") and game.initialized,"Load opens the real game")
	check(game.save_path == new_path and game.sim.money == 17321 and game.sim.day == 12,"Load restores the selected club, not an automatic starter")
	check(game.zoom == 3 and game.view.wall_mode == 1,"Load restores zoom and wall visibility")
	check(game.save_title != "" and test_saves.list_saves().size() == 3,"Save title persists and old clubs remain listed")
	check(FileAccess.get_file_as_string(test_saves.legacy_path) == legacy_text,"Loading another club preserves the legacy save")
	game.return_to_menu()
	await create_timer(.2).timeout
	boot = current_scene
	boot.saves = test_saves
	check(boot.load_saved(test_saves.legacy_path),"Legacy club is playable from the menu")
	await create_timer(.8).timeout
	game = current_scene
	check(game.save_path == test_saves.legacy_path and game.sim.money == 12345 and game.sim.day == 8,"Legacy club loads its saved state")
	game.return_to_menu()
	await create_timer(.2).timeout
	boot = current_scene
	boot.buttons[2].pressed.emit()
	check(boot.phase == "leaving","Quit button starts its actual exit transition")
	finish()

func finish() -> void:
	print("FRONT_END_TESTS checks=%d failures=%d" % [checks,failures])
	if failures == 0:
		print("FRONT_END_TESTS_PASSED")
		# Let the menu's real Quit action close the engine.
		if current_scene is FrontEnd and current_scene.phase == "leaving": return
	quit(0 if failures == 0 else 1)
