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
	before = g.model.snapshot()
	var fridge = g.model.purchase_item("fridge",2,-1)
	g.commit(before,"Late purchase")
	for i in range(100):
		d.step(.1)
		if d.phase == "unload": break
	g.check(d.active_order.size() == 3 and d.queue.is_empty(),"All purchases before arrival join same truck")
	g.check(d.truck.visible and d.truck.world.y == Street.LANE_WEST,"Physical truck parks in near road lane")
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
