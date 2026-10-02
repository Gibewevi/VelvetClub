class_name ClientNeeds
extends RefCounted

# Values are gameplay pressure, not real physiology. Time uses game minutes.
const SEEK = 65.0
const URGENT = 85.0
const BASE_RATE = .18
const DRINK_RATE = .65
const FIXTURES = ["toilet","old_toilet","urinal"]

static func drink(a: Actor, count: int) -> void:
	a.brain.drinks = int(a.brain.get("drinks",0))+count
	a.brain.bladder = minf(99.0,float(a.brain.get("bladder",20.0))+22.0*count)
	a.brain.digestion = minf(90.0,float(a.brain.get("digestion",0.0))+35.0*count)

static func compatible(a: Actor, item: Dictionary) -> bool:
	return not item.get("delivery_pending",false) and (item.get("kind","") in ["toilet","old_toilet"] or (item.get("kind","") == "urinal" and int(a.appearance.get("body",0)) == 1))

static func accessible(sim, a: Actor, s: Dictionary) -> bool:
	var item: Dictionary = sim.model.item_by_id(int(s.get("item",-1)))
	if not compatible(a,item): return false
	var room: Dictionary = sim.model.room_at(Vector2(item.x,item.z))
	return not room.is_empty() and Sanitation.usable(sim,a,s)

static func find_toilet(sim, a: Actor) -> Dictionary:
	var candidates: Array = []
	for s in sim.all_spots():
		if sim.reserved.has(sim.spot_key(s)) or not accessible(sim,a,s) or not Sanitation.first_for(sim,a,s): continue
		candidates.append(s)
	# Men use a free reachable urinal first, keeping shared WCs available.
	candidates.sort_custom(func(x,y):
		var ux = sim.model.item_by_id(x.item).kind == "urinal"
		var uy = sim.model.item_by_id(y.item).kind == "urinal"
		return ux if ux != uy else x.pos.distance_squared_to(a.world) < y.pos.distance_squared_to(a.world))
	return {} if candidates.is_empty() else candidates[0]

static func detach(sim, a: Actor) -> void:
	var escort = a.brain.get("escort")
	if is_instance_valid(escort): sim.drop_client(escort)
	sim.release(a)
	a.path = []
	a.lift = 0
	a.play("idle")

static func seek(sim, a: Actor) -> void:
	if a.brain.state != "toilet_wait": detach(sim,a)
	var s = find_toilet(sim,a)
	a.brain.need_retry = 2.0
	if not s.is_empty() and sim.go_spot(a,s):
		Sanitation.forget(sim,a)
		a.brain.state = "toilet_walk"
		a.brain.activity = "toilet_seek"
	else:
		a.brain.state = "toilet_wait"
		a.brain.activity = "toilet_wait"
		Sanitation.wait_in_line(sim,a)
		sim.hint("sanitary_access",a.brain.wait_reason+". Vérifiez la capacité et les accès.",60.0)
	a.emote("wc_urgent" if float(a.brain.get("bladder",0)) >= URGENT else "wc",2.0)

static func accident(sim, a: Actor) -> void:
	var b = a.brain
	sim.profiles.remember(str(b.get("profile_id","")),sim.day,"Un accident sanitaire a écourté la visite.")
	detach(sim,a)
	sim.add_dirt(a.world,"urine")
	b.bladder = 0.0
	b.sat = maxf(0.0,float(b.sat)-35.0)
	sim.rating = maxf(.5,sim.rating-.06)
	sim.night.accidents = int(sim.night.get("accidents",0))+1
	a.emote("help",2.5)
	for other in sim.clients.duplicate():
		if other == a or not is_instance_valid(other) or not other.brain.get("paid",false) or other.brain.state in ["leave","to_cloak_out","cloak_out"]: continue
		if other.world.distance_to(a.world) > 3.0 or sim.model.room_at(other.world) != sim.model.room_at(a.world): continue
		other.brain.sat = maxf(0.0,float(other.brain.sat)-10.0)
		other.emote("help",2.0)
		if not other.brain.has("service") and (other.brain.sat < 30.0 or sim.rng.randf() < .25): sim.leave(other)
	sim.hint("sanitary_accident","Accident : une flaque au sol mécontente les clients. Prévoyez des sanitaires accessibles et du personnel de ménage.",25.0)
	sim.leave(a)
	sim.stats_changed.emit()

static func tick(sim, a: Actor, gm: float, arrived: bool) -> bool:
	var b = a.brain
	if gm <= 0 or not b.get("paid",false) or b.state in ["enter","entering","to_desk","checkin","queue","to_queue","leave","to_cloak","cloak_in","to_cloak_out","cloak_out"]: return false
	if sim.model.room_at(a.world).is_empty(): return false
	if Sanitation.wash_tick(sim,a,gm,arrived): return true
	var dirty: int = sim.dirt_near(a.world,3.0)
	if dirty > 0:
		b.sat = maxf(0.0,float(b.sat)-.35*mini(dirty,3)*gm*float(b.get("cleanliness",1.0)))
		if b.sat < 18.0 and not b.has("service"):
			sim.leave(a)
			return true
	if b.state == "toilet_use":
		if not accessible(sim,a,b.get("spot",{})):
			seek(sim,a)
			return true
		b.bladder = maxf(0.0,float(b.get("bladder",0.0))-25.0*gm)
		b.timer -= gm
		if b.timer <= 0:
			b.bladder = 0.0
			b.sat = minf(100.0,float(b.sat)+3.0)
			sim.night.toilet_visits = int(sim.night.get("toilet_visits",0))+1
			var exit: Vector2 = b.spot.pos
			var fixture: Dictionary = sim.model.item_by_id(b.spot.item)
			if float(fixture.get("soil",0)) >= 60: b.sat = maxf(0,float(b.sat)-5)
			Sanitation.soil(fixture,sim.maintenance_rng.randf_range(6.0,10.0))
			Plumbing.after_use(sim,fixture)
			sim.release(a)
			a.set_world(exit)
			a.lift = 0
			a.play("idle")
			b.wash_left = 5.0
			Sanitation.wash(sim,a)
		return true
	var digestion = minf(gm,float(b.get("digestion",0.0)))
	b.digestion = maxf(0.0,float(b.get("digestion",0.0))-gm)
	b.bladder = minf(100.0,float(b.get("bladder",20.0))+BASE_RATE*gm+DRINK_RATE*digestion)
	# Finish an already agreed private visit; urgent clients then head to WC.
	if b.has("service"):
		b.bladder = minf(98.0,b.bladder)
		return false
	if b.bladder >= SEEK:
		b.need_emote = float(b.get("need_emote",0.0))-gm
		if b.need_emote <= 0:
			a.emote("wc_urgent" if b.bladder >= URGENT else "wc",1.8)
			b.need_emote = 3.0
	if b.bladder >= 100.0:
		accident(sim,a)
		return true
	if b.bladder >= URGENT: b.sat = maxf(0.0,float(b.sat)-.15*gm)
	if b.state == "toilet_walk":
		if not accessible(sim,a,b.get("spot",{})):
			seek(sim,a)
		elif arrived:
			var s: Dictionary = b.spot
			var item: Dictionary = sim.model.item_by_id(s.item)
			sim.settle(a)
			if item.kind != "urinal":
				a.set_world(Catalog.local_to_world(item,Vector2(0,.12)))
				a.face(Catalog.direction_to_world(item,Vector2(0,1)))
				a.play("sit")
			b.state = "toilet_use"
			a.bubble_time = 0
			b.activity = "toilet"
			b.timer = 5.0
		return true
	if b.state == "toilet_wait":
		b.need_wait = float(b.get("need_wait",0.0))+gm
		# Most visitors leave before an accident; a small patient minority risks waiting.
		if not b.has("wc_patience"):
			b.wc_patience = sim.rng.randf_range(12.0,28.0)
			b.wc_risk = sim.rng.randf() < .08
		if not b.wc_risk and (b.need_wait >= b.wc_patience or b.bladder >= 94):
			b.sat = maxf(0,float(b.sat)-12)
			sim.night.sanitary_departures = int(sim.night.get("sanitary_departures",0))+1
			sim.hint("sanitary_departure","Un client est parti : attente trop longue aux sanitaires.",45)
			sim.leave(a)
			return true
		if b.need_wait >= 8:
			sim.sanitary_saturated_until = sim.elapsed+20
			sim.hint("sanitary_capacity","Sanitaires saturés : ajoutez des WC ou des urinoirs et vérifiez leurs accès.",90)
		b.need_retry = float(b.get("need_retry",0.0))-gm
		if b.need_retry <= 0: seek(sim,a)
		return true
	if b.bladder >= SEEK:
		seek(sim,a)
		return true
	return false
