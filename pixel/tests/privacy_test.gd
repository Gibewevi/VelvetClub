extends SceneTree

# A maid or a technician in a bedroom when a couple comes in leaves the room
# straight away, without walking on the spot between her post and some other
# job; only once out of the room does she take up work again.

var checks = 0
var failures = 0

func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+text)

func _init() -> void:
	run.call_deferred()

func run() -> void:
	Art.load_all()
	var model = BuildingModel.new()
	model.add_room(-5,-3,10,8,0)
	model.add_room(-5,-7,5,4,2)
	model.add_room(0,-7,5,4,1)
	model.set_opening("x:0:5","door")
	model.set_opening("x:-3:-3","door")
	model.set_opening("x:2:-3","door")
	var wc = model.add_item("toilet",-4,-6.4,0)
	var bed = model.add_item("bed",2.5,-5.6,0)
	var maid_id = model.add_item("maid",-3.5,3.5,0)
	var tech_id = model.add_item("janitor",3.5,3.5,0)
	check(wc != -1 and bed != -1 and maid_id != -1 and tech_id != -1,"Toilets, a bedroom, a maid and a technician")
	var world = WorldView.new()
	root.add_child(world)
	world.setup(model)
	var sim = ClubSim.new()
	root.add_child(sim)
	sim.setup(model,world)
	sim.active = false
	var bedroom = model.room_at(Vector2(2.5,-4.0))
	for id in [maid_id,tech_id]:
		var a: Actor = sim.staff[id]
		# work waiting elsewhere: a dirty WC, water in the hall
		model.item_by_id(wc).soil = 100.0
		for d in sim.dirt: d.node.queue_free()
		sim.dirt.clear()
		sim.add_dirt(Vector2(-2.0,3.0),"water",1)
		# she is in the bedroom when a couple takes it
		sim.busy_beds.erase(bed)
		a.path = []
		a.set_world(Vector2(1.0,-3.6))
		a.brain.state = "post"
		sim.busy_beds[bed] = sim
		check(sim.room_private(bedroom),"The bedroom is taken")
		var states: Array = []
		var flips = 0
		var left_at = -1
		var last = ""
		for tick in range(400):
			sim.staff_ai(a,0.05)
			var s = String(a.brain.state)
			if s != last:
				states.append(s)
				if last != "": flips += 1
				last = s
			if left_at < 0 and model.room_at(a.world) != bedroom: left_at = tick
		var who = a.kind
		check(left_at >= 0 and left_at < 120,"%s leaves the taken bedroom (tick %d)" % [who,left_at])
		check(flips <= 6,"%s does not hesitate on the spot (%d changes: %s)" % [who,flips,str(states.slice(0,12))])
		check(states.size() > 1 and states.slice(1).any(func(x): return x in ["to_fixture","to_dirt","cleaning_fixture","mopping"]),"Out of the room, %s goes back to work (%s)" % [who,str(states.slice(0,8))])
		sim.busy_beds.erase(bed)
	# her post is in the bedroom: she waits there quietly, then works again
	var m: Actor = sim.staff[maid_id]
	var keep_post = m.brain.post
	m.path = []
	m.brain.post = Vector2(1.0,-3.6)
	m.set_world(Vector2(1.0,-3.6))
	m.brain.state = "post"
	sim.busy_beds[bed] = sim
	var walks = 0
	var changes = 0
	var prev = ""
	for tick in range(120):
		sim.staff_ai(m,0.05)
		if tick >= 20 and m.anim == "walk": walks += 1
		if String(m.brain.state) != prev:
			changes += 1
			prev = String(m.brain.state)
	check(walks == 0 and m.anim == "idle" and changes <= 2,"With her post in the taken bedroom she waits still (%d walking frames, %d changes)" % [walks,changes])
	model.item_by_id(wc).soil = 100.0
	sim.busy_beds.erase(bed)
	for tick in range(40): sim.staff_ai(m,0.05)
	check(m.brain.state in ["to_fixture","to_dirt","cleaning_fixture","mopping","to_bed_task"],"Once the couple has gone she goes to work (%s)" % m.brain.state)
	m.brain.post = keep_post
	print("PRIVACY_TESTS: %d checks, %d failures" % [checks,failures])
	if failures == 0: print("PRIVACY_TESTS_PASSED")
	quit(1 if failures > 0 else 0)
