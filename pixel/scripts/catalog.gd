class_name Catalog
extends RefCounted

const ROOMS = ["Espace public", "Chambre", "Toilettes", "Réserve", "Personnel", "Réception"]
const ROOM_COLORS = [Color("51404f"), Color("774653"), Color("647d80"), Color("655d58"), Color("525d72"), Color("7a3a4c")]
const ROOM_HINTS = [
	"Bar, salon et scène : le cœur du club.",
	"Salon privé : un lit, une table de nuit et une lampe.",
	"WC, urinoirs et lavabos pour les clients.",
	"Stock du bar : étagères, caisses et frigo.",
	"Vestiaire et bureau du personnel.",
	"Entrée : caisse, contrôle d'accès et vestiaire.",
]
const ROOM_PRICE = 40
const GROUP_CHARACTERS = 6
# Default finishes for each room type (floor pattern & colour, wall pattern & colour).
const ROOM_FINISHES = [
	{"floor_finish":"oak","floor_color":"cc8450","wall_finish":"worn_plaster","wall_color":"b83e56"},
	{"floor_finish":"carpet","floor_color":"9c2e4c","wall_finish":"worn_plaster","wall_color":"b44a5c"},
	{"floor_finish":"tile","floor_color":"8a8c98","wall_finish":"wall_tile","wall_color":"c2cad0"},
	{"floor_finish":"tile","floor_color":"7c7e8a","wall_finish":"worn_plaster","wall_color":"8e3a46"},
	{"floor_finish":"tile","floor_color":"868094","wall_finish":"worn_plaster","wall_color":"9a3a4c"},
	{"floor_finish":"oak","floor_color":"c47a4a","wall_finish":"worn_plaster","wall_color":"a8384e"},
]

# Spots: where characters use an item, in item-local metres (front = +z).
# use: sit / stand / work / dance / watch / lie ; who: client, staff or a role.
const ITEMS = {
	"bar": {"name":"Comptoir de bar", "size":Vector2(3,1), "group":0, "tag":"BAR", "price":1800,
		"spots":[{"use":"stand","who":"client","at":Vector2(-1,0.85),"face":Vector2(0,-1)},{"use":"stand","who":"client","at":Vector2(0,0.85),"face":Vector2(0,-1)},{"use":"stand","who":"client","at":Vector2(1,0.85),"face":Vector2(0,-1)},{"use":"work","who":"bartender","at":Vector2(0,-0.8),"face":Vector2(0,1)}]},
	"backbar": {"name":"Étagère à bouteilles", "size":Vector2(2,0.5), "group":0, "tag":"BAR", "price":900},
	"stool": {"name":"Tabouret", "size":Vector2(0.7,0.7), "group":0, "tag":"ASSISE", "price":120,
		"spots":[{"use":"sit","who":"client","at":Vector2(0,0.1),"face":Vector2(0,-1),"lift":7}]},
	"table": {"name":"Table ronde", "size":Vector2(1.3,1.3), "group":0, "tag":"SALON", "price":260},
	"chair": {"name":"Chaise", "size":Vector2(0.7,0.7), "group":-1, "tag":"ASSISE", "price":90,
		"spots":[{"use":"sit","who":"any","at":Vector2(0,0.12),"face":Vector2(0,1)}]},
	"sofa": {"name":"Canapé", "size":Vector2(2.6,1), "group":0, "tag":"SALON", "price":650,
		"spots":[{"use":"sit","who":"any","at":Vector2(-0.7,0.3),"face":Vector2(0,1)},{"use":"sit","who":"any","at":Vector2(0,0.3),"face":Vector2(0,1)},{"use":"sit","who":"any","at":Vector2(0.7,0.3),"face":Vector2(0,1)}]},
	"coffee": {"name":"Table basse", "size":Vector2(1.5,0.8), "group":0, "tag":"SALON", "price":180},
	"dance": {"name":"Scène & barre", "size":Vector2(3,3), "group":0, "tag":"SCÈNE", "price":2400, "anim":{"frames":4,"fps":3.0},
		"spots":[{"use":"dance","who":"escort","at":Vector2(0.35,0.3),"face":Vector2(0,1),"lift":7},{"use":"watch","who":"client","at":Vector2(0,1.85),"face":Vector2(0,-1)},{"use":"watch","who":"client","at":Vector2(1.85,0),"face":Vector2(-1,0)},{"use":"watch","who":"client","at":Vector2(1.35,1.35),"face":Vector2(-1,-1)}]},
	"plant": {"name":"Palmier", "size":Vector2(0.8,0.8), "group":7, "tag":"DÉCOR", "price":60},
	"plant_big": {"name":"Grand palmier", "size":Vector2(1,1), "group":7, "tag":"DÉCOR", "price":110},
	"sconce": {"name":"Applique chaude", "size":Vector2(0.6,0.6), "group":-1, "tag":"LUMIÈRE", "price":80, "wall":true},
	"neon": {"name":"Enseigne néon cœurs", "size":Vector2(2,0.5), "group":0, "tag":"NÉON", "price":350, "wall":true},
	"bed": {"name":"Lit double", "size":Vector2(2.2,2.7), "group":1, "tag":"CHAMBRE", "price":900,
		"spots":[{"use":"sit","who":"escort","at":Vector2(-0.45,0.35),"face":Vector2(0,1),"lift":4},{"use":"sit","who":"client","at":Vector2(0.45,0.35),"face":Vector2(0,1),"lift":4}]},
	"heart_bed": {"name":"Lit Cœur", "size":Vector2(2.2,2.7), "group":1, "tag":"CHAMBRE", "price":1200,
		"spots":[{"use":"sit","who":"escort","at":Vector2(-0.45,0.35),"face":Vector2(0,1),"lift":4},{"use":"sit","who":"client","at":Vector2(0.45,0.35),"face":Vector2(0,1),"lift":4}]},
	"fern": {"name":"Fougère en pot", "size":Vector2(0.5,0.5), "group":7, "tag":"PLANTES", "price":45},
	"cactus": {"name":"Cactus fleuri", "size":Vector2(0.5,0.5), "group":7, "tag":"PLANTES", "price":40},
	"aloe": {"name":"Aloé", "size":Vector2(0.5,0.5), "group":7, "tag":"PLANTES", "price":35},
	"monstera": {"name":"Monstera", "size":Vector2(0.6,0.6), "group":7, "tag":"PLANTES", "price":90},
	"strelitzia": {"name":"Oiseau de paradis", "size":Vector2(0.6,0.6), "group":7, "tag":"PLANTES", "price":110},
	"palm_small": {"name":"Petit palmier", "size":Vector2(0.6,0.6), "group":7, "tag":"PLANTES", "price":70},
	"palm_lights": {"name":"Petit palmier lumineux", "size":Vector2(0.6,0.6), "group":7, "tag":"PLANTES", "price":160, "anim":{"frames":3,"fps":2.5}},
	"shower": {"name":"Douche", "size":Vector2(0.9,0.9), "group":1, "tag":"HYGIÈNE", "price":650,
		# in and out through the glass door only; the floor in front of it stays clear
		"spots":[{"use":"wash","who":"any","at":Vector2(0,0),"face":Vector2(0,1),"door":Vector2(0,0.8)}],
		"clear":Rect2(-0.4,0.45,0.8,0.6)},
	"dancefloor": {"name":"Piste de danse", "size":Vector2(3,3), "group":0, "tag":"SALLE", "price":1500, "flat":true, "anim":{"frames":4,"fps":3.0},
		"spots":[{"use":"dance","who":"any","at":Vector2(-0.7,-0.7),"face":Vector2(1,1)},{"use":"dance","who":"any","at":Vector2(0.7,-0.7),"face":Vector2(-1,1)},
			{"use":"dance","who":"any","at":Vector2(-0.7,0.7),"face":Vector2(1,-1)},{"use":"dance","who":"any","at":Vector2(0.7,0.7),"face":Vector2(-1,-1)}]},
	"nightstand": {"name":"Table de nuit", "size":Vector2(0.7,0.7), "group":1, "tag":"CHAMBRE", "price":140},
	"lamp": {"name":"Lampe de chevet", "size":Vector2(0.6,0.6), "group":-1, "tag":"LUMIÈRE", "price":120},
	"mirror": {"name":"Miroir doré", "size":Vector2(0.9,0.5), "group":-1, "tag":"DÉCOR", "price":200},
	"armchair": {"name":"Fauteuil", "size":Vector2(1,1), "group":1, "tag":"ASSISE", "price":280,
		"spots":[{"use":"sit","who":"any","at":Vector2(0,0.12),"face":Vector2(0,1)}]},
	"toilet": {"name":"WC", "size":Vector2(0.7,1), "group":2, "tag":"SANITAIRE", "price":400,
		"spots":[{"use":"stand","who":"client","at":Vector2(0,0.72),"face":Vector2(0,-1)}]},
	"urinal": {"name":"Urinoir", "size":Vector2(0.5,0.45), "group":2, "tag":"SANITAIRE", "price":300,
		"spots":[{"use":"stand","who":"client","at":Vector2(0,0.55),"face":Vector2(0,-1)}]},
	"sink": {"name":"Lavabo", "size":Vector2(0.9,0.65), "group":2, "tag":"SANITAIRE", "price":280,
		"spots":[{"use":"stand","who":"client","at":Vector2(0,0.62),"face":Vector2(0,-1)}]},
	"bin": {"name":"Poubelle", "size":Vector2(0.5,0.5), "group":-1, "tag":"UTILITAIRE", "price":30},
	"shelf": {"name":"Étagère", "size":Vector2(1.8,0.7), "group":3, "tag":"STOCKAGE", "price":220},
	"crate": {"name":"Caisses", "size":Vector2(0.9,0.9), "group":3, "tag":"STOCKAGE", "price":60},
	"fridge": {"name":"Réfrigérateur", "size":Vector2(0.9,0.9), "group":3, "tag":"STOCKAGE", "price":700},
	"locker": {"name":"Casiers", "size":Vector2(1.5,0.7), "group":4, "tag":"PERSONNEL", "price":380},
	"desk": {"name":"Petit bureau", "size":Vector2(1.6,0.8), "group":4, "tag":"PERSONNEL", "price":320},
	"reception": {"name":"Comptoir d'accueil", "size":Vector2(2.0,0.8), "group":5, "tag":"ACCUEIL", "price":1200,
		"spots":[{"use":"stand","who":"client","at":Vector2(0,0.8),"face":Vector2(0,-1)},{"use":"work","who":"receptionist","at":Vector2(0,-0.72),"face":Vector2(0,1)}]},
	"coat_rack": {"name":"Portant à vêtements", "size":Vector2(1.25,0.5), "group":5, "tag":"VESTIAIRE", "price":180},
	"cloak_locker": {"name":"Casiers vestiaire", "size":Vector2(1.0,0.5), "group":5, "tag":"VESTIAIRE", "price":420},
	"rope": {"name":"Cordon velours", "size":Vector2(1.0,0.3), "group":5, "tag":"ACCUEIL", "price":150},
	"rug": {"name":"Tapis rouge", "size":Vector2(1.2,2.0), "group":-1, "tag":"DÉCOR", "price":140, "flat":true},
	"frame": {"name":"Tableau", "size":Vector2(0.8,0.2), "group":-1, "tag":"DÉCOR", "price":90, "wall":true},
	"cabinet": {"name":"Vitrine à alcools", "size":Vector2(0.8,0.45), "group":-1, "tag":"DÉCOR", "price":480},
	"pink": {"name":"Néon rose", "size":Vector2(0.5,0.5), "group":-1, "tag":"LUMIÈRE", "price":160},
	"red": {"name":"Néon rouge", "size":Vector2(0.5,0.5), "group":-1, "tag":"LUMIÈRE", "price":160},
	"purple": {"name":"Néon violet", "size":Vector2(0.5,0.5), "group":-1, "tag":"LUMIÈRE", "price":160},
	# Salvaged furniture of the derelict building: free, kept or thrown away at no cost.
	"old_sofa": {"name":"Vieux canapé", "size":Vector2(2.2,0.9), "group":0, "tag":"RÉCUPÉRÉ", "price":0, "used":true,
		"spots":[{"use":"sit","who":"any","at":Vector2(-0.6,0.25),"face":Vector2(0,1)},{"use":"sit","who":"any","at":Vector2(0.6,0.25),"face":Vector2(0,1)}]},
	"old_bed": {"name":"Vieux lit", "size":Vector2(2.0,2.4), "group":1, "tag":"RÉCUPÉRÉ", "price":0, "used":true,
		"spots":[{"use":"sit","who":"escort","at":Vector2(-0.4,0.3),"face":Vector2(0,1),"lift":4},{"use":"sit","who":"client","at":Vector2(0.4,0.3),"face":Vector2(0,1),"lift":4}]},
	"old_lamp": {"name":"Vieille lampe de chevet", "size":Vector2(0.6,0.6), "group":1, "tag":"RÉCUPÉRÉ", "price":0, "used":true},
	"old_table": {"name":"Vieille table", "size":Vector2(0.8,0.8), "group":0, "tag":"RÉCUPÉRÉ", "price":0, "used":true},
	"old_locker": {"name":"Vieux casier", "size":Vector2(1.0,0.7), "group":4, "tag":"RÉCUPÉRÉ", "price":0, "used":true},
	"old_fridge": {"name":"Vieux frigo", "size":Vector2(0.8,0.8), "group":3, "tag":"RÉCUPÉRÉ", "price":0, "used":true},
	"old_shelf": {"name":"Étagère rouillée", "size":Vector2(1.6,0.6), "group":3, "tag":"RÉCUPÉRÉ", "price":0, "used":true},
	"old_toilet": {"name":"WC défraîchi", "size":Vector2(0.7,1), "group":2, "tag":"RÉCUPÉRÉ", "price":0, "used":true,
		"spots":[{"use":"stand","who":"client","at":Vector2(0,0.72),"face":Vector2(0,-1)}]},
	"old_sink": {"name":"Lavabo défraîchi", "size":Vector2(0.9,0.65), "group":2, "tag":"RÉCUPÉRÉ", "price":0, "used":true,
		"spots":[{"use":"stand","who":"client","at":Vector2(0,0.62),"face":Vector2(0,-1)}]},
	"old_armchair": {"name":"Vieux fauteuil", "size":Vector2(1,1), "group":1, "tag":"RÉCUPÉRÉ", "price":0, "used":true,
		"spots":[{"use":"sit","who":"any","at":Vector2(0,0.12),"face":Vector2(0,1)}]},
	"old_rug": {"name":"Vieux tapis élimé", "size":Vector2(1.2,2.0), "group":-1, "tag":"RÉCUPÉRÉ", "price":0, "used":true, "flat":true},
	"old_wardrobe": {"name":"Vieille armoire", "size":Vector2(1.2,0.7), "group":1, "tag":"RÉCUPÉRÉ", "price":0, "used":true},
	"pillar": {"name":"Pilier", "size":Vector2(0.5,0.5), "group":-1, "tag":"STRUCTURE", "price":0, "used":true},
	"poster": {"name":"Vieille affiche", "size":Vector2(0.6,0.2), "group":-1, "tag":"RÉCUPÉRÉ", "price":0, "used":true, "wall":true},
	"boards": {"name":"Fenêtre condamnée", "size":Vector2(1.2,0.2), "group":-1, "tag":"RÉCUPÉRÉ", "price":0, "used":true, "wall":true},
	# Debris left in the building: technicians clean it (minutes of work).
	"trash_papers": {"name":"Papiers et détritus", "size":Vector2(0.8,0.8), "group":-1, "tag":"DÉCHETS", "price":0, "debris":true, "clean":6},
	"trash_bottles": {"name":"Bouteilles vides", "size":Vector2(0.7,0.7), "group":-1, "tag":"DÉCHETS", "price":0, "debris":true, "clean":5},
	"trash_planks": {"name":"Planches cassées", "size":Vector2(1.4,0.8), "group":-1, "tag":"DÉCHETS", "price":0, "debris":true, "clean":10},
	"trash_bags": {"name":"Sacs poubelle", "size":Vector2(0.8,0.7), "group":-1, "tag":"DÉCHETS", "price":0, "debris":true, "clean":8},
	"trash_cardboard": {"name":"Cartons écrasés", "size":Vector2(0.9,0.9), "group":-1, "tag":"DÉCHETS", "price":0, "debris":true, "clean":7},
	"trash_tissues": {"name":"Mouchoirs et serviettes usagés", "size":Vector2(0.6,0.6), "group":-1, "tag":"DÉCHETS", "price":0, "debris":true, "clean":3},
	"trash_rubble": {"name":"Gravats de plâtre", "size":Vector2(0.8,0.7), "group":-1, "tag":"DÉCHETS", "price":0, "debris":true, "clean":6},
	# Litter dropped by clients when no bin is at hand: quick to pick up.
	"litter_glass": {"name":"Verre abandonné", "size":Vector2(0.4,0.4), "group":-1, "tag":"DÉCHETS", "price":0, "debris":true, "litter":true, "clean":2},
	"litter_tissue": {"name":"Mouchoirs par terre", "size":Vector2(0.35,0.35), "group":-1, "tag":"DÉCHETS", "price":0, "debris":true, "litter":true, "clean":2},
	"litter_paper": {"name":"Papiers par terre", "size":Vector2(0.4,0.4), "group":-1, "tag":"DÉCHETS", "price":0, "debris":true, "litter":true, "clean":2},
	"escort": {"name":"Escort débutante", "size":Vector2(0.6,0.6), "group":6, "tag":"PERSONNEL", "price":0, "wage":15, "stars":0},
	"escort_pro": {"name":"Escort confirmée", "size":Vector2(0.6,0.6), "group":6, "tag":"PERSONNEL", "price":0, "wage":24, "stars":2},
	"escort_chic": {"name":"Escort élégante", "size":Vector2(0.6,0.6), "group":6, "tag":"PERSONNEL", "price":0, "wage":38, "stars":3},
	"escort_vip": {"name":"Escort de prestige", "size":Vector2(0.6,0.6), "group":6, "tag":"PERSONNEL", "price":0, "wage":60, "stars":4},
	"bartender": {"name":"Barman", "size":Vector2(0.6,0.6), "group":6, "tag":"PERSONNEL", "price":0, "wage":16},
	"receptionist": {"name":"Réceptionniste", "size":Vector2(0.6,0.6), "group":6, "tag":"PERSONNEL", "price":0, "wage":14},
	"security": {"name":"Agent de sécurité", "size":Vector2(0.6,0.6), "group":6, "tag":"PERSONNEL", "price":0, "wage":18},
	"janitor": {"name":"Technicien d'entretien", "size":Vector2(0.6,0.6), "group":6, "tag":"PERSONNEL", "price":0, "wage":13},
	"maid": {"name":"Femme de ménage", "size":Vector2(0.6,0.6), "group":6, "tag":"PERSONNEL", "price":0, "wage":13},
	"woman": {"name":"Hôtesse", "size":Vector2(0.6,0.6), "group":6, "tag":"PERSONNEL", "price":0, "wage":15},
	"man": {"name":"Portier", "size":Vector2(0.6,0.6), "group":6, "tag":"PERSONNEL", "price":0, "wage":15},
	"staff": {"name":"Employé polyvalent", "size":Vector2(0.6,0.6), "group":6, "tag":"PERSONNEL", "price":0, "wage":12},
}
# Behaviour of each staff kind in the club simulation.
const ROLES = {"escort":"escort","escort_pro":"escort","escort_chic":"escort","escort_vip":"escort","woman":"escort","bartender":"bartender","receptionist":"receptionist",
	"security":"security","man":"security","janitor":"cleaner","maid":"cleaner","staff":"cleaner"}
const STAFF_ORDER = ["janitor","maid","escort","escort_pro","escort_chic","escort_vip","bartender","receptionist","security"]
# Staff whose work is simulated for now; the others return with their features.
const STAFF_ACTIVE = ["janitor","maid","staff","escort","escort_pro","escort_chic","escort_vip","receptionist","bartender"]
const CLEANERS = ["janitor","maid","staff"]

static func footprint(kind: String, rotation: int) -> Vector2:
	var s: Vector2 = ITEMS[kind].size
	return Vector2(s.y, s.x) if posmod(rotation, 2) == 1 else s

# Which room types each piece of furniture belongs in. By default its own
# group (bar furniture in a public room, a WC in the toilets...); objects of
# no group (decoration, lights, plants) and people go anywhere. A few fit in
# several kinds of room.
const ROOM_FIT = {
	"sofa":[0,4,5],"old_sofa":[0,4,5],"table":[0,4,5],"old_table":[0,4,5],"coffee":[0,4,5],"neon":[0,1,5],
	"armchair":[0,1,4,5],"old_armchair":[0,1,4,5],"old_lamp":[0,1,4,5],"old_wardrobe":[1,4,5],"rope":[0,5],"fridge":[0,3,4],"shower":[1,2]}

static func home_room(kind: String) -> int:
	# the room type a piece of furniture makes of an empty room (-1: none)
	var g = int(ITEMS.get(kind,{}).get("group",-1))
	return g if g >= 0 and g < ROOMS.size() else -1

static func fits_room(kind: String, room_type: int) -> bool:
	if is_character(kind) or is_debris(kind): return true
	if ROOM_FIT.has(kind): return room_type in ROOM_FIT[kind]
	var home = home_room(kind)
	return home < 0 or home == room_type

static func fit_names(kind: String) -> String:
	# "les toilettes", "un espace public ou une réception"...
	var types: Array = ROOM_FIT.get(kind,[home_room(kind)])
	var names: Array = []
	for t in types: names.append(ROOMS[int(t)])
	if names.size() == 1: return names[0]
	return ", ".join(names.slice(0,names.size()-1))+" ou "+names[-1]

static func is_debris(kind: String) -> bool:
	return ITEMS.has(kind) and ITEMS[kind].get("debris",false)

static func is_used(kind: String) -> bool:
	return ITEMS.has(kind) and ITEMS[kind].get("used",false)

static func in_shop(kind: String) -> bool:
	return ITEMS.has(kind) and not is_character(kind) and not is_debris(kind) and not is_used(kind)

# Objects whose colours the player picks among the schemes below.
const COLOR_KINDS = ["dancefloor","dance"]
# Colour schemes of the stage and the dance floor (their lights in the art, their glow in game).
const DANCE_SCHEMES = [
	{"name":"Arc-en-ciel","colors":["ff4fa0","8a4ae0","3ad0e0","f0d050"]},
	{"name":"Rose & violet","colors":["ff4fa0","c04ae0","ff8ad0","7a3ad0"]},
	{"name":"Bleu glacier","colors":["3ad0e0","3a78f0","a0f0ff","5a4ae0"]},
	{"name":"Or & rouge","colors":["f0d050","ff5a3a","ffa040","d02a4a"]},
	{"name":"Vert acide","colors":["7af05a","3ad0a0","d0f05a","2a9a6a"]}]

static func anim_kind(item: Dictionary, frame: int) -> String:
	# The picture of an animated object for one frame of its loop.
	if item.kind in COLOR_KINDS: return "%s_s%d_f%d" % [item.kind,clampi(int(item.get("scheme",0)),0,DANCE_SCHEMES.size()-1),frame]
	return item.kind if frame == 0 else "%s_f%d" % [item.kind,frame]

static func stars_needed(kind: String) -> int:
	# Reputation (whole stars) a club needs to attract this recruit.
	return int(ITEMS.get(kind,{}).get("stars",0))

static func is_character(kind: String) -> bool:
	return ITEMS.has(kind) and int(ITEMS[kind].group) == GROUP_CHARACTERS

static func local_to_world(item: Dictionary, local: Vector2) -> Vector2:
	var r = posmod(int(item.rot),4)
	var v = local
	match r:
		1: v = Vector2(-local.y,local.x)
		2: v = Vector2(-local.x,-local.y)
		3: v = Vector2(local.y,-local.x)
	return Vector2(item.x,item.z)+v

static func direction_to_world(item: Dictionary, local: Vector2) -> Vector2:
	var r = posmod(int(item.rot),4)
	match r:
		1: return Vector2(-local.y,local.x)
		2: return Vector2(-local.x,-local.y)
		3: return Vector2(local.y,-local.x)
	return local

static func spots(item: Dictionary) -> Array:
	if item.get("delivery_pending",false): return []
	var out: Array = []
	var list: Array = ITEMS[item.kind].get("spots",[])
	for i in range(list.size()):
		var s: Dictionary = list[i]
		var o = {"item":int(item.id),"index":i,"use":s.use,"who":s.who,"pos":local_to_world(item,s.at),"face":direction_to_world(item,s.face),"lift":int(s.get("lift",0))}
		if s.has("door"): o.door = local_to_world(item,s.door)
		out.append(o)
	return out

static func clear_rect(item: Dictionary) -> Rect2:
	# Floor that must stay free in front of an item (the shower door), in world metres.
	var r: Rect2 = ITEMS.get(item.kind,{}).get("clear",Rect2())
	if r.size == Vector2.ZERO: return Rect2()
	var a = local_to_world(item,r.position)
	var b = local_to_world(item,r.end)
	return Rect2(Vector2(minf(a.x,b.x),minf(a.y,b.y)),(a-b).abs())
