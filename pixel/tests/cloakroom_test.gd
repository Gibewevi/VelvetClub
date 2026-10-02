extends SceneTree

# The cloakroom: coats left after paying, taken back when leaving, racks and
# lockers filling up a few coats at a time, a full cloakroom.

var checks = 0
var failures = 0
var model: BuildingModel
var world: WorldView
var sim: ClubSim
var rack: int
var locker: int

func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+text)

func _init() -> void:
	run.call_deferred()

func guest(with_coat: bool = true, pos: Vector2 = Vector2(0,1)) -> Actor:
	# made by hand: more clients than the street would send in one go
	var a = Actor.new()
	a.kind = "client"
	a.configure(Characters.random_client(sim.rng))
	a.brain = {"role":"client","name":"Test","profile_id":"","preference":"bar","cleanliness":1.0,"budget":100,"refused":[],"plan":3}
	sim.clients.append(a)
	world.add_actor(a)
	a.set_world(pos)
	a.path = []
	a.brain.merge({"paid":true,"state":"choose","activity":"look","timer":0.0,"sat":80.0,"coat":with_coat},true)
	a.brain.erase("coat_done")
	return a

func hang(a: Actor) -> void:
	# walks there and hands the coat
	a.set_world(a.path.back() if not a.path.is_empty() else a.world)
	a.path = []
	Cloakroom.tick(sim,a,true,0.0)
	Cloakroom.tick(sim,a,false,1.0)

func run() -> void:
	Art.load_all()
	model = BuildingModel.new()
	model.add_room(-5,-3,10,8,5)
	model.set_opening("x:0:5","door")
	rack = model.add_item("coat_rack",-3.5,-2.6,0)
	locker = model.add_item("cloak_locker",3.5,-2.6,0)
	check(rack != -1 and locker != -1,"Rack and lockers fit")
	world = WorldView.new()
	root.add_child(world)
	world.setup(model)
	sim = ClubSim.new()
	root.add_child(sim)
	sim.setup(model,world)
	sim.active = false
	sim.open = true
	check(Cloakroom.CAPACITY.cloak_locker > Cloakroom.CAPACITY.coat_rack*2 and Catalog.ITEMS.cloak_locker.price > Catalog.ITEMS.coat_rack.price,"Lockers cost more and hold far more coats")
	check(world.item_variant(model.item_by_id(rack)) == "coat_rack_c0" and world.item_variant(model.item_by_id(locker)) == "cloak_locker_o0","An unused cloakroom is empty")
	# not every client has a coat, more of them when it rains
	sim.rain_strength = 0.0
	var dry = 0
	for i in range(2000): if Cloakroom.has_coat(sim): dry += 1
	sim.rain_strength = 0.8
	var wet = 0
	for i in range(2000): if Cloakroom.has_coat(sim): wet += 1
	sim.rain_strength = 0.0
	check(absf(dry/2000.0-Cloakroom.COAT_CHANCE) < .05 and wet > dry*1.5,"About %d %% of clients bring a coat, more in the rain (%d vs %d)" % [int(Cloakroom.COAT_CHANCE*100),dry,wet])
	# one coat: to the nearest place with room, then hung
	var a = guest(true,Vector2(-2.5,0.5))
	check(Cloakroom.deposit(sim,a) and a.brain.state == "to_cloak" and int(a.brain.coat_to) == rack,"A client with a coat goes to the nearest cloakroom first")
	check(Cloakroom.used(sim,rack) == 1,"His place is kept while he walks there")
	hang(a)
	check(int(a.brain.get("coat_at",-1)) == rack and a.brain.state == "choose" and Cloakroom.used(sim,rack) == 1,"The coat is hung and he goes on with his evening")
	check(world.item_variant(model.item_by_id(rack)) == "coat_rack_c1","The rack shows one coat")
	var plain = guest(false)
	check(not Cloakroom.deposit(sim,plain) and float(plain.brain.sat) == 80.0,"A client without a coat goes straight in, not bothered")
	# the rack fills gradually, then the lockers take over
	for i in range(Cloakroom.CAPACITY.coat_rack-1):
		var g = guest(true,Vector2(-2.5,0.5))
		Cloakroom.deposit(sim,g)
		hang(g)
	check(Cloakroom.used(sim,rack) == Cloakroom.CAPACITY.coat_rack and world.item_variant(model.item_by_id(rack)) == "coat_rack_c7","Twelve coats fill the rack")
	var mid = Cloakroom.CAPACITY.coat_rack/2
	check(clampi(ceili(float(mid)/Cloakroom.CAPACITY.coat_rack*7.0-0.001),0,7) == 4,"Half the coats show half the rack")
	var next = guest(true,Vector2(-2.5,0.5))
	check(Cloakroom.deposit(sim,next) and int(next.brain.coat_to) == locker,"When the rack is full, the lockers take the coats")
	hang(next)
	check(world.item_variant(model.item_by_id(locker)) == "cloak_locker_o1","One locker shows taken")
	for i in range(Cloakroom.CAPACITY.cloak_locker-1):
		var g = guest(true,Vector2(2.5,0.5))
		Cloakroom.deposit(sim,g)
		hang(g)
	check(world.item_variant(model.item_by_id(locker)) == "cloak_locker_o9","Thirty coats fill the lockers")
	var late = guest(true,Vector2(0,1))
	check(not Cloakroom.deposit(sim,late) and float(late.brain.sat) == 80.0-Cloakroom.FULL_PENALTY and late.brain.coat_done,"A full cloakroom leaves him a little less pleased, once")
	check(not Cloakroom.deposit(sim,late),"He does not try again")
	# leaving: the coat first, then the street
	sim.leave(a)
	check(a.brain.state == "to_cloak_out","Leaving, he fetches his coat first")
	a.set_world(a.path.back() if not a.path.is_empty() else a.world)
	a.path = []
	Cloakroom.tick(sim,a,true,0.0)
	Cloakroom.tick(sim,a,false,1.0)
	check(not a.brain.has("coat_at") and a.brain.state == "leave" and Cloakroom.used(sim,rack) == Cloakroom.CAPACITY.coat_rack-1,"Coat taken back, he heads for the street and a hanger is free")
	check(world.item_variant(model.item_by_id(rack)) == "coat_rack_c7" or world.item_variant(model.item_by_id(rack)) == "coat_rack_c6","The rack shows it")
	# sent away without his coat (closing in a hurry): the hanger is freed
	var gone = sim.clients.filter(func(c): return int(c.brain.get("coat_at",-1)) == locker)[0]
	sim.remove_client(gone)
	check(Cloakroom.used(sim,locker) == Cloakroom.CAPACITY.cloak_locker-1,"A client gone frees his locker")
	# no cloakroom at all
	model.remove_item(rack)
	model.remove_item(locker)
	var nowhere = guest(true)
	check(not Cloakroom.deposit(sim,nowhere) and float(nowhere.brain.sat) == 80.0-Cloakroom.FULL_PENALTY,"Without a cloakroom he keeps his coat")
	print("CLOAKROOM_TESTS: %d checks, %d failures" % [checks,failures])
	if failures == 0: print("CLOAKROOM_TESTS_PASSED")
	quit(1 if failures > 0 else 0)
