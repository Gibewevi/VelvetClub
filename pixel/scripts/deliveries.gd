class_name Deliveries
extends Node

# Pending items own stable purchase keys; queues only reference those keys.
# Editing/undo never rewinds a truck or resurrects an already delivered parcel.
const BATCH_WAIT = 18.0
const RETRY_WAIT = 22.0
const CRUISE_SPEED = 13.0
const BRAKE_DISTANCE = 6.0
const BRAKE_ACCEL = CRUISE_SPEED*CRUISE_SPEED/(2.0*BRAKE_DISTANCE)
const LAUNCH_ACCEL = 13.0
const STOP_SETTLE = 0.55
const DOOR_OPEN_TIME = 1.2
var game
var model: BuildingModel
var nav = ClubNav.new()
var truck: DeliveryProp
var workers: Array = []
var jobs: Array = []
var queue: Array = []
var active_order: Array = []
var deferred_keys: Array = []
var completed: Dictionary = {}
var phase = "idle"
var timer = BATCH_WAIT
var clock = 0.0
var stop_x = 0.0
var truck_x = 32.0
var truck_speed = 0.0
var drive_accel = 0.0
var settle_age = -1.0
var brake_started = false
var launch_started = false
var order_number = 0
var cones: Array = []
var enabled = true
signal updated

func setup(owner_game, data: Dictionary = {}) -> void:
	game = owner_game
	model = game.model
	truck = DeliveryProp.new()
	game.view.add_actor(truck)
	truck.visible = false
	for i in range(2):
		var a = DeliveryCourier.new()
		a.setup(i)
		a.simulation = game.sim
		a.visible = false
		workers.append(a)
		game.view.add_actor(a)
		jobs.append({"key":"","state":"idle","timer":0.0,"target":Vector2.ZERO})
	from_dict(data)
	sync_orders()

static func package_size(item: Dictionary) -> int:
	var size: Vector2 = Catalog.ITEMS[item.kind].size
	if Catalog.bottle_shelf(item.kind) or item.kind in ["fridge","shower","locker","cloak_locker","cabinet"] or maxf(size.x,size.y) >= 1.5: return 2
	return 1 if size.x*size.y > .5 else 0

func item_for(key: String) -> Dictionary:
	for item in model.furniture:
		if item.get("delivery_key","") == key and item.get("delivery_pending",false): return item
	return {}

func reset() -> void:
	queue.clear()
	active_order.clear()
	deferred_keys.clear()
	completed.clear()
	phase = "idle"
	timer = BATCH_WAIT
	order_number = 0
	truck.visible = false
	truck.set_warning_lights(false)
	truck.reset_drive_effects()
	truck_speed = 0.0
	drive_accel = 0.0
	settle_age = -1.0
	brake_started = false
	launch_started = false
	for i in range(workers.size()):
		workers[i].visible = false
		workers[i].path = []
		workers[i].cargo(0,false)
		jobs[i] = {"key":"","state":"idle","timer":0.0,"target":Vector2.ZERO}
	updated.emit()

func sync_orders() -> void:
	var pending: Array = []
	for item in model.furniture:
		var key: String = item.get("delivery_key","")
		if completed.has(key): item.erase("delivery_pending")
		if item.get("delivery_pending",false): pending.append(key)
	var clean_active: Array = []
	for key in active_order:
		if key in pending and not key in clean_active: clean_active.append(key)
	active_order = clean_active
	var clean_queue: Array = []
	for key in queue:
		if key in pending and not key in active_order and not key in clean_queue: clean_queue.append(key)
	queue = clean_queue
	for key in pending:
		if not key in queue and not key in active_order: queue.append(key)
	rebuild_nav()
	for i in range(jobs.size()):
		var j: Dictionary = jobs[i]
		var a: DeliveryCourier = workers[i]
		if j.state == "return": a.path = []
		if j.key != "" and item_for(j.key).is_empty():
			j.key = ""
			a.cargo(0,false)
			j.state = "return"
			a.path = nav.path(a.world,loading_point(i),false)
		elif j.state in ["carry","unpack","blocked"]:
			# Recompute from the courier's actual position after any edit.
			j.state = "plan"
	if phase == "idle" and not queue.is_empty():
		phase = "waiting"
		timer = BATCH_WAIT
	if phase == "waiting" and queue.is_empty(): phase = "idle"
	updated.emit()

func loading_point(i: int = 0) -> Vector2:
	# Just behind the compact van's step, clear of its outward-opening doors.
	return Vector2(stop_x+3.6+i*.6,Street.LANE_WEST-.35+i*.7)

func rebuild_nav() -> void:
	var obstacles: Array = []
	if phase in ["open","unload","close"]:
		obstacles.append(Rect2(stop_x-2.85,Street.LANE_WEST-1.34,5.65,2.68))
		obstacles.append(Rect2(stop_x+2.4,Street.LANE_WEST-2.14,.85,4.28))
	nav.rebuild(model,true,obstacles)

func destination(from: Vector2, item: Dictionary) -> Array:
	# Unpack alongside the ghost, in its room, outside the final footprint.
	var r = model.item_rect(item)
	var room = model.room_at(Vector2(item.x,item.z))
	if room.is_empty(): return []
	var best: Array = []
	var distance = INF
	for x in range(floori((r.position.x-.9)*2),ceili((r.end.x+.9)*2)):
		for z in range(floori((r.position.y-.9)*2),ceili((r.end.y+.9)*2)):
			var p = Vector2(x*.5+.25,z*.5+.25)
			if r.grow(.12).has_point(p) or not model.inside(room,p) or not nav.walkable(p): continue
			var path = nav.path(from,p,false)
			if path.is_empty(): continue
			var length = 0.0
			var previous = from
			for step in path:
				length += previous.distance_to(step)
				previous = step
			if length < distance:
				distance = length
				best = path
	return best

func _process(delta: float) -> void:
	var p0 = Prof.t("deliveries")
	_timed_process(delta)
	Prof.add("deliveries",p0)

func _timed_process(delta: float) -> void:
	if game == null: return
	truck.warning_paused = not enabled or game.sim.speed == 0 or game.sim.paused_for_report
	if not enabled or game.sim.speed == 0 or game.sim.paused_for_report: return
	step(minf(delta,.15)*game.sim.speed)

func step(dt: float) -> void:
	if dt <= 0: return
	truck.step_effects(dt)
	clock += dt
	if phase == "waiting":
		timer -= dt
		if timer <= 0:
			var entry: Dictionary = game.sim.entrance
			stop_x = clampf(float(entry.get("door",Vector2.ZERO).x)-3.5,-15,14)
			truck_x = 34
			truck_speed = CRUISE_SPEED
			drive_accel = 0.0
			settle_age = -1.0
			brake_started = false
			launch_started = false
			phase = "arrive"
			truck.visible = true
			game.hud.toast("La fourgonnette de livraison arrive.")
	elif phase == "arrive":
		if advance_arrival(dt):
			active_order = queue.duplicate()
			queue.clear()
			deferred_keys.clear()
			order_number += 1
			phase = "open"
			settle_age = 0.0
			timer = STOP_SETTLE+DOOR_OPEN_TIME
			rebuild_nav()
			for i in range(2):
				workers[i].set_world(loading_point(i))
				jobs[i] = {"key":"","state":"idle","timer":0.0,"target":Vector2.ZERO}
	elif phase == "open":
		settle_age = minf(settle_age+dt,STOP_SETTLE+DOOR_OPEN_TIME)
		timer -= dt
		if timer <= 0:
			phase = "unload"
			settle_age = -1.0
			for a in workers: a.visible = true
	elif phase == "unload":
		for i in range(2): worker_step(i,dt)
		if jobs.all(func(j): return j.state == "idle") and active_order.all(func(k): return k in deferred_keys):
			for key in active_order:
				if not key in queue and not item_for(key).is_empty(): queue.append(key)
			active_order.clear()
			phase = "close"
			timer = 1.2
			for a in workers: a.visible = false
	elif phase == "close":
		timer -= dt
		if timer <= 0:
			phase = "depart"
			truck_speed = 0.0
			drive_accel = LAUNCH_ACCEL
			settle_age = -1.0
			if not launch_started:
				launch_started = true
				truck.set_world(Vector2(truck_x,Street.LANE_WEST))
				truck.play_launch()
			rebuild_nav()
	elif phase == "depart":
		advance_departure(dt)
		if truck_x <= -34:
			truck.visible = false
			truck_speed = 0.0
			drive_accel = 0.0
			phase = "waiting" if not queue.is_empty() else "idle"
			timer = RETRY_WAIT if not deferred_keys.is_empty() else BATCH_WAIT
	update_truck()
	updated.emit()

func advance_arrival(dt: float) -> bool:
	# Integrate the cruise and braking sections separately, including a step
	# that crosses their boundary. Position and speed reach zero together.
	var remaining = maxf(truck_x-stop_x,0.0)
	if remaining > BRAKE_DISTANCE:
		var cruise_dt = minf(dt,(remaining-BRAKE_DISTANCE)/CRUISE_SPEED)
		truck_x -= CRUISE_SPEED*cruise_dt
		truck_speed = CRUISE_SPEED
		drive_accel = 0.0
		dt -= cruise_dt
		if dt <= 0: return false
		remaining = maxf(truck_x-stop_x,0.0)
	if not brake_started:
		brake_started = true
		truck.set_world(Vector2(truck_x,Street.LANE_WEST))
		truck.play_brake()
	truck_speed = minf(CRUISE_SPEED,sqrt(2.0*BRAKE_ACCEL*remaining))
	var brake_dt = minf(dt,truck_speed/BRAKE_ACCEL)
	truck_x = maxf(stop_x,truck_x-truck_speed*brake_dt+0.5*BRAKE_ACCEL*brake_dt*brake_dt)
	truck_speed = maxf(0.0,truck_speed-BRAKE_ACCEL*brake_dt)
	drive_accel = -BRAKE_ACCEL
	if truck_speed < 0.0001 or truck_x-stop_x < 0.0001:
		truck_x = stop_x
		truck_speed = 0.0
		drive_accel = 0.0
		return true
	return false

func advance_departure(dt: float) -> void:
	var accelerating_dt = minf(dt,maxf(0.0,CRUISE_SPEED-truck_speed)/LAUNCH_ACCEL)
	var distance = truck_speed*accelerating_dt+0.5*LAUNCH_ACCEL*accelerating_dt*accelerating_dt
	truck_speed = minf(CRUISE_SPEED,truck_speed+LAUNCH_ACCEL*accelerating_dt)
	distance += truck_speed*(dt-accelerating_dt)
	truck_x = maxf(-34.0,truck_x-distance)
	drive_accel = LAUNCH_ACCEL if truck_speed < CRUISE_SPEED else 0.0

func worker_step(i: int, dt: float) -> void:
	var j: Dictionary = jobs[i]
	var a: DeliveryCourier = workers[i]
	if j.state == "idle":
		for key in active_order:
			if key in deferred_keys or jobs.any(func(other): return other.key == key): continue
			var item = item_for(key)
			if item.is_empty(): continue
			var path = destination(a.world,item)
			if path.is_empty():
				defer_item(key)
				continue
			j.key = key
			j.state = "pickup"
			j.timer = .7
			a.face(Vector2(-1,1))
			a.play("work")
			break
	elif j.state == "pickup":
		j.timer -= dt
		if j.timer <= 0: j.state = "plan"
	elif j.state == "plan":
		var item = item_for(j.key)
		if item.is_empty():
			start_return(i)
			return
		a.cargo(package_size(item),true)
		var path = destination(a.world,item)
		if path.is_empty():
			defer_item(j.key)
			start_return(i)
		else:
			a.path = path
			j.target = path.back()
			j.state = "carry"
	elif j.state == "carry":
		if a.step(dt,1.0):
			var item = item_for(j.key)
			if item.is_empty():
				start_return(i)
				return
			a.face(Vector2(item.x,item.z)-a.world)
			a.play("work")
			a.cargo(package_size(item),true,true)
			j.state = "unpack"
			j.timer = 1.0+package_size(item)*.3
	elif j.state == "unpack":
		j.timer -= dt
		if j.timer <= 0:
			var item = item_for(j.key)
			if not item.is_empty():
				var key: String = j.key
				completed[key] = true
				item.erase("delivery_pending")
				active_order.erase(key)
				game.delivery_installed(key,int(item.id))
			start_return(i)
	elif j.state == "return":
		if a.path.is_empty() and a.world.distance_to(loading_point(i)) > .7:
			a.path = nav.path(a.world,loading_point(i),false)
			if a.path.is_empty():
				a.play("idle")
				return # a removed door traps the courier until the player restores access
		if a.step(dt,1.0):
			j.state = "idle"
			j.key = ""
			a.play("idle")

func start_return(i: int) -> void:
	var a: DeliveryCourier = workers[i]
	jobs[i].key = ""
	jobs[i].state = "return"
	a.cargo(0,false)
	a.path = nav.path(a.world,loading_point(i),false)

func defer_item(key: String) -> void:
	if not key in deferred_keys:
		deferred_keys.append(key)
		game.hud.toast("Livraison en attente : dégagez un passage jusqu'au fantôme ou ajoutez une porte.",6)

func update_truck() -> void:
	truck.set_world(Vector2(truck_x,Street.LANE_WEST))
	var opening_doors = phase == "close" or (phase == "open" and settle_age >= STOP_SETTLE)
	var opening = 2 if phase == "unload" else (1 if opening_doors else 0)
	var name = "truck_%d_0" % opening
	if opening > 0:
		var carried = jobs.filter(func(j): return j.key != "" and j.state in ["carry","unpack","plan"]).size()
		name += "_load%d" % clampi(active_order.size()-carried,0,3)
	truck.show_frame(name)
	truck.set_drive_state(phase,truck_speed,drive_accel,settle_age)
	truck.set_warning_lights(phase in ["open","unload","close"])
	# Cones remain children of the truck; local ground coordinates match the art.
	if cones.is_empty():
		var info: Dictionary = truck.art.cone
		for p in [Vector2(-3.1,1.35),Vector2(3.8,1.5),Vector2(3.8,-1.5)]:
			var s = Sprite2D.new()
			s.texture = Art.tex(info.file)
			s.centered = false
			s.offset = -Vector2(info.ox,info.oy)
			s.position = Iso.pixel(p.x,p.y)
			truck.add_child(s)
			cones.append(s)
	for cone in cones: cone.visible = opening_doors or phase == "unload"

func status_text() -> String:
	var n = queue.size()+active_order.size()
	if phase == "idle": return "Livraisons"
	if phase == "waiting": return "%d colis · %ds" % [n,ceili(timer)]
	if phase == "arrive": return "Livraison en approche"
	if phase in ["close","depart"]: return "Livraison au départ"
	for i in range(jobs.size()):
		if jobs[i].state == "return" and workers[i].path.is_empty() and workers[i].world.distance_to(loading_point(i)) > .7: return "Livreur bloqué"
	return "Livraison · %d colis" % n

func item_status(item: Dictionary) -> String:
	var key: String = item.get("delivery_key","")
	if not item.get("delivery_pending",false): return "Installé"
	for j in jobs:
		if j.key == key: return {"pickup":"Chargement du colis","plan":"Transport","carry":"Transport","unpack":"Déballage"}.get(j.state,"En livraison")
	if key in deferred_keys: return "Accès bloqué · dégagez le passage"
	return "Dans la fourgonnette" if key in active_order else "Commande regroupée · en attente"

func to_dict() -> Dictionary:
	var saved: Array = []
	for i in range(jobs.size()):
		var j: Dictionary = jobs[i].duplicate(true)
		j.erase("target")
		j.pos = [workers[i].world.x,workers[i].world.y]
		saved.append(j)
	return {"phase":phase,"timer":timer,"clock":clock,"stop_x":stop_x,"truck_x":truck_x,"truck_speed":truck_speed,"drive_accel":drive_accel,"settle_age":settle_age,"brake_started":brake_started,"launch_started":launch_started,"queue":queue.duplicate(),"active":active_order.duplicate(),"deferred":deferred_keys.duplicate(),"jobs":saved,"number":order_number}

func from_dict(data: Dictionary) -> void:
	if not data.get("phase","") in ["idle","waiting","arrive","open","unload","close","depart"]: return
	truck.reset_drive_effects()
	phase = data.phase
	for key in ["timer","clock","stop_x","truck_x"]:
		var value = data.get(key)
		if (value is float or value is int) and is_finite(float(value)): set(key,clampf(value,-100,100000))
	stop_x = clampf(stop_x,-15,14)
	truck_x = clampf(truck_x,-40,40)
	timer = clampf(timer,0,RETRY_WAIT)
	# Older saves resume their existing motion without replaying an arrival
	# or departure effect. New saves preserve the exact speed and settling age.
	var remaining = maxf(truck_x-stop_x,0.0)
	truck_speed = minf(CRUISE_SPEED,sqrt(2.0*BRAKE_ACCEL*remaining)) if phase == "arrive" else (CRUISE_SPEED if phase == "depart" else 0.0)
	drive_accel = -BRAKE_ACCEL if phase == "arrive" and remaining <= BRAKE_DISTANCE else 0.0
	settle_age = STOP_SETTLE+maxf(0.0,DOOR_OPEN_TIME-timer) if phase == "open" else -1.0
	for limits in [["truck_speed",0.0,CRUISE_SPEED],["drive_accel",-BRAKE_ACCEL,LAUNCH_ACCEL],["settle_age",-1.0,STOP_SETTLE+DOOR_OPEN_TIME]]:
		var value = data.get(limits[0])
		if (value is float or value is int) and is_finite(float(value)): set(limits[0],clampf(float(value),limits[1],limits[2]))
	brake_started = data.get("brake_started",phase != "arrive" or remaining <= BRAKE_DISTANCE) == true
	launch_started = data.get("launch_started",phase == "depart") == true
	for pair in [["queue","queue"],["active","active_order"],["deferred","deferred_keys"]]:
		if data.get(pair[0]) is Array: set(pair[1],data[pair[0]].filter(func(k): return k is String).slice(0,3000))
	var number = data.get("number",0)
	if (number is float or number is int) and is_finite(float(number)): order_number = clampi(int(number),0,1000000)
	var saved = data.get("jobs",[])
	if saved is Array:
		for i in range(mini(saved.size(),2)):
			var j = saved[i]
			if not j is Dictionary or not j.get("key") is String: continue
			var p = j.get("pos")
			if not p is Array or p.size()!=2: continue
			if not (p[0] is float or p[0] is int) or not (p[1] is float or p[1] is int): continue
			if not is_finite(float(p[0])) or not is_finite(float(p[1])): continue
			workers[i].set_world(Vector2(clampf(p[0],-24,24),clampf(p[1],-24,24)))
			jobs[i].key = j.key
			jobs[i].state = "plan" if j.get("state") in ["pickup","plan","carry","unpack"] else "return"
	truck.visible = not phase in ["idle","waiting"]
	for a in workers: a.visible = phase == "unload"
	update_truck()
