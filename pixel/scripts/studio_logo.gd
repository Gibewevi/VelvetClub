class_name StudioLogo
extends Control

# Every letter is a literal 5 x 7 pixel mask, rather than a smoothed font.
const GLYPHS = {
	"B":["11110","10001","10001","11110","10001","10001","11110"],
	"I":["11111","00100","00100","00100","00100","00100","11111"],
	"T":["11111","00100","00100","00100","00100","00100","00100"],
	"-":["00000","00000","00000","11111","00000","00000","00000"],
	"G":["01111","10000","10000","10111","10001","10001","01111"],
	"A":["01110","10001","10001","11111","10001","10001","10001"],
	"M":["10001","11011","10101","10101","10001","10001","10001"],
	"E":["11111","10000","10000","11110","10000","10000","11111"],
	"S":["01111","10000","10000","01110","00001","00001","11110"]
}
var animated = false
var elapsed = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	set_process(animated)

func _process(delta: float) -> void:
	elapsed += delta
	queue_redraw()

func _draw() -> void:
	var px = maxi(2,int(minf(size.x/57.0,size.y/13.0)))
	var start = ((size-Vector2(53,7)*px)/2.0).floor()
	for i in range(9):
		var age = elapsed-0.12*i-0.12 if animated else 10.0
		if age < 0: continue
		var progress = clampf(age/0.42,0,1)
		var settle = int(round(pow(1-progress,3)*7))*px
		var origin = start+Vector2(i*6*px,(-1 if i%2 == 0 else 1)*settle)
		var glyph: Array = GLYPHS["BIT-GAMES"[i]]
		for y in range(7):
			for x in range(5):
				if glyph[y][x] != "1": continue
				if animated and progress < float((x*3+y*2)%9)/10.0: continue
				var point = origin+Vector2(x,y)*px
				draw_rect(Rect2(point+Vector2(px,px),Vector2.ONE*px),Color("512942"))
				var color = Color("fff2d8") if y < 2 else (Color("f4a9cc") if y < 5 else Color("d85a97"))
				if animated and absf(i*6+x-(elapsed-1.6)*64) < 1.5 and elapsed > 1.6: color = Color("fff9eb")
				draw_rect(Rect2(point,Vector2.ONE*px),color)
	var rule = minf(1.0,maxf(0.0,(elapsed-1.1)/0.6)) if animated else 1.0
	for i in range(4):
		var width = int(11*rule)*px
		draw_rect(Rect2(start+Vector2(i*14,10)*px,Vector2(width,px)),Color("c45388"))
	# Four short, deterministic sparks at the end of the assembly, no noise.
	if animated and elapsed > 1.4 and elapsed < 2.2:
		var t = (elapsed-1.4)/0.8
		for side in [-1,1]:
			for row in [-1,1]:
				var p = start+Vector2(26.5+side*(29+int(t*4)),3+row*(4+int(t*3)))*px
				draw_rect(Rect2(p.floor(),Vector2.ONE*px),Color(1,.82,.55,1-t))
