class_name Editors
extends RefCounted

# Appearance and finish editors, shown as pixel-art modal panels.

static func swatch(color: Color, action: Callable, parent: Node, active: bool) -> Button:
	var S = UiKit.scale
	var b = Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(12,12)*S
	b.tooltip_text = "#"+color.to_html(false)
	var c = ColorRect.new()
	c.color = color
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.offset_left = 3*S
	c.offset_top = 3*S
	c.offset_right = -3*S
	c.offset_bottom = -3*S
	b.add_child(c)
	UiKit.set_active(b,active)
	b.pressed.connect(action)
	parent.add_child(b)
	return b

static func color_row(parent: Node, title: String, colors: Array, current: String, on_pick: Callable) -> void:
	parent.add_child(UiKit.label(title,0,UiKit.MUTED))
	var g = UiKit.grid(parent,8,1)
	for c in colors: swatch(Color(c),on_pick.bind(c),g,String(c) == current)
	var picker = ColorPickerButton.new()
	picker.color = Color(current)
	picker.edit_alpha = false
	picker.focus_mode = Control.FOCUS_NONE
	picker.custom_minimum_size = Vector2(12,12)*UiKit.scale
	picker.tooltip_text = "Couleur personnalisée"
	picker.color_changed.connect(func(c): on_pick.call(c.to_html(false)))
	g.add_child(picker)

static func options_row(parent: Node, title: String, labels: Array, current: int, on_pick: Callable, columns: int = 3) -> void:
	parent.add_child(UiKit.label(title,0,UiKit.MUTED))
	var g = UiKit.grid(parent,columns,1)
	for i in range(labels.size()):
		var b = UiKit.button(labels[i],on_pick.bind(i),g)
		b.add_theme_font_size_override("font_size",UiKit.fs(0))
		UiKit.set_active(b,i == current)

static func appearance(hud: Hud, game, item_id: int) -> void:
	var item: Dictionary = game.model.item_by_id(item_id)
	if item.is_empty(): return
	var draft: Dictionary = item.appearance.duplicate(true)
	var state = {"draft":draft}
	var rebuild: Callable
	rebuild = func():
		hud.open_modal("Personnaliser · "+Catalog.ITEMS[item.kind].name,func(col):
			var d: Dictionary = state.draft
			var row = UiKit.hbox(col,6)
			var preview = TextureRect.new()
			preview.texture = UiKit.pixel_texture(UiKit.portrait(d,true),2)
			preview.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
			var frame = UiKit.panel(row)
			frame.add_child(preview)
			var right = UiKit.vbox(row,2)
			right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var set_key = func(key, value):
				d[key] = value
				state.draft = Characters.normalize(d,item.kind)
				rebuild.call()
			var body = int(d.body)
			if Characters.is_escort(item.kind):
				var st: Dictionary = Characters.STANDINGS[item.kind]
				right.add_child(UiKit.label("Standing %d/4 · %s" % [int(st.level),st.name],1,UiKit.GOLD))
				options_row(right,"SILHOUETTE",Characters.SILHOUETTE_LABELS,int(d.get("silhouette",0)),func(i): set_key.call("silhouette",i),3)
			else:
				options_row(right,"CORPS",["Femme","Homme"],body,func(i): set_key.call("body",i),2)
			var labels: Dictionary = Characters.LABELS[body]
			# only the outfits of her standing (escorts) or everyday clothes
			var allowed: Array = Characters.allowed_outfits(item.kind,body)
			var outfit_labels: Array = []
			for k in allowed: outfit_labels.append(labels.outfit_style[k])
			options_row(right,"TENUE",outfit_labels,allowed.find(int(d.outfit_style)),func(i): set_key.call("outfit_style",allowed[i]),2)
			options_row(right,"COIFFURE",labels.hairstyle,int(d.hairstyle),func(i): set_key.call("hairstyle",i),3)
			options_row(right,"VISAGE" if body == 0 else "BARBE",labels.face,int(d.face),func(i): set_key.call("face",i),3)
			options_row(right,"LUNETTES",Characters.GLASSES,int(d.glasses),func(i): set_key.call("glasses",i),3)
			color_row(col,"PEAU",Characters.SKINS,d.skin,func(c): set_key.call("skin",c))
			color_row(col,"CHEVEUX",Characters.HAIRS,d.hair,func(c): set_key.call("hair",c))
			color_row(col,"TENUE",Characters.OUTFITS,d.outfit,func(c): set_key.call("outfit",c))
			var actions = UiKit.hbox(col,3)
			UiKit.button("Appliquer",func():
				hud.close_modal()
				game.apply_appearance(item_id,state.draft),actions,"","check")
			UiKit.button("Annuler",func(): hud.close_modal(),actions,"","close"),300)
	rebuild.call()

static func finishes(hud: Hud, game, room_id: int) -> void:
	var room: Dictionary = game.model.room_by_id(room_id)
	if room.is_empty(): return
	var original = {"floor_finish":room.floor_finish,"floor_color":room.floor_color,"wall_finish":room.wall_finish,"wall_color":room.wall_color}
	var state = {"draft":original.duplicate()}
	var rebuild: Callable
	var restore = func():
		for k in original: room[k] = original[k]
		game.view.rebuild()
	rebuild = func():
		hud.open_modal("Revêtements · "+Catalog.ROOMS[int(room.type)],func(col):
			var d: Dictionary = state.draft
			var set_key = func(key, value):
				d[key] = value
				if key == "floor_finish": d.floor_color = Finishes.FLOORS[value].color
				if key == "wall_finish": d.wall_color = Finishes.WALLS[value].color
				for k in d: room[k] = d[k]
				game.view.rebuild()
				rebuild.call()
			var floor_keys = Finishes.FLOORS.keys()
			var names: Array = []
			for k in floor_keys: names.append("%s · %d $/m²" % [Finishes.FLOORS[k].name,int(Finishes.FLOORS[k].value)])
			options_row(col,"SOL",names,floor_keys.find(d.floor_finish),func(i): set_key.call("floor_finish",floor_keys[i]),2)
			color_row(col,"COULEUR DU SOL",Finishes.SWATCHES,d.floor_color,func(c): set_key.call("floor_color",c))
			var wall_keys = Finishes.WALLS.keys()
			var wnames: Array = []
			for k in wall_keys: wnames.append("%s · %d $/m" % [Finishes.WALLS[k].name,int(Finishes.WALLS[k].value)])
			options_row(col,"MURS",wnames,wall_keys.find(d.wall_finish),func(i): set_key.call("wall_finish",wall_keys[i]),2)
			var price = Finishes.value(d.merged({"w":room.w,"h":room.h}))-Finishes.value(original.merged({"w":room.w,"h":room.h}))
			col.add_child(UiKit.label(("Coût de la rénovation : %s $" % UiKit.money(price)) if price > 0 else ("Remboursement : %s $" % UiKit.money(-price) if price < 0 else "Aucun coût"),1,UiKit.GOLD if price > 0 else UiKit.GREEN))
			color_row(col,"COULEUR DES MURS",Finishes.SWATCHES,d.wall_color,func(c): set_key.call("wall_color",c))
			var actions = UiKit.hbox(col,3)
			UiKit.button("Appliquer",func():
				hud.close_modal()
				game.apply_finishes(room_id,state.draft),actions,"","check")
			UiKit.button("Annuler",func(): hud.close_modal(),actions,"","close"),300,restore)
	rebuild.call()
