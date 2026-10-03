extends SceneTree

# Priorities given to employees: a maid told to see to the toilets first
# goes there before the beds; with no priority she keeps her usual order.

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

func _init() -> void:
	run.call_deferred()

func reset(a: Actor) -> void:
	# back at her post, nothing in hand
	sim.release(a)
	sim.release_bed_task(a)
	sim.release_debris(a)
	sim.release_dirt_task(a)
	Waste.release(sim,a)
	a.path = []
	a.set_world(a.brain.post)
	a.brain.state = "post"

func run() -> void:
	Art.load_all()
	model = BuildingModel.new()
	model.add_room(-5,-3,10,8,0)
	model.add_room(-5,-7,5,4,2)
	model.add_room(0,-7,5,4,1)
	model.set_opening("x:0:5","door")
	model.set_opening("x:-3:-3","door")
	model.set_opening("x:2:-3","door")
	var wc_id = model.add_item("toilet",-4,-6.4,0)
	var bed_id = model.add_item("bed",2.5,-5.6,0)
	var bin_id = model.add_item("bin",3.5,2.5,0)
	var trash_id = model.add_item("trash_papers",-2.0,3.0,0)
	var maid_id = model.add_item("maid",2,2,0)
	var tech_id = model.add_item("janitor",-3,2,0)
	check(wc_id != -1 and bed_id != -1 and bin_id != -1 and trash_id != -1 and maid_id != -1 and tech_id != -1,"Toilets, a bedroom, a bin, rubbish, a maid and a technician")
	view = WorldView.new()
	root.add_child(view)
	view.setup(model)
	sim = ClubSim.new()
	root.add_child(sim)
	sim.setup(model,view)
	sim.active = false
	var maid: Actor = sim.staff[maid_id]
	var tech: Actor = sim.staff[tech_id]
	# the options
	check(Duties.options("maid").size() >= 5 and Duties.valid("maid","wc") and Duties.valid("maid","bins"),"A maid can be given the toilets, beds, bins, floors or rubbish first")
	check(Duties.valid("janitor","repair") and not Duties.valid("janitor","beds") and not Duties.valid("janitor","bins"),"A technician: repairs, toilets, floors, rubbish (no beds, no bins)")
	check(Duties.options("bartender").is_empty() and not Duties.valid("maid","dance"),"Jobs with a single task have no priority")
	# work waiting everywhere: an unmade bed, a dirty WC, a full bin
	model.item_by_id(bed_id).unmade = true
	model.item_by_id(wc_id).soil = 100.0
	model.item_by_id(bin_id).waste = Waste.CAPACITY
	# no priority: her usual order (the dirty fixtures before the beds)
	reset(maid)
	sim.staff_ai(maid,0.05)
	check(maid.brain.state == "to_fixture","Without a priority, the maid starts with the dirty WC (%s)" % maid.brain.state)
	# the beds first
	reset(maid)
	model.item_by_id(maid_id).duty = "beds"
	sim.staff_ai(maid,0.05)
	check(maid.brain.state == "to_bed_task" and int(maid.brain.bed_id) == bed_id,"Beds first: she makes the bed before the WC (%s)" % maid.brain.state)
	# the toilets first
	reset(maid)
	model.item_by_id(maid_id).duty = "wc"
	sim.staff_ai(maid,0.05)
	check(maid.brain.state == "to_fixture" and int(maid.brain.get("spot",{}).get("item",-1)) == wc_id,"Toilets first: she goes to clean the WC (%s)" % maid.brain.state)
	# the bins first
	reset(maid)
	model.item_by_id(maid_id).duty = "bins"
	sim.staff_ai(maid,0.05)
	check(maid.brain.state == "to_bin_empty","Bins first: she goes to empty the full bin (%s)" % maid.brain.state)
	# the rubbish first
	reset(maid)
	model.item_by_id(maid_id).duty = "debris"
	sim.staff_ai(maid,0.05)
	check(maid.brain.state == "to_debris" and int(maid.brain.debris_id) == trash_id,"Rubbish first: she picks up the papers (%s)" % maid.brain.state)
	# water on the toilet floor comes before the fixtures for a "toilets" maid
	reset(maid)
	model.item_by_id(maid_id).duty = "wc"
	sim.add_dirt(Vector2(-2.5,-4.5),"water",1)
	sim.add_dirt(Vector2(-1.0,1.0),"water",1)
	sim.staff_ai(maid,0.05)
	check(maid.brain.state == "to_dirt" and model.room_at(maid.brain.dirt.pos).get("type",-1) == 2,"Toilets first: the water on the toilet floor before the hall's (%s)" % maid.brain.state)
	# nothing of her priority left: she does the rest as usual
	reset(maid)
	for d in sim.dirt: d.node.queue_free()
	sim.dirt.clear()
	model.item_by_id(wc_id).soil = 0.0
	sim.staff_ai(maid,0.05)
	check(maid.brain.state in ["to_bin_empty","to_bed_task"],"Toilets clean: she goes back to her usual work (%s)" % maid.brain.state)
	# technician: the toilets before the rubbish
	reset(tech)
	model.item_by_id(wc_id).soil = 100.0
	sim.staff_ai(tech,0.05)
	var usual = String(tech.brain.state)
	reset(tech)
	model.item_by_id(tech_id).duty = "wc"
	sim.staff_ai(tech,0.05)
	check(tech.brain.state == "to_fixture","A technician with the toilets first goes to the WC (usual: %s)" % usual)
	# saved with the game; an unknown priority is dropped on loading
	var data = model.snapshot()
	for item in data.furniture:
		if int(item.id) == tech_id: item.duty = "beds"
	var loaded = BuildingModel.new()
	check(loaded.load_checked(data) and String(loaded.item_by_id(maid_id).get("duty","")) == "wc" and not loaded.item_by_id(tech_id).has("duty"),"Priorities are saved; one a job cannot have is dropped")
	print("DUTY_TESTS: %d checks, %d failures" % [checks,failures])
	if failures == 0: print("DUTY_TESTS_PASSED")
	quit(1 if failures > 0 else 0)
