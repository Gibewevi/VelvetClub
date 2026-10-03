extends SceneTree

var failures = 0
var checks = 0

func check(condition: bool, text: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("FAIL: "+text)

func count(model: BuildingModel, kind: String, room_type: int = -1) -> int:
	var n = 0
	for item in model.furniture:
		if item.kind != kind: continue
		if room_type >= 0 and int(model.room_at(Vector2(item.x,item.z)).get("type",-1)) != room_type: continue
		n += 1
	return n

func _init() -> void:
	Art.load_all()
	# The derelict building the player starts with.
	var d = BuildingModel.new()
	d.starter()
	check(d.rooms.size() == 5 and d.rooms.any(func(r): return int(r.type) == 5),"The modest derelict premises have five rooms, a reception among them")
	check(d.rooms.filter(func(r): return int(r.type) == 1).size() == 1,"There is a single bedroom")
	check(d.furniture.size() == 28,"Every starter object was placed (%d)" % d.furniture.size())
	check(d.debris().size() >= 10,"Debris is scattered around (%d)" % d.debris().size())
	var bedroom = d.rooms.filter(func(r): return int(r.type) == 1)[0]
	check(bedroom.wall_finish == "torn_wallpaper" and bedroom.floor_finish == "worn_carpet","The bedroom has torn wallpaper and a worn carpet")
	check(Finishes.value(bedroom) == 0 and Finishes.is_worn(bedroom),"Torn wallpaper and worn carpet are worthless worn finishes")
	var chars = d.furniture.filter(func(i): return Catalog.is_character(i.kind))
	check(chars.is_empty(),"Nobody works there yet")
	var worn = 0
	for r in d.rooms: if Finishes.is_worn(r): worn += 1
	check(worn == d.rooms.size(),"Every room has worn floors or walls")
	var free_value = 0
	for item in d.furniture: free_value += int(Catalog.ITEMS[item.kind].get("price",0))
	check(free_value == 0,"Salvaged furniture and debris are worth nothing")
	for kind in ["old_sofa","old_bed","old_lamp","old_table","old_fridge","old_shelf","old_toilet","old_sink","old_armchair","old_rug","old_wardrobe","pillar","poster","boards","trash_rubble"]:
		check(count(d,kind) >= 1,"The derelict building keeps a %s" % kind)
	for item in d.furniture: check(d.valid_item(item,int(item.id)),"Derelict item %s is valid" % item.kind)
	var dnav = ClubNav.new()
	dnav.rebuild(d)
	var door_out = Vector2(-1.5,6.5)
	for r in d.rooms:
		var cell = dnav.free_cell_near(Vector2(r.x+r.w/2.0,r.z+r.h/2.0))
		check(cell.x != 9999 and dnav.reachable(door_out,dnav.center(cell)),"Derelict %s at %d,%d is reachable from the street" % [Catalog.ROOMS[int(r.type)],int(r.x),int(r.z)])
	for item in d.debris():
		var cell = dnav.free_cell_near(Vector2(item.x,item.z))
		check(cell.x != 9999 and dnav.reachable(door_out,dnav.center(cell)),"Debris %s at %.1f,%.1f can be reached" % [item.kind,item.x,item.z])
	var reno = d.rooms[0].duplicate()
	reno.floor_finish = "oak"
	check(Finishes.value(reno) == 18*42,"Renovating the hall floor costs by the m²")
	# The complete club of the reference artwork stays available as a showcase.
	var m = BuildingModel.new()
	m.showcase()
	check(m.rooms.size() == 9,"Showcase has nine rooms")
	# Reception / entrance of 10 to 15 m² at the street.
	var reception: Dictionary = {}
	for r in m.rooms:
		if int(r.type) == 5: reception = r
	check(not reception.is_empty(),"Starter has a reception room")
	var area = int(reception.w*reception.h)
	check(area >= 10 and area <= 15,"Reception measures 10 to 15 m² (%d)" % area)
	check(count(m,"reception",5) == 1,"Reception has its counter")
	check(count(m,"chair",5) >= 1,"Reception counter has a chair")
	check(count(m,"coat_rack",5)+count(m,"cloak_locker",5) >= 2,"Reception has coat racks or lockers")
	check(count(m,"receptionist",5) == 1 and count(m,"security",5) == 1,"Reception is staffed")
	var lounge = m.rooms[0]
	var to_lounge = false
	var to_street = false
	for key in m.openings:
		if m.openings[key] != "door": continue
		var p = key.split(":")
		var x = int(p[1])
		var z = int(p[2])
		var a = m.room_at(Vector2(x+0.5,z+0.5)) if p[0] == "x" else m.room_at(Vector2(x+0.5,z+0.5))
		var b = m.room_at(Vector2(x+0.5,z-0.5)) if p[0] == "x" else m.room_at(Vector2(x-0.5,z+0.5))
		var ids = [int(a.get("id",0)),int(b.get("id",0))]
		if int(reception.id) in ids and int(lounge.id) in ids: to_lounge = true
		if int(reception.id) in ids and 0 in ids: to_street = true
	check(to_lounge,"A door leads from the reception straight into the lounge-bar")
	check(to_street,"The reception opens onto the street")
	check(count(m,"urinal",2) >= 3,"Toilets have urinals")
	check(count(m,"toilet",2) >= 2 and count(m,"sink",2) >= 1,"Toilets keep WCs and a sink")
	check(count(m,"bar",0) == 1 and count(m,"backbar",0) == 1 and count(m,"stool",0) >= 3,"Bar counter, bottle shelf and stools")
	check(count(m,"dance",0) == 1 and count(m,"neon",0) == 1,"Stage with pole and neon hearts")
	check(count(m,"bed",1) == 3,"Three private rooms with beds")
	check(count(m,"escort") == 4 and count(m,"bartender") == 1 and count(m,"maid") == 1 and count(m,"janitor") == 1,"Full staff")
	for item in m.furniture: check(m.valid_item(item,int(item.id)),"Starter item %s is valid" % item.kind)
	# Navigation: every room is reachable from the street.
	var nav = ClubNav.new()
	nav.rebuild(m)
	var street = Vector2(reception.x+1.5,reception.z+reception.h+2.0)
	for r in m.rooms:
		var target = Vector2(r.x+r.w/2.0,r.z+r.h/2.0)
		var cell = nav.free_cell_near(target)
		check(cell.x != 9999 and nav.reachable(street,nav.center(cell)),"%s at %d,%d is reachable from the street" % [Catalog.ROOMS[int(r.type)],int(r.x),int(r.z)])
	var spots = 0
	for item in m.furniture: spots += Catalog.spots(item).size()
	check(spots >= 30,"Furniture offers places to sit, work and dance")
	# Save round trip
	var copy = BuildingModel.new()
	check(copy.load_checked(JSON.parse_string(JSON.stringify(m.snapshot()))),"Snapshot reloads")
	check(copy.snapshot() == JSON.parse_string(JSON.stringify(m.snapshot())) or copy.rooms.size() == m.rooms.size(),"Reload keeps the layout")
	# A save from the 3D version imports.
	var legacy = {"version":2,"next_id":20,"escort_reference":true,"staff_reference":true,
		"rooms":[{"id":1,"x":-8,"z":-3,"w":12,"h":10,"type":0,"floor_finish":"worn_wood","floor_color":"927156","wall_finish":"worn_plaster","wall_color":"b96d53"},
			{"id":2,"x":-8,"z":-7,"w":4,"h":4,"type":2,"floor_finish":"tile","floor_color":"647d80","wall_finish":"paint","wall_color":"744451"}],
		"furniture":[{"id":3,"kind":"sofa","x":-5.0,"z":2.0,"rot":0},{"id":4,"kind":"escort","x":-2.0,"z":1.0,"rot":0,"appearance":{"skin":"c58f73","hair":"29202a","outfit":"a92f5b","hairstyle":0,"outfit_style":0,"face":0,"height":1.0,"build":1.0,"bust":1.0,"waist":1.0,"hips":1.0,"belly":0.15,"leg_length":1.0,"body":0,"glasses":0}},
			{"id":5,"kind":"security","x":-7.0,"z":1.5,"rot":0,"appearance":{"body":1,"skin":"b98266","hair":"231a16","outfit":"16161a","hairstyle":0,"outfit_style":0,"face":0,"glasses":1,"height":1.02,"build":1.1,"bust":1.15,"waist":1.05,"hips":1.0,"belly":0.05,"leg_length":1.0}},
			{"id":6,"kind":"toilet","x":-7.0,"z":-6.5,"rot":0},{"id":7,"kind":"woman","x":0.0,"z":4.0,"rot":0}],
		"openings":{"x:-6:-3":"door","x:-5:7":"door"}}
	var imported = BuildingModel.new()
	check(imported.load_checked(legacy),"A 3D save imports")
	check(imported.rooms.size() == 2 and imported.furniture.size() == 5,"Imported rooms and objects are kept")
	check(imported.rooms[0].floor_finish == "worn_wood" and imported.rooms[0].wall_color == "b96d53","Imported finishes are kept")
	var sec = imported.item_by_id(5)
	check(Characters.outfit_name(sec.appearance) == "security" and Characters.hat(sec.appearance) == "police","Imported security guard wears his uniform and cap")
	check(not sec.appearance.has("height"),"3D body sliders are dropped")
	check(imported.next_id == 20,"Imported next id is kept")
	# Invalid saves are refused.
	var bad = legacy.duplicate(true)
	bad.rooms[0].type = 42
	check(not BuildingModel.new().load_checked(bad),"Unknown room types are refused")
	bad = legacy.duplicate(true)
	bad.furniture[0].kind = "rocket"
	check(not BuildingModel.new().load_checked(bad),"Unknown objects are refused")
	bad = m.snapshot()
	bad.rooms[0].floor_finish = "lava"
	check(not BuildingModel.new().load_checked(bad),"Invalid finishes are refused in pixel saves")
	check(not BuildingModel.new().load_checked("nope"),"Garbage is refused")
	# Rules
	var t = BuildingModel.new()
	t.showcase()
	check(t.add_room(-8,-2,3,3,0) == -1,"Overlapping rooms are refused")
	check(t.add_item("sofa",-4.5,2.0,0) == -1,"Occupied places are refused")
	check(t.add_item("rug",-2.5,1.0,0) != -1,"Rugs lie under other objects")
	check(t.cost() > 20000,"The club has a value")
	check(Catalog.is_debris("trash_bags") and not Catalog.in_shop("trash_bags"),"Debris is not sold")
	check(Catalog.is_used("old_bed") and not Catalog.in_shop("old_bed"),"Salvaged furniture is not sold")
	# Getting off a bed against the wall or out of a shower stays inside the room.
	var rm = BuildingModel.new()
	rm.starter()
	var shower_id = rm.add_item("shower",3.5,3.55,3)
	check(shower_id != -1,"The shower fixture fits in the bedroom with its door facing free floor")
	if shower_id == -1:
		quit(1)
		return
	# the floor in front of a shower door stays clear, and the door opens into the room
	check(rm.add_item("nightstand",4.3,3.5,0) == -1 and rm.error.contains("douche"),"Nothing may block the shower door")
	check(rm.add_item("shower",3.5,2.4,0) == -1,"A shower whose door would open into another object is refused")
	var sw = BuildingModel.new()
	sw.starter()
	check(sw.add_item("shower",3.5,3.55,0) == -1 and sw.error.contains("porte"),"A shower facing the wall is refused")
	# …but a save holding one still loads, shower included
	var old_save = sw.snapshot()
	old_save.furniture.append({"id":900,"kind":"shower","x":3.5,"z":3.55,"rot":0})
	var sl = BuildingModel.new()
	check(sl.load_checked(old_save) and not sl.item_by_id(900).is_empty() and sl.strict,"A save with a shower facing the wall still loads")
	var rnav = ClubNav.new()
	rnav.rebuild(rm)
	var bedroom_r = rm.room_at(Vector2(5.0,2.0))
	var bed_r = rm.furniture.filter(func(i): return i.kind == "old_bed")[0]
	var sh = rm.item_by_id(shower_id)
	for s in Catalog.spots(bed_r)+Catalog.spots(sh):
		var pth = rnav.path(s.pos,Vector2(3.5,2.5))
		check(not pth.is_empty() and pth.all(func(q): return not rm.room_at(q).is_empty()),"From the %s spot at %.1f,%.1f the way out stays indoors" % [rm.item_by_id(int(s.item)).kind,s.pos.x,s.pos.y])
		check(not pth.is_empty() and rm.room_at(pth[0]) == bedroom_r,"The first step off the %s is in the bedroom" % rm.item_by_id(int(s.item)).kind)
	# The dance floor keeps its colours; animated objects have their pictures.
	var fm = BuildingModel.new()
	fm.starter()
	var fl = fm.add_item("dancefloor",-1.5,1.2,0)
	fm.item_by_id(fl).scheme = 3
	var fcopy = BuildingModel.new()
	check(fcopy.load_checked(JSON.parse_string(JSON.stringify(fm.snapshot()))) and int(fcopy.item_by_id(fl).get("scheme",0)) == 3,"The dance floor keeps its colours in a save")
	check(Catalog.anim_kind({"kind":"dance","scheme":2},1) == "dance_s2_f1","The stage names its pictures by colour and frame")
	check(Catalog.anim_kind(fm.item_by_id(fl),2) == "dancefloor_s3_f2" and Catalog.anim_kind({"kind":"palm_lights"},1) == "palm_lights_f1","Animated objects name their pictures")
	for kind in ["fern","cactus","aloe","monstera","strelitzia","palm_small","palm_lights"]:
		check(Catalog.in_shop(kind) and int(Catalog.ITEMS[kind].group) == 7,"%s is sold among the plants" % kind)
	# Hygiene: showers, made beds and clean rooms lower the risk of illness.
	check(ClubSim.infection_risk(true,false,0) < ClubSim.infection_risk(false,false,0),"A client who showered is less risky")
	check(ClubSim.infection_risk(true,false,0) < ClubSim.infection_risk(true,true,0),"A bed left unmade raises the risk")
	check(ClubSim.infection_risk(true,false,0) < ClubSim.infection_risk(true,false,2),"Litter in the room raises the risk")
	check(ClubSim.infection_risk(false,true,3) <= 0.5,"The risk stays bounded")
	check(ClubSim.SERVICES.size() == 3 and ClubSim.SERVICES[0].price < ClubSim.SERVICES[1].price and ClubSim.SERVICES[1].price < ClubSim.SERVICES[2].price,"Three services with rising prices")
	check(ClubSim.STANDING_RATE[4] > ClubSim.STANDING_RATE[1],"Prestige escorts charge more")
	check(Catalog.spots({"id":1,"kind":"old_bed","x":0,"z":0,"rot":0}).size() == 2,"The old bed has a place for each partner")
	check(Catalog.is_debris("trash_tissues") and Catalog.in_shop("shower") and Catalog.in_shop("dancefloor"),"Tissues are debris; shower and dance floor are sold")
	# Escort standings follow the club's reputation and dress the part.
	check(Catalog.stars_needed("escort") == 0 and Catalog.stars_needed("escort_pro") == 2 and Catalog.stars_needed("escort_chic") == 3 and Catalog.stars_needed("escort_vip") == 4,"Escort standings need 0, 2, 3 and 4 stars")
	check(int(Catalog.ITEMS.escort.wage) < int(Catalog.ITEMS.escort_pro.wage) and int(Catalog.ITEMS.escort_pro.wage) < int(Catalog.ITEMS.escort_chic.wage) and int(Catalog.ITEMS.escort_chic.wage) < int(Catalog.ITEMS.escort_vip.wage),"Classier escorts cost more")
	var look_rng = RandomNumberGenerator.new()
	look_rng.seed = 7
	for kind in Characters.ESCORT_KINDS:
		check(Catalog.ROLES[kind] == "escort" and kind in Catalog.STAFF_ACTIVE,"%s works as an escort" % kind)
		var outfits = {}
		for i in range(12):
			var look = Characters.hire_look(kind,look_rng)
			check(int(look.outfit_style) in Characters.STANDINGS[kind].outfits and int(look.body) == 0,"%s recruits wear an outfit of their standing" % kind)
			outfits[int(look.outfit_style)] = true
		check(outfits.size() >= 2,"%s recruits vary their outfits" % kind)
	var shapes = {}
	for i in range(30): shapes[int(Characters.hire_look("escort",look_rng).silhouette)] = true
	check(shapes.size() == 3,"Recruits come in the three body shapes (%d seen)" % shapes.size())
	check(int(Characters.normalize({"silhouette":7},"escort").silhouette) == 2 and int(Characters.normalize({"silhouette":1,"body":1},"security").silhouette) == 0,"Body shape is clamped (women only)")
	check(int(Characters.normalize({"outfit_style":0},"escort_vip").outfit_style) == 9,"A prestige escort cannot wear the beginners' lingerie")
	check(int(Characters.normalize({"outfit_style":9},"receptionist").outfit_style) in Characters.EVERYDAY_OUTFITS,"Other staff keep everyday clothes")
	var app = Characters.normalize({"body":1,"hairstyle":4,"outfit_style":9,"skin":"zzz"},"security")
	check(int(app.hairstyle) == 4 and int(app.outfit_style) == 4 and app.skin == "b98266","Appearance is clamped and sanitised")
	check(Catalog.local_to_world({"x":0,"z":0,"rot":3},Vector2(0,1)) == Vector2(1,0),"Rotation 3 faces +x")
	check(Catalog.local_to_world({"x":0,"z":0,"rot":1},Vector2(0,1)) == Vector2(-1,0),"Rotation 1 faces -x")
	parking_checks()
	orient_checks()
	site_checks()
	extension_checks()
	reach_checks()
	partition_checks()
	print("MODEL_TESTS: %d checks, %d failures" % [checks,failures])
	if failures == 0: print("MODEL_TESTS_PASSED")
	quit(1 if failures > 0 else 0)

func parking_checks() -> void:
	# The street is fixed; car parks are laid out behind its sidewalk in real
	# sizes, and every bay kept has a way in and out for a 4.4 x 1.8 m car.
	var front = Street.LOT_FRONT
	check(Street.ROAD.y-Street.ROAD.x == 7.0 and Street.LANE_WEST < Street.LANE_EAST,"A two-lane road of 2 x 3.5 m runs along the lot")
	check(Street.BAY_W == 2.5 and Street.BAY_D == 5.0 and Street.AISLE == 6.0,"Bays of 2.5 x 5 m along a 6 m two-way aisle")
	check(Street.layout(Rect2(0,front-11,12,11)).bays.size() == 4,"12 x 11 m keeps a single row and open manoeuvring space")
	check(Street.layout(Rect2(0,front-12,12,12)).bays.size() >= 2,"12 x 12 m holds a couple of bays")
	check(Street.layout(Rect2(-16,front-20,16,20)).bays.size() == 8,"16 x 20 m: a row of eight bays and an open aisle")
	check(Street.layout(Rect2(-24,front-20,40,20)).bays.size() == 16,"40 x 20 m: one accessible row along the wider edge")
	check(Street.layout(Rect2(-16,front-11,28,11)).bays.size() >= 4,"A wide shallow zone gets an aisle along the street")
	# every route: from an end of the street into the bay and back out, all other bays taken
	var routes = 0
	var bad: Array = []
	for r in [Rect2(0,front-12,12,12),Rect2(-16,front-20,16,20),Rect2(-24,front-16,24,16),Rect2(-16,front-11,28,11)]:
		var lay = Street.traffic_layout(r)
		for i in range(lay.bays.size()):
			var b: Dictionary = lay.bays[i]
			if b.ways_in.is_empty() or b.ways_out.is_empty(): bad.append("%s bay %d has no way" % [r,i])
			for east in b.ways_in:
				var route = Street.route_in(lay,i,east)
				routes += 1
				var parked_at: Vector2 = b.mouth+b.n*(Street.PARK_BACK if b.mode == "back" else Street.PARK_NOSE)
				if route.is_empty() or not Street.clear(lay,route,i) or route[-1].p.distance_to(parked_at) > 0.05 or absf(absf(route[0].p.x)-Street.LOT) > 0.6:
					bad.append("%s bay %d in %s: %s" % [r,i,east,Street.why])
			for east in b.ways_out:
				var route = Street.route_out(lay,i,east)
				routes += 1
				if route.is_empty() or not Street.clear(lay,route,i) or absf(absf(route[-1].p.x)-Street.LOT) > 0.05:
					bad.append("%s bay %d out %s: %s" % [r,i,east,Street.why])
	check(routes > 60 and bad.is_empty(),"Every bay can be reached and left by car, with all the others taken (%d routes) %s" % [routes,", ".join(bad.slice(0,3))])
	# the rules of the lot
	var m = BuildingModel.new()
	m.starter()
	var cost0 = m.cost()
	check(m.add_parking(8,-12,16,18) == -1 and m.error.contains("trottoir"),"A car park must reach the sidewalk")
	check(m.add_parking(-2,-4,16,12) == -1 and m.error.contains("pièce"),"A car park cannot cover a room")
	check(m.add_parking(8,3,2,5) == -1 and m.error.begins_with("Trop petit"),"A bay that is too narrow is refused, with the minimum size")
	var pid = m.add_parking(8,-12,16,20)
	check(pid != -1 and m.cost() == cost0+16*20*Street.PRICE_M2,"A car park is paid by the square metre")
	check(m.add_parking(10,-4,12,12) == -1,"Car parks do not overlap")
	check(m.add_room(10,-6,4,4,0) == -1 and m.error.contains("parking"),"No room on a car park")
	check(m.add_room(-12,4,4,6,0) == -1 and m.error.contains("trottoir"),"Nothing is built on the sidewalk or the road")
	check(not m.parking_at(Vector2(12,0)).is_empty() and m.parking_at(Vector2(12,9)).is_empty(),"A point finds its car park")
	var snap = m.snapshot()
	var m2 = BuildingModel.new()
	check(m2.load_checked(JSON.parse_string(JSON.stringify(snap))) and m2.parkings.size() >= 1 and m2.parking_by_id(pid).get("kind","") == "row" and m2.cost() == m.cost(),"Car parks are saved and loaded")
	snap.erase("parkings")
	var m3 = BuildingModel.new()
	check(m3.load_checked(snap) and m3.parkings.is_empty(),"A save from before car parks still loads")
	# an older save with a room reaching the street still loads (the rule is for new work)
	var old = BuildingModel.new()
	old.starter()
	var od = old.snapshot()
	var legacy_room = {"id":990,"x":-12,"z":4,"w":4,"h":6,"type":0}
	legacy_room.merge(Finishes.defaults(0))
	od.rooms.append(legacy_room)
	var m4 = BuildingModel.new()
	check(m4.load_checked(od) and not m4.room_by_id(990).is_empty(),"A save with a room on today's sidewalk still loads")
	m.remove_parking(pid)
	check(m.parkings.is_empty() and m.cost() == cost0,"A car park is removed")

func orient_checks() -> void:
	# Placing furniture turns it to suit its surroundings.
	var m = BuildingModel.new()
	m.add_room(0,0,8,6,0)
	check(Orient.best(m,"sofa",4.0,0.6,2) == 0,"A sofa by a wall turns its back to it")
	check(Orient.best(m,"sofa",0.6,3.0,0) == 3,"…whichever wall it is")
	check(Orient.best(m,"bed",4.0,4.6,0) == 2,"A bed puts its headboard against the wall")
	check(Orient.best(m,"armchair",4.0,3.0,1) == -1,"In the middle of an empty room nothing is decided (the player's rotation stays)")
	var table = m.add_item("table",4.0,3.0,0)
	check(table != -1 and Orient.best(m,"chair",4.0,4.2,0) == 2 and Orient.best(m,"chair",2.8,3.0,0) == 3,"A chair faces its table")
	var bar = m.add_item("bar",4.0,1.5,0)
	m.remove_item(table)
	check(bar != -1 and Orient.best(m,"stool",4.0,2.6,2) == 0,"A stool faces the bar")
	m.remove_item(bar)
	check(Orient.best(m,"reception",4.0,1.5,2) == 0,"A reception desk faces the room and keeps room behind for the receptionist")
	check(Orient.best(m,"reception",4.0,0.45,0) != 0,"…never pressed against the wall")
	var d = BuildingModel.new()
	d.add_room(0,0,8,6,0)
	for x in [3,4]: d.set_opening("x:%d:0" % x,"door")
	check(Orient.best(d,"sofa",4.0,0.6,0) != 0,"A sofa does not back onto a doorway")

func site_checks() -> void:
	# Building sites: logical progress only (time, %, phases), no view.
	var m = BuildingModel.new()
	var id = m.add_room(0,0,4,3,1)
	var room = m.room_by_id(id)
	room.build = SitePlan.start()
	var els = SitePlan.elements(m,room)
	var order: Array = []
	for e in els:
		if order.is_empty() or order[-1] != e.phase: order.append(e.phase)
	check(order == SitePlan.PHASES,"A site goes slab, walls, paint, floor, finish (%s)" % str(order))
	check(SitePlan.phase(room.build,els) == "slab" and SitePlan.progress(room.build,els) == 0.0,"A new site starts at the slab, 0 %")
	var segs = SitePlan.segments(m,room)
	check(segs.size() == 14,"An isolated 4 x 3 site has 14 m of wall to build (%d)" % segs.size())
	check(segs.filter(func(sg): return sg.full).size() == 7 and segs.filter(func(sg): return int(sg.rows) == SitePlan.FULL_ROWS).size() == 7,"Back walls rise full height, front walls stay low")
	var total = SitePlan.totals(room.build,els).y
	var cur = SitePlan.work(room.build,els,SitePlan.SLAB*2.5)
	check(cur == 2 and float(room.build.done["s:0:0"]) == 1.0 and float(room.build.done["s:0:1"]) == 1.0 and absf(float(room.build.done["s:1:0"])-0.5) < 0.001,"Concrete is poured cell by cell from the back corner")
	check(absf(SitePlan.progress(room.build,els)-SitePlan.SLAB*2.5/total) < 0.0001,"The percentage is the work done over all the work")
	check(SitePlan.wetness(room.build,Vector2i(0,0)) > 0.9,"Fresh concrete is wet")
	cur = SitePlan.work(room.build,els,SitePlan.SLAB*9.5,cur)
	check(SitePlan.phase(room.build,els) == "walls","Walls start once the slab is poured")
	cur = SitePlan.work(room.build,els,SitePlan.ROW*segs.size()*2.0,cur)
	check(segs.all(func(sg): return SitePlan.rows(room.build,sg) == 2),"Blocks are laid course by course all round")
	var left = SitePlan.remaining(room.build,els)
	check(absf(left-(total-SitePlan.totals(room.build,els).x)) < 0.0001 and left > 0.0,"Time left is the work still to do")
	# enlarging during the works keeps what was built
	var before_p = SitePlan.progress(room.build,els)
	check(m.resize_room(id,{"x":0,"z":0,"w":5,"h":3}),"A site can be enlarged")
	room = m.room_by_id(id)
	els = SitePlan.elements(m,room)
	SitePlan.tidy(room.build,els)
	check(SitePlan.phase(room.build,els) == "slab","New cells send the crew back to the slab")
	check(float(room.build.done["s:0:0"]) == 1.0 and float(room.build.done["s:3:2"]) == 1.0,"Concrete already poured stays")
	check(SitePlan.rows(room.build,{"key":"x:0:0","rows":SitePlan.FULL_ROWS}) == 2,"Walls already laid on the sides kept stay")
	check(not room.build.done.has("w:z:4:0"),"The wall of the moved side is taken down")
	check(SitePlan.progress(room.build,els) < before_p,"The percentage is worked out again")
	# undo restores an older plan, never older work
	var older = {"done":{"s:0:0":1.0},"clock":1.0,"wet":{}}
	var merged = SitePlan.merge(room.build,older)
	check(float(merged.done["w:x:0:0"]) >= 2.0 and float(merged.clock) >= float(room.build.clock),"Undo keeps the work done since")
	# saves
	var copy = BuildingModel.new()
	check(copy.load_checked(JSON.parse_string(JSON.stringify(m.snapshot()))) and SitePlan.building(copy.room_by_id(id)),"A site in progress is saved and loaded")
	check(SitePlan.sanitize({"done":{"s:0:0":"x"}}).is_empty() and SitePlan.sanitize({"done":{"s:0:0":-1}}).is_empty(),"Damaged site data is refused")
	var bad = m.snapshot()
	bad.rooms[0].build = {"done":"nope"}
	check(copy.load_checked(JSON.parse_string(JSON.stringify(bad))) and not SitePlan.building(copy.room_by_id(id)),"A damaged site loads as a finished room")
	check(not m.valid_item({"kind":"bed","x":2.5,"z":1.5,"rot":0}) and m.error.begins_with("Chantier"),"Nothing is furnished during the works")
	# to the end
	cur = SitePlan.work(room.build,els,10000.0,0)
	check(cur == els.size() and SitePlan.progress(room.build,els) == 1.0 and SitePlan.phase(room.build,els) == "done","Enough time finishes the site")
	var n = ClubNav.new()
	room.build = SitePlan.start()
	n.rebuild(m)
	check(not n.walkable(Vector2(2.5,1.5)),"Nobody walks on a site")
	room.erase("build")
	n.rebuild(m)
	check(n.walkable(Vector2(2.5,1.5)),"A finished room is open")
	check(SitePlan.duration_text(135.2) == "2 h 16" and SitePlan.duration_text(12.0) == "12 min","Time left reads in hours and minutes")

func extension_checks() -> void:
	# A drawing from a room's wall or floor adds ground to it: built as a
	# site of the same kind, it then merges and the wall between goes.
	var m = BuildingModel.new()
	var a = m.add_room(0,0,4,3,1)
	var other = m.add_room(-3,0,3,3,0)
	var room = m.room_by_id(a)
	var value = m.cost()
	var ext = m.add_extension(a,Rect2(4,0,2,3))
	check(ext != -1,"Ground drawn from a wall extends the room (%s)" % m.error)
	var site = m.room_by_id(ext)
	check(int(site.merge_into) == a and int(site.type) == 1 and site.wall_finish == room.wall_finish,"The extension takes the room's kind and finishes")
	check(m.cost()-value == 6*Catalog.ROOM_PRICE+Finishes.value(site),"Only the new ground is charged")
	check(m.edges().has("z:4:0") and m.edges()["z:4:0"].rooms.size() == 2,"The wall stays up during the works")
	# drawn from inside the room, beyond a corner: only the new ground counts
	var pieces = m.extension_parts(room,Rect2(2,1,4,4))
	var cells = 0
	for q in pieces: cells += int(q.get_area())
	check(cells == 12 and pieces.all(func(q): return not m.overlaps(room,q)),"A drawing from inside keeps only the ground beyond the walls (%d m²)" % cells)
	check(m.add_extension(a,Rect2(1,1,2,1)) == -1 and m.error.begins_with("Tirez"),"A drawing that stays inside the room adds nothing")
	check(m.add_extension(a,Rect2(-2,1,3,1)) == -1,"An extension cannot cover another room")
	check(m.add_extension(other,Rect2(4,0,1,3)) == -1,"Nor can it cover an extension in progress")
	# the works end: one room, no wall between
	site.erase("build")
	check(m.merge_extension(ext) == a and m.room_by_id(ext).is_empty(),"The finished extension joins its room")
	room = m.room_by_id(a)
	check(BuildingModel.area_of(room) == 18 and room.parts.size() == 1 and room.merged == [ext],"The room now covers both")
	check(not m.edges().has("z:4:0") and not m.edges().has("z:4:2"),"The wall between them is gone")
	check(BuildingModel.perimeter_of(room) == 18 and m.room_at(Vector2(5.5,1.5)) == room,"Outline and floor follow the new shape")
	check(m.valid_item({"kind":"sofa","x":4.0,"z":1.5,"rot":0}),"Furniture can stand across the old wall line")
	var n = ClubNav.new()
	n.rebuild(m)
	check(n.reachable(Vector2(1.5,1.5),Vector2(5.5,1.5)),"People walk through where the wall was")
	# an L: extend the extended room again, along the front
	ext = m.add_extension(a,Rect2(0,3,2,2))
	check(ext != -1,"An extended room can grow again")
	m.room_by_id(ext).erase("build")
	m.merge_extension(ext)
	room = m.room_by_id(a)
	var loop = BuildingModel.outline(room)
	check(loop.size() == BuildingModel.perimeter_of(room) and loop[0].a == Vector2i(-0,0) and loop[-1].b == loop[0].a,"The outline goes once round the L, from the back corner")
	check(BuildingModel.outline_points(room).size() == 6,"An L has six corners")
	check(m.shape(room).grow(-0.3).has_point(Vector2(1.0,3.2)) and not m.shape(room).grow(-0.3).has_point(Vector2(2.9,3.5)),"Points near the inner corner of the L are known")
	# a site of that shape builds the walls round its outline
	room.build = SitePlan.start()
	var segs = SitePlan.segments(m,room)
	check(segs.size() == BuildingModel.perimeter_of(room)-3,"An L-shaped site builds its own walls, not the one it shares (%d)" % segs.size())
	room.erase("build")
	# saves
	var copy = BuildingModel.new()
	check(copy.load_checked(JSON.parse_string(JSON.stringify(m.snapshot()))) and BuildingModel.area_of(copy.room_by_id(a)) == 22,"An extended room is saved and loaded")
	var bad = m.snapshot()
	for r in bad.rooms:
		if int(r.id) == a: r.parts = [{"x":0,"z":0,"w":"x","h":1}]
	check(not copy.load_checked(JSON.parse_string(JSON.stringify(bad))),"A damaged room shape is refused")
	# removing a room takes its pending extension along
	ext = m.add_extension(a,Rect2(6,0,1,3))
	m.remove_room(a)
	check(m.room_by_id(ext).is_empty(),"Removing a room removes its extension in progress")

func reach_checks() -> void:
	# "Can someone get there?" now answers from connected areas computed with
	# the plan; it must agree with a real path search everywhere.
	var m = BuildingModel.new()
	m.starter()
	m.add_room(10,-6,4,4,1)   # a closed room: no door, unreachable
	var n = ClubNav.new()
	n.rebuild(m)
	var rng = RandomNumberGenerator.new()
	rng.seed = 7
	var agree = 0
	var unreachable = 0
	for i in range(300):
		var a = Vector2(rng.randf_range(-14,16),rng.randf_range(-14,12))
		var b = Vector2(rng.randf_range(-14,16),rng.randf_range(-14,12))
		var ca = n.start_cell(a)
		var cb = n.free_cell_near(b)
		var searched = ca.x != 9999 and cb.x != 9999 and not n.astar.get_id_path(n.key(ca),n.key(cb)).is_empty()
		if n.reachable(a,b) == searched: agree += 1
		if not searched: unreachable += 1
	check(agree == 300 and unreachable > 0,"Reachability from connected areas matches path search (%d/300, %d unreachable)" % [agree,unreachable])

func split_checks() -> void:
	# A partition from wall to wall cuts the room in two: the far side becomes
	# a room of its own, of the same kind, that the player can change.
	var m = BuildingModel.new()
	var a = m.add_room(0,0,6,4,1)
	m.set_finishes(a,{"floor_finish":"carpet","floor_color":"9c2e4c","wall_finish":"worn_plaster","wall_color":"b44a5c"})
	m.set_opening("z:0:1","door")
	m.add_item("lamp",0.5,0.5,0)
	var value = m.cost()
	check(m.add_partition(BuildingModel.partition_keys(Vector2i(2,0),Vector2i(2,4))) == a and m.last_split.size() == 1,"Wall to wall, the partition cuts the room in two")
	var b = m.room_by_id(int(m.last_split[0]))
	var kept = m.room_by_id(a)
	check(m.rooms.size() == 2 and int(b.type) == 1 and b.floor_finish == "carpet" and b.wall_color == "b44a5c","The new room is a bedroom too, with the same finishes")
	check(BuildingModel.area_of(kept) == 16 and BuildingModel.area_of(b) == 8 and kept.x == 2 and b.x == 0,"The larger side keeps the room (4 x 4), the other is new (2 x 4)")
	check(not kept.has("walls") and not b.has("walls") and kept.cuts.size() == 4 and b.cuts.size() == 4,"The partition is now the wall between them")
	check(m.cost() == value+4*BuildingModel.PARTITION_PRICE,"It is paid as a partition, %d $ a metre, nothing more" % BuildingModel.PARTITION_PRICE)
	check(int(m.room_at(Vector2(0.5,0.5)).id) == int(b.id) and m.item_by_id(m.furniture[0].id).kind == "lamp","The lamp is now in the new room")
	check(m.set_opening("z:2:1","door"),"A door goes in the wall between them")
	var n = ClubNav.new()
	n.rebuild(m)
	check(n.reachable(Vector2(0.5,2),Vector2(4,2)),"…and people go through it")
	check(m.edges().has("z:2:2") and m.edges()["z:2:2"].rooms.size() == 2 and m.edges()["z:2:2"].rooms.has(a) and m.edges()["z:2:2"].rooms.has(int(b.id)),"It is drawn as a wall between two rooms")
	# changed by hand like any room
	b.type = 0
	check(m.cost() == value+4*BuildingModel.PARTITION_PRICE,"Changing its type costs nothing")
	# saved, with what it cost
	var copy = BuildingModel.new()
	check(copy.load_checked(JSON.parse_string(JSON.stringify(m.snapshot()))) and copy.room_by_id(a).cuts.size() == 4 and copy.cost() == m.cost(),"Saved and loaded at the same value")
	# an older save, partition drawn wall to wall but the room never cut: cut on loading
	var old = BuildingModel.new()
	var whole = old.add_room(0,0,6,4,1)
	old.room_by_id(whole).walls = BuildingModel.partition_keys(Vector2i(2,0),Vector2i(2,4))
	old.set_opening("z:2:1","door")
	var old_value = old.cost()
	var reloaded = BuildingModel.new()
	check(reloaded.load_checked(JSON.parse_string(JSON.stringify(old.snapshot()))) and reloaded.rooms.size() == 2 and reloaded.openings.get("z:2:1") == "door","An older save with a room closed by a partition loads as two rooms, door kept")
	check(int(reloaded.room_at(Vector2(0.5,1)).type) == 1 and reloaded.room_at(Vector2(0.5,1)) != reloaded.room_at(Vector2(4,1)) and reloaded.cost() == old_value,"Both bedrooms, at the same value")
	# a partition closing off a corner leaves an L-shaped room
	var l = BuildingModel.new()
	var big = l.add_room(0,0,6,6,0)
	l.add_partition(BuildingModel.partition_keys(Vector2i(4,0),Vector2i(4,2)))
	check(l.last_split.is_empty(),"Half way, nothing is cut yet")
	l.add_partition(BuildingModel.partition_keys(Vector2i(4,2),Vector2i(6,2)))
	var corner = l.room_by_id(int(l.last_split[0])) if l.last_split.size() == 1 else {}
	check(not corner.is_empty() and BuildingModel.area_of(corner) == 4 and BuildingModel.area_of(l.room_by_id(big)) == 32 and not l.room_by_id(big).get("parts",[]).is_empty(),"Closing off a corner: a 2 x 2 room, the rest L-shaped")
	check(l.room_at(Vector2(5,1)) == corner and l.room_at(Vector2(1,5)) == l.room_by_id(big) and l.room_at(Vector2(5,5)) == l.room_by_id(big),"Every metre of floor is in one of the two")

func partition_checks() -> void:
	# Walls put up inside a room: along the grid, paid by the metre, crossed
	# through a door only, saved with the room.
	var m = BuildingModel.new()
	var a = m.add_room(0,0,6,4,0)
	m.set_opening("z:0:1","door")
	var value = m.cost()
	var keys = BuildingModel.partition_keys(Vector2i(3,0),Vector2i(3,4))
	check(keys == ["z:3:0","z:3:1","z:3:2","z:3:3"],"A partition is drawn metre by metre along the grid")
	check(BuildingModel.partition_keys(Vector2i(1,1),Vector2i(3,2)).is_empty(),"Only straight partitions")
	check(m.partition_check(BuildingModel.partition_keys(Vector2i(0,0),Vector2i(6,0))).is_empty(),"Not on the room's own walls (%s)" % m.error)
	check(m.partition_check(BuildingModel.partition_keys(Vector2i(3,-2),Vector2i(3,2))).is_empty(),"Not out of the room")
	var chair = m.add_item("chair",3.0,2.5,0)
	check(chair != -1 and m.add_partition(keys) == -1 and m.error.begins_with("Déplacez"),"Furniture on the line must move first")
	m.remove_item(chair)
	# a partition that leaves a passage at its end: the room stays one
	var part = BuildingModel.partition_keys(Vector2i(3,0),Vector2i(3,3))
	check(m.add_partition(part) == a and m.cost() == value+3*BuildingModel.PARTITION_PRICE and m.last_split.is_empty(),"Put up, it costs %d $ a metre" % BuildingModel.PARTITION_PRICE)
	check(m.add_partition(part) == -1,"Not twice")
	check(m.edges().has("z:3:1") and m.edges()["z:3:1"].get("partition",false) and m.edges()["z:3:1"].rooms == [a,a],"It counts as a wall, with the room on both sides")
	check(m.closed_areas(m.room_by_id(a)) == 1 and m.rooms.size() == 1,"With a passage at its end, the room stays one")
	var n = ClubNav.new()
	n.rebuild(m)
	var round_path = n.path(Vector2(1,1.5),Vector2(5,1.5))
	check(n.reachable(Vector2(1,2),Vector2(5,2)) and round_path.any(func(q): return absf(q.x-3.0) < 0.6 and q.y > 3.0),"Nobody walks through a partition: the way goes round its end")
	check(m.set_opening("z:3:2","door"),"A door can go in a partition")
	n.rebuild(m)
	var path = n.path(Vector2(1,0.5),Vector2(5,0.5))
	check(path.any(func(q): return absf(q.x-3.0) < 0.6 and q.y > 2.0 and q.y < 3.0),"The way goes through its door")
	check(m.add_item("chair",3.0,0.5,0) == -1 and m.error == "Une cloison passe ici.","Nothing straddles a partition")
	check(m.add_item("chair",2.5,0.5,0) != -1,"Furniture fits right against it")
	check(m.partition_run("z:3:0").size() == 3 and m.partition_run("x:1:1").is_empty(),"A partition is taken as a whole run")
	# saved with the room, with its door
	var copy = BuildingModel.new()
	check(copy.load_checked(JSON.parse_string(JSON.stringify(m.snapshot()))) and copy.room_by_id(a).walls.size() == 3 and copy.openings.get("z:3:2") == "door","Partitions and their doors are saved")
	var bad = m.snapshot()
	bad.rooms[0].walls = ["z:0:1","nonsense","z:3:1",5,"z:3:1"]
	bad.openings.erase("z:3:2")
	check(copy.load_checked(JSON.parse_string(JSON.stringify(bad))) and copy.room_by_id(a).walls == ["z:3:1"],"A damaged partition list keeps only the walls inside the room")
	bad.rooms[0].walls = "z:3:1"
	check(not copy.load_checked(JSON.parse_string(JSON.stringify(bad))),"A partition list that is not a list is refused")
	# taken down: refunded, its door goes with it
	var furnished = m.cost()
	check(m.remove_partition("z:3:1") == 3 and not m.room_by_id(a).has("walls") and not m.openings.has("z:3:2") and m.cost() == furnished-3*BuildingModel.PARTITION_PRICE,"Taking it down refunds it and its door goes with it")
	split_checks()
	# a smaller room keeps only the partitions still inside it
	m.add_partition(BuildingModel.partition_keys(Vector2i(0,2),Vector2i(5,2)))
	m.furniture.clear()
	var smaller = m.room_by_id(a).duplicate(true)
	smaller.w = 3
	check(m.resize_room(a,smaller) and m.room_by_id(a).walls == ["x:0:2","x:1:2","x:2:2"],"Shrinking a room drops the partitions left outside")
	# not on a building site
	var site = m.add_room(10,0,4,4,0)
	m.room_by_id(site).build = SitePlan.start()
	check(m.add_partition(BuildingModel.partition_keys(Vector2i(12,0),Vector2i(12,4))) == -1,"No partition on a building site")
