class_name Duties
extends RefCounted

# Priorities the player gives an employee: a maid who sees to the toilets
# first, a technician who goes to repairs first... When she is free, the
# employee looks for that kind of work before anything else, then works as
# usual. Kept on the staff item ("duty").

const OPTIONS = {
	"maid":[["","Aucune"],["wc","Sanitaires"],["beds","Lits"],["bins","Poubelles"],["floor","Sols mouillés"],["debris","Déchets au sol"]],
	"staff":[["","Aucune"],["wc","Sanitaires"],["beds","Lits"],["bins","Poubelles"],["floor","Sols mouillés"],["debris","Déchets au sol"]],
	"janitor":[["","Aucune"],["repair","Réparations"],["wc","Sanitaires"],["floor","Sols mouillés"],["debris","Déchets au sol"]]}
const HINTS = {
	"":"Ordre habituel du métier.",
	"wc":"WC, urinoirs, lavabos et douches à nettoyer, et l'eau par terre dans les toilettes, avant tout le reste.",
	"beds":"Les lits défaits d'abord.",
	"bins":"Les poubelles à vider d'abord, jusqu'aux conteneurs.",
	"floor":"Les flaques et salissures par terre d'abord.",
	"debris":"Les déchets au sol d'abord.",
	"repair":"Les fuites et pannes d'abord."}

static func options(kind: String) -> Array:
	return OPTIONS.get(kind,[])

static func name_of(kind: String, duty: String) -> String:
	for o in options(kind):
		if o[0] == duty: return o[1]
	return ""

static func valid(kind: String, duty) -> bool:
	return duty is String and options(kind).any(func(o): return o[0] == duty)

static func of(sim, a: Actor) -> String:
	var duty = sim.model.item_by_id(a.item_id).get("duty","")
	return duty if valid(a.kind,duty) else ""

static func start(sim, a: Actor) -> bool:
	# Called when the employee is free: true when she sets off for her priority.
	match of(sim,a):
		"wc": return start_wc(sim,a)
		"floor": return start_spill(sim,a,false)
		"beds": return start_bed(sim,a)
		"debris": return start_debris(sim,a)
		"bins": return Waste.maid_tick(sim,a,false,0.0)
		"repair": return Plumbing.technician_tick(sim,a,false,0.0)
	return false

static func start_wc(sim, a: Actor) -> bool:
	# water on the toilet floor first, then the fixtures that need it
	if start_spill(sim,a,true): return true
	var b: Dictionary = a.brain
	for item in sim.model.furniture:
		if not item.kind in Plumbing.KINDS or not Sanitation.needs_cleaning(sim,item): continue
		var s = Plumbing.service_spot(item)
		if s.is_empty() or sim.reserved.has(sim.spot_key(s)) or not Sanitation.usable(sim,a,s): continue
		if sim.go_spot(a,s):
			b.state = "to_fixture"
			return true
	return false

static func start_spill(sim, a: Actor, toilets_only: bool) -> bool:
	var best: Dictionary = {}
	var best_d = INF
	for d in sim.dirt:
		if int(d.get("fixture",-1)) >= 0: continue
		if is_instance_valid(d.taken) and d.taken != a: continue
		var room = sim.model.room_at(d.pos)
		if toilets_only and (room.is_empty() or int(room.type) != 2): continue
		if sim.room_private(room) or not sim.nav.walkable(d.pos) or not sim.nav.reachable(a.world,d.pos): continue
		var dist = d.pos.distance_squared_to(a.world)
		if dist < best_d:
			best_d = dist
			best = d
	if best.is_empty() or not sim.go(a,sim.dirt_approach(a,best)): return false
	best.taken = a
	a.brain.dirt = best
	a.brain.state = "to_dirt"
	return true

static func start_bed(sim, a: Actor) -> bool:
	var bed = sim.next_bed(a)
	if bed.is_empty() or not sim.go(a,sim.bed_side(bed)): return false
	sim.beds_taken[int(bed.id)] = a
	a.brain.bed_id = int(bed.id)
	a.brain.state = "to_bed_task"
	return true

static func start_debris(sim, a: Actor) -> bool:
	var target = sim.next_debris(a)
	if target.is_empty() or not sim.go(a,Vector2(target.x,target.z)): return false
	sim.debris_taken[int(target.id)] = a
	a.brain.debris_id = int(target.id)
	a.brain.state = "to_debris"
	return true
