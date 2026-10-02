class_name Hud
extends Control

# Management interface in the retro window style of the earlier builds,
# redrawn as pixel art: status top-left, counters and history top-right, a
# dock of icon + text buttons at the bottom, and every panel or dialog in a
# window with a title bar.
const DOCK = [["select","Sélection","select","Sélection · Échap"],["build","Construire","build","Pièces, portes, fenêtres, parkings · T P F K"],
	["decor","Mobilier","furniture","Catalogue du mobilier · B"],["staff","Personnel","person","Embaucher et suivre l'équipe"],
	["clients","Clients","clients","Clients présents"],["services","Services","services","Tarifs"],
	["reports","Rapports","reports","Recettes et nuits précédentes"],["settings","Menu","menu","Vue et partie"]]
const TITLES = {"build":"Construire","decor":"Mobilier","staff":"Personnel","clients":"Clients","services":"Services","reports":"Rapports","settings":"Menu"}
var game
var S = 2
var money_label: Label
var time_label: Label
var day_label: Label
var stars: HBoxContainer
var clients_label: Label
var debris_label: Label
var queue_label: Label
var sat_label: Label
var open_button: Button
var delivery_button: Button
var sat_icon: TextureRect
var speed_buttons: Dictionary = {}
var tool_buttons: Dictionary = {}
var undo_button: Button
var redo_button: Button
var drawer: UiKit.RetroWindow
var drawer_body: VBoxContainer
var drawer_scroll: ScrollContainer
var active = ""
var context: UiKit.RetroWindow
var context_body: VBoxContainer
var toast_label: Label
var toast_time = 0.0
var hover_label: Label
var modal: Control
var modal_on_close: Callable
var mode_label: Label
var catalog_filter = -2
var catalog_search = ""
var portrait_cache: Dictionary = {}
var thumb_cache: Dictionary = {}
var live_refresh = 0.0
var sanitary_label: Label
var hygiene_label: Label
var hygiene_gauge: ProgressBar
var demand_label: Label
var staff_context_label: Label
var site_bar: ProgressBar
var site_label: Label
var site_phase_label: Label
var site_time_label: Label
var site_room = -1
var site_refresh = 0.0
var drawer_live = true
var drawer_refresh = 0.0   # lists of people and reports: redrawn every 2 s, not 2 per s

func build(game_ref) -> void:
	game = game_ref
	S = UiKit.scale
	theme = UiKit.theme
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	build_status()
	build_top_right()
	build_dock()
	build_drawer()
	build_context()
	toast_label = UiKit.label("",1)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	toast_label.offset_left = -320*S
	toast_label.offset_right = 320*S
	toast_label.offset_top = -48*S
	toast_label.offset_bottom = -38*S
	toast_label.add_theme_color_override("font_shadow_color",Color("08060e"))
	toast_label.add_theme_constant_override("shadow_offset_x",S)
	toast_label.add_theme_constant_override("shadow_offset_y",S)
	toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(toast_label)
	mode_label = UiKit.label("",1,UiKit.ACCENT)
	mode_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mode_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	mode_label.offset_left = -200*S
	mode_label.offset_right = 200*S
	mode_label.offset_top = 10*S
	mode_label.add_theme_color_override("font_shadow_color",Color("08060e"))
	mode_label.add_theme_constant_override("shadow_offset_x",S)
	mode_label.add_theme_constant_override("shadow_offset_y",S)
	mode_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(mode_label)
	hover_label = UiKit.label("",1)
	hover_label.add_theme_stylebox_override("normal",UiKit.button_box("tooltip"))
	hover_label.visible = false
	hover_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hover_label)

# ------------------------------------------------------------------ fixed bars

func build_status() -> void:
	var p = UiKit.panel(self)
	p.position = Vector2(6,6)*S
	p.custom_minimum_size.x = 112*S
	var col = UiKit.vbox(p,1)
	var row = UiKit.hbox(col,4)
	row.add_child(UiKit.icon("dollar",UiKit.GREEN))
	money_label = UiKit.label("0",3)
	row.add_child(money_label)
	var row2 = UiKit.hbox(col,4)
	row2.add_child(UiKit.icon("clock"))
	time_label = UiKit.label("20:00",3)
	row2.add_child(time_label)
	var row3 = UiKit.hbox(col,2)
	stars = UiKit.hbox(row3,1)
	for i in range(5): stars.add_child(UiKit.icon("star",UiKit.GOLD))
	day_label = UiKit.label("",1,UiKit.MUTED)
	day_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	day_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row3.add_child(day_label)
	UiKit.separator(col)
	var speeds = UiKit.hbox(col,2)
	for entry in [["pause",0,"Pause · Espace"],["play",1,"Vitesse normale · 1"],["fast",3,"Accéléré · 2"]]:
		speed_buttons[entry[1]] = UiKit.icon_button(entry[0],game.set_speed.bind(entry[1]),speeds,entry[2])
	open_button = UiKit.button("Fermé",func(): game.toggle_open(),col,"Ouvrir ou fermer le club · O","door")
	open_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	demand_label = wrap_label("",1,UiKit.MUTED)
	demand_label.custom_minimum_size.x = 102*S
	col.add_child(demand_label)
	delivery_button = UiKit.button("Livraisons",func(): toggle_drawer("deliveries"),col,"Suivre les commandes et leurs colis","furniture")
	delivery_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	sanitary_label = UiKit.label("",1,UiKit.GOLD)
	col.add_child(sanitary_label)

func build_top_right() -> void:
	var row = UiKit.hbox(self,4)
	row.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	row.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	row.offset_right = -6*S
	row.offset_top = 6*S
	var stats = UiKit.panel(row)
	var srow = UiKit.hbox(stats,4)
	for entry in [["clients","Clients présents dans le club"],["wait","File d'attente devant le club (elle n'avance que si un(e) réceptionniste encaisse l'entrée)"],["delete","Déchets à nettoyer"],["smile","Satisfaction moyenne des clients"]]:
		var cell = UiKit.hbox(srow,3)
		cell.tooltip_text = entry[1]
		cell.mouse_filter = Control.MOUSE_FILTER_PASS
		var ic = UiKit.icon(entry[0],UiKit.ACCENT if entry[0] == "clients" else UiKit.INK)
		cell.add_child(ic)
		var l = UiKit.label("0",1)
		l.custom_minimum_size.x = 28*S
		cell.add_child(l)
		match entry[0]:
			"clients": clients_label = l
			"wait": queue_label = l
			"delete": debris_label = l
			"smile":
				sat_label = l
				sat_icon = ic
	var history = UiKit.panel(row)
	var hrow = UiKit.hbox(history,2)
	undo_button = UiKit.icon_button("undo",func(): game.undo(),hrow,"Annuler · Ctrl + Z")
	redo_button = UiKit.icon_button("redo",func(): game.redo(),hrow,"Rétablir · Ctrl + Y")
	UiKit.icon_button("save",func(): game.manual_save(),hrow,"Enregistrer · Ctrl + S")

func build_dock() -> void:
	var dock = UiKit.panel(self)
	dock.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	dock.grow_horizontal = Control.GROW_DIRECTION_BOTH
	dock.grow_vertical = Control.GROW_DIRECTION_BEGIN
	dock.offset_bottom = -6*S
	var row = UiKit.hbox(dock,2)
	for d in DOCK:
		var key: String = d[0]
		if key == "services" and not ClubSim.FEATURES.services: continue
		if key == "reports" and not ClubSim.FEATURES.night_cycle: continue
		var action: Callable = toggle_drawer.bind(key)
		if key == "select":
			action = func():
				close_drawer()
				game.set_mode("select")
		tool_buttons[key] = UiKit.button(d[1],action,row,d[3],d[2])

func build_drawer() -> void:
	drawer = UiKit.window("",close_drawer)
	drawer.anchor_bottom = 1
	drawer.offset_left = 6*S
	drawer.offset_top = 82*S
	drawer.offset_right = 212*S
	drawer.offset_bottom = -38*S
	add_child(drawer)
	drawer_scroll = ScrollContainer.new()
	drawer_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	drawer_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	drawer.content.add_child(drawer_scroll)
	drawer.content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	drawer_body = UiKit.vbox(drawer_scroll,3)
	drawer_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	drawer.visible = false

func build_context() -> void:
	context = UiKit.window("Sélection",func():
		game.clear_selection()
		game.refresh())
	context.anchor_left = 1
	context.anchor_right = 1
	context.offset_left = -196*S
	context.offset_right = -6*S
	context.offset_top = 38*S
	add_child(context)
	context_body = context.content
	context.visible = false

# ------------------------------------------------------------------ refresh

func _process(delta: float) -> void:
	var p0 = Prof.t("hud")
	_timed_process(delta)
	Prof.add("hud",p0)

func _timed_process(delta: float) -> void:
	if game == null: return
	toast_time = maxf(0.0,toast_time-delta)
	toast_label.visible = toast_time > 0
	site_refresh -= delta
	if site_refresh <= 0.0 and site_room >= 0:
		site_refresh = 0.2
		update_site()
	live_refresh -= delta
	if live_refresh <= 0:
		live_refresh = 0.5
		var leaks = Plumbing.leaks(game.sim)
		sanitary_label.visible = leaks > 0 or not game.sim.sanitary_queue.is_empty() or game.sim.sanitary_saturated_until > game.sim.elapsed
		sanitary_label.text = "Fuites : %d · technicien requis" % leaks if leaks > 0 else ("Sanitaires saturés" if game.sim.sanitary_saturated_until > game.sim.elapsed else "File WC : %d" % game.sim.sanitary_queue.size())
		if is_instance_valid(hygiene_label):
			var selected = game.model.item_by_id(game.selected_item)
			hygiene_label.text = sanitary_details(selected)
			update_hygiene_gauge(selected)
		if is_instance_valid(staff_context_label):
			var employee = game.sim.staff.get(game.selected_item)
			if is_instance_valid(employee): staff_context_label.text = staff_state(employee)
		drawer_refresh -= 0.5
		if drawer_live and drawer_refresh <= 0.0 and active in ["clients","reports","deliveries","staff"] and not drawer_has_focus():
			drawer_refresh = 2.0
			fill_drawer()
		if game.selected_client != null or game.model.item_by_id(game.selected_item).get("delivery_pending",false): refresh_context()

func drawer_has_focus() -> bool:
	var f = get_viewport().gui_get_focus_owner()
	return f != null and drawer.is_ancestor_of(f)

func refresh_stats() -> void:
	var sim: ClubSim = game.sim
	money_label.text = UiKit.money(sim.money)
	money_label.add_theme_color_override("font_color",UiKit.INK if sim.money >= 0 else UiKit.RED)
	time_label.text = sim.clock_text()
	day_label.text = "%s · J%d" % [ClubCalendar.SHORT_DAYS[ClubCalendar.weekday(sim.day)],sim.day]
	var full = int(round(sim.rating))
	for i in range(stars.get_child_count()):
		(stars.get_child(i) as TextureRect).modulate = UiKit.GOLD if i < full else UiKit.DIM
	stars.tooltip_text = "Réputation : %.1f / 5" % sim.rating
	clients_label.text = str(sim.inside_count())
	queue_label.text = str(sim.queue.size())
	queue_label.add_theme_color_override("font_color",UiKit.RED if sim.queue.size() >= 4 else UiKit.INK)
	debris_label.text = str(game.model.debris().size()+sim.dirt.size())
	open_button.text = ("Ouvert" if sim.open else "Fermé")+(" · auto" if sim.opening_hours.enabled and sim.opening_override < 0 else "")
	open_button.tooltip_text = "Ouvrir ou fermer · O"+("\nDérogation jusqu'au prochain changement d'horaire." if sim.opening_hours.enabled else "")
	if is_instance_valid(demand_label): demand_label.text = sim.demand_text()
	open_button.add_theme_color_override("font_color",UiKit.GREEN if sim.open else UiKit.RED)
	open_button.add_theme_color_override("icon_normal_color",UiKit.GREEN if sim.open else UiKit.RED)
	UiKit.set_active(open_button,sim.open)
	var sat = int(round(sim.satisfaction()))
	sat_label.text = "%d%%" % sat
	sat_icon.modulate = UiKit.GREEN if sat >= 60 else (UiKit.GOLD if sat >= 35 else UiKit.RED)
	for k in speed_buttons: UiKit.set_active(speed_buttons[k],sim.speed == k)
	undo_button.disabled = game.undo_stack.is_empty()
	redo_button.disabled = game.redo_stack.is_empty()
	refresh_deliveries()

func refresh_deliveries() -> void:
	if game.deliveries == null or delivery_button == null: return
	delivery_button.text = game.deliveries.status_text()
	delivery_button.add_theme_color_override("font_color",UiKit.GOLD if game.deliveries.phase != "idle" else UiKit.MUTED)

func fill_deliveries() -> void:
	section("COMMANDES ET LIVRAISONS")
	drawer_body.add_child(wrap_label("Placez vos achats : leur fantôme réserve l'emplacement. Les achats se regroupent jusqu'à l'arrêt de la fourgonnette. Les livreurs passent par les portes, puis déballent sur place."))
	section(game.deliveries.status_text())
	if game.deliveries.status_text() == "Livreur bloqué": drawer_body.add_child(wrap_label("Rétablissez un passage entre le livreur et la rue pour qu'il puisse rejoindre sa fourgonnette.",1,UiKit.GOLD))
	var pending = game.model.furniture.filter(func(i): return i.get("delivery_pending",false))
	if pending.is_empty(): drawer_body.add_child(wrap_label("Tous les objets sont installés."))
	for item in pending:
		UiKit.separator(drawer_body)
		var id = int(item.id)
		var b = UiKit.button(Catalog.ITEMS[item.kind].name,func():
			game.set_mode("select")
			game.selected_item = id
			game.camera.position = (Iso.to_screen(item.x,item.z)-Vector2(game.viewport.size)/2).round()
			game.refresh(),drawer_body)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		drawer_body.add_child(wrap_label(game.deliveries.item_status(item)))
		drawer_body.add_child(wrap_label(["Petit colis · à la main","Colis moyen · diable","Gros colis · chariot"][Deliveries.package_size(item)]))

func toast(text: String, seconds: float = 4.5) -> void:
	toast_label.text = text
	toast_time = seconds

func set_mode_text(text: String) -> void:
	mode_label.text = text

func show_hover(text: String, at: Vector2) -> void:
	hover_label.text = text
	hover_label.visible = text != ""
	hover_label.reset_size()
	hover_label.position = ((at+Vector2(10,14)*S).min(size-hover_label.size-Vector2(4,4)*S)/S).floor()*S

# ------------------------------------------------------------------ drawers

func toggle_drawer(key: String) -> void:
	if active == key:
		close_drawer()
		return
	active = key
	drawer.visible = true
	drawer.title.text = TITLES.get(key,"")
	if key == "deliveries": drawer.title.text = "Livraisons"
	fill_drawer()
	update_dock()
	if key == "decor" and game.mode != "furniture": game.set_mode("select")

func close_drawer() -> void:
	active = ""
	drawer.visible = false
	update_dock()

func update_dock() -> void:
	for k in tool_buttons:
		var on = k == active or (k == "select" and active == "" and game.mode == "select")
		UiKit.set_active(tool_buttons[k],on)

func clear(node: Node) -> void:
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()

func fill_drawer() -> void:
	var p0 = Prof.t("hud.drawer")
	_timed_fill_drawer()
	Prof.add("hud.drawer",p0)

func _timed_fill_drawer() -> void:
	if active == "": return
	var scroll = drawer_scroll.scroll_vertical
	clear(drawer_body)
	match active:
		"build": fill_build()
		"staff": fill_staff()
		"clients": fill_clients()
		"decor": fill_decor()
		"services": fill_services()
		"reports": fill_reports()
		"settings": fill_settings()
		"deliveries": fill_deliveries()
	drawer_scroll.set_deferred("scroll_vertical",scroll)

func section(text: String, parent: Node = null) -> void:
	(parent if parent != null else drawer_body).add_child(UiKit.label(text,1,UiKit.MUTED))

func wrap_label(text: String, level: int = 1, color: Color = UiKit.MUTED) -> Label:
	var l = UiKit.label(text,level,color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 180*S
	return l

func fill_build() -> void:
	section("OUTILS")
	var g = UiKit.grid(drawer_body,2,2)
	for entry in [["select","Sélection","select","Échap"],["room","Pièce","build","Tracer une pièce · T"],["door","Porte","door","Placer une porte · P"],["window","Fenêtre","window","Placer une fenêtre · F"],
			["parking","Places","parking","Clic : une place · Glisser : une rangée · K"],["parking_lane","Allée","parking","Tracer le passage entre les places et la rue"]]:
		var b = UiKit.button(entry[1],game.set_mode.bind(entry[0]),g,entry[3],entry[2])
		b.custom_minimum_size.x = 92*S
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		UiKit.set_active(b,game.mode == entry[0])
	if game.mode in ["parking","parking_lane"] or not game.model.parkings.is_empty():
		UiKit.separator(drawer_body)
		section("PARKINGS")
		drawer_body.add_child(wrap_label("Places : cliquez pour une place, glissez pour une rangée. R pour tourner. Les ajouts s'alignent et se raccordent aux rangées voisines."))
		if game.mode == "parking": UiKit.button("Tourner les places · R",game.turn_parking_tool,drawer_body)
		drawer_body.add_child(wrap_label("Allée : tracez le passage devant les places, jusqu'à la rue. Gardez 6 m entre deux rangées face à face. Terrain neuf : 30 $/m² (375 $ par place). Le bitume existant est réutilisé gratuitement."))
		for pk in game.model.parkings:
			var n = game.view.parking_layouts.get(int(pk.id),{}).get("bays",[]).size()
			var title = "Allée" if pk.get("kind","") == "lane" else "%d place%s" % [n,"s" if n > 1 else ""]
			var b = UiKit.button("%s · %s × %s m" % [title,str(pk.w),str(pk.h)],game.select_parking.bind(int(pk.id)),drawer_body)
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			UiKit.set_active(b,game.selected_parking == int(pk.id))
	section("TYPE DE LA NOUVELLE PIÈCE")
	for i in range(Catalog.ROOMS.size()):
		var row = UiKit.hbox(drawer_body,3)
		row.add_child(UiKit.chip(Color(Catalog.ROOM_FINISHES[i].floor_color)))
		var b = UiKit.button(Catalog.ROOMS[i],game.set_room_type.bind(i),row,Catalog.ROOM_HINTS[i])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		UiKit.set_active(b,game.room_type == i and game.mode == "room")
	drawer_body.add_child(wrap_label("Glissez depuis le terrain libre : nouvelle pièce (%d $ le m²), même collée à une autre. Partez d'un mur ou du sol d'une pièce : elle s'agrandit, et le mur tombe à la fin des travaux." % Catalog.ROOM_PRICE))
	UiKit.separator(drawer_body)
	var area = 0
	for r in game.model.rooms: area += BuildingModel.area_of(r)
	section("PLAN · %d pièces · %d m²" % [game.model.rooms.size(),area])
	for r in game.model.rooms:
		var row = UiKit.hbox(drawer_body,3)
		row.add_child(UiKit.chip(Color(r.floor_color)))
		var works: Dictionary = game.construction.status(r) if game.construction != null else {}
		var b = UiKit.button("%s · %d m²%s" % [Catalog.ROOMS[int(r.type)],BuildingModel.area_of(r),(" · chantier %d %%" % int(works.percent)) if not works.is_empty() else ""],game.select_room.bind(int(r.id)),row)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UiKit.set_active(b,game.selected_room == int(r.id))

func portrait_texture(app: Dictionary, mult: int = 1) -> Texture2D:
	var key = JSON.stringify(app)+str(mult)
	if not portrait_cache.has(key): portrait_cache[key] = UiKit.pixel_texture(UiKit.portrait(app),mult)
	return portrait_cache[key]

func fill_staff() -> void:
	section("PLANNING")
	drawer_body.add_child(wrap_label(ClubCalendar.DAYS[ClubCalendar.weekday(game.sim.day)]+" · "+game.sim.clock_text()))
	UiKit.button("Horaires du club",func(): show_schedule(-1),drawer_body,"Ouverture automatique et jours d'ouverture")
	drawer_body.add_child(wrap_label("Ménage et maintenance continuent pendant la fermeture selon les plannings."))
	UiKit.separator(drawer_body)
	UiKit.separator(drawer_body)
	section("ÉQUIPE ET HORAIRES")
	var wages = 0
	for item in game.model.furniture:
		if not Catalog.is_character(item.kind): continue
		if ClubCalendar.covers(item.get("work_schedule",ClubCalendar.default_shift()),game.sim.day,game.sim.minute): wages += int(Catalog.ITEMS[item.kind].get("wage",0))
		var b = Button.new()
		var a: Actor = game.sim.staff.get(int(item.id))
		var state = staff_state(a) if a != null and is_instance_valid(a) else ""
		var profile = game.sim.profiles.get_profile(str(item.get("profile_id","")))
		b.text = "%s · %s\n%s" % [profile.get("name",Catalog.ITEMS[item.kind].name),Catalog.ITEMS[item.kind].name,state]
		b.icon = portrait_texture(item.appearance)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(game.select_item.bind(int(item.id)))
		UiKit.set_active(b,game.selected_item == int(item.id))
		drawer_body.add_child(b)
		UiKit.button("Fiche et histoire",show_profile.bind(str(item.get("profile_id","")),0),drawer_body)
		drawer_body.add_child(wrap_label(ClubCalendar.summary(item.get("work_schedule",ClubCalendar.default_shift()))))
		UiKit.button("Modifier le planning",show_schedule.bind(int(item.id)),drawer_body)
	drawer_body.add_child(wrap_label("Salaires planifiés actuellement : %s $/h, même lorsque le club est fermé." % UiKit.money(wages)))

	UiKit.separator(drawer_body)
	section("EMBAUCHER")
	for kind in Catalog.STAFF_ORDER:
		var entry: Dictionary = Catalog.ITEMS[kind]
		var active = kind in Catalog.STAFF_ACTIVE or ClubSim.FEATURES.staff_roles
		var need = Catalog.stars_needed(kind)
		var unlocked = game.sim.stars() >= need
		var available = active and unlocked
		var b = Button.new()
		if not active: b.text = "%s · bientôt" % entry.name
		elif not unlocked: b.text = "%s · %d étoiles" % [entry.name,need]
		else: b.text = "%s · %d $/h" % [entry.name,int(entry.wage)]
		b.icon = portrait_texture(Characters.defaults(kind))
		b.focus_mode = Control.FOCUS_NONE
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size",UiKit.fs(1))
		b.disabled = not available
		if Characters.is_escort(kind):
			var st: Dictionary = Characters.STANDINGS[kind]
			b.tooltip_text = "Standing %d/4 · %s · tient compagnie aux clients du salon" % [int(st.level),st.name] if unlocked else "Un club de %d étoiles attire les escorts de ce standing." % need
		elif not active: b.tooltip_text = "Arrive avec une prochaine fonctionnalité."
		else: b.tooltip_text = "Placer %s : cliquez dans une pièce · %s" % [entry.name.to_lower(),{"receptionist":"accueille les clients au comptoir d'accueil et encaisse l'entrée","bartender":"sert à boire au comptoir de bar"}.get(kind,"nettoie les déchets")]
		b.pressed.connect(game.choose_item.bind(kind))
		UiKit.set_active(b,game.mode == "furniture" and game.chosen_item == kind)
		drawer_body.add_child(b)

func staff_state(a: Actor) -> String:
	if a.brain.get("overtime",false): return "Termine sa tâche · fin de service"
	match a.brain.get("state",""):
		"off_shift": return "Hors service"
		"working": return "Au poste"
		"dancing": return "Sur scène"
		"lounge": return "Au salon"
		"with_client": return "Salon privé"
		"mopping": return "Nettoie"
		"approach": return "Aborde un client"
		"chat": return "Discute"
		"to_bed", "wait_partner": return "Monte en chambre"
		"in_service": return "En chambre"
		"to_shower_after", "showering": return "Douche"
		"sick": return "Malade"
		"to_bed_task", "making_bed": return "Refait un lit"
		"to_floor", "floor_dance": return "Danse sur la piste"
		"to_stage", "dancing": return "Show à la barre"
		"to_dirt": return "Va nettoyer"
		"to_fixture", "cleaning_fixture": return "Entretient les sanitaires"
		"to_repair": return "Va réparer une fuite"
		"repairing": return "Répare la plomberie"
		"patrol": return "Ronde"
	return "Disponible"

func fill_clients() -> void:
	var sim: ClubSim = game.sim
	UiKit.button("Carnet des clients connus",show_client_book,drawer_body,"Histoires, habitués et suivi, même après leur départ")
	var factors = sim.demand_factors()
	drawer_body.add_child(wrap_label(sim.demand_text(),1,UiKit.GOLD))
	drawer_body.add_child(wrap_label("Heure ×%.2f · Jour ×%.2f\nRéputation ×%.2f · Météo ×%.2f" % [factors.hour,factors.day,factors.reputation,factors.weather]))
	drawer_body.add_child(UiKit.label("Club ouvert" if sim.open else "Club fermé : personne n'entre",1,UiKit.GREEN if sim.open else UiKit.RED))
	section("AUJOURD'HUI")
	drawer_body.add_child(UiKit.label("%d entrées · %s $ encaissés" % [int(sim.night.clients),UiKit.money(int(sim.night.entry))],1))
	drawer_body.add_child(UiKit.label("Satisfaction : %d %%" % int(round(sim.satisfaction())),1))
	drawer_body.add_child(UiKit.label("Flaques : %d · Accidents : %d" % [sim.dirt.size(),int(sim.night.get("accidents",0))],1,UiKit.GOLD))
	drawer_body.add_child(wrap_label(Sanitation.status(sim),1,UiKit.GOLD))
	var water = sim.dirt.filter(func(d): return d.kind == "water").size()
	var work = 0.0
	for d in sim.dirt: work += float(d.get("work",6.0))
	drawer_body.add_child(wrap_label("Fuites : %d · Sol mouillé : %.1f m²\nNettoyage au sol : %.0f min de travail\nRéparations effectuées : %d" % [Plumbing.leaks(sim),water*.25,work,int(sim.night.get("repairs",0))],1,UiKit.GOLD))
	drawer_body.add_child(wrap_label("Départs liés aux sanitaires : %d · Lavages des mains : %d" % [int(sim.night.get("sanitary_departures",0)),int(sim.night.get("handwashes",0))]))
	UiKit.separator(drawer_body)
	section("PRÉSENTS (%d)" % sim.clients.size())
	for c in sim.clients:
		if not is_instance_valid(c): continue
		var row = UiKit.hbox(drawer_body,3)
		var b = UiKit.button("%s · %s" % [c.brain.name,ClubSim.ACTIVITY.get(c.brain.activity,"")],game.select_client.bind(c),row)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var sat = int(c.brain.sat)
		row.add_child(UiKit.label("%d%%" % sat,1,UiKit.GREEN if sat >= 60 else (UiKit.GOLD if sat >= 35 else UiKit.RED)))
	if sim.clients.is_empty():
		drawer_body.add_child(wrap_label("Personne pour l'instant. Les clients arrivent par la porte d'entrée donnant sur la rue." if not sim.entrance.is_empty() else "Aucune porte ne donne sur la rue : placez une porte extérieure (idéalement dans la réception)."))

func thumb(kind: String) -> Texture2D:
	if thumb_cache.has(kind): return thumb_cache[kind]
	var t: Texture2D
	if Catalog.is_character(kind):
		t = portrait_texture(Characters.defaults(kind))
	else:
		var info = Art.furniture_entry(kind,0)
		var img: Image = Art.image(info.file)
		img = img.get_region(img.get_used_rect())
		if img.get_width() <= 44 and img.get_height() <= 40: t = UiKit.pixel_texture(img)
		else: t = ImageTexture.create_from_image(img)
	thumb_cache[kind] = t
	return t

func fill_decor() -> void:
	drawer_body.add_child(wrap_label("Achats livrés par camion : placez le fantôme, les livreurs installeront l'objet. Achats regroupés automatiquement."))
	var field = LineEdit.new()
	field.placeholder_text = "Rechercher un objet…"
	field.text = catalog_search
	field.add_theme_font_size_override("font_size",UiKit.fs(1))
	field.text_changed.connect(func(t):
		catalog_search = t
		fill_decor_grid())
	drawer_body.add_child(field)
	var filters = UiKit.grid(drawer_body,4,2)
	for entry in [[-2,"Tout"],[0,"Bar"],[1,"Lits"],[2,"WC"],[3,"Stock"],[4,"Staff"],[5,"Accueil"],[-1,"Déco"],[7,"Plantes"]]:
		var b = UiKit.button(entry[1],func():
			catalog_filter = entry[0]
			fill_drawer(),filters)
		UiKit.set_active(b,catalog_filter == entry[0])
	var g = UiKit.grid(drawer_body,2,2)
	g.name = "Catalog"
	fill_decor_grid(g)

func fill_decor_grid(g: GridContainer = null) -> void:
	if g == null: g = drawer_body.get_node_or_null("Catalog")
	if g == null: return
	clear(g)
	var q = catalog_search.strip_edges().to_lower()
	for kind in Catalog.ITEMS:
		var e: Dictionary = Catalog.ITEMS[kind]
		if not Catalog.in_shop(kind): continue
		if catalog_filter != -2 and int(e.group) != catalog_filter: continue
		if q != "" and not String(e.name).to_lower().contains(q): continue
		var b = Button.new()
		b.icon = thumb(kind)
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.text = "%s\n%s $" % [e.name,UiKit.money(int(e.price))]
		b.add_theme_font_size_override("font_size",UiKit.fs(1))
		b.custom_minimum_size = Vector2(94,80)*S
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.focus_mode = Control.FOCUS_NONE
		b.tooltip_text = "%s · %s · %.1f × %.1f m" % [e.name,e.tag,e.size.x,e.size.y]
		b.pressed.connect(game.choose_item.bind(kind))
		UiKit.set_active(b,game.mode == "furniture" and game.chosen_item == kind)
		g.add_child(b)

func fill_services() -> void:
	section("TARIFS")
	for entry in [["entry","Entrée",0,80,"Payée à la réception."],["drink","Boisson",4,40,"Servie au bar si un barman est en poste."],["dance","Pourboire scène",0,120,"Quand une escort danse sur la scène."],["private","Salon privé",40,400,"Une chambre libre et une escort disponible."]]:
		var key: String = entry[0]
		var row = UiKit.hbox(drawer_body,3)
		var name = UiKit.label(entry[1],1)
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name)
		var value = UiKit.label("%d $" % int(game.sim.prices[key]),1,UiKit.GOLD)
		row.add_child(value)
		var slider = HSlider.new()
		slider.min_value = entry[2]
		slider.max_value = entry[3]
		slider.step = 1
		slider.value = game.sim.prices[key]
		slider.focus_mode = Control.FOCUS_NONE
		slider.custom_minimum_size.y = 10*S
		slider.value_changed.connect(func(v):
			game.set_price(key,int(v))
			value.text = "%d $" % int(v))
		drawer_body.add_child(slider)
		drawer_body.add_child(wrap_label(entry[4]))
	UiKit.separator(drawer_body)
	drawer_body.add_child(wrap_label("Des prix élevés rapportent plus par client mais en attirent moins et pèsent sur la satisfaction."))

func fill_reports() -> void:
	var sim: ClubSim = game.sim
	section("NUIT %d EN COURS · %s" % [sim.day,sim.clock_text()])
	var income = int(sim.night.entry)+int(sim.night.bar)+int(sim.night.dance)+int(sim.night.private)
	for entry in [["Entrées",sim.night.entry],["Bar",sim.night.bar],["Scène",sim.night.dance],["Salons privés",sim.night.private],["Salaires",-int(sim.night.wages)]]:
		report_line(drawer_body,entry[0],int(entry[1]))
	report_line(drawer_body,"Résultat",income-int(sim.night.wages),true)
	UiKit.separator(drawer_body)
	section("NUITS PRÉCÉDENTES")
	if sim.history.is_empty(): drawer_body.add_child(wrap_label("Le premier rapport arrive à la fermeture, à 04:00."))
	for i in range(sim.history.size()-1,-1,-1):
		var h: Dictionary = sim.history[i]
		report_line(drawer_body,"Nuit %d · %d%% · %.1f" % [int(h.day),int(h.satisfaction),float(h.rating)],int(h.net),true)
	UiKit.separator(drawer_body)
	section("VALEUR DU CLUB")
	drawer_body.add_child(UiKit.label("%s $ d'aménagements" % UiKit.money(game.model.cost()),1))

func report_line(parent: Node, text: String, value: int, strong: bool = false) -> void:
	var row = UiKit.hbox(parent,3)
	var l = UiKit.label(text,1,UiKit.INK if strong else UiKit.MUTED)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	row.add_child(UiKit.label(("+" if value > 0 else "")+UiKit.money(value)+" $",1,UiKit.GREEN if value > 0 else (UiKit.RED if value < 0 else UiKit.MUTED)))

func fill_settings() -> void:
	section("HORAIRES")
	UiKit.button("Horaires d'ouverture du club",func(): show_schedule(-1),drawer_body)
	drawer_body.add_child(wrap_label(("Automatique · " if game.sim.opening_hours.enabled else "Ouverture manuelle · ")+ClubCalendar.summary(game.sim.opening_hours)))
	UiKit.separator(drawer_body)
	section("VUE")
	var row = UiKit.hbox(drawer_body,2)
	for z in [1,2,3,4]:
		var b = UiKit.button("×%d" % z,func():
			game.set_zoom(z)
			fill_drawer.call_deferred(),row,"Agrandissement des pixels")
		UiKit.set_active(b,game.zoom == z)
	UiKit.button("Murs hauts" if game.view.wall_mode == 0 else "Murs coupés",func():
		game.toggle_walls()
		fill_drawer(),drawer_body,"Alterner murs hauts / murs coupés · W","walls")
	UiKit.button("Grille",func(): game.toggle_grid(),drawer_body,"G","grid")
	UiKit.button("Recentrer la vue",func(): game.center_camera(),drawer_body,"Origine","center")
	UiKit.button("Plein écran",func(): game.toggle_fullscreen(),drawer_body,"F11","fullscreen")
	UiKit.separator(drawer_body)
	section("PARTIE")
	UiKit.button("Enregistrer",func(): game.manual_save(),drawer_body,"Ctrl + S","save")
	UiKit.button("Importer le bâtiment 3D",func(): game.import_3d(),drawer_body,"Reprend les pièces et le mobilier de la version 3D","import")
	UiKit.button("Nouveau club",func(): confirm("Nouveau club","Repartir du club de départ ?\nL'argent et la réputation sont réinitialisés.",func(): game.reset_club()),drawer_body,"","plus")
	UiKit.button("Commandes et aide",func(): show_help(),drawer_body,"F1","help")
	UiKit.button("Quitter",func(): game.quit(),drawer_body,"","exit")
	drawer_body.add_child(wrap_label(game.save_status))

# ------------------------------------------------------------------ context window

func sanitary_details(item: Dictionary) -> String:
	var text = "Saleté : %d %% · Usure : %d %%" % [int(item.get("soil",0)),int(item.get("wear",0))]
	if Sanitation.needs_cleaning(game.sim,item):
		text += "\nNettoyage nécessaire"
	else:
		text += "\nEntretien à 100 % ou en cas de flaque"
	var status = Plumbing.repair_status(game.sim,item)
	if status != "": text += "\n"+status
	return text

func update_hygiene_gauge(item: Dictionary) -> void:
	if not is_instance_valid(hygiene_gauge): return
	hygiene_gauge.value = float(item.get("soil",0))
	var fill = StyleBoxFlat.new()
	fill.bg_color = UiKit.RED if Sanitation.needs_cleaning(game.sim,item) else (UiKit.GOLD if hygiene_gauge.value >= 60 else UiKit.GREEN)
	hygiene_gauge.add_theme_stylebox_override("fill",fill)

func room_size(room: Dictionary) -> String:
	# an extended room is no longer a rectangle: its area says it all
	if not room.get("parts",[]).is_empty(): return "%d m² (agrandie)" % BuildingModel.area_of(room)
	return "%d × %d m · %d m²" % [room.w,room.h,room.w*room.h]

func site_lines(works: Dictionary) -> Array:
	return ["Avancement : %d %%" % int(works.percent),"Phase : "+String(works.phase_name),
		"Temps restant : %s (≈ %d s)" % [SitePlan.duration_text(works.minutes),ceili(works.real_seconds)]]

func update_site() -> void:
	# The figures follow what the site shows, a few times a second.
	var room = game.model.room_by_id(site_room)
	if room.is_empty() or not SitePlan.building(room) or not is_instance_valid(site_label):
		site_room = -1
		if game.selected_room >= 0 and not room.is_empty(): refresh_context()
		return
	var works: Dictionary = game.construction.status(room)
	if works.is_empty(): return
	site_bar.value = float(works.progress)*100.0
	var lines = site_lines(works)
	site_label.text = lines[0]
	site_phase_label.text = lines[1]
	site_time_label.text = lines[2]

func refresh_context() -> void:
	var p0 = Prof.t("hud.context")
	_timed_refresh_context()
	Prof.add("hud.context",p0)

func _timed_refresh_context() -> void:
	staff_context_label = null
	site_room = -1
	site_label = null
	site_bar = null
	hygiene_gauge = null
	hygiene_label = null
	clear(context_body)
	var model: BuildingModel = game.model
	var item = model.item_by_id(game.selected_item)
	var room = model.room_by_id(game.selected_room)
	var client = game.selected_client
	var parking = model.parking_by_id(game.selected_parking)
	context.visible = game.mode == "select" and (not item.is_empty() or not room.is_empty() or game.selected_edge != "" or client != null or not parking.is_empty())
	if client != null and is_instance_valid(client):
		context.title.text = "Client"
		var head = UiKit.hbox(context_body,4)
		var t = TextureRect.new()
		t.texture = portrait_texture(client.appearance)
		head.add_child(t)
		head.add_child(UiKit.label(client.brain.name,1))
		context_body.add_child(UiKit.label(ClubSim.ACTIVITY.get(client.brain.activity,""),1,UiKit.MUTED))
		context_body.add_child(UiKit.label("Satisfaction : %d %%" % int(client.brain.sat),1,UiKit.GREEN if client.brain.sat >= 60 else UiKit.GOLD))
		context_body.add_child(UiKit.label("Dépensé : %d $" % int(client.brain.spent),1))
		context_body.add_child(UiKit.label("Budget : %d $" % int(client.brain.get("budget",0)),1,UiKit.MUTED))
		var need = int(client.brain.get("bladder",0.0))
		context_body.add_child(UiKit.label("Besoin de toilettes : %d %%" % need,1,UiKit.RED if need >= 85 else (UiKit.GOLD if need >= 65 else UiKit.MUTED)))
		context_body.add_child(UiKit.label("Boissons consommées : %d" % int(client.brain.get("drinks",0)),1,UiKit.MUTED))
		UiKit.button("Fiche et histoire",show_profile.bind(str(client.brain.get("profile_id","")),0),context_body)
		if client.brain.state == "toilet_wait":
			context_body.add_child(wrap_label(client.brain.get("wait_reason","Cherche un sanitaire"),1,UiKit.GOLD))
			if client.brain.has("wc_rank"): context_body.add_child(UiKit.label("Place dans la file : %d" % int(client.brain.wc_rank),1))
	elif not item.is_empty():
		var e: Dictionary = Catalog.ITEMS[item.kind]
		context.title.text = "Sélection"
		var head = UiKit.hbox(context_body,4)
		var t = TextureRect.new()
		t.texture = thumb(item.kind) if not Catalog.is_character(item.kind) else portrait_texture(item.appearance)
		head.add_child(t)
		var col = UiKit.vbox(head,1)
		var name = UiKit.label(e.name,1)
		name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name.custom_minimum_size.x = 100*S
		col.add_child(name)
		if Catalog.is_character(item.kind):
			var profile = game.sim.profiles.get_profile(str(item.get("profile_id","")))
			col.add_child(UiKit.label(profile.get("name",""),1,UiKit.GOLD))
			UiKit.button("Fiche et histoire",show_profile.bind(str(item.get("profile_id","")),0),context_body)
			col.add_child(UiKit.label("%d $/h" % int(e.wage),1,UiKit.GOLD))
			var a = game.sim.staff.get(int(item.id))
			if a != null and is_instance_valid(a):
				staff_context_label = UiKit.label(staff_state(a),1,UiKit.MUTED)
				col.add_child(staff_context_label)
			context_body.add_child(wrap_label(ClubCalendar.summary(item.get("work_schedule",ClubCalendar.default_shift()))))
			UiKit.button("Planning de cet employé",show_schedule.bind(int(item.id)),context_body)
			if Characters.is_escort(item.kind) and a != null and is_instance_valid(a):
				var health = int(a.brain.get("health",100.0))
				col.add_child(UiKit.label("Santé : %d %%" % health,1,UiKit.GREEN if health >= 70 else (UiKit.GOLD if health >= 55 else UiKit.RED)))
				var tariffs: Array = []
				for tier in range(ClubSim.SERVICES.size()): tariffs.append(str(game.sim.service_price(tier,a)))
				context_body.add_child(wrap_label("Tarifs : %s $ (rapide · classique · complète)" % " / ".join(tariffs)))
		elif item.get("delivery_pending",false):
			col.add_child(wrap_label(game.deliveries.item_status(item),1,UiKit.GOLD))
			context_body.add_child(wrap_label("Emplacement réservé. Déplacez le fantôme si nécessaire ; l'objet sera utilisable après déballage."))
		elif item.kind in Catalog.COLOR_KINDS:
			col.add_child(UiKit.label("%s $" % UiKit.money(int(e.price)),1,UiKit.GOLD))
			section("COULEURS",context_body)
			var cg = UiKit.grid(context_body,2,2)
			for i in range(Catalog.DANCE_SCHEMES.size()):
				var sb = UiKit.button(Catalog.DANCE_SCHEMES[i].name,game.set_item_scheme.bind(int(item.id),i),cg)
				sb.custom_minimum_size.x = 84*S
				UiKit.set_active(sb,int(item.get("scheme",0)) == i)
		elif item.kind in ClubSim.BED_KINDS:
			var busy = game.sim.busy_beds.has(int(item.id))
			col.add_child(UiKit.label("Occupé" if busy else ("Lit défait" if item.get("unmade",false) else "Lit fait"),1,UiKit.RED if item.get("unmade",false) and not busy else UiKit.GREEN))
		elif item.kind == "shower":
			col.add_child(UiKit.label("%s $" % UiKit.money(int(e.price)),1,UiKit.GOLD))
			var door = Catalog.local_to_world(item,ClubSim.SHOWER_DOOR)
			var usable = game.sim.nav.walkable(door) and game.model.room_at(door) == game.model.room_at(Vector2(item.x,item.z))
			col.add_child(UiKit.label("Porte dégagée" if usable else "Porte bloquée : douche inutilisable",1,UiKit.GREEN if usable else UiKit.RED))
		elif Catalog.is_debris(item.kind):
			col.add_child(UiKit.label("Déchet · %d min de travail" % int(e.clean),1,UiKit.RED))
		elif Catalog.is_used(item.kind):
			col.add_child(UiKit.label("Récupéré · gratuit",1,UiKit.GREEN))
		else:
			col.add_child(UiKit.label("%s $" % UiKit.money(int(e.price)),1,UiKit.GOLD))
		if Catalog.is_debris(item.kind):
			var cleaners = 0
			for other in model.furniture:
				if other.kind in Catalog.CLEANERS: cleaners += 1
			context_body.add_child(wrap_label("Un technicien d'entretien doit le ramasser." if cleaners == 0 else "Vos techniciens s'en chargent, du plus proche au plus loin."))
			var pr = UiKit.button("Priorité : oui" if item.get("priority",false) else "Nettoyer en priorité",game.toggle_priority.bind(int(item.id)),context_body,"Les techniciens commencent par les déchets prioritaires","check")
			UiKit.set_active(pr,item.get("priority",false))
			context.reset_size()
			return
		if not item.get("delivery_pending",false):
			if item.kind in Plumbing.KINDS:
				hygiene_label = wrap_label(sanitary_details(item),1,UiKit.GOLD)
				context_body.add_child(hygiene_label)
				hygiene_gauge = ProgressBar.new()
				hygiene_gauge.show_percentage = false
				hygiene_gauge.custom_minimum_size = Vector2(120*S,7*S)
				hygiene_gauge.add_theme_stylebox_override("background",UiKit.flat(Color("15141d"),UiKit.DIM))
				hygiene_gauge.tooltip_text = "La saleté s'accumule avec les utilisations. Une flaque ou une jauge pleine déclenche le ménage."
				context_body.add_child(hygiene_gauge)
				update_hygiene_gauge(item)
			for key in Sanitation.upgrades_for(item.kind):
				var upgrade: Dictionary = Sanitation.UPGRADES[key]
				var installed = item.get(key,false)
				var button = UiKit.button(upgrade.name+(" ✓" if installed else " · %d $" % upgrade.price),game.buy_sanitary_upgrade.bind(int(item.id),key),context_body,upgrade.effect)
				button.disabled = installed or game.sim.money < int(upgrade.price)
		context_body.add_child(UiKit.label("Glisser pour déplacer",1,UiKit.MUTED))
		var g = UiKit.grid(context_body,2,2)
		var remove_text = "Renvoyer" if Catalog.is_character(item.kind) else ("Jeter" if Catalog.is_used(item.kind) else "Revendre")
		if item.get("delivery_pending",false): remove_text = "Annuler l'achat"
		var actions = [["Déplacer","move",game.start_move,"Cliquer la nouvelle position"],["Tourner","rotate",game.rotate_item,"R"]]
		if not Catalog.is_used(item.kind): actions.append(["Copier","copy",game.duplicate_item,"Ctrl + D"])
		actions.append([remove_text,"delete",game.delete_selection,"Suppr"])
		for entry in actions:
			var b = UiKit.button(entry[0],entry[2],g,entry[3],entry[1])
			b.custom_minimum_size.x = 84*S
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if Catalog.is_character(item.kind):
			UiKit.button("Personnaliser…",game.edit_appearance.bind(int(item.id)),context_body,"Tenue, coiffure, couleurs","person")
	elif not room.is_empty() and SitePlan.building(room):
		# a room under construction: how far the works have gone
		context.title.text = "Chantier"
		var joins = game.model.room_by_id(int(room.get("merge_into",-1)))
		context_body.add_child(UiKit.label(("Agrandissement · %s · +%d m²" % [Catalog.ROOMS[int(joins.type)],BuildingModel.area_of(room)]) if not joins.is_empty() else ("%s · %s" % [Catalog.ROOMS[int(room.type)],room_size(room)]),1))
		site_room = int(room.id)
		site_bar = ProgressBar.new()
		site_bar.show_percentage = false
		site_bar.custom_minimum_size = Vector2(150*S,8*S)
		site_bar.add_theme_stylebox_override("background",UiKit.flat(Color("15141d"),UiKit.DIM))
		site_bar.add_theme_stylebox_override("fill",UiKit.flat(Color("f0a23a"),Color("f0a23a")))
		context_body.add_child(site_bar)
		site_label = UiKit.label("",1,UiKit.INK)
		context_body.add_child(site_label)
		site_phase_label = UiKit.label("",1,UiKit.GOLD)
		context_body.add_child(site_phase_label)
		site_time_label = UiKit.label("",1,UiKit.MUTED)
		context_body.add_child(site_time_label)
		update_site()
		section("MODIFIER LE CHANTIER",context_body)
		if not joins.is_empty():
			# an extension takes the kind and finishes of the room it joins
			context_body.add_child(wrap_label("À la fin des travaux, le mur tombe et cette surface rejoint la pièce (même type, mêmes revêtements). Tracez encore depuis un mur pour agrandir davantage."))
		else:
			context_body.add_child(wrap_label("Tirez les poignées, ou tracez depuis un de ses murs avec l'outil Pièce, pour agrandir la zone : seule la différence est facturée (%d $ le m²), ce qui est construit reste, les nouvelles cases rejoignent les travaux." % Catalog.ROOM_PRICE))
			var g = UiKit.grid(context_body,2,2)
			for i in range(Catalog.ROOMS.size()):
				var b = UiKit.button(Catalog.ROOMS[i],game.set_selected_room_type.bind(i),g)
				b.custom_minimum_size.x = 84*S
				UiKit.set_active(b,int(room.type) == i)
			UiKit.button("Revêtements…",game.edit_finishes.bind(int(room.id)),context_body,"Sol et murs posés à la fin des travaux","walls")
		UiKit.button("Abandonner le chantier",game.delete_selection,context_body,"Rembourse la pièce","delete")
	elif not room.is_empty():
		context.title.text = "Sélection"
		context_body.add_child(UiKit.label(room_size(room),1))
		section("TYPE",context_body)
		var g = UiKit.grid(context_body,2,2)
		for i in range(Catalog.ROOMS.size()):
			var b = UiKit.button(Catalog.ROOMS[i],game.set_selected_room_type.bind(i),g)
			b.custom_minimum_size.x = 84*S
			UiKit.set_active(b,int(room.type) == i)
		UiKit.button("Revêtements…",game.edit_finishes.bind(int(room.id)),context_body,"Sol et murs","walls")
		context_body.add_child(UiKit.label("Sol : "+Finishes.FLOORS[room.floor_finish].name,1,UiKit.MUTED))
		context_body.add_child(UiKit.label("Murs : "+Finishes.WALLS[room.wall_finish].name,1,UiKit.MUTED))
		context_body.add_child(wrap_label("Pour l'agrandir : outil Pièce, tracez depuis un de ses murs." if not room.get("parts",[]).is_empty() else "Tirez les poignées pour redimensionner, ou tracez depuis un de ses murs avec l'outil Pièce pour l'agrandir."))
		UiKit.button("Supprimer la pièce",game.delete_selection,context_body,"Retire aussi son mobilier","delete")
	elif not parking.is_empty():
		context.title.text = "Sélection"
		var lay: Dictionary = game.view.parking_layouts.get(int(parking.id),model.parking_layout(parking))
		var is_lane = parking.get("kind","") == "lane"
		context_body.add_child(UiKit.label("%s · %s × %s m" % ["Allée" if is_lane else "Rangée",str(parking.w),str(parking.h)],1))
		if not is_lane: context_body.add_child(UiKit.label("%d place%s" % [lay.bays.size(),"s" if lay.bays.size() > 1 else ""],1,UiKit.GREEN if lay.get("ok",false) else UiKit.RED))
		if lay.get("ok",false):
			if parking.get("kind","") == "row":
				context_body.add_child(wrap_label("Prolongez cette rangée sans déplacer les places existantes."))
				for side in [-1,1]:
					var candidate = model.parking_extension(int(parking.id),side)
					var valid = model.valid_parking(candidate)
					var price = model.parking_build_price(candidate)
					var b = UiKit.button(("+1 au début" if side < 0 else "+1 à la fin")+" · %s $" % UiKit.money(price),game.extend_parking.bind(side),context_body)
					b.disabled = not valid or game.sim.money < price
					b.tooltip_text = model.error if not valid else "Ajoute une place à cette extrémité de la rangée"
				UiKit.button("Continuer avec cette orientation",game.continue_parking,context_body)
			else: context_body.add_child(wrap_label("Surface libre pour relier les rangées et rejoindre la rue."))
		else:
			context_body.add_child(wrap_label(lay.get("error","")))
		context_body.add_child(UiKit.label("Valeur : %s $" % UiKit.money(Street.price(model.rect(parking))),1,UiKit.GOLD))
		UiKit.button("Supprimer l'allée" if is_lane else "Supprimer la rangée",game.delete_selection,context_body,"Suppr","delete")
	elif game.selected_edge != "":
		context.title.text = "Sélection"
		context_body.add_child(UiKit.label("Porte" if model.openings.get(game.selected_edge) == "door" else "Fenêtre",1))
		UiKit.button("Reboucher",game.delete_selection,context_body,"Suppr","delete")
	context.reset_size()

# ------------------------------------------------------------------ dialogs (movable windows)

func profile_scroll(parent: Node) -> VBoxContainer:
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0,clampf(size.y-235*S,120*S,270*S))
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)
	var col = UiKit.vbox(scroll,5)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return col

func show_client_book() -> void:
	open_modal("Carnet des clients",func(col):
		col.add_child(wrap_label("Retrouvez les clients connus, leurs souvenirs et vos notes de suivi."))
		var search = LineEdit.new()
		search.placeholder_text = "Rechercher un prénom…"
		col.add_child(search)
		var watched = CheckBox.new()
		watched.text = "Afficher seulement les clients suivis"
		col.add_child(watched)
		var entries = profile_scroll(col)
		var fill = func():
			clear(entries)
			var profiles: Array = game.sim.profiles.records.values().filter(func(p): return p.kind == "client")
			profiles.sort_custom(func(a,b): return int(a.last_arrival) > int(b.last_arrival) if a.last_arrival != b.last_arrival else str(a.name) < str(b.name))
			var count = 0
			for p in profiles:
				if not search.text.is_empty() and not str(p.name).to_lower().contains(search.text.to_lower()): continue
				if watched.button_pressed and not p.watched: continue
				var label = "%s · %d visites%s" % [p.name,int(p.visits)," · Suivi" if p.watched else (" · Habitué" if int(p.good_visits) >= 3 else "")]
				var button = UiKit.button(label,show_profile.bind(p.id,0),entries)
				button.alignment = HORIZONTAL_ALIGNMENT_LEFT
				button.icon = portrait_texture(p.appearance)
				count += 1
			if count == 0: entries.add_child(wrap_label("Aucun client correspondant pour l'instant."))
		search.text_changed.connect(func(_text): fill.call())
		watched.toggled.connect(func(_value): fill.call())
		fill.call()
		UiKit.button("Fermer",func(): close_modal(),col,"","check"),320)

func show_profile(id: String, tab: int = 0) -> void:
	for client in game.sim.clients:
		if is_instance_valid(client): game.sim.profiles.sync_spending(client)
	var p = game.sim.profiles.get_profile(id)
	if p.is_empty(): return
	open_modal("Fiche · "+p.name,func(col):
		var head = UiKit.hbox(col,6)
		var portrait = TextureRect.new()
		portrait.texture = portrait_texture(p.appearance,2)
		head.add_child(portrait)
		var info = UiKit.vbox(head,2)
		info.add_child(UiKit.label("%s · %d ans" % [p.name,int(p.age)],1,UiKit.GOLD))
		info.add_child(UiKit.label("Habitué du club" if p.kind == "client" and int(p.good_visits) >= 3 else ("Client" if p.kind == "client" else Catalog.ITEMS[p.kind].name),1))
		var tabs = UiKit.hbox(col,3)
		for i in range(3):
			var button = UiKit.button(["Portrait","Souvenirs","Suivi"][i],show_profile.bind(id,i),tabs)
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			UiKit.set_active(button,tab == i)
		var body = profile_scroll(col)
		if tab == 0:
			section("SON HISTOIRE",body)
			body.add_child(wrap_label(p.story,1,UiKit.INK))
			section("PERSONNALITÉ ET PRÉFÉRENCES",body)
			if p.kind == "client":
				body.add_child(wrap_label("%s · %s" % ["Patient" if p.patient else "Préfère être servi rapidement","Attentif à la propreté" if p.clean else "Tolérant à une petite saleté"]))
				body.add_child(wrap_label(CharacterProfiles.PREF_NAMES[p.preference]+" · plus souvent choisi, satisfaction +2."))
				body.add_child(wrap_label("Patience : %.0f min · %s\nSaleté : sensibilité ×%.1f" % [float(p.patience),"Généreux avec les pourboires" if p.generous else "Surveille ses dépenses",float(p.cleanliness)]))
				body.add_child(wrap_label("Aime venir le %s vers %02d h." % [ClubCalendar.DAYS[int(p.preferred_day)].to_lower(),int(p.preferred_hour)]))
				section("SES VISITES",body)
				body.add_child(wrap_label("%d entrées · %d $ dépensés au total" % [int(p.visits),int(p.spent)]))
				body.add_child(wrap_label("Dernière soirée terminée : %d %% de satisfaction" % int(p.last_satisfaction) if int(p.finished_visits) > 0 else "Aucune soirée terminée pour l'instant."))
				section("OBJECTIF PERSONNEL",body)
				body.add_child(wrap_label("Passer trois bonnes soirées au club : %d / 3.\n%s" % [mini(3,int(p.good_visits)),"Objectif atteint : habitué satisfait." if int(p.good_visits) >= 3 else "Une bonne expérience renforce son envie de revenir."]))
			else:
				body.add_child(wrap_label({"efficient":"Méthodique : temps de ménage et réparation réduit de 10 %.","welcoming":"Accueillant : satisfaction +1 lors de l'accueil ou du service au bar.","focused":"Appliqué : souhaite développer son expérience professionnelle."}[p.employee_trait]))
				body.add_child(wrap_label("Préfère travailler %s. Indication pour le planning ; aucun horaire imposé." % ("le soir" if p.shift == "soir" else "la nuit")))
				section("OBJECTIF PERSONNEL",body)
				body.add_child(wrap_label("Acquérir 8 heures d'expérience au club : %.1f / 8 h.\n%s" % [minf(8,float(p.work_minutes)/60),"Objectif atteint : temps de travail des tâches réduit de 5 %." if float(p.work_minutes) >= 480 else "Récompense : temps de travail des tâches réduit de 5 %. Les déplacements gardent leur vitesse."]))
		elif tab == 1:
			section("SOUVENIRS DU CLUB",body)
			for memory in p.memories:
				body.add_child(wrap_label("Jour %d · %s" % [int(memory.day),memory.text],1,UiKit.INK))
			if p.memories.is_empty(): body.add_child(wrap_label("Aucun souvenir pour l'instant."))
		else:
			section("NOTE DE LA DIRECTION",body)
			var note = LineEdit.new()
			note.text = p.note
			note.max_length = 240
			note.placeholder_text = "Votre note sur ce personnage…"
			body.add_child(note)
			note.text_changed.connect(func(text):
				p.note = text
				game.request_save())
			if p.kind == "client":
				var watch = CheckBox.new()
				watch.text = "Client à suivre"
				watch.button_pressed = p.watched
				body.add_child(watch)
				watch.toggled.connect(func(value):
					game.sim.profiles.mark_watched(id,value,game.sim.day)
					game.request_save())
				body.add_child(wrap_label("Le suivi est une note de gestion. Il ne prouve aucun incident et ne bloque pas l'entrée."))
				section("FAITS OBSERVÉS",body)
				if p.incidents.is_empty(): body.add_child(wrap_label("Aucun incident observé au club."))
				for event in p.incidents:
					body.add_child(wrap_label("Jour %d · %s · %s\nSource : %s%s" % [int(event.day),CharacterProfiles.INCIDENT_NAMES[event.kind],"Confirmé" if event.confirmed else "À vérifier",event.source," · Coût : %d $" % int(event.cost) if event.confirmed else ""],1,UiKit.GOLD))
				if not p.incidents.is_empty(): body.add_child(wrap_label("Coût des incidents confirmés : %d $" % game.sim.profiles.incident_cost(id)))
		var actions = UiKit.hbox(col,3)
		if p.kind == "client": UiKit.button("Carnet",show_client_book,actions)
		UiKit.button("Actualiser",show_profile.bind(id,tab),actions)
		UiKit.button("Fermer",func(): close_modal(),actions,"","check"),320)

func open_modal(title: String, build: Callable, width: int = 190, on_close: Callable = Callable()) -> VBoxContainer:
	var keep_pos = Vector2(-1,-1)
	if modal != null and is_instance_valid(modal) and modal.has_meta("window"):
		var old: Control = modal.get_meta("window")
		if old.get_meta("title","") == title: keep_pos = old.position
	close_modal(false)
	modal_on_close = on_close
	modal = Control.new()
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim = ColorRect.new()
	dim.color = Color(0.03,0.02,0.07,0.3)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal.add_child(dim)
	var win = UiKit.window(title,func(): close_modal(),true)
	win.custom_minimum_size.x = width*S
	win.set_meta("title",title)
	modal.add_child(win)
	modal.set_meta("window",win)
	add_child(modal)
	build.call(win.content)
	if keep_pos.x >= 0:
		win.position = keep_pos
	else:
		win.modulate.a = 0.0
		center_window.call_deferred(win)
	return win.content

func center_window(win: Control) -> void:
	if not is_instance_valid(win): return
	win.reset_size()
	var p = ((size-win.size)/2.0/S).floor()*S
	win.position = p.max(Vector2.ZERO)
	win.modulate.a = 1.0

func schedule_time_control(parent: Node, title: String, minutes: int) -> Dictionary:
	var row = UiKit.hbox(parent,3)
	var label = UiKit.label(title,1)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var hour = OptionButton.new()
	for h in range(24): hour.add_item("%02d" % h,h)
	hour.select(minutes/60)
	row.add_child(hour)
	row.add_child(UiKit.label(":",1))
	var part = OptionButton.new()
	var values: Array = [0,15,30,45]
	if not minutes%60 in values:
		values.append(minutes%60)
		values.sort()
	for m in values: part.add_item("%02d" % m,m)
	part.select(values.find(minutes%60))
	row.add_child(part)
	return {"hour":hour,"minute":part}

func show_schedule(id: int, preset: Dictionary = {}) -> void:
	var club = id < 0
	var item = game.model.item_by_id(id)
	if not club and item.is_empty(): return
	var draft: Dictionary = (game.sim.opening_hours if club else item.get("work_schedule",ClubCalendar.default_shift())).duplicate()
	if not preset.is_empty(): draft.merge(preset,true)
	var title = "Horaires du club" if club else "Planning · "+Catalog.ITEMS[item.kind].name
	open_modal(title,func(col):
		var mode_button: Button
		if club:
			mode_button = UiKit.button("Ouverture automatique : "+("oui" if draft.enabled else "non"),func(): pass,col)
			mode_button.pressed.connect(func():
				draft.enabled = not draft.enabled
				mode_button.text = "Ouverture automatique : "+("oui" if draft.enabled else "non")
				UiKit.set_active(mode_button,draft.enabled))
			UiKit.set_active(mode_button,draft.enabled)
		col.add_child(wrap_label("Jours de début du service" if not club else "Jours d'ouverture"))
		var days_row = UiKit.hbox(col,2)
		var buttons: Array = []
		for i in range(7):
			var button = UiKit.button(ClubCalendar.SHORT_DAYS[i],func(): pass,days_row,ClubCalendar.DAYS[i])
			button.custom_minimum_size.x = 28*S
			buttons.append(button)
			UiKit.set_active(button,bool(int(draft.days) & (1 << i)))
		var start = schedule_time_control(col,"Ouverture" if club else "Début",int(draft.start))
		var end = schedule_time_control(col,"Fermeture" if club else "Fin",int(draft.end))
		var preview = wrap_label(ClubCalendar.summary(draft),1,UiKit.GOLD)
		col.add_child(preview)
		var update = func():
			draft.start = start.hour.get_selected_id()*60+start.minute.get_selected_id()
			draft.end = end.hour.get_selected_id()*60+end.minute.get_selected_id()
			preview.text = ClubCalendar.summary(draft)
		for i in range(7):
			var button: Button = buttons[i]
			button.pressed.connect(func():
				draft.days = int(draft.days) ^ (1 << i)
				UiKit.set_active(button,bool(int(draft.days) & (1 << i)))
				update.call())
		for control in [start.hour,start.minute,end.hour,end.minute]: control.item_selected.connect(func(_index): update.call())
		col.add_child(wrap_label("Une fin avant le début se termine le lendemain. Deux heures identiques donnent un service de 24 h."))
		UiKit.separator(col)
		var presets = UiKit.hbox(col,2)
		UiKit.button("Tous les jours",func(): show_schedule(id,{"days":127,"start":draft.start,"end":draft.end,"enabled":draft.get("enabled",false)}),presets)
		UiKit.button("Ven–Sam",func(): show_schedule(id,{"days":48,"start":draft.start,"end":draft.end,"enabled":draft.get("enabled",false)}),presets)
		if not club:
			var shifts = UiKit.hbox(col,2)
			UiKit.button("Nuit 19–05",func(): show_schedule(id,{"days":draft.days,"start":1140,"end":300}),shifts)
			UiKit.button("Jour 06–14",func(): show_schedule(id,{"days":draft.days,"start":360,"end":840}),shifts)
		else:
			col.add_child(wrap_label("Le bouton Ouvert/Fermé permet une dérogation jusqu'au prochain changement d'horaire."))
		var row = UiKit.hbox(col,3)
		UiKit.button("Enregistrer",func():
			update.call()
			if club: game.set_opening_hours(draft)
			else: game.set_staff_schedule(id,draft)
			close_modal(),row,"","check")
		UiKit.button("Annuler",func(): close_modal(),row,"","close")
	,270)

func close_modal(run_callback: bool = true) -> void:
	if modal != null:
		modal.queue_free()
		modal = null
	if run_callback and modal_on_close.is_valid():
		var cb = modal_on_close
		modal_on_close = Callable()
		cb.call()

func modal_open() -> bool:
	return modal != null and is_instance_valid(modal)

func confirm(title: String, text: String, action: Callable) -> void:
	open_modal(title,func(col):
		var l = UiKit.label(text,1)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(l)
		var row = UiKit.hbox(col,3)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		UiKit.button("Confirmer",func():
			close_modal()
			action.call(),row,"","check")
		UiKit.button("Annuler",func(): close_modal(),row,"","close"),190)

func show_help() -> void:
	open_modal("Commandes",func(col):
		for block in [
			["CONSTRUIRE","T pièce · P porte · F fenêtre\nCliquez-glissez pour tracer ; tirez les poignées pour agrandir."],
			["MOBILIER","B catalogue · orientation automatique (murs, table, bar) · R : tourner à la main · A : auto · Maj + clic : en série\nGlisser un objet pour le déplacer."],
			["SÉLECTION","Suppr supprimer · Ctrl + D copier\nCtrl + Z / Y annuler / rétablir · Ctrl + S enregistrer"],
			["TEMPS","Espace pause · 1 normal · 2 accéléré"],
			["VUE","Molette : zoom ×1 à ×4 · clic droit + glisser\nW murs hauts / coupés · G grille · F11 plein écran"],
			["LE CLUB","O ouvrir / fermer. Les clients font la queue dehors et paient\nl'entrée à l'accueil : comptoir d'accueil + réceptionniste.\nSans personne à l'accueil, la file grandit et s'impatiente.\nUn barman sert au comptoir de bar ; les escorts tiennent\ncompagnie aux clients du salon."],
			["ESCORTS","Débutante dès le départ · confirmée à 2 étoiles\nélégante à 3 étoiles · prestige à 4 étoiles.\nPlus le standing est haut, plus les clients sont ravis."],
			["CHAMBRES","Bar, tabourets, chaises, canapés et piste de danse multiplient\nles rencontres. Escort et client discutent, s'accordent sur une\nprestation (rapide, classique, complète) et montent en chambre.\nDouches et lits refaits par la femme de ménage évitent les maladies."],
			["TEST (TEMPORAIRE)","Budget de 1 000 000 $ · F8 / Maj + F8 : une étoile de plus / de moins"]]:
			col.add_child(UiKit.label(block[0],1,UiKit.ACCENT))
			col.add_child(UiKit.label(block[1],1))
		var row = UiKit.hbox(col,3)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		UiKit.button("Fermer",func(): close_modal(),row,"","check"),300)

func show_report(r: Dictionary) -> void:
	open_modal("Rapport de la nuit %d" % int(r.day),func(col):
		for entry in [["Clients accueillis",str(int(r.clients))],["Salons privés",str(int(r.served))],["Satisfaction","%d %%" % int(r.satisfaction)],["Réputation","%.1f → %.1f" % [float(r.rating_before),float(r.rating)]]]:
			var row = UiKit.hbox(col,3)
			var l = UiKit.label(entry[0],1,UiKit.MUTED)
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(l)
			row.add_child(UiKit.label(entry[1],1))
		UiKit.separator(col)
		for entry in [["Entrées",int(r.entry)],["Bar",int(r.bar)],["Scène",int(r.dance)],["Salons privés",int(r.private)],["Salaires",-int(r.wages)],["Résultat",int(r.net)]]:
			report_line(col,entry[0],entry[1],entry[0] == "Résultat")
		var row = UiKit.hbox(col,3)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		UiKit.button("Nuit suivante",func(): close_modal(),row,"","play"),210,func(): game.next_night())
