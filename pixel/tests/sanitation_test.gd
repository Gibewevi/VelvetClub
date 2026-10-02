extends SceneTree

var checks = 0
var failures = 0
var model: BuildingModel
var world: WorldView
var sim: ClubSim
var wc: int
var sink: int
var urinal: int
var maid_id: int

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+message)

func _init() -> void:
	run.call_deferred()

func guest(body: int = 0) -> Actor:
	sim.spawn_client()
	var a: Actor = sim.clients.back()
	sim.queue.erase(a)
	a.configure(Characters.defaults("man" if body == 1 else "woman"))
	a.set_world(Vector2(0,1))
	a.path = []
	a.brain.merge({"paid":true,"state":"busy","activity":"look","timer":9999.0,"sat":90.0,"plan":99,"bladder":70.0,"digestion":0.0,"drinks":0,"wc_patience":100.0,"wc_risk":true},true)
	return a

func run() -> void:
	Art.load_all()
	model = BuildingModel.new()
	model.add_room(-5,-3,10,8,0)
	model.add_room(-5,-7,5,4,2)
	model.set_opening("x:0:5","door")
	model.set_opening("x:-3:-3","door")
	wc = model.add_item("toilet",-4,-6.4,0)
	urinal = model.add_item("urinal",-1,-6.7,0)
	sink = model.add_item("old_sink",-1,-4.2,0)
	maid_id = model.add_item("maid",2,2,0)
	world = WorldView.new()
	root.add_child(world)
	world.setup(model)
	sim = ClubSim.new()
	root.add_child(sim)
	sim.setup(model,world)
	sim.active = false
	sim.open = true
	var occupant = guest()
	ClientNeeds.seek(sim,occupant)
	var first = guest()
	var second = guest()
	var third = guest(1)
	ClientNeeds.seek(sim,first)
	ClientNeeds.seek(sim,second)
	ClientNeeds.seek(sim,third)
	check(first.brain.state == "toilet_wait" and second.brain.state == "toilet_wait","Occupied WC produces a real waiting queue")
	check(third.brain.state == "toilet_walk" and third.brain.spot.item == urinal,"Free urinal serves a man without blocking women waiting for a WC")
	check(sim.sanitary_queue == [first,second],"FIFO queue contains only waiting clients")
	check(first.brain.wc_rank == 1 and second.brain.wc_rank == 2,"Visible queue ranks follow arrival order")
	check(first.brain.wc_slot.distance_to(second.brain.wc_slot) >= .9,"Waiting positions have room between characters")
	for a in [first,second]:
		check(sim.nav.walkable(a.brain.wc_slot) and sim.nav.reachable(a.world,a.brain.wc_slot),"Assigned queue position is reachable floor")
		check(a.brain.wc_slot.distance_to(Vector2(-2.5,-3)) >= 1.05,"Queue keeps bathroom doorway free")
		check(model.room_at(a.brain.wc_slot).type == 0,"Queue stands in public room in front of bathroom")
	check(first.brain.wait_reason.contains("occupés"),"Occupied reason is explicit")
	for t in range(600):
		first.step(.03,1)
		second.step(.03,1)
		if first.world.distance_to(first.brain.wc_slot) < .05 and second.world.distance_to(second.brain.wc_slot) < .05: break
	check(first.world.distance_to(first.brain.wc_slot) < .05 and second.world.distance_to(second.brain.wc_slot) < .05,"People physically walk to their places in line")
	sim.release(occupant)
	ClientNeeds.seek(sim,second)
	check(second.brain.state == "toilet_wait","Later client cannot steal a newly freed WC")
	ClientNeeds.seek(sim,first)
	check(first.brain.state == "toilet_walk" and sim.sanitary_queue == [second],"Head of queue takes the free WC")
	var former_slot: Vector2 = second.brain.wc_slot
	ClientNeeds.seek(sim,second)
	check(second.brain.wc_rank == 1 and second.brain.wc_slot != former_slot,"Next person advances as queue shrinks")
	ClientNeeds.tick(sim,second,9,false)
	check(Sanitation.status(sim).contains("saturés") and sim.sanitary_saturated_until > sim.elapsed,"Sustained waiting signals saturation")
	second.brain.wc_risk = false
	second.brain.wc_patience = 1.0
	ClientNeeds.tick(sim,second,.1,false)
	check(second.brain.state == "leave" and not second in sim.sanitary_queue and sim.dirt.is_empty(),"Impatient visitors leave before an accident and release their queue slot")
	check(int(sim.night.get("sanitary_departures",0)) == 1,"Sanitary departure is counted once")
	var blocked = guest()
	model.openings.erase("x:-3:-3")
	sim.nav.rebuild(model)
	ClientNeeds.seek(sim,blocked)
	check(blocked.brain.wait_reason.contains("bloqué") and not blocked in sim.sanitary_queue,"Blocked access is distinguished from an occupied fixture")
	model.item_by_id(wc).delivery_pending = true
	ClientNeeds.seek(sim,blocked)
	check(blocked.brain.wait_reason.contains("Aucun WC"),"A free urinal or pending WC cannot satisfy a female visitor")
	model.item_by_id(wc).erase("delivery_pending")
	model.set_opening("x:-3:-3","door")
	sim.layout_changed()
	check(sim.sanitary_queue.is_empty() and not first.brain.has("wc_slot"),"Building edits clear stale queue slots")
	for a in sim.clients.duplicate(): sim.remove_client(a)
	var washer = guest()
	washer.brain.bladder = 0
	washer.set_world(Vector2(-2,-4))
	Sanitation.wash(sim,washer)
	check(washer.brain.state == "wash_walk" and washer.brain.spot.item == sink,"Old sinks are useful and reserve one handwashing spot")
	for t in range(250):
		sim.client_ai(washer,.04)
		if washer.brain.state == "washing_hands": break
	check(washer.brain.state == "washing_hands" and washer.anim == "work","Visible washing animation starts at the sink")
	check(is_equal_approx(washer.brain.timer,4.0),"Regular sink uses baseline washing time")
	for t in range(60):
		sim.client_ai(washer,.04)
		if washer.brain.state == "choose": break
	check(washer.brain.state == "choose" and sim.night.handwashes == 1,"Handwashing completes and returns visitor to entertainment")
	check(model.item_by_id(sink).soil == 8.0 and not washer.brain.has("spot"),"Sink gets dirty and releases its reservation")
	model.item_by_id(sink).soap = true
	Sanitation.wash(sim,washer)
	Sanitation.wash_tick(sim,washer,.1,true)
	check(washer.brain.timer == 2.5,"Soap speeds up handwashing")
	var sat: float = washer.brain.sat
	Sanitation.wash_tick(sim,washer,3,true)
	check(washer.brain.sat == minf(100,sat+3),"Soap improves satisfaction")
	model.item_by_id(sink).delivery_pending = true
	washer.brain.wash_left = 5.0
	Sanitation.wash(sim,washer)
	for t in range(6): Sanitation.wash_tick(sim,washer,1,true)
	check(washer.brain.state == "choose" and not washer.brain.has("spot"),"No sink produces a bounded wait rather than a stuck client")
	model.item_by_id(sink).erase("delivery_pending")
	var fixture: Dictionary = model.item_by_id(wc)
	fixture.soil = 0.0
	Sanitation.soil(fixture,16)
	check(fixture.soil == 16,"Toilet use soils the fixture")
	fixture.easy_clean = true
	Sanitation.soil(fixture,16)
	check(fixture.soil == 24,"Easy-clean finish halves soiling")
	fixture.soil = 80.0
	var maid: Actor = sim.staff[maid_id]
	check(not Sanitation.cleaner_tick(sim,maid,false,.1),"Partial dirt alone does not dispatch the maid")
	Plumbing.urine_trace(sim,fixture)
	var spot: Dictionary = Catalog.spots(fixture)[0]
	sim.reserve(washer,spot)
	check(not Sanitation.cleaner_tick(sim,maid,false,.1),"Cleaning never starts on an occupied toilet")
	sim.release(washer)
	check(Sanitation.cleaner_tick(sim,maid,false,.1) and maid.brain.state == "to_fixture","Cleaner claims a dirty, free fixture")
	check(ClientNeeds.find_toilet(sim,washer).is_empty(),"Fixture under maintenance is unavailable to clients")
	model.item_by_id(maid_id).cleaning_kit = true
	for t in range(400):
		sim.staff_ai(maid,.04)
		if maid.brain.state == "cleaning_fixture": break
	check(maid.brain.state == "cleaning_fixture" and maid.anim == "mop","Cleaner walks to fixture and visibly cleans it")
	check(is_equal_approx(maid.brain.timer,3.57*sim.profiles.employee_factor(maid.brain.profile_id)),"Finish, cleaning kit and employee trait combine to shorten maintenance")
	for t in range(50): sim.staff_ai(maid,.04)
	check(fixture.soil == 0.0 and sim.dirt.is_empty() and not sim.reserved.has(sim.spot_key(spot)),"Cleaning restores hygiene and releases the fixture")
	check(is_equal_approx(Sanitation.cleaning_factor(sim,maid),.6*sim.profiles.employee_factor(maid.brain.profile_id)),"Cleaning kit and employee trait speed all household tasks")
	var saved = model.snapshot()
	var loaded = BuildingModel.new()
	check(loaded.load_checked(JSON.parse_string(JSON.stringify(saved))),"Upgraded building passes save validation")
	check(loaded.item_by_id(sink).soap and loaded.item_by_id(wc).easy_clean and loaded.item_by_id(maid_id).cleaning_kit,"Every purchased improvement survives save/load")
	check(loaded.item_by_id(wc).soil == 0 and loaded.item_by_id(sink).soil == 16,"Hygiene values survive save/load")
	var upgraded_cost = model.cost()
	fixture.erase("easy_clean")
	model.item_by_id(sink).erase("soap")
	model.item_by_id(maid_id).erase("cleaning_kit")
	check(upgraded_cost-model.cost() == 360,"Upgrade value participates in normal payment, refund and undo")
	saved.furniture[0].soil = "invalid"
	check(not loaded.load_checked(saved),"Malformed hygiene cannot corrupt simulation")
	check(Art.ui_texture("emotes","wc") != null and Art.ui_texture("emotes","wc_urgent") != null,"Yellow and red WC pixel bubbles are packaged")
	for a in sim.clients.duplicate(): sim.remove_client(a)
	sim.queue_free()
	world.queue_free()
	await process_frame
	print("SANITATION_TESTS: %d checks, %d failures" % [checks,failures])
	if failures == 0: print("SANITATION_TESTS_PASSED")
	quit(1 if failures else 0)
