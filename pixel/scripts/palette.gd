class_name Palette
extends RefCounted

# Hue-shifted ramps identical to tools/pixelart/pa_core.py: shadows drift to
# violet, lights to amber. Recolourable art stores palette indices, so any
# finish or appearance colour keeps the hand-picked tone structure.

static var cache: Dictionary = {}

static func toward(h: float, target: float, amount: float) -> float:
	var d = fposmod(target-h+0.5,1.0)-0.5
	if absf(d) <= amount: return fposmod(target,1.0)
	return fposmod(h+amount*signf(d),1.0)

static func ramp(base: Color, n: int = 6, mid: int = 3) -> Array:
	var h = base.h
	var s = base.s
	var v = base.v
	var grey = s <= 0.08
	var out: Array = []
	for i in range(n):
		var k = i-mid
		var hh = h
		var ss = s
		var vv = v
		if k < 0:
			var t = float(-k)
			if grey:
				hh = 0.70
				ss = minf(0.4,s+0.06*t)
			else:
				hh = toward(h,0.75,0.03*t)
				ss = minf(1.0,s+0.05*t)
			vv = v*(1.0-0.21*t)
		elif k > 0:
			var t = float(k)
			hh = h if grey else toward(h,0.11,0.025*t)
			ss = maxf(0.0,s-0.09*t)
			vv = minf(1.0,v+(minf(v*0.35,(1.0-v)*0.55)+0.03)*t)
		out.append(Color.from_hsv(hh,ss,vv))
	return out

static func ramp4(base: Color) -> Array:
	var r = ramp(base)
	return [r[4],r[3],r[2],r[1]]

static func texture(colors: Array, size: int = 64) -> ImageTexture:
	var img = Image.create(size,1,false,Image.FORMAT_RGBA8)
	img.fill(Color(0,0,0,1))
	for i in range(mini(colors.size(),size)):
		if colors[i] != null: img.set_pixel(i,0,colors[i])
	return ImageTexture.create_from_image(img)

static func floor_palette(color: Color) -> ImageTexture:
	var key = "floor:"+color.to_html(false)
	if not cache.has(key): cache[key] = texture(ramp(color),8)
	return cache[key]

static func darker(c: Color) -> Color:
	return Color(c.r*0.7,c.g*0.62,c.b*0.66)

static func wall_palette(face: Color, cap: Color = Color("c29a6c"), base: Color = Color("3b2432")) -> ImageTexture:
	var key = "wall:%s:%s" % [face.to_html(false),cap.to_html(false)]
	if cache.has(key): return cache[key]
	var colors: Array = []
	colors.resize(64)
	var slots = [face,cap,darker(face),base]
	for s in range(slots.size()):
		var r = ramp(slots[s])
		for t in range(6): colors[s*6+t] = r[t]
	colors[24] = Color("1b101e")
	# bare plaster behind peeled paint and missing tiles
	var plaster = ramp(Color("d8c8aa"))
	for t in range(6): colors[30+t] = plaster[t]
	cache[key] = texture(colors)
	return cache[key]

static func blush(skin: Color) -> Color:
	return Color(minf(1.0,skin.r*0.92+40.0/255.0),skin.g*0.72,skin.b*0.78)

static func character(skin: Color, hair: Color, outfit: Color, outfit_name: String) -> ImageTexture:
	var key = "char:%s:%s:%s:%s" % [skin.to_html(false),hair.to_html(false),outfit.to_html(false),outfit_name]
	if cache.has(key): return cache[key]
	var roles: Dictionary = Art.chars.roles
	var extra: Dictionary = Art.chars.outfits[outfit_name]
	var fixed: Dictionary = Art.chars.fixed
	var colors: Array = []
	colors.resize(64)
	colors[int(roles.ink)] = Color(fixed.ink)
	var bases = {"skin":skin,"hair":hair,"g1":outfit,"g2":Color(extra.g2),"g3":Color(extra.g3)}
	for role in bases:
		var r = ramp4(bases[role])
		for i in range(4): colors[int(roles[role][i])] = r[i]
	colors[int(roles.eye_white)] = Color(fixed.eye_white)
	colors[int(roles.iris)] = Color(fixed.iris)
	colors[int(roles.lips)] = Color(extra.get("lips",fixed.lips))
	colors[int(roles.blush)] = blush(skin)
	var shoe = ramp(Color(extra.shoe))
	colors[26] = shoe[4]
	colors[27] = shoe[3]
	colors[28] = shoe[1]
	colors[29] = Color(fixed.metal[0])
	colors[30] = Color(fixed.metal[1])
	colors[31] = Color(fixed.shine)
	var prop = ramp4(Color(fixed.prop))
	for i in range(4): colors[32+i] = prop[i]
	colors[36] = Color(fixed.wood[0])
	colors[37] = Color(fixed.wood[1])
	colors[38] = Color(fixed.lens[0])
	colors[39] = Color(fixed.lens[1])
	cache[key] = texture(colors)
	return cache[key]
