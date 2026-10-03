class_name ClubNav
extends RefCounted

# Walkable grid of 0.5 m cells. Characters cross walls only through doors;
# furniture blocks the cells whose centres it covers.
const CELL = 0.5
var astar = AStar2D.new()
var area = Rect2i()
var blocked: Dictionary = {}
var room_of: Dictionary = {}
var zone: Dictionary = {}     # point -> connected area: who can reach whom, without a search
var partitions: Dictionary = {}   # edge key -> true: walls put up inside a room
var walled: Dictionary = {}       # room id -> true when it has partitions
var model: BuildingModel

func key(c: Vector2i) -> int:
	return (c.x-area.position.x)+(c.y-area.position.y)*area.size.x

func cell_of(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x/CELL),floori(p.y/CELL))

func center(c: Vector2i) -> Vector2:
	return Vector2((c.x+0.5)*CELL,(c.y+0.5)*CELL)

func rebuild(building: BuildingModel, delivery_road: bool = false, extra_obstacles: Array = []) -> void:
	model = building
	astar.clear()
	blocked.clear()
	room_of.clear()
	partitions.clear()
	walled.clear()
	for room in model.rooms:
		for k in room.get("walls",[]):
			partitions[k] = true
			walled[int(room.id)] = true
	var b = Rect2(-6,-6,12,12)
	if not model.rooms.is_empty():
		b = model.bounds(model.rooms[0])
		for room in model.rooms: b = b.merge(model.bounds(room))
	b = b.grow(7)
	if delivery_road: b = b.merge(Rect2(-24,8,48,7))
	var L = float(Iso.LOT)
	b = b.intersection(Rect2(-L,-L,2*L,2*L))
	area = Rect2i(floori(b.position.x/CELL),floori(b.position.y/CELL),ceili(b.size.x/CELL)+1,ceili(b.size.y/CELL)+1)
	var obstacles: Array = extra_obstacles.duplicate()
	# nobody but the site crew walks on a building site
	for room in model.rooms:
		if SitePlan.building(room):
			for part in BuildingModel.parts_of(room): obstacles.append((part as Rect2).grow(0.01))
	for item in model.furniture:
		if item.get("delivery_pending",false): continue
		# People walk around (or over) rugs and debris.
		if Catalog.is_character(item.kind) or Catalog.ITEMS[item.kind].get("flat",false) or Catalog.is_debris(item.kind): continue
		for r in Catalog.item_solids(item): obstacles.append(r.grow(.04))
	for r in obstacles:
		var c0 = cell_of(r.position)
		var c1 = cell_of(r.end)
		for cx in range(c0.x,c1.x+1):
			for cy in range(c0.y,c1.y+1):
				var cc = Vector2i(cx,cy)
				if r.has_point(center(cc)): blocked[cc] = true
	var room_cache: Dictionary = {}
	for cx in range(area.position.x,area.end.x):
		for cy in range(area.position.y,area.end.y):
			var cc = Vector2i(cx,cy)
			var room = model.room_at(center(cc))
			room_of[cc] = int(room.id) if not room.is_empty() else 0
			if blocked.has(cc): continue
			astar.add_point(key(cc),center(cc),1.0 if room_of[cc] != 0 else 1.4)
	for cx in range(area.position.x,area.end.x):
		for cy in range(area.position.y,area.end.y):
			var a = Vector2i(cx,cy)
			if not astar.has_point(key(a)): continue
			for d in [Vector2i(1,0),Vector2i(0,1)]:
				var n = a+d
				if astar.has_point(key(n)) and passable(a,n): astar.connect_points(key(a),key(n))
			for d in [Vector2i(1,1),Vector2i(1,-1)]:
				var n = a+d
				if not astar.has_point(key(n)): continue
				var s1 = a+Vector2i(d.x,0)
				var s2 = a+Vector2i(0,d.y)
				if astar.has_point(key(s1)) and astar.has_point(key(s2)) and passable(a,s1) and passable(s1,n) and passable(a,s2) and passable(s2,n):
					astar.connect_points(key(a),key(n))
	# Connected areas, once per layout: "can someone get there?" was a full
	# path search each time (cleaners asked it for every puddle, every frame).
	zone.clear()
	var count = 0
	for id in astar.get_point_ids():
		if zone.has(id): continue
		zone[id] = count
		var stack: Array = [id]
		while not stack.is_empty():
			var q = stack.pop_back()
			for n in astar.get_point_connections(q):
				if not zone.has(n):
					zone[n] = count
					stack.append(n)
		count += 1

func passable(a: Vector2i, b: Vector2i) -> bool:
	var ra = room_of.get(a,0)
	var same = ra == room_of.get(b,0)
	if same and not walled.has(ra): return true
	# Different rooms: the shared boundary must hold a door. Inside a room
	# with partitions: a partition is crossed through its door only.
	var k = ""
	if a.y == b.y:
		var m = maxi(a.x,b.x)
		if same and posmod(m,2) != 0: return true
		k = BuildingModel.edge_key("z",floori(m*CELL),floori(center(a).y))
	else:
		var m = maxi(a.y,b.y)
		if same and posmod(m,2) != 0: return true
		k = BuildingModel.edge_key("x",floori(center(a).x),floori(m*CELL))
	if same and not partitions.has(k): return true
	return model.openings.get(k,"") == "door"

func walkable(p: Vector2) -> bool:
	var c = cell_of(p)
	return area.has_point(c) and astar.has_point(key(c))

func free_cell_near(p: Vector2, same_room: bool = true) -> Vector2i:
	var c = cell_of(p)
	var room = room_of.get(c,0)
	if astar.has_point(key(c)) and area.has_point(c): return c
	for radius in range(1,5):
		var best = Vector2i(9999,9999)
		var best_d = 1e9
		for dx in range(-radius,radius+1):
			for dy in range(-radius,radius+1):
				var n = c+Vector2i(dx,dy)
				if not area.has_point(n) or not astar.has_point(key(n)): continue
				if same_room and room_of.get(n,0) != room: continue
				var d = center(n).distance_squared_to(p)
				if d < best_d:
					best_d = d
					best = n
		if best.x != 9999: return best
	return Vector2i(9999,9999)

func start_cell(from: Vector2) -> Vector2i:
	# Someone getting off a bed or out of a shower steps into the same room,
	# never into the next room or the street behind the wall.
	var a = free_cell_near(from,true)
	return a if a.x != 9999 else free_cell_near(from,false)

func path(from: Vector2, to: Vector2, exact_end: bool = true) -> Array:
	var a = start_cell(from)
	var b = free_cell_near(to)
	if a.x == 9999 or b.x == 9999: return []
	var pts: PackedVector2Array = astar.get_point_path(key(a),key(b))
	if pts.is_empty(): return []
	var out: Array = []
	for p in pts: out.append(p)
	if exact_end: out.append(to)
	return out

func reachable(from: Vector2, to: Vector2) -> bool:
	var a = start_cell(from)
	var b = free_cell_near(to)
	if a.x == 9999 or b.x == 9999: return false
	return int(zone.get(key(a),-1)) == int(zone.get(key(b),-2))
