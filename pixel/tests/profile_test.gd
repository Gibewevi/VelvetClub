extends SceneTree

var checks = 0
var failures = 0

class ProfileGame:
	extends Node
	var sim: ClubSim
	var saves = 0
	func request_save() -> void:
		saves += 1

func find_control(node: Node, type_name: String, text: String = "") -> Control:
	for child in node.get_children():
		if child.is_class(type_name) and (text == "" or child.get("text") == text): return child
		var found = find_control(child,type_name,text)
		if found != null: return found
	return null

func label_text(node: Node) -> String:
	var text = ""
	for child in node.get_children():
		if child is Label: text += child.text+"\n"
		text += label_text(child)
	return text

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+message)

func _init() -> void:
	run.call_deferred()

func run() -> void:
	Art.load_all()
	var book = CharacterProfiles.new()
	var p = book.make_client(Characters.defaults("man"),1,[])
	var identity: String = p.id
	var story: String = p.story
	var guest = Actor.new()
	guest.kind = "client"
	guest.brain = {"profile_id":identity,"paid":true,"sat":85.0,"spent":32}
	book.arrive(p,1)
	book.admit(guest,1)
	book.admit(guest,1)
	book.spend(guest,32)
	book.finish(guest,1)
	book.finish(guest,1)
	check(p.visits == 1 and p.good_visits == 1 and p.spent == 32,"Admission/departure is counted once; revenue has its own ledger")
	check(p.loyalty > .3,"A good experience increases return probability")
	check(book.select_client([],1,22,true).is_empty(),"An identity cannot return twice on the same calendar day")
	check(book.select_client([identity],2,22,true).is_empty(),"An active identity cannot spawn a duplicate")
	check(book.select_client([],2,22,true).id == identity,"An eligible regular returns with the same identity")
	for day in [2,3]:
		guest.brain.erase("profile_admitted")
		guest.brain.erase("profile_finished")
		book.arrive(p,day)
		book.admit(guest,day)
		book.finish(guest,day)
	check(p.visits == 3 and p.good_visits == 3 and p.memories.any(func(m): return m.text.contains("habitué")),"Three good visits complete the personal objective with a real memory")
	guest.brain.erase("profile_admitted")
	guest.brain.erase("profile_finished")
	guest.brain.paid = false
	book.arrive(p,4)
	book.finish(guest,4)
	check(p.visits == 3 and p.good_visits == 3,"Leaving the entrance queue does not count as a paid visit")
	check(book.record_incident(identity,"case-1","theft",4,100,"Témoignage",false),"Future security systems can record an unconfirmed observation")
	check(book.incident_cost(identity) == 0 and not p.incidents[0].confirmed,"A report is not a confirmed offence or a financial loss")
	check(book.record_incident(identity,"case-1","theft",4,100,"Vigile",true),"The same event can be confirmed after investigation")
	check(not book.record_incident(identity,"case-1","theft",4,100,"Caméra",true),"Guard and camera cannot double-count the same event")
	check(p.incidents.size() == 1 and book.incident_cost(identity) == 100,"Confirmed loss is counted exactly once")
	check(not book.record_incident(identity,"case-1","aggression",4,999,"Vigile",true),"A duplicate event cannot change its nature or cost")
	check(not book.record_incident(identity,"","damage",4,10,"Vigile",true),"An observation needs a stable event identity")
	book.mark_watched(identity,true,4)
	p.note = "Surveiller l'accueil, sans refuser l'entrée."
	var encoded = JSON.parse_string(JSON.stringify(book.to_dict()))
	var loaded = CharacterProfiles.new()
	loaded.from_dict(encoded)
	var restored = loaded.get_profile(identity)
	check(restored.name == p.name and restored.age == p.age and restored.story == story and restored.appearance == p.appearance,"Identity, story and appearance survive JSON save/load")
	check(restored.visits == 3 and restored.good_visits == 3 and restored.spent == 32,"History and completed objectives survive save/load")
	check(restored.watched and restored.note == p.note and loaded.incident_cost(identity) == 100,"Player notes and confirmed security observations persist")
	check(restored.latent == p.latent,"Future hidden tendencies are stable and independent from appearance")
	check(loaded.make_client(Characters.defaults("woman"),5,[]).id != identity,"Loading cannot reuse a previous identity")
	for i in range(80): book.remember(identity,5,"Souvenir %d" % i)
	check(p.memories.size() == CharacterProfiles.MAX_MEMORIES and p.memories[0].text == "Souvenir 79","Memory history is bounded, preserving the newest facts")
	for i in range(60): book.record_incident(identity,"event-%d" % i,"damage",5,10,"Vigile",true)
	check(p.incidents.size() == CharacterProfiles.MAX_INCIDENTS,"Incident history is bounded")
	var corrupt = CharacterProfiles.new()
	corrupt.from_dict({"records":[null,{}, {"id":"bad","kind":"client"}, {"id":"p00000001","kind":"client","appearance":{},"spent":"oops","loyalty":INF,"incidents":[{}],"memories":"bad"}],"next_id":-42})
	check(corrupt.records.size() == 1 and corrupt.get_profile("p00000001").spent == 0,"Corrupt optional profile data is normalized without losing the game")
	check(corrupt.next_id > 1,"A malformed counter cannot overwrite an existing profile")
	var full_book = CharacterProfiles.new()
	for i in range(CharacterProfiles.MAX_CLIENTS): full_book.make_client(Characters.defaults("man"),1,[])
	var protected_id: String = full_book.records.values()[0].id
	full_book.mark_watched(protected_id,true,1)
	full_book.get_profile(protected_id).note = "Note à conserver."
	full_book.make_client(Characters.defaults("woman"),2,[])
	check(full_book.records.size() == CharacterProfiles.MAX_CLIENTS and full_book.get_profile(protected_id).note == "Note à conserver.","Bounded directory protects followed clients and player notes when replacing an old casual visitor")
	var model = BuildingModel.new()
	model.add_room(-5,-3,10,8,0)
	model.set_opening("x:0:5","door")
	var maid_id = model.add_item("maid",-3,1,0)
	model.add_item("bar",1,-1,0)
	model.add_item("sofa",-2,-1,0)
	var view = WorldView.new()
	root.add_child(view)
	view.setup(model)
	var sim = ClubSim.new()
	root.add_child(sim)
	sim.setup(model,view)
	sim.active = false
	var maid: Actor = sim.staff[maid_id]
	var employee = sim.profiles.get_profile(maid.brain.profile_id)
	check(not employee.story.is_empty() and not maid.brain.name.is_empty(),"Legacy employees automatically receive a named biography")
	var old_id: String = employee.id
	model.move_item(maid_id,-3,2,1)
	sim.layout_changed()
	check(sim.staff[maid_id].brain.profile_id == old_id,"Moving or rotating an employee preserves identity")
	check(is_equal_approx(Sanitation.cleaning_factor(sim,maid),.9),"The displayed cleaner trait actually speeds up cleaning")
	sim.profiles.employee_work(old_id,480,sim.day)
	check(is_equal_approx(Sanitation.cleaning_factor(sim,maid),.855),"Completing the staff objective grants its modest efficiency bonus")
	model.item_by_id(maid_id).work_schedule = {"days":0,"start":0,"end":0}
	sim.refresh_schedule_state()
	var hours: float = employee.work_minutes
	sim.staff_ai(maid,60)
	check(employee.work_minutes == hours,"Off-duty time does not progress an employee's objective")
	var snapshot = JSON.parse_string(JSON.stringify(model.snapshot()))
	var other_model = BuildingModel.new()
	check(other_model.load_checked(snapshot),"Model validation accepts saved profile references")
	var saved_sim = JSON.parse_string(JSON.stringify(sim.to_dict()))
	var other_view = WorldView.new()
	root.add_child(other_view)
	other_view.setup(other_model)
	var other_sim = ClubSim.new()
	root.add_child(other_sim)
	other_sim.from_dict(saved_sim)
	other_sim.setup(other_model,other_view)
	other_sim.active = false
	check(other_sim.staff[maid_id].brain.profile_id == old_id and other_sim.profiles.get_profile(old_id).work_minutes == hours,"Employee biography and objective survive whole-game save/load")
	sim.spawn_client()
	check(sim.clients.size() == 1,"Persistent identity system still spawns clients through the real entrance")
	var client: Actor = sim.clients[0]
	var client_profile = sim.profiles.get_profile(client.brain.profile_id)
	check(client.appearance == client_profile.appearance and client.brain.name == client_profile.name,"Visible actor and biography belong to the same identity")
	check(client.brain.patience == client_profile.patience and client.brain.generous == client_profile.generous,"Displayed temperament controls actual patience and tipping behaviour")
	client.brain.paid = true
	client.brain.sat = 80
	client.brain.visits = 0
	var count_bar: Array = []
	for preference in ["","bar"]:
		var count = 0
		sim.rng.seed = 222
		client.brain.preference = preference
		for i in range(160):
			sim.release(client)
			client.brain.visits = 0
			sim.choose_activity(client)
			if client.brain.activity == "bar": count += 1
		count_bar.append(count)
	check(count_bar[1] > count_bar[0] and count_bar[0] > 0,"Preferred activity is measurably chosen more often, when available")
	sim.release(client)
	client.brain.activity = "lounge"
	client.brain.preference = "lounge"
	client.brain.sat = 50
	sim.start_activity(client)
	check(client.brain.sat >= 55,"Favourite activity grants its displayed satisfaction bonus")
	sim.earn(12,"bar",client)
	check(client_profile.spent == 12,"Real purchases update the persistent spending ledger immediately")
	client.brain.spent = 19 # Includes a 7-dollar legacy/direct tipping transaction.
	sim.to_dict()
	sim.to_dict()
	check(client_profile.spent == 19,"Saving during a visit reconciles all transaction paths without double-counting")
	sim.remove_client(client)
	sim.day += 1
	var returnee = sim.profiles.select_client([],sim.day,22,true)
	check(returnee.id == client_profile.id and returnee.appearance == client_profile.appearance,"After leaving, the client can return with their exact biography and appearance")
	UiKit.setup(2)
	var game = ProfileGame.new()
	root.add_child(game)
	game.sim = sim
	var hud = Hud.new()
	root.add_child(hud)
	hud.set_process(false)
	hud.size = Vector2(1440,900)
	hud.game = game
	hud.theme = UiKit.theme
	hud.show_profile(client_profile.id,0)
	await process_frame
	await process_frame
	check(hud.modal_open() and label_text(hud.modal).contains(client_profile.story),"A departed client's biography remains accessible in the real profile window")
	var window: Control = hud.modal.get_meta("window")
	check(window.size.x <= hud.size.x and window.size.y <= hud.size.y and window.position.y >= 0,"Profile window fits the game viewport")
	check(not label_text(hud.modal).contains("latent") and not label_text(hud.modal).contains("dangerosité"),"Hidden security tendencies are never displayed as observed facts")
	var follow: Button = find_control(hud.modal,"Button","Suivi")
	follow.pressed.emit()
	await process_frame
	check(label_text(hud.modal).contains("Aucun incident observé"),"Follow-up tab starts without invented incidents")
	var note: LineEdit = find_control(hud.modal,"LineEdit")
	note.text = "Prévoir un accueil attentif."
	note.text_changed.emit(note.text)
	var watch: CheckBox = find_control(hud.modal,"CheckBox")
	watch.button_pressed = true
	check(client_profile.note == note.text and client_profile.watched and game.saves >= 2,"Writing notes and marking a client updates the persisted model and requests a save")
	var persisted = CharacterProfiles.new()
	persisted.from_dict(JSON.parse_string(JSON.stringify(sim.profiles.to_dict())))
	check(persisted.get_profile(client_profile.id).note == note.text and persisted.get_profile(client_profile.id).watched,"Notes written through the UI survive a real JSON round trip")
	hud.show_client_book()
	await process_frame
	check(find_control(hud.modal,"Button","%s · %d visites · Suivi" % [client_profile.name,int(client_profile.visits)]) != null,"Client directory exposes watched visitors after departure")
	var search: LineEdit = find_control(hud.modal,"LineEdit")
	search.text = "ZZZ-nobody"
	search.text_changed.emit(search.text)
	check(label_text(hud.modal).contains("Aucun client correspondant"),"Directory search filters results")
	hud.show_profile(old_id,0)
	await process_frame
	check(label_text(hud.modal).contains(employee.story) and label_text(hud.modal).contains("Objectif atteint"),"Staff window displays its own history, work trait and completed objective")
	hud.queue_free()
	game.queue_free()
	other_sim.queue_free()
	other_view.queue_free()
	sim.queue_free()
	view.queue_free()
	guest.free()
	await process_frame
	print("PROFILE_CHECKS %d failures %d" % [checks,failures])
	if failures == 0: print("PROFILE_TESTS_PASSED")
	quit(1 if failures > 0 else 0)
