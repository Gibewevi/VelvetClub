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

func run() -> void:
	Art.load_all()
	for kind in ["woman","janitor"]:
		var a = Actor.new()
		root.add_child(a)
		a.configure(Characters.defaults(kind))
		a.set_world(Vector2(2,3))
		for direction in [Vector2(1,0),Vector2(-1,0),Vector2(0,1),Vector2(0,-1)]:
			a.play("idle")
			a.face(direction)
			a.play("kneel")
			var anchor = a.position
			var origin = a.current_frame()
			a._process(2)
			check(a.current_frame() == origin,"Resting pose ignores real time while simulation is paused")
			a.step(1.4,1)
			check(a.frame_i == 2,"Simulation advances the slow breathing cycle")
			check(a.layers.all(func(s): return s.frame == a.current_frame()),"Clothes, face and hair keep matching frames")
			for file in a.files:
				if not ("hair" in file or "face_" in file): continue
				var sheet = Art.image(file)
				var before = sheet.get_region(Rect2i(origin*32,1,32,47))
				var breathed = sheet.get_region(Rect2i(a.current_frame()*32,0,32,47))
				check(before.get_data() == breathed.get_data(),"Head layers follow the same one-pixel vertical breath")
			check(a.position == anchor and a.world == Vector2(2,3),"Animation keeps the actor planted on the floor")
			var at = a.current_frame()
			a.step(3,0)
			check(a.current_frame() == at,"Zero simulation speed freezes the pose")
			a.step(2.6,1)
			check(a.current_frame() == origin,"Four-second cycle loops without drifting")
			a.play("idle")
			a.play("kneel")
			a.step(.5,3)
			check(a.frame_i == 2,"Fast-forward scales the neutral pose animation")
			a.path = [Vector2(4,3)]
			a.step(.1,1)
			check(a.anim == "walk","Leaving the resting pose switches cleanly to walking")
			a.path = []
			a.set_world(Vector2(2,3))
		a.queue_free()
	await process_frame
	print("REST_POSE_TESTS: %d checks, %d failures" % [checks,failures])
	if failures == 0: print("REST_POSE_TESTS_PASSED")
	quit(1 if failures else 0)
