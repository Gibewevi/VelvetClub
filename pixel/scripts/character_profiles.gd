class_name CharacterProfiles
extends RefCounted

# Persistent identities, separate from the temporary actors walking in the scene.
# Security observations are evidence; latent tendencies are never shown as facts.
const MAX_CLIENTS = 512
const MAX_MEMORIES = 16
const MAX_INCIDENTS = 32
const FEMALE_NAMES = ["Chloé","Élodie","Inès","Léa","Nadia","Sofia","Zoé","Hélène","Manon","Sarah","Emma","Julie"]
const MALE_NAMES = ["Alex","Bastien","David","Farid","Hugo","Jules","Karim","Marc","Olivier","Rémi","Théo","Lucas"]
const LAST_NAMES = ["Martin","Bernard","Dubois","Thomas","Robert","Richard","Petit","Durand","Leroy","Moreau","Simon","Laurent","Lefebvre","Michel","Garcia","Roux","Vincent","Fournier","Morel","Girard","André","Lefèvre","Mercier","Dupont","Lambert","Bonnet","François","Martinez","Legrand","Garnier","Faure","Rousseau"]
const JOBS = ["la restauration","le commerce","la logistique","l'informatique","l'artisanat","le spectacle","les transports","l'hôtellerie"]
const HOBBIES = ["la musique live","la danse","le cinéma","la cuisine","les voyages","la photographie","les jeux de société","le jardinage"]
const PREFERENCES = ["bar","lounge","dance","stage"]
const PREF_NAMES = {"bar":"Le bar et les conversations","lounge":"Le salon et les sièges confortables","dance":"La piste de danse","stage":"Les spectacles sur scène"}
const INCIDENT_NAMES = {"theft":"Vol","aggression":"Comportement dangereux","damage":"Dégradation"}
var records: Dictionary = {}
var next_id = 1
var rng = RandomNumberGenerator.new()

func _init() -> void:
	rng.seed = 20260959

func get_profile(id: String) -> Dictionary:
	return records.get(id,{})

func create(kind: String, appearance: Dictionary, day: int) -> Dictionary:
	var id = "p%08d" % next_id
	next_id += 1
	var gen = RandomNumberGenerator.new()
	gen.seed = int(id.trim_prefix("p"))+590000
	var names: Array = FEMALE_NAMES if int(appearance.get("body",1)) == 0 else MALE_NAMES
	var job: String = JOBS[gen.randi_range(0,JOBS.size()-1)]
	var hobby: String = HOBBIES[gen.randi_range(0,HOBBIES.size()-1)]
	var preference: String = PREFERENCES[gen.randi_range(0,PREFERENCES.size()-1)]
	var patient = gen.randf() < .5
	var clean = gen.randf() < .45
	var generous = gen.randf() < .35
	var p = {"id":id,"kind":kind,"name":names[gen.randi_range(0,names.size()-1)]+" "+LAST_NAMES[gen.randi_range(0,LAST_NAMES.size()-1)],"age":gen.randi_range(23,64),
		"appearance":appearance.duplicate(true),"preference":preference,"patient":patient,"clean":clean,"generous":generous,
		"patience":65.0 if patient else 48.0,"cleanliness":1.3 if clean else 1.0,
		"budget_base":gen.randi_range(100,250),"preferred_day":gen.randi_range(0,6),"preferred_hour":gen.randi_range(20,23),
		"story":"Travaille dans %s et aime %s. Vient au club pour %s." % [job,hobby,{"bar":"discuter autour d'un verre","lounge":"se détendre dans une ambiance confortable","dance":"danser après une longue semaine","stage":"profiter des spectacles"}[preference]],
		"employee_trait":"efficient" if kind in ["maid","janitor"] else ("welcoming" if kind in ["bartender","receptionist"] else "focused"),
		"shift":"soir" if gen.randf() < .5 else "nuit","work_minutes":0.0,"created_day":day,
		"visits":0,"finished_visits":0,"good_visits":0,"spent":0,"last_arrival":0,"last_satisfaction":0.0,"loyalty":.3,
		"watched":false,"note":"","memories":[],"incidents":[],
		"latent":{"theft":gen.randf_range(0,.12),"aggression":gen.randf_range(0,.08)}}
	if kind != "client":
		p.story = "A travaillé dans %s avant de rejoindre l'équipe. Aime %s et souhaite gagner en expérience dans son métier." % [job,hobby]
		p.staff_item = -1
	records[id] = p
	return p

func ensure_employee(item: Dictionary, day: int) -> Dictionary:
	var p = get_profile(str(item.get("profile_id","")))
	if p.is_empty() or p.kind != item.kind or int(p.get("staff_item",-1)) != int(item.id):
		p = create(item.kind,item.appearance,day)
		p.staff_item = int(item.id)
		# hired from the short list: the name and age on the candidate's card
		var hired: Dictionary = item.get("staff",{})
		if hired.has("name") and str(hired.name) != "": p.name = str(hired.name)
		if hired.has("age"): p.age = int(hired.age)
		item.profile_id = p.id
		remember(p.id,day,"Rejoint l'équipe du club.")
	p.appearance = item.appearance.duplicate(true)
	return p

func remember(id: String, day: int, text: String) -> void:
	var p = get_profile(id)
	if p.is_empty(): return
	p.memories.push_front({"day":maxi(1,day),"text":text.left(240)})
	if p.memories.size() > MAX_MEMORIES: p.memories.resize(MAX_MEMORIES)

func select_client(active_ids: Array, day: int, hour: float, force_return: bool = false) -> Dictionary:
	var candidates: Array = []
	var weights: Array = []
	var total = 0.0
	for p in records.values():
		if p.kind != "client" or p.id in active_ids or int(p.last_arrival) >= day or int(p.visits) == 0: continue
		var weight = .15+float(p.loyalty)
		if ClubCalendar.weekday(day) == int(p.preferred_day): weight *= 2
		if absf(hour-float(p.preferred_hour)) < 2: weight *= 1.5
		candidates.append(p)
		weights.append(weight)
		total += weight
	if candidates.is_empty() or (not force_return and rng.randf() > .45): return {}
	var roll = rng.randf()*total
	for i in candidates.size():
		roll -= float(weights[i])
		if roll <= 0: return candidates[i]
	return candidates.back()

func make_client(appearance: Dictionary, day: int, active_ids: Array) -> Dictionary:
	var clients = records.values().filter(func(p): return p.kind == "client")
	if clients.size() >= MAX_CLIENTS:
		clients.sort_custom(func(a,b): return int(a.last_arrival) < int(b.last_arrival))
		var freed = false
		for p in clients:
			if p.id in active_ids or p.watched or p.note != "" or not p.incidents.is_empty() or int(p.visits) >= 2: continue
			records.erase(p.id)
			freed = true
			break
		if not freed: return {}
	return create("client",appearance,day)

func arrive(p: Dictionary, day: int) -> void:
	p.last_arrival = day
	if int(p.visits) == 0 and p.memories.is_empty(): remember(p.id,day,"Découvre le club pour la première fois.")

func admit(a: Actor, day: int) -> void:
	var p = get_profile(str(a.brain.get("profile_id","")))
	if p.is_empty() or a.brain.get("profile_admitted",false): return
	a.brain.profile_admitted = true
	p.visits = int(p.visits)+1
	remember(p.id,day,"Première entrée dans le club." if int(p.visits) == 1 else "Revient au club · visite %d." % int(p.visits))

func spend(a: Actor, amount: int) -> void:
	var p = get_profile(str(a.brain.get("profile_id","")))
	if not p.is_empty():
		p.spent = int(p.spent)+maxi(0,amount)
		a.brain.profile_spent = int(a.brain.get("profile_spent",0))+maxi(0,amount)

func sync_spending(a: Actor) -> void:
	var unrecorded = int(a.brain.get("spent",0))-int(a.brain.get("profile_spent",0))
	if unrecorded > 0: spend(a,unrecorded)

func finish(a: Actor, day: int) -> void:
	var p = get_profile(str(a.brain.get("profile_id","")))
	if p.is_empty() or a.brain.get("profile_finished",false): return
	sync_spending(a)
	a.brain.profile_finished = true
	if not a.brain.get("paid",false):
		remember(p.id,day,"Repart avant d'entrer après une attente ou un accès impossible.")
		return
	admit(a,day)
	p.finished_visits = int(p.finished_visits)+1
	p.last_satisfaction = clampf(float(a.brain.sat),0,100)
	p.loyalty = clampf(lerpf(float(p.loyalty),p.last_satisfaction/100.0,.3),.05,.95)
	if p.last_satisfaction >= 60:
		p.good_visits = int(p.good_visits)+1
		remember(p.id,day,"Bonne soirée · satisfaction %d %% · %d $ dépensés." % [int(p.last_satisfaction),int(a.brain.spent)])
	else:
		remember(p.id,day,"Soirée décevante · satisfaction %d %% · %d $ dépensés." % [int(p.last_satisfaction),int(a.brain.spent)])
	if int(p.good_visits) == 3 and p.last_satisfaction >= 60: remember(p.id,day,"Trois bonnes soirées : devient un habitué satisfait.")

func employee_work(id: String, minutes: float, day: int) -> void:
	var p = get_profile(id)
	if p.is_empty() or minutes <= 0: return
	var before = float(p.work_minutes)
	p.work_minutes = minf(1000000,before+minutes)
	if before < 480 and float(p.work_minutes) >= 480: remember(id,day,"Objectif atteint : 8 heures d'expérience au club. Efficacité +5 %.")

func employee_factor(id: String) -> float:
	var p = get_profile(id)
	if p.is_empty(): return 1.0
	return (.9 if p.employee_trait == "efficient" else 1.0)*(.95 if float(p.work_minutes) >= 480 else 1.0)

func welcome_bonus(id: String) -> float:
	var p = get_profile(id)
	return 1.0 if not p.is_empty() and p.employee_trait == "welcoming" else 0.0

func mark_watched(id: String, value: bool, day: int) -> void:
	var p = get_profile(id)
	if p.is_empty() or p.watched == value: return
	p.watched = value
	remember(id,day,"Ajouté au suivi par la direction." if value else "Retiré du suivi par la direction.")

# Called by future theft/danger systems after an observation, never by biography generation.
# event_id makes reporting the same incident by guard + camera idempotent.
func record_incident(id: String, event_id: String, kind: String, day: int, cost: int, source: String, confirmed: bool) -> bool:
	var p = get_profile(id)
	if p.is_empty() or p.kind != "client" or not INCIDENT_NAMES.has(kind) or event_id.is_empty() or event_id.length() > 128 or source.is_empty(): return false
	for e in p.incidents:
		if e.id == event_id:
			if e.kind != kind: return false
			if confirmed and not e.confirmed:
				e.confirmed = true
				e.cost = maxi(0,cost)
				e.source = source.left(100)
				remember(id,day,"Incident confirmé : "+INCIDENT_NAMES[kind]+".")
				return true
			return false
	p.incidents.push_front({"id":event_id.left(128),"kind":kind,"day":day,"cost":maxi(0,cost) if confirmed else 0,"source":source.left(100),"confirmed":confirmed})
	if p.incidents.size() > MAX_INCIDENTS: p.incidents.resize(MAX_INCIDENTS)
	remember(id,day,("Incident confirmé : " if confirmed else "Signalement à vérifier : ")+INCIDENT_NAMES[kind]+".")
	return true

func incident_cost(id: String) -> int:
	var total = 0
	for e in get_profile(id).get("incidents",[]):
		if e.confirmed: total += int(e.cost)
	return total

func to_dict() -> Dictionary:
	return {"version":1,"next_id":next_id,"rng_state":str(rng.state),"records":records.values().duplicate(true)}

static func number(value: Variant, low: float, high: float, fallback: float) -> float:
	return clampf(float(value),low,high) if (value is int or value is float) and is_finite(float(value)) else fallback

func from_dict(data: Variant) -> void:
	records.clear()
	next_id = 1
	rng.seed = 20260959
	if not data is Dictionary or not data.get("records") is Array: return
	for raw in data.records.slice(0,3512):
		if not raw is Dictionary or not raw.get("id") is String or not raw.get("kind") is String: continue
		var id: String = raw.id
		if not id.begins_with("p") or not id.trim_prefix("p").is_valid_int() or id.length() > 16 or records.has(id): continue
		var serial = id.trim_prefix("p").to_int()
		if serial < 1 or serial > 1000000000: continue
		var kind: String = raw.kind
		if kind != "client" and not Catalog.is_character(kind): continue
		if not Characters.valid(raw.get("appearance",{})): continue
		# Reconstruct immutable narrative and tendencies from the identity seed.
		next_id = serial
		var p = create(kind,Characters.normalize(raw.get("appearance",{}),"" if kind == "client" else kind),1)
		records.erase(p.id)
		p.id = id
		records[id] = p
		for key in ["visits","finished_visits","good_visits","spent","last_arrival","created_day","staff_item"]:
			p[key] = int(number(raw.get(key),-1 if key == "staff_item" else 0,1000000000,p.get(key,0)))
		p.work_minutes = number(raw.get("work_minutes"),0,1000000,0)
		p.loyalty = number(raw.get("loyalty"),.05,.95,.3)
		p.last_satisfaction = number(raw.get("last_satisfaction"),0,100,0)
		p.watched = raw.get("watched",false) == true
		p.note = raw.get("note","").left(240) if raw.get("note","") is String else ""
		for m in raw.get("memories",[]) if raw.get("memories",[]) is Array else []:
			if m is Dictionary and m.get("text") is String:
				p.memories.append({"day":int(number(m.get("day"),1,1000000000,1)),"text":m.text.left(240)})
			if p.memories.size() >= MAX_MEMORIES: break
		for e in raw.get("incidents",[]) if raw.get("incidents",[]) is Array else []:
			if not e is Dictionary or not e.get("id") is String or not INCIDENT_NAMES.has(e.get("kind","")) or not e.get("source") is String: continue
			if p.incidents.any(func(other): return other.id == e.id.left(128)): continue
			p.incidents.append({"id":e.id.left(128),"kind":e.kind,"day":int(number(e.get("day"),1,1000000000,1)),"cost":int(number(e.get("cost"),0,1000000000,0)) if e.get("confirmed",false) == true else 0,"source":e.source.left(100),"confirmed":e.get("confirmed",false) == true})
			if p.incidents.size() >= MAX_INCIDENTS: break
	var highest = 1
	for id in records: highest = maxi(highest,str(id).trim_prefix("p").to_int()+1)
	next_id = maxi(highest,int(number(data.get("next_id"),1,1000000001,highest)))
	var state = data.get("rng_state","")
	if state is String and state.is_valid_int(): rng.state = state.to_int()
