extends SceneTree

var checks = 0
var failures = 0
var model: BuildingModel
var world: WorldView
var sim: ClubSim
var bar: Dictionary
var shelf: Dictionary
var crate: Dictionary
var worker: Actor
var client: Actor

func check(ok: bool, why: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+why)

func _init() -> void: run.call_deferred()

func run() -> void:
	Art.load_all()
	model = BuildingModel.new()
	model.add_room(-6,-6,12,8,0)
	model.add_room(6,-6,4,4,3)
	model.set_opening("z:6:-4","door")
	bar = model.item_by_id(model.add_item("bar",0,0))
	shelf = model.item_by_id(model.add_item("backbar",0,-3))
	crate = model.item_by_id(model.add_item("bottle_crate",8,-4))
	var id = model.add_item("bartender",0,-.8)
	world = WorldView.new()
	root.add_child(world)
	world.setup(model)
	sim = ClubSim.new()
	root.add_child(sim)
	sim.setup(model,world)
	sim.active = false
	worker = sim.staff[id]
	client = Actor.new()
	client.configure(Characters.defaults("man"))
	world.add_actor(client)
	client.set_world(Vector2(0,.85))
	client.brain = {"activity":"bar","spent":0,"sat":75.0,"drinks":0,"bladder":0.0,"digestion":0.0}
	worker.brain.bar_id = int(bar.id)
	worker.brain.state = "working"
	check(int(shelf.stock) == 0 and int(crate.stock) == 48,"New shelves are empty, bought cartons contain 12 bottles / 48 glasses")
	var money = sim.money
	check(not sim.bar_stock.serve(client) and sim.money == money and client.brain.drinks == 0,"A staffed bar with empty shelves sells no alcohol")
	sim.bar_stock.set_stock(shelf,12)
	shelf.delivery_pending = true
	check(not sim.bar_stock.serve(client),"Unpacked ghosts cannot supply alcohol")
	shelf.erase("delivery_pending")
	sim.set_price("drink",19)
	var before = int(shelf.stock)
	check(sim.bar_stock.serve(client),"A working bartender serves from the local shelf")
	check(before-int(shelf.stock) == int(client.brain.drinks) and sim.money-money == int(client.brain.drinks)*19,"Actual glasses are deducted and charged once at the player's tariff")
	check(world.item_variant(shelf) == "backbar_fill_%d" % ceili(int(shelf.stock)/4.0),"Visible bottles match remaining portions")
	# A bartender is attached to this counter, not a global permission to serve.
	worker.brain.state = "stock_carry"
	check(not sim.bar_stock.serve(client),"A bartender carrying a carton cannot simultaneously serve")
	worker.brain.state = "working"
	sim.bar_stock.set_stock(shelf,0)
	worker.brain.serve = 0.0
	check(sim.bar_stock.start_refill(worker,bar),"Low stock starts a trip through the door to the reserve")
	var another = Actor.new()
	another.item_id = 999
	another.set_world(worker.world)
	check(not sim.bar_stock.start_refill(another,bar),"Two employees cannot restock the same shelf together")
	another.free()
	var seen: Dictionary = {}
	var saved: Dictionary = {}
	for i in range(800):
		sim.staff_ai(worker,.1)
		seen[worker.brain.state] = true
		if worker.brain.state == "stock_carry" and saved.is_empty(): saved = sim.bar_stock.to_dict()
		if int(shelf.stock) == 48 and worker.brain.state == "working": break
	check(seen.has("stock_pick") and seen.has("stock_carry") and seen.has("stock_fill"),"Pickup, carrying and progressive unpacking are real timed states")
	check(int(crate.stock) == 0 and int(shelf.stock) == 48 and sim.bar_stock.tasks.is_empty(),"The carton is transferred without creating stock and the bartender returns to work")
	check(world.item_variant(crate) == "bottle_crate_fill_0" and worker.bar_carry_kind == "","The empty reserve carton flattens and the employee frees his hands")
	check(not saved.is_empty() and int(saved.ledger[crate.stock_key]) == 48,"Saving during carrying preserves the full unfinished carton in reserve")
	# Reload, undo and malformed data cannot refill shelves for free.
	var qty = int(shelf.stock)
	shelf.stock = 192
	sim.bar_stock.sync()
	check(int(shelf.stock) == qty,"A restored construction snapshot never rewinds stock")
	var encoded = JSON.parse_string(JSON.stringify(sim.to_dict()))
	var reload = BarStock.new()
	reload.from_dict(encoded.bar_stock)
	check(reload.ledger == sim.bar_stock.ledger,"The club save preserves the authoritative inventory ledger")
	var copy = BuildingModel.new()
	check(copy.load_checked(JSON.parse_string(JSON.stringify(model.snapshot()))) and int(copy.item_by_id(shelf.id).stock) == qty,"Bottle quantities and stable keys survive a real JSON save")
	var malformed = model.snapshot()
	for item in malformed.furniture:
		if item.kind == "backbar": item.stock = "infinite"
	check(not copy.load_checked(malformed),"Invalid stock quantities are rejected before replacing a club")
	var duplicate = model.snapshot()
	for item in duplicate.furniture:
		if item.kind == "bottle_crate": item.stock_key = shelf.stock_key
	check(not copy.load_checked(duplicate),"Two shelves/cartons cannot share one inventory identity")
	check(model.cost_parts().furniture >= 0,"Consumed cartons have no full-price resale value")
	# No door: reachable supplies are a prerequisite, not a teleport.
	sim.bar_stock.set_stock(crate,48)
	sim.bar_stock.set_stock(shelf,0)
	model.openings.clear()
	sim.nav.rebuild(model)
	check(not sim.bar_stock.start_refill(worker,bar),"A sealed reserve cannot refill a bar")
	model.set_opening("z:6:-4","door")
	sim.nav.rebuild(model)
	check(sim.bar_stock.start_refill(worker,bar),"Restocking recovers once access is reopened")
	for i in range(300):
		sim.staff_ai(worker,.1)
		if worker.brain.state == "stock_carry": break
	var in_carton = int(sim.bar_stock.tasks[worker.item_id].left)
	sim.bar_stock.interrupt(worker)
	check(in_carton > 0 and int(crate.stock) == 48 and int(shelf.stock) == 0,"Interrupting a trip returns the carried bottles to reserve")
	worker.brain.state = "working"
	worker.set_world(Vector2(0,-.8))
	var samples: Array = []
	for kind in ["bar","bar_luxe"]:
		bar.kind = kind
		sim.rng.seed = 3571
		var total = 0
		var premium = 0
		for i in range(200):
			sim.bar_stock.set_stock(shelf,96)
			var drunk = int(client.brain.drinks)
			sim.bar_stock.serve(client)
			total += int(client.brain.drinks)-drunk
			premium += int(client.brain.last_drink == "Sélection premium")
		samples.append([total,premium])
	bar.kind = "bar"
	check(samples[1][0] > samples[0][0] and samples[0][1] == 0 and samples[1][1] > 100,"A premium counter produces more real glasses and more expensive alcohol orders")
	client.brain.budget = 0
	var stocked = int(shelf.stock)
	var cash = sim.money
	check(not sim.bar_stock.serve(client) and int(shelf.stock) == stocked and sim.money == cash,"An unaffordable order never consumes or charges alcohol")
	client.brain.budget = 19
	var previous_drinks = int(client.brain.drinks)
	check(sim.bar_stock.serve(client) and int(client.brain.drinks) == previous_drinks+1 and int(client.brain.budget) == 0,"A client buys only the glass his remaining budget covers")
	client.brain.erase("budget")
	var original = bar.kind
	bar.kind = "bar_module"
	var module = model.item_by_id(model.add_item("bar_module",1.5,0))
	check(not module.is_empty() and sim.bar_stock.bartender(module) == worker,"Connected modular counters share a nearby bartender")
	var module_spots = Catalog.spots(bar)+Catalog.spots(module)
	module_spots = module_spots.filter(func(s): return s.who == "client")
	check(sim.bar_stock.activity_options(module_spots).size() == 1,"Connected modules count as one bar activity")
	var prestigious = model.item_by_id(model.add_item("bar_luxe",-3.9,0))
	var premium_spots = Catalog.spots(prestigious).filter(func(s): return s.who == "client")
	var weighted = sim.bar_stock.activity_options(module_spots+premium_spots)
	check(weighted.size() == 2 and float(weighted[1][1]) > float(weighted[0][1]),"Each separate counter attracts its clients at its own quality")
	model.remove_item(int(prestigious.id))
	model.remove_item(int(module.id))
	bar.kind = original
	# A hollow L leaves its work aisle usable, including all four orientations.
	for rotation in range(4):
		var u = BuildingModel.new()
		u.add_room(-6,-6,12,12,0)
		var uid = u.add_item("bar_l",0,0,rotation)
		var item = u.item_by_id(uid)
		var aisle = Catalog.local_to_world(item,Vector2(0,-.25))
		var nav = ClubNav.new()
		nav.rebuild(u)
		check(uid > 0 and nav.walkable(aisle) and nav.reachable(Catalog.local_to_world(item,Vector2(0,-2.0)),aisle),"L counter has a reachable inner aisle, rotation %d" % rotation)
		check(u.add_item("bartender",aisle.x,aisle.y) > 0,"A bartender fits in the hollow L, rotation %d" % rotation)
	for kind in Catalog.BARS+["backbar","bottles_small","bottles_arch","bottles_luxe","bottle_crate"]:
		for rotation in range(4):
			check(not Art.furniture_entry(kind,rotation).is_empty(),"Native bar artwork exists for %s/%d" % [kind,rotation])
	for kind in ["backbar","bottles_small","bottles_arch","bottles_luxe"]:
		for count in range(Catalog.stock_capacity(kind)/4+1):
			check(not Art.furniture_entry("%s_fill_%d" % [kind,count],0).is_empty(),"Every visible bottle count has an artwork")
		for rotation in range(4):
			var empty = Art.furniture_entry("%s_fill_0" % kind,rotation)
			var full = Art.furniture_entry(kind,rotation)
			check(empty.ox == full.ox and empty.oy == full.oy and empty.w == full.w and empty.h == full.h,"The cabinet stays fixed as bottles appear, %s/%d" % [kind,rotation])
	sim.bar_stock.reset()
	check(sim.bar_stock.ledger.is_empty() and sim.bar_stock.tasks.is_empty(),"A new club clears inventory and unfinished tasks")
	print("BAR_STOCK_TESTS: %d checks, %d failures" % [checks,failures])
	if failures == 0: print("BAR_STOCK_TESTS_PASSED")
	quit(1 if failures else 0)
