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

func head(info: Dictionary) -> Dictionary:
	for part in info.get("parts",[]):
		if part.name == "head": return part
	return {}

func stable_top(a: Dictionary, b: Dictionary) -> bool:
	var first = Art.image(a.file)
	var second = Art.image(b.file)
	for y in range(-int(a.oy),-int(a.oy)+12):
		for x in range(-int(a.ox),-int(a.ox)+first.get_width()):
			var p = Vector2i(x+int(b.ox),y+int(b.oy))
			var color = second.get_pixelv(p) if Rect2i(Vector2i.ZERO,second.get_size()).has_point(p) else Color.TRANSPARENT
			var original = first.get_pixel(x+int(a.ox),y+int(a.oy))
			# A neighbouring blanket can own a shared dark outline pixel; the
			# actual upholstered surface must stay unchanged between states.
			if original.a > .5 and color.a > .5 and original.r > .25 and color.r > .25 and original != color: return false
	return true

func run() -> void:
	Art.load_all()
	check(Catalog.in_shop("heart_bed") and "heart_bed" in ClubSim.BED_KINDS,"Heart bed is available in the furniture shop and recognised as a bed")
	for rotation in range(4):
		check(Catalog.footprint("heart_bed",rotation) == Catalog.footprint("bed",rotation),"Both beds keep the same modular footprint")
		var original = head(Art.furniture_entry("heart_bed",rotation))
		check(not original.is_empty(),"Heart headboard has its own sorting part")
		var image = Art.image(original.file)
		var gold_pixels = 0
		for y in range(image.get_height()):
			for x in range(image.get_width()):
				var c = image.get_pixel(x,y)
				if c.a > .5 and c.r > .65 and c.g > .4 and c.b < c.g*.8: gold_pixels += 1
		if rotation in [0,3]: check(gold_pixels > 12,"Front-facing heart headboard has a readable gold border")
		for state in ["unmade","busy","busy_1","busy_2","busy_3"]:
			var info = Art.furniture_entry("heart_bed_"+state,rotation)
			check(not info.is_empty(),"Heart bed retains its own appearance in every state and rotation")
			if not info.is_empty(): check(stable_top(original,head(info)),"Upper heart upholstery stays stable outside shared outline occlusion")
	var model = BuildingModel.new()
	model.add_room(-5,-5,10,10,1)
	var id = model.add_item("heart_bed",0,0,0)
	var maid_id = model.add_item("maid",-2,3,0)
	check(id != -1,"Heart bed can be placed in a bedroom")
	var restored = BuildingModel.new()
	check(restored.load_checked(model.snapshot()) and restored.item_by_id(id).kind == "heart_bed","New model survives a save/load round trip")
	check(Deliveries.package_size(model.item_by_id(id)) == 2,"Heart bed uses a large delivery package")
	var view = WorldView.new()
	root.add_child(view)
	view.setup(model)
	var sim = ClubSim.new()
	root.add_child(sim)
	sim.setup(model,view)
	sim.active = false
	check(sim.free_bed().get("id",-1) == id,"Simulation can find the heart bed in a bedroom")
	var item = model.item_by_id(id)
	item.delivery_pending = true
	check(sim.free_bed().is_empty(),"Undelivered heart bed remains unusable")
	item.erase("delivery_pending")
	item.unmade = true
	view.refresh_bed(id)
	check(view.bed_variant(item) == "heart_bed_unmade","Unmade model keeps its heart headboard")
	var maid: Actor = sim.staff[maid_id]
	for i in range(600):
		sim.staff_ai(maid,.05)
		if not item.get("unmade",false): break
	check(not item.get("unmade",false),"Cleaner can remake the new bed")
	print("BED_CHECKS: %d failures: %d" % [checks,failures])
	if failures == 0: print("BED_TESTS_PASSED")
	quit(0 if failures == 0 else 1)
