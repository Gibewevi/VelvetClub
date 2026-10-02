class_name Sanitation
extends RefCounted

const SINKS = ["sink","old_sink"]
const FIXTURES = ["toilet","old_toilet","urinal","sink","old_sink"]
const UPGRADES = {
	"easy_clean":{"name":"Revêtement lavable","price":120,"effect":"Salissure et temps d'entretien divisés par deux."},
	"soap":{"name":"Distributeur de savon","price":60,"effect":"Lavage plus rapide et satisfaction améliorée."},
	"cleaning_kit":{"name":"Kit de ménage amélioré","price":180,"effect":"Tous les travaux de ménage sont 40 % plus rapides."}}

static func upgrades_for(kind: String) -> Array:
	if kind in Catalog.CLEANERS: return ["cleaning_kit"]
	if kind in SINKS: return ["easy_clean","soap"]
	if kind in FIXTURES or kind == "shower": return ["easy_clean"]
	return []

static func value(item: Dictionary) -> int:
	var total = 0
	for key in upgrades_for(item.kind):
		if item.get(key,false) == true: total += UPGRADES[key].price
	return total

static func usable(sim, a: Actor, s: Dictionary, allow_broken: bool = false) -> bool:
	var item: Dictionary = sim.model.item_by_id(s.get("item",-1))
	if item.is_empty() or item.get("delivery_pending",false): return false
	if not allow_broken and item.get("leaking",false): return false
	var room: Dictionary = sim.model.room_at(Vector2(item.x,item.z))
	return not room.is_empty() and not sim.room_private(room) and sim.model.room_at(s.pos) == room and sim.nav.walkable(s.pos) and sim.nav.reachable(a.world,s.pos)

static func soil(item: Dictionary, amount: float) -> void:
	# a fixture cleaned with care stays clean a little longer
	item.soil = clampf(float(item.get("soil",0.0))+amount*(.5 if item.get("easy_clean",false) else 1.0)*(1.0-float(item.get("shine",0.0))),0,100)

static func forget(sim, a: Actor) -> void:
	sim.sanitary_queue.erase(a)
	for key in ["wc_slot","wc_anchor","wc_room","wc_rank","wait_reason","need_wait"]: a.brain.erase(key)

static func first_for(sim, a: Actor, spot: Dictionary) -> bool:
	for other in sim.sanitary_queue:
		if other == a: return true
		if is_instance_valid(other) and other.brain.state == "toilet_wait" and ClientNeeds.accessible(sim,other,spot): return false
	return true

static func doors(sim) -> Array:
	var out: Array = []
	for key in sim.model.openings:
		if sim.model.openings[key] != "door": continue
		var p = key.split(":")
		out.append({"pos":Vector2(float(p[1])+.5,float(p[2])) if p[0] == "x" else Vector2(float(p[1]),float(p[2])+.5),"normal":Vector2(0,1) if p[0] == "x" else Vector2(1,0)})
	return out

static func wait_in_line(sim, a: Actor) -> void:
	var found = false
	var broken = false
	var reachable: Array = []
	for s in sim.all_spots():
		if ClientNeeds.compatible(a,sim.model.item_by_id(s.item)):
			found = true
			if sim.model.item_by_id(s.item).get("leaking",false): broken = true
			if ClientNeeds.accessible(sim,a,s): reachable.append(s)
	var b = a.brain
	b.wait_reason = "Aucun WC adapté" if not found else (("Sanitaires en panne : technicien requis" if broken else "Accès aux sanitaires bloqué") if reachable.is_empty() else "Tous les sanitaires adaptés sont occupés")
	if reachable.is_empty():
		sim.sanitary_queue.erase(a)
		b.erase("wc_slot")
		b.erase("wc_rank")
		return
	if not a in sim.sanitary_queue: sim.sanitary_queue.append(a)
	reachable.sort_custom(func(x,y): return x.pos.distance_squared_to(a.world) < y.pos.distance_squared_to(a.world))
	var fixture: Dictionary = sim.model.item_by_id(reachable[0].item)
	var room: Dictionary = sim.model.room_at(Vector2(fixture.x,fixture.z))
	b.wc_room = room.id
	var anchor: Vector2 = reachable[0].pos-reachable[0].face.normalized()*1.25
	var door_list = doors(sim)
	# Wait beside the bathroom door on the public side, leaving the doorway clear.
	var best = INF
	for door in door_list:
		for sign_dir in [-1,1]:
			var inside: Vector2 = door.pos+door.normal*.5*sign_dir
			var public_side: Dictionary = sim.model.room_at(door.pos-door.normal*.5*sign_dir)
			if sim.model.room_at(inside) != room or public_side.is_empty() or public_side == room: continue
			var along: Vector2 = Vector2(door.normal.y,-door.normal.x)
			# Furniture near a doorway must not force the whole line into the bathroom.
			for depth in [1.0,1.5,2.0]:
				for offset in [0.0,-1.0,1.0,-1.5,1.5]:
					var outside: Vector2 = door.pos-door.normal*depth*sign_dir+along*offset
					if sim.model.room_at(outside) != public_side or not sim.nav.walkable(outside) or not sim.nav.reachable(a.world,outside): continue
					var d = outside.distance_squared_to(Vector2(fixture.x,fixture.z))
					if d < best:
						best = d
						anchor = outside
	b.wc_anchor = anchor
	var used: Array = []
	for other in sim.sanitary_queue:
		if is_instance_valid(other) and other.brain.get("wc_room",-1) != room.id and other.brain.has("wc_slot"): used.append(other.brain.wc_slot)
	var previous = anchor
	var rank = 0
	for waiter in sim.sanitary_queue:
		if not is_instance_valid(waiter) or waiter.brain.get("wc_room",-1) != room.id: continue
		rank += 1
		var choice = Vector2.INF
		var score = INF
		# A line bends around furniture when necessary. Stable grid positions prevent jitter.
		for dx in range(-8,9):
			for dz in range(-8,9):
				var p: Vector2 = sim.nav.center(sim.nav.cell_of(anchor)+Vector2i(dx,dz))
				if not sim.nav.walkable(p) or sim.model.room_at(p) != sim.model.room_at(anchor): continue
				if used.any(func(q): return q.distance_to(p) < 1.1 or (absf((q-p).x-(q-p).y) < 1.2 and absf((q-p).x+(q-p).y) < 1.8)): continue
				if door_list.any(func(d): return d.pos.distance_to(p) < 1.05): continue
				if reachable.any(func(s): return s.pos.distance_to(p) < 1.0): continue
				var cost = p.distance_squared_to(previous)+p.distance_squared_to(anchor)*.08
				# Favor a visible diagonal row over silhouettes stacked vertically on screen.
				cost += absf((p-previous).x+(p-previous).y)*.35
				if cost >= score or not sim.nav.reachable(waiter.world,p): continue
				score = cost
				choice = p
		waiter.brain.wc_rank = rank
		if choice == Vector2.INF: continue
		used.append(choice)
		previous = choice
		if waiter.brain.get("wc_slot",Vector2.INF) != choice:
			waiter.brain.wc_slot = choice
			sim.go(waiter,choice)
		if waiter.path.is_empty(): waiter.face(anchor-waiter.world)

static func status(sim) -> String:
	var count = sim.sanitary_queue.size()
	var delayed = false
	for a in sim.sanitary_queue:
		if is_instance_valid(a) and float(a.brain.get("need_wait",0)) >= 8: delayed = true
	return ("Sanitaires saturés" if delayed else "File sanitaires")+" : %d en attente" % count

static func wash(sim, a: Actor) -> void:
	var candidates: Array = []
	for s in sim.all_spots():
		if sim.model.item_by_id(s.item).kind in SINKS and usable(sim,a,s) and not sim.reserved.has(sim.spot_key(s)): candidates.append(s)
	candidates.sort_custom(func(x,y): return x.pos.distance_squared_to(a.world) < y.pos.distance_squared_to(a.world))
	if not candidates.is_empty() and sim.go_spot(a,candidates[0]):
		a.brain.state = "wash_walk"
		a.brain.activity = "wash_hands"
		return
	# A short bounded wait avoids congestion becoming an endless second queue.
	a.brain.state = "wash_wait"
	a.brain.activity = "wash_wait"
	a.brain.wash_retry = 1.0

static func wash_tick(sim, a: Actor, gm: float, arrived: bool) -> bool:
	var b = a.brain
	if not b.state in ["wash_walk","wash_wait","washing_hands"]: return false
	if b.state == "wash_wait":
		b.wash_left = float(b.get("wash_left",5.0))-gm
		b.wash_retry = float(b.get("wash_retry",0.0))-gm
		if b.wash_left <= 0:
			b.sat = maxf(0,float(b.sat)-2)
			b.state = "choose"
			b.activity = "look"
			sim.hint("no_sink","Un lavabo accessible et libre permet aux clients de se laver les mains.",90)
		elif b.wash_retry <= 0: wash(sim,a)
		return true
	var s: Dictionary = b.get("spot",{})
	if not usable(sim,a,s):
		sim.release(a)
		a.path = []
		wash(sim,a)
		return true
	var item: Dictionary = sim.model.item_by_id(s.item)
	if b.state == "wash_walk" and arrived:
		sim.settle(a)
		a.play("work")
		a.emote("wash",2)
		b.state = "washing_hands"
		b.timer = 2.5 if item.get("soap",false) else 4.0
	elif b.state == "washing_hands":
		b.timer -= gm
		if b.timer <= 0:
			soil(item,8)
			Plumbing.after_use(sim,item)
			b.sat = minf(100,float(b.sat)+(3 if item.get("soap",false) else 1))
			sim.night.handwashes = int(sim.night.get("handwashes",0))+1
			sim.release(a)
			b.state = "choose"
			b.activity = "look"
			a.play("idle")
	return true

static func cleaning_factor(sim, a: Actor) -> float:
	return (.6 if sim.model.item_by_id(a.item_id).get("cleaning_kit",false) else 1.0)*sim.profiles.employee_factor(str(a.brain.get("profile_id","")))

static func fixture_spills(sim, item: Dictionary) -> Array:
	return sim.dirt.filter(func(d): return int(d.get("fixture",-1)) == int(item.get("id",-2)))

static func needs_cleaning(sim, item: Dictionary) -> bool:
	return float(item.get("soil",0)) >= 100 or not fixture_spills(sim,item).is_empty()

static func cleaner_tick(sim, a: Actor, arrived: bool, gm: float) -> bool:
	var b = a.brain
	if b.state in ["to_fixture","cleaning_fixture"]:
		var s: Dictionary = b.get("spot",{})
		if not usable(sim,a,s):
			sim.release(a)
			a.path = []
			b.state = "post"
			return true
		var item: Dictionary = sim.model.item_by_id(s.item)
		if b.state == "to_fixture" and arrived:
			sim.settle(a)
			a.play("mop")
			b.state = "cleaning_fixture"
			var work = 4.0+float(item.get("soil",0))*.05
			for spill in fixture_spills(sim,item): work += float(spill.work)
			b.timer = work*(.5 if item.get("easy_clean",false) else 1.0)*cleaning_factor(sim,a)
		elif b.state == "cleaning_fixture":
			b.timer -= gm
			if b.timer <= 0:
				# a careless cleaner leaves some of the dirt, a careful one a shine
				var care = float(b.get("quality",1.0))
				item.soil = clampf((1.0-care)*120.0,0.0,40.0)
				if care > 1.0: item.shine = snappedf(clampf(care-1.0,0.0,0.3),0.01)
				else: item.erase("shine")
				for spill in fixture_spills(sim,item):
					spill.node.queue_free()
					sim.dirt.erase(spill)
					sim.night.dirt_cleaned = int(sim.night.get("dirt_cleaned",0))+1
				sim.view.refresh_sanitary(item,sim.maintenance_clock)
				sim.release(a)
				b.state = "back"
				if not sim.go(a,b.post): b.state = "post"
		return true
	if b.state in ["post","idle","back"]:
		for item in sim.model.furniture:
			if not item.kind in Plumbing.KINDS or not needs_cleaning(sim,item): continue
			var s = Plumbing.service_spot(item)
			if s.is_empty() or sim.reserved.has(sim.spot_key(s)) or not usable(sim,a,s): continue
			if sim.go_spot(a,s):
				b.state = "to_fixture"
				return true
	return false
