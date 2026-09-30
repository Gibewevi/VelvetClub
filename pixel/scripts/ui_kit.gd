class_name UiKit
extends RefCounted

# Retro interface of the earlier builds, redrawn as pixel art: charcoal and
# plum windows with a pink accent on the title bar, bevelled buttons, hard
# drop shadows and 10 x 10 monochrome icons. Every texture is enlarged by a
# whole number (nearest neighbour); Pixelify Sans sits on the same pixel grid.
const INK = Color("eee7ed")
const MUTED = Color("ada2b2")
const ACCENT = Color("d889af")
const GOLD = Color("ffd24a")
const GREEN = Color("7fe07a")
const RED = Color("ff6070")
const DIM = Color("5c5470")
const SEP = Color("37424b")
static var scale = 2
static var font: FontFile
static var theme: Theme

static func setup(ui_scale: int) -> Theme:
	scale = ui_scale
	# The imported font resource (the raw .ttf is not shipped in the export).
	font = (load("res://fonts/PixelifySans.ttf") as FontFile).duplicate()
	font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	font.hinting = TextServer.HINTING_NONE
	font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	theme = Theme.new()
	theme.default_font = font
	theme.default_font_size = fs(1)
	for cls in ["Button","OptionButton"]:
		theme.set_stylebox("normal",cls,button_box("button"))
		theme.set_stylebox("hover",cls,button_box("button_hover"))
		theme.set_stylebox("pressed",cls,button_box("button_pressed"))
		theme.set_stylebox("hover_pressed",cls,button_box("button_pressed"))
		theme.set_stylebox("disabled",cls,button_box("button_disabled"))
		theme.set_stylebox("focus",cls,StyleBoxEmpty.new())
		theme.set_color("font_color",cls,INK)
		theme.set_color("font_hover_color",cls,Color.WHITE)
		theme.set_color("font_pressed_color",cls,Color.WHITE)
		theme.set_color("font_disabled_color",cls,DIM)
		theme.set_color("icon_normal_color",cls,INK)
		theme.set_color("icon_hover_color",cls,Color.WHITE)
		theme.set_color("icon_pressed_color",cls,Color.WHITE)
		theme.set_constant("h_separation",cls,4*scale)
	theme.set_stylebox("panel","PanelContainer",box("panel"))
	theme.set_color("font_color","Label",INK)
	theme.set_stylebox("normal","LineEdit",button_box("field"))
	theme.set_stylebox("focus","LineEdit",button_box("field"))
	theme.set_color("font_color","LineEdit",INK)
	theme.set_color("font_placeholder_color","LineEdit",DIM)
	theme.set_stylebox("panel","TooltipPanel",button_box("tooltip"))
	theme.set_color("font_color","TooltipLabel",INK)
	theme.set_font_size("font_size","TooltipLabel",fs(1))
	var line = StyleBoxLine.new()
	line.color = SEP
	line.thickness = scale
	theme.set_stylebox("separator","HSeparator",line)
	theme.set_constant("separation","HSeparator",4*scale)
	for cls in ["VScrollBar","HScrollBar"]:
		for state in ["scroll","grabber","grabber_highlight","grabber_pressed"]:
			var b = StyleBoxFlat.new()
			b.bg_color = {"scroll":Color("15141d"),"grabber":Color("514650"),"grabber_highlight":Color("a76d8b"),"grabber_pressed":ACCENT}[state]
			b.set_content_margin_all(2*scale)
			theme.set_stylebox(state,cls,b)
	theme.set_stylebox("slider","HSlider",flat(Color("15141d"),Color("49414e")))
	theme.set_stylebox("grabber_area","HSlider",flat(Color("503044"),Color("15141d")))
	theme.set_stylebox("grabber_area_highlight","HSlider",flat(Color("6a3c5a"),Color("15141d")))
	theme.set_icon("grabber","HSlider",knob())
	theme.set_icon("grabber_highlight","HSlider",knob())
	for icon_name in ["checked","unchecked","checked_disabled","unchecked_disabled"]:
		theme.set_icon(icon_name,"CheckBox",tex("icons","checked" if icon_name.begins_with("checked") else "unchecked"))
	theme.set_color("font_color","CheckBox",INK)
	return theme

static func fs(level: int) -> int:
	# Pixelify Sans is drawn on a grid of size/10: 10 px per interface pixel
	# lands its pixels exactly on the interface pixels (20 px for big numbers).
	return (10 if level < 3 else 20)*scale

static func tex(group: String, name: String) -> Texture2D:
	return Art.ui_texture(group,name,scale)

static func nine(name: String, l: int, t: int, r: int, b: int) -> StyleBoxTexture:
	var s = StyleBoxTexture.new()
	s.texture = Art.ui_texture("panels",name,scale)
	s.texture_margin_left = l*scale
	s.texture_margin_top = t*scale
	s.texture_margin_right = r*scale
	s.texture_margin_bottom = b*scale
	s.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	s.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	return s

static func box(name: String) -> StyleBoxTexture:
	# 16 x 16 frames with a 2 px hard shadow on the right and bottom.
	var s = nine(name,3,3,5,5)
	s.content_margin_left = 6*scale
	s.content_margin_right = 8*scale
	s.content_margin_top = 5*scale
	s.content_margin_bottom = 7*scale
	return s

static func title_box() -> StyleBoxTexture:
	var s = nine("title",3,3,5,1)
	s.content_margin_left = 4*scale
	s.content_margin_right = 6*scale
	s.content_margin_top = 3*scale
	s.content_margin_bottom = 2*scale
	return s

static func window_box() -> StyleBoxTexture:
	var s = nine("window",3,2,5,5)
	s.content_margin_left = 6*scale
	s.content_margin_right = 8*scale
	s.content_margin_top = 5*scale
	s.content_margin_bottom = 7*scale
	return s

static func button_box(name: String) -> StyleBoxTexture:
	# 12 x 12 bevelled buttons with a 1 px shadow.
	var s = nine(name,3,3,4,4)
	s.content_margin_left = 6*scale
	s.content_margin_right = 7*scale
	s.content_margin_top = 3*scale
	s.content_margin_bottom = 4*scale
	return s

static func flat(color: Color, border: Color) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = color
	s.border_color = border
	s.set_border_width_all(scale)
	s.anti_aliasing = false
	s.set_content_margin_all(2*scale)
	return s

static func knob() -> Texture2D:
	var img = Image.create(6*scale,8*scale,false,Image.FORMAT_RGBA8)
	img.fill(Color("08060e"))
	img.fill_rect(Rect2i(scale,scale,4*scale,6*scale),ACCENT)
	img.fill_rect(Rect2i(scale,scale,4*scale,scale),Color("f4c6dc"))
	return ImageTexture.create_from_image(img)

static func label(text: String, level: int = 1, color: Color = INK) -> Label:
	var l = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size",fs(level))
	l.add_theme_color_override("font_color",color)
	return l

static func icon(name: String, color: Color = INK) -> TextureRect:
	var t = TextureRect.new()
	t.texture = tex("icons",name)
	t.modulate = color
	t.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t

static func button(text: String, action: Callable, parent: Node = null, tip: String = "", icon_name: String = "") -> Button:
	var b = Button.new()
	b.text = text
	b.tooltip_text = tip
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_size_override("font_size",fs(1))
	if icon_name != "":
		b.icon = tex("icons",icon_name)
		b.expand_icon = false
	b.pressed.connect(action)
	if parent != null: parent.add_child(b)
	return b

static func icon_button(icon_name: String, action: Callable, parent: Node = null, tip: String = "") -> Button:
	var b = button("",action,parent,tip,icon_name)
	var names = {"normal":"button","hover":"button_hover","pressed":"button_pressed","hover_pressed":"button_pressed","disabled":"button_disabled"}
	for state in names:
		var s: StyleBoxTexture = button_box(names[state])
		s.content_margin_left = 4*scale
		s.content_margin_right = 5*scale
		s.content_margin_top = 3*scale
		s.content_margin_bottom = 4*scale
		b.add_theme_stylebox_override(state,s)
	return b

static func set_active(b: Button, on: bool) -> void:
	var current = b.get_theme_stylebox("normal")
	var s = button_box("button_active" if on else "button")
	if current is StyleBoxTexture:
		s.content_margin_left = current.content_margin_left
		s.content_margin_right = current.content_margin_right
		s.content_margin_top = current.content_margin_top
		s.content_margin_bottom = current.content_margin_bottom
	b.add_theme_stylebox_override("normal",s)

static func panel(parent: Node) -> PanelContainer:
	var p = PanelContainer.new()
	p.add_theme_stylebox_override("panel",box("panel"))
	if parent != null: parent.add_child(p)
	return p

static func separator(parent: Node) -> void:
	parent.add_child(HSeparator.new())

static func vbox(parent: Node, sep: int = 3) -> VBoxContainer:
	var c = VBoxContainer.new()
	c.add_theme_constant_override("separation",sep*scale)
	if parent != null: parent.add_child(c)
	return c

static func hbox(parent: Node, sep: int = 3) -> HBoxContainer:
	var c = HBoxContainer.new()
	c.add_theme_constant_override("separation",sep*scale)
	if parent != null: parent.add_child(c)
	return c

static func grid(parent: Node, columns: int, sep: int = 3) -> GridContainer:
	var g = GridContainer.new()
	g.columns = columns
	g.add_theme_constant_override("h_separation",sep*scale)
	g.add_theme_constant_override("v_separation",sep*scale)
	if parent != null: parent.add_child(g)
	return g

static func chip(color: Color, w: int = 6, h: int = 6) -> ColorRect:
	var r = ColorRect.new()
	r.color = color
	r.custom_minimum_size = Vector2(w,h)*scale
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

class RetroWindow:
	# A retro window: a title bar with a pink accent line, a centred title and
	# a close button, above a bordered body. Drag the bar to move it.
	extends VBoxContainer
	var bar: PanelContainer
	var title: Label
	var close_button: Button
	var body: PanelContainer
	var content: VBoxContainer
	var draggable = false
	var dragging = false

	func _init(text: String, on_close: Callable, movable: bool) -> void:
		draggable = movable
		add_theme_constant_override("separation",0)
		bar = PanelContainer.new()
		bar.add_theme_stylebox_override("panel",UiKit.title_box())
		bar.mouse_filter = Control.MOUSE_FILTER_STOP
		bar.mouse_default_cursor_shape = Control.CURSOR_MOVE if movable else Control.CURSOR_ARROW
		add_child(bar)
		var row = UiKit.hbox(bar,2)
		var left = Control.new()
		left.custom_minimum_size.x = 13*UiKit.scale
		row.add_child(left)
		title = UiKit.label(text,1)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title.clip_text = true
		row.add_child(title)
		if on_close.is_valid():
			close_button = UiKit.icon_button("close",on_close,row,"Fermer · Échap")
		else:
			var right = Control.new()
			right.custom_minimum_size.x = 13*UiKit.scale
			row.add_child(right)
		body = PanelContainer.new()
		body.add_theme_stylebox_override("panel",UiKit.window_box())
		body.size_flags_vertical = Control.SIZE_EXPAND_FILL
		add_child(body)
		content = UiKit.vbox(body,3)
		bar.gui_input.connect(_on_bar_input)

	func _on_bar_input(event: InputEvent) -> void:
		if not draggable: return
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			dragging = event.pressed
		elif event is InputEventMouseMotion and dragging:
			var s = UiKit.scale
			var p = position+event.relative
			p = Vector2(snappedf(p.x,s),snappedf(p.y,s))
			var area = get_viewport_rect().size
			position = p.clamp(Vector2(-size.x+40*s,0),area-Vector2(40*s,20*s))

static func window(text: String, on_close: Callable = Callable(), movable: bool = false) -> RetroWindow:
	return RetroWindow.new(text,on_close,movable)

static func money(v: int) -> String:
	var s = str(absi(v))
	var out = ""
	while s.length() > 3:
		out = " "+s.substr(s.length()-3)+out
		s = s.substr(0,s.length()-3)
	return ("-" if v < 0 else "")+s+out

static func pixel_texture(img: Image, mult: int = 1) -> ImageTexture:
	var copy = img.duplicate()
	var f = scale*mult
	if f > 1: copy.resize(copy.get_width()*f,copy.get_height()*f,Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(copy)

static func portrait(app: Dictionary, full: bool = false) -> Image:
	# Composite the real character layers (frame 0, facing the viewer)
	# through the palette, pixel by pixel.
	var pal: Image = Characters.palette(app).get_image()
	var out = Image.create(32,48,false,Image.FORMAT_RGBA8)
	out.fill(Color(0,0,0,0))
	for file in Characters.layers(app):
		var src: Image = Art.image(file)
		for y in range(48):
			for x in range(32):
				var c = src.get_pixel(x,y)
				if c.a < 0.5: continue
				var idx = int(round(c.r*255.0/4.0))
				out.set_pixel(x,y,pal.get_pixel(idx,0))
	if full: return out
	return out.get_region(Rect2i(4,2,24,24))
