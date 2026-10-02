class_name SiteWorker
extends Actor

# A building-site worker: yellow hard hat, orange high-visibility vest,
# dark work clothes. The body sheet changes with the tool in hand (shovel and
# trowel, or paint roller); what he carries, the wheelbarrow he pushes and
# the board he lays are small sprites attached to him.

const SKINS = ["e0ae8c","8d5a3c","c98e6a"]
var simulation: ClubSim
var site_id = -1
var role = 0
var tasks: Array = []
var task: Dictionary = {}
var wait = 0.0                 # game minutes left on the task in hand
var carried = Sprite2D.new()
var barrow = Sprite2D.new()
var board = Sprite2D.new()
var holding = ""
var barrow_state = -1          # -1 none, 0 empty, 1 full of concrete
var heading = Vector2(1,0)
var tool = ""

func setup(index: int) -> void:
	kind = "worker"
	set_meta("worker",true)
	role = index % 3
	var app = Characters.defaults("janitor")
	app.hairstyle = 2
	app.glasses = 0
	app.face = index % 3
	app.skin = SKINS[index % SKINS.size()]
	configure(app)
	var hat = Sprite2D.new()
	hat.texture = Art.tex(Art.chars.files["hat_m_hardhat"])
	hat.hframes = int(Art.chars.frames)
	hat.centered = false
	hat.offset = Vector2(-16,-46)
	hat.material = mat
	add_child(hat)
	layers.append(hat)
	files.append(Art.chars.files["hat_m_hardhat"])
	mat.set_shader_parameter("palette",palette(app))
	use_tool("hivis")
	speed = 2.0
	for s in [carried,barrow,board]:
		s.centered = false
		s.visible = false
		add_child(s)
	board.z_index = -1
	apply_frame()

static func palette(app: Dictionary) -> ImageTexture:
	# Never edit the shared palette of the staff: a copy for the workers.
	var img = Characters.palette(app).get_image()
	var ramps = {
		"g1":[Color("ffad5a"),Color("f0701e"),Color("c24f16"),Color("7e3218")],
		"g2":Palette.ramp4(Color("394052")),
		"g3":[Color("ffffff"),Color("d8e0e4"),Color("a9b2b8"),Color("6e767e")],
		"prop":[Color("ffe58a"),Color("f2c230"),Color("c8901e"),Color("7e5418")],
	}
	for role_name in ramps:
		for i in range(4): img.set_pixel(int(Art.chars.roles[role_name][i]),0,ramps[role_name][i])
	img.set_pixel(26,0,Color("8a6a4a"))
	img.set_pixel(27,0,Color("5a4030"))
	img.set_pixel(28,0,Color("2e2018"))
	img.set_pixel(29,0,Color("a9afbb"))
	img.set_pixel(30,0,Color("5b6170"))
	return ImageTexture.create_from_image(img)

func use_tool(name: String) -> void:
	if tool == name: return
	tool = name
	layers[1].texture = Art.tex(Art.chars.files["body_m_"+name])
	files[1] = Art.chars.files["body_m_"+name]

func hold(name: String) -> void:
	holding = name
	carried.visible = name != ""
	if name == "": return
	var info: Dictionary = Art.site["carry_"+name]
	carried.texture = Art.tex(info.file)
	carried.offset = -Vector2(info.ox,info.oy)
	update_attached()

func push(state: int) -> void:
	barrow_state = state
	barrow.visible = state >= 0
	update_attached()

func lay_board(on: bool) -> void:
	board.visible = on
	if not on: return
	var info: Dictionary = Art.site["plank_x" if absf(heading.x) > absf(heading.y) else "plank_z"]
	board.texture = Art.tex(info.file)
	board.offset = -Vector2(info.ox,info.oy)
	update_attached()

func play(name: String) -> void:
	# walking behind the wheelbarrow, the hands stay on its handles
	super.play("push" if name == "walk" and barrow_state >= 0 else name)

func face(dir: Vector2) -> void:
	super.face(dir)
	if dir.length() > 0.001:
		heading = Vector2(signf(dir.x),0) if absf(dir.x) >= absf(dir.y) else Vector2(0,signf(dir.y))
		update_attached()

func update_attached() -> void:
	var toward_camera = heading.x+heading.y > 0
	if carried.visible:
		var side = Vector2(heading.x,heading.y)*0.32
		carried.position = Iso.pixel(side.x,side.y)+Vector2(0,-19)
		carried.z_index = 1 if toward_camera else -1
	if barrow.visible:
		var r = 0 if heading.x > 0.5 else (1 if heading.y > 0.5 else (2 if heading.x < -0.5 else 3))
		var info: Dictionary = Art.site["barrow_%d_%d" % [r,barrow_state]]
		barrow.texture = Art.tex(info.file)
		barrow.offset = -Vector2(info.ox,info.oy)
		barrow.position = Iso.pixel(heading.x*0.95,heading.y*0.95)
		barrow.z_index = 1 if toward_camera else -1
	if board.visible:
		board.position = Iso.pixel(heading.x*0.55,heading.y*0.55)

func pixel_bounds() -> Rect2:
	var r = Rect2(position+Vector2(-10,-48),Vector2(20,50))
	if barrow.visible: r = r.merge(Rect2(position+barrow.position+Vector2(-20,-22),Vector2(40,30)))
	return r

func _process(delta: float) -> void:
	super._process(delta*(simulation.speed if simulation != null else 1))

func hit(_p: Vector2) -> bool: return false
