class_name BarStock
extends RefCounted

# One unit is one glass; four glasses use one visible bottle. Item keys survive
# undo/redo. The ledger owns stock, so a building edit cannot recreate alcohol.
const CARTON = 48
const STATES = ["stock_walk","stock_pick","stock_carry","stock_fill","stock_return"]
var sim
var ledger: Dictionary = {}
var tasks: Dictionary = {}
var claimed: Dictionary = {}

static func initialize(item: Dictionary, legacy: bool = false) -> void:
	var cap = Catalog.stock_capacity(item.kind)
	if cap <= 0: return
	if not item.get("stock_key") is String or String(item.get("stock_key","")).is_empty():
		item.stock_key = "%s-%d-%d" % [str(Time.get_unix_time_from_system()),randi(),int(item.id)]
	if not item.has("stock"):
		item.stock = cap if item.kind == "bottle_crate" or legacy else 0
	item.stock = clampi(int(item.stock),0,cap)

func setup(owner_sim) -> void:
	sim = owner_sim

func reset() -> void:
	if sim != null:
		for a in sim.staff.values():
			if is_instance_valid(a): interrupt(a)
	ledger.clear()
	tasks.clear()
	claimed.clear()

func sync() -> void:
	for item in sim.model.furniture:
		if Catalog.stock_capacity(item.kind) <= 0: continue
		initialize(item,not item.has("stock"))
		var key: String = item.stock_key
		if not ledger.has(key): ledger[key] = int(item.stock)+int(item.get("stock_overflow",0))
		item.erase("stock_overflow")
		var previous_stock = clampi(int(ledger[key]),0,Catalog.legacy_stock_capacity(item.kind))
		var cap = Catalog.stock_capacity(item.kind)
		if previous_stock > cap:
			# Old saved stock that no longer fits is bought back at its carton price,
			# once. The inventory ledger is authoritative even after undo or reload.
			var refund = roundi((previous_stock-cap)*int(Catalog.ITEMS.bottle_crate.price)/float(CARTON))
			sim.money += refund
			sim.ledger.book(sim.day,"in","resale",refund)
		item.stock = mini(previous_stock,cap)
		ledger[key] = int(item.stock)
		refresh(item)

func set_stock(item: Dictionary, value: int) -> void:
	if item.is_empty(): return
	initialize(item)
	item.stock = clampi(value,0,Catalog.stock_capacity(item.kind))
	ledger[item.stock_key] = int(item.stock)
	refresh(item)

func refresh(item: Dictionary) -> void:
	if sim.view != null: sim.view.refresh_stock(int(item.id))

func active(item: Dictionary) -> bool:
	if item.is_empty() or item.get("delivery_pending",false): return false
	var room = sim.model.room_at(Vector2(item.x,item.z))
	return not room.is_empty() and not SitePlan.building(room)

func shelves(bar: Dictionary) -> Array:
	if not active(bar): return []
	var room = sim.model.room_at(Vector2(bar.x,bar.z))
	return sim.model.furniture.filter(func(i): return Catalog.bottle_shelf(i.kind) and active(i) and sim.model.room_at(Vector2(i.x,i.z)) == room and Vector2(i.x,i.z).distance_to(Vector2(bar.x,bar.z)) <= 6.0)

func available(bar: Dictionary) -> int:
	var n = 0
	for shelf in shelves(bar): n += int(shelf.get("stock",0))
	return n

func bar_at_client(a: Actor) -> Dictionary:
	var item = sim.model.item_by_id(int(a.brain.get("spot",{}).get("item",-1)))
	if not item.is_empty() and item.kind in Catalog.BARS: return item
	return nearest_bar(a.world)

func nearest_bar(at: Vector2) -> Dictionary:
	var room = sim.model.room_at(at)
	var best: Dictionary = {}
	var distance = 3.5
	for bar in sim.model.furniture:
		if not bar.kind in Catalog.BARS or not active(bar) or sim.model.room_at(Vector2(bar.x,bar.z)) != room: continue
		var d = Vector2(bar.x,bar.z).distance_to(at)
		if d < distance:
			distance = d
			best = bar
	return best

func cluster(bar: Dictionary) -> Array:
	if bar.kind != "bar_module": return [int(bar.id)]
	var out: Array = [int(bar.id)]
	var pending: Array = [bar]
	while not pending.is_empty():
		var current: Dictionary = pending.pop_back()
		for item in sim.model.furniture:
			if item.kind != "bar_module" or int(item.id) in out or not active(item): continue
			if sim.model.room_at(Vector2(item.x,item.z)) != sim.model.room_at(Vector2(bar.x,bar.z)): continue
			if sim.model.item_rect(current).grow(.12).intersects(sim.model.item_rect(item)):
				out.append(int(item.id))
				pending.append(item)
	return out

func bartender(bar: Dictionary) -> Actor:
	if not active(bar): return null
	for a in sim.staff.values():
		if not sim.staff_available(a) or a.brain.role != "bartender" or a.brain.state != "working": continue
		var own = int(a.brain.get("bar_id",a.brain.get("spot",{}).get("item",-1)))
		if not own in cluster(bar) or a.world.distance_to(Vector2(bar.x,bar.z)) > 3.5: continue
		var spots = Catalog.spots(sim.model.item_by_id(own)).filter(func(s): return s.who == "bartender")
		if not spots.is_empty() and a.world.distance_to(spots[0].pos) < .8: return a
	return null

func can_serve_spot(spot: Dictionary) -> bool:
	var item = sim.model.item_by_id(int(spot.item))
	if item.is_empty(): return false
	var bar = item if item.kind in Catalog.BARS else nearest_bar(spot.pos)
	return not bar.is_empty() and available(bar) > 0 and bartender(bar) != null

func attraction(spots: Array) -> float:
	var q = 0.0
	for s in spots:
		var item = sim.model.item_by_id(int(s.item))
		var bar = item if item.get("kind","") in Catalog.BARS else nearest_bar(s.pos)
		q = maxf(q,float(Catalog.ITEMS.get(bar.get("kind",""),{}).get("bar_quality",0)))
	return 4.0*(1.0+.8*q)

func activity_options(spots: Array) -> Array:
	# Clients choose the actual counter's appeal; a prestigious bar must not
	# boost the nearest plain bar by sharing one global activity weight.
	var groups: Dictionary = {}
	for spot in spots:
		var item = sim.model.item_by_id(int(spot.item))
		var bar = item if item.get("kind","") in Catalog.BARS else nearest_bar(spot.pos)
		if bar.is_empty(): continue
		var key = int(bar.id)
		if bar.kind == "bar_module":
			var connected = cluster(bar)
			connected.sort()
			key = int(connected[0])
		if not groups.has(key): groups[key] = []
		groups[key].append(spot)
	var out: Array = []
	for group in groups.values(): out.append(["bar",attraction(group),group])
	return out

func serve(a: Actor) -> bool:
	var bar = bar_at_client(a)
	var worker = bartender(bar)
	var stock = available(bar)
	if worker == null or stock == 0: return false
	var q = float(Catalog.ITEMS[bar.kind].get("bar_quality",0))
	var rounds = 2 if sim.rng.randf() < clampf(.28*float(worker.brain.get("speed",1))+.25*q,.1,.8) else 1
	rounds = mini(rounds,stock)
	var premium = q > 0 and sim.rng.randf() < .1+.65*q
	var price = roundi(int(sim.prices.drink)*(1.65 if premium else 1.0))
	var budget = int(a.brain.get("budget",1000000))
	if premium and budget < price:
		premium = false
		price = int(sim.prices.drink)
	if price > 0: rounds = mini(rounds,budget/price)
	if rounds <= 0: return false
	# The selected bar affects actual choice and receipts, never just a decoration score.
	var left = rounds
	for shelf in shelves(bar):
		var take = mini(left,int(shelf.get("stock",0)))
		if take > 0: set_stock(shelf,int(shelf.stock)-take)
		left -= take
		if left == 0: break
	sim.earn(price*rounds,"bar",a)
	a.brain.spent = int(a.brain.get("spent",0))+price*rounds
	if a.brain.has("budget"): a.brain.budget = maxi(0,budget-price*rounds)
	a.brain.last_drink = "Sélection premium" if premium else "Alcool classique"
	a.brain.last_drink_price = price
	a.brain.sat += 5.0+q*2.0+sim.profiles.welcome_bonus(str(worker.brain.get("profile_id","")))
	ClientNeeds.drink(a,rounds)
	worker.brain.serve = 6.0
	return true

func service_point(item: Dictionary, from: Vector2) -> Vector2:
	# A reachable place on the open front; no snapping through a closed wall.
	var at = Catalog.local_to_world(item,Vector2(0,Catalog.ITEMS[item.kind].size.y/2.0+.4))
	var cell = sim.nav.free_cell_near(at)
	if cell.x == 9999: return Vector2.INF
	var p = sim.nav.center(cell)
	if sim.model.room_at(p) != sim.model.room_at(Vector2(item.x,item.z)) or p.distance_to(at) > .85 or not sim.nav.reachable(from,p): return Vector2.INF
	return p

func start_refill(a: Actor, bar: Dictionary) -> bool:
	var candidates = shelves(bar).filter(func(i): return int(i.get("stock",0)) <= Catalog.stock_capacity(i.kind)/4 and not claimed.has(int(i.id)))
	candidates.sort_custom(func(x,y): return int(x.get("stock",0)) < int(y.get("stock",0)))
	for shelf in candidates:
		var destination = service_point(shelf,a.world)
		if destination == Vector2.INF: continue
		for source in sim.model.furniture:
			if source.kind != "bottle_crate" or not active(source) or int(source.get("stock",0)) == 0: continue
			var room = sim.model.room_at(Vector2(source.x,source.z))
			if int(room.type) != 3: continue
			var origin = service_point(source,a.world)
			if origin == Vector2.INF or not sim.nav.reachable(origin,destination): continue
			if not sim.go(a,origin): continue
			claimed[int(shelf.id)] = a.item_id
			tasks[a.item_id] = {"shelf":int(shelf.id),"source":int(source.id),"source_key":source.stock_key,"left":0,"to":destination,"timer":3.0,"box":null}
			a.brain.state = "stock_walk"
			return true
	return false

func tick(a: Actor, arrived: bool, gm: float) -> void:
	var b: Dictionary = a.brain
	if not tasks.has(a.item_id):
		if b.state in STATES: b.state = "post"
		if b.state in ["post","idle"]:
			var spots = sim.free_spots("work","bartender").filter(func(s): return sim.model.item_by_id(s.item).kind in Catalog.BARS)
			spots.sort_custom(func(x,y): return x.pos.distance_squared_to(b.post) < y.pos.distance_squared_to(b.post))
			for spot in spots:
				if sim.go_spot(a,spot):
					b.bar_id = int(spot.item)
					b.state = "to_work"
					return
			a.play("idle")
		elif b.state == "to_work" and arrived:
			sim.settle(a)
			b.state = "working"
		elif b.state == "working":
			var bar = sim.model.item_by_id(int(b.get("bar_id",-1)))
			if not active(bar):
				sim.release(a)
				b.state = "post"
				return
			var serve_time = maxf(0,float(b.get("serve",0))-gm)
			b.serve = serve_time
			a.play("work" if serve_time > 0 else "idle")
			if serve_time <= 0: start_refill(a,bar)
		return
	var task: Dictionary = tasks[a.item_id]
	var shelf = sim.model.item_by_id(int(task.shelf))
	var source = sim.model.item_by_id(int(task.source))
	if not active(shelf) or not active(sim.model.item_by_id(int(b.get("bar_id",-1)))):
		interrupt(a)
		sim.release(a)
		b.state = "post"
		return
	match b.state:
		"stock_walk":
			if arrived:
				a.play("work")
				b.state = "stock_pick"
		"stock_pick":
			task.timer -= gm
			if task.timer <= 0:
				if not active(source):
					interrupt(a)
					b.state = "working"
					return
				task.left = mini(CARTON,mini(int(source.stock),Catalog.stock_capacity(shelf.kind)-int(shelf.stock)))
				set_stock(source,int(source.stock)-int(task.left))
				if task.left <= 0 or not sim.go(a,task.to):
					interrupt(a)
					b.state = "post"
					return
				a.set_bar_carry("box")
				b.state = "stock_carry"
		"stock_carry":
			if arrived:
				a.set_bar_carry("bottle")
				a.face(Vector2(shelf.x,shelf.z)-a.world)
				a.play("work")
				var box = BarParcel.new()
				box.set_world(a.world+Vector2(.4,.1))
				sim.view.add_actor(box)
				task.box = box
				task.timer = 1.6
				b.state = "stock_fill"
		"stock_fill":
			task.timer -= gm
			while task.timer <= 0 and int(task.left) > 0:
				task.timer += 1.6
				var count = mini(4,mini(int(task.left),Catalog.stock_capacity(shelf.kind)-int(shelf.stock)))
				if count <= 0: break
				set_stock(shelf,int(shelf.stock)+count)
				task.left -= count
			if int(task.left) == 0 or int(shelf.stock) == Catalog.stock_capacity(shelf.kind):
				interrupt(a)
				if b.get("spot") is Dictionary and sim.go(a,b.spot.pos): b.state = "to_work"
				else: b.state = "post"

func interrupt(a: Actor) -> void:
	a.set_bar_carry("")
	if not tasks.has(a.item_id): return
	var task: Dictionary = tasks[a.item_id]
	var left = int(task.left)
	if left > 0:
		ledger[task.source_key] = int(ledger.get(task.source_key,0))+left
		var source = sim.model.item_by_id(int(task.source))
		if not source.is_empty(): set_stock(source,int(ledger[task.source_key]))
	if is_instance_valid(task.box): task.box.queue_free()
	claimed.erase(int(task.shelf))
	tasks.erase(a.item_id)

func layout_changed() -> void:
	for a in sim.staff.values():
		if is_instance_valid(a) and tasks.has(a.item_id):
			interrupt(a)
			sim.release(a)
			a.path = []
			a.brain.state = "post"
	sync()

func to_dict() -> Dictionary:
	# On reload unfinished cartons go back to the reserve. No alcohol is lost
	# or doubled when saving midway through the carrying/filling animation.
	var result = ledger.duplicate()
	for t in tasks.values(): result[t.source_key] = int(result.get(t.source_key,0))+int(t.left)
	return {"ledger":result}

func from_dict(data: Variant) -> void:
	ledger.clear()
	if not data is Dictionary or not data.get("ledger") is Dictionary: return
	var raw: Dictionary = data.ledger
	var count = 0
	for key in raw:
		if count >= 6000: break
		var v = raw[key]
		if not key is String or key.length() > 128 or not (v is int or v is float) or not is_finite(float(v)): continue
		ledger[key] = clampi(int(v),0,192)
		count += 1
