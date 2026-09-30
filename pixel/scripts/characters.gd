class_name Characters
extends RefCounted

# Appearance of placed characters and generated clients. Each option selects
# a pixel-art layer; colours only change the palette of those layers.
const DEFAULTS = {"skin":"c58f73","hair":"2b2030","outfit":"e0609a","hairstyle":0,"outfit_style":0,"face":0,"body":0,"glasses":0,"silhouette":0}
# Body shapes of the escorts (their outfits exist on each): 0 galbée, 1 très généreuse, 2 fine.
const SILHOUETTES = ["galbee","genereuse","fine"]
const SILHOUETTE_LABELS = ["Galbée","Très généreuse","Fine"]
const PRESETS = {
	"escort": {"skin":"c58f73","hair":"2b2030","outfit":"e0609a","hairstyle":0,"outfit_style":0,"face":0},
	"escort_pro": {"skin":"e0ae8c","hair":"c0482c","outfit":"c01e44","hairstyle":1,"outfit_style":6,"face":1},
	"escort_chic": {"skin":"f2c9ab","hair":"8a2e24","outfit":"7a1030","hairstyle":3,"outfit_style":7,"face":3},
	"escort_vip": {"skin":"f0c3a4","hair":"e2b25a","outfit":"a01030","hairstyle":2,"outfit_style":9,"face":3},
	"receptionist": {"skin":"f2c9ab","hair":"e2b25a","outfit":"6a3a8c","hairstyle":0,"outfit_style":3,"face":1},
	"maid": {"skin":"e8b896","hair":"6a3c24","outfit":"1e1a22","hairstyle":2,"outfit_style":4,"face":0},
	"security": {"body":1,"skin":"b98266","hair":"231a16","outfit":"232a44","hairstyle":0,"outfit_style":0,"face":1,"glasses":1},
	"janitor": {"body":1,"skin":"d6a383","hair":"2b1f18","outfit":"2e3c6e","hairstyle":1,"outfit_style":1,"face":2,"glasses":2},
	"bartender": {"body":1,"skin":"e0ae8c","hair":"8a4a2a","outfit":"1c1a20","hairstyle":3,"outfit_style":4,"face":1},
	"woman": {"skin":"d9a07c","hair":"8a2e24","outfit":"c01e44","hairstyle":1,"outfit_style":2,"face":2},
	"man": {"body":1,"skin":"9a6a50","hair":"161214","outfit":"1c1c24","hairstyle":3,"outfit_style":3,"face":0},
	"staff": {"body":1,"skin":"c99273","hair":"3a2a22","outfit":"3a4a5a","hairstyle":3,"outfit_style":2,"face":2},
}
# Order matters: saves store the index. 0-4 are the historic outfits.
const FEMALE_OUTFITS = ["lingerie","body","dress","blazer","maid","tube","bodycon","corset","cocktail","gown","sequin","string","balconnet","babydoll","bijoux"]
const MALE_OUTFITS = ["security","janitor","casual","suit","bartender"]
const FEMALE_HAIR = ["long","bob","bun","waves","pony"]
const MALE_HAIR = ["fade","short","shaved","short","curly"]
const LABELS = {
	0: {"outfit_style":["Lingerie","Body en dentelle","Robe courte","Tailleur","Tenue de soubrette","Bandeau & mini-jupe","Robe moulante","Corset & bas","Robe de cocktail","Robe du soir","Robe à sequins",
		"Soutien-gorge & string","Balconnet, résille & jarretelles","Nuisette transparente","Lingerie bijou"],
		"hairstyle":["Cheveux longs","Carré","Chignon","Boucles glamour","Queue-de-cheval"],"face":["Traits doux","Traits fins","Traits affirmés","Glamour"]},
	1: {"outfit_style":["Uniforme sécurité","Combinaison d'entretien","Décontractée","Costume","Gilet de barman"],"hairstyle":["Dégradé","Casquette","Rasée","Courte","Bouclée"],"face":["Barbe complète","Barbe courte","Rasé de près"]},
}
# Escort standings: the more prestigious the club (its stars), the classier
# the escorts it can attract, each with the outfits and looks of her rank.
const STANDINGS = {
	"escort": {"level":1,"name":"Débutante","stars":0,"outfits":[0,5,11],"hair":[0,4,1],"faces":[0,2],
		"colors":["e0609a","ff4f8a","c01e44","8a3aa0","3a78c8"]},
	"escort_pro": {"level":2,"name":"Confirmée","stars":2,"outfits":[1,6,12],"hair":[1,3,0,4],"faces":[1,2,3],
		"colors":["c01e44","8a2a8a","1c1a20","d02a5a","2a4a9a"]},
	"escort_chic": {"level":3,"name":"Élégante","stars":3,"outfits":[7,8,13],"hair":[3,2,0],"faces":[1,3],
		"colors":["7a1030","1c1a20","2a6a5a","3a2a6a","6a1a4a"]},
	"escort_vip": {"level":4,"name":"Prestige","stars":4,"outfits":[9,10,14],"hair":[2,3],"faces":[3],
		"colors":["a01030","1c1a20","d0a040","f2efe9","2a4a9a","5a1a6a"]},
}
const ESCORT_KINDS = ["escort","escort_pro","escort_chic","escort_vip"]
# Everyday outfits for the other women (clients, hostesses, maids, receptionists).
const EVERYDAY_OUTFITS = [2,3,4]
const GLASSES = ["Sans lunettes","Lunettes de soleil","Lunettes"]
const SKINS = ["f6d2b8","f0c3a4","e0ae8c","c99273","b98266","9a6a50","7a4a34","5a3424"]
const HAIRS = ["1a1418","2b2030","3a2a22","6a3c24","8a2e24","c0482c","e2b25a","f0e0c0","b0b0bc","8a3aa0","3a78c8","e060a0"]
const OUTFITS = ["e0609a","c01e44","6a3a8c","232a44","2e3c6e","1c1a20","1e1a22","2a6a5a","d0a040","f2efe9","3a4a5a","8a2a3a"]

static func is_character(kind: String) -> bool:
	return PRESETS.has(kind)

static func is_escort(kind: String) -> bool:
	return STANDINGS.has(kind)

static func defaults(kind: String = "escort") -> Dictionary:
	var result: Dictionary = DEFAULTS.duplicate(true)
	result.merge(PRESETS.get(kind,{}),true)
	return result

static func choice_count(key: String, body: int) -> int:
	match key:
		"outfit_style": return FEMALE_OUTFITS.size() if body == 0 else MALE_OUTFITS.size()
		"hairstyle": return FEMALE_HAIR.size() if body == 0 else MALE_HAIR.size()
		"face": return 4 if body == 0 else 3
		"glasses": return 3
		"body": return 2
		"silhouette": return SILHOUETTES.size() if body == 0 else 1
	return 1

static func allowed_outfits(kind: String, body: int) -> Array:
	# An escort wears the outfits of her standing; the other women keep to
	# everyday clothes; men choose freely.
	if body == 1: return range(MALE_OUTFITS.size())
	if STANDINGS.has(kind): return STANDINGS[kind].outfits
	return EVERYDAY_OUTFITS

static func normalize(data: Dictionary, kind: String = "") -> Dictionary:
	var result = defaults(kind)
	for key in ["skin","hair","outfit"]:
		if Finishes.valid_color(data.get(key)): result[key] = String(data[key]).to_lower()
	var body = data.get("body",result.body)
	if (body is int or body is float) and is_finite(float(body)): result.body = clampi(int(body),0,1)
	for key in ["outfit_style","hairstyle","face","glasses","silhouette"]:
		var value = data.get(key,result[key])
		if (value is int or value is float) and is_finite(float(value)): result[key] = clampi(int(value),0,choice_count(key,int(result.body))-1)
	var allowed = allowed_outfits(kind,int(result.body))
	if kind != "" and not int(result.outfit_style) in allowed: result.outfit_style = allowed[0]
	return result

static func valid(data: Variant) -> bool:
	if not data is Dictionary: return false
	for key in data:
		var value = data[key]
		if key in ["skin","hair","outfit"]:
			if not Finishes.valid_color(value): return false
		elif key in ["hairstyle","outfit_style","face","body","glasses","silhouette"]:
			if not (value is int or value is float) or not is_finite(float(value)) or float(value) < 0 or float(value) > 20 or float(value) != floor(float(value)): return false
		elif value is float and not is_finite(value): return false
	return true

static func outfit_name(app: Dictionary) -> String:
	return (MALE_OUTFITS if int(app.body) == 1 else FEMALE_OUTFITS)[int(app.outfit_style)]

static func hat(app: Dictionary) -> String:
	var outfit = outfit_name(app)
	if outfit == "security": return "police"
	if outfit == "maid": return "headband"
	if int(app.body) == 1 and int(app.hairstyle) == 1: return "cap"
	return ""

static func layers(app: Dictionary) -> Array:
	# Drawing order: back hair, body, face, front hair, headwear, glasses.
	var b = "m" if int(app.body) == 1 else "f"
	var hair = (MALE_HAIR if b == "m" else FEMALE_HAIR)[int(app.hairstyle)]
	var files: Dictionary = Art.chars.files
	var out: Array = []
	out.append(files["hairb_%s_%s" % [b,hair]])
	var body_key = "body_%s_%s" % [b,outfit_name(app)]
	var sil = int(app.get("silhouette",0))
	if b == "f" and sil > 0 and sil < SILHOUETTES.size() and files.has("%s_%s" % [body_key,SILHOUETTES[sil]]): body_key = "%s_%s" % [body_key,SILHOUETTES[sil]]
	out.append(files[body_key])
	var face = str(int(app.face)) if b == "m" else "f%d" % int(app.face)
	out.append(files["face_%s_%s" % [b,face]])
	out.append(files["hairf_%s_%s" % [b,hair]])
	var h = hat(app)
	if h != "" and files.has("hat_%s_%s" % [b,h]): out.append(files["hat_%s_%s" % [b,h]])
	if int(app.glasses) > 0: out.append(files["glasses_%s_%d" % [b,int(app.glasses)]])
	return out

static func palette(app: Dictionary) -> ImageTexture:
	return Palette.character(Color(app.skin),Color(app.hair),Color(app.outfit),outfit_name(app))

static func hire_look(kind: String, rng: RandomNumberGenerator) -> Dictionary:
	# A new recruit: escorts get a random look of their standing, the other
	# staff wear their uniform.
	if not STANDINGS.has(kind): return defaults(kind)
	var s: Dictionary = STANDINGS[kind]
	var app = defaults(kind)
	app.skin = SKINS[rng.randi_range(0,SKINS.size()-1)]
	app.hair = ["1a1418","2b2030","3a2a22","6a3c24","8a2e24","c0482c","e2b25a","f0e0c0","e060a0"][rng.randi_range(0,8)]
	app.outfit_style = s.outfits[rng.randi_range(0,s.outfits.size()-1)]
	app.hairstyle = s.hair[rng.randi_range(0,s.hair.size()-1)]
	app.face = s.faces[rng.randi_range(0,s.faces.size()-1)]
	app.outfit = s.colors[rng.randi_range(0,s.colors.size()-1)]
	app.glasses = 0
	# varied figures: very generous 4 times in 10, slim 1 in 4
	var roll = rng.randf()
	app.silhouette = 1 if roll < 0.4 else (2 if roll > 0.75 else 0)
	return normalize(app,kind)

static func random_client(rng: RandomNumberGenerator) -> Dictionary:
	var female = rng.randf() < 0.3
	var app = DEFAULTS.duplicate(true)
	app.body = 0 if female else 1
	app.skin = SKINS[rng.randi_range(0,SKINS.size()-1)]
	app.hair = ["2b2030","3a2a22","6a3c24","8a2e24","c0482c","e2b25a","f0e0c0","b0b0bc","8a3aa0","3a2a22"][rng.randi_range(0,9)]
	if female:
		app.outfit_style = [2,3][rng.randi_range(0,1)]
		app.hairstyle = rng.randi_range(0,2)
		app.outfit = ["c01e44","6a3a8c","2a6a5a","8a2a5a","d0a040","3a78c8"][rng.randi_range(0,5)]
	else:
		app.outfit_style = [2,3,3][rng.randi_range(0,2)]
		app.hairstyle = [0,2,3,3,4][rng.randi_range(0,4)]
		app.outfit = ["3c4062","4a3a5e","4a5a6e","8a2a3a","2e4a7a","6a5040","2a5a52"][rng.randi_range(0,6)]
		app.face = rng.randi_range(0,2)
	app.glasses = 2 if rng.randf() < 0.12 else 0
	return app
