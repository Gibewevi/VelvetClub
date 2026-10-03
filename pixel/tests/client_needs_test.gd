extends SceneTree

var checks = 0
var failures = 0
var model: BuildingModel
var world: WorldView
var sim: ClubSim
var wc: int
var old_wc: int
var urinal: int
var maid_id: int
var bar_id: int

func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+text)

func _init() -> void:
	run.call_deferred()

func guest(body: int, pos: Vector2 = Vector2(0,1)) -> Actor:
	sim.spawn_client()
	var a: Actor = sim.clients.back()
	sim.queue.erase(a)
	a.configure(Characters.defaults("man" if body == 1 else "woman"))
	a.set_world(pos)
	a.path = []
	a.brain.merge({"paid":true,"state":"busy","activity":"look","timer":9999.0,"sat":90.0,"plan":99,"bladder":20.0,"digestion":0.0,"drinks":0},true)
	return a

func run() -> void:
	Art.load_all()
	model = BuildingModel.new()
	model.add_room(-5,-3,10,8,0)
	model.add_room(-5,-7,5,4,2)
	model.set_opening("x:0:5","door")
	model.set_opening("x:-3:-3","door")
	wc = model.add_item("toilet",-4,-6.4,0)
	old_wc = model.add_item("old_toilet",-2.4,-6.4,0)
	urinal = model.add_item("urinal",-.8,-6.7,0)
	model.add_item("sink",-.6,-4.2,0)
	var counter_id = model.add_item("bar",2,0,0)
	var shelf_id = model.add_item("bottles_small",2,-2,0)
	bar_id = model.add_item("bartender",2,-.9,0)
	maid_id = model.add_item("maid",-3,2,0)
	check(wc != -1 and old_wc != -1 and urinal != -1 and maid_id != -1 and bar_id != -1,"Fixture and staff test layout fits")
	world = WorldView.new()
	root.add_child(world)
	world.setup(model)
	sim = ClubSim.new()
	root.add_child(sim)
	sim.setup(model,world)
	sim.active = false
	sim.open = true
	var male = guest(1)
	var female = guest(0,Vector2(1,2))
	check(ClientNeeds.find_toilet(sim,male).get("item",-1) == urinal,"Men prefer an available reachable urinal")
	check(ClientNeeds.find_toilet(sim,female).get("item",-1) in [wc,old_wc],"Women choose a WC")
	check(not ClientNeeds.compatible(female,model.item_by_id(urinal)),"Women never use urinals")
	check(ClientNeeds.compatible(male,model.item_by_id(wc)) and ClientNeeds.compatible(male,model.item_by_id(old_wc)),"Men may use either kind of WC")
	var sinks = model.furniture.filter(func(i): return i.kind == "sink")
	check(not ClientNeeds.compatible(male,sinks[0]),"Sinks are not toilets")
	model.item_by_id(urinal).delivery_pending = true
	check(ClientNeeds.find_toilet(sim,male).get("item",-1) in [wc,old_wc],"A ghost urinal cannot be used")
	model.item_by_id(urinal).erase("delivery_pending")
	model.openings.erase("x:-3:-3")
	sim.nav.rebuild(model)
	check(ClientNeeds.find_toilet(sim,male).is_empty(),"A closed-off sanitary room is inaccessible")
	model.set_opening("x:-3:-3","door")
	sim.nav.rebuild(model)
	var bathroom_spots = sim.all_spots().filter(func(s): return s.item in [wc,old_wc])
	for s in bathroom_spots: sim.reserved[sim.spot_key(s)] = male
	female.brain.bladder = 75.0
	ClientNeeds.tick(sim,female,1.0,true)
	check(female.brain.state == "toilet_wait","Women wait while both WCs are occupied despite a free urinal")
	sim.reserved.clear()
	ClientNeeds.tick(sim,female,2.1,true)
	check(female.brain.state == "toilet_walk" and female.brain.spot.item in [wc,old_wc],"Waiting client takes a WC after it is freed")
	var reserved_key = sim.spot_key(female.brain.spot)
	check(sim.reserved.get(reserved_key) == female,"Toilet is reserved during the walk")
	var before_visits: int = female.brain.visits
	for tick in range(400):
		sim.client_ai(female,.05)
		if female.brain.state == "toilet_use": break
	check(female.brain.state == "toilet_use" and female.anim == "sit","Client physically reaches and sits on the WC clothed")
	for tick in range(350):
		sim.client_ai(female,.05)
		if female.brain.state == "choose": break
	check(female.brain.bladder == 0.0 and female.brain.state == "choose","A completed visit relieves the need")
	check(not sim.reserved.has(reserved_key) and female.brain.visits == before_visits,"Using WC releases the reservation without consuming an entertainment visit")
	check(sim.night.toilet_visits == 1,"One toilet visit is counted")
	# A bar alone has no effect. Only a paid serving increases pressure.
	ClientNeeds.tick(sim,male,10.0,true)
	check(is_equal_approx(male.brain.bladder,21.8),"Without drinking, a bar does not magically accelerate bladder pressure")
	male.brain.bladder = 20.0
	male.brain.activity = "bar"
	sim.bar_stock.set_stock(model.item_by_id(shelf_id),48)
	sim.staff[bar_id].brain.bar_id = counter_id
	sim.staff[bar_id].brain.state = "working"
	sim.start_activity(male)
	check(male.brain.drinks in [1,2] and male.brain.bladder > 20.0 and male.brain.digestion > 0,"Drinks actually served at the bar increase pressure and digestion")
	var pressure: float = male.brain.bladder
	ClientNeeds.tick(sim,male,1.0,true)
	check(is_equal_approx(male.brain.bladder-pressure,.83),"Drinking accelerates subsequent pressure growth")
	var drinks: int = male.brain.drinks
	sim.staff[bar_id].brain.state = "free"
	male.brain.activity = "bar"
	sim.start_activity(male)
	check(male.brain.drinks == drinks,"An unstaffed bar serves no imaginary drinks")
	# Fixture removal while on the way must release a stale reservation.
	sim.release(male)
	male.brain.state = "busy"
	male.brain.bladder = 70.0
	ClientNeeds.tick(sim,male,.1,true)
	check(male.brain.get("spot",{}).get("item",-1) == urinal,"Urgent man heads to the urinal")
	model.item_by_id(urinal).delivery_pending = true
	ClientNeeds.tick(sim,male,.1,false)
	check(male.brain.get("spot",{}).get("item",-1) != urinal,"Newly unavailable urinal is abandoned")
	model.item_by_id(urinal).erase("delivery_pending")
	sim.release(male)
	sim.release(female)
	male.path = []
	female.path = []
	# No female-compatible facility: visible accident, reaction, reputation.
	for id in [wc,old_wc]: model.item_by_id(id).delivery_pending = true
	female.set_world(Vector2(0,2))
	female.brain.state = "busy"
	female.brain.bladder = 99.95
	female.brain.digestion = 0.0
	male.set_world(Vector2(.5,2))
	male.brain.state = "busy"
	male.brain.sat = 29.0
	var rating = sim.rating
	ClientNeeds.tick(sim,female,1.0,true)
	check(sim.dirt.size() == 1 and sim.dirt[0].kind == "urine","Failure to reach a compatible toilet leaves a urine puddle")
	check(sim.dirt[0].node.texture == Art.tex(Art.sanitary.puddles.urine[1]),"Accident has the yellow puddle asset")
	check(female.brain.state == "leave" and male.brain.state == "leave","Embarrassed client and unhappy nearby witness leave")
	check(sim.rating < rating and sim.night.accidents == 1,"Incident damages reputation exactly once")
	ClientNeeds.tick(sim,female,20.0,true)
	check(sim.night.accidents == 1,"Leaving client cannot repeatedly cause accidents")
	var saved = JSON.parse_string(JSON.stringify(sim.to_dict()))
	check(saved.dirt.size() == 1 and saved.dirt[0].kind == "urine","Save data includes puddle type and coordinates")
	var pos: Vector2 = sim.dirt[0].pos
	sim.from_dict(saved)
	check(sim.dirt.size() == 1 and sim.dirt[0].pos == pos,"Save round-trip keeps the puddle at the same position")
	var maid: Actor = sim.staff[maid_id]
	sim.staff_ai(maid,.1)
	check(maid.brain.state == "to_dirt" and sim.dirt[0].taken == maid,"Maid reserves a reachable puddle")
	for tick in range(300):
		sim.staff_ai(maid,.05)
		if maid.brain.state == "mopping": break
	check(maid.brain.state == "mopping" and maid.anim == "mop","Maid reaches the puddle and mops")
	var timer: float = maid.brain.timer
	sim.active = true
	sim.speed = 0
	sim._process(20)
	check(maid.brain.timer == timer and sim.dirt.size() == 1,"Pausing freezes cleaning")
	sim.active = false
	for tick in range(80): sim.staff_ai(maid,.05)
	check(sim.dirt.is_empty() and sim.night.dirt_cleaned == 1,"Cleaning actually removes the puddle")
	# Skip a nearer inaccessible puddle instead of starving all cleaning work.
	sim.add_dirt(Vector2(-3,-4),"urine")
	sim.add_dirt(Vector2(2,3),"urine")
	model.openings.erase("x:-3:-3")
	sim.nav.rebuild(model)
	maid.set_world(Vector2(-3,-2))
	maid.path = []
	maid.brain.state = "post"
	sim.staff_ai(maid,.1)
	check(maid.brain.state == "to_dirt" and maid.brain.dirt.pos.y > 0,"Cleaner skips an inaccessible nearer spill")
	sim.layout_changed()
	check(not maid.brain.has("dirt") and sim.dirt.all(func(d): return d.taken == null),"Layout edits release cleaning claims")
	sim.from_dict({"dirt":[{"x":"bad","z":0},{"x":10000,"z":1},{"x":1,"z":1,"kind":"unknown"}]})
	check(sim.dirt.is_empty(),"Malformed or out-of-bounds saved puddles are ignored")
	sim.from_dict({"money":200})
	check(sim.dirt.is_empty(),"Old saves without puddles remain compatible")
	for c in sim.clients.duplicate(): sim.remove_client(c)
	sim.queue_free()
	world.queue_free()
	await process_frame
	print("CLIENT_NEEDS_TESTS: %d checks, %d failures" % [checks,failures])
	if failures == 0: print("CLIENT_NEEDS_TESTS_PASSED")
	quit(1 if failures > 0 else 0)
