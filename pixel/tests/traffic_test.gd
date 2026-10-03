extends SceneTree

var checks = 0
var failures = 0

class DashboardGame:
	extends Node
	var sim: ClubSim
	var model: BuildingModel
	func select_item(_id: int) -> void: pass

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+message)

func _init() -> void:
	run.call_deferred()

func run() -> void:
	var prices = {"entry":20,"drink":12}
	var one = ClubDemand.factors(1,6,22,0,prices).per_hour
	var five = ClubDemand.factors(5,6,22,0,prices).per_hour
	check(five > one*8,"Reputation is the principal demand factor, above an eightfold increase")
	var previous = 0.0
	for step in range(51):
		var current = ClubDemand.reputation(step/10.0)
		check(current > previous,"Every increment of reputation increases demand")
		previous = current
	check(ClubDemand.factors(3,6,22,0,prices).per_hour > ClubDemand.factors(3,2,22,0,prices).per_hour,"Weekend attracts more customers")
	check(ClubDemand.factors(3,2,22,0,prices).per_hour > ClubDemand.factors(3,2,12,0,prices).per_hour*5,"Night draws many more visitors than midday")
	check(ClubDemand.factors(5,6,22,1,prices).per_hour > one*5,"Even heavy rain cannot erase a well-rated club's advantage")
	var data = TrafficHistory.new()
	data.observe(1,1430,30,true,4,8,3,.5)
	check(data.hours["1:23"].minutes == 10 and data.hours["2:0"].minutes == 20,"History correctly splits at midnight")
	check(is_equal_approx(data.summary(data.day_rows(2)).occupancy,50),"Occupancy is weighted by time and capacity")
	data.observe(2,20,40,true,2,8,1,0)
	check(is_equal_approx(data.summary(data.day_rows(2)).occupancy,100.0/3),"Different densities form a weighted average, not an average of frames")
	data.admitted(2,22,12)
	data.admitted(2,25,4)
	check(data.summary(data.day_rows(2)).wait == 8,"Average waiting time uses the real admitted clients")
	var decoded = TrafficHistory.new()
	decoded.from_dict(JSON.parse_string(JSON.stringify(data.to_dict())))
	check(decoded.summary(decoded.day_rows(2)) == data.summary(data.day_rows(2)),"Traffic metrics survive JSON serialization")
	decoded.from_dict({"hours":[{},null,{"day":"bad","hour":9},{"day":1,"hour":0,"arrivals":"oops","minutes":INF}]})
	check(decoded.hours.size() == 1 and decoded.hours["1:0"].arrivals == 0,"Malformed optional traffic data is safely ignored or normalized")
	data.observe(30,0,1,false,0,8,0,0)
	check(not data.hours.has("1:23") and not data.hours.has("2:0"),"History is limited to 28 calendar days")
	Art.load_all()
	var model = BuildingModel.new()
	model.add_room(-3,3,6,5,5)
	model.set_opening("x:0:8","door")
	var desk = model.add_item("reception",-1,4.7,0)
	var staff_id = model.add_item("receptionist",-1,3.7,0)
	check(desk >= 0 and staff_id >= 0,"Test reception has real usable furniture")
	var view = WorldView.new()
	root.add_child(view)
	view.setup(model)
	var sim = ClubSim.new()
	root.add_child(sim)
	sim.setup(model,view)
	sim.active = false
	var saved_day = sim.day
	var saved_minute = sim.minute
	sim.day = 6
	sim.minute = 1320
	sim.rating = 1
	var saved_rng = sim.rng.state
	var low_interval = sim.spawn_interval()
	sim.rating = 5
	sim.rng.state = saved_rng
	var high_interval = sim.spawn_interval()
	check(low_interval > high_interval*8,"Real arrival intervals respond strongly to reputation")
	sim.day = saved_day
	sim.minute = saved_minute
	sim.rating = 1
	check(sim.admission.capacity > 0 and sim.admission.capacity <= 12,"Capacity reflects accessible public floor rather than the number of toilets")
	check(sim.admission.slots.size() > 12,"Outdoor queue has more visible space than the old hard-coded twelve")
	for i in sim.admission.slots.size():
		var p: Vector2 = sim.queue_slot(i)
		check(p.y < Street.ROAD.x and model.room_at(p).is_empty() and sim.nav.walkable(p),"Every queue slot is reachable outdoor ground, never the roadway")
		if i > 2: check(p.y >= Street.WALK_NEAR.x and p.y <= Street.WALK_NEAR.y,"Overflow queue remains on the pavement")
	var employee: Actor = sim.staff[staff_id]
	for step in range(200):
		sim.staff_ai(employee,.1)
		if employee.brain.state == "working": break
	check(employee.brain.state == "working","Receptionist physically works at the desk")
	# Fill the interior using existing actors, then ensure reception cannot
	# quietly admit one extra visitor while multiple people wait outside.
	saved_rng = sim.rng.state
	var empty_interval = sim.spawn_interval()
	for i in sim.admission.capacity:
		var a = Actor.new()
		a.kind = "client"
		a.configure(Characters.defaults("man"))
		a.set_world(Vector2(1,5))
		a.brain = {"paid":true,"state":"busy","sat":90,"spent":0,"activity":"look","visits":0,"plan":99,"timer":9999,"bladder":0,"digestion":0}
		sim.clients.append(a)
		view.add_actor(a)
	sim.rng.state = saved_rng
	check(is_equal_approx(sim.spawn_interval(),empty_interval),"A full interior does not silently suppress outdoor demand")
	sim.spawn_client()
	var first: Actor = sim.queue[0]
	first.set_world(sim.queue_slot(0))
	first.path = []
	first.brain.state = "queue"
	sim.wait_in_line(first,true,1)
	check(first in sim.queue and first.brain.state == "queue","A full club leaves clients visibly waiting outside")
	var released: Actor = sim.clients[0]
	sim.remove_client(released)
	sim.wait_in_line(first,true,1)
	check(first.brain.state == "to_desk" and not first in sim.queue,"One freed place admits the first waiting customer")
	sim.set_price("entry",37)
	var cash_before_entry = sim.money
	check(sim.admission.occupancy_load(sim) == sim.admission.capacity and not sim.admission.can_enter(sim),"Admission reserves a place during the walk to reception")
	for step in range(300):
		sim.client_ai(first,.1)
		if first.brain.get("paid",false): break
	check(first.brain.paid and sim.traffic.summary(sim.traffic.day_rows(sim.day)).admitted == 1,"Successful admission enters the hourly statistics once")
	check(sim.money == cash_before_entry+37 and sim.night.entry == 37 and first.brain.spent == 37,"Reception collects the configured entry tariff exactly once")
	sim.spawn_client()
	var impatient: Actor = sim.queue.back()
	impatient.set_world(sim.queue_slot(0))
	impatient.path = []
	impatient.brain.state = "queue"
	impatient.brain.reached = true
	impatient.brain.patience = 2.0
	sim.wait_in_line(impatient,true,3)
	sim.impatience(impatient,1)
	check(impatient.brain.state == "leave" and not impatient in sim.queue,"An impatient client abandons and physically leaves the line")
	check(sim.traffic.summary(sim.traffic.day_rows(sim.day)).abandoned == 1,"An abandoned queue is counted once")
	sim.spawn_client()
	var patient: Actor = sim.queue.back()
	patient.set_world(sim.queue_slot(0))
	patient.path = []
	patient.brain.state = "queue"
	patient.brain.reached = true
	patient.brain.patience = 90
	sim.wait_in_line(patient,true,3)
	check(patient.brain.state == "queue","A more patient client tolerates the same delay")
	while sim.queue.size() < sim.admission.slots.size(): sim.spawn_client()
	var before = sim.clients.size()
	var balked: float = sim.traffic.summary(sim.traffic.day_rows(sim.day)).balked
	sim.spawn_client()
	check(sim.clients.size() == before and sim.traffic.summary(sim.traffic.day_rows(sim.day)).balked == balked+1,"A fully occupied outdoor line records lost demand without overlapping more actors")
	var restored_sim = ClubSim.new()
	restored_sim.from_dict(JSON.parse_string(JSON.stringify(sim.to_dict())))
	check(restored_sim.traffic.hours.size() == sim.traffic.hours.size() and restored_sim.traffic.summary(restored_sim.traffic.hours.values()) == sim.traffic.summary(sim.traffic.hours.values()),"The club save preserves real arrival, admission and abandonment history")
	restored_sim.free()
	sim.rain_strength = .8
	var has_umbrella = 0
	for a in sim.queue:
		RainUmbrella.update_actor(sim,a)
		var umbrella = a.get_node_or_null("RainUmbrella")
		if umbrella != null and umbrella.visible:
			has_umbrella += 1
			a.set_world(Vector2(1,5))
			RainUmbrella.update_actor(sim,a)
			check(not umbrella.visible,"Umbrella closes as soon as the visitor is inside")
	check(has_umbrella > 0 and has_umbrella < sim.queue.size(),"Rain gives some outdoor clients a stable pixel-art umbrella")
	var wet = 0.0
	var total = 0.0
	sim.rain_strength = 0
	sim.weather_remaining = 0
	for i in range(2000):
		sim.weather_tick(sim.weather_remaining+.001)
		total += sim.weather_remaining
		if sim.rain_strength > 0: wet += sim.weather_remaining
	check(wet > 0 and wet/total < .10,"Long-run rain is occasional and does not dominate club attendance")
	sim.rain_strength = 0
	sim.rating = 5
	sim.day = 6
	sim.minute = 1320
	sim.opening_hours = {"days":32,"start":1200,"end":240,"enabled":true}
	var forecast = ClubDemand.forecast(sim)
	check(forecast[0].value > forecast[12].value and forecast[12].value == 0,"Forecast respects weekend overnight opening and daytime closure")
	var game = DashboardGame.new()
	game.model = model
	game.sim = sim
	root.add_child(game)
	UiKit.setup(2)
	var hud = Hud.new()
	root.add_child(hud)
	hud.set_process(false)
	hud.game = game
	hud.theme = UiKit.theme
	hud.size = Vector2(1440,900)
	hud.drawer_body = VBoxContainer.new()
	hud.add_child(hud.drawer_body)
	hud.drawer_body.size.x = 492
	hud.staff_tab = 2
	hud.fill_staff()
	await process_frame
	await process_frame
	var graphs = 0
	for child in hud.drawer_body.get_children():
		if child is TrafficChart: graphs += 1
	check(graphs == 4,"Management tab builds hourly, daily, occupancy and forecast charts")
	check(hud.drawer_body.size.x < 600,"Three Personnel tabs and charts fit the existing drawer width")
	hud.queue_free()
	game.queue_free()
	sim.queue_free()
	view.queue_free()
	await process_frame
	print("TRAFFIC_TESTS: %d checks, %d failures" % [checks,failures])
	if failures == 0: print("TRAFFIC_TESTS_PASSED")
	quit(1 if failures > 0 else 0)
