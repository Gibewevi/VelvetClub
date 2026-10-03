extends SceneTree

# Furniture belongs in its kind of room: no reception desk in the toilets.
# An empty room takes the kind of the first piece put in it.

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
	var m = BuildingModel.new()
	var hall = m.add_room(0,0,6,5,0)
	var wc = m.add_room(6,0,3,3,2)
	var front = m.add_room(0,5,4,3,5)
	m.add_item("toilet",7.5,1.0,0)
	m.add_item("reception",2.0,6.5,0)
	m.add_item("sofa",3.0,2.5,0)
	# the rules themselves
	check(not Catalog.fits_room("reception",2) and not Catalog.fits_room("toilet",5),"No reception desk in the toilets, no WC at the reception")
	check(Catalog.fits_room("armchair",0) and Catalog.fits_room("armchair",1) and Catalog.fits_room("old_wardrobe",5),"An armchair suits a lounge or a bedroom, a wardrobe the reception")
	check(Catalog.fits_room("shower",2) and Catalog.fits_room("shower",1) and not Catalog.fits_room("shower",0),"A shower goes in a bedroom or the toilets")
	check(Catalog.fits_room("lamp",2) and Catalog.fits_room("fern",3) and Catalog.fits_room("maid",2),"Lights, plants and people go anywhere")
	check(Catalog.home_room("toilet") == 2 and Catalog.home_room("lamp") == -1,"A WC makes toilets, a lamp makes nothing")
	# refused in a furnished room of another kind, with the reason
	check(m.add_item("reception",7.5,2.4,0) == -1 and m.error.contains("Réception") and m.error.contains("Toilettes"),"A reception desk is refused in the toilets (%s)" % m.error)
	check(m.add_item("urinal",1.0,6.0,0) == -1 and m.error.contains("Toilettes"),"A urinal is refused at the reception")
	check(m.add_item("bed",2.0,1.6,0) == -1 and m.room_by_id(hall).type == 0,"A bed is refused in a furnished lounge, which stays a lounge")
	check(m.add_item("table",1.0,1.0,0) != -1 and m.last_retype == "","A table goes in the lounge as usual")
	# an empty room takes the kind of its first piece
	var spare = m.add_room(0,-4,4,4,0)
	m.add_item("fern",0.5,-3.5,0)
	m.add_item("maid",3.5,-0.5,0)
	check(m.bare(m.room_by_id(spare)),"A plant and an employee leave a room bare")
	var wc2 = m.add_item("toilet",2.0,-3.4,0)
	check(wc2 != -1 and int(m.room_by_id(spare).type) == 2 and m.last_retype == "Toilettes","A WC turns the empty room into toilets")
	check(m.add_item("sink",0.8,-1.5,0) != -1 and m.last_retype == "","More fixtures follow without change")
	check(m.add_item("bar",2.0,-2.0,0) == -1 and m.error.contains("Videz la pièce"),"Now furnished, it refuses a bar and says how to change it")
	# moving the only piece into another empty room
	var spare2 = m.add_room(-4,0,4,4,0)
	var desk = m.add_item("desk",-2.0,1.0,0)
	check(int(m.room_by_id(spare2).type) == 4,"A desk makes a staff room")
	check(m.move_item(desk,-2.0,2.0,0) and m.last_retype == "","Moving it inside its room changes nothing")
	# changing a room's type by hand: its furniture must fit
	check(m.misfits(m.room_by_id(wc),5).size() == 1 and m.misfits(m.room_by_id(spare2),4).is_empty(),"A WC has no place in a reception; a desk does in a staff room")
	# older saves with furniture in the wrong room still load
	var data = m.snapshot()
	for r in data.rooms:
		if int(r.id) == wc: r.type = 0
	var loaded = BuildingModel.new()
	check(loaded.load_checked(data),"A save with a WC in a lounge still loads")
	print("ROOM_FIT_TESTS: %d checks, %d failures" % [checks,failures])
	if failures == 0: print("ROOM_FIT_TESTS_PASSED")
	quit(1 if failures > 0 else 0)
