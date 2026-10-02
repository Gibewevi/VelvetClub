extends SceneTree

var checks = 0
var failures = 0
var model: BuildingModel
var view: WorldView
var sim: ClubSim

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+message)

func clear_water() -> void:
	for d in sim.dirt: d.node.queue_free()
	sim.dirt.clear()

func _init() -> void:
	run.call_deferred()

func run() -> void:
	Art.load_all()
	model = BuildingModel.new()
	model.add_room(-5,-3,10,8,0)
	model.add_room(-5,-7,5,4,2)
	model.set_opening("x:0:5","door")
	model.set_opening("x:-3:-3","door")
	var wc_id = model.add_item("toilet",-4,-6.4,0)
	var sink_id = model.add_item("sink",-1,-4.2,0)
	var shower_id = model.add_item("shower",-1,-6.2,0)
	var maid_id = model.add_item("maid",2,2,0)
	var tech_id = model.add_item("janitor",3,2,0)
	view = WorldView.new()
	root.add_child(view)
	view.setup(model)
	sim = ClubSim.new()
	root.add_child(sim)
	sim.setup(model,view)
	sim.active = false
	var wc = model.item_by_id(wc_id)
	var sink = model.item_by_id(sink_id)
	var shower = model.item_by_id(shower_id)
	var maid: Actor = sim.staff[maid_id]
	var tech: Actor = sim.staff[tech_id]
	for i in range(3): Plumbing.after_use(sim,wc)
	check(wc.wear == 6 and not wc.get("leaking",false),"Fresh plumbing gets an initial grace period")
	clear_water()
	wc.soil = 100.0
	Plumbing.urine_trace(sim,wc)
	check(not sim.dirt.is_empty() and sim.dirt.all(func(d): return d.kind == "urine"),"Dirty toilets generate urine traces on floor")
	var before_work = 0.0
	for d in sim.dirt: before_work += d.work
	Plumbing.urine_trace(sim,wc)
	var after_work = 0.0
	for d in sim.dirt: after_work += d.work
	check(after_work > before_work,"Repeated splashes increase cleaning work")
	view.refresh_sanitary(wc,0)
	var fx: Dictionary = view.item_entries[wc_id].sanitary_fx
	check(fx.soil.visible and fx.smell.visible,"Heavy grime has visible stains and comic smell lines")
	var dirty_texture = fx.soil.texture
	wc.soil = 20.0
	view.refresh_sanitary(wc,0)
	check(fx.soil.texture != dirty_texture and not fx.smell.visible,"Light dirt has a distinct calmer appearance")
	wc.soil = 0.0
	view.refresh_sanitary(wc,0)
	check(not fx.soil.visible,"Clean equipment has no stain overlay")
	clear_water()
	Plumbing.start_leak(sim,wc)
	check(wc.leaking and sim.dirt.size() == 1 and fx.fault.visible and fx.drops.visible,"Leak immediately shows water, droplets and repair badge")
	check(not Sanitation.usable(sim,maid,Plumbing.service_spot(wc)),"Leaking sanitary cannot be used normally")
	check(Sanitation.usable(sim,tech,Plumbing.service_spot(wc),true),"Technician can access the leaking item")
	var frame = fx.drops.texture
	Plumbing.tick(sim,1.0)
	check(sim.dirt.size() == 1 and fx.drops.texture != frame,"Droplets animate before next spread step")
	Plumbing.tick(sim,39.0)
	check(sim.dirt.size() == 11,"Water spreads incrementally with elapsed game time")
	check(sim.dirt.all(func(d): return model.room_at(d.pos).type == 2 and sim.nav.walkable(d.pos)),"Water stays on connected bathroom floor and avoids obstacles")
	var positions: Dictionary = {}
	for d in sim.dirt: positions[sim.nav.cell_of(d.pos)] = true
	check(positions.size() == sim.dirt.size(),"Flood creates distinct patches rather than stacking sprites")
	var footprint = sim.dirt.size()
	var clock = sim.maintenance_clock
	sim.active = true
	sim.speed = 0
	sim._process(100)
	check(sim.dirt.size() == footprint and sim.maintenance_clock == clock,"Pause freezes water spread and effect animation")
	sim.active = false
	var saved = JSON.parse_string(JSON.stringify(sim.to_dict()))
	sim.dirt[0].work = 2.0
	var progress = JSON.parse_string(JSON.stringify(sim.to_dict()))
	sim.from_dict(progress)
	check(sim.dirt[0].work == 2 and sim.dirt.size() == footprint,"Partial mopping progress survives save/load")
	var loaded = BuildingModel.new()
	check(loaded.load_checked(JSON.parse_string(JSON.stringify(model.snapshot()))),"Leaking equipment save validates")
	check(loaded.item_by_id(wc_id).leaking and loaded.item_by_id(wc_id).wear == wc.wear,"Leak and wear survive save/load")
	var bad = model.snapshot()
	bad.furniture[0].leaking = "yes"
	check(not loaded.load_checked(bad),"Malformed leak flags are rejected")
	bad = model.snapshot()
	bad.furniture[0].wear = "old"
	check(not loaded.load_checked(bad),"Malformed wear is rejected")
	sim.from_dict({"dirt":[{"x":-3,"z":-4,"load":"bad","work":2},{"x":-3,"z":-4,"work":-1}]})
	check(sim.dirt.is_empty(),"Invalid puddle workload is rejected")
	sim.from_dict(saved)
	check(not Plumbing.technician_tick(sim,maid,true,30) and wc.leaking,"Maid cannot repair plumbing")
	model.openings.erase("x:-3:-3")
	sim.nav.rebuild(model)
	check(not Plumbing.technician_tick(sim,tech,false,.1) and Plumbing.repair_status(sim,wc).contains("bloqué"),"Technician respects closed access and reports it")
	model.set_opening("x:-3:-3","door")
	sim.nav.rebuild(model)
	sim.staff_ai(tech,.04)
	check(tech.brain.state == "to_repair" and not tech.brain.has("dirt"),"Technician prioritizes repair over puddle cleaning")
	for i in range(500):
		sim.staff_ai(tech,.04)
		if tech.brain.state == "repairing": break
	check(tech.brain.state == "repairing" and tech.anim == "work","Technician physically reaches fixture and repairs it")
	check(Plumbing.repair_status(sim,wc).contains("en cours"),"Repair progress is reported on equipment")
	var standing_water = sim.dirt.size()
	for i in range(200):
		sim.staff_ai(tech,.04)
		if not wc.leaking: break
	check(not wc.leaking and wc.wear == 0 and sim.night.repairs == 1,"Completed repair stops leak and resets wear")
	check(sim.dirt.size() == standing_water,"Repair leaves existing flood for cleaning")
	Plumbing.tick(sim,80)
	check(sim.dirt.size() == standing_water and not fx.fault.visible and not fx.drops.visible,"Repaired item stops spreading and loses faulty visuals")
	check(Sanitation.usable(sim,maid,Plumbing.service_spot(wc)),"Repaired toilet becomes usable again")
	# One saturated patch takes longer, and new water adds real work while mopping.
	clear_water()
	sim.add_dirt(Vector2(-3,-4),"water",2)
	var d: Dictionary = sim.dirt[0]
	sim.staff_ai(maid,.04)
	for i in range(500):
		sim.staff_ai(maid,.04)
		if maid.brain.state == "mopping": break
	check(maid.brain.state == "mopping" and is_equal_approx(maid.brain.timer,12*Sanitation.cleaning_factor(sim,maid)),"Large wet patch requires more cleaning work, modified by employee efficiency")
	sim.staff_ai(maid,.4)
	var remaining: float = d.work
	sim.add_dirt(d.pos,"water",1)
	check(d.work == remaining+6,"New water adds work even while someone is mopping")
	for i in range(200):
		sim.staff_ai(maid,.04)
		if sim.dirt.is_empty(): break
	check(sim.dirt.is_empty(),"Mopping eventually removes a repaired flood")
	Plumbing.start_leak(sim,sink)
	check(sink.leaking,"Lavabos also support plumbing faults")
	clear_water()
	Plumbing.tick(sim,4)
	check(sim.dirt.size() == 1,"Mopping alone cannot stop an active source refilling the floor")
	Plumbing.start_leak(sim,shower)
	check(shower.leaking and sim.nav.walkable(Plumbing.service_spot(shower).pos),"Shower repairs use the accessible doorway, not the blocked interior")
	check(sim.free_shower(model.room_at(Vector2(shower.x,shower.z))).is_empty(),"Faulty shower is excluded from client service")
	# Removing or moving a broken item releases repair reservations safely.
	sim.release(tech)
	tech.brain.state = "post"
	Plumbing.technician_tick(sim,tech,false,.1)
	check(tech.brain.state == "to_repair","Another leak gets queued for repair")
	var removed_id: int = tech.brain.spot.item
	model.remove_item(removed_id)
	sim.layout_changed()
	check(tech.brain.state == "post" and not tech.brain.has("spot"),"Construction cancels stale repair claims")
	for item in [sink,shower]: item.leaking = false
	clear_water()
	for i in range(500):
		Plumbing.after_use(sim,wc)
		if wc.leaking: break
	check(wc.leaking,"Repeated actual use can eventually cause a random fault")
	check(Art.ui_texture("emotes","repair") != null,"Repair thought bubble is included in the game")
	sim.queue_free()
	view.queue_free()
	await process_frame
	print("PLUMBING_TESTS: %d checks, %d failures" % [checks,failures])
	if failures == 0: print("PLUMBING_TESTS_PASSED")
	quit(1 if failures else 0)
