extends SceneTree

# Waste and lingerie: clients drop a glass or tissues in a bin, or on the
# floor without one; bins fill up and a maid takes the bag out to the
# containers by the street. An escort changes into her lingerie in a twirl in
# front of the bed, and dresses again after the shower.

var checks = 0
var failures = 0
var model: BuildingModel
var world: WorldView
var sim: ClubSim

func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+text)

func _init() -> void:
	run.call_deferred()

func guest(pos: Vector2, litter: String = "litter_glass") -> Actor:
	var a = Actor.new()
	a.kind = "client"
	a.configure(Characters.random_client(sim.rng))
	a.brain = {"role":"client","name":"Test","profile_id":"","preference":"bar","cleanliness":1.0,"budget":100,"refused":[],"plan":3}
	sim.clients.append(a)
	world.add_actor(a)
	a.set_world(pos)
	a.path = []
	a.brain.merge({"paid":true,"state":"choose","activity":"look","timer":0.0,"sat":80.0,"coat_done":true,"spent":0,"visits":0,"waited":0.0,"patience":60.0},true)
	if litter != "": a.brain.litter = litter
	return a

func toss(a: Actor) -> void:
	# walks to the bin and drops it in
	a.set_world(a.path.back() if not a.path.is_empty() else a.world)
	a.path = []
	Waste.tick(sim,a,true,0.0)
	Waste.tick(sim,a,false,1.0)

func litter_count() -> int:
	return model.furniture.filter(func(i): return Catalog.ITEMS[i.kind].get("litter",false)).size()

func walk(a: Actor) -> void:
	a.set_world(a.path.back() if not a.path.is_empty() else a.world)
	a.path = []

func run() -> void:
	Art.load_all()
	model = BuildingModel.new()
	model.starter()
	# the derelict rubbish is not the point here
	model.furniture = model.furniture.filter(func(i): return not Catalog.is_debris(i.kind))
	var bin = model.add_item("bin",-0.6,3.4,0)
	var maid_id = model.add_item("maid",1.8,2.2,0)
	var janitor_id = model.add_item("janitor",-2.0,4.0,0)
	check(bin != -1 and maid_id != -1 and janitor_id != -1,"A bin, a maid and a technician fit in the hall")
	world = WorldView.new()
	root.add_child(world)
	world.setup(model)
	sim = ClubSim.new()
	root.add_child(sim)
	sim.setup(model,world)
	sim.active = false
	sim.open = true
	# the catalogue
	check(Catalog.in_shop("bin") and int(Catalog.ITEMS.bin.price) > 0,"Bins are sold in the shop")
	for kind in ["litter_glass","litter_tissue","litter_paper"]:
		check(Catalog.is_debris(kind) and Catalog.ITEMS[kind].get("litter",false) and not Catalog.in_shop(kind) and float(Catalog.ITEMS[kind].clean) <= 3.0,"%s is quick litter for the cleaners" % kind)
		check(not Art.furniture_entry(kind,0).is_empty(),"%s has its picture" % kind)
	for n in range(4): check(not Art.furniture_entry("bin_f%d" % n,0).is_empty(),"A bin %d/3 full has its picture" % n)
	var levels = []
	for n in [0,1,4,5,9,10]: levels.append(Waste.level({"waste":n}))
	check(levels == [0,1,1,2,2,3],"The bin shows empty, a few pieces, well filled, full (%s)" % str(levels))
	check(world.item_variant(model.item_by_id(bin)) == "bin_f0","A new bin is empty")
	# what clients have in hand after an activity
	var a = guest(Vector2(0,1),"")
	var glasses = 0
	for i in range(2000):
		a.brain.erase("litter")
		Waste.pick_up(sim,a,"bar")
		if a.brain.get("litter","") == "litter_glass": glasses += 1
	check(absf(glasses/2000.0-float(Waste.LITTER.bar[1])) < .05,"About %d %% of drinks leave an empty glass (%d)" % [int(Waste.LITTER.bar[1]*100),glasses])
	a.brain.erase("litter")
	for i in range(200): Waste.pick_up(sim,a,"look")
	check(not a.brain.has("litter"),"Looking around leaves nothing in hand")
	a.brain.erase("litter")
	var toilet = 0
	for i in range(1000):
		a.brain.erase("litter")
		Waste.pick_up(sim,a,"toilet")
		if a.brain.get("litter","") == "litter_tissue": toilet += 1
	check(toilet > 200 and toilet < 400,"Some come back from the toilets with tissues (%d / 1000)" % toilet)
	sim.clients.erase(a)
	# into the bin
	var g = guest(Vector2(0.5,2.5))
	check(Waste.dispose(sim,g) and g.brain.state == "to_bin" and int(g.brain.bin_to) == bin,"A client with an empty glass walks to the nearest bin")
	check(Waste.used(sim,bin) == 1,"His piece counts while he walks there")
	toss(g)
	check(int(model.item_by_id(bin).get("waste",0)) == 1 and not g.brain.has("litter") and g.brain.state == "choose","The glass is in the bin and he goes on with his evening")
	check(world.item_variant(model.item_by_id(bin)) == "bin_f1" and litter_count() == 0,"The bin shows it, nothing on the floor")
	sim.clients.erase(g)
	# the bin fills up, then overflows onto the floor
	for i in range(Waste.CAPACITY-1):
		var o = guest(Vector2(0.5,2.5),"litter_paper")
		Waste.dispose(sim,o)
		toss(o)
		sim.clients.erase(o)
	check(int(model.item_by_id(bin).waste) == Waste.CAPACITY and world.item_variant(model.item_by_id(bin)) == "bin_f3","Ten pieces fill the bin")
	var late = guest(Vector2(0.5,2.5),"litter_tissue")
	check(not Waste.dispose(sim,late) and litter_count() == 1 and not late.brain.has("litter"),"With the bin full, the tissues end up on the floor")
	var dropped: Dictionary = model.furniture.filter(func(i): return i.kind == "litter_tissue")[0]
	check(Vector2(dropped.x,dropped.z).distance_to(late.world) < 0.8 and int(sim.night.get("littered",0)) == 1,"Right where he stands")
	check(sim.hints.has("waste"),"A hint tells the player why")
	sim.clients.erase(late)
	# the cleaners pick litter up, nearest first
	var maid: Actor = sim.staff[maid_id]
	var janitor: Actor = sim.staff[janitor_id]
	check(int(sim.next_debris(janitor).get("id",-1)) == int(dropped.id),"A technician will pick the tissues up")
	# a maid empties the full bin into a container outside
	check(not Waste.containers(sim).is_empty(),"There are containers by the street")
	check(not Waste.maid_tick(sim,janitor,false,0.1),"A technician leaves the bins to the maids")
	maid.brain.state = "post"
	check(Waste.maid_tick(sim,maid,false,0.1) and maid.brain.state == "to_bin_empty" and sim.bins_taken.get(bin) == maid,"The maid comes for the full bin")
	walk(maid)
	Waste.maid_tick(sim,maid,true,0.0)
	check(maid.brain.state == "bagging" and maid.anim == "work","She ties the bag")
	Waste.maid_tick(sim,maid,false,5.0)
	check(maid.brain.state == "to_container" and int(maid.brain.get("bag",0)) == Waste.CAPACITY and not model.item_by_id(bin).has("waste"),"She takes the bag out, the bin is empty")
	check(world.item_variant(model.item_by_id(bin)) == "bin_f0","The bin shows empty again")
	check(maid.carry != null and maid.carry.visible,"She carries the rubbish bag")
	check(not maid.path.is_empty() and model.room_at(maid.path.back()).is_empty(),"The container is outside the club")
	var near = Waste.containers(sim).any(func(c): return c.pos.distance_to(maid.path.back()) < 2.5)
	check(near,"She stands right by a container")
	check(sim.staff_committed(maid),"She finishes the job even at the end of her shift")
	walk(maid)
	Waste.maid_tick(sim,maid,true,0.0)
	check(maid.brain.state == "dumping","She throws the bag in")
	Waste.maid_tick(sim,maid,false,2.0)
	check(maid.brain.state in ["back","post"] and not maid.brain.has("bag") and not maid.carry.visible and int(sim.night.get("bins_emptied",0)) == 1,"Bag thrown, back to work")
	check(not sim.bins_taken.has(bin),"The bin is free for the next time")
	# a bin not yet at the mark stays
	model.item_by_id(bin).waste = Waste.EMPTY_AT-1
	maid.brain.state = "post"
	check(not Waste.maid_tick(sim,maid,false,0.1),"A bin below the mark is left for later")
	# called away with the bag in hand: it goes back in the bin
	model.item_by_id(bin).waste = Waste.EMPTY_AT
	Waste.maid_tick(sim,maid,false,0.1)
	walk(maid)
	Waste.maid_tick(sim,maid,true,0.0)
	Waste.maid_tick(sim,maid,false,5.0)
	Waste.interrupt(sim,maid)
	check(int(model.item_by_id(bin).get("waste",0)) == Waste.EMPTY_AT and not maid.brain.has("bag") and not maid.carry.visible,"Called away, she puts the bag back")
	maid.path = []
	maid.brain.state = "post"
	# no bin at all
	model.remove_item(bin)
	var plain = guest(Vector2(-2,2),"litter_glass")
	Waste.dispose(sim,plain)
	check(litter_count() == 2 and model.furniture.any(func(i): return i.kind == "litter_glass"),"Without a bin the glass is left on the floor")
	sim.clients.erase(plain)
	# a bedroom bin takes the tissues after a visit
	var bedroom = model.rooms.filter(func(r): return int(r.type) == 1)[0]
	check(not Waste.toss_in_room(sim,bedroom),"No bin in the bedroom: nothing to toss into")
	var room_bin = model.add_item("bin",3.4,1.3,0)
	check(room_bin != -1 and Waste.toss_in_room(sim,bedroom) and int(model.item_by_id(room_bin).waste) == 1,"With a bin there, the used tissues go in it")
	model.remove_item(room_bin)
	# a client does not walk into a bedroom to use its bin
	var far_bin = model.add_item("bin",3.4,1.3,0)
	var hall = guest(Vector2(2.0,1.0),"litter_paper")
	check(Waste.nearest_bin(sim,hall).is_empty(),"Clients do not go into a bedroom to throw things away")
	sim.clients.erase(hall)
	model.remove_item(far_bin)
	# saved bins
	var saved = model.snapshot()
	var full_bin = model.add_item("bin",-0.6,3.4,0)
	var data = model.snapshot()
	for item in data.furniture:
		if int(item.id) == full_bin: item.waste = 50
	var loaded = BuildingModel.new()
	check(loaded.load_checked(data) and int(loaded.item_by_id(full_bin).waste) == Waste.CAPACITY,"A saved bin keeps its contents, within the bin's size")
	for item in data.furniture:
		if item.kind == "old_sofa": item.waste = 3
	check(not BuildingModel.new().load_checked(data),"Waste on anything else than a bin is rejected")
	model.restore(saved)
	world.rebuild()
	lingerie()
	print("WASTE_TESTS: %d checks, %d failures" % [checks,failures])
	if failures == 0: print("WASTE_TESTS_PASSED")
	quit(1 if failures > 0 else 0)

func lingerie() -> void:
	# a visit in bed: the escort changes in a twirl in front of the bed
	var string_style = Characters.FEMALE_OUTFITS.find("string")
	var rng = RandomNumberGenerator.new()
	rng.seed = 7
	var id = model.add_item("escort_chic",-2.4,0.2,0,Characters.hire_look("escort_chic",rng))
	sim.layout_changed()
	var e: Actor = sim.staff[id]
	var own: Dictionary = e.appearance.duplicate(true)
	check(int(own.outfit_style) != string_style,"She arrives in her own outfit")
	# the twirl on its own
	sim.undress(e)
	check(e.brain.has("change") and e.path.is_empty(),"She stops to change")
	var faces: Dictionary = {}
	var swapped_at = -1.0
	var t = 0.0
	while e.brain.has("change") and t < 10.0:
		sim.outfit_tick(e,0.25)
		t += 0.25
		faces["%s%s" % [e.view,e.flip]] = true
		if swapped_at < 0 and int(e.appearance.outfit_style) == string_style: swapped_at = t
	check(faces.size() == 4,"She turns all the way round (%d facings)" % faces.size())
	check(swapped_at > ClubSim.TWIRL*0.3 and swapped_at < ClubSim.TWIRL*0.7,"Half way round, she is in her lingerie (%.1f min)" % swapped_at)
	check(not e.brain.has("change") and t <= ClubSim.TWIRL+0.3,"The twirl is short (%.1f min)" % t)
	check(int(e.appearance.outfit_style) == string_style and String(e.appearance.outfit) in ClubSim.LINGERIE,"A coloured string and bra")
	var was = Color(String(own.outfit))
	var now = Color(String(e.appearance.outfit))
	check(Vector3(now.r-was.r,now.g-was.g,now.b-was.b).length() > 0.45,"In a colour that stands out from her outfit (%s -> %s)" % [own.outfit,e.appearance.outfit])
	check(e.brain.get("dressed") == model.item_by_id(id).appearance,"Her own clothes are kept for later")
	check(e.appearance.skin == own.skin and e.appearance.hair == own.hair and e.appearance.hairstyle == own.hairstyle,"Only the outfit changes")
	sim.sync_staff()
	check(int(e.appearance.outfit_style) == string_style,"The club's bookkeeping does not dress her back")
	sim.redress(e)
	t = 0.0
	while e.brain.has("change") and t < 10.0:
		sim.outfit_tick(e,0.25)
		t += 0.25
	check(e.appearance == model.item_by_id(id).appearance and not e.brain.has("dressed"),"Dressed again in her own outfit")
	sim.undress(e)
	sim.dress_now(e)
	check(e.appearance == model.item_by_id(id).appearance and not e.brain.has("change") and not e.brain.has("dressed"),"End of her shift: dressed at once")
	# a whole visit, without then with a shower in the room
	var bed: Dictionary = model.furniture.filter(func(i): return i.kind == "old_bed")[0]
	var room = model.room_at(Vector2(bed.x,bed.z))
	for with_shower in [false,true]:
		if with_shower:
			check(model.add_item("shower",3.5,3.55,3) != -1,"A shower fits in the bedroom")
			world.rebuild()
			sim.layout_changed()
		var c = guest(Vector2(-1.4,0.2),"")
		c.configure(Characters.defaults("man"))
		var agreed = false
		for attempt in range(40):
			e.path = []
			c.path = []
			e.set_world(Vector2(-2.4,0.2))
			c.set_world(Vector2(-1.4,0.2))
			e.brain.state = "free"
			c.brain.state = "busy"
			c.brain.activity = "lounge"
			c.brain.budget = sim.service_price(2,e)
			c.brain.sat = 95.0
			c.brain.refused = []
			c.brain.escort = e
			e.brain.client = c
			if sim.negotiate(e,c,1.0):
				if int(c.brain.service.tier) != 0:
					agreed = true
					break
				sim.cancel_service(c)
		check(agreed,"A visit in bed is agreed")
		if not agreed: return
		check(e.brain.state == "to_undress" and int(e.appearance.outfit_style) != string_style,"She walks to the foot of the bed, still dressed")
		var seen = {"undressing":false,"lingerie_in_bed":false,"lingerie_dance":false,"twirl_out":false}
		var where_changed = Vector2.INF
		var done = false
		for tick in range(9000):
			sim.staff_ai(e,0.1)
			if is_instance_valid(c) and c.brain.has("service"): sim.client_ai(c,0.1)
			# the shower door swings in the view
			world.step_shower_doors(0.1)
			if e.brain.state == "undressing" and not seen.undressing:
				seen.undressing = true
				where_changed = e.world
			var lingerie_on = int(e.appearance.outfit_style) == string_style
			if e.brain.state in ["wait_partner","in_service"] and lingerie_on and c.brain.get("service",{}).get("phase","") in ["","undress"]: seen.lingerie_in_bed = true
			if OS.get_environment("WASTE_TRACE") != "" and tick % 20 == 0: print("T%d e=%s c=%s phase=%s lingerie=%s change=%s dressed=%s" % [tick,e.brain.state,c.brain.state,c.brain.get("service",{}).get("phase",""),lingerie_on,e.brain.has("change"),e.brain.has("dressed")])
			if c.brain.get("service",{}).get("phase","") == "dance" and lingerie_on: seen.lingerie_dance = true
			if e.brain.has("change") and e.brain.has("dressed") and not c.brain.has("service"): seen.twirl_out = true
			if not c.brain.has("service") and not e.brain.has("dressed") and not e.brain.has("change") and e.brain.state in ["free","post"]:
				done = true
				break
		var label = " (with a shower)" if with_shower else " (no shower)"
		check(seen.undressing and model.room_at(where_changed) == room and sim.nav.walkable(where_changed),"She changes on the bedroom floor, in front of the bed"+label)
		check(seen.lingerie_in_bed,"She waits on the bed in her lingerie"+label)
		check(seen.lingerie_dance,"She dances for him in her lingerie"+label)
		check(seen.twirl_out,"After the visit she twirls back into her clothes"+label)
		check(done and e.appearance == model.item_by_id(id).appearance,"Back in her own outfit"+label)
		if with_shower: check(int(sim.night.get("showers",0)) >= 1,"She showered before dressing")
		sim.clients.erase(c)
		c.queue_free()
