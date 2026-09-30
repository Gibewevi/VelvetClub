class_name BuildingModel
extends RefCounted

var rooms: Array = []
var furniture: Array = []
var parkings: Array = []   # {id,x,z,w,h,kind,rotation}; half-metre modular rows/lanes
var openings: Dictionary = {}
var next_id: int = 1
var error: String = ""
var strict = true   # rules newer than some saves (shower doors kept free, nothing on the street): not enforced on loading
const LIMIT = 24

func uid() -> int:
	var result = next_id
	next_id += 1
	return result

func snapshot() -> Dictionary:
	return {"version":3,"rooms":rooms.duplicate(true),"furniture":furniture.duplicate(true),"openings":openings.duplicate(true),"next_id":next_id,
		"parkings":parkings.duplicate(true)}

func restore(data: Dictionary) -> void:
	rooms = data.rooms.duplicate(true)
	furniture = data.furniture.duplicate(true)
	openings = data.openings.duplicate(true)
	parkings = data.get("parkings",[]).duplicate(true)
	next_id = int(data.next_id)

func rect(room: Dictionary) -> Rect2:
	return Rect2(room.x,room.z,room.w,room.h)

func room_at(p: Vector2) -> Dictionary:
	for room in rooms:
		if rect(room).has_point(p): return room
	return {}

func room_by_id(id: int) -> Dictionary:
	for room in rooms:
		if room.id == id: return room
	return {}

func item_by_id(id: int) -> Dictionary:
	for item in furniture:
		if item.id == id: return item
	return {}

func item_rect(item: Dictionary) -> Rect2:
	var s = Catalog.footprint(item.kind,int(item.rot))
	return Rect2(Vector2(item.x,item.z)-s/2,s)

func valid_room(candidate: Dictionary, except_id: int = -1) -> bool:
	error = ""
	var r = rect(candidate)
	if r.size.x < 2 or r.size.y < 2:
		error = "Une pièce doit mesurer au moins 2 × 2 m."
		return false
	if r.position.x < -LIMIT or r.position.y < -LIMIT or r.end.x > LIMIT or r.end.y > LIMIT:
		error = "Vous avez atteint la limite du terrain."
		return false
	if strict and r.end.y > Street.LOT_FRONT:
		error = "Le trottoir et la rue sont publics : construisez en retrait."
		return false
	for room in rooms:
		if room.id != except_id and r.intersects(rect(room)):
			error = "Les pièces peuvent se toucher, mais pas se chevaucher."
			return false
	for pk in parkings:
		if r.intersects(rect(pk)):
			error = "Un parking occupe déjà cet endroit."
			return false
	if except_id != -1:
		var old = room_by_id(except_id)
		for item in furniture:
			if not old.is_empty() and rect(old).has_point(Vector2(item.x,item.z)) and not r.encloses(item_rect(item)):
				error = "Déplacez le mobilier avant de réduire ce côté."
				return false
	return true

func add_room(x: int, z: int, w: int, h: int, type: int, finishes: Dictionary = {}) -> int:
	var room = {"id":next_id,"x":x,"z":z,"w":w,"h":h,"type":type}
	room.merge(Finishes.defaults(type))
	room.merge(finishes,true)
	if not valid_room(room): return -1
	room.id = uid()
	rooms.append(room)
	return room.id

func set_finishes(id: int, finishes: Dictionary) -> bool:
	var room = room_by_id(id)
	if room.is_empty() or not Finishes.valid(finishes):
		error = "Revêtement ou couleur invalide."
		return false
	for key in ["floor_finish","floor_color","wall_finish","wall_color"]: room[key] = finishes[key]
	return true

func resize_room(id: int, candidate: Dictionary) -> bool:
	if not valid_room(candidate,id): return false
	var room = room_by_id(id)
	for key in ["x","z","w","h"]: room[key] = candidate[key]
	prune_openings()
	return true

func remove_room(id: int) -> void:
	var room = room_by_id(id)
	if room.is_empty(): return
	furniture = furniture.filter(func(i): return not rect(room).has_point(Vector2(i.x,i.z)))
	rooms.erase(room)
	prune_openings()

func valid_item(item: Dictionary, except_id: int = -1) -> bool:
	error = ""
	if not Catalog.ITEMS.has(item.get("kind","")):
		error = "Objet inconnu."
		return false
	var area = item_rect(item)
	var room = room_at(Vector2(item.x,item.z))
	if room.is_empty() or not rect(room).encloses(area):
		error = "Placez l'objet entièrement à l'intérieur d'une pièce."
		return false
	var flat = Catalog.ITEMS[item.kind].get("flat",false)
	var person = Catalog.is_character(item.kind)
	var clear = Catalog.clear_rect(item) if strict else Rect2()
	if clear.size != Vector2.ZERO and not rect(room).encloses(clear):
		error = "La porte de la douche doit s'ouvrir dans la pièce."
		return false
	for other in furniture:
		if other.id == except_id: continue
		# Rugs lie under everything; people may stand on them.
		if flat or Catalog.ITEMS[other.kind].get("flat",false): continue
		if Catalog.is_character(other.kind) or person: pass
		elif clear.size != Vector2.ZERO and clear.grow(-0.04).intersects(item_rect(other).grow(-0.04)):
			error = "Laissez la porte de la douche dégagée."
			return false
		elif strict and Catalog.clear_rect(other).size != Vector2.ZERO and Catalog.clear_rect(other).grow(-0.04).intersects(area.grow(-0.04)):
			error = "Cet objet bloquerait la porte de la douche."
			return false
		if area.grow(-0.06).intersects(item_rect(other).grow(-0.06)):
			if person and Catalog.is_character(other.kind):
				error = "Deux personnes ne peuvent pas occuper la même place."
			else:
				error = "Cet emplacement est déjà occupé."
			return false
	return true

# ------------------------------------------------------------------ car parks

func parking_by_id(id: int) -> Dictionary:
	for pk in parkings:
		if pk.id == id: return pk
	return {}

func parking_at(p: Vector2) -> Dictionary:
	for pk in parkings:
		if rect(pk).has_point(p): return pk
	return {}

func parking_layout(pk: Dictionary) -> Dictionary:
	return Street.layout(rect(pk),int(pk.get("rotation",-1)),str(pk.get("kind","legacy")))

func parking_origin(point: Vector2, rotation: int) -> Vector2:
	# The preview sits under the pointer and snaps to either end of a row.
	# Its existing origin stays fixed when the row is extended.
	var size = Street.row_size(rotation)
	var origin = (point-size/2.0).snapped(Vector2(0.5,0.5))
	var nearest = 1.1
	var result = origin
	for pk in parkings:
		if pk.get("kind","") != "row" or int(pk.get("rotation",-1)) != rotation: continue
		var r = rect(pk)
		var axis = Street.row_axis(rotation)
		var span = r.size.dot(axis)
		for target in [r.position-axis*Street.BAY_W,r.position+axis*span]:
			var distance = origin.distance_to(target)
			if distance < nearest:
				nearest = distance
				result = target
	return result

func row_candidate(origin: Vector2, start: Vector2, end: Vector2, rotation: int) -> Dictionary:
	var axis = Street.row_axis(rotation)
	var delta = (end-start).dot(axis)
	var extra = int(floor((absf(delta)+Street.BAY_W/2.0)/Street.BAY_W))
	var size = Street.row_size(rotation,extra+1)
	var at = origin-axis*(extra*Street.BAY_W) if delta < 0 else origin
	return {"x":at.x,"z":at.y,"w":size.x,"h":size.y,"rotation":rotation,"kind":"row"}

func valid_parking(candidate: Dictionary, except_id: int = -1) -> bool:
	# New modules can be placed anywhere on the lot and linked with lanes.
	error = ""
	var r = rect(candidate)
	if r.size.x <= 0 or r.size.y <= 0:
		error = "Trop petit : une place entière mesure 2,5 × 5 m."
		return false
	if r.position.x < -LIMIT or r.position.y < -LIMIT or r.end.x > LIMIT:
		error = "Vous avez atteint la limite du terrain."
		return false
	if strict and candidate.get("kind","legacy") == "legacy" and absf(r.end.y-Street.LOT_FRONT) > 0.01:
		error = "Le parking doit border le trottoir : c'est par là qu'entrent les voitures."
		return false
	if r.end.y > Street.LOT_FRONT+0.01:
		error = "Le trottoir et la rue sont publics."
		return false
	for room in rooms:
		if r.intersects(rect(room)):
			error = "Un parking ne peut pas empiéter sur une pièce."
			return false
	for pk in parkings:
		if pk.id != except_id and r.intersects(rect(pk)):
			if pk.get("kind","") == "lane" and candidate.get("kind","") in ["row","lane"]: continue
			error = "Les parkings peuvent se toucher, mais pas se chevaucher."
			return false
	if candidate.get("kind","") == "row":
		var rotation = int(candidate.get("rotation",0))
		if rotation < 0 or rotation > 3:
			error = "Orientation de la rangée invalide."
			return false
		var axis = Street.row_axis(rotation)
		var depth = r.size.x if axis.y != 0 else r.size.y
		var count = r.size.dot(axis)/Street.BAY_W
		if not is_equal_approx(depth,Street.BAY_D) or count < 1 or not is_equal_approx(count,roundf(count)):
			error = "Une rangée contient des places entières de 2,5 × 5 m."
			return false
	if strict:
		var lay = parking_layout(candidate)
		if not lay.ok:
			error = lay.error
			return false
		if candidate.get("kind","") == "row":
			for bay in lay.bays:
				var access = Street.bay_access(bay)
				for room in rooms:
					if access.intersects(rect(room)):
						error = "L'entrée des places donne sur un bâtiment. R pour tourner."
						return false
				for pk in parkings:
					if int(pk.id) == except_id: continue
					for other in parking_layout(pk).bays:
						if access.intersects(other.rect) or Street.bay_access(other).intersects(bay.rect):
							error = "Gardez 6 m libres devant les places : ajoutez-les côte à côte, ou de l'autre côté de l'allée."
							return false
	return true

func add_parking(x: float, z: float, w: float, h: float, kind: String = "legacy", rotation: int = -1) -> int:
	var candidate = {"id":next_id,"x":x,"z":z,"w":w,"h":h,"kind":kind,"rotation":rotation}
	if not valid_parking(candidate): return -1
	if kind in ["row","lane"]:
		# Existing asphalt is reusable: trim only the covered lane surface.
		# Never erase a neighbouring row or charge the same ground twice.
		for lane in parkings.duplicate():
			if lane.get("kind","") != "lane" or not rect(lane).intersects(rect(candidate)): continue
			var parts = subtract_rectangle(rect(lane),rect(candidate))
			parkings.erase(lane)
			for i in range(parts.size()):
				var part: Rect2 = parts[i]
				parkings.append({"id":lane.id if i == 0 else uid(),"x":part.position.x,"z":part.position.y,"w":part.size.x,"h":part.size.y,"kind":"lane","rotation":0})
	candidate.id = uid()
	parkings.append(candidate)
	if kind == "row": merge_parking_rows(candidate)
	return candidate.id

static func subtract_rectangle(outer: Rect2, cut: Rect2) -> Array:
	var inner = outer.intersection(cut)
	if not inner.has_area(): return [outer]
	var parts = [Rect2(outer.position,Vector2(outer.size.x,inner.position.y-outer.position.y)),
		Rect2(outer.position.x,inner.end.y,outer.size.x,outer.end.y-inner.end.y),
		Rect2(outer.position.x,inner.position.y,inner.position.x-outer.position.x,inner.size.y),
		Rect2(inner.end.x,inner.position.y,outer.end.x-inner.end.x,inner.size.y)]
	return parts.filter(func(r): return r.size.x >= 0.5 and r.size.y >= 0.5)

func parking_build_price(candidate: Dictionary) -> int:
	var area = 0.0
	var added = rect(candidate).get_area()
	for pk in parkings:
		area += rect(pk).get_area()
		if pk.get("kind","") == "lane": added -= rect(pk).intersection(rect(candidate)).get_area()
	return roundi((area+added)*Street.PRICE_M2)-roundi(area*Street.PRICE_M2)

func merge_parking_rows(row: Dictionary) -> void:
	# Merge only side-by-side identical orientations. No recentering, turning
	# or movement of existing spaces; snapshots make this one undoable action.
	var changed = true
	while changed:
		changed = false
		for other in parkings:
			if other.id == row.id or other.get("kind","") != "row" or other.get("rotation",-1) != row.rotation: continue
			var a = rect(row)
			var b = rect(other)
			var along_z = posmod(int(row.rotation),2) == 1
			var aligned = is_equal_approx(a.position.x,b.position.x) if along_z else is_equal_approx(a.position.y,b.position.y)
			var adjacent = (is_equal_approx(a.end.y,b.position.y) or is_equal_approx(b.end.y,a.position.y)) if along_z else (is_equal_approx(a.end.x,b.position.x) or is_equal_approx(b.end.x,a.position.x))
			if aligned and adjacent:
				var joined = a.merge(b)
				row.x = joined.position.x
				row.z = joined.position.y
				row.w = joined.size.x
				row.h = joined.size.y
				row.id = mini(int(row.id),int(other.id))
				parkings.erase(other)
				changed = true
				break

func parking_extension(id: int, side: int) -> Dictionary:
	var pk = parking_by_id(id)
	if pk.is_empty() or pk.get("kind","") != "row": return {}
	var axis = Street.row_axis(int(pk.rotation))
	var r = rect(pk)
	var at = r.position+axis*(r.size.dot(axis) if side > 0 else -Street.BAY_W)
	var size = Street.row_size(int(pk.rotation))
	return {"x":at.x,"z":at.y,"w":size.x,"h":size.y,"rotation":pk.rotation,"kind":"row"}

func parking_edges(pk: Dictionary) -> Array:
	# Half-metre boundary segments of the union. Shared edges disappear,
	# including between a row and its lane. A bay mouth is always open.
	var r = rect(pk)
	var lay = parking_layout(pk)
	var out: Array = []
	for edge in [[r.position,Vector2(r.end.x,r.position.y),Vector2(0,-1)],
			[Vector2(r.position.x,r.end.y),r.end,Vector2(0,1)],
			[r.position,Vector2(r.position.x,r.end.y),Vector2(-1,0)],
			[Vector2(r.end.x,r.position.y),r.end,Vector2(1,0)]]:
		var normal: Vector2 = edge[2]
		if pk.get("kind","") == "row" and normal == -Street.row_normal(int(pk.rotation)): continue
		var length: float = edge[0].distance_to(edge[1])
		var axis: Vector2 = (edge[1]-edge[0]).normalized()
		for i in range(int(round(length*2.0))):
			var a: Vector2 = edge[0]+axis*(i*0.5)
			var middle = a+axis*0.25
			if not parking_at(middle+normal*0.02).is_empty(): continue
			var driveway = false
			if normal == Vector2(0,1) and is_equal_approx(r.end.y,Street.LOT_FRONT):
				for drive in lay.drives:
					if middle.x > drive.x0 and middle.x < drive.x1: driveway = true
			if not driveway: out.append({"a":a,"b":a+axis*0.5,"normal":normal})
	return out

func remove_parking(id: int) -> void:
	parkings = parkings.filter(func(pk): return pk.id != id)

func modularize_parking(id: int) -> void:
	# Old rectangular saves become one editable row plus free asphalt. Keep
	# the original extent and total paid area, and preserve the row's ID.
	var pk = parking_by_id(id)
	if pk.is_empty() or pk.get("kind","legacy") != "legacy": return
	var lay = parking_layout(pk)
	if not lay.ok: return
	var outer = rect(pk)
	var row: Rect2 = lay.bays[0].rect
	for bay in lay.bays: row = row.merge(bay.rect)
	pk.merge({"x":row.position.x,"z":row.position.y,"w":row.size.x,"h":row.size.y,"kind":"row","rotation":lay.rotation},true)
	var parts = subtract_rectangle(outer,row)
	for part in parts:
		if part.size.x < 0.5 or part.size.y < 0.5: continue
		parkings.append({"id":uid(),"x":part.position.x,"z":part.position.y,"w":part.size.x,"h":part.size.y,"kind":"lane","rotation":0})

func add_item(kind: String, x: float, z: float, rotation: int = 0, appearance: Dictionary = {}) -> int:
	if not Catalog.ITEMS.has(kind): return -1
	var item = {"id":next_id,"kind":kind,"x":x,"z":z,"rot":posmod(rotation,4)}
	if Catalog.is_character(kind): item.appearance = Characters.normalize(appearance,kind)
	if not valid_item(item): return -1
	item.id = uid()
	furniture.append(item)
	return item.id

func purchase_item(kind: String, x: float, z: float, rotation: int = 0, appearance: Dictionary = {}) -> int:
	var id = add_item(kind,x,z,rotation,appearance)
	if id >= 0 and not Catalog.is_character(kind) and int(Catalog.ITEMS[kind].get("price",0)) > 0:
		var item = item_by_id(id)
		item.delivery_pending = true
		item.delivery_key = "%s-%s-%d" % [str(Time.get_unix_time_from_system()),str(randi()),id]
	return id

func set_appearance(id: int, appearance: Dictionary) -> bool:
	var item = item_by_id(id)
	if item.is_empty() or not Catalog.is_character(item.kind) or not Characters.valid(appearance):
		error = "Apparence du personnage invalide."
		return false
	item.appearance = Characters.normalize(appearance,item.kind)
	return true

func move_item(id: int, x: float, z: float, rotation: int) -> bool:
	var item = item_by_id(id)
	if item.is_empty(): return false
	var candidate = item.duplicate()
	candidate.x = x
	candidate.z = z
	candidate.rot = posmod(rotation,4)
	if not valid_item(candidate,id): return false
	item.merge(candidate,true)
	return true

static func edge_key(axis: String, x: int, z: int) -> String:
	return "%s:%d:%d" % [axis,x,z]

func edges() -> Dictionary:
	var result = {}
	for room in rooms:
		for x in range(int(room.x),int(room.x+room.w)):
			for z in [int(room.z),int(room.z+room.h)]:
				var k = edge_key("x",x,z)
				if not result.has(k): result[k] = {"axis":"x","x":x,"z":z,"rooms":[]}
				result[k].rooms.append(room.id)
		for z in range(int(room.z),int(room.z+room.h)):
			for x in [int(room.x),int(room.x+room.w)]:
				var k = edge_key("z",x,z)
				if not result.has(k): result[k] = {"axis":"z","x":x,"z":z,"rooms":[]}
				result[k].rooms.append(room.id)
	return result

func prune_openings() -> void:
	var walls = edges()
	for key in openings.keys():
		if not walls.has(key): openings.erase(key)

func set_opening(key: String, kind: String) -> bool:
	if not edges().has(key):
		error = "Sélectionnez un mur existant."
		return false
	openings[key] = kind
	return true

func cost() -> int:
	# Value of the building: rooms by area, renovated finishes and furniture.
	# Salvaged furniture and debris are worth nothing.
	var total = 0
	for room in rooms: total += int(room.w*room.h)*Catalog.ROOM_PRICE+Finishes.value(room)
	for item in furniture: total += int(Catalog.ITEMS[item.kind].get("price",0))
	var parking_area = 0.0
	for pk in parkings: parking_area += rect(pk).get_area()
	total += roundi(parking_area*Street.PRICE_M2)
	return total

func debris() -> Array:
	return furniture.filter(func(i): return Catalog.is_debris(i.kind))

func remove_item(id: int) -> void:
	var item = item_by_id(id)
	if not item.is_empty(): furniture.erase(item)

func load_checked(data: Variant) -> bool:
	# Validate into a separate model; a damaged save never replaces a live project.
	if not data is Dictionary: return false
	var version = data.get("version")
	if not version in [1,2,3,1.0,2.0,3.0]: return false
	if not data.get("rooms") is Array or not data.get("furniture") is Array or not data.get("openings") is Dictionary: return false
	if data.rooms.size() > 500 or data.furniture.size() > 3000: return false
	var candidate = BuildingModel.new()
	# a shower saved facing a wall stays (unused until it is turned)
	candidate.strict = false
	var ids = {}
	var delivery_keys = {}
	for r in data.rooms:
		if not r is Dictionary: return false
		for key in ["id","x","z","w","h","type"]:
			if not r.get(key) is float and not r.get(key) is int: return false
			if not is_finite(float(r[key])) or float(r[key]) != floor(float(r[key])): return false
		if r.id < 1 or ids.has(int(r.id)) or r.type < 0 or r.type >= Catalog.ROOMS.size(): return false
		if not candidate.valid_room(r): return false
		ids[int(r.id)] = true
		var loaded = r.duplicate(true)
		for key in ["id","x","z","w","h","type"]: loaded[key] = int(r[key])
		if int(version) == 1 or not Finishes.valid(loaded):
			if int(version) == 3: return false
			var keep = loaded.duplicate()
			loaded.merge(Finishes.defaults(int(r.type)),true)
			# Earlier builds' colours stay when their finish still exists.
			for key in ["floor_color","wall_color"]:
				if Finishes.valid_color(keep.get(key)): loaded[key] = keep[key]
			for key in ["floor_finish","wall_finish"]:
				if Finishes.catalog("floor" if key == "floor_finish" else "wall").has(keep.get(key,"")): loaded[key] = keep[key]
		candidate.rooms.append(loaded)
	for item in data.furniture:
		if not item is Dictionary or not Catalog.ITEMS.has(item.get("kind","")): return false
		for key in ["id","x","z","rot"]:
			if not item.get(key) is float and not item.get(key) is int: return false
			if not is_finite(float(item[key])): return false
		if item.id < 1 or item.id != floor(item.id) or ids.has(int(item.id)) or item.rot < 0 or item.rot > 3 or item.rot != floor(item.rot): return false
		var loaded_item = item.duplicate(true)
		loaded_item.id = int(item.id)
		loaded_item.rot = int(item.rot)
		if item.has("delivery_pending"):
			if not item.delivery_pending is bool or Catalog.is_character(item.kind): return false
			if not item.get("delivery_key") is String or item.delivery_key.is_empty() or item.delivery_key.length() > 128: return false
			if delivery_keys.has(item.delivery_key): return false
			delivery_keys[item.delivery_key] = true
		if Catalog.is_character(item.kind):
			if item.has("appearance") and not Characters.valid(item.appearance): return false
			loaded_item.appearance = Characters.normalize(item.get("appearance",{}),item.kind)
		if not candidate.valid_item(loaded_item):
			# Older builds used larger footprints for some objects: keep the
			# project but skip only the pieces that no longer fit.
			if int(version) == 3: return false
			continue
		ids[int(item.id)] = true
		candidate.furniture.append(loaded_item)
	var saved_parks = data.get("parkings",[])
	if not saved_parks is Array or saved_parks.size() > 500: return false
	for pk in saved_parks:
		if not pk is Dictionary: return false
		for key in ["id","x","z","w","h"]:
			if not pk.get(key) is float and not pk.get(key) is int: return false
			if not is_finite(float(pk[key])) or float(pk[key])*2.0 != floor(float(pk[key])*2.0): return false
		if float(pk.id) != floor(float(pk.id)): return false
		var loaded_pk = {"id":int(pk.id),"x":float(pk.x),"z":float(pk.z),"w":float(pk.w),"h":float(pk.h),"kind":str(pk.get("kind","legacy")),"rotation":pk.get("rotation",-1)}
		if not loaded_pk.kind in ["legacy","row","lane"]: return false
		if not loaded_pk.rotation is int and not loaded_pk.rotation is float: return false
		if not is_finite(float(loaded_pk.rotation)) or float(loaded_pk.rotation) != floor(float(loaded_pk.rotation)) or loaded_pk.rotation < -1 or loaded_pk.rotation > 3: return false
		loaded_pk.rotation = int(loaded_pk.rotation)
		if loaded_pk.kind == "row" and loaded_pk.rotation < 0: return false
		if loaded_pk.id < 1 or ids.has(loaded_pk.id) or loaded_pk.w < 0.5 or loaded_pk.h < 0.5: return false
		if not candidate.valid_parking(loaded_pk): continue
		ids[loaded_pk.id] = true
		candidate.parkings.append(loaded_pk)
	var walls = candidate.edges()
	for key in data.openings:
		if not walls.has(key) or not data.openings[key] in ["door","window"]: return false
		candidate.openings[key] = data.openings[key]
	for id in ids: candidate.next_id = maxi(candidate.next_id,id+1)
	candidate.next_id = maxi(candidate.next_id,int(data.get("next_id",1)))
	for pk in candidate.parkings.duplicate(): candidate.modularize_parking(int(pk.id))
	restore(candidate.snapshot())
	return true

func starter() -> void:
	# The modest derelict premises the player takes over: a small hall on the
	# street, a WC, a storeroom and a single bedroom with torn wallpaper and an
	# old carpet. A few salvaged pieces of furniture are kept for free, and
	# technicians must clear the debris. No staff yet.
	parkings.clear()
	rooms.clear()
	furniture.clear()
	openings.clear()
	next_id = 1
	add_room(-4,-1,7,6,0,{"floor_finish":"damaged_wood","floor_color":"a88256","wall_finish":"decay","wall_color":"9a2a3a"})
	add_room(-4,-4,3,3,2,{"floor_finish":"dirty_tile","floor_color":"8a8c98","wall_finish":"dirty_tile","wall_color":"c2cad0"})
	add_room(-1,-4,4,3,3,{"floor_finish":"dirty_tile","floor_color":"7a767e","wall_finish":"decay","wall_color":"8e2e3c"})
	add_room(3,0,4,4,1,{"floor_finish":"worn_carpet","floor_color":"56627e","wall_finish":"torn_wallpaper","wall_color":"6e5a7a"})
	for key in ["x:-2:5","x:-3:-1","x:1:-1","z:3:2"]: set_opening(key,"door")
	for key in ["z:-4:0"]: set_opening(key,"window")
	for entry in [
		# hall: an old sofa by the window, a table, a pillar, posters, a boarded window, rubbish
		["old_sofa",-3.55,1.6,3],["old_table",-3.5,3.4,0],["boards",-3.9,4.4,3],["pillar",0.0,2.0,0],
		["poster",-1.5,-0.9,0],["poster",2.6,-0.9,0],
		["trash_planks",1.5,3.8,0],["trash_papers",-1.2,1.0,0],["trash_papers",2.2,0.5,0],["trash_bottles",-2.8,-0.5,0],
		["trash_bottles",0.8,4.6,0],["trash_cardboard",2.4,2.0,0],["trash_bags",2.5,-0.4,0],["trash_rubble",-3.5,-0.35,0],
		# WC
		["old_toilet",-3.4,-3.5,0],["old_sink",-1.33,-3.0,1],["trash_papers",-2.4,-2.2,0],
		# storeroom
		["old_shelf",1.0,-3.7,0],["old_fridge",2.5,-3.55,0],["trash_bags",-0.4,-1.6,0],["trash_cardboard",2.5,-2.2,0],
		# the bedroom: wardrobe, bedside lamp, bed, armchair on a threadbare rug, plaster rubble
		["old_wardrobe",3.65,0.37,0],["old_lamp",4.6,0.4,0],["old_bed",5.95,1.2,0],
		["old_rug",4.5,3.2,1],["old_armchair",6.4,3.4,1],["trash_rubble",3.8,1.5,0],["trash_bottles",5.2,3.4,0]]:
		if add_item(entry[0],entry[1],entry[2],entry[3]) < 0: push_warning("starter: %s at %s,%s refused (%s)" % [entry[0],entry[1],entry[2],error])

func showcase() -> void:
	# A club laid out like the reference artwork: reception at the street,
	# the lounge-bar with its stage, toilets, stock and staff rooms behind the
	# bar, a corridor to three private rooms.
	rooms.clear()
	furniture.clear()
	openings.clear()
	parkings.clear()
	next_id = 1
	# drawn before the street had a fixed place: it runs onto the sidewalk
	var was_strict = strict
	strict = false
	add_room(-8,-2,12,9,0)
	add_room(-6,-6,5,4,2)
	add_room(-1,-6,5,4,3)
	add_room(4,-6,4,5,4)
	add_room(4,-1,2,12,0,{"floor_finish":"tile","floor_color":"4a4c62","wall_finish":"worn_plaster","wall_color":"8e3044"})
	add_room(6,-1,4,4,1)
	add_room(6,3,4,4,1)
	add_room(6,7,4,4,1)
	add_room(-8,7,5,3,5)
	for key in ["x:-5:7","x:-6:10","x:-4:-2","x:2:-2","z:4:-3","x:5:-1","z:4:4","z:6:0","z:6:4","z:6:8"]: set_opening(key,"door")
	for key in ["z:-8:-1","z:-8:5","x:-5:-6","x:1:-6","x:6:-6","z:10:1","z:10:5","z:10:9"]: set_opening(key,"window")
	# Lounge and bar
	for entry in [
		["backbar",0,-1.75,0],["bar",0,-0.25,0],["stool",-1,0.75,0],["stool",0,0.75,0],["stool",1,0.75,0],
		["sofa",-7.0,2.5,3],["neon",-7.75,2.5,3],["sofa",-5.9,-1.5,0],["coffee",-5.9,-0.2,0],
		["table",-4.5,2.0,0],["chair",-4.5,0.9,0],["chair",-4.5,3.1,2],["chair",-5.6,2.0,3],["chair",-3.4,2.0,1],
		["table",-4.5,5.3,0],["chair",-4.5,4.2,0],["chair",-5.6,5.3,3],["chair",-3.4,5.3,1],
		["dance",0.5,4.0,0],["plant",-7.6,-1.6,0],["plant",3.6,-1.6,0],["plant_big",3.5,6.5,0],["plant",-7.6,6.6,0],
		["sconce",-7.7,0.4,3],["sconce",-7.7,4.6,3],["sconce",-2.4,-1.7,0],["frame",-1.6,-1.9,0],["pink",3.7,1.2,0],
		["purple",-2.4,6.7,0],["red",3.7,-0.7,0],
		# Toilets
		["toilet",-5.3,-5.5,0],["toilet",-4.4,-5.5,0],["urinal",-3.4,-5.775,0],["urinal",-2.8,-5.775,0],["urinal",-2.2,-5.775,0],
		["sink",-1.33,-3.6,1],["bin",-1.3,-2.35,0],["sconce",-5.7,-4.2,3],
		# Stock
		["shelf",0.4,-5.65,0],["crate",2.3,-5.5,0],["fridge",3.5,-5.5,0],["shelf",-0.65,-3.8,3],["crate",0.9,-2.5,0],
		# Staff room
		["locker",5.2,-5.65,0],["desk",7.0,-5.6,0],["chair",7.0,-4.8,2],["plant",7.6,-1.45,0],["mirror",4.25,-3.5,3],
		# Corridor
		["plant",5.5,10.5,0],["sconce",5.7,2.0,1],["sconce",5.7,6.5,1],
		# Private rooms
		["bed",8.4,0.35,0],["lamp",6.95,-0.7,0],["armchair",9.45,2.4,1],["plant",6.45,2.55,0],
		["bed",8.4,4.35,0],["lamp",6.95,3.3,0],["armchair",9.45,6.4,1],
		["bed",8.4,8.35,0],["lamp",6.95,7.3,0],["plant",9.55,10.55,0],
		# Reception / entrance
		["reception",-5.5,8.4,0],["chair",-6.1,7.45,0],["coat_rack",-3.25,8.0,1],["cloak_locker",-7.75,8.0,3],
		["mirror",-7.75,9.3,3],["plant",-3.4,9.6,0],["rug",-5.5,9.4,1],["sconce",-3.8,7.3,0]]:
		add_item(entry[0],entry[1],entry[2],entry[3])
	# Staff at their posts
	add_item("bartender",0,-1.1,0)
	add_item("receptionist",-5.1,7.5,0)
	add_item("security",-4.2,9.3,0)
	add_item("janitor",-3.5,-3.4,0)
	add_item("maid",5.6,-3.3,0)
	add_item("escort",-2.3,3.4,0)
	add_item("escort",-6.3,4.1,0,{"skin":"f0c3a4","hair":"c0482c","outfit":"c01e44","hairstyle":1,"outfit_style":2,"face":1})
	add_item("escort",2.9,2.6,0,{"skin":"8a5a44","hair":"1a1418","outfit":"2a1d30","hairstyle":0,"outfit_style":1,"face":2})
	add_item("escort",7.6,6.4,0,{"skin":"f2c9ab","hair":"e2b25a","outfit":"e8508c","hairstyle":0,"outfit_style":0,"face":0})
	strict = was_strict
