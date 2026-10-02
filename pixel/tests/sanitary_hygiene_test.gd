extends SceneTree

var checks = 0
var failures = 0
var sim: ClubSim
var model: BuildingModel
var view: WorldView

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+message)

func choose_roll(incident: bool, chance: float) -> void:
	var probe = RandomNumberGenerator.new()
	for seed_value in range(1000):
		probe.seed = seed_value
		if (probe.randf() < chance) == incident:
			sim.maintenance_rng.seed = seed_value
			return

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
	var urinal_id = model.add_item("urinal",-1,-6.7,0)
	var maid_id = model.add_item("maid",2,2,0)
	var other_id = model.add_item("maid",3,2,0)
	view = WorldView.new()
	root.add_child(view)
	view.setup(model)
	sim = ClubSim.new()
	root.add_child(sim)
	sim.setup(model,view)
	sim.active = false
	var maid: Actor = sim.staff[maid_id]
	var other: Actor = sim.staff[other_id]
	for id in [wc_id,urinal_id]:
		var item = model.item_by_id(id)
		maid.brain.state = "post"
		maid.path = []
		# Repeated ordinary visits accumulate dirt without immediately sending staff.
		for visit in range(10):
			item.wear = 0
			choose_roll(false,Plumbing.URINE_CHANCE[item.kind])
			Sanitation.soil(item,8)
			Plumbing.after_use(sim,item)
			check(sim.dirt.is_empty() and not Sanitation.needs_cleaning(sim,item),"Normal visits do not request cleaning")
		check(item.soil == 80,"Normal use accumulates progressive hygiene loss")
		check(not Sanitation.cleaner_tick(sim,maid,false,.1),"Maid stays at her post below full hygiene gauge")
		# An occasional splash requests cleaning even with a partially filled gauge.
		choose_roll(true,Plumbing.URINE_CHANCE[item.kind])
		item.wear = 0
		Plumbing.after_use(sim,item)
		check(sim.dirt.size() == 1 and sim.dirt[0].kind == "urine" and item.soil == 80,"Random incident creates one yellow spill without filling the gauge")
		check(Sanitation.needs_cleaning(sim,item),"A visible incident triggers cleaning below 100 percent")
		var spill: Dictionary = sim.dirt[0]
		check(spill.node.position.distance_to(Iso.pixel(item.x,item.z)) < Iso.pixel(spill.pos.x,spill.pos.y).distance_to(Iso.pixel(item.x,item.z)),"Urine is drawn at the fixture base, separate from the accessible work spot")
		check(sim.next_dirt(other).is_empty(),"A second cleaner cannot mop the same fixture spill independently")
		var save = JSON.parse_string(JSON.stringify(sim.to_dict()))
		sim.from_dict(save)
		check(Sanitation.fixture_spills(sim,item).size() == 1 and Sanitation.needs_cleaning(sim,item),"Save/load retains the incident and its fixture link")
		var spot = Plumbing.service_spot(item)
		sim.reserve(other,spot)
		check(not Sanitation.cleaner_tick(sim,maid,false,.1),"Incident cleaning waits until fixture is unoccupied")
		sim.release(other)
		check(Sanitation.cleaner_tick(sim,maid,false,.1),"Maid claims a free contaminated fixture")
		check(not Sanitation.cleaner_tick(sim,other,false,.1),"Two cleaners cannot claim one sanitary")
		for i in range(700):
			sim.staff_ai(maid,.04)
			if item.soil == 0: break
		check(item.soil == 0 and sim.dirt.is_empty(),"One physical cleaning visit resets gauge and removes its spill")
		check(not Sanitation.needs_cleaning(sim,item),"Clean fixture does not immediately schedule another visit")
	# The full gauge always produces a spill, without relying on luck.
	var wc = model.item_by_id(wc_id)
	wc.soil = 99
	Sanitation.soil(wc,8)
	Plumbing.after_use(sim,wc)
	check(wc.soil == 100 and Sanitation.fixture_spills(sim,wc).size() == 1,"Full gauge clamps to 100 and guarantees a urine puddle")
	var load: float = sim.dirt[0].load
	for i in range(10): Plumbing.tick(sim,1)
	check(sim.dirt.size() == 1 and sim.dirt[0].load == load,"Full gauge does not generate an endless stream of duplicated puddles")
	var fx: Dictionary = view.item_entries[wc_id].sanitary_fx
	check(fx.soil.visible and fx.smell.visible,"Full fixture has the strongest dirt appearance")
	var loaded = BuildingModel.new()
	check(loaded.load_checked(JSON.parse_string(JSON.stringify(model.snapshot()))) and loaded.item_by_id(wc_id).soil == 100,"Full hygiene gauge survives save/load")
	# Moving/selling a fixture never makes its old spill disappear remotely.
	wc.x += .5
	sim.layout_changed()
	check(not sim.dirt[0].has("fixture") and not sim.next_dirt(other).is_empty(),"Moving fixture detaches its old spill for ordinary floor cleaning")
	var urinal = model.item_by_id(urinal_id)
	Plumbing.urine_trace(sim,urinal)
	model.remove_item(urinal_id)
	sim.layout_changed()
	check(sim.dirt.all(func(d): return not d.has("fixture")),"Selling sanitary leaves its puddle cleanable")
	sim.queue_free()
	view.queue_free()
	await process_frame
	print("SANITARY_HYGIENE_TESTS: %d checks, %d failures" % [checks,failures])
	if failures == 0: print("SANITARY_HYGIENE_TESTS_PASSED")
	quit(1 if failures else 0)
