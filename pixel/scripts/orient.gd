class_name Orient
extends RefCounted

# Automatic orientation while placing furniture: each rotation that fits is
# scored on the item's surroundings and the best one is kept. A sofa puts
# its back to the nearest wall and turns towards a coffee table, a chair
# faces its table, a stool the bar, a bed its headboard to the wall, a bar
# or a reception desk leaves room behind for whoever serves. Without a
# clear reason (middle of a room, nothing around), nothing is decided and
# the player's rotation stands. Local -z is always an item's back.

const FLUSH = 0.35        # a back this close to a wall stands against it
const REACH = 2.6         # how far an item looks for what it should face

# back against a wall
const WALL_BACKED = ["sofa","old_sofa","armchair","old_armchair","bed","heart_bed","old_bed","backbar","neon","sconce","mirror","frame",
	"poster","boards","toilet","old_toilet","urinal","sink","old_sink","shelf","old_shelf","locker","old_locker","fridge",
	"old_fridge","old_wardrobe","cabinet","coat_rack","cloak_locker","desk","shower","nightstand","crate"]
# a counter: someone works behind it, so its back keeps a free strip
const COUNTERS = {"bar":["backbar"],"reception":[]}
# what an item turns towards, and which of its sides is its front
const FACES = {
	"chair":{"targets":["table","old_table","desk","coffee"],"front":Vector2(0,1)},
	"stool":{"targets":["bar"],"front":Vector2(0,-1)},
	"sofa":{"targets":["coffee","table","old_table","dance"],"front":Vector2(0,1)},
	"old_sofa":{"targets":["coffee","table","old_table","dance"],"front":Vector2(0,1)},
	"armchair":{"targets":["coffee","table","old_table"],"front":Vector2(0,1)},
	"old_armchair":{"targets":["coffee","table","old_table"],"front":Vector2(0,1)},
	"backbar":{"targets":["bar"],"front":Vector2(0,1)},
}

static func applies(kind: String) -> bool:
	return kind in WALL_BACKED or COUNTERS.has(kind) or FACES.has(kind)

static func best(model: BuildingModel, kind: String, x: float, z: float, current: int, except_id: int = -1) -> int:
	# The rotation this item should have here, or -1 when nothing decides.
	if not applies(kind): return -1
	var best_rot = -1
	var best_score = 2.5      # below this, the surroundings say nothing clear
	for r in range(4):
		var item = {"kind":kind,"x":x,"z":z,"rot":r}
		if not model.valid_item(item,except_id): continue
		var s = score(model,item,except_id)+(0.5 if r == posmod(current,4) else 0.0)
		if s > best_score:
			best_score = s
			best_rot = r
	return best_rot

static func score(model: BuildingModel, item: Dictionary, except_id: int = -1) -> float:
	var kind: String = item.kind
	var s = 0.0
	var back = Catalog.direction_to_world(item,Vector2(0,-1))
	var gap = wall_gap(model,item,back)
	if kind in WALL_BACKED and gap <= FLUSH:
		s += 10.0-gap*10.0
		if door_behind(model,item,back): s -= 8.0
	if COUNTERS.has(kind):
		# the free strip behind, up to a wall or the back bar
		var behind = gap
		for other in model.furniture:
			if int(other.id) == except_id or not other.kind in COUNTERS[kind]: continue
			var d = strip_to(model.item_rect(item),model.item_rect(other),back)
			if d >= 0.0: behind = minf(behind,d)
		if behind >= 0.6 and behind <= 2.6: s += 9.0-absf(behind-1.1)
		elif behind < 0.6: s -= 6.0
	if FACES.has(kind):
		var rule: Dictionary = FACES[kind]
		var front = Catalog.direction_to_world(item,rule.front)
		var at = Vector2(item.x,item.z)
		var nearest = INF
		var aim = 0.0
		for other in model.furniture:
			if int(other.id) == except_id or not other.kind in rule.targets: continue
			var to = Vector2(other.x,other.z)-at
			var d = to.length()-(model.item_rect(other).size.length()/2.0)
			if d > REACH or d >= nearest or to.length() < 0.01: continue
			nearest = d
			aim = front.dot(to.normalized())
		if aim > 0.6: s += 12.0*aim
		elif nearest < INF and aim < -0.3: s -= 4.0
	return s

static func wall_gap(model: BuildingModel, item: Dictionary, back: Vector2) -> float:
	# Distance from the item's back to the wall of its room behind it.
	var room = model.room_at(Vector2(item.x,item.z))
	if room.is_empty(): return INF
	var r = model.item_rect(item)
	var rr = model.part_at(room,Vector2(item.x,item.z))
	if back.y < -0.5: return r.position.y-rr.position.y
	if back.y > 0.5: return rr.end.y-r.end.y
	if back.x < -0.5: return r.position.x-rr.position.x
	return rr.end.x-r.end.x

static func door_behind(model: BuildingModel, item: Dictionary, back: Vector2) -> bool:
	# Backing onto a doorway would block it.
	var room = model.room_at(Vector2(item.x,item.z))
	if room.is_empty(): return false
	var r = model.item_rect(item)
	var rr = model.part_at(room,Vector2(item.x,item.z))
	if absf(back.y) > 0.5:
		var zw = int(rr.position.y if back.y < 0 else rr.end.y)
		for cx in range(floori(r.position.x),ceili(r.end.x)):
			if model.openings.get(BuildingModel.edge_key("x",cx,zw),"") == "door": return true
	else:
		var xw = int(rr.position.x if back.x < 0 else rr.end.x)
		for cz in range(floori(r.position.y),ceili(r.end.y)):
			if model.openings.get(BuildingModel.edge_key("z",xw,cz),"") == "door": return true
	return false

static func strip_to(a: Rect2, b: Rect2, back: Vector2) -> float:
	# The gap from a's back to b when b lies straight behind it, else -1.
	if absf(back.y) > 0.5:
		if a.end.x <= b.position.x or b.end.x <= a.position.x: return -1.0
		return a.position.y-b.end.y if back.y < 0 else b.position.y-a.end.y
	if a.end.y <= b.position.y or b.end.y <= a.position.y: return -1.0
	return a.position.x-b.end.x if back.x < 0 else b.position.x-a.end.x
