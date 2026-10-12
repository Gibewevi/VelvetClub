class_name ClubSaves
extends RefCounted

# The menu only reads saves. Starting a new club always allocates another
# path; the game's existing atomic writer remains responsible for saving.
var folder = "user://clubs"
var legacy_path = "user://pixel_club.json"

func new_path() -> String:
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder)) != OK: return ""
	var stamp = Time.get_datetime_string_from_system().replace(":","").replace("-","")
	for i in range(100):
		var path = "%s/club_%s_%d.json" % [folder,stamp,Time.get_ticks_usec()+i]
		if not FileAccess.file_exists(path): return path
	return ""

func read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {"error":"Cette sauvegarde n'est plus disponible."}
	var file = FileAccess.open(path,FileAccess.READ)
	if file == null: return {"error":"Impossible de lire cette sauvegarde."}
	if file.get_length() > 32*1024*1024: return {"error":"Ce fichier de sauvegarde est trop volumineux."}
	var data = JSON.parse_string(file.get_as_text())
	if not data is Dictionary: return {"error":"Sauvegarde illisible. Le fichier est conservé."}
	if not data.get("club",{}) is Dictionary or not data.get("deliveries",{}) is Dictionary:
		return {"error":"Sauvegarde incompatible. Le fichier est conservé."}
	var candidate = BuildingModel.new()
	if not candidate.load_checked(data.get("model")):
		return {"error":"Sauvegarde incompatible. Le fichier est conservé."}
	return {"data":data}

func list_saves() -> Array:
	var paths: Array = []
	if FileAccess.file_exists(legacy_path): paths.append(legacy_path)
	var dir = DirAccess.open(folder)
	if dir != null:
		for file in dir.get_files():
			if file.begins_with("club_") and file.ends_with(".json"): paths.append(folder.path_join(file))
	var entries: Array = []
	for path in paths:
		var result = read(path)
		var entry = {"path":path,"modified":FileAccess.get_modified_time(path),"valid":result.has("data")}
		if entry.valid:
			var data: Dictionary = result.data
			var info = data.get("meta",{})
			entry.title = str(info.get("title","Mon club")) if info is Dictionary else "Mon club"
			var club: Dictionary = data.get("club",{})
			entry.day = int(club.get("day",1)) if club.get("day",1) is float or club.get("day",1) is int else 1
			entry.money = int(club.get("money",ClubSim.START_MONEY)) if club.get("money",0) is float or club.get("money",0) is int else 0
		else:
			entry.title = "Ancienne partie" if path == legacy_path else "Partie indisponible"
			entry.error = result.error
		entries.append(entry)
	entries.sort_custom(func(a,b): return a.modified > b.modified)
	return entries

static func new_title() -> String:
	var date = Time.get_datetime_dict_from_system()
	return "Club du %02d/%02d/%d · %02dh%02d" % [date.day,date.month,date.year,date.hour,date.minute]

static func bypass_menu(args: PackedStringArray) -> bool:
	for arg in args:
		if arg in ["--smoke-test","--ui-test","--sim-test","--delivery-test","--finishes-test"]: return true
		if arg.begins_with("--capture=") or arg.begins_with("--profile-save="): return true
	return false
