class_name ClubSim
extends Node

# Club simulation. The player renovates a derelict building and opens or
# closes the club. Clients queue outside the door: nobody enters before paying
# the entrance at the reception desk, served by a receptionist at her post;
# without one the queue grows and clients lose patience. Inside they look
# around, drink at the bar (served by a bartender), sit in the lounge where
# escorts keep them company, then leave more or less happy; technicians clear
# the debris. The other advanced mechanics (stage, private rooms, mess made by
# clients, the 20:00-04:00 night with its report, security) are kept below and
# switched off in FEATURES, to be brought back and tested one by one.
signal stats_changed
signal night_over(report: Dictionary)
signal notice(text: String)
signal debris_cleaned(item_id: int)
signal open_changed(value: bool)

# lounge_company: escorts keep the lounge clients company (flirt, hearts).
# reception: clients queue outside and pay at the desk; bar: drinks served by a bartender;
# private: escorts meet clients in the public room, agree on a service and take them to a bedroom.
const FEATURES = {"reception":true,"bar":true,"stage":true,"lounge_company":true,"private":true,
	"toilets":true,"client_mess":false,"night_cycle":false,"staff_roles":false,"services":false}
# Which feature switches each staff role on (cleaners always work).
const ROLE_FEATURE = {"receptionist":"reception","bartender":"bar","escort":"lounge_company","security":"staff_roles"}
const QUEUE_MAX = ClubAdmission.QUEUE_LIMIT
const QUEUE_GAP = 0.65
const QUICK_KNEEL_GAP = 0.4
const OPEN_MINUTES = 480
const DAY_MINUTES = 1440
const MINUTES_PER_SECOND = 2.5
# Simulated time per frame is capped: when the computer cannot keep up, the
# game slows down instead of simulating ever more per frame (which made each
# frame longer still, until the window stopped answering).
const MAX_FRAME = 0.1
const NAMES = ["Alex","Bastien","Chloé","David","Élodie","Farid","Gaël","Hugo","Inès","Jules","Karim","Léa","Marc","Nadia","Olivier","Paul","Quentin","Rémi","Sofia","Théo","Ugo","Victor","Wassim","Yanis","Zoé","Mehdi","Lucas","Nathan","Hélène","Manon"]
const ACTIVITY = {"look":"Fait le tour","entering":"Entre","bar":"Au bar","lounge":"Au salon","dance":"Danse","stage":"Devant la scène","private":"En chambre","toilet":"Aux toilettes","toilet_seek":"Cherche les toilettes","toilet_wait":"Attend un sanitaire libre","wash_hands":"Se lave les mains","wash_wait":"Attend un lavabo","checkin":"À la réception","queue":"Fait la queue","enter":"Arrive","leave":"S'en va","walk":"Se déplace","cloak":"Au vestiaire"}

var model: BuildingModel
var view: WorldView
var nav = ClubNav.new()
var rng = RandomNumberGenerator.new()
var profiles = CharacterProfiles.new()
var traffic = TrafficHistory.new()
var admission = ClubAdmission.new()
var maintenance_rng = RandomNumberGenerator.new()
var maintenance_clock = 0.0
# Seed capital for a modest club: initial equipment and a payroll reserve.
# Loading a saved club restores its actual balance through from_dict().
const START_MONEY = 15000
var money = START_MONEY
var day = 1
var minute = 1080.0
var opening_hours = ClubCalendar.default_opening()
var opening_override = -1
var override_window = false
var weather_rng = RandomNumberGenerator.new()
var waste_rng = RandomNumberGenerator.new()
var bins_taken: Dictionary = {}  # bin id -> maid emptying it
var rain_strength = 0.0
var weather_remaining = 180.0
var wage_remainder = 0.0
var recruit_day = 0        # the day the candidate lists were drawn for
var recruit_batch = 0      # ads placed that day: each brings new candidates
var recruit_gone: Array = []   # candidates hired then let go today
var saved_weather_state = ""
var saved_weather_ground: Dictionary = {}
var saved_night: Dictionary = {}
var speed = 1
var rating = 1.0
var open = false
var debris_taken: Dictionary = {}
var prices = {"entry":20,"drink":12,"dance":30,"private":150}
var night: Dictionary = {}
var history: Array = []
var staff: Dictionary = {}
var clients: Array = []
var dirt: Array = []
var saved_dirt: Array = []
var sanitary_queue: Array = []
var sanitary_saturated_until = 0.0
var reserved: Dictionary = {}
var spawn_timer = 0.0
var recent_satisfaction: Array = []
var closing = false
var paused_for_report = false
var active = true
var entrance: Dictionary = {}
var last_hour = -1
var queue: Array = []          # clients waiting outside, the first one pays next
var queue_notice = 0.0
var busy_beds: Dictionary = {}   # bed id -> client in service there
var beds_taken: Dictionary = {}  # bed id -> cleaner making it
var elapsed = 0.0                # game minutes since the start (never wraps)
var hints: Dictionary = {}       # notice key -> elapsed minute it may show again
signal world_changed
signal debris_dropped(id: int)

func setup(building: BuildingModel, world: WorldView) -> void:
	model = building
	view = world
	rng.seed = 20260928
	maintenance_rng.seed = 20260951
	waste_rng.seed = 20261002
	weather_rng.seed = 20260955
	if saved_weather_state.is_valid_int(): weather_rng.state = saved_weather_state.to_int()
	reset_night()
	restore_night(saved_night)
	saved_night.clear()
	layout_changed()
	restore_dirt()
	refresh_schedule_state()
	view.rain_ground.from_dict(saved_weather_ground)
	view.rain.phase = view.rain_ground.phase
	view.rain.step(0,rain_strength)

func reset_night() -> void:
	night = {"entry":0,"bar":0,"dance":0,"private":0,"wages":0,"clients":0,"served":0,"satisfaction":[],"day":day,"impatient":0,
		"met":0,"agreed":0,"refused":0,"tips":0,"floor_dates":0,"stage_tips":0,"stage_dates":0,"tier_0":0,"tier_1":0,"tier_2":0,"infections":0,"sick":0,"showers":0,"beds_made":0,"accidents":0,"toilet_visits":0,"dirt_cleaned":0}

func restore_night(data: Dictionary) -> void:
	for key in night:
		var value = data.get(key)
		if key == "satisfaction" and value is Array:
			night[key] = value.filter(func(n): return (n is int or n is float) and is_finite(float(n)) and n >= 0 and n <= 100).slice(0,1000)
		elif key != "day" and (value is int or value is float) and is_finite(float(value)):
			night[key] = clampi(int(value),0,1000000000)
	night.day = day

func to_dict() -> Dictionary:
	for client in clients:
		if is_instance_valid(client): profiles.sync_spending(client)
	var spills: Array = []
	for d in dirt: spills.append({"x":d.pos.x,"z":d.pos.y,"kind":d.get("kind","water"),"load":d.get("load",1.0),"work":d.get("work",6.0),"fixture":d.get("fixture",-1),"origin_x":d.get("origin",d.pos).x,"origin_z":d.get("origin",d.pos).y})
	return {"money":money,"day":day,"minute":minute,"rating":rating,"open":open,"prices":prices.duplicate(),"history":history.duplicate(true),"dirt":spills,"calendar_version":1,"opening_hours":opening_hours.duplicate(),"opening_override":opening_override,"override_window":override_window,
		"weather":{"rain":rain_strength,"remaining":weather_remaining,"rng_state":str(weather_rng.state),"ground":view.rain_ground.to_dict() if view != null else saved_weather_ground.duplicate()},"wage_remainder":wage_remainder,"night":night.duplicate(true),"characters":profiles.to_dict(),"recruits":Recruits.to_dict(self),"traffic":traffic.to_dict()}

func from_dict(data: Variant) -> void:
	if not data is Dictionary: return
	profiles.from_dict(data.get("characters",{}))
	traffic.from_dict(data.get("traffic",{}))
	Recruits.from_dict(self,data.get("recruits"))
	for key in ["money","day","minute","rating"]:
		var v = data.get(key)
		if (v is int or v is float) and is_finite(float(v)): set(key,v)
	money = int(money)
	day = maxi(1,int(day))
	minute = clampf(float(minute),0,DAY_MINUTES-1)
	rating = clampf(float(rating),0,5)
	# Preserve the visible hour of older saves, which measured from 20:00.
	if not data.has("calendar_version") and (data.get("minute") is int or data.get("minute") is float):
		var legacy_minute = minute
		minute = fposmod(legacy_minute+1200.0,DAY_MINUTES)
		if legacy_minute >= 240.0: day += 1
	open = data.get("open",false) == true
	if ClubCalendar.valid(data.get("opening_hours"),true): opening_hours = ClubCalendar.normalized(data.opening_hours)
	var manual = data.get("opening_override",-1)
	if manual in [-1,0,1] and data.get("override_window",false) is bool:
		opening_override = int(manual)
		override_window = data.get("override_window",false)
	var weather = data.get("weather",{})
	saved_weather_ground = {}
	if weather is Dictionary:
		if weather.get("ground") is Dictionary: saved_weather_ground = weather.ground.duplicate()
		for key in ["rain","remaining"]:
			var n = weather.get(key)
			if (n is int or n is float) and is_finite(float(n)):
				if key == "rain": rain_strength = clampf(float(n),0,1)
				else: weather_remaining = clampf(float(n),.01,720)
		if weather.get("rng_state","") is String: saved_weather_state = weather.get("rng_state","")
	var remainder = data.get("wage_remainder",0)
	if (remainder is int or remainder is float) and is_finite(float(remainder)): wage_remainder = clampf(float(remainder),0,.999999)
	if model != null:
		if saved_weather_state.is_valid_int(): weather_rng.state = saved_weather_state.to_int()
		refresh_schedule_state()
		view.rain_ground.from_dict(saved_weather_ground)
		view.rain.phase = view.rain_ground.phase
		view.rain.step(0,rain_strength)
	if data.get("night") is Dictionary:
		saved_night = data.night.duplicate(true)
		if not night.is_empty():
			restore_night(saved_night)
			saved_night.clear()
	var p = data.get("prices",{})
	if p is Dictionary:
		for k in prices:
			var v = p.get(k)
			if (v is int or v is float) and is_finite(float(v)): prices[k] = clampi(int(v),0,999)
	var h = data.get("history",[])
	if h is Array: history = h.slice(maxi(0,h.size()-14))
	saved_dirt.clear()
	var spills = data.get("dirt",[])
	if spills is Array:
		for d in spills.slice(0,Plumbing.MAX_PUDDLES):
			if not d is Dictionary or not d.get("kind","water") in ["water","urine"]: continue
			var x = d.get("x")
			var z = d.get("z")
			if not (x is int or x is float) or not (z is int or z is float): continue
			if not is_finite(float(x)) or not is_finite(float(z)) or absf(float(x)) > Iso.LOT or absf(float(z)) > Iso.LOT: continue
			var amount = d.get("load",1.0)
			var work = d.get("work",6.0)
			if not (amount is int or amount is float) or not (work is int or work is float): continue
			if not is_finite(float(amount)) or not is_finite(float(work)) or amount <= 0 or work <= 0: continue
			var spill = {"x":float(x),"z":float(z),"kind":d.get("kind","water"),"load":clampf(amount,.1,3),"work":clampf(work,.1,60)}
			var source = d.get("fixture",-1)
			var ox = d.get("origin_x",x)
			var oz = d.get("origin_z",z)
			if (source is int or source is float) and is_finite(float(source)) and source == floor(source) and source >= 0 and source < 2147483647 and (ox is int or ox is float) and (oz is int or oz is float) and is_finite(float(ox)) and is_finite(float(oz)) and absf(ox) <= Iso.LOT and absf(oz) <= Iso.LOT:
				spill.merge({"fixture":int(source),"origin":Vector2(ox,oz)})
			saved_dirt.append(spill)
	if view != null: restore_dirt()

# ------------------------------------------------------------------ layout

func layout_changed() -> void:
	var p0 = Prof.t("sim.layout")
	_timed_layout_changed()
	Prof.add("sim.layout",p0)

func _timed_layout_changed() -> void:
	sanitary_queue.clear()
	nav.rebuild(model)
	find_entrance()
	admission.rebuild(self)
	sync_staff()
	for a in staff.values():
		if is_instance_valid(a) and a.brain.state in ["to_fixture","cleaning_fixture","to_repair","repairing"]:
			release(a)
			a.path = []
			a.brain.state = "post"
		if is_instance_valid(a) and a.brain.get("role","") == "cleaner" and a.brain.has("dirt"):
			release_dirt_task(a)
			a.path = []
			a.brain.state = "post"
		if is_instance_valid(a) and a.brain.get("state","") in Waste.MAID_STATES:
			Waste.interrupt(self,a)
			a.path = []
			a.brain.state = "post"
	for d in dirt.duplicate():
		validate_fixture_dirt(d)
		if model.room_at(d.pos).is_empty():
			d.node.queue_free()
			dirt.erase(d)
	for c in clients.duplicate():
		if not is_instance_valid(c): continue
		Sanitation.forget(self,c)
		if c.brain.has("service"): end_service(c,true)
		c.path = []
		release(c)
		c.brain.timer = 0.0
		if c.brain.get("paid",true):
			c.brain.state = "choose"
		else:
			# not paid yet: back in the line outside
			if not c in queue: queue.append(c)
			c.brain.state = "to_queue"
			c.brain.slot = -1

func find_entrance() -> void:
	entrance = {}
	var best_score = -1
	for key in model.openings:
		if model.openings[key] != "door": continue
		var parts = key.split(":")
		var axis = parts[0]
		var x = int(parts[1])
		var z = int(parts[2])
		var pos_room = model.room_at(Vector2(x+0.5,z+0.5))
		var neg_room = model.room_at(Vector2(x+0.5,z-0.5)) if axis == "x" else model.room_at(Vector2(x-0.5,z+0.5))
		if not pos_room.is_empty() and not neg_room.is_empty(): continue
		if pos_room.is_empty() and neg_room.is_empty(): continue
		var room = pos_room if not pos_room.is_empty() else neg_room
		if SitePlan.building(room): continue
		var score = 10 if int(room.type) == 5 else (5 if int(room.type) == 0 else 1)
		if score <= best_score: continue
		var door = Vector2(x+0.5,z) if axis == "x" else Vector2(x,z+0.5)
		var outward = Vector2(0,1) if axis == "x" else Vector2(1,0)
		if not pos_room.is_empty(): outward = -outward
		var along = Vector2(1,0) if axis == "x" else Vector2(0,1)
		best_score = score
		entrance = {"door":door,"outside":door+outward*1.2,"inside":door-outward*1.1,"street":Vector2(door.x+7.0,9.25),"street2":Vector2(door.x-7.0,9.25),"room":room,"outward":outward,"along":along}

func sync_staff() -> void:
	var seen: Dictionary = {}
	for item in model.furniture:
		if item.get("delivery_pending",false): continue
		if not Catalog.is_character(item.kind): continue
		var id = int(item.id)
		var profile = profiles.ensure_employee(item,day)
		seen[id] = true
		var a: Actor = staff.get(id)
		if a == null or not is_instance_valid(a):
			a = Actor.new()
			a.item_id = id
			a.kind = item.kind
			a.configure(item.appearance)
			a.set_world(Vector2(item.x,item.z))
			a.face(Catalog.direction_to_world(item,Vector2(0,1)))
			a.brain = {"role":Catalog.ROLES.get(item.kind,"escort"),"state":"post","timer":0.0,"post":Vector2(item.x,item.z)}
			staff[id] = a
			view.add_actor(a)
		else:
			# an escort in her lingerie keeps it on; her own clothes come back after
			if a.brain.get("dressed") is Dictionary: a.brain.dressed = item.appearance
			elif not a.brain.has("change") and a.appearance != item.appearance: a.configure(item.appearance)
			var post = Vector2(item.x,item.z)
			if a.brain.get("post",post) != post:
				release(a)
				a.path = []
				a.set_world(post)
				a.lift = 0
				a.play("idle")
				a.face(Catalog.direction_to_world(item,Vector2(0,1)))
				a.brain.state = "post"
			a.brain.post = post
			a.kind = item.kind
		a.brain.profile_id = profile.id
		a.brain.name = profile.name
		# what the candidate brought: speed, quality of work, wage
		var skills = Recruits.stats(item)
		a.brain.speed = skills.speed
		a.brain.quality = skills.quality
		a.brain.wage = skills.wage
		a.speed = 1.7*sqrt(skills.speed)
	for id in staff.keys():
		if not seen.has(id):
			var a = staff[id]
			if is_instance_valid(a):
				release(a)
				release_dirt_task(a)
				view.remove_actor(a)
			staff.erase(id)

# ------------------------------------------------------------------ spots

func all_spots() -> Array:
	var out: Array = []
	for item in model.furniture:
		if item.get("delivery_pending",false): continue
		if Catalog.ITEMS[item.kind].has("spots"): out.append_array(Catalog.spots(item))
	return out

func spot_key(s: Dictionary) -> String:
	return "%d:%d" % [s.item,s.index]

func free_spots(use: String, who: String, room_types: Array = []) -> Array:
	var out: Array = []
	for s in all_spots():
		if s.use != use: continue
		if s.who != who and s.who != "any" and not (who == "client" and s.who == "any"): continue
		if reserved.has(spot_key(s)): continue
		if not room_types.is_empty():
			var room = model.room_at(s.pos)
			if room.is_empty() or not int(room.type) in room_types: continue
		out.append(s)
	return out

func reserve(actor: Actor, s: Dictionary) -> void:
	release(actor)
	reserved[spot_key(s)] = actor
	actor.brain.spot = s

func release(actor: Actor) -> void:
	if not actor.has_method("step"): return
	var s = actor.brain.get("spot")
	if s is Dictionary and reserved.get(spot_key(s)) == actor: reserved.erase(spot_key(s))
	actor.brain.erase("spot")

func go(actor: Actor, target: Vector2, exact: bool = true) -> bool:
	# Someone called away from a shower still leaves through its door.
	var from = actor.world
	var lead: Array = []
	var w = actor.brain.get("wash")
	if w is Dictionary:
		view.set_shower_door(int(w.id),true,0.5)
		actor.brain.erase("wash")
	var sh = shower_under(from)
	if not sh.is_empty():
		var door = Catalog.local_to_world(sh,SHOWER_DOOR)
		lead = [door]
		from = door
		actor.visible = true
		view.set_shower_door(int(sh.id),true,0.5,true)
	var p = nav.path(from,target,exact)
	if p.is_empty(): return false
	actor.path = lead+p
	actor.lift = 0
	return true

func go_spot(actor: Actor, s: Dictionary) -> bool:
	reserve(actor,s)
	# a shower is walked up to from the front of its door (see shower_step)
	if not go(actor,s.door if s.has("door") else s.pos):
		release(actor)
		return false
	return true

const SHOWER_DOOR = Vector2(0,0.8)

func shower_under(p: Vector2) -> Dictionary:
	for item in model.furniture:
		if item.get("delivery_pending",false): continue
		if item.kind == "shower" and model.item_rect(item).has_point(p): return item
	return {}

func shower_step(a: Actor, arrived: bool, gm: float) -> bool:
	# In and out of a shower through its glass door only: the door swings open,
	# step in, it shuts; wash out of sight; it opens, step out, it shuts.
	# Returns true once back in front of the door.
	var s = a.brain.get("spot")
	if not s is Dictionary or not s.has("door"): return true
	var id = int(s.item)
	if not a.brain.has("wash"): a.brain.wash = {"id":id,"phase":"door","t":0.0}
	var w: Dictionary = a.brain.wash
	match w.phase:
		"door":
			a.face(s.pos-a.world)
			a.play("idle")
			view.set_shower_door(id,true)
			w.phase = "opening"
		"opening":
			if view.shower_door_open(id):
				a.path = [s.pos]
				w.phase = "in"
		"in":
			if arrived:
				a.face(s.door-s.pos)
				a.play("idle")
				view.set_shower_door(id,false)
				w.phase = "closing"
		"closing":
			if view.shower_door_shut(id):
				a.visible = false
				view.puff(s.pos,"wash",2.5)
				w.t = rng.randf_range(3.0,5.0)
				w.phase = "wash"
		"wash":
			w.t = float(w.t)-gm
			if w.t <= 0:
				a.visible = true
				view.set_shower_door(id,true)
				w.phase = "out_opening"
		"out_opening":
			if view.shower_door_open(id):
				a.path = [s.door]
				w.phase = "out"
		"out":
			if arrived:
				view.set_shower_door(id,false)
				a.brain.erase("wash")
				var fixture = model.item_by_id(id)
				if not fixture.is_empty():
					Sanitation.soil(fixture,10)
					Plumbing.after_use(self,fixture)
				return true
	return false

func settle(actor: Actor) -> void:
	# Arrived on a spot: sit, stand or work facing the right way.
	var s = actor.brain.get("spot")
	if not s is Dictionary: return
	actor.set_world(s.pos)
	actor.lift = int(s.lift)
	actor.set_world(s.pos)
	actor.face(s.face)
	match s.use:
		"sit": actor.play("sit")
		"quick": actor.play("stand")
		"dance": actor.play("dance")
		"work": actor.play("work")
		_: actor.play("idle")

# ------------------------------------------------------------------ time

func clock_text() -> String:
	return ClubCalendar.time_text(int(minute))

func staff_planned(a: Actor) -> bool:
	var item = model.item_by_id(a.item_id)
	return not item.is_empty() and ClubCalendar.covers(item.get("work_schedule",ClubCalendar.default_shift()),day,minute)

func staff_committed(a: Actor) -> bool:
	# Finish an actual task already underway, then stop before taking another.
	return a.brain.has("client") or a.brain.state in ["mopping","cleaning_fixture","repairing","clearing","making_bed"]+Waste.MAID_STATES

func staff_available(a: Actor) -> bool:
	return is_instance_valid(a) and staff_planned(a) and a.brain.get("state","") != "off_shift"

func reconcile_staff(a: Actor) -> bool:
	var planned = staff_planned(a)
	if not planned and staff_committed(a):
		a.brain.overtime = true
		return true
	a.brain.overtime = false
	if not planned:
		if a.brain.state != "off_shift":
			release(a)
			release_dirt_task(a)
			release_debris(a)
			release_bed_task(a)
			Waste.interrupt(self,a)
			dress_now(a)
			a.path = []
			a.lift = 0
			a.set_world(a.brain.post)
			a.play("idle")
			a.brain.state = "off_shift"
		a.visible = false
		return false
	if a.brain.state == "off_shift":
		a.visible = true
		a.brain.state = "post"
		a.set_world(a.brain.post)
		a.play("idle")
	return true

func refresh_schedule_state() -> void:
	if opening_hours.enabled:
		var expected = ClubCalendar.covers(opening_hours,day,minute)
		if opening_override >= 0 and expected != override_window: opening_override = -1
		var wanted = expected if opening_override < 0 else opening_override == 1
		if open != wanted: set_open(wanted,false)
	for a in staff.values():
		if is_instance_valid(a): reconcile_staff(a)

func set_opening_hours(schedule: Dictionary) -> void:
	if not ClubCalendar.valid(schedule,true): return
	opening_hours = ClubCalendar.normalized(schedule)
	opening_override = -1
	refresh_schedule_state()
	stats_changed.emit()

func next_clock_step(remaining: float) -> float:
	var step = minf(remaining,60.0-fposmod(minute,60.0))
	step = minf(step,weather_remaining)
	var schedules: Array = [opening_hours]
	for item in model.furniture:
		if Catalog.is_character(item.kind): schedules.append(item.get("work_schedule",ClubCalendar.default_shift()))
	for schedule in schedules:
		for key in ["start","end"]:
			var until = float(schedule[key])-minute
			if until > .00001: step = minf(step,until)
	return maxf(.00001,step)

func weather_tick(minutes: float) -> void:
	weather_remaining -= minutes
	if weather_remaining <= .00001:
		# Short occasional showers, separated by long dry spells.
		if rain_strength > 0:
			rain_strength = 0.0
			weather_remaining = weather_rng.randf_range(360,720)
		elif weather_rng.randf() < .15:
			rain_strength = weather_rng.randf_range(.4,.9)
			weather_remaining = weather_rng.randf_range(30,90)
		else:
			weather_remaining = weather_rng.randf_range(180,360)

func accrue_wages(minutes: float) -> void:
	var total = 0.0
	for a in staff.values():
		if is_instance_valid(a) and a.brain.state != "off_shift":
			total += float(a.brain.get("wage",Catalog.ITEMS[a.kind].get("wage",0)))*minutes/60.0
	wage_remainder += total
	var amount = floori(wage_remainder+.0000001)
	wage_remainder = maxf(0,wage_remainder-amount)
	money -= amount
	night.wages += amount

func record_calendar_day() -> void:
	var report = night.duplicate(true)
	var avg = satisfaction()
	if not night.satisfaction.is_empty():
		avg = 0.0
		for value in night.satisfaction: avg += float(value)
		avg /= night.satisfaction.size()
	report.satisfaction = int(round(avg))
	report.rating = rating
	report.income = int(night.entry)+int(night.bar)+int(night.dance)+int(night.private)
	report.net = report.income-int(night.wages)
	report.money = money
	history.append(report)
	if history.size() > 14: history.pop_front()

func _process(delta: float) -> void:
	var p0 = Prof.t("sim")
	_timed_process(delta)
	Prof.add("sim",p0)

func _timed_process(delta: float) -> void:
	# only the engine's frames are capped; a deliberate jump of time (tests,
	# skipping ahead) is simulated in full
	if is_equal_approx(delta,get_process_delta_time()): delta = minf(delta,MAX_FRAME)
	if not active or paused_for_report or speed == 0: return
	var remaining = delta*speed*MINUTES_PER_SECOND
	while remaining > .00001:
		refresh_schedule_state()
		var gm = minf(1.0,next_clock_step(remaining))
		var dt = gm/MINUTES_PER_SECOND
		traffic.observe(day,minute,gm,open,inside_count(),admission.capacity,queue.size(),rain_strength)
		accrue_wages(gm)
		view.step_shower_doors(dt)
		elapsed += gm
		Plumbing.tick(self,gm)
		if open and FEATURES.reception: queue_hint(gm)
		if open and not closing:
			spawn_timer = minf(spawn_timer,60.0/maxf(demand_factors().per_hour,.2)*1.3)
			spawn_timer -= gm
			while spawn_timer <= 0:
				spawn_timer += spawn_interval()
				spawn_client()
		for a in staff.values():
			if is_instance_valid(a): staff_ai(a,dt)
		for c in clients.duplicate():
			if is_instance_valid(c): client_ai(c,dt)
		for c in clients:
			if is_instance_valid(c): RainUmbrella.update_actor(self,c)
		view.rain.step(dt,rain_strength)
		weather_tick(gm)
		minute += gm
		if minute >= DAY_MINUTES-.00001:
			record_calendar_day()
			minute = maxf(0,minute-DAY_MINUTES)
			day += 1
			reset_night()
		remaining -= gm
	refresh_schedule_state()
	stats_changed.emit()

func hour_of_day() -> float:
	return minute/60.0

func set_open(value: bool, manual: bool = true) -> void:
	if manual and opening_hours.enabled:
		opening_override = 1 if value else 0
		override_window = ClubCalendar.covers(opening_hours,day,minute)
	open = value
	closing = not open
	spawn_timer = 1.0
	if not open:
		for c in clients.duplicate():
			if is_instance_valid(c) and not c.brain.state in ["leave","to_cloak_out","cloak_out"]: leave(c)
	open_changed.emit(open)
	stats_changed.emit()

func demand_factors() -> Dictionary:
	return ClubDemand.factors(rating,day,hour_of_day(),rain_strength,prices)

func spawn_interval() -> float:
	var factors = demand_factors()
	var interval = clampf(60.0/maxf(factors.per_hour,.2),.6,240.0)
	return interval*rng.randf_range(.7,1.3)

func demand_text() -> String:
	var factors = demand_factors()
	var level = "Faible" if factors.rate < .4 else ("Modérée" if factors.rate < .9 else ("Forte" if factors.rate < 1.6 else "Très forte"))
	return "Affluence : "+level+" · "+("Pluie" if rain_strength > 0 else "Temps sec")

func free_capacity() -> int:
	var n = 0
	for s in all_spots():
		if s.who in ["client","any"]: n += 1
	return n

func pay_wages_hour() -> void:
	accrue_wages(60.0)

func earn(amount: int, category: String, actor: Actor = null) -> void:
	if actor != null and actor.kind == "client": profiles.spend(actor,amount)
	money += amount
	night[category] = int(night.get(category,0))+amount
	if actor != null: actor.emote("dollar",2.0)

func end_night() -> void:
	for c in clients.duplicate(): remove_client(c)
	var sats: Array = night.satisfaction
	var avg = 0.0
	for s in sats: avg += s
	avg = avg/sats.size() if not sats.is_empty() else satisfaction()
	var old = rating
	rating = clampf(lerpf(rating,avg/20.0,0.35),0.5,5.0)
	var report = night.duplicate(true)
	report.satisfaction = int(round(avg))
	report.rating_before = old
	report.rating = rating
	report.income = int(night.entry)+int(night.bar)+int(night.dance)+int(night.private)
	report.net = report.income-int(night.wages)
	report.money = money
	history.append(report.duplicate())
	if history.size() > 14: history.pop_front()
	for a in staff.values():
		if is_instance_valid(a): release_dirt_task(a)
	for d in dirt: d.node.queue_free()
	dirt.clear()
	paused_for_report = true
	night_over.emit(report)

func start_next_night() -> void:
	day += 1
	minute = 1200.0
	last_hour = -1
	closing = false
	paused_for_report = false
	reset_night()
	night.day = day
	for id in staff:
		var a = staff[id]
		if is_instance_valid(a):
			release(a)
			a.path = []
			a.lift = 0
			a.set_world(a.brain.post)
			a.play("idle")
			a.brain.state = "post"
	stats_changed.emit()

# ------------------------------------------------------------------ stats for the HUD

func satisfaction() -> float:
	var vals: Array = []
	for c in clients:
		if is_instance_valid(c): vals.append(c.brain.sat)
	vals.append_array(recent_satisfaction)
	if vals.is_empty(): return clampf(rating*20.0,0,100)
	var s = 0.0
	for v in vals: s += v
	return s/vals.size()

func beds() -> Vector2i:
	var total = 0
	var used = 0
	for item in model.furniture:
		if item.get("delivery_pending",false): continue
		if item.kind != "bed": continue
		total += 1
		for k in reserved:
			if k.begins_with("%d:" % int(item.id)):
				used += 1
				break
	return Vector2i(used,total)

func client_count() -> int:
	return clients.size()

# ------------------------------------------------------------------ dirt

func add_dirt(p: Vector2, kind: String = "water", amount: float = 1.0) -> void:
	if model.room_at(p).is_empty(): return
	var c = nav.free_cell_near(p)
	if c.x == 9999: return
	for d in dirt:
		if d.kind == kind and int(d.get("fixture",-1)) < 0 and nav.cell_of(d.pos) == c:
			d.load = minf(3,float(d.get("load",1))+amount)
			d.work = minf(60,float(d.get("work",6))+6*amount)
			refresh_dirt(d)
			return
	if dirt.size() < Plumbing.MAX_PUDDLES: place_dirt(nav.center(c),kind,amount,6*amount)

func add_fixture_dirt(item: Dictionary, amount: float) -> void:
	var spot = Plumbing.service_spot(item)
	if spot.is_empty(): return
	var cell = nav.free_cell_near(spot.pos)
	if cell.x == 9999 or model.room_at(nav.center(cell)) != model.room_at(Vector2(item.x,item.z)): return
	var spills = Sanitation.fixture_spills(self,item)
	if not spills.is_empty():
		var d: Dictionary = spills[0]
		d.load = minf(3,float(d.load)+amount)
		d.work = minf(60,float(d.work)+6*amount)
		refresh_dirt(d)
		return
	if dirt.size() >= Plumbing.MAX_PUDDLES: return
	place_dirt(nav.center(cell),"urine",amount,6*amount)
	var d: Dictionary = dirt.back()
	d.fixture = int(item.id)
	d.origin = Vector2(item.x,item.z)
	refresh_dirt(d)

func validate_fixture_dirt(d: Dictionary) -> void:
	if int(d.get("fixture",-1)) < 0: return
	var item = model.item_by_id(int(d.fixture))
	# Moving/selling the fixture leaves its old spill as ordinary floor cleaning.
	if item.is_empty() or not item.kind in ClientNeeds.FIXTURES or Vector2(item.x,item.z) != d.get("origin",Vector2.INF):
		d.erase("fixture")
		d.erase("origin")
	refresh_dirt(d)

func place_dirt(pos: Vector2, kind: String, amount: float = 1.0, work: float = 6.0) -> void:
	var s = Sprite2D.new()
	s.position = Iso.pixel(pos.x,pos.y)
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	view.dirt_layer.add_child(s)
	var d = {"pos":pos,"kind":kind,"node":s,"taken":null,"load":amount,"work":work}
	dirt.append(d)
	refresh_dirt(d)

func refresh_dirt(d: Dictionary) -> void:
	var at: Vector2 = d.pos
	if int(d.get("fixture",-1)) >= 0:
		# Draw under the base; retain the reachable service position for pathfinding.
		at = d.origin.lerp(d.pos,.65)
	d.node.position = Iso.pixel(at.x,at.y).round()
	var level = 0 if float(d.get("load",1)) < .6 else (1 if float(d.get("load",1)) < 2 else 2)
	d.node.texture = Art.tex(Art.sanitary.puddles[d.kind][level])

func restore_dirt() -> void:
	for a in staff.values():
		if is_instance_valid(a): release_dirt_task(a)
	for d in dirt: d.node.queue_free()
	dirt.clear()
	for d in saved_dirt:
		var pos = Vector2(d.x,d.z)
		if not model.room_at(pos).is_empty():
			place_dirt(pos,d.kind,d.get("load",1.0),d.get("work",6.0))
			if d.has("fixture"):
				dirt.back().merge({"fixture":d.fixture,"origin":d.origin})
				validate_fixture_dirt(dirt.back())
	saved_dirt.clear()

func dirt_near(p: Vector2, radius: float) -> int:
	var n = 0
	for d in dirt:
		if d.pos.distance_to(p) < radius and model.room_at(p) == model.room_at(d.pos): n += 1
	return n

# ------------------------------------------------------------------ clients

func spawn_client() -> void:
	traffic.count(day,minute,"attempts")
	if entrance.is_empty() or clients.size() >= ClubAdmission.ACTOR_LIMIT or (FEATURES.reception and queue.size() >= admission.slots.size()):
		traffic.count(day,minute,"balked")
		return
	var start: Vector2 = entrance.street if rng.randf() < 0.5 else entrance.street2
	if not nav.reachable(start,entrance.outside):
		traffic.count(day,minute,"balked")
		return
	var active_ids: Array = clients.map(func(c): return str(c.brain.get("profile_id","")))
	var profile = profiles.select_client(active_ids,day,hour_of_day())
	if profile.is_empty(): profile = profiles.make_client(Characters.random_client(rng),day,active_ids)
	if profile.is_empty(): profile = profiles.select_client(active_ids,day,hour_of_day(),true)
	if profile.is_empty():
		traffic.count(day,minute,"balked")
		return
	profiles.arrive(profile,day)
	var a = Actor.new()
	a.kind = "client"
	a.configure(profile.appearance)
	a.set_world(start)
	a.speed = rng.randf_range(1.2,1.6)
	a.brain = {"role":"client","state":"enter","timer":0.0,"sat":clampf(35.0+rating*9.0+rng.randf_range(-8,8),10,95),
		"name":profile.name,"profile_id":profile.id,"preference":profile.preference,"cleanliness":profile.cleanliness,"visits":0,"plan":rng.randi_range(2,4),"waited":0.0,"spent":0,"activity":"enter",
		"patience":profile.patience,"paid":not FEATURES.reception,"slot":-1,"grumble":0.0,
		"budget":int(profile.budget_base+rating*90.0),"refused":[],
		"generous":profile.generous,
		"bladder":rng.randf_range(12.0,28.0),"digestion":0.0,"drinks":0,"coat":Cloakroom.has_coat(self)}
	clients.append(a)
	traffic.count(day,minute,"arrivals")
	view.add_actor(a)
	night.clients += 1
	if FEATURES.reception:
		# nobody gets in before paying at the desk: join the line outside
		queue.append(a)
		a.brain.state = "to_queue"
		a.brain.activity = "queue"
		walk_to_slot(a)
	else:
		profiles.admit(a,day)
		go(a,entrance.outside)

func remove_client(a: Actor) -> void:
	profiles.finish(a,day)
	Sanitation.forget(self,a)
	if a.brain.has("service"): end_service(a,true)
	release(a)
	queue.erase(a)
	if a.brain.has("escort"):
		var e = a.brain.escort
		if is_instance_valid(e) and e.brain.get("client") == a: drop_client(e)
	clients.erase(a)
	Cloakroom.forget(self,a)
	recent_satisfaction.append(a.brain.sat)
	if recent_satisfaction.size() > 12: recent_satisfaction.pop_front()
	night.satisfaction.append(a.brain.sat)
	if not FEATURES.night_cycle: rating = clampf(lerpf(rating,a.brain.sat/20.0,0.06),0.5,5.0)
	view.remove_actor(a)

func client_ai(a: Actor, dt: float) -> void:
	var b: Dictionary = a.brain
	var arrived = a.step(dt,1.0)
	var gm = dt*MINUTES_PER_SECOND
	if FEATURES.toilets and ClientNeeds.tick(self,a,gm,arrived): return
	if Cloakroom.tick(self,a,arrived,gm): return
	if Waste.tick(self,a,arrived,gm): return
	match b.state:
		"enter":
			if arrived:
				if go(a,entrance.inside):
					b.state = "entering"
					b.activity = "entering"
				else: b.state = "choose"
		"entering":
			if arrived:
				profiles.admit(a,day)
				earn(int(prices.entry),"entry",a)
				b.spent += int(prices.entry)
				b.state = "choose"
		"to_queue", "queue":
			wait_in_line(a,arrived,gm)
		"to_desk":
			if arrived:
				settle(a)
				b.state = "checkin"
				b.timer = rng.randf_range(2.0,4.0)
		"checkin":
			# The entrance is paid to the receptionist in person.
			if receptionist_at(int(b.get("desk",-1))) != null:
				var desk_staff = receptionist_at(int(b.desk))
				b.timer -= gm/profiles.employee_factor(str(desk_staff.brain.get("profile_id","")))*float(desk_staff.brain.get("speed",1.0))
				if b.timer <= 0:
					earn(int(prices.entry),"entry",a)
					b.spent += int(prices.entry)
					b.paid = true
					profiles.admit(a,day)
					traffic.admitted(day,minute,float(b.waited))
					b.sat += profiles.welcome_bonus(str(desk_staff.brain.get("profile_id","")))
					# a warm welcome pleases, a sullen one does not
					b.sat += (float(desk_staff.brain.get("quality",1.0))-1.0)*10.0
					b.sat += 2.0*security_presence()
					release(a)
					b.state = "choose"
			else:
				impatience(a,gm)
		"choose":
			# something to throw away first, a coat to the cloakroom first
			if not Waste.dispose(self,a) and not Cloakroom.deposit(self,a): choose_activity(a)
		"walk":
			if arrived:
				settle(a)
				b.state = "busy"
				start_activity(a)
		"busy":
			b.timer -= gm
			activity_tick(a,gm)
			# an escort is coming over or talking: he stays for the conversation
			var talking = b.has("escort") and is_instance_valid(b.escort) and b.escort.brain.state in ["approach","chat"]
			if b.timer <= 0 and not talking:
				finish_activity(a)
		"to_shower", "showering", "to_bed", "wait_partner", "in_service":
			client_service(a,arrived,gm)
		"leave":
			if arrived:
				if a.world.distance_to(b.get("exit",a.world)) < 0.2 or a.path.is_empty():
					remove_client(a)
	b.sat = clampf(b.sat,0,100)

func inside_count() -> int:
	# Clients who paid their way in (those still in line or turned away are outside).
	var n = 0
	for c in clients:
		if is_instance_valid(c) and c.brain.get("paid",true) and not model.room_at(c.world).is_empty(): n += 1
	return n

func queue_slot(i: int) -> Vector2:
	# The line starts at the door on the red carpet, steps out onto the
	# pavement, then runs along the facade past the bins (the sign stands on
	# the other side of the door).
	return admission.slots[clampi(i,0,admission.slots.size()-1)] if not admission.slots.is_empty() else entrance.outside

func walk_to_slot(a: Actor) -> void:
	var i = queue.find(a)
	if i < 0 or entrance.is_empty(): return
	a.brain.slot = i
	a.brain.state = "to_queue"
	if not go(a,queue_slot(i)): a.path = []

func wait_in_line(a: Actor, arrived: bool, gm: float) -> void:
	var b = a.brain
	var i = queue.find(a)
	if i < 0:
		queue.append(a)
		i = queue.size()-1
	if int(b.get("slot",-1)) != i:
		walk_to_slot(a)
	elif b.state == "to_queue" and a.path.is_empty():
		b.state = "queue"
		b.reached = true
		a.face(entrance.door-a.world if i == 0 else queue_slot(i-1)-a.world)
		a.play("idle")
	if i == 0 and b.state == "queue" and admission.can_enter(self):
		# At the head of the line: in as soon as a receptionist can take the entrance.
		var desk = free_desk()
		if not desk.is_empty() and go_spot(a,desk):
			queue.erase(a)
			b.desk = int(desk.item)
			b.state = "to_desk"
			b.activity = "checkin"
			for c in queue: walk_to_slot(c)
			return
	# the wait starts once in the line, not on the way from the street
	if b.get("reached",false): impatience(a,gm)

func impatience(a: Actor, gm: float) -> void:
	# Waiting sours the mood; past their patience clients walk away.
	var b = a.brain
	b.waited += gm
	if b.waited > 4.0: b.sat -= 0.3*gm
	b.grumble = float(b.get("grumble",0.0))-gm
	if b.waited > b.patience*0.5 and b.grumble <= 0:
		b.grumble = rng.randf_range(6.0,10.0)
		a.emote("help",2.0)
	if b.waited > b.patience:
		if b.get("queue_abandoned",false): return
		b.queue_abandoned = true
		traffic.count(day,minute,"abandoned")
		profiles.remember(str(b.get("profile_id","")),day,"Quitte la file après %.0f min d'attente." % float(b.waited))
		b.sat -= 12
		night.impatient = int(night.get("impatient",0))+1
		leave(a)

func free_desk() -> Dictionary:
	# The client place of a reception desk whose receptionist is at her post.
	for s in all_spots():
		if s.use != "stand" or s.who != "client" or reserved.has(spot_key(s)): continue
		if model.item_by_id(s.item).get("kind","") != "reception": continue
		if receptionist_at(int(s.item)) != null: return s
	return {}

func receptionist_at(desk_id: int) -> Actor:
	for id in staff:
		var r = staff[id]
		if staff_available(r) and r.brain.role == "receptionist" and r.brain.state == "working" and int(r.brain.get("desk",-1)) == desk_id: return r
	return null

func queue_hint(gm: float) -> void:
	# Tell the player why the line does not move.
	queue_notice -= gm
	if queue.size() < 2 or queue_notice > 0: return
	queue_notice = 90.0
	if not admission.can_enter(self):
		notice.emit("Club complet : %d clients attendent dehors. Agrandissez l'espace public ou adaptez votre équipe aux heures de pointe." % queue.size())
	elif not model.furniture.any(func(i): return not i.get("delivery_pending",false) and i.kind == "reception"):
		notice.emit("Des clients font la queue dehors : installez un comptoir d'accueil (Mobilier) et embauchez un(e) réceptionniste.")
	elif free_desk().is_empty() and not staff.values().any(func(r): return staff_available(r) and r.brain.role == "receptionist" and r.brain.state == "working"):
		notice.emit("Des clients font la queue dehors : personne n'est à l'accueil pour encaisser l'entrée.")

func security_presence() -> float:
	# 0 without a guard at his post, else how reassuring the best one is
	var best = 0.0
	for id in staff:
		var a = staff[id]
		if staff_available(a) and a.brain.role == "security" and a.brain.state in ["working","post"] and not a.moving: best = maxf(best,float(a.brain.get("quality",1.0)))
	return best

func role_present(role: String) -> bool:
	for id in staff:
		var a = staff[id]
		if staff_available(a) and a.brain.role == role and a.brain.state in ["working","post"] and not a.moving: return true
	return false

func leave(a: Actor) -> void:
	Sanitation.forget(self,a)
	if a.brain.has("service"): end_service(a,true)
	if a.brain.has("escort"):
		var e = a.brain.escort
		if is_instance_valid(e) and e.brain.get("client") == a: drop_client(e)
		a.brain.erase("escort")
	a.visible = true
	release(a)
	queue.erase(a)
	var b = a.brain
	b.state = "leave"
	b.activity = "leave"
	if entrance.is_empty():
		remove_client(a)
		return
	# his coat first, if he left one
	if Cloakroom.collect(self,a): return
	head_out(a)

func head_out(a: Actor) -> void:
	var b = a.brain
	b.state = "leave"
	b.activity = "leave"
	if entrance.is_empty():
		remove_client(a)
		return
	var exit: Vector2 = entrance.street if rng.randf() < 0.5 else entrance.street2
	b.exit = exit
	if not go(a,exit): remove_client(a)

func choose_activity(a: Actor) -> void:
	var b = a.brain
	if closing or b.visits >= b.plan or b.sat < 18:
		leave(a)
		return
	var options: Array = []
	if FEATURES.bar:
		var bar_spots = free_spots("sit","client",[0]).filter(func(s): return model.item_by_id(s.item).kind == "stool")
		bar_spots.append_array(free_spots("stand","client",[0]).filter(func(s): return model.item_by_id(s.item).kind == "bar"))
		if not bar_spots.is_empty(): options.append(["bar",4.0 if role_present("bartender") else 1.0,bar_spots])
	var lounge = free_spots("sit","client",[0,5]).filter(func(s): return model.item_by_id(s.item).kind in ["sofa","chair","armchair","old_sofa"])
	if not lounge.is_empty(): options.append(["lounge",3.0,lounge])
	if FEATURES.stage:
		var stage = free_spots("watch","client",[0])
		# a pole show on: the clients flock to the stage
		if not stage.is_empty() and dancing(): options.append(["stage",6.0,stage])
	var floor_spots = free_spots("dance","client",[0,5]).filter(func(s): return model.item_by_id(s.item).kind == "dancefloor")
	# an escort dancing on the floor draws the clients there
	var show = staff.values().any(func(e): return staff_available(e) and e.brain.get("state","") == "floor_dance")
	if not floor_spots.is_empty(): options.append(["dance",4.5 if show else 2.5,floor_spots])
	var spot = look_spot(a)
	if not spot.is_empty(): options.append(["look",2.0,[spot]])
	if options.is_empty():
		b.timer = 0
		b.sat -= 2
		wander(a)
		return
	var total = 0.0
	for o in options:
		if o[0] == b.get("preference",""): o[1] *= 1.7
		total += o[1]
	var pick = rng.randf()*total
	var chosen = options[0]
	for o in options:
		pick -= o[1]
		if pick <= 0:
			chosen = o
			break
	var list: Array = chosen[2]
	list.sort_custom(func(x,y): return x.pos.distance_squared_to(a.world) < y.pos.distance_squared_to(a.world))
	var s = list[mini(rng.randi_range(0,2),list.size()-1)]
	if chosen[0] == "look":
		if not go(a,s.pos):
			b.sat -= 1
			b.state = "choose"
			b.visits += 1
			return
		b.activity = "look"
		b.state = "walk"
		return
	if not go_spot(a,s):
		b.sat -= 1
		wander(a)
		return
	b.activity = chosen[0]
	b.state = "walk"

func look_spot(a: Actor) -> Dictionary:
	# A free place in a public room to stand and look around.
	var rooms = model.rooms.filter(func(r): return int(r.type) in [0,5] and not SitePlan.building(r))
	for attempt in range(6):
		if rooms.is_empty(): return {}
		var r = rooms[rng.randi_range(0,rooms.size()-1)]
		var p = model.random_point(r,rng,0.6)
		var c = nav.free_cell_near(p)
		if c.x != 9999 and nav.room_of.get(c,0) != 0: return {"pos":nav.center(c)}
	return {}

func ambiance(p: Vector2) -> float:
	# How pleasant the room around a point is: decoration and renovation
	# help, debris and worn finishes hurt.
	var room = model.room_at(p)
	if room.is_empty(): return 0.0
	var r = model.shape(room)
	var decor = 0
	var mess = 0.0
	for item in model.furniture:
		if item.get("delivery_pending",false): continue
		if not r.has_point(Vector2(item.x,item.z)): continue
		# a glass or a tissue on the floor spoils a room less than a heap of rubbish
		if Catalog.is_debris(item.kind): mess += 0.5 if Catalog.ITEMS[item.kind].get("litter",false) else 1.0
		elif Catalog.in_shop(item.kind): decor += 1
	var charm = 0.0
	for id in staff:
		var e = staff[id]
		if is_instance_valid(e) and e.brain.get("role","") == "escort" and r.has_point(e.world): charm += 1.5*standing(e)
	var unmade = model.furniture.filter(func(i): return not i.get("delivery_pending",false) and i.kind in BED_KINDS and i.get("unmade",false) and r.has_point(Vector2(i.x,i.z))).size()
	var score = minf(decor*1.5,12.0)-minf(mess*4.0,24.0)+minf(charm,9.0)-4.0*unmade
	if Finishes.is_worn(room): score -= 5.0
	return score

func standing(a: Actor) -> int:
	# 1 débutante .. 4 prestige; other escorts (hostesses) count as 1.
	return int(Characters.STANDINGS.get(a.kind,{}).get("level",1))

func stars() -> int:
	return int(round(rating))

func wander(a: Actor) -> void:
	var room = model.room_at(a.world)
	if room.is_empty():
		a.brain.state = "choose"
		return
	var target = model.random_point(room,rng,0.5)
	go(a,target)
	a.brain.state = "walk"
	a.brain.activity = "walk"

func companion_seat(a: Actor) -> Dictionary:
	# A free seat right next to a client relaxing in the lounge.
	for c in clients:
		if not is_instance_valid(c) or c.brain.activity != "lounge" or c.brain.state != "busy": continue
		var best: Dictionary = {}
		var best_d = 1.7
		for s in free_spots("sit","staff",[0]):
			var d = s.pos.distance_to(c.world)
			if d < best_d and d > 0.2:
				best_d = d
				best = s
		if not best.is_empty(): return best
	return {}

func dancing() -> bool:
	# Someone is on the stage (the pole show), not just on the dance floor.
	for id in staff:
		var e = staff[id]
		if staff_available(e) and e.brain.role == "escort" and e.brain.get("state","") == "dancing": return true
	return false

func free_escort() -> Actor:
	var best: Actor = null
	for id in staff:
		var e = staff[id]
		if staff_available(e) and e.brain.role == "escort" and e.brain.state in ["post","lounge","idle_free","free"] and not e.brain.has("client"):
			best = e
			if e.anim != "dance": return e
	return best

func start_activity(a: Actor) -> void:
	var b = a.brain
	if b.activity == b.get("preference",""): b.sat = minf(100,float(b.sat)+2)
	match b.activity:
		"look":
			b.timer = rng.randf_range(6,14)
			b.sat += 1.0+ambiance(a.world)*0.6
			a.play("idle")
		"bar":
			b.timer = rng.randf_range(15,30)
			var staffed = role_present("bartender")
			# a quick bartender pours a second round more often
			var drinks = 1 if rng.randf() < 1.0-0.4*bartender_speed() else 2
			if staffed:
				earn(int(prices.drink)*drinks,"bar",a)
				b.spent += int(prices.drink)*drinks
				b.sat += 5
				ClientNeeds.drink(a,drinks)
				b.sat += bartender_serve()
			else:
				b.sat -= 10
				a.emote("help",2.0)
			if FEATURES.client_mess and rng.randf() < 0.12: add_dirt(a.world+Vector2(0,0.6))
		"lounge":
			b.timer = rng.randf_range(20,40)
			b.sat += 3+ambiance(a.world)*0.6
		"stage":
			b.timer = rng.randf_range(12,22)
			earn(int(prices.dance),"dance",a)
			b.spent += int(prices.dance)
			b.sat += 6
		"toilet":
			b.timer = rng.randf_range(3,6)
			if FEATURES.client_mess and rng.randf() < 0.35: add_dirt(a.world+Vector2(rng.randf_range(-0.4,0.4),rng.randf_range(-0.2,0.4)))
		"dance":
			b.timer = rng.randf_range(12,22)
			b.sat += 3+ambiance(a.world)*0.5
	b.visits += 1

func activity_tick(a: Actor, gm: float) -> void:
	var b = a.brain
	if b.activity == "dance":
		for id in staff:
			var e = staff[id]
			if staff_available(e) and e.brain.get("state","") == "floor_dance" and e.world.distance_to(a.world) < 2.5:
				b.sat = minf(float(b.sat)+0.3*gm,100.0)
				break

func finish_activity(a: Actor) -> void:
	var b = a.brain
	Waste.pick_up(self,a,String(b.get("activity","")))
	release(a)
	a.lift = 0
	b.state = "choose"

func bartender_serve() -> float:
	for id in staff:
		var s = staff[id]
		if staff_available(s) and s.brain.role == "bartender":
			s.brain.serve = 6.0
			return profiles.welcome_bonus(str(s.brain.get("profile_id","")))+(float(s.brain.get("quality",1.0))-1.0)*10.0
	return 0.0

func bartender_speed() -> float:
	for id in staff:
		var s = staff[id]
		if staff_available(s) and s.brain.role == "bartender": return float(s.brain.get("speed",1.0))
	return 1.0

# ------------------------------------------------------------------ staff

func staff_ai(a: Actor, dt: float) -> void:
	if not reconcile_staff(a): return
	var b: Dictionary = a.brain
	var arrived = a.step(dt,1.0)
	var gm = dt*MINUTES_PER_SECOND
	if not role_active(b.role):
		if arrived: a.play("idle")
		return
	profiles.employee_work(str(b.get("profile_id","")),gm,day)
	if b.role != "cleaner": gm /= profiles.employee_factor(str(b.get("profile_id","")))
	# a quick employee gets through the work sooner (an escort's energy is used apart)
	if b.role != "escort": gm *= float(b.get("speed",1.0))
	match b.role:
		"bartender": work_at(a,arrived,"bar","bartender",gm)
		"receptionist": receptionist_ai(a,arrived,gm)
		"security": security_ai(a,arrived,gm)
		"cleaner": cleaner_ai(a,arrived,gm)
		"escort": escort_ai(a,arrived,gm)

func role_active(role: String) -> bool:
	return role == "cleaner" or FEATURES.staff_roles or FEATURES.get(ROLE_FEATURE.get(role,""),false)

func work_at(a: Actor, arrived: bool, kind: String, who: String, gm: float) -> void:
	var b = a.brain
	match b.state:
		"post", "idle":
			var spots = free_spots("work",who).filter(func(s): return model.item_by_id(s.item).kind == kind)
			spots.sort_custom(func(x,y): return x.pos.distance_squared_to(b.post) < y.pos.distance_squared_to(b.post))
			if not spots.is_empty() and go_spot(a,spots[0]):
				b.state = "to_work"
			else:
				b.state = "idle"
				a.play("idle")
		"to_work":
			if arrived:
				settle(a)
				b.state = "working"
		"working":
			var serve = float(b.get("serve",0.0))
			if serve > 0:
				b.serve = serve-gm
				a.play("work")
			else:
				a.play("idle")

func receptionist_ai(a: Actor, arrived: bool, gm: float) -> void:
	var b = a.brain
	if b.state in ["post","idle"]:
		# Prefer a chair right behind the counter, else stand at the desk.
		var desk: Dictionary = {}
		for s in all_spots():
			if s.use == "work" and s.who == "receptionist" and not reserved.has(spot_key(s)): desk = s
		if desk.is_empty():
			b.state = "idle"
			a.play("idle")
			return
		b.desk = int(desk.item)
		var chair: Dictionary = {}
		for s in free_spots("sit","staff"):
			if model.item_by_id(s.item).kind == "chair" and s.pos.distance_to(desk.pos) < 1.3: chair = s
		if go_spot(a,chair if not chair.is_empty() else desk):
			b.state = "to_work"
	elif b.state == "to_work":
		if arrived:
			settle(a)
			b.state = "working"
	elif b.state == "working":
		if model.item_by_id(int(b.get("desk",-1))).is_empty():
			release(a)
			b.state = "post"
			return
		var busy = false
		for c in clients:
			if is_instance_valid(c) and c.brain.state == "checkin" and int(c.brain.get("desk",-1)) == int(b.desk): busy = true
		var s = b.get("spot",{})
		if s is Dictionary and s.get("use","") == "sit":
			a.play("sit")
		else:
			a.play("work" if busy else "idle")

func security_ai(a: Actor, arrived: bool, gm: float) -> void:
	var b = a.brain
	b.timer = float(b.get("timer",0.0))-gm
	match b.state:
		"post":
			if arrived:
				a.play("idle")
				if not entrance.is_empty(): a.face(entrance.door-a.world)
			if b.timer <= 0:
				b.timer = rng.randf_range(50,90)
				var room = model.room_at(b.post)
				var rooms = model.rooms.filter(func(r): return int(r.type) in [0,5] and not SitePlan.building(r))
				if not rooms.is_empty():
					var r = rooms[rng.randi_range(0,rooms.size()-1)]
					if go(a,model.random_point(r,rng,0.6)): b.state = "patrol"
		"patrol":
			if arrived:
				b.state = "return"
				b.timer = rng.randf_range(4,8)
				a.play("idle")
		"return":
			if b.timer <= 0 and a.path.is_empty():
				if go(a,b.post): b.state = "post"
				else: b.state = "post"

func next_debris(a: Actor) -> Dictionary:
	# Debris flagged as a priority first, then the nearest one.
	var best: Dictionary = {}
	var best_d = 1e12
	for item in model.furniture:
		if item.get("delivery_pending",false): continue
		if not Catalog.is_debris(item.kind): continue
		if room_private(model.room_at(Vector2(item.x,item.z))): continue
		var owner = debris_taken.get(int(item.id))
		if owner != null and is_instance_valid(owner) and owner != a: continue
		var d = Vector2(item.x,item.z).distance_squared_to(a.world)-(10000.0 if item.get("priority",false) else 0.0)
		if d < best_d:
			best_d = d
			best = item
	return best

func room_private(room: Dictionary) -> bool:
	# A couple is in this room (or on its way, or someone is showering there).
	if room.is_empty() or int(room.type) != 1: return false
	var r = model.shape(room)
	for id in busy_beds:
		var bed = model.item_by_id(int(id))
		if not bed.is_empty() and r.has_point(Vector2(bed.x,bed.z)): return true
	for id in staff:
		var e = staff[id]
		if is_instance_valid(e) and e.brain.get("state","") in ["to_shower_after","showering"] and r.has_point(e.world): return true
	return false

func next_bed(a: Actor) -> Dictionary:
	# The nearest unmade bed nobody is using or already making.
	var best: Dictionary = {}
	var best_d = 1e12
	for item in model.furniture:
		if item.get("delivery_pending",false): continue
		if not item.kind in BED_KINDS or not item.get("unmade",false) or busy_beds.has(int(item.id)): continue
		if room_private(model.room_at(Vector2(item.x,item.z))): continue
		var owner = beds_taken.get(int(item.id))
		if owner != null and is_instance_valid(owner) and owner != a: continue
		var d = Vector2(item.x,item.z).distance_squared_to(a.world)
		if d < best_d:
			best_d = d
			best = item
	return best

func bed_side(bed: Dictionary) -> Vector2:
	# Where to stand to make a bed: at its foot.
	var size: Vector2 = Catalog.ITEMS[bed.kind].size
	var p = Catalog.local_to_world(bed,Vector2(0,size.y/2.0+0.35))
	var cell = nav.free_cell_near(p)
	return p if cell.x == 9999 else nav.center(cell)

func release_bed_task(a: Actor) -> void:
	var id = int(a.brain.get("bed_id",-1))
	if beds_taken.get(id) == a: beds_taken.erase(id)
	a.brain.erase("bed_id")

func release_debris(a: Actor) -> void:
	var id = a.brain.get("debris_id",-1)
	if debris_taken.get(id) == a: debris_taken.erase(id)
	a.brain.erase("debris_id")

func release_dirt_task(a: Actor) -> void:
	var d = a.brain.get("dirt")
	if d is Dictionary and d.get("taken") == a: d.taken = null
	a.brain.erase("dirt")

func next_dirt(a: Actor) -> Dictionary:
	var candidates: Array = []
	for d in dirt:
		if int(d.get("fixture",-1)) >= 0: continue
		if is_instance_valid(d.taken) and d.taken != a: continue
		if room_private(model.room_at(d.pos)) or not nav.walkable(d.pos) or not nav.reachable(a.world,d.pos): continue
		candidates.append(d)
	candidates.sort_custom(func(x,y): return x.pos.distance_squared_to(a.world) < y.pos.distance_squared_to(a.world))
	return {} if candidates.is_empty() else candidates[0]

func dirt_approach(a: Actor, spill: Dictionary) -> Vector2:
	var best: Vector2 = spill.pos
	var distance = INF
	for offset in [Vector2(.75,0),Vector2(-.75,0),Vector2(0,.75),Vector2(0,-.75)]:
		var p: Vector2 = spill.pos+offset
		if not nav.walkable(p) or model.room_at(p) != model.room_at(spill.pos) or not nav.reachable(a.world,p): continue
		var d = p.distance_squared_to(a.world)
		if d < distance:
			distance = d
			best = p
	return best

func cleaner_ai(a: Actor, arrived: bool, gm: float) -> void:
	var b = a.brain
	# discretion: out of a room where a couple is, back to her post
	var here = model.room_at(a.world)
	if b.state != "back" and not here.is_empty() and room_private(here):
		release(a)
		release_debris(a)
		release_bed_task(a)
		release_dirt_task(a)
		Waste.interrupt(self,a)
		b.state = "back"
		if not go(a,b.post): b.state = "post"
		return
	if b.state in ["to_dirt","mopping"] and (not b.has("dirt") or not b.dirt in dirt or room_private(model.room_at(b.dirt.pos)) or not nav.reachable(a.world,b.dirt.pos)):
		release_dirt_task(a)
		a.path = []
		b.state = "post"
	# Wet floors take priority over routine debris and bed making.
	if Plumbing.technician_tick(self,a,arrived,gm): return
	if b.state in ["post","idle","back"]:
		var spill = next_dirt(a)
		if not spill.is_empty() and go(a,dirt_approach(a,spill)):
			spill.taken = a
			b.dirt = spill
			b.state = "to_dirt"
			return
	if Sanitation.cleaner_tick(self,a,arrived,gm): return
	# full bins out to the containers by the street
	if Waste.maid_tick(self,a,arrived,gm): return
	match b.state:
		"to_debris":
			if model.item_by_id(int(b.get("debris_id",-1))).is_empty():
				release_debris(a)
				b.state = "post"
			elif arrived:
				var item = model.item_by_id(int(b.debris_id))
				b.state = "clearing"
				b.timer = float(Catalog.ITEMS[item.kind].get("clean",6))*Sanitation.cleaning_factor(self,a)
				a.face(Vector2(item.x,item.z)-a.world)
				a.play("mop")
			return
		"clearing":
			var id = int(b.get("debris_id",-1))
			if model.item_by_id(id).is_empty():
				release_debris(a)
				b.state = "post"
				return
			b.timer -= gm
			a.play("mop")
			if b.timer <= 0:
				release_debris(a)
				b.state = "post"
				a.play("idle")
				debris_cleaned.emit(id)
			return
	match b.state:
		"to_bed_task":
			if model.item_by_id(int(b.get("bed_id",-1))).is_empty() or busy_beds.has(int(b.bed_id)):
				# someone took the bed meanwhile: back to her post, discreetly
				release_bed_task(a)
				b.state = "back"
				if not go(a,b.post): b.state = "post"
			elif arrived:
				var bed = model.item_by_id(int(b.bed_id))
				b.state = "making_bed"
				b.timer = 5.0*Sanitation.cleaning_factor(self,a)
				a.face(Vector2(bed.x,bed.z)-a.world)
				a.play("work")
			return
		"making_bed":
			b.timer -= gm
			a.play("work")
			if b.timer <= 0:
				var bed = model.item_by_id(int(b.get("bed_id",-1)))
				if not bed.is_empty() and not busy_beds.has(int(bed.id)):
					bed.unmade = false
					view.set_bed_look(int(bed.id),"made")
					night.beds_made += 1
				release_bed_task(a)
				b.state = "post"
				a.play("idle")
			return
	if b.state in ["post","idle","back"]:
		# maids make the beds first, technicians pick up the debris first
		var bed_first = a.kind == "maid"
		for pass_bed in ([true,false] if bed_first else [false,true]):
			if pass_bed:
				var bed = next_bed(a)
				if not bed.is_empty() and go(a,bed_side(bed)):
					beds_taken[int(bed.id)] = a
					b.bed_id = int(bed.id)
					b.state = "to_bed_task"
					return
			else:
				var target = next_debris(a)
				if not target.is_empty() and go(a,Vector2(target.x,target.z)):
					debris_taken[int(target.id)] = a
					b.debris_id = int(target.id)
					b.state = "to_debris"
					return
	match b.state:
		"post", "idle":
			if a.path.is_empty():
				a.play("idle")
		"to_dirt":
			if arrived:
				b.state = "mopping"
				b.timer = float(b.dirt.get("work",6.0))*Sanitation.cleaning_factor(self,a)
				a.face(b.dirt.pos-a.world)
				a.play("mop")
		"mopping":
			b.dirt.work = maxf(0,float(b.dirt.get("work",6.0))-gm/Sanitation.cleaning_factor(self,a))
			b.timer = b.dirt.work*Sanitation.cleaning_factor(self,a)
			a.play("mop")
			if b.timer <= 0:
				var d = b.get("dirt")
				if d != null:
					d.node.queue_free()
					dirt.erase(d)
					night.dirt_cleaned = int(night.get("dirt_cleaned",0))+1
				b.erase("dirt")
				b.state = "back"
				if not go(a,b.post): b.state = "post"
		"back":
			if arrived:
				a.play("idle")
				b.state = "post"

func escort_ai(a: Actor, arrived: bool, gm: float) -> void:
	var b = a.brain
	b.timer = float(b.get("timer",0.0))-gm
	b.health = minf(100.0,float(b.get("health",100.0))+gm*2.0/60.0)
	# a twirl into or out of her lingerie: nothing else until it is done
	if outfit_tick(a,gm): return
	if float(b.get("sick",0.0)) > 0.0:
		escort_sick(a,arrived,gm)
		return
	match b.state:
		"post", "free":
			# still in her lingerie (a visit called off): dressed again first
			if b.has("dressed"):
				redress(a)
				return
			# Look for a client to meet first, else keep a seated client
			# company, dance if the stage is free, or wait in the lounge.
			if FEATURES.private and try_approach(a): return
			# the pole show on the stage, where the generous watchers tip
			var stage_spots = free_spots("dance","escort").filter(func(s): return model.item_by_id(s.item).kind == "dance") if FEATURES.stage else []
			if not stage_spots.is_empty() and rng.randf() < 0.5 and go_spot(a,stage_spots[0]):
				b.state = "to_stage"
				return
			# dance on the dance floor, where generous clients tip
			var fs = floor_spot(a)
			if not fs.is_empty() and rng.randf() < 0.45 and go_spot(a,fs):
				b.state = "to_floor"
				return
			var company = companion_seat(a)
			if not company.is_empty() and rng.randf() < 0.55 and go_spot(a,company):
				b.state = "to_lounge"
				return
			var seats = free_spots("sit","staff",[0]).filter(func(s): return model.item_by_id(s.item).kind in ["sofa","armchair","chair","old_sofa","old_armchair"])
			if not seats.is_empty():
				seats.sort_custom(func(x,y): return x.pos.distance_squared_to(a.world) < y.pos.distance_squared_to(a.world))
				if go_spot(a,seats[mini(rng.randi_range(0,2),seats.size()-1)]):
					b.state = "to_lounge"
					return
			b.state = "idle_free"
			b.timer = rng.randf_range(4,8)/float(b.get("speed",1.0))
			a.play("idle")
		"to_stage":
			if arrived:
				settle(a)
				b.state = "dancing"
				b.timer = rng.randf_range(30,50)
		"dancing":
			b.tip_t = float(b.get("tip_t",0.0))-gm
			if b.tip_t <= 0:
				b.tip_t = rng.randf_range(2.0,3.5)
				crowd_tips(a,["stage","bar","lounge","look","dance"],3.6,10,8,"stage_tips",true)
				if FEATURES.private and crowd_date(a,["stage","bar","lounge"],3.6,0.35,"stage_dates",true): return
			if b.timer <= 0:
				release(a)
				a.lift = 0
				b.state = "free"
		"to_lounge":
			if arrived:
				settle(a)
				b.state = "lounge"
				b.timer = rng.randf_range(20,40)
		"lounge":
			b.flirt = float(b.get("flirt",0.0))-gm*float(b.get("speed",1.0))
			if b.flirt <= 0:
				b.flirt = rng.randf_range(3,6)
				# from her seat she keeps an eye out for someone to meet
				if FEATURES.private and try_approach(a): return
				for c in clients:
					if is_instance_valid(c) and c.brain.activity == "lounge" and c.brain.state == "busy" and c.world.distance_to(a.world) < 1.7:
						a.emote("heart",2.2)
						c.emote("heart",2.2)
						# the higher her standing, the happier the client
						c.brain.sat = minf(float(c.brain.sat)+(2.0+2.0*standing(a))*float(b.get("quality",1.0)),100.0)
						break
			if b.timer <= 0:
				release(a)
				a.lift = 0
				b.state = "free"
		"idle_free":
			if b.timer <= 0: b.state = "free"
		"to_floor":
			if arrived:
				settle(a)
				b.state = "floor_dance"
				b.timer = rng.randf_range(14,24)
				b.tip_t = 2.0
		"floor_dance":
			b.tip_t = float(b.get("tip_t",0.0))-gm
			if b.tip_t <= 0:
				b.tip_t = rng.randf_range(2.0,3.5)
				crowd_tips(a,["dance","bar","lounge","look"],3.0,5,5,"")
				if FEATURES.private and crowd_date(a,["dance"],2.5,0.3,"floor_dates"): return
			if b.timer <= 0:
				release(a)
				a.lift = 0
				b.state = "free"
		"approach":
			var c = b.get("client")
			if not partner_ok(a,c):
				drop_client(a)
			elif arrived:
				if b.has("spot"): settle(a)
				else:
					a.play("idle")
					a.face(c.world-a.world)
				# on the dance floor, a generous client asks her upstairs right away
				if c.brain.activity == "dance" and c.brain.get("generous",false):
					night.met += 1
					a.emote("heart",1.8)
					c.emote("heart",1.8)
					release(a)
					a.lift = 0
					if negotiate(a,c,0.3): night.floor_dates = int(night.get("floor_dates",0))+1
					return
				b.state = "chat"
				b.timer = rng.randf_range(3.0,6.0)
				night.met += 1
				a.emote("talk",2.0)
				c.emote("talk",2.0)
		"chat":
			var c = b.get("client")
			if not partner_ok(a,c): drop_client(a)
			elif b.timer <= 0: negotiate(a,c)
		"to_undress", "undressing":
			# in front of the bed she slips into her lingerie, then sits down
			var c = b.get("client")
			if not is_instance_valid(c) or not c.brain.has("service"):
				drop_client(a)
			elif b.state == "to_undress":
				if arrived:
					var bed = model.item_by_id(int(c.brain.service.bed))
					if not bed.is_empty(): a.face(Vector2(bed.x,bed.z)-a.world)
					b.state = "undressing"
					undress(a)
			elif not b.has("change"):
				var s = b.get("spot")
				if s is Dictionary and go(a,s.pos): b.state = "to_bed"
				else:
					settle(a)
					b.state = "wait_partner"
		"to_bed":
			if arrived:
				settle(a)
				b.state = "wait_partner"
		"to_redress":
			if arrived: redress(a)
			if not b.has("dressed") or b.has("change"): b.state = "free"
		"wait_partner", "in_service":
			var c = b.get("client")
			if not is_instance_valid(c) or not c.brain.has("service"):
				a.visible = true
				release(a)
				b.erase("client")
				b.state = "free"
		"to_shower_after":
			if arrived:
				b.state = "showering"
				shower_step(a,true,gm)
		"showering":
			if shower_step(a,arrived,gm):
				release(a)
				night.showers += 1
				b.state = "free"
				# out of the shower, she gets dressed again
				redress(a)
				roll_escort(a,float(b.get("risk",0.0)))

# ------------------------------------------------------------------ encounters

const SERVICES = [
	{"key":"quick","name":"Prestation rapide","price":80,"minutes":20},
	{"key":"classic","name":"Prestation classique","price":150,"minutes":26},
	{"key":"full","name":"Prestation complète","price":260,"minutes":40}]
# Price factor by standing (1 débutante .. 4 prestige).
const STANDING_RATE = [1.0,1.0,1.3,1.7,2.2]
# Furniture where people cross paths in the public room.
const SOCIAL_KINDS = ["bar","stool","chair","table","coffee","sofa","old_sofa","armchair","old_armchair","old_table","dancefloor"]
const BED_KINDS = ["bed","heart_bed","old_bed"]

static func infection_risk(client_washed: bool, bed_unmade: bool, mess: int) -> float:
	# Chance that a service passes an illness on: a client who could not
	# shower, a bed not made since the last time, litter in the room.
	return clampf(0.02+(0.0 if client_washed else 0.07)+(0.06 if bed_unmade else 0.0)+0.03*mini(mess,3),0.0,0.5)

func service_price(tier: int, e: Actor) -> int:
	return int(round(SERVICES[tier].price*STANDING_RATE[clampi(standing(e),0,4)]))

func social_count(room: Dictionary) -> int:
	if room.is_empty(): return 0
	var r = model.shape(room)
	return model.furniture.filter(func(i): return not i.get("delivery_pending",false) and i.kind in SOCIAL_KINDS and r.has_point(Vector2(i.x,i.z))).size()

func room_mess(room: Dictionary) -> int:
	if room.is_empty(): return 0
	var r = model.shape(room)
	return model.furniture.filter(func(i): return Catalog.is_debris(i.kind) and r.has_point(Vector2(i.x,i.z))).size()

func hint(key: String, text: String, every: float = 180.0) -> void:
	if elapsed < float(hints.get(key,-1.0)): return
	hints[key] = elapsed+every
	notice.emit(text)

func try_approach(e: Actor) -> bool:
	# A free escort spots a client busy in the public room. The more places
	# there are to sit, drink and dance, the more often they cross paths.
	var best: Actor = null
	var best_d = 1e9
	for c in clients:
		if not is_instance_valid(c): continue
		var cb = c.brain
		if cb.state != "busy" or not cb.activity in ["bar","lounge","dance","look"]: continue
		if cb.has("escort") or cb.get("service_done",false) or e.item_id in cb.get("refused",[]): continue
		var room = model.room_at(c.world)
		if room.is_empty() or not int(room.type) in [0,5]: continue
		var d = c.world.distance_squared_to(e.world)
		if d < best_d:
			best_d = d
			best = c
	if best == null: return false
	if rng.randf() > clampf(0.3+0.07*social_count(model.room_at(best.world)),0.3,0.92): return false
	release(e)
	e.lift = 0
	var spot = meeting_spot(best)
	if not spot.is_empty():
		if not go_spot(e,spot): return false
	else:
		var cell = nav.free_cell_near(best.world+Vector2(0.55,0.35))
		if cell.x == 9999 or not go(e,nav.center(cell)): return false
	best.brain.escort = e
	best.brain.timer = maxf(float(best.brain.timer),14.0)
	e.brain.client = best
	e.brain.state = "approach"
	return true

func meeting_spot(c: Actor) -> Dictionary:
	# A free seat, bar place or dance spot right next to the client.
	var room = model.room_at(c.world)
	var best: Dictionary = {}
	var best_d = 1.8
	for s in all_spots():
		if reserved.has(spot_key(s)) or not s.use in ["sit","stand","dance"]: continue
		if s.who in ["receptionist","bartender"]: continue
		var kind = model.item_by_id(s.item).get("kind","")
		if kind in BED_KINDS or kind == "shower" or kind == "dance": continue
		if model.room_at(s.pos) != room: continue
		if c.brain.activity == "dance" and s.use != "dance": continue
		var d = s.pos.distance_to(c.world)
		if d > 0.2 and d < best_d:
			best_d = d
			best = s
	return best

func partner_ok(e: Actor, c) -> bool:
	return c != null and is_instance_valid(c) and c.brain.get("escort") == e and c.brain.state in ["busy","walk"]

func drop_client(e: Actor) -> void:
	var c = e.brain.get("client")
	if c != null and is_instance_valid(c) and c.brain.get("escort") == e: c.brain.erase("escort")
	e.brain.erase("client")
	e.visible = true
	release(e)
	e.lift = 0
	e.brain.state = "free"
	if e.anim in ["kneel","stand"]:
		e.path = []
		e.play("idle")

func free_bed() -> Dictionary:
	# A bed in a bedroom that nobody uses; made beds first.
	var best: Dictionary = {}
	var best_score = -1
	for item in model.furniture:
		if item.get("delivery_pending",false): continue
		if not item.kind in BED_KINDS or busy_beds.has(int(item.id)): continue
		var room = model.room_at(Vector2(item.x,item.z))
		if room.is_empty() or int(room.type) != 1: continue
		if bed_spot(item,"client").is_empty() or bed_spot(item,"escort").is_empty(): continue
		var score = 1 if item.get("unmade",false) else 2
		if score > best_score:
			best_score = score
			best = item
	return best

func bed_spot(bed: Dictionary, who: String) -> Dictionary:
	for s in Catalog.spots(bed):
		if s.who == who and not reserved.has(spot_key(s)): return s
	return {}

func pose_obstruction(p: Vector2, kneeling: bool) -> float:
	var height = 39.0 if kneeling else 46.0
	var bounds = Rect2(Iso.pixel(p.x,p.y)+Vector2(-10,-height),Vector2(20,height+1))
	var area = 0.0
	for i in range(view.statics.size()):
		if WorldView.behind_point(view.statics[i].rect,p): continue
		var overlap = bounds.intersection(view.s_px[i])
		if overlap.has_area(): area += overlap.get_area()
	return area

func quick_places(bed: Dictionary, c: Actor, e: Actor) -> Dictionary:
	var p0 = Prof.t("sim.quick_places")
	var out = _timed_quick_places(bed,c,e)
	Prof.add("sim.quick_places",p0)
	return out

func _timed_quick_places(bed: Dictionary, c: Actor, e: Actor) -> Dictionary:
	# Two reachable floor positions in the bedroom, with a visible gap between
	# their silhouettes. No furniture, doorway or wall can split the pair.
	var room = model.room_at(Vector2(bed.x,bed.z))
	if room.is_empty(): return {}
	var inner = model.shape(room).grow(-0.3)
	var best: Dictionary = {}
	var score = INF
	var lo = nav.cell_of(inner.position)
	var hi = nav.cell_of(inner.end)
	for x in range(lo.x,hi.x+1):
		for y in range(lo.y,hi.y+1):
			var p = nav.center(Vector2i(x,y))
			if not inner.has_point(p) or not nav.walkable(p): continue
			for offset in [Vector2(1,-0.5),Vector2(0.5,-1),Vector2(-1,0.5),Vector2(-0.5,1)]:
				var q: Vector2 = p+offset
				if not inner.has_point(q) or not nav.walkable(q): continue
				if not nav.walkable(p.lerp(q,0.25)) or not nav.walkable(p.lerp(q,0.5)) or not nav.walkable(p.lerp(q,0.75)): continue
				var d = p.distance_squared_to(Vector2(bed.x,bed.z))+q.distance_squared_to(Vector2(bed.x,bed.z))
				d += 100.0*(pose_obstruction(p,false)+pose_obstruction(q,true))
				if d >= score or not nav.reachable(c.world,p) or not nav.reachable(e.world,q): continue
				score = d
				best = {"client":p,"escort":q}
	return best

func service_spot(sv: Dictionary, who: String) -> Dictionary:
	var bed = model.item_by_id(int(sv.bed))
	if bed.is_empty(): return {}
	if int(sv.tier) != 0: return bed_spot(bed,who)
	var places: Dictionary = sv.get("places",{})
	if places.is_empty(): return {}
	var other = "escort" if who == "client" else "client"
	return {"item":int(bed.id),"index":2 if who == "client" else 3,
		"pos":places[who],"face":places[other]-places[who],"lift":0,"use":"quick","who":who}

func free_shower(room: Dictionary) -> Dictionary:
	# Only a shower whose door opens onto free floor of the same room is used.
	if room.is_empty(): return {}
	var r = model.shape(room)
	for s in free_spots("wash","any"):
		if not model.item_by_id(s.item).get("leaking",false) and r.has_point(s.pos) and r.has_point(s.door) and nav.walkable(s.door): return s
	return {}

func floor_spot(e: Actor) -> Dictionary:
	var spots = free_spots("dance","escort",[0,5]).filter(func(s): return model.item_by_id(s.item).kind == "dancefloor")
	if spots.is_empty(): return {}
	spots.sort_custom(func(x,y): return x.pos.distance_squared_to(e.world) < y.pos.distance_squared_to(e.world))
	return spots[0]

func crowd_tips(e: Actor, activities: Array, radius: float, base: int, per_level: int, counter: String, whole_room: bool = false) -> void:
	# Generous clients watching her dance slip her a tip. A pole show is seen
	# from the whole room; those at the foot of the stage tip more often.
	var room = model.room_at(e.world)
	for c in clients:
		if not is_instance_valid(c) or not c.brain.get("generous",false) or c.brain.state != "busy": continue
		if not c.brain.activity in activities: continue
		var near = c.world.distance_to(e.world) <= radius
		if not near and not (whole_room and model.room_at(c.world) == room): continue
		if rng.randf() > (0.6 if near else 0.3): continue
		var tip = int((base+per_level*standing(e))*rng.randf_range(1.0,2.0)*float(e.brain.get("quality",1.0)))
		if int(c.brain.budget) < tip: continue
		c.brain.budget = int(c.brain.budget)-tip
		c.brain.spent += tip
		c.brain.sat = minf(float(c.brain.sat)+1.0,100.0)
		money += tip
		night.tips = int(night.get("tips",0))+tip
		night.dance = int(night.dance)+tip
		if counter != "": night[counter] = int(night.get(counter,0))+tip
		view.puff(e.world,"dollar",1.6)

func crowd_date(e: Actor, activities: Array, radius: float, bonus: float, counter: String, whole_room: bool = false) -> bool:
	# A generous client watching or dancing with her takes her upstairs straight away.
	var room = model.room_at(e.world)
	for c in clients:
		if not is_instance_valid(c) or not c.brain.get("generous",false): continue
		var cb = c.brain
		if cb.state != "busy" or not cb.activity in activities or cb.has("escort") or cb.get("service_done",false) or e.item_id in cb.get("refused",[]): continue
		var near = c.world.distance_to(e.world) <= radius
		if not near and not (whole_room and model.room_at(c.world) == room): continue
		if rng.randf() > (0.4 if near else 0.15): continue
		release(e)
		e.lift = 0
		cb.escort = e
		e.brain.client = c
		e.emote("heart",1.8)
		c.emote("heart",1.8)
		if negotiate(e,c,bonus): night[counter] = int(night.get(counter,0))+1
		return true
	return false

func negotiate(e: Actor, c: Actor, bonus: float = 0.0) -> bool:
	# Both must agree: the client must want her and afford a service, she
	# must be in the mood, and a bedroom must be free.
	var cb = c.brain
	var affordable: Array = []
	for t in range(SERVICES.size()):
		if service_price(t,e) <= int(cb.budget): affordable.append(t)
	var chance = clampf(0.3+bonus+float(cb.sat)/200.0+0.05*standing(e)+0.04*social_count(model.room_at(c.world))+(float(e.brain.get("quality",1.0))-1.0)*0.3,0.1,0.95)
	var bed = free_bed()
	if affordable.is_empty() or bed.is_empty() or float(cb.sat) < 25.0 or rng.randf() > chance:
		night.refused += 1
		e.emote("no",2.0)
		cb.sat -= 3.0 if affordable.is_empty() or bed.is_empty() else 2.0
		cb.refused.append(e.item_id)
		if bed.is_empty() and not affordable.is_empty():
			hint("no_room","Une escort et un client s'entendaient, mais aucune chambre n'était libre (lit dans une chambre).")
		drop_client(e)
		return false
	var tier: int = affordable[affordable.size()-1] if rng.randf() < 0.5 else affordable[rng.randi_range(0,affordable.size()-1)]
	var places = quick_places(bed,c,e) if tier == 0 else {}
	if tier == 0 and places.is_empty():
		night.refused += 1
		cb.refused.append(e.item_id)
		drop_client(e)
		hint("quick_space","La prestation rapide demande un peu d'espace libre au sol dans la chambre.")
		return false
	night.agreed += 1
	e.emote("heart",2.0)
	c.emote("heart",2.0)
	cb.service = {"tier":tier,"price":service_price(tier,e),"bed":int(bed.id),"washed":false,"escort":e,"places":places}
	cb.activity = "private"
	busy_beds[int(bed.id)] = c
	release(c)
	c.lift = 0
	# the client showers first if the room has a shower
	var shower = free_shower(model.room_at(Vector2(bed.x,bed.z)))
	if not shower.is_empty() and go_spot(c,shower): cb.state = "to_shower"
	else: client_to_bed(c)
	if not cb.has("service"): return false
	release(e)
	e.lift = 0
	var es = service_spot(cb.service,"escort")
	if es.is_empty() or not go_spot(e,es):
		cancel_service(c)
		return false
	e.brain.state = "to_bed"
	# for a visit in bed she first changes into her lingerie in front of it
	if tier != 0 and can_undress(e) and go(e,dress_point(bed)): e.brain.state = "to_undress"
	return true

func client_to_bed(c: Actor) -> void:
	var s = service_spot(c.brain.service,"client")
	if s.is_empty() or not go_spot(c,s):
		cancel_service(c)
		return
	c.brain.state = "to_bed"

func cancel_service(c: Actor) -> void:
	var sv: Dictionary = c.brain.get("service",{})
	busy_beds.erase(int(sv.get("bed",-1)))
	var e = sv.get("escort")
	if e != null and is_instance_valid(e) and e.brain.get("client") == c: drop_client(e)
	c.visible = true
	release(c)
	c.brain.erase("service")
	c.brain.erase("escort")
	c.brain.state = "choose"
	if int(sv.get("tier",-1)) == 0:
		c.path = []
		c.lift = 0
		c.play("idle")
		if is_instance_valid(e):
			e.path = []
			e.play("idle")

func client_service(c: Actor, arrived: bool, gm: float) -> void:
	var b = c.brain
	if not b.has("service"):
		b.state = "choose"
		return
	var sv: Dictionary = b.service
	match b.state:
		"to_shower":
			if arrived:
				b.state = "showering"
				shower_step(c,true,gm)
		"showering":
			if shower_step(c,arrived,gm):
				sv.washed = true
				night.showers += 1
				release(c)
				client_to_bed(c)
		"to_bed":
			if arrived:
				settle(c)
				b.state = "wait_partner"
				b.timer = 25.0
		"wait_partner":
			b.timer -= gm
			var e = sv.get("escort")
			if e != null and is_instance_valid(e) and e.brain.state == "wait_partner": start_service(c,e)
			elif b.timer <= 0 or e == null or not is_instance_valid(e):
				b.sat -= 5
				cancel_service(c)
		"in_service":
			service_script(c,gm)

func start_service(c: Actor, e: Actor) -> void:
	# Quick visits use a still, clothed floor pose; other tiers use the bed.
	var sv: Dictionary = c.brain.service
	var bed = model.item_by_id(int(sv.bed))
	var room = model.room_at(Vector2(bed.x,bed.z))
	sv.bed_unmade = bed.get("unmade",false) if int(sv.tier) != 0 else false
	sv.mess = room_mess(room)
	sv.phase = "undress"
	sv.phase_t = 4.0
	sv.tempo = -1.0
	if int(sv.tier) == 0:
		sv.phase = "quick_arrival"
		sv.phase_t = 3.0
		c.play("stand")
		e.play("stand")
	c.brain.state = "in_service"
	e.brain.state = "in_service"
	c.brain.timer = float(SERVICES[int(sv.tier)].minutes)
	# the client pays at the end (see end_service)
	night.served += 1
	night["tier_%d" % int(sv.tier)] = int(night.get("tier_%d" % int(sv.tier),0))+1
	view.puff(c.world.lerp(e.world,0.5) if int(sv.tier) == 0 else Vector2(bed.x,bed.z),"heart",2.0)

func end_service(c: Actor, aborted: bool = false) -> void:
	# Floor poses preserve the bed; bed-based visits leave it unmade.
	# Health outcomes still depend on hygiene.
	var sv: Dictionary = c.brain.service
	var e = sv.get("escort")
	var bed_id = int(sv.bed)
	var started = c.brain.state == "in_service"
	var uses_bed = int(sv.tier) != 0
	busy_beds.erase(bed_id)
	var bed = model.item_by_id(bed_id)
	view.show_clothes(bed_id,false)
	c.visible = true
	release(c)
	c.lift = 0
	if not uses_bed:
		c.path = []
		c.play("idle")
	c.brain.erase("service")
	c.brain.erase("escort")
	c.brain.state = "choose"
	var room = model.room_at(Vector2(bed.x,bed.z)) if not bed.is_empty() else {}
	var risk = infection_risk(sv.get("washed",false),sv.get("bed_unmade",false),int(sv.get("mess",0)))
	if started and uses_bed and not bed.is_empty():
		bed.unmade = true
		view.set_bed_look(bed_id,"unmade")
	else:
		view.set_bed_look(bed_id,"unmade" if bed.get("unmade",false) else "made")
	if started and not aborted:
		var tier = int(sv.tier)
		money += int(sv.price)
		night.private = int(night.private)+int(sv.price)
		c.brain.spent += int(sv.price)
		view.float_text(c.world,"+%d $" % int(sv.price),Color("ffd66b"),3.0)
	if started and not aborted:
		var tier = int(sv.tier)
		var lvl = standing(e) if e != null and is_instance_valid(e) else 1
		c.brain.sat += 10.0+4.0*tier+2.0*lvl+(2.0 if sv.get("washed",false) else 0.0)-(8.0 if sv.get("bed_unmade",false) else 0.0)-3.0*mini(int(sv.get("mess",0)),3)
		c.brain.service_done = true
		c.brain.visits += 1
		# Bed-based visits keep their closing emotes.
		match tier:
			0:
				pass
			1:
				c.emote("heart",2.5)
				if e != null and is_instance_valid(e): e.emote("heart",2.5)
			2:
				c.emote("star",3.0)
				if e != null and is_instance_valid(e): e.emote("heart",3.0)
		if rng.randf() < risk: infect_client(c)
		# the tissues go in the room's bin if it has one, else on the floor
		if uses_bed and rng.randf() < 0.6 and not bed.is_empty() and not Waste.toss_in_room(self,room): drop_tissues(bed)
	if e != null and is_instance_valid(e) and e.brain.get("client") == c:
		e.visible = true
		release(e)
		e.lift = 0
		if not uses_bed:
			e.path = []
			e.play("idle")
		e.brain.erase("client")
		# she showers after if she can, which lowers her own risk
		var shower = free_shower(room)
		if started and not shower.is_empty() and go_spot(e,shower):
			e.brain.state = "to_shower_after"
			e.brain.risk = risk*0.6
		else:
			e.brain.state = "free"
			if started: roll_escort(e,risk+0.05)
			# no shower: she dresses again in front of the bed
			if e.brain.get("state","") == "free" and e.brain.has("dressed") and not bed.is_empty() and go(e,dress_point(bed)): e.brain.state = "to_redress"

# Quick visits keep a static floor pose; other tiers use the bed sequence.
func service_script(c: Actor, gm: float) -> void:
	var b = c.brain
	var sv: Dictionary = b.service
	var e = sv.get("escort")
	var bed = model.item_by_id(int(sv.bed))
	if bed.is_empty():
		end_service(c,true)
		return
	if int(sv.tier) == 0:
		if not is_instance_valid(e):
			end_service(c,true)
			return
		if sv.phase == "quick_arrival":
			sv.phase_t = float(sv.phase_t)-gm
			if sv.phase_t <= 0:
				sv.phase = "quick_pose"
				# She kneels right in front of him, not at the arrival spacing.
				var gap: Vector2 = e.world-c.world
				if gap.length() > QUICK_KNEEL_GAP: e.set_world(c.world+gap.normalized()*QUICK_KNEEL_GAP)
				c.face(e.world-c.world)
				e.face(c.world-e.world)
				c.play("stand")
				e.play("kneel")
				b.puff = 1.0
		elif sv.phase == "quick_pose":
			b.timer -= gm
			b.puff = float(b.get("puff",0.0))-gm
			if b.puff <= 0:
				b.puff = 3.0
				view.puff(c.world.lerp(e.world,0.5),"heart",1.6)
			if b.timer <= 0:
				# she gets up; a word, then he pays and they part
				sv.phase = "quick_after"
				sv.phase_t = 3.0
				e.play("stand")
				c.emote("heart",2.0)
				e.emote("heart",2.0)
		else:
			sv.phase_t = float(sv.phase_t)-gm
			if sv.phase_t <= 0: end_service(c)
		return
	var bp = Vector2(bed.x,bed.z)
	var size: Vector2 = Catalog.ITEMS[bed.kind].size
	var head = Catalog.local_to_world(bed,Vector2(0,-size.y/2.0+0.3))
	b.puff = float(b.get("puff",0.0))-gm
	if sv.phase == "undress":
		# sitting on the edge of the bed, flirting
		sv.phase_t = float(sv.phase_t)-gm
		if b.puff <= 0:
			b.puff = 1.0
			view.puff(bp,"heart",1.4)
		if sv.phase_t <= 0:
			# she gets up and dances for him in front of the bed
			sv.phase = "dance"
			sv.phase_t = [6.0,10.0,14.0][int(sv.tier)]
			var room = model.room_at(bp)
			var foot = Catalog.local_to_world(bed,Vector2(0,size.y/2.0+0.55))
			sv.stage = room_floor_near(room,foot)
			if e != null and is_instance_valid(e):
				release(e)
				e.lift = 0
				if not go(e,sv.stage): e.set_world(sv.stage)
		return
	if sv.phase == "dance":
		sv.phase_t = float(sv.phase_t)-gm
		if e != null and is_instance_valid(e) and e.path.is_empty():
			e.face(c.world-e.world)
			e.play("dance")
		if b.puff <= 0:
			b.puff = 1.1
			view.puff(sv.stage,"heart" if rng.randf() < 0.7 else "dollar",1.4)
		if sv.phase_t <= 0:
			# a tip for the show, then under the covers
			var tip = 10*(1+int(sv.tier))*standing(e) if e != null and is_instance_valid(e) else 10
			money += tip
			view.float_text(sv.stage,"+%d $" % tip,Color("ffd66b"),2.5)
			night.private = int(night.private)+tip
			c.brain.spent += tip
			sv.phase = "action"
			c.visible = false
			if e != null and is_instance_valid(e):
				e.path = []
				e.visible = false
				var es = bed_spot(bed,"escort")
				e.set_world(es.pos if not es.is_empty() else bp)
			view.set_bed_look(int(sv.bed),"busy",4.0)
			view.show_clothes(int(sv.bed),true,clothes_spot(bed))
		return
	b.timer -= gm
	var tier = int(sv.tier)
	var f = clampf(1.0-float(b.timer)/float(SERVICES[tier].minutes),0.0,1.0)
	var tempo = 4.0
	var icon = "heart"
	var every = 2.5
	var at = bp
	match tier:
		1:
			# steady, with hearts
			tempo = 4.0
		2:
			# slow start, the headboard knocking, then fireworks and a nap
			if f < 0.45:
				tempo = 3.0
			elif f < 0.88:
				tempo = 8.0
				icon = "bang" if int(elapsed) % 2 == 0 else "star"
				every = 1.4
				at = head
			else:
				tempo = 0.0
				icon = "zzz"
				every = 2.0
	if tempo != float(sv.tempo):
		sv.tempo = tempo
		view.set_bed_look(int(sv.bed),"busy",tempo)
	if b.puff <= 0:
		b.puff = every
		view.puff(at,icon,1.8)
	if b.timer <= 0: end_service(c)

func clothes_spot(bed: Dictionary) -> Vector2:
	# A bit of bedroom floor beside the bed where the clothes stay in sight:
	# inside the room, with nothing standing just in front of it on screen.
	var room = model.room_at(Vector2(bed.x,bed.z))
	var size: Vector2 = Catalog.ITEMS[bed.kind].size
	var first = Vector2.INF
	for local in [Vector2(-size.x/2.0-0.5,0.4),Vector2(size.x/2.0+0.5,0.4),Vector2(0,size.y/2.0+0.6)]:
		var p = room_floor_near(room,Catalog.local_to_world(bed,local))
		if first == Vector2.INF: first = p
		if not nav.blocked.has(nav.cell_of(p+Vector2(0.5,0.5))) and not nav.blocked.has(nav.cell_of(p+Vector2(0.5,0.0))): return p
	return first

func room_floor_near(room: Dictionary, p: Vector2) -> Vector2:
	var p0 = Prof.t("sim.floor_near")
	var out = _timed_room_floor_near(room,p)
	Prof.add("sim.floor_near",p0)
	return out

func _timed_room_floor_near(room: Dictionary, p: Vector2) -> Vector2:
	# The free floor cell of a room closest to a point: never behind a wall.
	if room.is_empty(): return p
	var r = model.shape(room)
	var inner = r.grow(-0.3)
	var best = p
	var best_d = 1e12
	var c0 = nav.cell_of(r.position)
	var c1 = nav.cell_of(r.end-Vector2(0.01,0.01))
	for cx in range(c0.x,c1.x+1):
		for cy in range(c0.y,c1.y+1):
			var cc = Vector2i(cx,cy)
			if nav.blocked.has(cc) or int(nav.room_of.get(cc,0)) != int(room.id): continue
			var cp = nav.center(cc)
			if not inner.has_point(cp): continue
			var d = cp.distance_squared_to(p)
			if d < best_d:
				best_d = d
				best = cp
	return best

# ------------------------------------------------------------------ lingerie

const TWIRL = 4.0          # game minutes of the twirl into or out of her lingerie
const TWIRL_STEP = 0.5     # a quarter turn every half minute: two full turns
const TWIRL_TURN = [Vector2(1,0),Vector2(0,1),Vector2(-1,0),Vector2(0,-1)]
# colours of the string and bra she changes into
const LINGERIE = ["e0306a","1c1a20","f2efe9","8a2a9a","c01e44","f070b0","3ad0e0","f0d050"]

func can_undress(e: Actor) -> bool:
	return int(e.appearance.get("body",0)) == 0 and not e.brain.has("dressed") and not e.brain.has("change")

func dress_point(bed: Dictionary) -> Vector2:
	# the floor in front of the foot of the bed
	var size: Vector2 = Catalog.ITEMS[bed.kind].size
	return room_floor_near(model.room_at(Vector2(bed.x,bed.z)),Catalog.local_to_world(bed,Vector2(0,size.y/2.0+0.55)))

func undress(e: Actor) -> void:
	# a coloured string and a little bra, in a twirl
	if not can_undress(e): return
	var look: Dictionary = e.appearance.duplicate()
	look.outfit_style = Characters.FEMALE_OUTFITS.find("string")
	# a colour that stands out from what she was wearing, so the change shows
	var own = Color(String(e.appearance.get("outfit","e0609a")))
	var colors = LINGERIE.filter(func(c): return Vector3(Color(c).r-own.r,Color(c).g-own.g,Color(c).b-own.b).length() > 0.45)
	if colors.is_empty(): colors = LINGERIE
	look.outfit = colors[rng.randi_range(0,colors.size()-1)]
	start_change(e,look,true)

func redress(e: Actor) -> void:
	if not e.brain.has("dressed") or e.brain.has("change"): return
	start_change(e,e.brain.dressed,false)

func start_change(e: Actor, look: Dictionary, undressing: bool) -> void:
	e.path = []
	e.lift = 0
	e.play("idle")
	e.brain.change = {"look":look,"t":0.0,"undress":undressing,"swapped":false,"turn":-1}

func outfit_tick(e: Actor, gm: float) -> bool:
	# She turns on the spot; half way round, a little cloud and the other outfit.
	var ch = e.brain.get("change")
	if not ch is Dictionary: return false
	ch.t = float(ch.t)+gm
	var turn = int(float(ch.t)/TWIRL_STEP)
	if turn != int(ch.turn):
		ch.turn = turn
		e.face(TWIRL_TURN[turn % TWIRL_TURN.size()])
	if not ch.swapped and float(ch.t) >= TWIRL*0.5:
		ch.swapped = true
		if ch.undress: e.brain.dressed = model.item_by_id(e.item_id).get("appearance",e.appearance)
		else: e.brain.erase("dressed")
		e.configure(ch.look)
		if view != null: view.outfit_poof(e.world)
	if float(ch.t) < TWIRL: return true
	e.brain.erase("change")
	e.emote("heart" if ch.undress else "star",1.6)
	return false

func dress_now(e: Actor) -> void:
	# back in her own clothes at once (her shift is over, she is ill)
	e.brain.erase("change")
	if e.brain.get("dressed") is Dictionary: e.configure(e.brain.dressed)
	e.brain.erase("dressed")

func drop_tissues(bed: Dictionary) -> void:
	# Used tissues and a towel near the bed, for the cleaners.
	var size: Vector2 = Catalog.ITEMS[bed.kind].size
	for local in [Vector2(0,size.y/2.0+0.4),Vector2(size.x/2.0+0.4,0.3),Vector2(-size.x/2.0-0.4,0.3),Vector2(size.x/2.0+0.4,-0.6)]:
		var p = Catalog.local_to_world(bed,local)
		var id = model.add_item("trash_tissues",p.x,p.y,0)
		if id != -1:
			debris_dropped.emit(id)
			return

func infect_client(c: Actor) -> void:
	c.brain.sat -= 25.0
	night.infections += 1
	c.emote("sick",3.0)
	hint("client_ill","Un client est reparti malade. Douches, lits refaits et chambres propres réduisent le risque.")

func roll_escort(e: Actor, risk: float) -> void:
	if rng.randf() >= risk: return
	var b = e.brain
	b.health = float(b.get("health",100.0))-45.0
	e.emote("sick",3.0)
	if b.health < 55.0: make_sick(e)

func make_sick(e: Actor) -> void:
	# A sick escort stops working and rests for about ten hours.
	var b = e.brain
	b.sick = 600.0
	night.sick += 1
	dress_now(e)
	if b.has("client"): drop_client(e)
	release(e)
	e.visible = true
	e.lift = 0
	b.state = "sick"
	go(e,b.post)
	hint("escort_sick","%s est malade : elle se repose et ne travaille plus pendant quelques heures." % Catalog.ITEMS.get(e.kind,{}).get("name","Une escort"),60.0)

func escort_sick(e: Actor, arrived: bool, gm: float) -> void:
	var b = e.brain
	b.sick = float(b.sick)-gm
	if b.state != "sick":
		if b.has("client"): drop_client(e)
		release(e)
		e.visible = true
		b.state = "sick"
		go(e,b.post)
	if arrived: e.play("idle")
	b.grumble = float(b.get("grumble",0.0))-gm
	if b.grumble <= 0:
		b.grumble = 25.0
		e.emote("sick",2.0)
	if b.sick <= 0:
		b.sick = 0.0
		b.health = maxf(float(b.health),70.0)
		b.state = "free"
