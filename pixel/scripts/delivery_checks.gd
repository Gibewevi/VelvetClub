extends RefCounted

static func run(g) -> void:
	var d: Deliveries = g.deliveries
	d.enabled = false
	g.sim.active = false
	g.model.rooms.clear()
	g.model.furniture.clear()
	g.model.openings.clear()
	g.model.parkings.clear()
	g.model.add_room(-5,-3,10,10,0)
	g.model.set_opening("x:-1:7","door")
	g.changed_view()
	motion_checks(g)
	var baseline = g.sim.money
	var before = g.model.snapshot()
	var sofa = g.model.purchase_item("sofa",-3,0)
	var lamp = g.model.purchase_item("lamp",2,1)
	g.check(sofa >= 0 and lamp >= 0,"Purchase positions valid")
	g.commit(before,"Test order")
	g.check(d.queue.size() == 2 and d.phase == "waiting","Purchases group in one pending order")
	var clock_before = d.timer
	g.sim.speed = 0
	d.enabled = true
	d._process(1.0)
	g.check(d.timer == clock_before,"Pause freezes delivery countdown")
	d.enabled = false
	g.sim.speed = 1
	g.check(g.sim.money == baseline-770,"Charge once at purchase")
	g.check(Catalog.spots(g.model.item_by_id(sofa)).is_empty(),"Ghost sofa cannot be used")
	g.check(g.sim.nav.walkable(Vector2(-3,0)),"Ghost is not a physical obstacle")
	g.check(g.view.item_entries[sofa].node.modulate.a < .6,"Ghost visibly transparent")
	g.check(Deliveries.package_size(g.model.item_by_id(lamp)) == 0 and Deliveries.package_size(g.model.item_by_id(sofa)) == 2,"Carton sizes follow item volume")
	g.undo()
	g.check(d.queue.is_empty() and g.sim.money == baseline,"Undo cancels order and refunds")
	g.redo()
	g.check(d.queue.size() == 2 and g.sim.money == baseline-770,"Redo requeues without duplicate charge")
	d.step(18.1)
	g.check(d.phase == "arrive","Truck starts on road after batch interval")
	g.check(not d.truck.warning_enabled,"Moving van does not flash its warning lights")
	before = g.model.snapshot()
	var fridge = g.model.purchase_item("fridge",2,-1)
	g.commit(before,"Late purchase")
	for i in range(100):
		d.step(.1)
		if d.phase == "unload": break
	g.check(d.active_order.size() == 3 and d.queue.is_empty(),"All purchases before arrival join same truck")
	g.check(d.truck.visible and d.truck.world.y == Street.LANE_WEST,"Physical truck parks in near road lane")
	g.check(d.truck.warning_enabled,"Parked van enables gentle warning lights")
	var body_picture: Texture2D = d.truck.body.texture
	var body_anchor: Vector2 = d.truck.body.offset
	var lighting_clock: float = d.truck.warning_clock
	var saved_clock: float = d.clock
	d.clock += 3.0
	d.update_truck()
	g.check(d.truck.body.texture == body_picture and d.truck.body.offset == body_anchor,"Advancing simulated time cannot flicker or move the van body")
	g.check(d.truck.warning_clock == lighting_clock,"Warning pulse does not advance with accelerated simulation time")
	d.clock = saved_clock
	g.check(d.nav.walkable(d.loading_point(0)) and d.nav.walkable(d.loading_point(1)),"Both loading positions stay outside the van and open doors")
	before = g.model.snapshot()
	var chair = g.model.purchase_item("chair",3,3)
	g.commit(before,"Next delivery")
	g.check(d.queue.size() == 1 and d.active_order.size() == 3,"Purchases after parking wait for next delivery")
	for i in range(100):
		d.step(.1)
		if d.jobs.any(func(j): return j.state == "carry"): break
	g.check(d.jobs.filter(func(j): return j.state == "carry").size() == 2,"Two couriers transport distinct parcels")
	var saved = JSON.parse_string(JSON.stringify({"model":g.model.snapshot(),"deliveries":d.to_dict()}))
	var copy = BuildingModel.new()
	g.check(copy.load_checked(saved.model),"Pending order save validates")
	g.check(copy.item_by_id(sofa).get("delivery_pending",false),"Save retains ghost status")
	var damaged: Dictionary = saved.model.duplicate(true)
	damaged.furniture[1].delivery_key = damaged.furniture[0].delivery_key
	g.check(not copy.load_checked(damaged),"Duplicate parcel identities are rejected")
	d.from_dict(saved.deliveries)
	d.sync_orders()
	g.check(d.phase == "unload" and d.active_order.size() == 3,"Mid-route reload restores active batch")
	before = g.model.snapshot()
	g.check(g.model.move_item(sofa,-2,-1,0),"Ghost may move while courier carries it")
	g.commit(before,"Move ghost")
	before = g.model.snapshot()
	g.model.furniture.erase(g.model.item_by_id(lamp))
	g.commit(before,"Cancel parcel")
	g.check(not d.active_order.has(saved.model.furniture[1].delivery_key),"Cancellation removes parcel from truck")
	var visits: Dictionary = {}
	for i in range(1600):
		d.step(.1)
		visits[d.phase] = true
		if d.phase == "idle": break
	g.check(visits.has("close") and visits.has("depart"),"Truck closes and drives away")
	g.check(d.phase == "idle" and d.queue.is_empty() and d.active_order.is_empty(),"Both queued deliveries finish")
	g.check(d.order_number == 2,"Exactly two truck visits for two batches")
	for id in [sofa,fridge,chair]:
		g.check(not g.model.item_by_id(id).get("delivery_pending",false),"Parcel installed exactly once %d" % id)
	g.check(not Catalog.spots(g.model.item_by_id(sofa)).is_empty(),"Delivered sofa is usable")
	g.check(not g.sim.nav.walkable(Vector2(-2,-1)),"Installed sofa becomes solid")
	g.check(g.sim.money == baseline-650-700-90,"No delivery debit or cancellation double refund")
	g.undo()
	g.check(not g.model.item_by_id(sofa).get("delivery_pending",false),"Undo construction preserves completed delivery")
	g.redo()
	g.check(not g.model.item_by_id(sofa).get("delivery_pending",false),"Redo does not create another shipment")
	# A sealed room keeps the ghost queued, and retries after adding a door.
	before = g.model.snapshot()
	g.model.add_room(-5,-7,4,4,1)
	var blocked = g.model.purchase_item("lamp",-3,-5)
	g.commit(before,"Blocked target")
	var reached_retry = false
	for i in range(650):
		d.step(.1)
		if not d.deferred_keys.is_empty() and d.phase == "waiting":
			reached_retry = true
			break
	g.check(reached_retry and g.model.item_by_id(blocked).get("delivery_pending",false),"No teleport through wall; blocked parcel retries")
	g.check(d.item_status(g.model.item_by_id(blocked)).begins_with("Accès bloqué"),"Blocked parcel has actionable status")
	before = g.model.snapshot()
	g.model.set_opening("x:-3:-3","door")
	g.commit(before,"Restore access")
	for i in range(900):
		d.step(.1)
		if d.phase == "idle": break
	g.check(not g.model.item_by_id(blocked).get("delivery_pending",false),"Restored door allows delivery")
	# Cancelling an object being carried returns an empty courier, never installs it.
	before = g.model.snapshot()
	var cancel_id = g.model.purchase_item("lamp",1,2)
	g.commit(before,"Cancel during transport")
	for i in range(500):
		d.step(.1)
		if d.jobs.any(func(j): return j.state == "carry"): break
	g.check(d.jobs.any(func(j): return j.state == "carry"),"Cancellation test reaches actual transport")
	before = g.model.snapshot()
	g.model.furniture.erase(g.model.item_by_id(cancel_id))
	g.commit(before,"Cancel active courier")
	for i in range(500):
		d.step(.1)
		if d.phase == "idle": break
	g.check(d.phase == "idle" and g.model.item_by_id(cancel_id).is_empty(),"Cancelled carried parcel cannot reappear")
	# Old saves and recruited people remain immediately available.
	var recruit = g.model.purchase_item("janitor",1,4)
	g.check(recruit >= 0 and not g.model.item_by_id(recruit).get("delivery_pending",false),"Staff are not shipped in boxes")
	var old = BuildingModel.new()
	old.starter()
	g.check(copy.load_checked(old.snapshot()) and copy.furniture.all(func(i): return not i.get("delivery_pending",false)),"Older furniture remains installed")
	print("DELIVERY_TEST_RESULT: %d failures" % g.failures)

static func motion_checks(g) -> void:
	var d: Deliveries = g.deliveries
	d.reset()
	d.phase = "arrive"
	d.stop_x = -3.5
	d.truck_x = 12.0
	d.truck_speed = Deliveries.CRUISE_SPEED
	d.truck.visible = true
	d.update_truck()
	var approach = d.to_dict()
	var paused_x = d.truck_x
	g.sim.speed = 0
	d.enabled = true
	d._process(.5)
	g.check(d.truck_x == paused_x and d.truck_speed == Deliveries.CRUISE_SPEED,"Pause freezes driving position and speed")
	d.enabled = false
	g.sim.speed = 1
	d.step(.2)
	g.check(is_equal_approx(paused_x-d.truck_x,2.6) and d.truck_speed == Deliveries.CRUISE_SPEED,"Van cruises at 13 metres per second before braking")
	for i in range(80):
		d.step(.05)
		if d.brake_started: break
	g.check(d.brake_started and d.truck_speed < Deliveries.CRUISE_SPEED and d.drive_accel < 0,"Van progressively brakes over the last six metres")
	g.check(d.truck.dust.active_count() > 0,"Braking produces one visible wheel-dust burst")
	var road_anchor: Vector2 = d.truck.dust.puffs[0].world if not d.truck.dust.puffs.is_empty() else Vector2.ZERO
	d.step(.05)
	g.check(d.truck.motion_pitch > 0,"Braking compresses the front suspension")
	g.check(not d.truck.dust.puffs.is_empty() and d.truck.dust.puffs[0].world == road_anchor,"Dust remains anchored to the road as the van moves")
	var braking = d.to_dict()
	var saved_speed = d.truck_speed
	d.from_dict(braking)
	g.check(d.brake_started and is_equal_approx(d.truck_speed,saved_speed),"Reload preserves braking progress and event state")
	d.step(.05)
	g.check(d.truck.dust.active_count() == 0 and d.truck_speed < saved_speed,"Reload during braking does not emit the same dust burst twice")
	d.from_dict(braking)
	d.step(.12)
	var whole_x = d.truck_x
	var whole_speed = d.truck_speed
	d.from_dict(braking)
	for i in range(3): d.step(.04)
	g.check(is_equal_approx(d.truck_x,whole_x) and is_equal_approx(d.truck_speed,whole_speed),"Braking path is independent of the simulation step size")
	var previous_speed = d.truck_speed
	var monotonic = true
	for i in range(40):
		d.step(.07)
		monotonic = monotonic and d.truck_x >= d.stop_x and d.truck_speed <= previous_speed
		previous_speed = d.truck_speed
		if d.phase != "arrive": break
	g.check(monotonic and d.phase == "open" and d.truck_x == d.stop_x and d.truck_speed == 0,"Braking never overshoots and ends at the exact parking point")
	d.step(.2)
	g.check(d.truck.requested_frame == "truck_0_0" and d.settle_age < Deliveries.STOP_SETTLE,"Doors stay closed while the suspension settles")
	var settling = d.to_dict()
	var paused_pitch = d.truck.motion_pitch
	var paused_age = d.settle_age
	g.sim.speed = 0
	d.enabled = true
	d._process(.5)
	g.check(d.settle_age == paused_age and d.truck.motion_pitch == paused_pitch,"Pause freezes suspension and settling countdown")
	d.enabled = false
	g.sim.speed = 1
	d.from_dict(settling)
	g.check(is_equal_approx(d.settle_age,paused_age) and d.truck.requested_frame == "truck_0_0","Reload during settling keeps the doors closed for the remaining delay")
	d.step(.36)
	g.check(d.truck.requested_frame.begins_with("truck_1_0"),"Rear doors open after the suspension delay")
	d.from_dict(approach)
	d.step(10.0)
	g.check(d.phase == "open" and d.truck_x == d.stop_x and d.truck_speed == 0,"A large time step still stops exactly without passing the club")
	d.truck.reset_drive_effects()
	d.phase = "close"
	d.timer = .02
	d.settle_age = -1.0
	d.launch_started = false
	d.step(.03)
	g.check(d.phase == "depart" and d.launch_started and d.truck_speed == 0 and d.truck.dust.active_count() > 0,"Departure begins from rest with a single launch burst")
	var launch_x = d.truck_x
	d.step(.2)
	g.check(is_equal_approx(d.truck_speed,2.6) and is_equal_approx(launch_x-d.truck_x,.26),"Departure accelerates progressively instead of jumping to cruise speed")
	g.check(d.truck.motion_pitch < 0,"Acceleration compresses the rear suspension")
	var launching = d.to_dict()
	d.from_dict(launching)
	d.step(.05)
	g.check(d.truck.dust.active_count() == 0 and d.truck_speed > float(launching.truck_speed),"Reload during departure resumes acceleration without another launch burst")
	d.step(.75)
	g.check(is_equal_approx(d.truck_speed,Deliveries.CRUISE_SPEED),"Departure reaches cruise speed after one second")
	var legacy: Dictionary = approach.duplicate(true)
	for key in ["truck_speed","drive_accel","settle_age","brake_started","launch_started"]: legacy.erase(key)
	d.from_dict(legacy)
	g.check(d.phase == "arrive" and d.truck_speed > 0 and d.truck.dust.active_count() == 0,"Older arrival saves resume without replaying an effect")
	legacy = launching.duplicate(true)
	for key in ["truck_speed","drive_accel","settle_age","brake_started","launch_started"]: legacy.erase(key)
	d.from_dict(legacy)
	g.check(d.phase == "depart" and d.launch_started and d.truck_speed > 0 and d.truck.dust.active_count() == 0,"Older departure saves remain in motion without a duplicate launch")
	d.reset()
