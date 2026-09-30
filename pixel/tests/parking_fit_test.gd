extends SceneTree

var failures = 0
var checks = 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+message)

func inspect(model: BuildingModel) -> void:
	for i in range(model.parkings.size()):
		var pk: Dictionary = model.parkings[i]
		var lay = model.parking_layout(pk)
		for bay in lay.bays:
			check(model.rect(pk).encloses(bay.rect),"Bay fully inside its row")
			check(bay.n == Street.row_normal(int(lay.rotation)),"No unexpected turn inside a row")
			for other in lay.bays:
				if other.index != bay.index: check(not Street.bay_access(bay).intersects(other.rect),"No bay behind another bay's entrance")
		for j in range(i): check(not model.rect(pk).intersects(model.rect(model.parkings[j])),"Modules have no overlapping surfaces")
		for edge in model.parking_edges(pk):
			check(model.parking_at(edge.a.lerp(edge.b,0.5)+edge.normal*0.02).is_empty(),"No kerb between connected surfaces")

func _init() -> void:
	for rotation in range(4):
		for count in [1,2,5]:
			var size = Street.row_size(rotation,count)
			var lay = Street.layout(Rect2(Vector2(-10,-10),size),rotation,"row")
			check(lay.ok and lay.bays.size() == count,"One straight row in each orientation")
			for bay in lay.bays:
				check(bay.rect.size == Street.row_size(rotation),"Exact 2.5 x 5 m module")
				check(bay.n == Street.row_normal(rotation),"Stop and entrance face the requested way")
	# Extending a row neither re-centres its bays nor changes its identity.
	var m = BuildingModel.new()
	m.starter()
	var cost0 = m.cost()
	var id = m.add_parking(8,-4,5,2.5,"row",1)
	check(id != -1 and m.cost() == cost0+375,"A single place can be built away from the sidewalk")
	var first: Rect2 = m.parking_layout(m.parking_by_id(id)).bays[0].rect
	var next = m.parking_extension(id,1)
	check(m.parking_build_price(next) == 375,"Only the new place is charged")
	var joined = m.add_parking(next.x,next.z,next.w,next.h,next.kind,next.rotation)
	check(joined == id and m.parkings.size() == 1,"Adjacent rows join and preserve the existing ID")
	var row = m.parking_by_id(id)
	check(m.parking_layout(row).bays[0].rect == first,"Existing bay keeps its exact footprint")
	check(m.parking_layout(row).bays.size() == 2 and m.cost() == cost0+750,"Two side-by-side places cost exactly twice one")
	check(m.parking_origin(Vector2(10.6,2.2),1) == Vector2(8,1),"Next preview snaps to the exact end of the row")
	var reverse = m.row_candidate(Vector2(8,1),Vector2(10.5,2.25),Vector2(10.5,-2.75),1)
	check(reverse.z == -4 and reverse.h == 7.5,"Reverse drag extends only along the row axis")
	check(not m.valid_parking({"x":13,"z":-4,"w":5,"h":5,"kind":"row","rotation":1}),"Tandem rows blocking the mouths are refused")
	check(m.add_parking(13,-4,6,12,"lane",0) != -1,"An aisle connects the row to the street")
	check(m.add_parking(19,-4,5,5,"row",3) != -1,"A facing row shares the six-metre aisle")
	inspect(m)
	var loaded = BuildingModel.new()
	check(loaded.load_checked(JSON.parse_string(JSON.stringify(m.snapshot()))),"Half-metre modules reload")
	check(loaded.snapshot() == m.snapshot(),"Footprints, orientations and IDs survive a round trip")
	check(loaded.cost() == m.cost(),"Reload preserves total value")
	# Repaint existing asphalt without paying for it twice or leaving overlaps.
	var asphalt = BuildingModel.new()
	asphalt.add_parking(0,-10,10,5,"lane",0)
	var cost = asphalt.cost()
	var painted = {"x":0,"z":-10,"w":2.5,"h":5,"kind":"row","rotation":0}
	check(asphalt.valid_parking(painted) and asphalt.parking_build_price(painted) == 0,"Places reuse a lane's asphalt for free")
	var painted_id = asphalt.add_parking(0,-10,2.5,5,"row",0)
	check(painted_id != -1 and asphalt.cost() == cost,"Reusing asphalt preserves the total paid surface")
	inspect(asphalt)
	check(asphalt.parking_build_price({"x":0,"z":-5,"w":10,"h":5,"kind":"lane","rotation":0}) == 1500,"New asphalt charges only new area")
	# Existing saves are reorganised, not deleted or expanded.
	var old = BuildingModel.new()
	var legacy = old.add_parking(8,-12,16,20)
	var legacy_cost = old.cost()
	var migrated = BuildingModel.new()
	check(migrated.load_checked(JSON.parse_string(JSON.stringify(old.snapshot()))),"V36 car park migrates")
	var recovered = migrated.parking_by_id(legacy)
	check(recovered.get("kind","") == "row" and migrated.parking_layout(recovered).bays.size() == 8,"Old tandem grid becomes one extensible row")
	check(migrated.parkings.size() > 1 and migrated.cost() == legacy_cost,"Remaining old surface becomes an aisle at no extra cost")
	inspect(migrated)
	var bad = m.snapshot()
	bad.parkings[0].rotation = 1.5
	check(not BuildingModel.new().load_checked(bad),"Invalid saved orientations are rejected")
	# Red preview conditions are shared by both click and extension.
	check(not m.valid_parking({"x":8,"z":-4,"w":5,"h":2.5,"kind":"row","rotation":1}),"Existing place cannot be overwritten")
	check(not m.valid_parking({"x":23,"z":0,"w":5,"h":2.5,"kind":"row","rotation":1}),"Module beyond the lot is refused")
	print("PARKING_FIT_TESTS: %d checks, %d failures" % [checks,failures])
	if failures == 0: print("PARKING_FIT_TESTS_PASSED")
	quit(1 if failures > 0 else 0)
