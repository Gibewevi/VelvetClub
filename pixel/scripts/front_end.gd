class_name FrontEnd
extends Control

const INTRO_SECONDS = 3.3
var saves = ClubSaves.new()
var phase = "intro"
var intro_time = 0.0
var intro: Control
var menu: Control
var backdrop: MenuBackdrop
var menu_column: VBoxContainer
var buttons: Array[Button] = []
var load_button: Button
var notice: Label
var load_overlay: Control
var load_notice: Label
var curtain: ColorRect
var transition: Tween
var last_error = ""
var entries: Array = []
var pixel_scale = 3

func _ready() -> void:
	get_tree().auto_accept_quit = false
	if ClubSaves.bypass_menu(OS.get_cmdline_user_args()):
		phase = "bypass"
		get_tree().change_scene_to_file.call_deferred("res://main.tscn")
		return
	Art.load_all()
	UiKit.setup(3 if get_viewport_rect().size.x >= 2400 else 2)
	theme = UiKit.theme
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	build_menu()
	build_intro()
	curtain = ColorRect.new()
	curtain.color = Color("100e1b")
	curtain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	curtain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	curtain.modulate.a = 0
	add_child(curtain)
	get_viewport().size_changed.connect(layout)
	layout()
	if get_tree().has_meta("club_menu_notice"):
		notice.text = str(get_tree().get_meta("club_menu_notice"))
		get_tree().remove_meta("club_menu_notice")
	if get_tree().has_meta("club_skip_intro"):
		get_tree().remove_meta("club_skip_intro")
		show_menu(false)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--intro-capture="): capture_screen.call_deferred(arg.trim_prefix("--intro-capture="),true)
		if arg.begins_with("--menu-capture="): capture_screen.call_deferred(arg.trim_prefix("--menu-capture="),false)

func build_intro() -> void:
	intro = Control.new()
	intro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(intro)
	var bg = ColorRect.new()
	bg.color = Color("100e1b")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	intro.add_child(bg)
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	intro.add_child(center)
	var column = VBoxContainer.new()
	column.add_theme_constant_override("separation",24)
	center.add_child(column)
	var logo = StudioLogo.new()
	logo.animated = true
	logo.custom_minimum_size = Vector2(684,200)
	column.add_child(logo)
	var caption = UiKit.label("DES MONDES À CONSTRUIRE, PIXEL PAR PIXEL",1,UiKit.MUTED)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(caption)
	var skip = UiKit.label("Une touche ou un clic pour passer",1,UiKit.DIM)
	skip.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	skip.offset_top = -66
	skip.offset_bottom = -32
	skip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro.add_child(skip)

func build_menu() -> void:
	menu = Control.new()
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(menu)
	backdrop = MenuBackdrop.new()
	menu.add_child(backdrop)
	menu_column = VBoxContainer.new()
	menu_column.add_theme_constant_override("separation",16)
	menu.add_child(menu_column)
	var studio = StudioLogo.new()
	studio.custom_minimum_size = Vector2(480,80)
	menu_column.add_child(studio)
	var game_title = UiKit.label("VELVET CLUB",3,Color("fff2d8"))
	game_title.add_theme_font_size_override("font_size",44)
	menu_column.add_child(game_title)
	var tag = UiKit.label("Votre club. Votre histoire.",1,UiKit.MUTED)
	menu_column.add_child(tag)
	var gap = Control.new()
	gap.custom_minimum_size.y = 18
	menu_column.add_child(gap)
	menu_button("Nouvelle partie",start_new,"plus")
	load_button = menu_button("Charger une partie",show_load,"save")
	menu_button("Quitter",leave_game,"exit")
	notice = UiKit.label("",1,UiKit.MUTED)
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notice.custom_minimum_size.y = 62
	menu_column.add_child(notice)
	var footer = UiKit.label("BIT-GAMES  ·  PIXEL ART & GESTION",1,UiKit.DIM)
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	footer.offset_left = 36
	footer.offset_top = -46
	footer.offset_bottom = -20
	menu.add_child(footer)
	menu.hide()
	refresh_saves()

func menu_button(text: String, action: Callable, icon_name: String) -> Button:
	var holder = Control.new()
	holder.custom_minimum_size.y = 58
	menu_column.add_child(holder)
	var button = UiKit.button(text,action,holder,"",icon_name)
	button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_stylebox_override("focus",UiKit.flat(Color(0,0,0,0),Color("f4a9cc")))
	var motion = {"tween":null}
	var highlight = func(active: bool):
		if is_instance_valid(motion.tween): motion.tween.kill()
		motion.tween = create_tween().set_parallel(true)
		motion.tween.tween_property(button,"offset_left",6.0 if active else 0.0,.12)
		motion.tween.tween_property(button,"modulate",Color("ffcfdf") if active else Color.WHITE,.12)
	button.mouse_entered.connect(func(): if not button.disabled: highlight.call(true))
	button.mouse_exited.connect(func(): highlight.call(button.has_focus()))
	button.focus_entered.connect(func(): highlight.call(true))
	button.focus_exited.connect(func(): highlight.call(false))
	buttons.append(button)
	return button

func layout() -> void:
	pixel_scale = maxi(2,int(minf(get_viewport_rect().size.x/480.0,get_viewport_rect().size.y/300.0)))
	backdrop.scale = Vector2.ONE*pixel_scale
	backdrop.position = ((get_viewport_rect().size-Vector2(480,300)*pixel_scale)/2.0).floor()
	menu_column.position = backdrop.position+Vector2(22,42)*pixel_scale
	menu_column.get_child(0).custom_minimum_size.x = 174*pixel_scale
	menu_column.get_child(0).custom_minimum_size.y = 25*pixel_scale
	menu_column.add_theme_constant_override("separation",5*pixel_scale)
	menu_column.get_child(1).add_theme_font_size_override("font_size",14*pixel_scale)
	for button in buttons: button.get_parent().custom_minimum_size.y = 18*pixel_scale
	# Resolve the new child minimum sizes before fitting the column. Otherwise
	# the original logo width keeps buttons too wide at 1024 x 640.
	menu_column.call_deferred("reset_size")
	if load_overlay != null: close_load()

func _process(delta: float) -> void:
	if phase == "intro":
		intro_time += delta
		if intro_time >= INTRO_SECONDS: show_menu()

func _input(event: InputEvent) -> void:
	if phase != "intro": return
	var key = event is InputEventKey and event.pressed and not event.echo
	var click = event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT]
	if key or click:
		get_viewport().set_input_as_handled()
		show_menu()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE and load_overlay != null:
		close_load()
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST: get_tree().quit()

func show_menu(animate: bool = true) -> void:
	if phase not in ["intro","transition"]: return
	phase = "transition"
	menu.show()
	menu.modulate.a = 0 if animate else 1
	if animate:
		transition = create_tween().set_parallel(true)
		transition.tween_property(intro,"modulate:a",0,.22)
		transition.tween_property(menu,"modulate:a",1,.32)
		await transition.finished
	intro.hide()
	phase = "menu"
	buttons[0].grab_focus()

func refresh_saves() -> void:
	entries = saves.list_saves()
	if load_button != null:
		load_button.disabled = entries.is_empty()
		load_button.tooltip_text = "Aucune partie enregistrée pour le moment." if entries.is_empty() else "Retrouver vos clubs enregistrés sur cet ordinateur."

func start_new() -> bool:
	if phase != "menu": return false
	var path = saves.new_path()
	if path == "":
		last_error = "Impossible de créer une sauvegarde sur cet ordinateur."
		notice.text = last_error
		return false
	launch(path,true,ClubSaves.new_title())
	return true

func show_load() -> void:
	if phase != "menu" or load_overlay != null: return
	refresh_saves()
	load_overlay = Control.new()
	load_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(load_overlay)
	var dim = ColorRect.new()
	dim.color = Color(.035,.025,.07,.9)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	load_overlay.add_child(dim)
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	load_overlay.add_child(center)
	var panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel",UiKit.window_box())
	panel.custom_minimum_size = Vector2(minf(780,get_viewport_rect().size.x-80),minf(580,get_viewport_rect().size.y-100))
	center.add_child(panel)
	var column = VBoxContainer.new()
	column.add_theme_constant_override("separation",18)
	panel.add_child(column)
	column.add_child(UiKit.label("CHARGER UNE PARTIE",3,UiKit.INK))
	column.add_child(UiKit.label("Choisissez le club à retrouver.",1,UiKit.MUTED))
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation",12)
	scroll.add_child(list)
	var first: Button
	for entry in entries:
		var text = entry.title+"\n"
		text += "Jour %d   ·   %s $" % [entry.day,UiKit.money(entry.money)] if entry.valid else "Illisible · fichier conservé"
		var b = UiKit.button(text,func(): load_saved(entry.path),list)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size.y = 76
		b.disabled = not entry.valid
		b.focus_mode = Control.FOCUS_ALL
		b.add_theme_stylebox_override("focus",UiKit.flat(Color(0,0,0,0),Color("f4a9cc")))
		b.tooltip_text = entry.get("error",entry.path.get_file())
		if first == null and entry.valid: first = b
	if entries.is_empty(): list.add_child(UiKit.label("Aucune partie enregistrée.",1,UiKit.MUTED))
	load_notice = UiKit.label("",1,UiKit.RED)
	load_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(load_notice)
	var back = UiKit.button("Retour",close_load,column)
	back.focus_mode = Control.FOCUS_ALL
	for button in buttons: button.focus_mode = Control.FOCUS_NONE
	if first != null: first.grab_focus()
	else: back.grab_focus()

func close_load() -> void:
	if load_overlay == null: return
	load_overlay.queue_free()
	load_overlay = null
	load_notice = null
	for button in buttons: button.focus_mode = Control.FOCUS_ALL
	load_button.grab_focus()

func load_saved(path: String) -> bool:
	if phase != "menu": return false
	var result = saves.read(path)
	if not result.has("data"):
		last_error = result.error
		if load_notice != null: load_notice.text = last_error
		else: notice.text = last_error
		return false
	launch(path,false,"")
	return true

func launch(path: String, fresh: bool, title: String) -> void:
	phase = "leaving"
	for button in buttons: button.disabled = true
	curtain.move_to_front()
	curtain.mouse_filter = Control.MOUSE_FILTER_STOP
	transition = create_tween()
	transition.tween_property(curtain,"modulate:a",1,.22)
	await transition.finished
	get_tree().set_meta("club_launch",{"path":path,"fresh":fresh,"title":title})
	var error = get_tree().change_scene_to_file("res://main.tscn")
	if error != OK:
		get_tree().remove_meta("club_launch")
		phase = "menu"
		curtain.modulate.a = 0
		curtain.mouse_filter = Control.MOUSE_FILTER_IGNORE
		last_error = "Impossible d'ouvrir le jeu."
		notice.text = last_error
		for button in buttons: button.disabled = false
		refresh_saves()

func leave_game() -> void:
	if phase != "menu": return
	phase = "leaving"
	curtain.move_to_front()
	curtain.mouse_filter = Control.MOUSE_FILTER_STOP
	transition = create_tween()
	transition.tween_property(curtain,"modulate:a",1,.18)
	await transition.finished
	get_tree().quit()

func capture_screen(path: String, studio: bool) -> void:
	if studio:
		await get_tree().create_timer(1.7).timeout
	else:
		show_menu(false)
		await get_tree().create_timer(.5).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()
