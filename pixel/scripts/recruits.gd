class_name Recruits
extends RefCounted

# Hiring from a short list. Every day three candidates apply for each job.
# Each has a speed and a quality of work (0.75 to 1.3; 1 is an ordinary
# employee) and asks for a wage that follows them, give or take a good deal
# or a greedy one. The player picks who to hire. The stats stay on the hired
# item ("staff") and the simulation reads them from the actor's brain:
#   speed   - tasks done faster (cleaning, check-in, rounds), quicker steps;
#             a fast bartender pours a second round more often.
#   quality - depends on the job: the welcome at the desk, the service at
#             the bar, fixtures left clean for longer, the clients' pleasure
#             in an escort's company.

const PER_ROLE = 3
const MIN_SKILL = 0.75
const MAX_SKILL = 1.3
const AD_PRICE = 100
# profiles drawn for each list: three different ones, so the choice means something
const TYPES = [
	{"speed":0.82,"quality":0.85,"tag":"Débutant"},
	{"speed":1.24,"quality":0.82,"tag":"Rapide mais brouillon"},
	{"speed":0.82,"quality":1.24,"tag":"Lent mais soigné"},
	{"speed":1.0,"quality":1.0,"tag":"Solide"},
	{"speed":1.2,"quality":1.2,"tag":"Expérimenté"},
]
const HAIRS = ["1a1418","2b2030","3a2a22","6a3c24","8a2e24","c0482c","e2b25a","231a16","8a4a2a"]

static func skill_names(kind: String) -> Array:
	# [speed name, what it does, quality name, what it does]
	match Catalog.ROLES.get(kind,""):
		"receptionist": return ["Rapidité","encaisse plus vite, la file avance","Accueil","clients plus satisfaits à l'arrivée"]
		"bartender": return ["Rapidité","sert plus souvent une deuxième tournée","Service","clients plus satisfaits au bar"]
		"cleaner": return ["Rapidité","nettoie et répare plus vite","Soin","sanitaires propres plus longtemps"]
		"security": return ["Rapidité","rondes plus fréquentes","Présence","les clients se sentent en sécurité"]
		"escort": return ["Énergie","va plus vite vers les clients","Charme","satisfaction, rendez-vous et pourboires"]
	return ["Rapidité","travaille plus vite","Qualité","travail plus soigné"]

static func base_wage(kind: String) -> int:
	return int(Catalog.ITEMS[kind].get("wage",0))

static func fair_wage(kind: String, speed: float, quality: float) -> float:
	return base_wage(kind)*(1.0+0.8*((speed-1.0)+(quality-1.0)))

static func stars(v: float) -> int:
	# 1 to 5 squares on the card
	return clampi(int(round((v-MIN_SKILL)/(MAX_SKILL-MIN_SKILL)*4.0))+1,1,5)

# ---------------------------------------------------------------- the lists

static func refresh(sim) -> void:
	# a new day brings new candidates
	if int(sim.recruit_day) == int(sim.day): return
	sim.recruit_day = int(sim.day)
	sim.recruit_batch = 0
	sim.recruit_gone = []

static func pool(sim, kind: String) -> Array:
	# The candidates of the day for a job. Drawn from the day, the job and
	# the round of ads, so they stay the same after a reload.
	refresh(sim)
	var gen = RandomNumberGenerator.new()
	gen.seed = hash("%d:%s:%d" % [int(sim.day),kind,int(sim.recruit_batch)])
	var types = range(TYPES.size())
	for i in range(types.size()-1,0,-1):
		var j = gen.randi_range(0,i)
		var t = types[i]
		types[i] = types[j]
		types[j] = t
	var out: Array = []
	for i in range(PER_ROLE):
		var c = candidate(kind,TYPES[types[i]],gen)
		c.key = "%d:%s:%d:%d" % [int(sim.day),kind,int(sim.recruit_batch),i]
		out.append(c)
	return out

static func candidate(kind: String, type: Dictionary, gen: RandomNumberGenerator) -> Dictionary:
	var app = Characters.hire_look(kind,gen)
	if not Characters.is_escort(kind):
		# the uniform stays, the person changes
		app.skin = Characters.SKINS[gen.randi_range(0,Characters.SKINS.size()-1)]
		app.hair = HAIRS[gen.randi_range(0,HAIRS.size()-1)]
		app = Characters.normalize(app,kind)
	var speed = snappedf(clampf(float(type.speed)+gen.randf_range(-0.07,0.07),MIN_SKILL,MAX_SKILL),0.05)
	var quality = snappedf(clampf(float(type.quality)+gen.randf_range(-0.07,0.07),MIN_SKILL,MAX_SKILL),0.05)
	var fair = fair_wage(kind,speed,quality)
	var wage = maxi(maxi(1,int(round(base_wage(kind)*0.6))),int(round(fair*(1.0+gen.randf_range(-0.14,0.14)))))
	var names: Array = CharacterProfiles.FEMALE_NAMES if int(app.get("body",0)) == 0 else CharacterProfiles.MALE_NAMES
	var name = names[gen.randi_range(0,names.size()-1)]+" "+CharacterProfiles.LAST_NAMES[gen.randi_range(0,CharacterProfiles.LAST_NAMES.size()-1)]
	var deal = ""
	if wage <= fair*0.92: deal = "Bonne affaire"
	elif wage >= fair*1.08: deal = "Exigeant"
	return {"kind":kind,"name":name,"age":gen.randi_range(21,58),"appearance":app,"speed":speed,"quality":quality,"wage":wage,"tag":type.tag,"deal":deal}

static func taken(sim, key: String) -> bool:
	# hired (and still in the club), or hired then let go today
	if sim.recruit_gone.has(key): return true
	for item in sim.model.furniture:
		if item.has("staff") and str(item.staff.get("key","")) == key: return true
	return false

static func advertise(sim) -> void:
	# a new ad: three new candidates per job right away
	refresh(sim)
	sim.recruit_batch = int(sim.recruit_batch)+1
	sim.money -= AD_PRICE
	sim.ledger.book(sim.day,"out","ads",AD_PRICE)
	sim.night.wages = int(sim.night.get("wages",0))+AD_PRICE
	sim.stats_changed.emit()

static func let_go(sim, item: Dictionary) -> void:
	# fired today: not on the list again
	var key = str(item.get("staff",{}).get("key",""))
	if key.begins_with("%d:" % int(sim.day)) and not sim.recruit_gone.has(key): sim.recruit_gone.append(key)

# ---------------------------------------------------------------- hired staff

static func hired(c: Dictionary) -> Dictionary:
	# what stays on the item once the candidate is hired
	return {"speed":float(c.speed),"quality":float(c.quality),"wage":int(c.wage),"name":str(c.name),"age":int(c.age),"key":str(c.key)}

static func stats(item: Dictionary) -> Dictionary:
	# staff hired before the short list work like an ordinary employee
	var s: Dictionary = item.get("staff",{})
	return {"speed":float(s.get("speed",1.0)),"quality":float(s.get("quality",1.0)),"wage":int(s.get("wage",base_wage(str(item.kind))))}

static func valid(s: Variant) -> bool:
	if not s is Dictionary or s.size() > 8: return false
	for field in ["speed","quality"]:
		var v = s.get(field)
		if not (v is float or v is int) or not is_finite(float(v)) or float(v) < 0.5 or float(v) > 1.5: return false
	var w = s.get("wage")
	if not (w is float or w is int) or not is_finite(float(w)) or float(w) < 0 or float(w) > 1000: return false
	if s.has("name") and (not s.name is String or s.name.length() > 40): return false
	if s.has("age") and (not (s.age is int or s.age is float) or float(s.age) < 16 or float(s.age) > 90): return false
	if s.has("key") and (not s.key is String or s.key.length() > 48): return false
	return true

static func normalized(s: Dictionary) -> Dictionary:
	var out = {"speed":clampf(float(s.speed),0.5,1.5),"quality":clampf(float(s.quality),0.5,1.5),"wage":int(s.wage)}
	for field in ["name","key"]:
		if s.has(field): out[field] = str(s[field])
	if s.has("age"): out.age = int(s.age)
	return out

static func to_dict(sim) -> Dictionary:
	return {"day":int(sim.recruit_day),"batch":int(sim.recruit_batch),"gone":sim.recruit_gone.duplicate()}

static func from_dict(sim, data: Variant) -> void:
	if not data is Dictionary: return
	var d = data.get("day")
	var b = data.get("batch")
	var g = data.get("gone")
	if not (d is int or d is float) or not (b is int or b is float) or not g is Array or g.size() > 200: return
	if not is_finite(float(d)) or not is_finite(float(b)) or float(b) < 0 or float(b) > 1000: return
	for key in g:
		if not key is String or key.length() > 48: return
	sim.recruit_day = int(d)
	sim.recruit_batch = int(b)
	sim.recruit_gone = g.duplicate()
