class_name Plumbing
extends RefCounted

const KINDS = ["toilet","old_toilet","urinal","sink","old_sink","shower"]
const TECHNICIANS = ["janitor","staff"]
const SPREAD_MINUTES = 4.0
const MAX_PUDDLES = 512
# Per-use incident probabilities, separate from gradual hygiene loss.
const URINE_CHANCE = {"toilet":0.08,"old_toilet":0.08,"urinal":0.12}

static func service_spot(item: Dictionary) -> Dictionary:
	var spots = Catalog.spots(item)
	if spots.is_empty(): return {}
	var s: Dictionary = spots[0].duplicate()
	if s.has("door"):
		s.pos = s.door
		s.erase("door")
		s.face = Vector2(item.x,item.z)-s.pos
		s.use = "stand"
	return s

static func after_use(sim, item: Dictionary) -> void:
	if item.is_empty() or not item.kind in KINDS or item.get("delivery_pending",false): return
	item.wear = minf(100,float(item.get("wear",0))+2.0)
	if item.kind in ClientNeeds.FIXTURES:
		var chance = float(URINE_CHANCE[item.kind])
		if float(item.get("soil",0)) >= 100:
			ensure_overflow(sim,item)
		elif sim.maintenance_rng.randf() < chance:
			urine_trace(sim,item)
	# Salvaged plumbing fails a little more often; newly repaired items get a grace period.
	var chance = .003+float(item.wear)*.00025+(.012 if Catalog.is_used(item.kind) else 0.0)
	if item.wear >= 8 and sim.maintenance_rng.randf() < chance: start_leak(sim,item)
	sim.view.refresh_sanitary(item,sim.maintenance_clock)

static func urine_trace(sim, item: Dictionary) -> void:
	if not item.kind in ClientNeeds.FIXTURES: return
	sim.add_fixture_dirt(item,.65 if float(item.get("soil",0)) < 100 else 1.5)

static func ensure_overflow(sim, item: Dictionary) -> void:
	if item.kind in ClientNeeds.FIXTURES and float(item.get("soil",0)) >= 100 and Sanitation.fixture_spills(sim,item).is_empty():
		urine_trace(sim,item)

static func start_leak(sim, item: Dictionary) -> void:
	if item.is_empty() or not item.kind in KINDS or item.get("delivery_pending",false) or item.get("leaking",false): return
	item.leaking = true
	item.leak_timer = 0.0
	spread(sim,item)
	sim.view.refresh_sanitary(item,sim.maintenance_clock)
	sim.hint("plumbing_leak","Fuite d'eau ! Un technicien doit réparer l'équipement. Le ménage seul ne peut pas arrêter l'eau.",30)

static func spread(sim, item: Dictionary) -> void:
	var s = service_spot(item)
	if s.is_empty(): return
	var room: Dictionary = sim.model.room_at(Vector2(item.x,item.z))
	if room.is_empty(): return
	var origin: Vector2i = sim.nav.free_cell_near(s.pos)
	if origin.x == 9999 or sim.model.room_at(sim.nav.center(origin)) != room: return
	var wet: Dictionary = {}
	for d in sim.dirt:
		if d.kind == "water": wet[sim.nav.cell_of(d.pos)] = d
	var frontier: Array = [origin]
	var seen: Dictionary = {origin:true}
	var cursor = 0
	# Flood only connected, walkable floor of this room, never through a wall or furniture.
	while cursor < frontier.size():
		var cell: Vector2i = frontier[cursor]
		cursor += 1
		if not wet.has(cell):
			if sim.dirt.size() < MAX_PUDDLES:
				sim.add_dirt(sim.nav.center(cell),"water",1.0)
				return
		else:
			for offset in [Vector2i(1,0),Vector2i(0,1),Vector2i(-1,0),Vector2i(0,-1)]:
				var next: Vector2i = cell+offset
				var p: Vector2 = sim.nav.center(next)
				if seen.has(next) or not sim.nav.walkable(p) or sim.model.room_at(p) != room or not sim.nav.passable(cell,next): continue
				seen[next] = true
				frontier.append(next)
	# Once the available floor is flooded, water thickens existing patches instead.
	var smallest: Dictionary = {}
	for cell in seen:
		if wet.has(cell) and (smallest.is_empty() or wet[cell].work < smallest.work): smallest = wet[cell]
	if not smallest.is_empty(): sim.add_dirt(smallest.pos,"water",.5)

static func tick(sim, gm: float) -> void:
	if gm <= 0: return
	sim.maintenance_clock += gm/ClubSim.MINUTES_PER_SECOND
	for item in sim.model.furniture:
		if not item.kind in KINDS or item.get("delivery_pending",false): continue
		ensure_overflow(sim,item)
		if item.get("leaking",false):
			item.leak_timer = float(item.get("leak_timer",0))+gm
			var pulses = mini(32,floori(item.leak_timer/SPREAD_MINUTES))
			item.leak_timer -= pulses*SPREAD_MINUTES
			for i in range(pulses): spread(sim,item)
		sim.view.refresh_sanitary(item,sim.maintenance_clock)

static func leaks(sim) -> int:
	var count = 0
	for item in sim.model.furniture:
		if item.kind in KINDS and item.get("leaking",false) and not item.get("delivery_pending",false): count += 1
	return count

static func repair_status(sim, item: Dictionary) -> String:
	if not item.get("leaking",false): return ""
	var s = service_spot(item)
	var owner = sim.reserved.get(sim.spot_key(s))
	if is_instance_valid(owner) and owner.brain.state == "repairing": return "Fuite · réparation en cours"
	if is_instance_valid(owner) and owner.brain.state == "to_repair": return "Fuite · technicien en route"
	var technicians = sim.staff.values().filter(func(a): return is_instance_valid(a) and a.kind in TECHNICIANS)
	if technicians.is_empty(): return "Fuite · recrutez un technicien"
	if not technicians.any(func(a): return sim.staff_available(a)): return "Fuite · techniciens hors service"
	if not technicians.any(func(a): return Sanitation.usable(sim,a,s,true)): return "Fuite · accès technicien bloqué"
	return "Fuite · attend un technicien"

static func technician_tick(sim, a: Actor, arrived: bool, gm: float) -> bool:
	if not a.kind in TECHNICIANS: return false
	var b = a.brain
	if b.state in ["to_repair","repairing"]:
		var s: Dictionary = b.get("spot",{})
		var item: Dictionary = sim.model.item_by_id(s.get("item",-1))
		if not item.get("leaking",false) or not Sanitation.usable(sim,a,s,true):
			sim.release(a)
			a.path = []
			b.state = "post"
			return true
		if b.state == "to_repair" and arrived:
			sim.settle(a)
			a.play("work")
			a.emote("repair",4)
			b.state = "repairing"
			b.timer = (10.0+float(item.get("wear",0))*.05)*sim.profiles.employee_factor(str(b.get("profile_id","")))
		elif b.state == "repairing":
			b.timer -= gm
			if b.timer <= 0:
				item.leaking = false
				item.leak_timer = 0.0
				item.wear = 0.0
				sim.night.repairs = int(sim.night.get("repairs",0))+1
				sim.view.refresh_sanitary(item,sim.maintenance_clock)
				sim.release(a)
				b.state = "back"
				a.emote("star",1.5)
				if not sim.go(a,b.post): b.state = "post"
		return true
	if b.state in ["post","idle","back"]:
		var candidates: Array = []
		for item in sim.model.furniture:
			if not item.kind in KINDS or not item.get("leaking",false): continue
			var s = service_spot(item)
			if sim.reserved.has(sim.spot_key(s)) or not Sanitation.usable(sim,a,s,true): continue
			candidates.append(s)
		candidates.sort_custom(func(x,y): return x.pos.distance_squared_to(a.world) < y.pos.distance_squared_to(a.world))
		for s in candidates:
			if sim.go_spot(a,s):
				b.state = "to_repair"
				return true
	return false
