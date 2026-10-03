class_name Waste
extends RefCounted

# Waste in the club. A client done at the bar, back from the toilets or up
# from the lounge or the dance floor sometimes has something to throw away:
# an empty glass, tissues, a paper. With a bin within reach he takes it there;
# otherwise it ends up on the floor, where it spoils the room until a cleaner
# picks it up. Bins fill up; the maids empty them into the containers outside,
# by the street.

const CAPACITY = 10
const REACH = 9.0            # metres a client is ready to walk to a bin
const TOSS_MINUTES = 0.4
const EMPTY_AT = 7           # pieces in a bin when a maid comes to empty it
const BAG_MINUTES = 1.0
const DUMP_MINUTES = 0.8
const EMPTIERS = ["maid","staff"]
# what is left in hand after an activity, and how often
const LITTER = {"bar":["litter_glass",0.45],"toilet":["litter_tissue",0.3],"lounge":["litter_paper",0.15],
	"dance":["litter_paper",0.12],"stage":["litter_paper",0.12]}
const CLIENT_STATES = ["to_bin","binning"]
const MAID_STATES = ["to_bin_empty","bagging","to_container","dumping"]
# rooms where clients look for a bin: public rooms, toilets, reception
const CLIENT_ROOMS = [0,2,5]

static func is_bin(item: Dictionary) -> bool:
	return item.get("kind","") == "bin" and not item.get("delivery_pending",false)

static func level(item: Dictionary) -> int:
	# the picture of a bin: 0 empty, 1 a few pieces, 2 well filled, 3 full
	var n = int(item.get("waste",0))
	if n <= 0: return 0
	if n >= CAPACITY: return 3
	return 1 if n*2 < CAPACITY else 2

static func pick_up(sim, a: Actor, activity: String) -> void:
	# after an activity: maybe something left in hand to throw away
	if not LITTER.has(activity) or a.brain.has("litter"): return
	if sim.waste_rng.randf() < float(LITTER[activity][1]): a.brain.litter = String(LITTER[activity][0])

static func used(sim, id: int) -> int:
	# pieces in the bin, and clients on their way to drop one
	var n = int(sim.model.item_by_id(id).get("waste",0))
	for c in sim.clients:
		if is_instance_valid(c) and int(c.brain.get("bin_to",-1)) == id and c.brain.get("state","") in CLIENT_STATES: n += 1
	return n

static func approach(sim, item: Dictionary) -> Vector2:
	# where to stand to use a bin: in front of it if there is room, else on a side
	var size: Vector2 = Catalog.ITEMS[item.kind].size
	var room = sim.model.room_at(Vector2(item.x,item.z))
	var first = Vector2.INF
	for local in [Vector2(0,size.y/2.0+0.4),Vector2(size.x/2.0+0.4,0),Vector2(-size.x/2.0-0.4,0),Vector2(0,-size.y/2.0-0.4)]:
		var p = Catalog.local_to_world(item,local)
		var c = sim.nav.free_cell_near(p)
		if c.x == 9999: continue
		var q = sim.nav.center(c)
		if first == Vector2.INF: first = q
		if sim.model.room_at(q) == room and q.distance_to(p) < 0.8: return q
	return first if first != Vector2.INF else Vector2(item.x,item.z)

static func nearest_bin(sim, a: Actor) -> Dictionary:
	# the closest bin with room left that the client can walk to
	var best: Dictionary = {}
	var best_d = REACH*REACH
	for item in sim.model.furniture:
		if not is_bin(item) or used(sim,int(item.id)) >= CAPACITY: continue
		var room = sim.model.room_at(Vector2(item.x,item.z))
		if room.is_empty() or not int(room.type) in CLIENT_ROOMS: continue
		var at = approach(sim,item)
		var d = at.distance_squared_to(a.world)
		if d >= best_d or not sim.nav.reachable(a.world,at): continue
		best_d = d
		best = {"item":int(item.id),"pos":at}
	return best

static func dispose(sim, a: Actor) -> bool:
	# Called when the client is free to choose; true when he walks to a bin.
	var b: Dictionary = a.brain
	if not b.has("litter"): return false
	var spot = nearest_bin(sim,a)
	if not spot.is_empty() and sim.go(a,spot.pos):
		b.bin_to = spot.item
		b.state = "to_bin"
		b.activity = "bin"
		return true
	drop(sim,a)
	return false

static func drop(sim, a: Actor) -> void:
	# no bin at hand: on the floor it goes
	var kind = String(a.brain.get("litter",""))
	a.brain.erase("litter")
	a.brain.erase("bin_to")
	if kind == "" or litter_at(sim,kind,a.world) == -1: return
	sim.night.littered = int(sim.night.get("littered",0))+1
	if sim.model.furniture.any(func(i): return is_bin(i)):
		sim.hint("waste","Poubelles pleines ou trop loin : des clients jettent leurs déchets par terre. Ajoutez des poubelles et une femme de ménage pour les vider.",240.0)
	else:
		sim.hint("waste","Pas de poubelle : les clients jettent verres, mouchoirs et papiers par terre. Placez des poubelles près du bar, des toilettes et des salons.",240.0)

static func litter_at(sim, kind: String, p: Vector2) -> int:
	# at his feet, or close by wherever there is room
	for off in [Vector2.ZERO,Vector2(0.4,0),Vector2(-0.4,0),Vector2(0,0.4),Vector2(0,-0.4),Vector2(0.4,0.4),Vector2(-0.4,-0.4),Vector2(0.4,-0.4),Vector2(-0.4,0.4)]:
		var q: Vector2 = p+off
		var id = sim.model.add_item(kind,snappedf(q.x,0.05),snappedf(q.y,0.05),sim.waste_rng.randi_range(0,3))
		if id != -1:
			sim.debris_dropped.emit(id)
			return id
	return -1

static func toss_in_room(sim, room: Dictionary) -> bool:
	# used tissues after a visit go in the bedroom's bin when it has one
	if room.is_empty(): return false
	var r = sim.model.shape(room)
	for item in sim.model.furniture:
		if not is_bin(item) or not r.has_point(Vector2(item.x,item.z)) or int(item.get("waste",0)) >= CAPACITY: continue
		item.waste = int(item.get("waste",0))+1
		sim.night.binned = int(sim.night.get("binned",0))+1
		refresh(sim,item)
		return true
	return false

static func tick(sim, a: Actor, arrived: bool, gm: float) -> bool:
	# a client on his way to a bin, or dropping something in
	var b: Dictionary = a.brain
	match String(b.get("state","")):
		"to_bin":
			var item: Dictionary = sim.model.item_by_id(int(b.get("bin_to",-1)))
			if item.is_empty():
				a.path = []
				drop(sim,a)
				b.state = "choose"
			elif arrived:
				a.face(Vector2(item.x,item.z)-a.world)
				a.play("work")
				b.timer = TOSS_MINUTES
				b.state = "binning"
			return true
		"binning":
			b.timer -= gm
			if b.timer <= 0:
				var item: Dictionary = sim.model.item_by_id(int(b.get("bin_to",-1)))
				if item.is_empty() or int(item.get("waste",0)) >= CAPACITY:
					drop(sim,a)
				else:
					item.waste = int(item.get("waste",0))+1
					b.erase("litter")
					b.erase("bin_to")
					sim.night.binned = int(sim.night.get("binned",0))+1
					refresh(sim,item)
				a.play("idle")
				b.state = "choose"
			return true
	return false

static func bin_to_empty(sim, a: Actor) -> Dictionary:
	# the fullest bin past the mark, nearer first, that no one else is emptying
	var best: Dictionary = {}
	var best_score = -INF
	for item in sim.model.furniture:
		if not is_bin(item) or int(item.get("waste",0)) < EMPTY_AT: continue
		var owner = sim.bins_taken.get(int(item.id))
		if owner != null and is_instance_valid(owner) and owner != a: continue
		if sim.room_private(sim.model.room_at(Vector2(item.x,item.z))): continue
		var score = float(item.waste)*4.0-Vector2(item.x,item.z).distance_to(a.world)
		if score <= best_score or not sim.nav.reachable(a.world,approach(sim,item)): continue
		best_score = score
		best = item
	return best

static func containers(sim) -> Array:
	# the dumpsters by the street (as drawn), else beside the entrance
	var out: Array = []
	if sim.view != null and "containers" in sim.view:
		for c in sim.view.containers: out.append(c)
	if out.is_empty() and not sim.entrance.is_empty():
		var e: Dictionary = sim.entrance
		out.append({"pos":e.door+e.outward*1.4-e.along*3.6,"away":e.outward})
	return out

static func container_spot(sim, a: Actor) -> Dictionary:
	# where to stand to throw a bag in the nearest container
	var best: Dictionary = {}
	var best_d = INF
	for c in containers(sim):
		var stand: Vector2 = c.pos+c.away*1.0
		var cell = sim.nav.free_cell_near(stand)
		if cell.x == 9999: continue
		stand = sim.nav.center(cell)
		var d = stand.distance_squared_to(a.world)
		if d >= best_d or not sim.nav.reachable(a.world,stand): continue
		best_d = d
		best = {"stand":stand,"at":c.pos}
	return best

static func maid_tick(sim, a: Actor, arrived: bool, gm: float) -> bool:
	# A maid empties the bins past the mark into a container outside.
	if not a.kind in EMPTIERS: return false
	var b: Dictionary = a.brain
	match String(b.get("state","")):
		"to_bin_empty":
			var item: Dictionary = sim.model.item_by_id(int(b.get("bin_id",-1)))
			if item.is_empty():
				release(sim,a)
				a.path = []
				b.state = "post"
			elif arrived:
				a.face(Vector2(item.x,item.z)-a.world)
				a.play("work")
				b.timer = BAG_MINUTES*Sanitation.cleaning_factor(sim,a)
				b.state = "bagging"
			return true
		"bagging":
			b.timer -= gm
			if b.timer <= 0:
				var from = int(b.get("bin_id",-1))
				var item: Dictionary = sim.model.item_by_id(from)
				var pieces = 0
				if not item.is_empty():
					pieces = int(item.get("waste",0))
					item.erase("waste")
					refresh(sim,item)
				release(sim,a)
				a.play("idle")
				var spot = container_spot(sim,a) if pieces > 0 else {}
				if not spot.is_empty() and sim.go(a,spot.stand):
					b.bag = pieces
					b.bag_from = from
					b.dump_at = spot.at
					b.state = "to_container"
					a.set_carry(true)
				else:
					b.state = "back"
					if not sim.go(a,b.post): b.state = "post"
			return true
		"to_container":
			if arrived:
				a.face(b.get("dump_at",a.world)-a.world)
				a.play("work")
				b.timer = DUMP_MINUTES
				b.state = "dumping"
			return true
		"dumping":
			b.timer -= gm
			if b.timer <= 0:
				for key in ["bag","bag_from","dump_at"]: b.erase(key)
				a.set_carry(false)
				sim.night.bins_emptied = int(sim.night.get("bins_emptied",0))+1
				a.play("idle")
				b.state = "back"
				if not sim.go(a,b.post): b.state = "post"
			return true
		"post", "idle", "back":
			var item = bin_to_empty(sim,a)
			if item.is_empty() or not sim.go(a,approach(sim,item)): return false
			sim.bins_taken[int(item.id)] = a
			b.bin_id = int(item.id)
			b.state = "to_bin_empty"
			return true
	return false

static func release(sim, a: Actor) -> void:
	# the bin she was going to empty is free for another maid
	var id = int(a.brain.get("bin_id",-1))
	if sim.bins_taken.get(id) == a: sim.bins_taken.erase(id)
	a.brain.erase("bin_id")

static func interrupt(sim, a: Actor) -> void:
	# called away (a couple in the room, end of her shift): a bag in hand goes
	# back in its bin, or out if the bin is gone
	var b: Dictionary = a.brain
	if b.has("bag"):
		var item: Dictionary = sim.model.item_by_id(int(b.get("bag_from",-1)))
		if not item.is_empty():
			item.waste = mini(CAPACITY,int(item.get("waste",0))+int(b.bag))
			refresh(sim,item)
		for key in ["bag","bag_from","dump_at"]: b.erase(key)
	release(sim,a)
	a.set_carry(false)

static func refresh(sim, item: Dictionary) -> void:
	if sim.view != null: sim.view.refresh_bin(int(item.id))
