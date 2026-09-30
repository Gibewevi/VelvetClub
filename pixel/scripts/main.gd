extends Node

# Pixel-art club management game. The world is drawn in native pixels inside
# a SubViewport and enlarged by an integer factor; the interface is drawn on
# top with pixel textures enlarged the same way.
var model = BuildingModel.new()
var view: WorldView
var sim: ClubSim
var deliveries: Deliveries
var hud: Hud
var container: SubViewportContainer
var viewport: SubViewport
var camera: Camera2D
var ui_layer: CanvasLayer
var zoom = 2
var mode = "select"
var room_type = 0
var chosen_item = "sofa"
var look_rng = RandomNumberGenerator.new()
var placement_rotation = 0
var parking_rotation = 1
var parking_pointer = Vector2.ZERO
var placement_appearance: Dictionary = {}
var selected_room = -1
var selected_item = -1
var selected_edge = ""
var selected_parking = -1
var selected_client: Actor = null
var moving_item = -1
var drag: Dictionary = {}
var undo_stack: Array = []
var redo_stack: Array = []
var panning = false
var save_path = "user://pixel_club.json"
var legacy_path = "user://building.json"
var save_timer: Timer
var autosave_timer: Timer
var save_status = "Sauvegarde automatique active"
var initialized = false
var test_mode = false
var failures = 0
var night_report: Dictionary = {}

func _ready() -> void:
	get_tree().auto_accept_quit = false
	Art.load_all()
	var args = OS.get_cmdline_user_args()
	test_mode = "--smoke-test" in args or "--ui-test" in args or "--sim-test" in args or "--delivery-test" in args
	# Screenshots always start from the fresh club and never write a save.
	for arg in args:
		if arg.begins_with("--capture="): test_mode = true
	if test_mode: save_path = "user://pixel_test.json"
	var bad_save = false
	var club_data = {}
	var delivery_data = {}
	model.starter()
	if not test_mode and FileAccess.file_exists(save_path):
		var data = JSON.parse_string(FileAccess.get_file_as_string(save_path))
		if data is Dictionary and model.load_checked(data.get("model")):
			club_data = data.get("club",{})
			if data.get("deliveries") is Dictionary: delivery_data = data.deliveries
		else:
			bad_save = true
			model.starter()
	var screen = DisplayServer.screen_get_size()
	var ui_scale = 3 if DisplayServer.window_get_size().x >= 2400 else 2
	UiKit.setup(ui_scale)
	container = SubViewportContainer.new()
	container.stretch = true
	container.stretch_shrink = zoom
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)
	viewport = SubViewport.new()
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	viewport.snap_2d_transforms_to_pixel = true
	viewport.snap_2d_vertices_to_pixel = true
	viewport.handle_input_locally = false
	container.add_child(viewport)
	view = WorldView.new()
	viewport.add_child(view)
	view.setup(model)
	camera = Camera2D.new()
	camera.anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT
	viewport.add_child(camera)
	camera.make_current()
	sim = ClubSim.new()
	add_child(sim)
	sim.from_dict(club_data)
	sim.setup(model,view)
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 10
	add_child(ui_layer)
	hud = Hud.new()
	ui_layer.add_child(hud)
	hud.build(self)
	deliveries = Deliveries.new()
	add_child(deliveries)
	deliveries.setup(self,delivery_data)
	deliveries.updated.connect(hud.refresh_deliveries)
	sim.stats_changed.connect(hud.refresh_stats)
	sim.debris_cleaned.connect(on_debris_cleaned)
	sim.world_changed.connect(func():
		view.rebuild()
		refresh()
		request_save())
	view.set_club_open(sim.open)
	sim.notice.connect(func(t): hud.toast(t))
	sim.night_over.connect(func(r):
		night_report = r
		save_game()
		if not test_mode: hud.show_report(r))
	save_timer = Timer.new()
	save_timer.one_shot = true
	save_timer.wait_time = 0.8
	save_timer.timeout.connect(save_game)
	add_child(save_timer)
	autosave_timer = Timer.new()
	autosave_timer.wait_time = 30.0
	autosave_timer.timeout.connect(func(): if not test_mode: save_game())
	add_child(autosave_timer)
	autosave_timer.start()
	get_viewport().size_changed.connect(func(): call_deferred("clamp_camera"))
	center_camera.call_deferred()
	hud.refresh_stats()
	initialized = true
	if bad_save: hud.toast("Sauvegarde illisible : club de départ chargé. L'ancien fichier reste intact jusqu'à la prochaine sauvegarde.")
	else: hud.toast("Votre local est à rénover : embauchez un technicien pour nettoyer, puis ouvrez le club (O).",8.0)
	if "--smoke-test" in args: smoke_test.call_deferred()
	if "--sim-test" in args: sim_test.call_deferred()
	if "--ui-test" in args: ui_test.call_deferred()
	if "--delivery-test" in args: delivery_test.call_deferred()
	for arg in args:
		if arg.begins_with("--capture="): capture.call_deferred(arg.trim_prefix("--capture="))

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and initialized:
		if not test_mode: save_game()
		get_tree().quit()

func quit() -> void:
	_notification(NOTIFICATION_WM_CLOSE_REQUEST)

# ------------------------------------------------------------------ camera

func world_px(screen: Vector2) -> Vector2:
	return camera.position+screen/float(zoom)

func ground_at(screen: Vector2) -> Vector2:
	return Iso.to_world(world_px(screen))

func center_camera() -> void:
	var c = view.bounds.get_center()
	var p = Iso.to_screen(c.x,c.y)+Vector2(0,-10)
	camera.position = (p-Vector2(viewport.size)/2.0).round()

func overview() -> void:
	set_zoom(1 if zoom != 1 else 2)
	center_camera()

func set_zoom(z: int, anchor: Vector2 = Vector2(-1,-1)) -> void:
	z = clampi(z,1,4)
	if z == zoom: return
	if anchor.x < 0: anchor = get_viewport().get_visible_rect().size/2.0
	var before = world_px(anchor)
	zoom = z
	container.stretch_shrink = zoom
	await get_tree().process_frame
	camera.position = (before-anchor/float(zoom)).round()
	clamp_camera()

func clamp_camera() -> void:
	var L = Iso.LOT
	var lo = Vector2(Iso.to_screen(-L,L).x,Iso.to_screen(-L,-L).y)-Vector2(viewport.size)*0.5
	var hi = Vector2(Iso.to_screen(L,-L).x,Iso.to_screen(L,L).y)-Vector2(viewport.size)*0.5
	camera.position = camera.position.clamp(lo,hi).round()

func toggle_fullscreen() -> void:
	var fs = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fs else DisplayServer.WINDOW_MODE_FULLSCREEN)

func toggle_walls() -> void:
	view.wall_mode = 1-view.wall_mode
	view.rebuild()
	hud.toast("Murs hauts : on voit les briques et les appliques." if view.wall_mode == 0 else "Murs coupés : tout l'intérieur est visible.")

func toggle_grid() -> void:
	view.grid.visible = not view.grid.visible
	view.grid.queue_redraw()

func toggle_open() -> void:
	sim.set_open(not sim.open)
	view.set_club_open(sim.open)
	hud.refresh_stats()
	if hud.active == "clients": hud.fill_drawer()
	if sim.open:
		hud.toast("Club ouvert : les clients peuvent entrer." if not sim.entrance.is_empty() else "Club ouvert, mais aucune porte ne donne sur la rue.")
	else:
		hud.toast("Club fermé : plus personne n'entre, les clients présents s'en vont.")
	request_save()

func toggle_priority(id: int) -> void:
	var item = model.item_by_id(id)
	if item.is_empty(): return
	item.priority = not item.get("priority",false)
	refresh()
	request_save()

func on_debris_cleaned(id: int) -> void:
	# Cleaning is permanent: the debris also leaves the undo history.
	model.remove_item(id)
	for stack in [undo_stack,redo_stack]:
		for snap in stack:
			snap.furniture = snap.furniture.filter(func(i): return int(i.id) != id)
	if selected_item == id: clear_selection()
	view.rebuild()
	refresh()
	if model.debris().is_empty(): hud.toast("Plus aucun déchet : le local est propre !")
	request_save()

func set_speed(s: int) -> void:
	sim.speed = s
	hud.refresh_stats()

# ------------------------------------------------------------------ state

func clear_selection() -> void:
	moving_item = -1
	selected_room = -1
	selected_item = -1
	selected_edge = ""
	selected_parking = -1
	selected_client = null
	drag = {}

func refresh() -> void:
	hud.show_hover("",Vector2.ZERO)
	view.selection(selected_item,model.room_by_id(selected_room),selected_edge,model.parking_by_id(selected_parking))
	hud.refresh_context()
	if hud.active in ["build","staff","decor"]: hud.fill_drawer()
	hud.update_dock()
	var texts = {"select":"","room":"Tracer : "+Catalog.ROOMS[room_type],"door":"Placer une porte","window":"Placer une fenêtre","furniture":Catalog.ITEMS[chosen_item].name+" · R : tourner",
		"parking":"Places · R : tourner", "parking_lane":"Allée · glisser pour tracer"}
	hud.set_mode_text(texts.get(mode,""))
	hud.refresh_stats()

func set_mode(value: String) -> void:
	mode = value
	clear_selection()
	view.clear_preview()
	view.show_edge("")
	if mode in ["room","parking","parking_lane"]: view.grid.visible = true
	elif not hud.active == "build": view.grid.visible = false
	view.show_street_line(mode in ["parking","parking_lane"])
	refresh()
	hud.toast({"select":"Cliquez un meuble, une personne, une ouverture ou le sol d'une pièce.","room":"Cliquez-glissez pour tracer une pièce (2 × 2 m minimum).","door":"Cliquez un mur pour y placer une porte.","window":"Cliquez un mur pour y placer une fenêtre.","furniture":"Cliquez pour placer · R : tourner · Maj : en série · Échap : annuler",
		"parking":"Cliquez pour une place · glissez pour une rangée · R : tourner. Les rangées voisines se raccordent.","parking_lane":"Tracez l'allée à côté des places et jusqu'au trottoir. Une largeur de 6 m facilite les manœuvres."}.get(mode,""))

func set_room_type(t: int) -> void:
	room_type = t
	set_mode("room")

func set_item_scheme(id: int, scheme: int) -> void:
	# The dance floor's colours (free, undoable).
	var item = model.item_by_id(id)
	if item.is_empty() or int(item.get("scheme",0)) == scheme: return
	var before = model.snapshot()
	item.scheme = clampi(scheme,0,Catalog.DANCE_SCHEMES.size()-1)
	commit(before,"couleurs")
	view.rebuild()
	refresh()

func test_reputation(step: int) -> void:
	# TEMPORARY test tool (F8 / Maj+F8): one star more or less, to try the
	# escort standings without playing for hours.
	sim.rating = clampf(float(sim.stars()+step),1.0,5.0)
	sim.stats_changed.emit()
	refresh()
	hud.toast("Test : réputation %d étoile(s)" % sim.stars())

func choose_item(kind: String) -> void:
	if Catalog.is_character(kind) and sim.stars() < Catalog.stars_needed(kind):
		hud.toast("%s : il faut une réputation de %d étoiles." % [Catalog.ITEMS[kind].name,Catalog.stars_needed(kind)])
		return
	chosen_item = kind
	placement_appearance = Characters.hire_look(kind,look_rng) if Catalog.is_character(kind) else {}
	placement_rotation = 0
	set_mode("furniture")
	var e: Dictionary = Catalog.ITEMS[kind]
	if Catalog.is_character(kind): hud.toast("%s · %d $/h · cliquez dans une pièce pour le poste" % [e.name,int(e.wage)])
	else: hud.toast("%s · %s $ · R : tourner · Maj : en série" % [e.name,UiKit.money(int(e.price))])

func select_room(id: int) -> void:
	clear_selection()
	mode = "select"
	selected_room = id
	refresh()

func select_parking(id: int) -> void:
	clear_selection()
	mode = "select"
	view.show_street_line(false)
	selected_parking = id
	refresh()

func extend_parking(side: int) -> void:
	var r = model.parking_extension(selected_parking,side)
	if r.is_empty(): return
	var before = model.snapshot()
	var id = model.add_parking(r.x,r.z,r.w,r.h,r.kind,int(r.rotation))
	if id == -1:
		hud.toast(model.error)
		return
	if commit(before,"Rangée prolongée d'une place."): select_parking(id)

func continue_parking() -> void:
	var pk = model.parking_by_id(selected_parking)
	if pk.is_empty(): return
	parking_rotation = int(pk.get("rotation",1))
	set_mode("parking")

func turn_parking_tool() -> void:
	parking_rotation = posmod(parking_rotation+1,4)
	if drag.get("kind","") == "parking":
		drag.origin = model.parking_origin(drag.start,parking_rotation)
	refresh()
	show_parking_preview(parking_candidate(drag,parking_pointer))

func select_item(id: int) -> void:
	clear_selection()
	mode = "select"
	selected_item = id
	refresh()

func select_client(a: Actor) -> void:
	clear_selection()
	mode = "select"
	selected_client = a
	refresh()

func set_selected_room_type(t: int) -> void:
	var room = model.room_by_id(selected_room)
	if room.is_empty(): return
	var before = model.snapshot()
	room.type = t
	commit(before,"Pièce transformée en "+Catalog.ROOMS[t]+".")

func set_price(key: String, value: int) -> void:
	sim.prices[key] = value
	request_save()

# ------------------------------------------------------------------ changes, money, history

func commit(before: Dictionary, message: String) -> bool:
	# Charge (or refund) the difference in building value.
	var old = BuildingModel.new()
	old.restore(before)
	var diff = model.cost()-old.cost()
	if diff > 0 and diff > sim.money:
		model.restore(before)
		changed_view()
		hud.toast("Fonds insuffisants : il manque %s $." % UiKit.money(diff-sim.money))
		return false
	sim.money -= diff
	undo_stack.append(before)
	if undo_stack.size() > 80: undo_stack.pop_front()
	redo_stack.clear()
	changed_view()
	if diff > 0: message += "  −%s $" % UiKit.money(diff)
	elif diff < 0: message += "  +%s $" % UiKit.money(-diff)
	hud.toast(message)
	request_save()
	return true

func changed_view() -> void:
	if deliveries != null: deliveries.sync_orders()
	view.rebuild()
	sim.layout_changed()
	refresh()

func delivery_installed(key: String, id: int) -> void:
	# Delivery progress survives construction undo/redo without another charge.
	for stack in [undo_stack,redo_stack]:
		for snapshot in stack:
			for item in snapshot.furniture:
				if item.get("delivery_key","") == key: item.erase("delivery_pending")
	changed_view()
	var item = model.item_by_id(id)
	if not item.is_empty():
		view.puff(Vector2(item.x,item.z),"heart",1.3)
		hud.toast(Catalog.ITEMS[item.kind].name+" livré et installé.")
	request_save()

func request_save() -> void:
	if initialized and not test_mode:
		save_status = "Enregistrement…"
		save_timer.start()

func restore_to(data: Dictionary, message: String) -> void:
	var old = BuildingModel.new()
	old.restore(model.snapshot())
	model.restore(data)
	sim.money -= model.cost()-old.cost()
	clear_selection()
	changed_view()
	hud.toast(message)
	request_save()

func undo() -> void:
	if undo_stack.is_empty():
		hud.toast("Aucune modification à annuler.")
		return
	redo_stack.append(model.snapshot())
	restore_to(undo_stack.pop_back(),"Modification annulée.")

func redo() -> void:
	if redo_stack.is_empty():
		hud.toast("Aucune modification à rétablir.")
		return
	undo_stack.append(model.snapshot())
	restore_to(redo_stack.pop_back(),"Modification rétablie.")

func apply_finishes(room_id: int, finishes: Dictionary) -> void:
	var before = model.snapshot()
	if not model.set_finishes(room_id,finishes):
		hud.toast(model.error)
		return
	if model.snapshot() == before:
		changed_view()
		return
	commit(before,"Revêtements appliqués.")

func apply_appearance(item_id: int, appearance: Dictionary) -> void:
	var before = model.snapshot()
	if not model.set_appearance(item_id,appearance):
		hud.toast(model.error)
		return
	if model.snapshot() == before: return
	commit(before,"Tenue enregistrée.")

func edit_appearance(item_id: int) -> void:
	Editors.appearance(hud,self,item_id)

func edit_finishes(room_id: int) -> void:
	Editors.finishes(hud,self,room_id)

func delete_selection() -> void:
	if selected_room < 0 and selected_item < 0 and selected_edge == "" and selected_parking < 0: return
	var before = model.snapshot()
	var what = "Élément supprimé."
	if selected_item >= 0:
		var item = model.item_by_id(selected_item)
		if not item.is_empty() and Catalog.is_debris(item.kind):
			hud.toast("Un technicien d'entretien doit nettoyer ce déchet (Personnel).")
			return
		if not item.is_empty() and Catalog.is_used(item.kind): what = Catalog.ITEMS[item.kind].name+" jeté."
		if not item.is_empty() and Catalog.is_character(item.kind): what = Catalog.ITEMS[item.kind].name+" a quitté l'équipe."
		model.furniture.erase(item)
	elif selected_room >= 0: model.remove_room(selected_room)
	elif selected_parking >= 0:
		model.remove_parking(selected_parking)
		what = "Parking démoli."
	elif selected_edge != "": model.openings.erase(selected_edge)
	clear_selection()
	commit(before,what+" Ctrl + Z pour annuler.")

func rotate_item() -> void:
	if mode == "parking":
		turn_parking_tool()
		return
	if mode == "furniture":
		placement_rotation = (placement_rotation+1)%4
		update_preview(get_viewport().get_mouse_position())
		return
	var item = model.item_by_id(selected_item)
	if item.is_empty() or Catalog.is_debris(item.kind): return
	var before = model.snapshot()
	if model.move_item(selected_item,item.x,item.z,int(item.rot)+1): commit(before,"Objet tourné de 90°.")
	else: hud.toast(model.error)

func start_move() -> void:
	var item = model.item_by_id(selected_item).duplicate()
	if item.is_empty() or Catalog.is_debris(item.kind): return
	var id = int(item.id)
	choose_item(item.kind)
	moving_item = id
	placement_appearance = item.get("appearance",{}).duplicate(true)
	placement_rotation = int(item.rot)
	hud.toast("Cliquez la nouvelle position · R : tourner · Échap : annuler")

func duplicate_item() -> void:
	var item = model.item_by_id(selected_item).duplicate()
	if item.is_empty() or not Catalog.in_shop(item.kind) and not Catalog.is_character(item.kind): return
	choose_item(item.kind)
	placement_rotation = int(item.rot)
	placement_appearance = item.get("appearance",{}).duplicate(true)

func next_night() -> void:
	if not sim.paused_for_report: return
	sim.start_next_night()
	hud.toast("Nuit %d : le club rouvre ses portes." % sim.day)
	save_game()

# ------------------------------------------------------------------ save

func save_game() -> void:
	var data = {"model":model.snapshot(),"club":sim.to_dict(),"deliveries":deliveries.to_dict(),"view":{"zoom":zoom,"walls":view.wall_mode}}
	var temp = save_path+".tmp"
	var file = FileAccess.open(temp,FileAccess.WRITE)
	if file == null:
		save_status = "Échec de sauvegarde : disque ou droits."
		hud.toast(save_status)
		return
	file.store_string(JSON.stringify(data,"\t"))
	file.flush()
	var err = file.get_error()
	file.close()
	if err != OK:
		save_status = "Sauvegarde incomplète."
		return
	var path = ProjectSettings.globalize_path(save_path)
	if FileAccess.file_exists(save_path): DirAccess.copy_absolute(path,path+".bak")
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(temp),path) != OK:
		save_status = "Sauvegarde non remplacée ; l'ancienne reste disponible."
		return
	save_status = "Enregistré sur cet ordinateur"

func manual_save() -> void:
	save_game()
	hud.toast(save_status)

func reset_club() -> void:
	var before = model.snapshot()
	deliveries.reset()
	model.starter()
	sim.money = ClubSim.START_MONEY
	sim.rating = 1.0
	sim.day = 1
	sim.minute = 1320.0
	sim.set_open(false)
	view.set_club_open(false)
	sim.history.clear()
	sim.reset_night()
	undo_stack.clear()
	redo_stack.clear()
	for c in sim.clients.duplicate(): sim.remove_client(c)
	clear_selection()
	changed_view()
	center_camera()
	hud.toast("Nouveau départ : un local vétuste à rénover.")
	request_save()

func import_3d() -> void:
	if not FileAccess.file_exists(legacy_path):
		hud.toast("Aucun bâtiment de la version 3D trouvé sur cet ordinateur.")
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(legacy_path))
	var candidate = BuildingModel.new()
	if not candidate.load_checked(data):
		hud.toast("Le bâtiment 3D n'a pas pu être lu.")
		return
	var before = model.snapshot()
	model.restore(candidate.snapshot())
	undo_stack.append(before)
	redo_stack.clear()
	clear_selection()
	changed_view()
	center_camera()
	hud.toast("Bâtiment 3D importé : %d pièces, %d objets. Ctrl + Z pour revenir." % [model.rooms.size(),model.furniture.size()])
	request_save()

# ------------------------------------------------------------------ input

func ui_blocking() -> bool:
	return hud.modal_open()

func _input(event: InputEvent) -> void:
	if not initialized: return
	if event is InputEventMouseButton and not event.pressed:
		if event.button_index in [MOUSE_BUTTON_RIGHT,MOUSE_BUTTON_MIDDLE]: panning = false
		if event.button_index == MOUSE_BUTTON_LEFT and not drag.is_empty():
			if get_viewport().gui_get_hovered_control() != null:
				drag = {}
				view.clear_preview()
				refresh()
			else: finish_drag(event.position)
			get_viewport().set_input_as_handled()
	if event is InputEventMouseMotion:
		if panning:
			camera.position -= event.relative/float(zoom)
			clamp_camera()
		elif not drag.is_empty(): update_preview(event.position)

func _unhandled_input(event: InputEvent) -> void:
	if not initialized or ui_blocking(): return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.ctrl_pressed:
			match event.keycode:
				KEY_Z: undo()
				KEY_Y: redo()
				KEY_S: manual_save()
				KEY_D: duplicate_item()
		else:
			match event.keycode:
				KEY_B: hud.toggle_drawer("decor")
				KEY_1: set_speed(1)
				KEY_2: set_speed(3)
				KEY_T: set_mode("room")
				KEY_P: set_mode("door")
				KEY_F: set_mode("window")
				KEY_K: set_mode("parking")
				KEY_SPACE: set_speed(0 if sim.speed != 0 else 1)
				KEY_O: toggle_open()
				KEY_R: rotate_item()
				KEY_DELETE, KEY_BACKSPACE: delete_selection()
				KEY_ESCAPE:
					if mode != "select" or selected_item >= 0 or selected_room >= 0 or selected_parking >= 0 or selected_client != null: set_mode("select")
					elif hud.active != "": hud.close_drawer()
					else: hud.toggle_drawer("settings")
				KEY_G: toggle_grid()
				KEY_W: toggle_walls()
				KEY_HOME: center_camera()
				KEY_F1: hud.show_help()
				KEY_F8: test_reputation(-1 if event.shift_pressed else 1)
				KEY_F11: toggle_fullscreen()
				KEY_EQUAL, KEY_KP_ADD: set_zoom(zoom+1)
				KEY_MINUS, KEY_KP_SUBTRACT: set_zoom(zoom-1)
	if event is InputEventMouseMotion and not panning and drag.is_empty(): update_preview(event.position)
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP: set_zoom(zoom+1,event.position)
			MOUSE_BUTTON_WHEEL_DOWN: set_zoom(zoom-1,event.position)
			MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE: panning = true
			MOUSE_BUTTON_LEFT: begin_action(event.position)

func snap_point(p: Vector2) -> Vector2:
	return Vector2(snappedf(p.x,0.25),snappedf(p.y,0.25))

func begin_action(screen: Vector2) -> void:
	var p = ground_at(screen)
	var wp = world_px(screen)
	if mode == "parking":
		drag = {"kind":mode,"start":p,"origin":model.parking_origin(p,parking_rotation)}
		update_preview(screen)
		return
	if mode == "parking_lane":
		drag = {"kind":mode,"start":(p*2.0).floor()/2.0}
		update_preview(screen)
		return
	if mode == "room":
		drag = {"kind":mode,"start":p.floor()}
		update_preview(screen)
		return
	if mode == "furniture":
		var at = snap_point(p)
		var before = model.snapshot()
		var id = -1
		if moving_item >= 0:
			if model.move_item(moving_item,at.x,at.y,placement_rotation): id = moving_item
		else: id = model.purchase_item(chosen_item,at.x,at.y,placement_rotation,placement_appearance)
		if id == -1:
			hud.toast(model.error)
			return
		# each recruit of a series gets a look of her own
		if moving_item < 0 and Catalog.is_character(chosen_item): placement_appearance = Characters.hire_look(chosen_item,look_rng)
		var keep = moving_item < 0 and Input.is_key_pressed(KEY_SHIFT)
		var moved = moving_item >= 0
		var name = Catalog.ITEMS[chosen_item].name
		if not keep:
			mode = "select"
			moving_item = -1
			view.clear_preview()
			selected_item = id
		var pending = model.item_by_id(id).get("delivery_pending",false)
		if commit(before,(name+" déplacé." if moved else name+(" commandé · emplacement réservé." if pending else " installé."))) and not keep: refresh()
		return
	if mode in ["door","window"]:
		var key = view.nearest_edge(wp)
		if key == "":
			hud.toast("Visez un mur existant.")
			return
		if model.openings.get(key) == mode: return
		var before = model.snapshot()
		model.set_opening(key,mode)
		commit(before,("Porte" if mode == "door" else "Fenêtre")+" intégrée au mur.")
		return
	var room = model.room_by_id(selected_room)
	if not room.is_empty():
		var hs = view.handles(room)
		for i in range(hs.size()):
			var hp = Iso.to_screen(hs[i].x,hs[i].y)
			if wp.distance_to(hp) < 6:
				drag = {"kind":"resize","side":i,"original":room.duplicate(),"start":p}
				return
	var hit = view.pick(wp)
	clear_selection()
	if hit.has("actor"):
		var a: Actor = hit.actor
		if a.item_id >= 0:
			selected_item = a.item_id
			var item = model.item_by_id(selected_item)
			drag = {"kind":"move","id":selected_item,"start":p,"screen":screen,"original":item.duplicate()}
		else: selected_client = a
	elif hit.has("item"):
		selected_item = int(hit.item)
		var item = model.item_by_id(selected_item)
		if not Catalog.is_debris(item.kind): drag = {"kind":"move","id":selected_item,"start":p,"screen":screen,"original":item.duplicate()}
	else:
		var key = view.pick_wall(wp)
		if key != "" and model.openings.has(key): selected_edge = key
		else:
			room = model.room_at(p)
			if not room.is_empty(): selected_room = int(room.id)
			else:
				var pk = model.parking_at(p)
				if not pk.is_empty(): selected_parking = int(pk.id)
	refresh()

func room_candidate(screen: Vector2) -> Dictionary:
	var p = ground_at(screen)
	if drag.kind in ["room","parking"]:
		var start: Vector2 = drag.start
		var end = p.floor()
		return {"x":int(minf(start.x,end.x)),"z":int(minf(start.y,end.y)),"w":int(absf(end.x-start.x))+1,"h":int(absf(end.y-start.y))+1,"type":room_type}
	var r: Dictionary = drag.original.duplicate()
	var delta: Vector2 = (p-drag.start).round()
	match int(drag.side):
		0:
			r.x += int(delta.x)
			r.w -= int(delta.x)
		1: r.w += int(delta.x)
		2:
			r.z += int(delta.y)
			r.h -= int(delta.y)
		3: r.h += int(delta.y)
	return r

func parking_candidate(d: Dictionary, screen: Vector2) -> Dictionary:
	var p = ground_at(screen)
	if d.get("kind",mode) == "parking_lane":
		var start: Vector2 = d.get("start",(p*2.0).floor()/2.0)
		var end = (p*2.0).floor()/2.0
		var at = start.min(end)
		var size = (end-start).abs()+Vector2(0.5,0.5)
		return {"x":at.x,"z":at.y,"w":size.x,"h":size.y,"kind":"lane","rotation":0}
	var start: Vector2 = d.get("start",p)
	var origin: Vector2 = d.get("origin",model.parking_origin(p,parking_rotation))
	return model.row_candidate(origin,start,p,parking_rotation)

func show_parking_preview(r: Dictionary) -> void:
	var valid = model.valid_parking(r)
	var lay = model.parking_layout(r)
	var price = model.parking_build_price(r)
	if valid and price > sim.money:
		valid = false
		model.error = "Fonds insuffisants."
	view.preview_parking(model.rect(r),lay,valid)
	var dimensions = "%s × %s m" % [str(r.w),str(r.h)]
	var label = "Allée" if r.kind == "lane" else "%d place%s" % [lay.bays.size(),"s" if lay.bays.size() > 1 else ""]
	var instruction = "Glissez pour tracer" if r.kind == "lane" else "Cliquez ou glissez · R : tourner"
	if valid: hud.toast("%s · %s · %s $ · %s" % [label,dimensions,UiKit.money(price),"Relâchez pour poser" if not drag.is_empty() else instruction],1.5)
	else: hud.toast("%s · %s" % [dimensions,model.error],1.5)

func moved_candidate(screen: Vector2) -> Dictionary:
	var r: Dictionary = drag.original.duplicate()
	var p = snap_point(Vector2(r.x,r.z)+ground_at(screen)-drag.start)
	r.x = p.x
	r.z = p.y
	return r

func update_preview(screen: Vector2) -> void:
	if ui_blocking(): return
	parking_pointer = screen
	var hovered_ui = get_viewport().gui_get_hovered_control() != null
	if not drag.is_empty():
		if drag.kind in ["room","resize"]:
			var r = room_candidate(screen)
			var valid = model.valid_room(r,selected_room if drag.kind == "resize" else -1)
			view.preview_room(r,valid)
			var price = int(r.w*r.h)*Catalog.ROOM_PRICE if drag.kind == "room" else 0
			hud.toast("%d × %d m%s · %s" % [r.w,r.h,(" · %s $" % UiKit.money(price)) if price > 0 else "","Relâchez pour valider" if valid else model.error],1.5)
		elif drag.kind in ["parking","parking_lane"]:
			show_parking_preview(parking_candidate(drag,screen))
		elif drag.kind == "move" and screen.distance_to(drag.screen) > 6:
			var item = moved_candidate(screen)
			view.preview_item(item,model.valid_item(item,int(drag.id)))
		return
	if hovered_ui:
		view.clear_preview()
		hud.show_hover("",screen)
		return
	var wp = world_px(screen)
	if mode == "furniture":
		var p = snap_point(ground_at(screen))
		var item = {"kind":chosen_item,"x":p.x,"z":p.y,"rot":placement_rotation,"appearance":placement_appearance}
		view.preview_item(item,model.valid_item(item,moving_item))
	elif mode in ["door","window"]:
		view.preview_edge(view.nearest_edge(wp),mode)
	elif mode in ["parking","parking_lane"]:
		show_parking_preview(parking_candidate({},screen))
	elif mode == "room":
		var c = ground_at(screen).floor()
		view.preview_room({"x":c.x,"z":c.y,"w":1,"h":1},true)
	elif mode == "select":
		var hit = view.pick(wp)
		var text = ""
		var hover_id = -1
		if hit.has("actor"):
			var a: Actor = hit.actor
			if a.item_id >= 0:
				hover_id = a.item_id
				var item = model.item_by_id(a.item_id)
				text = Catalog.ITEMS[item.kind].name if not item.is_empty() else ""
			else: text = "%s · %s · %d%%" % [a.brain.get("name",""),ClubSim.ACTIVITY.get(a.brain.get("activity",""),""),int(a.brain.get("sat",0))]
		elif hit.has("item"):
			var item = model.item_by_id(int(hit.item))
			if not item.is_empty():
				text = Catalog.ITEMS[item.kind].name
				if item.get("delivery_pending",false): text += " · "+deliveries.item_status(item)
				hover_id = int(item.id)
		else:
			var room = model.room_at(ground_at(screen))
			if not room.is_empty(): text = Catalog.ROOMS[int(room.type)]
			else:
				var pk = model.parking_at(ground_at(screen))
				if not pk.is_empty():
					var n = view.parking_layouts.get(int(pk.id),{}).get("bays",[]).size()
					text = "Parking · %d place%s" % [n,"s" if n > 1 else ""]
		view.hover_item(hover_id)
		hud.show_hover(text,screen)

func finish_drag(screen: Vector2) -> void:
	if drag.is_empty(): return
	var before = model.snapshot()
	var d = drag
	drag = {}
	view.clear_preview()
	if d.kind == "room":
		var r = room_candidate_from(d,screen)
		var id = model.add_room(r.x,r.z,r.w,r.h,room_type)
		if id == -1:
			hud.toast(model.error)
			refresh()
			return
		if commit(before,Catalog.ROOMS[room_type]+" construite."):
			selected_room = id
			mode = "select"
			refresh()
	elif d.kind in ["parking","parking_lane"]:
		var r = parking_candidate(d,screen)
		var id = model.add_parking(r.x,r.z,r.w,r.h,r.kind,int(r.rotation))
		if id == -1:
			hud.toast(model.error)
			refresh()
			return
		var bays = model.parking_layout(r).bays.size()
		if commit(before,"Allée ajoutée." if r.kind == "lane" else "%d place%s ajoutée%s." % [bays,"s" if bays > 1 else "","s" if bays > 1 else ""]):
			# Stay in the tool: adding the next module needs no extra click.
			show_parking_preview(parking_candidate({},screen))
	elif d.kind == "resize":
		drag = d
		var r = room_candidate(screen)
		drag = {}
		if model.resize_room(selected_room,r): commit(before,"Pièce redimensionnée.")
		else:
			hud.toast(model.error)
			refresh()
	elif d.kind == "move":
		if screen.distance_to(d.screen) > 6:
			drag = d
			var r = moved_candidate(screen)
			drag = {}
			if model.move_item(int(d.id),r.x,r.z,int(r.rot)): commit(before,"Objet déplacé.")
			else:
				hud.toast(model.error)
				refresh()
		else: refresh()

func room_candidate_from(d: Dictionary, screen: Vector2) -> Dictionary:
	drag = d
	var r = room_candidate(screen)
	drag = {}
	return r

# ------------------------------------------------------------------ captures and tests

func capture(path: String) -> void:
	var seconds = 1.0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--sim-seconds="): seconds = float(arg.trim_prefix("--sim-seconds="))
		if arg.begins_with("--zoom="): await set_zoom(int(arg.trim_prefix("--zoom=")))
		if arg == "--walls-low": toggle_walls()
		if arg.begins_with("--drawer="): hud.toggle_drawer(arg.trim_prefix("--drawer="))
		if arg == "--setup=reception": capture_reception()
		if arg == "--setup=depth": capture_depth()
		if arg == "--setup=parking": capture_parking()
		if arg == "--setup=parking_modular": capture_modular_parking()
		if arg == "--setup=delivery": capture_delivery()
		if arg == "--open": toggle_open()
	hud.toast_time = 0
	center_camera()
	if seconds > 1.5: set_speed(3)
	await get_tree().create_timer(seconds).timeout
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--focus="):
			var parts = arg.trim_prefix("--focus=").split(",")
			var p = Iso.to_screen(float(parts[0]),float(parts[1]))
			camera.position = (p-Vector2(viewport.size)/2.0).round()
		if arg == "--pause": set_speed(0)
		if arg.begins_with("--escorts="): capture_escorts(int(arg.trim_prefix("--escorts=")))
	hud.toast_time = 0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--until="):
			# wait for a room phase (undress / dance / action) to show it
			var phase = arg.trim_prefix("--until=")
			set_speed(3 if phase == "shower_door" else 1)
			var waited = 0.0
			var shown = func():
				if phase == "stage": return sim.staff.values().any(func(e): return is_instance_valid(e) and e.brain.get("state","") == "dancing" and e.path.is_empty())
				if phase == "shower_door": return view.shower_doors.values().any(func(d): return d.open and int(d.shown) == 0)
				return sim.clients.any(func(c): return is_instance_valid(c) and c.brain.has("service") and c.brain.service.get("phase","") == phase and (phase != "dance" or c.brain.service.escort.path.is_empty()))
			while waited < 120.0 and not shown.call():
				await get_tree().process_frame
				waited += get_process_delta_time()
			if phase != "shower_door":
				await get_tree().create_timer(0.4).timeout
				set_speed(0)
	if "--debug-services" in OS.get_cmdline_user_args():
		for c in sim.clients:
			if is_instance_valid(c) and c.brain.has("service"):
				var e = c.brain.service.get("escort")
				print("SERVICE client %s at %s vis %s anim %s phase %s | escort %s at %s vis %s anim %s" % [c.brain.state,str(c.world),str(c.visible),c.anim,c.brain.service.get("phase",""),e.brain.state if e else "-",str(e.world) if e else "-",str(e.visible) if e else "-",e.anim if e else "-"])
	var frames = 0
	var ghost = -1
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--frames="): frames = int(arg.trim_prefix("--frames="))
		if arg.begins_with("--ghost="): ghost = int(arg.trim_prefix("--ghost="))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--parking-preview="):
			# Capture the same modular preview used by the construction tool.
			var parts = arg.trim_prefix("--parking-preview=").split(",")
			set_mode("parking")
			hud.toggle_drawer("build")
			var r = {"x":float(parts[0]),"z":float(parts[1]),"w":float(parts[2]),"h":float(parts[3]),"kind":"row","rotation":parking_rotation}
			show_parking_preview(r)
			await get_tree().create_timer(0.3).timeout
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(path)
			print("CAPTURE_SAVED "+path)
			get_tree().quit()
			return
	if ghost >= 0 and not model.parkings.is_empty():
		var planned: Dictionary = view.parking_layouts.get(int(model.parkings[0].id),{})
		if planned.get("kind","") in ["row","lane","legacy"]:
			# Compact paint layouts make no claim that a car can manoeuvre
			# through every row. Never index missing experimental routes.
			print("GHOST_ROUTE_UNAVAILABLE: compact parking layout")
			ghost = -1
	if ghost >= 0 and not model.parkings.is_empty():
		# a test car (a box of a car's size) drives a planned route: from
		# the end of the street into a bay, then back out and away
		var lay: Dictionary = view.parking_layouts.get(int(model.parkings[0].id),{})
		var bay: Dictionary = lay.bays[mini(ghost,lay.bays.size()-1)]
		var route = Street.route_in(lay,int(bay.index),bay.ways_in[0])+Street.route_out(lay,int(bay.index),bay.ways_out[0])
		view.show_route(route)
		# skip most of the long run along the street
		var shown: Array = []
		for pose in route:
			if absf(pose.p.x-bay.mouth.x) < 14.0: shown.append(pose)
		set_speed(0)
		var n = maxi(frames,2)
		for i in range(n):
			var pose: Dictionary = shown[int(float(i)/float(n-1)*(shown.size()-1))]
			view.show_ghost_car(pose.p,pose.d,pose.rev)
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(path.replace(".png","_%03d.png" % i))
		print("CAPTURE_SAVED %d frames" % n)
		get_tree().quit()
		return
	if frames > 0:
		# a short sequence, e.g. someone stepping into the shower
		set_speed(1)
		for i in range(frames):
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(path.replace(".png","_%02d.png" % i))
			await get_tree().create_timer(0.09).timeout
		print("CAPTURE_SAVED %d frames" % frames)
		get_tree().quit()
		return
	await get_tree().create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("CAPTURE_SAVED "+path)
	get_tree().quit()

func capture_reception() -> void:
	# Documentation set-up: a reception desk with its receptionist near the
	# street door, and a small bar room with its bartender.
	var hall = model.room_at(Vector2(0,2))
	model.furniture = model.furniture.filter(func(i): return not (Catalog.is_debris(i.kind) and model.rect(hall).has_point(Vector2(i.x,i.z))))
	var before = model.snapshot()
	model.add_item("reception",-0.6,3.2,0)
	model.add_item("receptionist",-1.2,1.4,0)
	model.add_room(3,-7,6,7,0)
	model.set_opening("z:3:-1","door")
	var stage_id = model.add_item("dance",7.0,-5.5,0)
	if stage_id != -1: model.item_by_id(stage_id).scheme = 2
	model.add_item("bar",5.0,-2.6,0)
	model.add_item("bartender",6.4,-0.6,0)
	for x in [4.0,5.0,6.0]: model.add_item("stool",x,-1.5,0)
	var rng = RandomNumberGenerator.new()
	rng.seed = 5
	model.add_item("escort_chic",-2.4,0.2,0,Characters.hire_look("escort_chic",rng))
	model.add_item("escort",0.6,0.8,0,Characters.hire_look("escort",rng))
	model.add_item("maid",1.8,2.2,0)
	model.add_item("shower",3.5,3.55,3)
	var floor_id = model.add_item("dancefloor",-1.5,1.2,0)
	if floor_id != -1: model.item_by_id(floor_id).scheme = 1
	for plant in [["palm_lights",2.55,4.55],["monstera",-3.55,-0.55],["fern",0.9,4.6],["cactus",-2.6,4.6]]:
		model.add_item(plant[0],plant[1],plant[2],0)
	commit(before,"reception")

func capture_modular_parking() -> void:
	var before = model.snapshot()
	model.add_parking(8,-4.5,5,12.5,"row",1)
	model.add_parking(13,-4.5,6,12.5,"lane",0)
	commit(before,"Parking modulaire")

func capture_parking() -> void:
	# Documentation: the starting premises with a car park on each side.
	var before = model.snapshot()
	var a = model.add_parking(8,-12,16,20)
	var b = model.add_parking(-24,-4,16,12)
	if a == -1 or b == -1: print("PARKING_SKIP ",model.error)
	commit(before,"parkings")

var depth_actors: Array = []

func capture_depth() -> void:
	# Documentation and check: every seat, bed, shower and stage in its four
	# rotations, with people sitting, dancing or washing on them.
	var before = model.snapshot()
	model.rooms = []
	model.furniture = []
	model.openings = {}
	model.add_room(-10,-12,23,20,0)
	var rows = [
		[-10.6,[["chair",-9.0,1.4],["armchair",-3.2,1.6],["old_armchair",3.4,1.6],["stool",9.2,1.0]]],
		[-7.2,[["sofa",-8.4,2.7],["old_sofa",2.4,2.5]]],
		[-2.8,[["bed",-8.4,3.0],["old_bed",3.4,2.7]]],
		[1.6,[["shower",-9.4,1.8],["reception",-1.6,2.3]]],
		[5.8,[["dance",-8.2,3.4],["bar",6.4,0.0]]]]
	var ids: Array = []
	for row in rows:
		for group in row[1]:
			for r in range(4 if group[2] > 0.0 else 1):
				var id = model.add_item(group[0],group[1]+r*group[2],row[0],r)
				if id != -1: ids.append(id)
				else: print("DEPTH_SKIP ",group[0]," rot ",r," ",model.error)
	for k in [5.4,6.4,7.4]: ids.append(model.add_item("stool",k,6.95,0))
	ids.append(model.add_item("backbar",6.4,4.6,0))
	commit(before,"depth")
	var rng = RandomNumberGenerator.new()
	rng.seed = 11
	for a in depth_actors:
		if is_instance_valid(a): view.remove_actor(a)
	depth_actors.clear()
	for id in ids:
		var item = model.item_by_id(id)
		if item.is_empty(): continue
		var n = 0
		for s in Catalog.spots(item):
			if s.use == "stand" and item.kind != "bar": continue
			if s.use == "watch" and n > 1: continue
			var a = Actor.new()
			a.kind = "client"
			var woman = s.who == "escort" or (s.who == "any" and n % 2 == 1)
			a.configure(Characters.hire_look("escort_chic",rng) if woman else Characters.random_client(rng))
			a.lift = int(s.lift)
			a.set_world(s.pos)
			a.face(s.face)
			a.play({"sit":"sit","dance":"dance","work":"work"}.get(s.use,"idle"))
			if s.has("door") and int(item.rot) in [0,3]:
				# stepping in through the open door
				view.set_shower_door(int(item.id),true)
				a.set_world(s.pos.lerp(s.door,0.55))
				a.face(s.pos-s.door)
			view.add_actor(a)
			depth_actors.append(a)
			n += 1

func capture_escorts(variant: int) -> void:
	# Documentation capture: one escort per standing, in the outfits of the
	# chosen variant (1 or 2); the hall is swept first.
	set_speed(0)
	var hall = model.room_at(Vector2(0,2))
	model.furniture = model.furniture.filter(func(i): return not (Catalog.is_debris(i.kind) and model.rect(hall).has_point(Vector2(i.x,i.z))))
	var before = model.snapshot()
	var rng = RandomNumberGenerator.new()
	rng.seed = 11+variant
	var spots = [Vector2(-0.2,4.6),Vector2(0.5,3.9),Vector2(1.2,3.2),Vector2(4.2,3.2)]
	for i in range(4):
		var kind = Characters.ESCORT_KINDS[i]
		var look = Characters.hire_look(kind,rng)
		look.outfit_style = Characters.STANDINGS[kind].outfits[variant-1]
		model.add_item(kind,spots[i].x,spots[i].y,3,look)
	commit(before,"escorts")

func check(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		print("FAIL: "+description)

func smoke_test() -> void:
	await get_tree().process_frame
	# The derelict start: worn rooms, salvaged furniture, debris, no staff, closed.
	check(model.rooms.size() == 4,"The modest derelict premises have four rooms")
	check(model.debris().size() >= 10,"Debris litters the building (%d)" % model.debris().size())
	check(sim.staff.is_empty() and not sim.open,"No staff yet and the club is closed")
	check(sim.money == ClubSim.START_MONEY and ClubSim.START_MONEY >= 1000000,"The player starts with the temporary test budget")
	check(view.statics.size() > 40,"World view built walls and furniture (%d)" % view.statics.size())
	var start_money = sim.money
	# Build a room and furnish it, paying for both.
	var before = model.snapshot()
	var cost0 = model.cost()
	var id = model.add_room(-8,-4,4,3,0)
	check(id != -1,"A new room fits beside the toilets")
	check(commit(before,"test"),"Room commit accepted")
	check(sim.money == start_money-(model.cost()-cost0),"Room area and finishes are charged")
	var after_room = sim.money
	before = model.snapshot()
	var sofa = model.add_item("sofa",-6.0,-2.5,0)
	check(sofa != -1 and commit(before,"sofa"),"Sofa placed in the new room")
	check(sim.money == after_room-650,"The sofa is paid")
	undo()
	check(model.item_by_id(sofa).is_empty() and sim.money == after_room,"Undo removes and refunds the sofa")
	redo()
	check(not model.item_by_id(sofa).is_empty(),"Redo restores the sofa")
	selected_item = sofa
	rotate_item()
	check(int(model.item_by_id(sofa).rot) == 1,"Rotate turns the sofa")
	# Renovating finishes costs money.
	var money_before = sim.money
	var value_before = Finishes.value(model.room_by_id(id))
	apply_finishes(id,{"floor_finish":"carpet","floor_color":"9c2e4c","wall_finish":"wallpaper","wall_color":"7a2e5a"})
	check(model.room_by_id(id).floor_finish == "carpet","Finishes applied")
	check(sim.money == money_before-(Finishes.value(model.room_by_id(id))-value_before),"Renovation is charged by m² and wall length")
	# Salvaged furniture is free to keep and to throw away; debris cannot be deleted by hand.
	var old_table = model.furniture.filter(func(i): return i.kind == "old_table")[0]
	money_before = sim.money
	selected_item = int(old_table.id)
	delete_selection()
	check(model.item_by_id(int(old_table.id)).is_empty() and sim.money == money_before,"Salvaged furniture is thrown away for free")
	undo()
	var trash = model.debris()[0]
	selected_item = int(trash.id)
	delete_selection()
	check(not model.item_by_id(int(trash.id)).is_empty(),"Debris cannot be deleted by hand")
	check(not Catalog.in_shop("old_sofa") and not Catalog.in_shop("trash_bags") and Catalog.in_shop("sofa"),"Only new furniture is sold")
	# Escort standings follow the reputation (F8 is the temporary test key).
	check(sim.stars() == 1,"The club starts with one star")
	chosen_item = "sofa"
	choose_item("escort_vip")
	check(chosen_item != "escort_vip","A one-star club cannot attract a prestige escort")
	choose_item("escort")
	check(chosen_item == "escort" and int(placement_appearance.outfit_style) in Characters.STANDINGS.escort.outfits,"Beginner escorts can be hired right away")
	for i in range(3): test_reputation(1)
	check(sim.stars() == 4,"The test key raises the reputation")
	choose_item("escort_vip")
	check(chosen_item == "escort_vip" and int(placement_appearance.outfit_style) in Characters.STANDINGS.escort_vip.outfits,"A four-star club attracts prestige escorts dressed for their standing")
	test_reputation(-5)
	check(sim.stars() == 1,"The test key lowers the reputation back")
	set_mode("select")
	# Hiring a technician, dressing him.
	before = model.snapshot()
	var tech = model.add_item("janitor",-2.0,4.0,0)
	check(tech != -1 and commit(before,"hire"),"A technician is hired")
	check(sim.staff.size() == 1,"The technician got an actor")
	apply_appearance(tech,{"skin":"8a5a44","hair":"e2b25a","outfit":"3a78c8","hairstyle":3,"outfit_style":1,"face":1,"body":1,"glasses":0})
	check(sim.staff[tech].appearance.outfit == "3a78c8","Staff actor wears the new outfit")
	# Cleaning removes debris for good, even from the undo history.
	var trash_id = int(trash.id)
	checkpoint_for_test()
	on_debris_cleaned(trash_id)
	check(model.item_by_id(trash_id).is_empty(),"Cleaned debris leaves the building")
	var in_history = false
	for snap in undo_stack:
		for i in snap.furniture:
			if int(i.id) == trash_id: in_history = true
	check(not in_history,"Cleaned debris cannot come back with Undo")
	# Opening and closing the club; the sign follows.
	toggle_open()
	check(sim.open and view.club_open,"The club opens and its sign lights up")
	toggle_open()
	check(not sim.open and not view.club_open,"The club closes")
	# Openings
	before = model.snapshot()
	model.set_opening("x:-7:-4","door")
	check(commit(before,"door"),"Door accepted")
	# Save and reload
	save_game()
	var data = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	var copy = BuildingModel.new()
	check(copy.load_checked(data.model),"Saved club loads back")
	check(copy.snapshot().rooms.size() == model.rooms.size(),"Reload keeps rooms")
	check(data.club.get("open",true) == false,"The open state is saved")
	# Picking: the old sofa is pickable where it is drawn.
	var old_sofa = model.furniture.filter(func(i): return i.kind == "old_sofa")[0]
	var entry: Dictionary = view.item_entries[int(old_sofa.id)]
	var sp: Sprite2D = entry.sprite
	check(view.pick(sp.position+Vector2(0,-8)).get("item",-1) == int(old_sofa.id),"Clicking the old sofa picks it")
	# Money guard
	var rich = sim.money
	sim.money = 10
	before = model.snapshot()
	check(model.add_item("bar",-7.5,-2.5,1) != -1,"A bar fits in the new room")
	check(not commit(before,"bar"),"Unaffordable purchases are refused")
	sim.money = rich
	check(container.stretch_shrink == zoom and viewport.canvas_item_default_texture_filter == Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST,"World is scaled by an integer with nearest filtering")
	depth_checks()
	parking_checks()
	print("SMOKE_TEST_RESULT: %d failures" % failures)
	if failures == 0: print("SMOKE_TEST_PASSED")
	get_tree().quit(1 if failures > 0 else 0)

func parking_checks() -> void:
	# The car park tool: the street line shows, a zone against the sidewalk
	# is laid out and paid, selected, demolished and brought back.
	set_mode("parking")
	check(view.street_hint != null and view.street_hint.visible,"In car-park mode the sidewalk line shows")
	var rect = Rect2(8,Street.LOT_FRONT-20,16,20)
	var lay = Street.layout(rect)
	view.preview_parking(rect,lay,true)
	check(view.preview_node != null and view.preview_node.get_child_count() > lay.bays.size(),"The preview draws the zone, its aisles and its bays")
	view.clear_preview()
	set_mode("select")
	check(not view.street_hint.visible,"The line hides again")
	var money0 = sim.money
	var before = model.snapshot()
	var fx0 = view.floor_fx.get_child_count()
	var id = model.add_parking(8,int(Street.LOT_FRONT)-20,16,20)
	check(id != -1 and commit(before,"parking"),"A car park is laid out beside the club")
	check(sim.money == money0-16*20*Street.PRICE_M2,"…and paid by the square metre")
	check(view.parking_layouts.get(id,{}).get("bays",[]).size() == 8 and view.floor_fx.get_child_count() > fx0+40,"Its bays, lines, wheel stops and kerbs are drawn")
	var on_road = 0
	for e in view.statics:
		if e.kind == "prop" and (e.rect as Rect2).end.y > Street.ROAD.x and (e.rect as Rect2).position.y < Street.ROAD.y: on_road += 1
		if e.kind == "prop" and (e.rect as Rect2).intersects(rect.grow(-0.3)): on_road += 1
	check(on_road == 0,"No lamp, tree or bin stands on the road or in a car park (%d)" % on_road)
	select_parking(id)
	check(hud.context.visible and selected_parking == id,"Clicking a car park selects it")
	delete_selection()
	check(model.parkings.is_empty() and sim.money == money0,"Demolished (and refunded like any removal)")
	undo()
	check(model.parkings.size() == 1,"Undo brings it back")
	model.parkings.clear()
	changed_view()

func depth_checks() -> void:
	# Drawing order: people on seats, beds, the stage and in the shower, in the
	# four rotations, against every part of the furniture.
	var before = model.snapshot()
	var room = model.add_room(-22,-22,17,16,0)
	check(room != -1,"A spare room for the depth checks")
	var wrong: Array = []
	var z: Dictionary = {}
	var total = 0
	var people_count = 0
	for batch in [["sofa","old_sofa","chair","armchair","old_armchair","stool"],["bed","old_bed","dance","shower"]]:
		var placed: Array = []
		var x = -21.8
		var zz = -21.0
		var row_h = 0.0
		for kind in batch:
			for r in range(4):
				var size: Vector2 = Catalog.footprint(kind,r)
				if x+size.x > -5.2:
					x = -21.8
					zz += row_h+1.2
					row_h = 0.0
				var id = model.add_item(kind,x+size.x/2.0,zz+size.y/2.0,r)
				if id != -1: placed.append(id)
				else: print("DEPTH_SKIP %s %d %s" % [kind,r,model.error])
				x += size.x+1.4
				row_h = maxf(row_h,size.y)
		total += placed.size()
		changed_view()
		var pairs: Array = []
		for id in placed:
			var item = model.item_by_id(id)
			for s in Catalog.spots(item):
				if not s.use in ["sit","dance","wash"]: continue
				var a = Actor.new()
				a.configure(Characters.random_client(look_rng))
				a.lift = int(s.lift)
				a.set_world(s.pos)
				view.add_actor(a)
				pairs.append([a,item])
		people_count += pairs.size()
		view.depth_sort()
		for pr in pairs:
			var a: Actor = pr[0]
			var item: Dictionary = pr[1]
			var key = "%s:%d" % [item.kind,int(item.rot)]
			if not z.has(key): z[key] = {"people":[]}
			z[key].people.append(a.z_index)
			for e in view.item_entries[int(item.id)].get("parts",[view.item_entries[int(item.id)]]):
				z[key][e.get("part","base")] = e.node.z_index
				if not WorldView.actor_rect(a).intersects(view.s_px[int(e.index)]): continue
				if (a.z_index > e.node.z_index) != WorldView.behind_point(e.rect,a.world): wrong.append("%s %s" % [key,e.get("part","")])
		if batch.has("shower"):
			# a bubble floats over everything
			pairs[0][0].emote("heart",1.0)
			check(pairs[0][0].bubble != null and not pairs[0][0].bubble.z_as_relative and pairs[0][0].bubble.z_index > 3900,"Bubbles are drawn above walls and furniture")
			# the shower door swings open and shut in steps, and its parts follow
			var sh = placed.filter(func(i): return model.item_by_id(i).kind == "shower" and int(model.item_by_id(i).rot) == 0)[0]
			view.set_shower_door(sh,true)
			var frames: Array = []
			for i in range(12):
				view.step_shower_doors(0.05)
				frames.append(int(view.shower_doors.get(sh,{}).get("shown",0)))
			var door_part = view.item_entries[sh].parts.filter(func(e): return e.part == "door")[0]
			check(frames.has(1) and frames.has(2) and view.shower_door_open(sh) and door_part.file.contains("shower_f3"),"The shower door opens frame by frame (%s)" % str(frames))
			check(door_part.rect.end.y > model.item_rect(model.item_by_id(sh)).end.y+0.5,"The open door is ordered where it now stands")
			view.set_shower_door(sh,false)
			for i in range(12): view.step_shower_doors(0.05)
			check(view.shower_door_shut(sh) and not view.shower_doors.has(sh) and door_part.file.ends_with("shower_0_door.png"),"…and shuts again")
			# the whole order is worked out fast enough to run every frame
			var t0 = Time.get_ticks_usec()
			for i in range(20): view.depth_sort()
			var ms = (Time.get_ticks_usec()-t0)/20000.0
			print("DEPTH_SORT %.2f ms for %d statics and %d people" % [ms,view.statics.size(),pairs.size()])
			check(ms < 6.0,"Depth sorting stays cheap (%.2f ms)" % ms)
		for pr in pairs: view.remove_actor(pr[0])
		for id in placed: model.remove_item(id)
	check(total == 40,"Every seat, bed, stage and shower fits the spare room in its four rotations (%d)" % total)
	check(wrong.is_empty(),"Everyone on a seat, bed, stage or in a shower is drawn in the right order against each part (%s)" % ", ".join(wrong))
	var ahead = func(key: String, part: String) -> bool: return z.has(key) and z[key].has(part) and z[key].people.all(func(v): return v > z[key][part])
	var hidden = func(key: String, part: String) -> bool: return z.has(key) and z[key].has(part) and z[key].people.all(func(v): return v < z[key][part])
	check(ahead.call("sofa:0","back") and ahead.call("sofa:0","base") and z["sofa:0"].people.size() == 3,"On a sofa facing the room all three sit in front of the seat and the backrest")
	check(hidden.call("sofa:2","back") and ahead.call("sofa:2","base"),"On a sofa turned away the backrest hides them, the seat stays under them")
	check(hidden.call("chair:1","back") and ahead.call("chair:0","back"),"A chair turned away hides its sitter's back")
	check(ahead.call("bed:0","head") and hidden.call("bed:2","head"),"The headboard is behind the couple, or in front when the bed is turned")
	check(ahead.call("dance:0","pole") and hidden.call("dance:2","pole"),"The dancer is in front of the pole or behind it, as the stage turns")
	check(ahead.call("shower:0","tiles_a") and ahead.call("shower:0","tiles_b") and hidden.call("shower:0","door") and hidden.call("shower:0","side"),"Inside a shower: in front of the tiles, behind the glass")
	check(ahead.call("shower:3","tiles_a") and hidden.call("shower:3","door") and hidden.call("shower:3","tiles_b"),"…whichever way the shower is turned")
	check(hidden.call("shower:2","tiles_a"),"A shower turned around: its tiled wall stands in front of whoever is inside")
	print("DEPTH_CHECKS %d items, %d people" % [total,people_count])
	model.restore(before)
	changed_view()

func checkpoint_for_test() -> void:
	undo_stack.append(model.snapshot())

func run_sim(steps: int, watch: Callable = Callable()) -> void:
	for i in range(steps):
		sim._process(0.1)
		if watch.is_valid(): watch.call()

func sim_test() -> void:
	# The derelict club with a fixed seed: closed, cleaned, opened without a
	# reception (the line grows outside), then with a receptionist and a bar.
	await get_tree().process_frame
	sim.speed = 1
	sim.minute = 0.0
	run_sim(600)
	check(sim.clients.is_empty() and int(sim.night.clients) == 0,"Nobody enters while the club is closed")
	var debris0 = model.debris().size()
	var before = model.snapshot()
	model.add_item("janitor",-2.0,4.0,0)
	model.add_item("maid",-1.0,2.8,0)
	var vip = model.add_item("escort_vip",-2.4,0.2,0,Characters.hire_look("escort_vip",look_rng))
	commit(before,"hire")
	check(sim.staff.size() == 3 and vip != -1,"Two cleaners and a prestige escort are hired")
	var mops = [false]
	run_sim(2400,func():
		for id in sim.staff:
			if sim.staff[id].anim == "mop": mops[0] = true)
	var debris1 = model.debris().size()
	check(mops[0],"Technicians mop the debris")
	check(debris1 < debris0-4,"Technicians cleared debris (%d -> %d)" % [debris0,debris1])
	var money0 = sim.money
	var rating0 = sim.rating
	# 1. Open without any reception: the line grows outside, nobody gets in.
	sim.minute = 90.0
	toggle_open()
	var longest = [0]
	var outside = [true]
	var sneaked = [false]
	run_sim(1600,func():
		longest[0] = maxi(longest[0],sim.queue.size())
		for c in sim.clients:
			if not is_instance_valid(c): continue
			if c.brain.state == "queue" and not model.room_at(c.world).is_empty(): outside[0] = false
			if not c.brain.paid and c.brain.state in ["choose","walk","busy"]: sneaked[0] = true)
	check(longest[0] >= 4,"Without a reception the line grows in front of the club (%d)" % longest[0])
	check(outside[0],"The line waits outside, in the street")
	check(int(sim.night.entry) == 0 and not sneaked[0],"Nobody gets in without paying")
	check(int(sim.night.impatient) >= 2,"Clients lose patience and walk away (%d)" % int(sim.night.impatient))
	check(sim.rating < rating0,"Impatient clients hurt the reputation (%.2f -> %.2f)" % [rating0,sim.rating])
	# 2. A desk alone is not enough: someone has to be there to take the money.
	before = model.snapshot()
	var desk = model.add_item("reception",1.3,3.0,0)
	commit(before,"desk")
	run_sim(300)
	check(desk != -1 and int(sim.night.entry) == 0,"A desk without a receptionist takes no entrance")
	# 3. A receptionist at the desk, a bar and its bartender: the line moves.
	before = model.snapshot()
	var receptionist = model.add_item("receptionist",1.3,1.6,0)
	var bar_room = model.add_room(3,-7,6,7,0)
	model.set_opening("z:3:-1","door")
	var bar = model.add_item("bar",5.0,-2.6,0)
	var bartender = model.add_item("bartender",6.4,-0.6,0)
	var shower = model.add_item("shower",3.5,3.55,3)
	var floor_id = model.add_item("dancefloor",-1.5,1.2,0)
	var stage_id = model.add_item("dance",7.0,-5.5,0)
	commit(before,"staff")
	check(floor_id != -1,"A dance floor fits in the hall")
	check(stage_id != -1,"The stage and its pole fit in the bar room")
	check(receptionist != -1 and bar_room != -1 and bar != -1 and bartender != -1,"Receptionist, bar room, bar and bartender are set up")
	check(shower != -1,"A shower fits in the bedroom")
	var bed_id = int(model.furniture.filter(func(i): return i.kind == "old_bed")[0].id)
	sim.minute = 90.0
	var impatient_before = int(sim.night.impatient)
	var entries_before = int(sim.night.clients)
	var most = [0]
	var company = [false]
	var unpaid_inside = [false]
	var working = [false]
	var line = [0]
	var seen = {"chat":false,"client_shower":false,"escort_shower":false,"busy":false,"unmade":false,"remade":false,"tissues":false,
		"flirt":false,"action":false,"clothes":false,"shaking":false,"dance":false,"outside":0,"maid_in":0,"maid_run":0,"clothes_out":false,
		"door_ways":0,"wall_ways":0,"shut_ways":0,"door_frames":{}}
	var bedroom = model.room_at(Vector2(5.0,2.0))
	var shower_item = model.item_by_id(shower)
	var shower_rect = model.item_rect(shower_item)
	var shower_door = Catalog.local_to_world(shower_item,ClubSim.SHOWER_DOOR)
	var shower_center = Vector2(shower_item.x,shower_item.z)
	var last_at: Dictionary = {}
	var served0 = int(sim.night.served)
	var watch = func():
		var e = sim.staff.get(vip)
		if e != null and is_instance_valid(e):
			if e.brain.state == "chat": seen.chat = true
			if e.brain.state == "showering": seen.escort_shower = true
		for c in sim.clients:
			if is_instance_valid(c) and c.brain.state == "showering": seen.client_shower = true
		if sim.busy_beds.has(bed_id): seen.busy = true
		for c in sim.clients:
			if not is_instance_valid(c) or not c.brain.has("service") or c.brain.state != "in_service": continue
			if c.brain.service.phase == "undress" and c.visible: seen.flirt = true
			if c.brain.service.phase == "action" and not c.visible: seen.action = true
		if view.clothes.has(bed_id):
			seen.clothes = true
			if not model.rect(bedroom).has_point(view.clothes_at.get(bed_id,Vector2(5,2))): seen.clothes_out = true
		for c in sim.clients:
			if is_instance_valid(c) and c.brain.has("service") and c.brain.service.get("phase","") == "dance":
				var e2 = c.brain.service.get("escort")
				if e2 != null and is_instance_valid(e2) and e2.anim == "dance": seen.dance = true
		# nobody in the middle of a service ever walks around outside the building
		for c in sim.clients:
			if is_instance_valid(c) and c.brain.state in ["to_bed","wait_partner","in_service","showering"] and model.room_at(c.world).is_empty(): seen.outside += 1
		if e != null and is_instance_valid(e) and e.brain.state in ["to_bed","wait_partner","in_service","to_shower_after","showering"] and model.room_at(e.world).is_empty(): seen.outside += 1
		# maids keep out while a couple is in the bedroom
		# (she may need one tick to notice a couple just came in, never longer)
		var lingering = false
		if sim.room_private(bedroom):
			for id in sim.staff:
				var m = sim.staff[id]
				if is_instance_valid(m) and m.kind == "maid" and m.brain.state != "back" and model.rect(bedroom).has_point(m.world): lingering = true
		seen.maid_run = seen.maid_run+1 if lingering else 0
		seen.maid_in = maxi(seen.maid_in,seen.maid_run)
		if float(view.bed_looks.get(bed_id,{}).get("fps",0.0)) > 0.0: seen.shaking = true
		# into and out of the shower only through its door, and only while it is open
		var movers: Array = sim.clients.duplicate()
		if e != null and is_instance_valid(e): movers.append(e)
		for p in movers:
			if not is_instance_valid(p): continue
			var was = last_at.get(p.get_instance_id(),p.world)
			last_at[p.get_instance_id()] = p.world
			if shower_rect.has_point(was) == shower_rect.has_point(p.world): continue
			var out_at: Vector2 = was if shower_rect.has_point(p.world) else p.world
			var lane = Geometry2D.get_closest_point_to_segment(out_at,shower_center,shower_door).distance_to(out_at)
			if lane < 0.3: seen.door_ways += 1
			else: seen.wall_ways += 1
			if int(view.shower_doors.get(int(shower),{}).get("shown",0)) < 2: seen.shut_ways += 1
		seen.door_frames[int(view.shower_doors.get(int(shower),{}).get("shown",0))] = true
		var bed = model.item_by_id(bed_id)
		if bed.get("unmade",false): seen.unmade = true
		elif seen.unmade: seen.remade = true
		if model.furniture.any(func(i): return i.kind == "trash_tissues"): seen.tissues = true
		most[0] = maxi(most[0],sim.inside_count())
		line[0] = maxi(line[0],sim.queue.size())
		if e != null and is_instance_valid(e) and e.brain.state == "lounge": company[0] = true
		var r = sim.staff.get(receptionist)
		if r != null and is_instance_valid(r) and r.brain.state == "working" and r.anim in ["work","sit"]: working[0] = true
		for c in sim.clients:
			if is_instance_valid(c) and not c.brain.paid and c.brain.state in ["choose","walk","busy"]: unpaid_inside[0] = true
	run_sim(4000,watch)
	var impatient_after = int(sim.night.impatient)-impatient_before
	var arrivals = int(sim.night.clients)-entries_before
	run_sim(4000,watch)
	check(working[0],"The receptionist works at her desk")
	check(int(sim.night.entry) > 0,"Clients pay the entrance at the desk (%d $)" % int(sim.night.entry))
	check(not unpaid_inside[0],"Every client inside has paid")
	check(most[0] >= 2,"Several clients were inside at once (%d)" % most[0])
	check(int(sim.night.bar) > 0,"The bartender serves drinks (%d $)" % int(sim.night.bar))
	check(company[0] or seen.chat,"The escort joins clients in the lounge")
	check(seen.chat and int(sim.night.met) >= 1,"An escort meets a client and they talk (%d meetings)" % int(sim.night.met))
	check(int(sim.night.agreed) >= 1 and int(sim.night.served) > served0,"They agree and go up to a bedroom (%d deals, %d refusals)" % [int(sim.night.agreed),int(sim.night.refused)])
	check(int(sim.night.private) > 0,"Services are paid (%d $)" % int(sim.night.private))
	check(seen.busy,"The couple disappears under the covers")
	check(seen.flirt and seen.action,"They flirt on the edge of the bed, then dive under the covers")
	check(seen.clothes and not seen.clothes_out,"Clothes land on the bedroom floor, inside the room")
	check(seen.dance,"She dances for him in front of the bed before the covers")
	check(seen.outside == 0,"Nobody goes out through the wall to reach or leave the bed or the shower (%d)" % seen.outside)
	check(seen.maid_in <= 2,"The maid never stays in the room while a couple is there (longest %d ticks)" % seen.maid_in)
	check(seen.shaking,"Bed-based visits still animate the bed")
	check(seen.client_shower and seen.escort_shower,"The client showers before, the escort after")
	check(seen.door_ways >= 8 and seen.wall_ways == 0,"People step in and out of the shower through its door only (%d through the door, %d elsewhere)" % [seen.door_ways,seen.wall_ways])
	check(seen.shut_ways == 0,"Never through a shut door (%d)" % seen.shut_ways)
	print("SIM_SHOWER through the door %d, elsewhere %d, door shut %d" % [seen.door_ways,seen.wall_ways,seen.shut_ways])
	check(seen.door_frames.has(1) and seen.door_frames.has(2) and seen.door_frames.has(3),"The shower door swings open and shut (%s)" % str(seen.door_frames.keys()))
	check(seen.unmade and seen.remade,"The bed is left unmade, then the maid makes it")
	check(seen.tissues or int(sim.night.served)-served0 < 3,"Used tissues are left behind for the cleaners")
	check(int(sim.night.tips) > 0,"Generous clients tip the escort on the dance floor (%d $)" % int(sim.night.tips))
	check(int(sim.night.floor_dates) >= 1,"A generous client takes her upstairs straight from the dance floor (%d)" % int(sim.night.floor_dates))
	check(int(sim.night.stage_tips) > 0,"Generous watchers tip the pole dancer (%d $)" % int(sim.night.stage_tips))
	check(int(sim.night.stage_dates) >= 1,"A generous watcher takes her upstairs straight from the stage (%d)" % int(sim.night.stage_dates))
	print("SIM_FLOOR tips %d $ (stage %d $), dates from the floor %d, from the stage %d" % [int(sim.night.tips),int(sim.night.stage_tips),int(sim.night.floor_dates),int(sim.night.stage_dates)])
	print("SIM_SERVICES met %d, agreed %d, refused %d, served %d (quick %d, classic %d, full %d), income %d $, showers %d, beds made %d, infections %d" % [int(sim.night.met),int(sim.night.agreed),int(sim.night.refused),int(sim.night.served)-served0,int(sim.night.tier_0),int(sim.night.tier_1),int(sim.night.tier_2),int(sim.night.private),int(sim.night.showers),int(sim.night.beds_made),int(sim.night.infections)])
	check(int(sim.night.wages) > 0,"Wages were paid")
	check(impatient_after <= 2,"With a receptionist at the desk the line keeps moving (%d impatient out of %d)" % [impatient_after,arrivals])
	print("SIM_PHASE3 arrivals %d, impatient %d, longest line %d" % [arrivals,impatient_after,line[0]])
	# Health: a service caught without hygiene makes an escort ill; she rests, then comes back.
	var sick_e = sim.staff.get(vip)
	sick_e.brain.health = 50.0
	sim.roll_escort(sick_e,1.0)
	check(sick_e.brain.state == "sick" and float(sick_e.brain.sick) > 0,"A sick escort stops working")
	run_sim(40)
	check(sick_e.brain.state == "sick" and not sim.clients.any(func(c): return is_instance_valid(c) and c.brain.get("escort") == sick_e),"She does not meet clients while ill")
	run_sim(2600)
	check(sick_e.brain.state != "sick" and float(sick_e.brain.health) >= 70.0,"She recovers after resting")
	toggle_open()
	run_sim(1200)
	check(sim.clients.is_empty() and sim.queue.is_empty(),"Clients and the line left after closing (%d)" % sim.clients.size())
	check(sim.busy_beds.is_empty() and sim.staff.values().all(func(a): return is_instance_valid(a) and a.visible),"Nobody is left hidden in a bed")
	var entries = int(sim.night.clients)
	run_sim(800)
	check(int(sim.night.clients) == entries,"Nobody else comes in once closed")
	print("SIM_REPORT money %d -> %d, rating %.2f -> %.2f, clients %d, longest line %d, impatient %d, entry %d $, bar %d $, debris %d -> %d" % [money0,sim.money,rating0,sim.rating,entries,longest[0],int(sim.night.impatient),int(sim.night.entry),int(sim.night.bar),debris0,model.debris().size()])
	print("SIM_TEST_RESULT: %d failures" % failures)
	if failures == 0: print("SIM_TEST_PASSED")
	get_tree().quit(1 if failures > 0 else 0)

func ui_click(control: Control) -> void:
	# Move the pointer first, like a player would: it also dismisses the
	# tooltip left open by the previous button.
	var r = control.get_global_rect()
	var p = r.get_center()
	var m = InputEventMouseMotion.new()
	m.position = p
	m.global_position = p
	Input.parse_input_event(m)
	await get_tree().process_frame
	for pressed in [true,false]:
		var e = InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = pressed
		e.position = p
		e.global_position = p
		Input.parse_input_event(e)
		await get_tree().process_frame

func world_click(x: float, z: float) -> void:
	var p = (Iso.to_screen(x,z)-camera.position)*float(zoom)
	var m = InputEventMouseMotion.new()
	m.position = p
	m.global_position = p
	Input.parse_input_event(m)
	await get_tree().process_frame
	for pressed in [true,false]:
		var e = InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = pressed
		e.position = p
		e.global_position = p
		Input.parse_input_event(e)
		await get_tree().process_frame

func world_drag(a: Vector2, b: Vector2) -> void:
	var pa = (Iso.to_screen(a.x,a.y)-camera.position)*float(zoom)
	var pb = (Iso.to_screen(b.x,b.y)-camera.position)*float(zoom)
	var e = InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	e.position = pa
	e.global_position = pa
	Input.parse_input_event(e)
	await get_tree().process_frame
	for i in range(1,6):
		var m = InputEventMouseMotion.new()
		m.position = pa.lerp(pb,i/5.0)
		m.global_position = m.position
		m.button_mask = MOUSE_BUTTON_MASK_LEFT
		Input.parse_input_event(m)
		await get_tree().process_frame
	var r = InputEventMouseButton.new()
	r.button_index = MOUSE_BUTTON_LEFT
	r.pressed = false
	r.position = pb
	r.global_position = pb
	Input.parse_input_event(r)
	await get_tree().process_frame

func ui_capture(dir: String, name: String) -> void:
	if dir == "": return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir.path_join(name))

func parking_hover(point: Vector2) -> void:
	var motion = InputEventMouseMotion.new()
	motion.position = (Iso.to_screen(point.x,point.y)-camera.position)*float(zoom)
	motion.global_position = motion.position
	Input.parse_input_event(motion)
	await get_tree().process_frame

func parking_key_r() -> void:
	var event = InputEventKey.new()
	event.keycode = KEY_R
	event.pressed = true
	Input.parse_input_event(event)
	await get_tree().process_frame
	event = InputEventKey.new()
	event.keycode = KEY_R
	Input.parse_input_event(event)
	await get_tree().process_frame

func parking_ui_checks(dir: String) -> void:
	hud.close_drawer()
	var previous_camera = camera.position
	camera.position = (Iso.to_screen(12,-1)-Vector2(viewport.size)/2.0).round()
	parking_rotation = 1
	set_mode("parking")
	await get_tree().process_frame
	var money0 = sim.money
	var count0 = model.parkings.size()
	var undo0 = undo_stack.size()
	var centre = Vector2(10.5,-2.75)
	await parking_hover(centre)
	check(view.preview_node != null and view.preview_node.get_meta("bay_count") == 1,"Hover previews one exact module before clicking")
	check(view.preview_node.get_child(0).color.g > view.preview_node.get_child(0).color.r,"Free module is green")
	for rotation in [2,3,0,1]:
		await parking_key_r()
		check(parking_rotation == rotation,"R cycles all four parking orientations")
	await ui_capture(dir,"parking-green.png")
	await world_click(centre.x,centre.y)
	check(model.parkings.size() == count0+1 and mode == "parking","One click places a bay and keeps the tool active")
	check(sim.money == money0-375,"One exact 2.5 x 5 m module costs 375 dollars")
	var pk = model.parking_at(centre)
	var id = int(pk.get("id",-1))
	check(id >= 0 and pk.w == 5 and pk.h == 2.5,"Single bay footprint and facing match the preview")
	var original_bay = model.parking_layout(pk).bays[0].rect if id >= 0 else Rect2()
	await world_click(10.6,-0.2)
	check(model.parkings.size() == count0+1 and model.parking_layout(model.parking_by_id(id)).bays.size() == 2,"Adjacent click snaps and joins the existing row")
	check(model.parking_layout(model.parking_by_id(id)).bays[0].rect == original_bay,"Adding a bay never shifts the first one")
	await world_drag(Vector2(10.5,2.25),Vector2(10.5,4.75))
	check(model.parking_layout(model.parking_by_id(id)).bays.size() == 4,"Dragging adds two bays side by side")
	check(sim.money == money0-1500,"Only the four placed modules are charged")
	set_mode("select")
	await world_click(9,-3)
	check(selected_parking == id,"Clicking a row selects its extension controls")
	var extend: Button = null
	for child in hud.context_body.get_children():
		if child is Button and child.text.begins_with("+1 au début"): extend = child
	check(extend != null and not extend.disabled,"One-click extension is available in the selection panel")
	if extend != null: await ui_click(extend)
	check(model.parking_layout(model.parking_by_id(id)).bays.size() == 5,"Extension button adds exactly one bay")
	undo()
	check(model.parking_layout(model.parking_by_id(id)).bays.size() == 4 and sim.money == money0-1500,"Undo restores the previous row and its money")
	redo()
	check(model.parking_layout(model.parking_by_id(id)).bays.size() == 5 and sim.money == money0-1875,"Redo restores the extension")
	set_mode("parking_lane")
	await world_drag(Vector2(13.25,-6.25),Vector2(18.75,7.75))
	check(model.parkings.size() == count0+2,"A separately drawn aisle joins the row and the street")
	var lane = model.parking_at(Vector2(15,0))
	check(lane.get("kind","") == "lane" and lane.w == 6 and lane.h == 14.5,"Aisle follows the half-metre drag exactly")
	var shared_kerbs = 0
	for module in model.parkings:
		for edge in model.parking_edges(module):
			if is_equal_approx(edge.a.x,13.0) and is_equal_approx(edge.b.x,13.0) and edge.a.y >= -6.5 and edge.b.y <= 6.0: shared_kerbs += 1
	check(shared_kerbs == 0,"There is no kerb between the row and its aisle")
	set_mode("select")
	hud.toast_time = 0
	await ui_capture(dir,"parking-modular.png")
	var money_before_invalid = sim.money
	set_mode("parking")
	await parking_hover(Vector2(15.5,-3.25))
	check(view.preview_node.get_child(0).color.r > view.preview_node.get_child(0).color.g,"A tandem bay blocking the row entrance is red")
	await ui_capture(dir,"parking-red.png")
	await world_click(15.5,-3.25)
	check(model.parkings.size() == count0+2 and sim.money == money_before_invalid,"Invalid click changes neither parking nor money")
	await parking_key_r()
	await parking_key_r()
	await world_click(21.5,-3.25)
	check(model.parkings.size() == count0+3,"Opposite-facing row can share the same aisle")
	while undo_stack.size() > undo0: undo()
	check(model.parkings.size() == count0 and sim.money == money0,"All modular edits undo cleanly")
	set_mode("select")
	camera.position = previous_camera

func ui_test() -> void:
	var dir = ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--ui-output="): dir = arg.trim_prefix("--ui-output=")
	await get_tree().create_timer(0.5).timeout
	set_speed(0)
	hud.toast_time = 0
	await ui_capture(dir,"01-club.png")
	for key in ["build","decor","staff","clients","settings"]:
		await ui_click(hud.tool_buttons[key])
		await get_tree().process_frame
		check(hud.active == key and hud.drawer.visible,"Toolbar opens "+key)
		await ui_capture(dir,"02-panel-%s.png" % key)
	await ui_click(hud.tool_buttons["settings"])
	check(not hud.drawer.visible,"Clicking the active tool closes its panel")
	# Dialog windows can be dragged by their title bar.
	hud.show_help()
	await get_tree().process_frame
	await get_tree().process_frame
	var win: Control = hud.modal.get_meta("window")
	var before_pos = win.position
	var grab = win.bar.get_global_rect().get_center()
	for step in [[true,Vector2.ZERO],[null,Vector2(30,20)],[false,Vector2(30,20)]]:
		if step[0] == null:
			var mm = InputEventMouseMotion.new()
			mm.position = grab+step[1]
			mm.global_position = mm.position
			mm.relative = step[1]
			mm.button_mask = MOUSE_BUTTON_MASK_LEFT
			Input.parse_input_event(mm)
		else:
			var e = InputEventMouseButton.new()
			e.button_index = MOUSE_BUTTON_LEFT
			e.pressed = step[0]
			e.position = grab+step[1]
			e.global_position = e.position
			Input.parse_input_event(e)
		await get_tree().process_frame
	check(win.position != before_pos,"Windows move when their title bar is dragged")
	await ui_capture(dir,"02-help-window.png")
	hud.close_modal()
	# Place a stool through the decoration panel, then undo.
	hud.toggle_drawer("decor")
	await get_tree().process_frame
	hud.close_drawer()
	choose_item("stool")
	var count = model.furniture.size()
	await world_click(-2.5,1.0)
	check(model.furniture.size() == count+1,"Clicking the floor places the chosen object")
	undo()
	check(model.furniture.size() == count,"Undo removes it")
	hud.close_drawer()
	# Draw a room with the mouse, then open a door in its wall.
	set_mode("room")
	room_type = 5
	var rooms_before = model.rooms.size()
	await world_drag(Vector2(12.5,-5.5),Vector2(14.5,-3.5))
	check(model.rooms.size() == rooms_before+1,"Dragging on the ground builds a room")
	var built = model.room_at(Vector2(13.5,-4.5))
	check(not built.is_empty() and int(built.w) == 3 and int(built.h) == 3 and int(built.type) == 5,"The new room follows the drag")
	set_mode("door")
	await world_click(13.5,-3.02)
	check(model.openings.get("x:13:-3","") == "door","Clicking a wall adds a door")
	undo()
	undo()
	check(model.rooms.size() == rooms_before,"Undo removes the new room")
	await parking_ui_checks(dir)
	# Select the bar by clicking its sprite.
	set_mode("select")
	var bar = model.furniture.filter(func(i): return i.kind == "old_sofa")[0]
	# People walking in front of the sofa would legitimately catch the click.
	for a in view.actors: a.visible = false
	await world_click(bar.x,bar.z)
	for a in view.actors:
		if not a.has_meta("courier") and not a.has_meta("delivery_vehicle"): a.visible = true
	check(selected_item == int(bar.id),"Clicking the old sofa selects it (got %d)" % selected_item)
	check(sim.staff.values().all(func(a): return is_instance_valid(a) and a.get_parent() == view.sorted),"Staff survive a rebuild of the view")
	check(hud.context.visible,"Selection shows the context panel")
	await ui_capture(dir,"03-selection.png")
	# Room selection and finish editor
	var lounge = model.rooms[0]
	select_room(int(lounge.id))
	edit_finishes(int(lounge.id))
	await get_tree().process_frame
	check(hud.modal_open(),"Finish editor opens")
	await ui_capture(dir,"04-finishes.png")
	hud.close_modal()
	# Open the club with its button.
	await ui_click(hud.open_button)
	check(sim.open,"The Open button opens the club")
	await ui_click(hud.open_button)
	check(not sim.open,"Clicking again closes it")
	# Appearance editor on a newly hired technician
	var hire_before = model.snapshot()
	model.add_item("janitor",-2.0,4.0,0)
	commit(hire_before,"hire")
	var escort = model.furniture.filter(func(i): return i.kind == "janitor")[0]
	select_item(int(escort.id))
	edit_appearance(int(escort.id))
	await get_tree().process_frame
	check(hud.modal_open(),"Appearance editor opens")
	await ui_capture(dir,"05-appearance.png")
	hud.close_modal()
	clear_selection()
	refresh()
	# Let the club run a little and capture the lively scene.
	toggle_open()
	set_speed(3)
	await get_tree().create_timer(6.0).timeout
	set_speed(0)
	hud.toast_time = 0
	await ui_capture(dir,"06-soiree.png")
	await set_zoom(3)
	camera.position = (Iso.to_screen(-3,3)-Vector2(viewport.size)/2.0).round()
	await get_tree().create_timer(0.3).timeout
	await ui_capture(dir,"07-zoom-x3.png")
	await delivery_ui_checks(dir)
	print("UI_TEST_RESULT: %d failures" % failures)
	if failures == 0: print("UI_TEST_PASSED")
	get_tree().quit(1 if failures > 0 else 0)

func delivery_test() -> void:
	await get_tree().process_frame
	load("res://scripts/delivery_checks.gd").run(self)
	print("DELIVERY_TEST_PASSED" if failures == 0 else "DELIVERY_TEST_FAILED")
	get_tree().quit(0 if failures == 0 else 1)

func capture_delivery() -> void:
	# A reproducible real shipment in the starter club, not a staged overlay.
	var before = model.snapshot()
	model.furniture = model.furniture.filter(func(i): return not Catalog.is_debris(i.kind) and i.kind != "old_sofa")
	model.purchase_item("sofa",-2.4,1.8,3)
	model.purchase_item("lamp",1.2,3.0,0)
	model.purchase_item("fridge",1.5,-2.6,0)
	commit(before,"Livraison")
	deliveries.enabled = false
	var delivery_seconds = 27.0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--delivery-at="): delivery_seconds = float(arg.trim_prefix("--delivery-at="))
	for i in range(int(delivery_seconds*10)): deliveries.step(.1)

func delivery_ui_checks(dir: String) -> void:
	sim.active = false
	deliveries.enabled = false
	for c in sim.clients.duplicate(): sim.remove_client(c)
	model.rooms.clear()
	model.furniture.clear()
	model.openings.clear()
	model.parkings.clear()
	model.add_room(-5,-3,10,10,0)
	model.set_opening("x:-1:7","door")
	changed_view()
	await set_zoom(2)
	camera.position = (Iso.to_screen(0,4)-Vector2(viewport.size)/2).round()
	hud.close_drawer()
	choose_item("sofa")
	await world_click(-3,0)
	var sofas = model.furniture.filter(func(i): return i.kind == "sofa")
	check(sofas.size() == 1 and sofas[0].get("delivery_pending",false),"Buying through mouse creates a ghost")
	choose_item("lamp")
	await world_click(2,1)
	check(deliveries.queue.size() == 2,"UI purchases join same order")
	await ui_click(hud.delivery_button)
	check(hud.active == "deliveries" and hud.drawer.visible,"Delivery button opens order tracking")
	await ui_capture(dir,"delivery-order.png")
	hud.close_drawer()
	clear_selection()
	refresh()
	await ui_capture(dir,"delivery-ghosts.png")
	for i in range(260): deliveries.step(.1)
	check(deliveries.truck.visible and deliveries.phase == "unload","Truck opens and couriers start in real view")
	await ui_capture(dir,"delivery-truck.png")
	var saw_unpack = false
	for i in range(700):
		deliveries.step(.1)
		if not saw_unpack and deliveries.jobs.any(func(j): return j.state == "unpack"):
			saw_unpack = true
			await ui_capture(dir,"delivery-unpack.png")
		if deliveries.phase == "idle": break
	check(saw_unpack,"Visible unpacking stage precedes installation")
	check(model.furniture.all(func(i): return not i.get("delivery_pending",false)),"UI purchases become real furniture")
	check(not deliveries.truck.visible,"Truck leaves after delivery")
	await ui_capture(dir,"delivery-installed.png")
