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
	var fri = {"days":16,"start":1140,"end":300}
	check(not ClubCalendar.covers(fri,5,1139),"Friday shift excludes time before start")
	check(ClubCalendar.covers(fri,5,1140),"Friday shift starts at 19:00")
	check(ClubCalendar.covers(fri,6,299),"Friday overnight shift continues Saturday morning")
	check(not ClubCalendar.covers(fri,6,300),"Overnight shift ends precisely at 05:00")
	check(not ClubCalendar.covers(fri,6,1140),"Friday-only shift never repeats Saturday evening")
	check(ClubCalendar.covers({"days":64,"start":1200,"end":240},8,200),"Sunday overnight shift crosses week boundary")
	check(not ClubCalendar.covers({"days":0,"start":0,"end":0},1,500),"Empty day mask is full-week rest")
	for day in range(1,8):
		for minute in [0,600,1439]: check(ClubCalendar.covers(ClubCalendar.default_shift(),day,minute),"Legacy continuous shift stays available")
	check(ClubCalendar.covers({"days":1,"start":1080,"end":1080},2,1000),"24-hour shift follows its start day")
	check(not ClubCalendar.covers({"days":1,"start":1080,"end":1080},2,1080),"24-hour Monday shift stops Tuesday at the start hour")
	for bad in [{"days":128,"start":0,"end":0},{"days":1,"start":1440,"end":0},{"days":1,"start":"night","end":0},{"days":1.5,"start":0,"end":0}]:
		check(not ClubCalendar.valid(bad),"Invalid schedules are rejected")
	check(ClubCalendar.time_factor(23) > ClubCalendar.time_factor(12)*5,"Evening/night peak is substantially above daytime")
	check(ClubCalendar.day_factor(6,23) > ClubCalendar.day_factor(2,23),"Saturday night peaks above weekdays")
	check(ClubCalendar.day_factor(7,2) == ClubCalendar.day_factor(6,23),"Saturday weekend peak continues Sunday after midnight")
	Art.load_all()
	var model = BuildingModel.new()
	model.add_room(-5,-3,10,8,0)
	model.add_room(-5,-7,5,4,2)
	model.set_opening("x:0:5","door")
	model.set_opening("x:-3:-3","door")
	var wc_id = model.add_item("toilet",-4,-6.4,0)
	var maid_id = model.add_item("maid",2,2,0)
	var tech_id = model.add_item("janitor",3,2,0)
	model.item_by_id(maid_id).work_schedule = {"days":127,"start":1080,"end":1200}
	model.item_by_id(tech_id).work_schedule = {"days":0,"start":0,"end":0}
	var view = WorldView.new()
	root.add_child(view)
	view.setup(model)
	var sim = ClubSim.new()
	root.add_child(sim)
	sim.minute = 1079
	sim.setup(model,view)
	sim.active = false
	var maid: Actor = sim.staff[maid_id]
	check(maid.brain.state == "off_shift" and not maid.visible,"Off-duty employee is absent from building")
	var wc = model.item_by_id(wc_id)
	wc.soil = 40
	Plumbing.urine_trace(sim,wc)
	sim.staff_ai(maid,4)
	check(not sim.dirt.is_empty() and maid.brain.state == "off_shift","Off-duty employee never takes a cleaning job")
	sim.active = true
	sim._process(.4)
	check(sim.minute == 1080 and maid.visible and maid.brain.state == "post","Shift starts at exact scheduled minute")
	for i in range(500):
		sim._process(.04)
		if sim.dirt.is_empty(): break
	check(not sim.open and sim.dirt.is_empty() and wc.soil == 0,"Maid physically cleans while club is closed")
	# Precise payroll across both shift boundaries, even in a single large update.
	sim.minute = 1050
	sim.wage_remainder = 0
	sim.refresh_schedule_state()
	var cash: int = sim.money
	sim._process(72)
	check(sim.minute == 1230 and sim.money == cash-2*int(Catalog.ITEMS.maid.wage),"Only two worked hours are paid in a three-hour clock jump")
	check(maid.brain.state == "off_shift" and not maid.visible,"Employee leaves at end of shift")
	# Repair already underway finishes without accepting new work afterwards.
	var tech: Actor = sim.staff[tech_id]
	model.item_by_id(tech_id).work_schedule = {"days":127,"start":1200,"end":1231}
	sim.refresh_schedule_state()
	Plumbing.start_leak(sim,wc)
	var spot = Plumbing.service_spot(wc)
	sim.reserve(tech,spot)
	tech.set_world(spot.pos)
	tech.brain.state = "repairing"
	tech.brain.timer = 3.0
	sim.minute = 1231
	sim.refresh_schedule_state()
	check(tech.brain.overtime and tech.visible,"Employee finishing a task remains visible after shift cutoff")
	sim.staff_ai(tech,2)
	sim.staff_ai(tech,.1)
	check(not wc.leaking and tech.brain.state == "off_shift","Repair finishes then technician goes off duty")
	# Automatic opening, closing, manual exception and reopen on the next schedule.
	sim.day = 5
	sim.minute = 1139
	sim.set_opening_hours({"days":16,"start":1140,"end":300,"enabled":true})
	check(not sim.open,"Club stays closed before planned opening")
	sim._process(.4)
	check(sim.open and not sim.closing,"Club automatically opens exactly on time")
	sim.set_open(false)
	sim._process(.4)
	check(not sim.open and sim.opening_override == 0,"Manual closure persists within the current scheduled window")
	sim.day = 6
	sim.minute = 300
	sim.refresh_schedule_state()
	check(not sim.open and sim.opening_override == -1,"Manual exception ends at scheduled closing")
	sim.day = 12
	sim.minute = 1140
	sim.refresh_schedule_state()
	check(sim.open,"Club reopens the following scheduled Friday")
	sim.spawn_client()
	sim.minute = 299
	sim.day = 13
	sim.refresh_schedule_state()
	sim._process(.4)
	check(not sim.open and sim.queue.is_empty() and sim.clients.all(func(a): return a.brain.state == "leave"),"Scheduled closing clears admissions and sends existing clients home")
	# Overnight staff remain present after public closing.
	model.item_by_id(maid_id).work_schedule = {"days":16,"start":1140,"end":360}
	sim.refresh_schedule_state()
	check(maid.visible and not sim.open,"Friday maid shift can continue after Saturday public closing")
	# Reputation and rain have direct, independently measurable effects.
	sim.rating = 1
	sim.rain_strength = 0
	var dry: float = sim.demand_factors().rate
	sim.rain_strength = 1
	check(is_equal_approx(sim.demand_factors().rate,dry*.7),"Heavy rain moderates customer arrival demand by 30 percent")
	sim.rating = 5
	check(sim.demand_factors().rate > dry,"Strong reputation outweighs moderate rain penalty")
	var rain_time: float = view.rain.phase
	var clock: float = sim.minute
	var remaining: float = sim.weather_remaining
	sim.speed = 0
	sim._process(100)
	check(sim.minute == clock and sim.weather_remaining == remaining and view.rain.phase == rain_time,"Pause freezes calendar, weather and rain animation")
	sim.speed = 1
	sim.wage_remainder = .375
	sim.night.wages = 33
	var state = sim.to_dict()
	var restored = ClubSim.new()
	restored.from_dict(JSON.parse_string(JSON.stringify(state)))
	check(restored.day == sim.day and restored.minute == sim.minute and restored.opening_hours == sim.opening_hours,"Calendar and club hours survive JSON save/load")
	restored.setup(model,view)
	restored.active = false
	check(restored.night.wages == 33 and is_equal_approx(restored.wage_remainder,.375),"Current-day wages and fractional pay survive a complete restore")
	check(restored.weather_rng.state == sim.weather_rng.state,"Weather randomness resumes from its saved state")
	check(view.rain.sheltered(Iso.pixel(-3,-5)) and not view.rain.sheltered(Iso.pixel(15,10)),"Rain is excluded from the interior and allowed outdoors")
	check(restored.rain_strength == 1 and is_equal_approx(restored.weather_remaining,sim.weather_remaining),"Rain state and weather duration survive save/load")
	var loaded = BuildingModel.new()
	check(loaded.load_checked(JSON.parse_string(JSON.stringify(model.snapshot()))) and loaded.item_by_id(maid_id).work_schedule == model.item_by_id(maid_id).work_schedule,"Individual employee schedule survives model save/load")
	var bad = model.snapshot()
	bad.furniture[1].work_schedule.start = 1500
	check(not loaded.load_checked(bad),"Invalid saved employee hours are rejected")
	var legacy = ClubSim.new()
	legacy.from_dict({"day":1,"minute":90,"money":100})
	check(legacy.clock_text() == "21:30" and legacy.day == 1,"Older save retains its displayed evening time")
	legacy.from_dict({"day":1,"minute":300,"money":100})
	check(legacy.clock_text() == "01:00" and legacy.day == 2,"Older overnight save migrates across midnight")
	# Calendar day wrap must retain dirt and active night shifts, without report pause.
	sim.opening_hours.enabled = false
	sim.set_open(false)
	sim.day = 5
	sim.minute = 1439
	var spills: int = sim.dirt.size()
	sim._process(.4)
	check(sim.day == 6 and sim.minute == 0 and not sim.paused_for_report and sim.dirt.size() == spills,"Midnight advances day without clearing dirt or stopping the simulation")
	check(ClubCalendar.covers(model.item_by_id(maid_id).work_schedule,sim.day,sim.minute),"Night shift remains scheduled across midnight")
	check(not sim.history.is_empty(),"Completed calendar day records a financial report")
	for a in restored.staff.values(): view.remove_actor(a)
	restored.staff.clear()
	for extra in [restored,legacy]: extra.free()
	sim.queue_free()
	view.queue_free()
	await process_frame
	print("CALENDAR_TESTS: %d checks, %d failures" % [checks,failures])
	if failures == 0: print("CALENDAR_TESTS_PASSED")
	quit(1 if failures else 0)
