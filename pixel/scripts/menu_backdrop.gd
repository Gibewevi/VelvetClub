class_name MenuBackdrop
extends Control

# A small scene built from the actual game sprites; no simulation or save
# is loaded behind the menu, and artist edits remain visible here too.
var clock = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	clock += delta
	queue_redraw()

func ground(x: float, z: float) -> Vector2:
	return Vector2(345,116)+Vector2((x-z)*16,(x+z)*8)

func poly(points: Array, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array(points),color)

func asset(kind: String, x: float, z: float, rotation: int = 0) -> void:
	var entry = Art.furniture_entry(kind,rotation)
	if entry.is_empty(): return
	draw_texture(Art.tex(entry.file),(ground(x,z)-Vector2(entry.ox,entry.oy)).round())

func _draw() -> void:
	draw_rect(Rect2(-600,-400,1680,1100),Color("100e1b"))
	for x in range(-18,22):
		for z in range(-18,22):
			var p = ground(x,z)
			if p.x < -50 or p.x > 530 or p.y < -50 or p.y > 350: continue
			poly([p,p+Vector2(16,8),p+Vector2(0,16),p+Vector2(-16,8)],Color("1d1b2b") if (x+z)%2 == 0 else Color("201d30"))
			draw_line(p,p+Vector2(16,8),Color("30283d"))
			draw_line(p,p+Vector2(-16,8),Color("30283d"))
	# Charcoal plinth, warm timber floor and the game's red/plum cutaway walls.
	poly([ground(0,0)+Vector2(0,5),ground(8,0)+Vector2(0,5),ground(8,7)+Vector2(0,5),ground(0,7)+Vector2(0,5)],Color("080711"))
	for x in range(8):
		for z in range(7):
			poly([ground(x,z),ground(x+1,z),ground(x+1,z+1),ground(x,z+1)],Color("825044") if z%2 == 0 else Color("75433e"))
			draw_line(ground(x,z),ground(x+1,z),Color("4d2d35"))
	for ends in [[ground(0,0),ground(8,0)],[ground(0,7),ground(0,0)]]:
		var a: Vector2 = ends[0]
		var b: Vector2 = ends[1]
		poly([a,b,b-Vector2(0,44),a-Vector2(0,44)],Color("642237"))
		draw_line(a-Vector2(0,44),b-Vector2(0,44),Color("e0bd79"),3)
		draw_line(a-Vector2(0,41),b-Vector2(0,41),Color("922038"),2)
	# Steady neon floor pools beneath the finished cabinets.
	poly([ground(1,1),ground(6,1),ground(6,3),ground(1,3)],Color(.75,.1,.38,.12))
	asset("bottles_arch",2.1,.6)
	asset("bottles_luxe",5.4,.6)
	asset("bar_luxe",3.6,2.6)
	asset("stool",2.3,3.9)
	asset("stool",3.6,3.9)
	asset("stool",4.9,3.9)
	asset("sofa",1.6,5.6)
	asset("table",4.1,5.5)
	asset("armchair",6.5,5.5,3)
	for corner in [[0,0],[8,0],[0,7]]:
		var p = ground(corner[0],corner[1])
		draw_rect(Rect2(p-Vector2(3,47),Vector2(6,47)),Color("392133"))
		draw_rect(Rect2(p-Vector2(3,47),Vector2(6,3)),Color("e0bd79"))
	# A single calm travelling accent along the plinth, rather than shimmer.
	var a = ground(0,7)
	var b = ground(8,7)
	draw_line(a,b,Color("b84677"),1)
	var pulse = .5+.5*sin(clock*.8)
	draw_line(a,b,Color(.95,.27,.58,.16+pulse*.12),2)
	# Opaque panel under the text; the club remains prominent on the right.
	draw_rect(Rect2(-80,-80,297,460),Color("171321"))
	draw_rect(Rect2(213,-80,4,460),Color("382338"))
	draw_rect(Rect2(217,-80,1,460),Color("5e3552"))
