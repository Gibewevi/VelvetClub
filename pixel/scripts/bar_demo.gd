class_name BarDemo
extends RefCounted

# Isolated captures use the real inventory and staff AI, never painted bottles
# or actors placed in fictional task states.
static func setup(game, restock: bool = false) -> void:
	var sim = game.sim
	sim.active = false
	sim.set_open(false)
	sim.bar_stock.reset()
	for actor in sim.clients.duplicate(): sim.remove_client(actor)
	game.model.rooms.clear()
	game.model.furniture.clear()
	game.model.openings.clear()
	game.model.parkings.clear()
	var model = game.model
	if not restock:
		model.add_room(-9,-9,18,14,0)
		for entry in [["bar_module",-6,-3],["bar_round",-1,-3],["bar_l",5,-3],["bar_luxe",2,2],
			["bottles_small",-6,-6.5],["backbar",-1,-6.5],["bottles_arch",5,-6.5],["bottles_luxe",2,-.5],
			["sofa",-5,2],["stool",-2,-1.5],["stool",0,-1.5]]:
			model.add_item(entry[0],entry[1],entry[2])
		game.changed_view()
		for item in model.furniture:
			if Catalog.bottle_shelf(item.kind): sim.bar_stock.set_stock(item,Catalog.stock_capacity(item.kind))
	else:
		model.add_room(-5,-5,10,10,0)
		model.add_room(5,-5,4,6,3)
		model.set_opening("z:5:-2","door")
		model.add_item("bar_luxe",0,1.8)
		var storage = model.add_item("bottles_arch",0,-2.5)
		model.add_item("bottle_crate",7,-3)
		model.add_item("bottle_crate",7,-1)
		var staff = model.add_item("bartender",0,.85)
		game.changed_view()
		var a: Actor = sim.staff[staff]
		var want = "stock_fill"
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--stock-state="): want = arg.trim_prefix("--stock-state=")
		sim.bar_stock.set_stock(model.item_by_id(storage),8)
		for i in range(700):
			sim.staff_ai(a,.1)
			if a.brain.state == want:
				if want == "stock_fill":
					for k in range(34): sim.staff_ai(a,.1)
				break
		game.select_item(storage)
		print("BAR_DEMO state=%s stock=%d" % [a.brain.state,int(model.item_by_id(storage).stock)])
	game.view.depth_sort()
