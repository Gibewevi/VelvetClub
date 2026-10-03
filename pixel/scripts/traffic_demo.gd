class_name TrafficDemo
extends RefCounted

# Only called by --capture in the isolated screenshot mode. The charts use
# actual simulated arrivals, admissions and waiting, never invented samples.
static func setup(game) -> void:
	var sim = game.sim
	sim.active = false
	for actor in sim.clients.duplicate(): sim.remove_client(actor)
	game.model.rooms.clear()
	game.model.furniture.clear()
	game.model.openings.clear()
	game.model.parkings.clear()
	game.model.add_room(-5,1,10,7,0)
	game.model.set_opening("x:0:8","door")
	game.model.add_item("reception",-2,3.5,0)
	game.model.add_item("receptionist",-2,2.5,0)
	game.model.add_item("bar",2,3.5,0)
	game.model.add_item("bartender",2,2.5,0)
	game.model.add_item("sofa",-2,6,0)
	game.model.add_item("sofa",2,6,0)
	game.changed_view()
	sim.traffic = TrafficHistory.new()
	sim.day = 6
	sim.minute = 1080
	sim.rating = 4.5
	sim.set_open(true)
	sim.active = true
	for i in range(960): sim._process(.1)
	sim.active = false
	game.hud.staff_tab = 2
	if game.hud.active != "staff": game.hud.toggle_drawer("staff")
	game.hud.fill_drawer()
	for arg in OS.get_cmdline_user_args():
		if arg == "--queue-rain":
			sim.rain_strength = .8
			sim.spawn_client()
			for actor in sim.clients:
				RainUmbrella.update_actor(sim,actor)
	game.view.depth_sort()
