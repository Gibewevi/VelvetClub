extends SceneTree

# The club's books: income and spending by day and kind, wages by job,
# building work and purchases, periods, saving.

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
	# the ledger on its own
	var l = Ledger.new()
	l.book(3,"in","bar",24)
	l.book(3,"in","services",150)
	l.book(3,"out","wages",13.5,"maid")
	l.book(3,"out","wages",16.5,"bartender")
	l.book(4,"in","entry",40)
	l.book(4,"out","furniture",900)
	l.book(4,"in","bar",-5)
	var day3 = l.period("yesterday",4)
	check(Ledger.total(day3,"in") == 174 and Ledger.total(day3,"out") == 30,"A day: 174 $ in, 30 $ out")
	check(is_equal_approx(float(day3.wages.maid),13.5) and is_equal_approx(float(day3.wages.bartender),16.5),"Wages kept by job")
	var today = l.period("today",4)
	check(Ledger.total(today,"in") == 40 and Ledger.total(today,"out") == 900 and not today["in"].has("bar"),"Today apart; nothing negative is booked")
	var week = l.period("week",4)
	check(Ledger.total(week,"in") == 214 and Ledger.total(week,"out") == 930,"Seven days add up")
	check(Ledger.total(l.period("all",4),"in") == 214 and l.opened == 3,"Since the start, books opened on day 3")
	var days = l.daily(4,3)
	check(days.size() == 3 and days[0].day == 2 and days[2]["in"] == 40 and days[1]["out"] == 30,"Day by day, oldest first")
	# building work and purchases
	l.book_value(5,{"building":1000,"furniture":500,"parking":0},{"building":1480,"furniture":1150,"parking":0})
	var day5 = l.period("today",5)
	check(int(day5.out.building) == 480 and int(day5.out.furniture) == 650,"Work and purchases by kind")
	l.book_value(5,{"building":1480,"furniture":1150,"parking":0},{"building":1480,"furniture":250,"parking":0})
	check(int(l.period("today",5)["in"].resale) == 900,"A sale or an undo comes back as income")
	# only so many days are kept, the totals stay
	l.book(80,"in","entry",20)
	check(not l.days.has(3) and l.days.has(80) and Ledger.total(l.totals,"in") == 214+900+20,"Old days dropped, totals kept")
	# saved and loaded
	var copy = Ledger.new()
	copy.from_dict(JSON.parse_string(JSON.stringify(l.to_dict())))
	check(Ledger.total(copy.totals,"in") == Ledger.total(l.totals,"in") and copy.days.has(80) and copy.opened == 3,"Saved and loaded")
	copy.from_dict({"days":{"7":{"in":{"bar":"lots","entry":-4,"theft":99,"services":50},"wages":{"nobody":5,"maid":3}}},"totals":"bad","opened":NAN})
	check(Ledger.total(copy.days[7],"in") == 50 and copy.days[7].wages.keys() == ["maid"] and Ledger.total(copy.totals,"in") == 0 and copy.opened == 0,"A damaged save keeps only what makes sense")
	# fed by the club
	var model = BuildingModel.new()
	model.starter()
	model.furniture = model.furniture.filter(func(i): return not Catalog.is_debris(i.kind))
	var maid = model.add_item("maid",1.8,2.2,0)
	var bartender = model.add_item("bartender",-1.0,3.0,0)
	check(maid != -1 and bartender != -1,"A maid and a bartender are hired")
	var world = WorldView.new()
	root.add_child(world)
	world.setup(model)
	var sim = ClubSim.new()
	root.add_child(sim)
	sim.setup(model,world)
	sim.active = false
	var d = sim.day
	sim.earn(20,"entry")
	sim.earn(24,"bar")
	sim.earn(30,"dance")
	var b = sim.ledger.period("today",d)
	check(int(b["in"].entry) == 20 and int(b["in"].bar) == 24 and int(b["in"].stage) == 30,"Entries, drinks and the stage are booked")
	sim.accrue_wages(60.0)
	b = sim.ledger.period("today",d)
	var maid_wage = float(sim.staff[maid].brain.get("wage",Catalog.ITEMS.maid.wage))
	var bar_wage = float(sim.staff[bartender].brain.get("wage",Catalog.ITEMS.bartender.wage))
	check(is_equal_approx(float(b.wages.get("maid",0)),maid_wage) and is_equal_approx(float(b.wages.get("bartender",0)),bar_wage),"An hour's wages by job")
	check(absf(float(b.out.wages)-(maid_wage+bar_wage)) < 0.01,"…and in total")
	var cash = sim.money
	Recruits.advertise(sim)
	check(int(sim.ledger.period("today",d).out.ads) == Recruits.AD_PRICE and sim.money == cash-Recruits.AD_PRICE,"A job ad is booked")
	var saved = sim.to_dict()
	var again = ClubSim.new()
	again.from_dict(JSON.parse_string(JSON.stringify(saved)))
	check(Ledger.total(again.ledger.period("today",d),"in") == 74,"The books are saved with the game")
	print("LEDGER_TESTS: %d checks, %d failures" % [checks,failures])
	if failures == 0: print("LEDGER_TESTS_PASSED")
	quit(1 if failures > 0 else 0)
