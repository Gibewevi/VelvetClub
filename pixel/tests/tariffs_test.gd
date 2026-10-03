extends SceneTree

var checks = 0
var failures = 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+message)

func _init() -> void:
	run.call_deferred()

func run() -> void:
	var sim = ClubSim.new()
	var other = ClubSim.new()
	check(sim.prices == {"entry":20,"drink":12,"dance":30,"quick":80,"private":150,"full":260},"New clubs keep the established default prices")
	for entry in [["entry",27],["drink",16],["dance",35],["quick",65],["private",175],["full",290]]:
		check(sim.set_price(entry[0],entry[1]),"Price can be changed: "+entry[0])
	check(other.prices.entry == 20,"Each club has its own prices dictionary")
	for tier in range(3):
		var key: String = ClubSim.SERVICES[tier].price_key
		for level in range(1,5):
			check(sim.service_price_for_standing(tier,level) == int(round(sim.prices[key]*ClubSim.STANDING_RATE[level])),"Player tariff reaches the actual service quotation at every standing")
	var saved = JSON.parse_string(JSON.stringify(sim.to_dict()))
	other.from_dict(saved)
	check(other.prices == sim.prices,"All six tariffs survive the real club JSON save")
	other.from_dict({"prices":{"entry":25,"drink":15,"dance":45,"private":195}})
	check(other.prices.private == 195 and other.service_price_for_standing(1,1) == 195,"Old salon price migrates to the classic service")
	check(other.prices.quick == 80 and other.prices.full == 260,"Older saves receive defaults for the two new tariffs")
	other.from_dict({"prices":{"entry":-50,"drink":99999,"private":"bad","quick":INF,"full":null,"unknown":12}})
	check(other.prices.entry == 0 and other.prices.drink == 40,"Malformed saved amounts stay within the editable bounds")
	check(other.prices.private == 150 and other.prices.quick == 80 and other.prices.full == 260 and other.prices.size() == 6,"Invalid or unknown tariffs do not contaminate saved settings")
	check(not sim.set_price("unknown",42) and not sim.prices.has("unknown"),"Unknown live tariff keys are rejected")
	sim.set_price("quick",0)
	check(sim.service_price_for_standing(0,4) == 0,"Free services remain free at all standings")
	sim.set_price("full",99999)
	check(sim.prices.full == 800,"Live controls enforce the same bounds as loading")
	var baseline = ClubDemand.factors(3,6,22,0,ClubSim.default_prices()).per_hour
	var expensive = ClubSim.default_prices()
	expensive.entry = 80
	expensive.drink = 40
	check(ClubDemand.factors(3,6,22,0,expensive).per_hour < baseline,"Higher admission and bar tariffs reduce actual demand")
	# A real staffed bar charges the configured price per drink, and records
	# the same amount in both cash and the bar revenue report.
	Art.load_all()
	var model = BuildingModel.new()
	model.add_room(-4,-4,8,8,0)
	var counter_id = model.add_item("bar",0,0,0)
	var shelf_id = model.add_item("backbar",0,-3,0)
	model.item_by_id(shelf_id).stock = 96
	var bartender_id = model.add_item("bartender",0,-1,0)
	var world = WorldView.new()
	root.add_child(world)
	world.setup(model)
	var bar_sim = ClubSim.new()
	root.add_child(bar_sim)
	bar_sim.setup(model,world)
	bar_sim.active = false
	var bartender: Actor = bar_sim.staff[bartender_id]
	bartender.path = []
	bartender.brain.state = "working"
	bartender.brain.bar_id = counter_id
	check(bar_sim.role_present("bartender"),"Bar price test uses a planned bartender at work")
	var client = Actor.new()
	client.configure(Characters.defaults("man"))
	world.add_actor(client)
	client.set_world(Vector2(0,1))
	client.brain = {"activity":"bar","sat":75.0,"spent":0,"visits":0,"bladder":0.0,"digestion":0.0,"drinks":0}
	bar_sim.set_price("drink",19)
	var before = bar_sim.money
	bar_sim.start_activity(client)
	check(client.brain.drinks > 0 and bar_sim.money-before == int(client.brain.drinks)*19,"The bar charges the configured price for each actual drink served")
	check(bar_sim.night.bar == bar_sim.money-before and client.brain.spent == bar_sim.night.bar,"Bar reports and client spending match the configured tariff")
	bar_sim.set_price("drink",0)
	before = bar_sim.money
	var drinks_before = int(client.brain.drinks)
	bar_sim.start_activity(client)
	check(bar_sim.money == before and int(client.brain.drinks) > drinks_before,"Complimentary drinks still serve clients without charging cash")
	sim.free()
	other.free()
	print("TARIFFS_TESTS: %d checks, %d failures" % [checks,failures])
	if failures == 0: print("TARIFFS_TESTS_PASSED")
	quit(1 if failures else 0)
