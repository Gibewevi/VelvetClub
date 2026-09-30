extends SceneTree

var checks = 0
var failures = 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+label)

func _init() -> void:
	run.call_deferred()

func run() -> void:
	Art.load_all()
	var model = BuildingModel.new()
	model.starter()
	var id = model.add_item("escort_pro",-2.4,0.2,0,Characters.normalize({"outfit_style":6},"escort_pro"))
	var world = WorldView.new()
	root.add_child(world)
	world.wall_mode = 1
	world.setup(model)
	var sim = ClubSim.new()
	root.add_child(sim)
	sim.setup(model,world)
	sim.active = false
	sim.open = true
	sim.spawn_client()
	var c: Actor = sim.clients[0]
	var e: Actor = sim.staff[id]
	c.configure(Characters.defaults("man"))
	sim.queue.clear()
	c.brain.paid = true
	var bed: Dictionary = model.furniture.filter(func(i): return i.kind == "old_bed")[0]
	var room = model.room_at(Vector2(bed.x,bed.z))
	var app_c = c.appearance.duplicate(true)
	var app_e = e.appearance.duplicate(true)
	var captured = false
	for mode in ["complete","unmade","cancel","layout"]:
		bed.unmade = mode == "unmade"
		world.set_bed_look(int(bed.id),"unmade" if bed.unmade else "made")
		c.path = []
		e.path = []
		c.set_world(Vector2(-1.4,0.2))
		e.set_world(Vector2(-2.4,0.2))
		c.brain.state = "busy"
		c.brain.activity = "lounge"
		c.brain.budget = sim.service_price(0,e)
		c.brain.sat = 95.0
		c.brain.erase("service_done")
		e.brain.erase("sick_until")
		var before = sim.money
		var agreed = false
		for attempt in range(20):
			c.brain.escort = e
			e.brain.client = c
			if sim.negotiate(e,c,1.0):
				agreed = true
				break
		check(agreed,"Quick visit finds reachable floor positions: "+mode)
		if not agreed: continue
		check(int(c.brain.service.tier) == 0,"Budget selects the quick visit")
		check(sim.money == before,"Walking to the room does not charge the client")
		if mode == "cancel":
			sim.cancel_service(c)
			check(c.path.is_empty() and e.path.is_empty() and sim.money == before,"Cancellation clears both paths without a charge")
		else:
			var posed = false
			for tick in range(1200):
				sim.staff_ai(e,0.1)
				sim.client_ai(c,0.1)
				if c.brain.get("service",{}).get("phase","") == "quick_pose":
					posed = true
					break
			check(posed,"Both characters walk into the room before posing: "+mode)
			if not posed: continue
			check(c.visible and e.visible and c.anim == "stand" and e.anim == "kneel","Both clothed characters remain visible in the requested poses")
			check(c.lift == 0 and e.lift == 0 and sim.nav.walkable(c.world) and sim.nav.walkable(e.world),"Both poses are on free floor")
			check(model.room_at(c.world) == room and model.room_at(e.world) == room,"Both actors are in the same bedroom")
			check(absf(c.position.x-e.position.x) >= 24.0,"Silhouettes stay separate without contact")
			check(not world.bed_looks.has(int(bed.id)) and not world.clothes.has(int(bed.id)),"No bed animation or dropped clothing")
			check(c.appearance == app_c and e.appearance == app_e,"All clothing layers are preserved")
			check(sim.money-before == sim.service_price(0,e),"The quick visit is charged once")
			check(sim.room_private(room),"The bedroom stays reserved during the visit")
			var frame_c = c.current_frame()
			var frame_e = e.current_frame()
			c._process(3.0)
			e._process(3.0)
			check(c.current_frame() == frame_c and e.current_frame() == frame_e,"The pose has no body or head motion")
			if not captured:
				for arg in OS.get_cmdline_user_args():
					if arg.begins_with("--capture="):
						world.scale = Vector2(4,4)
						world.position = Vector2(root.size)/2.0-(c.position+e.position)*2.0+Vector2(0,64)
						await process_frame
						await RenderingServer.frame_post_draw
						root.get_texture().get_image().save_png(arg.trim_prefix("--capture="))
						captured = true
			if mode == "layout":
				sim.layout_changed()
			else:
				sim.service_script(c,float(ClubSim.SERVICES[0].minutes)+1.0)
			check(bed.unmade == (mode == "unmade"),"The quick visit preserves the bed's previous state")
			check(c.anim != "stand" and e.anim != "kneel","Both actors leave the static poses")
		check(not c.brain.has("service") and not e.brain.has("client") and sim.busy_beds.is_empty() and sim.reserved.is_empty(),"Completion or cancellation releases both actors and the room")
	check(not model.furniture.any(func(i): return i.kind == "trash_tissues"),"Floor poses leave no bed-related litter")
	print("QUICK_SERVICE_TESTS: %d checks, %d failures" % [checks,failures])
	if failures == 0: print("QUICK_SERVICE_TESTS_PASSED")
	quit(1 if failures else 0)
