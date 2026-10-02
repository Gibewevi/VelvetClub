class_name Cloakroom
extends RefCounted

# Coats at the cloakroom. Some clients come with a coat (more of them when it
# rains); after paying at the desk they leave it on a rack or in a locker,
# and take it back on their way out. A rack or a locker fills up with the
# evening's crowd, a few coats at a time; when there is no room left, the
# client keeps his coat and is a little less pleased.

const CAPACITY = {"coat_rack":12,"cloak_locker":30}
const COAT_CHANCE = 0.4
const COAT_CHANCE_RAIN = 0.75
const HAND_MINUTES = 0.8
const FULL_PENALTY = 4.0

static func has_coat(sim) -> bool:
	return sim.rng.randf() < (COAT_CHANCE_RAIN if float(sim.rain_strength) > 0.1 else COAT_CHANCE)

static func used(sim, id: int) -> int:
	# coats hanging there, and clients on their way to hang one
	var n = 0
	for c in sim.clients:
		if not is_instance_valid(c): continue
		var b: Dictionary = c.brain
		if int(b.get("coat_at",-1)) == id: n += 1
		elif int(b.get("coat_to",-1)) == id and b.get("state","") in ["to_cloak","cloak_in"]: n += 1
	return n

static func front(sim, item: Dictionary) -> Vector2:
	# where a client stands to use it: in front, a little to one side or the other
	var size: Vector2 = Catalog.ITEMS[item.kind].size
	var p = Catalog.local_to_world(item,Vector2(sim.rng.randf_range(-0.3,0.3)*size.x,size.y/2.0+0.45))
	var c = sim.nav.free_cell_near(p)
	return sim.nav.center(c) if c.x != 9999 else p

static func place_for(sim, a: Actor) -> Dictionary:
	# the nearest rack or locker with room left that the client can reach
	var best: Dictionary = {}
	var best_d = INF
	for item in sim.model.furniture:
		if not CAPACITY.has(item.kind) or item.get("delivery_pending",false): continue
		if used(sim,int(item.id)) >= int(CAPACITY[item.kind]): continue
		var at = front(sim,item)
		var d = at.distance_squared_to(a.world)
		if d >= best_d or not sim.nav.reachable(a.world,at): continue
		best_d = d
		best = {"item":int(item.id),"pos":at}
	return best

static func deposit(sim, a: Actor) -> bool:
	# Called when the client is free to choose what to do; true when he goes
	# to the cloakroom first.
	var b: Dictionary = a.brain
	if not b.get("coat",false) or b.get("coat_done",false) or not b.get("paid",true): return false
	var spot = place_for(sim,a)
	b.coat_done = true
	if spot.is_empty():
		var any = sim.model.furniture.any(func(i): return CAPACITY.has(i.kind) and not i.get("delivery_pending",false))
		b.sat -= FULL_PENALTY
		sim.hint("cloak","Vestiaire plein : ajoutez un portant ou des casiers (plus grands) près de l'accueil." if any else "Pas de vestiaire : les clients gardent leur manteau. Un portant ou des casiers près de l'accueil les mettraient à l'aise.",240.0)
		return false
	if not sim.go(a,spot.pos): return false
	b.coat_to = spot.item
	b.state = "to_cloak"
	b.activity = "cloak"
	return true

static func collect(sim, a: Actor) -> bool:
	# Called when the client leaves; true when he first fetches his coat.
	var b: Dictionary = a.brain
	var id = int(b.get("coat_at",-1))
	if id < 0: return false
	var item: Dictionary = sim.model.item_by_id(id)
	if item.is_empty():
		b.erase("coat_at")
		return false
	var at = front(sim,item)
	if not sim.nav.reachable(a.world,at) or not sim.go(a,at): return false
	b.state = "to_cloak_out"
	b.activity = "cloak"
	return true

static func tick(sim, a: Actor, arrived: bool, gm: float) -> bool:
	var b: Dictionary = a.brain
	match String(b.get("state","")):
		"to_cloak", "to_cloak_out":
			if arrived:
				var item: Dictionary = sim.model.item_by_id(int(b.get("coat_to" if b.state == "to_cloak" else "coat_at",-1)))
				if not item.is_empty(): a.face(Vector2(item.x,item.z)-a.world)
				a.play("work")
				b.timer = HAND_MINUTES
				b.state = "cloak_in" if b.state == "to_cloak" else "cloak_out"
			return true
		"cloak_in":
			b.timer -= gm
			if b.timer <= 0:
				var id = int(b.get("coat_to",-1))
				b.erase("coat_to")
				if not sim.model.item_by_id(id).is_empty():
					b.coat_at = id
					refresh(sim,id)
				a.play("idle")
				b.state = "choose"
			return true
		"cloak_out":
			b.timer -= gm
			if b.timer <= 0:
				var id = int(b.get("coat_at",-1))
				b.erase("coat_at")
				refresh(sim,id)
				a.play("idle")
				sim.head_out(a)
			return true
	return false

static func forget(sim, a: Actor) -> void:
	# a client gone without his coat (sent away): the hanger is free again
	var id = int(a.brain.get("coat_at",-1))
	if id >= 0:
		a.brain.erase("coat_at")
		refresh(sim,id)

static func refresh(sim, id: int) -> void:
	var item: Dictionary = sim.model.item_by_id(id)
	if item.is_empty() or not CAPACITY.has(item.kind) or sim.view == null: return
	sim.view.set_cloak_fill(id,float(used(sim,id))/float(CAPACITY[item.kind]))
