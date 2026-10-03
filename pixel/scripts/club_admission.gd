class_name ClubAdmission
extends RefCounted

var capacity = 0
var slots: Array = []
const QUEUE_LIMIT = 24
const ACTOR_LIMIT = 96

func rebuild(sim) -> void:
	capacity = 0
	slots.clear()
	if sim.entrance.is_empty(): return
	var public_rooms = {}
	for room in sim.model.rooms:
		if int(room.type) in [0,5] and not SitePlan.building(room): public_rooms[int(room.id)] = true
	var floor_area = 0.0
	var start = sim.nav.start_cell(sim.entrance.inside)
	var connected = sim.nav.zone.get(sim.nav.key(start),-1)
	for cell in sim.nav.room_of:
		if not public_rooms.has(sim.nav.room_of[cell]): continue
		var point_id = sim.nav.key(cell)
		if connected >= 0 and sim.nav.zone.get(point_id,-2) == connected: floor_area += ClubNav.CELL*ClubNav.CELL
	if floor_area > 0: capacity = clampi(floori(floor_area/2.5),1,48)
	var door: Vector2 = sim.entrance.door
	var out: Vector2 = sim.entrance.outward
	# A few approach spots by the entrance, then the public pavement. The
	# greedy line bends at the end of the sidewalk rather than entering a road.
	for i in range(3):
		var p = door+out*(1.0+i*.85)
		if p.y < Street.ROAD.x-.4 and sim.model.room_at(p).is_empty() and sim.nav.walkable(p) and sim.nav.reachable(sim.entrance.outside,p): slots.append(p)
	var choices: Array = []
	for z in [8.75,9.75]:
		for x in range(-23,24):
			var p = Vector2(float(x)+.25,z)
			if slots.any(func(q): return q.distance_to(p) < .85): continue
			if sim.nav.walkable(p) and sim.nav.reachable(sim.entrance.outside,p) and sim.model.room_at(p).is_empty(): choices.append(p)
	var previous: Vector2 = slots.back() if not slots.is_empty() else sim.entrance.outside
	while slots.size() < QUEUE_LIMIT and not choices.is_empty():
		choices.sort_custom(func(a,b): return a.distance_squared_to(previous) < b.distance_squared_to(previous))
		var next: Vector2 = choices.pop_front()
		if slots.any(func(q): return q.distance_to(next) < .85): continue
		slots.append(next)
		previous = next

func occupancy_load(sim) -> int:
	var total = sim.inside_count()
	for a in sim.clients:
		if is_instance_valid(a) and not a.brain.get("paid",false) and a.brain.get("state","") in ["to_desk","checkin","entering"]: total += 1
	return total

func can_enter(sim) -> bool:
	return capacity > 0 and occupancy_load(sim) < capacity
