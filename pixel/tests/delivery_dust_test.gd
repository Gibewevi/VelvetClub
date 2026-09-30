extends SceneTree

# Exercise the actual particle nodes under a moving vehicle. A stored world
# origin alone is not enough: their rendered position must stay on the road.
var failures = 0
var checks = 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+message)

func _init() -> void:
	run.call_deferred()

func snapshot(dust: DeliveryDust) -> Array:
	var result: Array = []
	for child in dust.get_children():
		var sprite = child as Sprite2D
		if sprite != null:
			result.append([sprite.get_instance_id(),sprite.global_position,sprite.texture,sprite.modulate,sprite.visible])
	return result

func crisp_textures(dust: DeliveryDust) -> bool:
	var inspected = {}
	for child in dust.get_children():
		var sprite = child as Sprite2D
		if sprite == null or sprite.texture == null: return false
		if inspected.has(sprite.texture): continue
		inspected[sprite.texture] = true
		var image = sprite.texture.get_image()
		if image == null or image.is_empty(): return false
		for y in range(image.get_height()):
			for x in range(image.get_width()):
				var alpha = image.get_pixel(x,y).a
				if alpha > .001 and alpha < .999: return false
	return not inspected.is_empty()

func run() -> void:
	var vehicle = Node2D.new()
	root.add_child(vehicle)
	var dust = DeliveryDust.new()
	vehicle.add_child(dust)
	for launching in [false,true]:
		var label = "Launch" if launching else "Brake"
		var world = Vector2(-3.5,8.25)
		vehicle.position = Iso.pixel(world.x,world.y)
		dust.burst(world,launching)
		check(dust.active_count() > 1 and dust.active_count() <= DeliveryDust.MAX_PUFFS,label+" emits several bounded puffs")
		check(dust.get_child_count() == dust.active_count(),label+" has one managed node per puff")
		for dt in [.03,.08,.16,.21]:
			dust.step(dt,world)
			check(crisp_textures(dust),label+" animation uses hard-edged pixel textures")
			var before = snapshot(dust)
			check(before.any(func(state): return state[4]),label+" has visible particles during its burst")
			for i in range(5): dust.step(0.0,world)
			check(snapshot(dust) == before,label+" pause preserves every visible animation property")
			# An abrupt parent move isolates anchoring from simulated drift. The
			# zero-time refresh used by DeliveryProp must exactly compensate it.
			world += Vector2(-1.273,.119)
			vehicle.position = Iso.pixel(world.x,world.y)
			dust.step(0.0,world)
			var after = snapshot(dust)
			var anchored = before.size() == after.size()
			var integer_pixels = true
			for i in range(mini(before.size(),after.size())):
				if before[i][4]: anchored = anchored and before[i][1] == after[i][1]
				var position: Vector2 = after[i][1]
				if after[i][4]: integer_pixels = integer_pixels and position == position.round()
			check(anchored,label+" visible puffs remain fixed on the road when their parent moves")
			check(integer_pixels,label+" particles remain on whole screen pixels")
		var old_nodes = dust.get_children()
		dust.step(5.0,world)
		check(dust.active_count() == 0 and dust.get_child_count() == 0,label+" burst fully expires")
		await process_frame
		check(old_nodes.all(func(node): return not is_instance_valid(node)),label+" expired sprites are freed")
	# Stress repeated events without advancing time: a bad caller or rapid
	# scene restart must not grow the scene tree beyond the particle budget.
	for i in range(20): dust.burst(Vector2(i*.37,8.25),i%2 == 0)
	check(dust.active_count() > 0 and dust.active_count() <= DeliveryDust.MAX_PUFFS,"Repeated bursts respect the particle budget")
	check(dust.get_child_count() == dust.active_count(),"Saturation leaves no detached unmanaged particle children")
	var remaining = dust.get_children()
	dust.clear_puffs()
	dust.clear_puffs()
	check(dust.active_count() == 0 and dust.get_child_count() == 0,"Clearing an effect is complete and repeatable")
	await process_frame
	check(remaining.all(func(node): return not is_instance_valid(node)),"Cleared sprites are freed")
	vehicle.queue_free()
	await process_frame
	print("DELIVERY_DUST_TESTS: %d checks, %d failures" % [checks,failures])
	if failures == 0: print("DELIVERY_DUST_TESTS_PASSED")
	quit(1 if failures > 0 else 0)
