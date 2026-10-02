extends SceneTree

# Hiring from the short list: three different candidates a day per job,
# wages that follow skills, and skills that change how the work is done.

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
	var model = BuildingModel.new()
	model.add_room(-5,-3,10,8,0)
	model.set_opening("x:0:5","door")
	var world = WorldView.new()
	root.add_child(world)
	world.setup(model)
	var sim = ClubSim.new()
	root.add_child(sim)
	sim.setup(model,world)
	sim.active = false
	sim.day = 3
	# --- the lists
	var list = Recruits.pool(sim,"bartender")
	check(list.size() == Recruits.PER_ROLE,"Three candidates per job")
	var tags = {}
	for c in list: tags[c.tag] = true
	check(tags.size() == 3,"Three different profiles to choose from (%s)" % ", ".join(tags.keys()))
	check(JSON.stringify(Recruits.pool(sim,"bartender")) == JSON.stringify(list),"The same candidates after a reload the same day")
	var fair_ok = true
	var spread_ok = true
	for c in list:
		var fair = Recruits.fair_wage("bartender",c.speed,c.quality)
		if absf(float(c.wage)-fair) > fair*0.15+1.0: fair_ok = false
		if c.speed < Recruits.MIN_SKILL or c.speed > Recruits.MAX_SKILL or c.quality < Recruits.MIN_SKILL or c.quality > Recruits.MAX_SKILL: spread_ok = false
		if int(c.wage) < int(round(Recruits.base_wage("bartender")*0.6)): fair_ok = false
	check(fair_ok,"Wages follow the skills, give or take a good deal")
	check(spread_ok,"Skills stay between %.2f and %.2f" % [Recruits.MIN_SKILL,Recruits.MAX_SKILL])
	var best = list.duplicate()
	best.sort_custom(func(x,y): return x.speed+x.quality > y.speed+y.quality)
	var dear = 0
	var cheap = 0
	for kind in ["bartender","receptionist","janitor","maid","escort"]:
		for d in range(1,30):
			sim.day = d
			var pool = Recruits.pool(sim,kind)
			pool.sort_custom(func(x,y): return x.speed+x.quality > y.speed+y.quality)
			if int(pool[0].wage) > int(pool[2].wage): dear += 1
			else: cheap += 1
	check(dear > cheap*4,"The best candidate usually asks for more (%d / %d)" % [dear,dear+cheap])
	sim.day = 3
	check(Recruits.stars(Recruits.MIN_SKILL) == 1 and Recruits.stars(Recruits.MAX_SKILL) == 5 and Recruits.stars(1.0) == 3,"Skills show as 1 to 5 squares")
	sim.day = 4
	check(JSON.stringify(Recruits.pool(sim,"bartender")) != JSON.stringify(list),"New candidates the next day")
	var escorts = Recruits.pool(sim,"escort")
	check(escorts.all(func(c): return int(c.appearance.outfit_style) in Characters.STANDINGS.escort.outfits and int(c.appearance.body) == 0),"Escort candidates are dressed for their standing")
	var guards = Recruits.pool(sim,"janitor")
	check(guards.all(func(c): return int(c.appearance.outfit_style) == int(Characters.defaults("janitor").outfit_style)) and guards.any(func(c): return c.appearance.skin != guards[0].appearance.skin or c.appearance.hair != guards[0].appearance.hair),"Staff candidates wear the uniform, each a person of their own")
	# an ad: new faces right away, for a price
	var money = sim.money
	var first = Recruits.pool(sim,"maid")
	Recruits.advertise(sim)
	check(sim.money == money-Recruits.AD_PRICE and JSON.stringify(Recruits.pool(sim,"maid")) != JSON.stringify(first),"An ad brings new candidates for %d $" % Recruits.AD_PRICE)
	sim.day = 5
	Recruits.refresh(sim)
	check(sim.recruit_batch == 0 and sim.recruit_gone.is_empty(),"The next day starts afresh")
	# --- hired
	var c: Dictionary = Recruits.pool(sim,"bartender")[0]
	var good = c.duplicate(true)
	good.speed = 1.3
	good.quality = 1.3
	good.wage = 40
	var id = model.add_item("bartender",0,0,0,good.appearance)
	model.item_by_id(id).staff = Recruits.hired(good)
	var old = model.add_item("bartender",2,0,0)
	sim.sync_staff()
	var a: Actor = sim.staff[id]
	var b: Actor = sim.staff[old]
	check(sim.profiles.get_profile(a.brain.profile_id).name == good.name and int(sim.profiles.get_profile(a.brain.profile_id).age) == int(good.age),"The recruit keeps the name and age on the card")
	check(Recruits.taken(sim,good.key) and not Recruits.taken(sim,Recruits.pool(sim,"bartender")[1].key),"Hired, the candidate leaves the list, the others stay")
	check(is_equal_approx(float(a.brain.speed),1.3) and is_equal_approx(a.speed,1.7*sqrt(1.3)) and is_equal_approx(b.speed,1.7),"A quick employee walks a little faster")
	check(Recruits.stats(model.item_by_id(old)) == {"speed":1.0,"quality":1.0,"wage":Recruits.base_wage("bartender")},"Staff hired before the list work as before")
	# wages: each one's own
	var before = sim.money
	sim.wage_remainder = 0.0
	sim.night.wages = 0
	sim.accrue_wages(60.0)
	check(before-sim.money == 40+Recruits.base_wage("bartender"),"Each employee is paid his own wage (%d $ for the hour)" % (before-sim.money))
	# quality at the bar: the better bartender serves first here
	b.brain.state = "off_shift"
	var bonus = sim.bartender_serve()
	check(is_equal_approx(bonus,sim.profiles.welcome_bonus(a.brain.profile_id)+3.0) and is_equal_approx(sim.bartender_speed(),1.3),"A careful bartender pleases more, a quick one pours more rounds")
	var poor = 0
	a.brain.quality = 0.75
	poor = sim.bartender_serve()
	check(poor < bonus-5.0,"A careless one pleases less")
	# a careful cleaner leaves a shine: the fixture gets dirty more slowly
	var wc = {"kind":"toilet","soil":0.0,"shine":0.3}
	Sanitation.soil(wc,10.0)
	var plain = {"kind":"toilet","soil":0.0}
	Sanitation.soil(plain,10.0)
	check(is_equal_approx(float(wc.soil),7.0) and is_equal_approx(float(plain.soil),10.0),"Cleaned with care, a fixture stays clean longer")
	# saved and loaded
	var copy = BuildingModel.new()
	check(copy.load_checked(JSON.parse_string(JSON.stringify(model.snapshot()))) and copy.item_by_id(id).staff.key == good.key and int(copy.item_by_id(id).staff.wage) == 40,"The hired skills are saved")
	var bad = model.snapshot()
	for item in bad.furniture:
		if int(item.id) == id: item.staff.speed = 9
	check(not copy.load_checked(JSON.parse_string(JSON.stringify(bad))),"Impossible skills are refused")
	bad = model.snapshot()
	bad.furniture.append({"id":999,"kind":"chair","x":-3.0,"z":3.0,"rot":0,"staff":{"speed":1,"quality":1,"wage":10}})
	check(not copy.load_checked(JSON.parse_string(JSON.stringify(bad))),"Only staff have skills")
	Recruits.advertise(sim)
	var saved = Recruits.to_dict(sim)
	var other = ClubSim.new()
	Recruits.from_dict(other,JSON.parse_string(JSON.stringify(saved)))
	check(other.recruit_day == sim.recruit_day and other.recruit_batch == 1,"The day's ads are saved")
	Recruits.from_dict(other,{"day":5,"batch":-3,"gone":[]})
	check(other.recruit_batch == 1,"Damaged hiring data is ignored")
	other.free()
	# let go the same day: not back on the list
	Recruits.let_go(sim,model.item_by_id(id))
	model.remove_item(id)
	check(Recruits.taken(sim,good.key),"Someone let go today does not apply again")
	print("RECRUIT_TESTS: %d checks, %d failures" % [checks,failures])
	if failures == 0: print("RECRUIT_TESTS_PASSED")
	quit(1 if failures > 0 else 0)
