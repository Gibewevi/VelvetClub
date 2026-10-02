extends SceneTree

# Checks that the generated art respects the pixel grid of the game:
# 32 x 16 floor cells, 32 x 48 character frames, crisp alpha, and that every
# catalogue entry has its sprites.
var failures = 0
var checks = 0

func check(condition: bool, text: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("FAIL: "+text)

func binary_alpha(img: Image) -> bool:
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			var a = img.get_pixel(x,y).a
			if a > 0.02 and a < 0.98: return false
	return true

func opaque(img: Image, f: int, x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < 32 and y < 48 and img.get_pixel(f*32+x,y).a > 0.5

func pieces(img: Image, f: int) -> int:
	# 4-connected groups of opaque pixels in one frame.
	var seen = {}
	var count = 0
	for y in range(48):
		for x in range(32):
			if not opaque(img,f,x,y) or seen.has(Vector2i(x,y)): continue
			count += 1
			var stack = [Vector2i(x,y)]
			seen[Vector2i(x,y)] = true
			while not stack.is_empty():
				var p: Vector2i = stack.pop_back()
				for d in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
					var q = p+d
					if opaque(img,f,q.x,q.y) and not seen.has(q):
						seen[q] = true
						stack.append(q)
	return count

func lowest_row(img: Image, f: int) -> int:
	for y in range(47,-1,-1):
		for x in range(32):
			if opaque(img,f,x,y): return y
	return -1

func leg_pixels(img: Image, f: int) -> int:
	var n = 0
	for y in range(34,48):
		for x in range(32):
			if opaque(img,f,x,y): n += 1
	return n

func _init() -> void:
	Art.load_all()
	check(Art.ready,"Art manifests load")
	# Characters: sheets of 32 x 48 frames, palette indices only, no soft edges.
	var frames = int(Art.chars.frames)
	check(int(Art.chars.frame[0]) == 32 and int(Art.chars.frame[1]) == 48,"Character frame is 32 x 48 px")
	var size = int(Art.chars.palette_size)
	for key in Art.chars.files:
		var img = Art.image(Art.chars.files[key])
		check(img != null,"Character sheet %s loads" % key)
		if img == null: continue
		check(img.get_width() == 32*frames and img.get_height() == 48,"Sheet %s is %d frames of 32 x 48" % [key,frames])
		check(binary_alpha(img),"Sheet %s has hard pixel edges" % key)
		var bad = 0
		for y in range(48):
			for x in range(0,img.get_width()):
				var c = img.get_pixel(x,y)
				if c.a > 0.5:
					var idx = int(round(c.r*255.0/4.0))
					if idx < 1 or idx >= size: bad += 1
		check(bad == 0,"Sheet %s only uses palette indices" % key)
	for anim in ["front:idle","front:walk","front:sit","front:dance","front:mop","front:work","back:idle","back:walk","back:sit","front:stand","back:stand","front:kneel","back:kneel"]:
		check(Art.chars.anims.has(anim),"Animation %s exists" % anim)
	for anim in ["front:stand","back:stand"]:
		check(Art.chars.anims[anim].size() == 1,"Pose %s is static" % anim)
	for anim in ["front:kneel","back:kneel"]:
		check(Art.chars.anims[anim].size() == 6,"Resting pose %s has a slow breathing cycle" % anim)
	# Bodies stay in one piece in every frame (no seam or break between the
	# legs and the body), stand on the anchor row and keep a steady leg size
	# through the walk cycle.
	for key in Art.chars.files:
		if not String(key).begins_with("body_"): continue
		var img = Art.image(Art.chars.files[key])
		if img == null: continue
		for f in range(frames):
			check(pieces(img,f) == 1,"%s frame %d is one connected shape" % [key,f])
		for anim in ["front:idle","back:idle"]:
			for f in Art.chars.anims[anim]:
				# soles on row 46 (the anchor), their outline on row 47
				check(lowest_row(img,int(f)) == 47,"%s %s stands on the anchor row" % [key,anim])
		for anim in ["front:walk","back:walk"]:
			var sizes: Array = []
			for f in Art.chars.anims[anim]:
				sizes.append(leg_pixels(img,int(f)))
				check(absi(lowest_row(img,int(f))-47) <= 1,"%s %s frame %d keeps its feet on the ground" % [key,anim,int(f)])
			check(sizes.max()-sizes.min() <= maxi(10,int(sizes.max()*0.2)),"%s %s legs keep their size (%s)" % [key,anim,str(sizes)])
	# Every escort outfit exists on each body shape.
	for kind in Characters.ESCORT_KINDS:
		for o in Characters.STANDINGS[kind].outfits:
			for sil in range(Characters.SILHOUETTES.size()):
				var app = Characters.normalize({"outfit_style":o,"silhouette":sil},kind)
				var files = Characters.layers(app)
				check(Art.image(files[1]) != null and (sil == 0 or String(files[1]).ends_with("_%s.png" % Characters.SILHOUETTES[sil])),"Outfit %d exists in shape %s" % [o,Characters.SILHOUETTES[sil]])
	# Every appearance choice has its layers.
	for body in [0,1]:
		for o in range(Characters.choice_count("outfit_style",body)):
			for h in range(Characters.choice_count("hairstyle",body)):
				for fc in range(Characters.choice_count("face",body)):
					var app = Characters.normalize({"body":body,"outfit_style":o,"hairstyle":h,"face":fc,"glasses":1})
					var ok = true
					for file in Characters.layers(app): ok = ok and Art.image(file) != null
					check(ok,"Layers exist for body %d outfit %d hair %d face %d" % [body,o,h,fc])
	# Furniture: four orientations for every catalogue object.
	for kind in Catalog.ITEMS:
		if Catalog.is_character(kind):
			check(Characters.is_character(kind),"Character %s has an appearance preset" % kind)
			continue
		for r in range(4):
			var e = Art.furniture_entry(kind,r)
			check(not e.is_empty(),"%s has art for rotation %d" % [kind,r])
			if e.is_empty(): continue
			var img = Art.image(e.file)
			check(img != null and img.get_width() == int(e.w) and img.get_height() == int(e.h),"%s_%d matches its manifest size" % [kind,r])
	# Street trees: three static silhouettes, each with a flat tree pit, and
	# nothing cut at the edges of the picture.
	for v in range(3):
		var info: Dictionary = Art.tiles.props.get("tree_%d" % v,{})
		check(not info.is_empty() and int(info.get("frames",1)) == 1,"Tree %d is a single static picture" % v)
		if info.is_empty(): continue
		var img = Art.image(info.file)
		check(img != null and binary_alpha(img),"Tree %d is crisp" % v)
		check(Art.image(info.pit.file) != null,"Tree %d has its pit" % v)
		if img == null: continue
		var clipped = false
		for y in range(img.get_height()):
			if img.get_pixel(0,y).a > 0.5 or img.get_pixel(img.get_width()-1,y).a > 0.5: clipped = true
		for x in range(img.get_width()):
			if img.get_pixel(x,0).a > 0.5: clipped = true
		check(not clipped,"Tree %d crown is not cut by its picture" % v)
	# Every picture of the animated objects exists.
	for kind in Catalog.ITEMS:
		var anim: Dictionary = Catalog.ITEMS[kind].get("anim",{})
		if anim.is_empty(): continue
		var schemes = Catalog.DANCE_SCHEMES.size() if kind in Catalog.COLOR_KINDS else 1
		for sc in range(schemes):
			for f in range(int(anim.frames)):
				var name = Catalog.anim_kind({"kind":kind,"scheme":sc},f)
				check(not Art.furniture_entry(name,0).is_empty() and not Art.furniture_entry(name,3).is_empty(),"%s has its picture" % name)
	# Beds in use and unmade beds have their own pictures.
	for kind in ["bed_busy","bed_busy_1","bed_busy_2","bed_busy_3","bed_unmade","heart_bed_busy","heart_bed_busy_1","heart_bed_busy_2","heart_bed_busy_3","heart_bed_unmade","old_bed_busy","old_bed_busy_1","old_bed_busy_2","old_bed_busy_3","old_bed_unmade","clothes_pile"]:
		for r in range(4):
			check(not Art.furniture_entry(kind,r).is_empty(),"%s has art for rotation %d" % [kind,r])
	for icon in ["talk","no","sick","wash","heart","dollar","bang","star","zzz","sweat"]:
		check(Art.ui_texture("emotes",icon) != null,"Emote %s exists" % icon)
	# Floors tile on the 32 x 16 grid (period of 4 m).
	var period = int(Art.tiles.floor_period)
	for name in Art.tiles.floors:
		var img = Art.image(Art.tiles.floors[name])
		check(img.get_width() == 32*period and img.get_height() == 16*period,"Floor %s repeats on the 32 x 16 grid" % name)
	check(int(Art.tiles.wall_h) == 56 and int(Art.tiles.low_h) == 12,"Walls are 56 px high, cut-away walls 12 px")
	for key in Art.tiles.walls:
		var img = Art.image(Art.tiles.walls[key].file)
		check(img != null and binary_alpha(img),"Wall %s is crisp" % key)
	# Interface: the retro 10 x 10 monochrome icons, colour emotes and windows.
	for name in Art.ui.icons:
		var img = Art.image(Art.ui.icons[name])
		check(img.get_width() == 10 and img.get_height() == 10 and binary_alpha(img),"Icon %s is a crisp 10 x 10" % name)
	for name in Art.ui.emotes:
		var img = Art.image(Art.ui.emotes[name])
		check(img.get_width() == 16 and img.get_height() == 16,"Emote %s is 16 x 16" % name)
	for name in ["panel","title","window","button","button_hover","button_pressed","button_active","button_disabled","field","tooltip"]:
		check(Art.ui.panels.has(name) and Art.image(Art.ui.panels[name]) != null,"Interface frame %s exists" % name)
	for name in ["select","build","furniture","person","clients","services","reports","menu","undo","redo","save","close"]:
		check(Art.ui.icons.has(name),"Dock and window icon %s exists" % name)
	# Palette ramps mirror the generator exactly.
	var r = Palette.ramp(Color("c58f73"))
	check(r[0].to_html(false) == "492028" and r[3].to_html(false) == "c58f73" and r[4].to_html(false) == "edc59f","Runtime ramps match the art generator")
	print("ART_TESTS: %d checks, %d failures" % [checks,failures])
	if failures == 0: print("ART_TESTS_PASSED")
	quit(1 if failures > 0 else 0)
