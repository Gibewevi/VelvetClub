class_name Finishes
extends RefCounted

# Floor and wall finishes: a hand-drawn pixel pattern (tone map) recoloured
# with a hue-shifted ramp of the chosen colour.
# value: renovation price per m² of floor, or per metre of wall. The worn
# finishes of the derelict building are worth nothing.
const FLOORS = {
	"damaged_wood":{"name":"Plancher abîmé","color":"a88256","pattern":"boards_damaged","value":0,"worn":true},
	"dirty_tile":{"name":"Carrelage encrassé","color":"8a8c98","pattern":"tile_dirty","value":0,"worn":true},
	"worn_carpet":{"name":"Moquette usagée","color":"7a3040","pattern":"carpet_worn","value":0,"worn":true},
	"worn_wood":{"name":"Vieux plancher","color":"9a6440","pattern":"boards_worn","value":6},
	"concrete":{"name":"Béton ciré","color":"7e8290","pattern":"plain","value":10},
	"tile":{"name":"Carrelage","color":"8a8c98","pattern":"tile","value":14},
	"oak":{"name":"Parquet chaud","color":"c07a4a","pattern":"boards","value":18},
	"carpet":{"name":"Moquette velours","color":"9c2e4c","pattern":"carpet","value":20},
	"terrazzo":{"name":"Terrazzo","color":"a89a90","pattern":"terrazzo","value":24}
}
const WALLS = {
	"decay":{"name":"Murs décrépis","color":"9a2a3a","pattern":"decay","value":0,"worn":true},
	"dirty_tile":{"name":"Faïence sale","color":"c2cad0","pattern":"tile_dirty","value":0,"worn":true},
	"torn_wallpaper":{"name":"Vieille tapisserie déchirée","color":"7a4a5a","pattern":"wallpaper_torn","value":0,"worn":true},
	"peeling_paint":{"name":"Peinture patinée","color":"8a5a6a","pattern":"peeling","value":6},
	"paint":{"name":"Peinture mate","color":"9a4a5e","pattern":"plain","value":12},
	"worn_plaster":{"name":"Briques","color":"a8364a","pattern":"brick","value":16},
	"wallpaper":{"name":"Papier peint","color":"7a2e5a","pattern":"paper","value":18},
	"wall_tile":{"name":"Faïence","color":"c2cad0","pattern":"tile","value":20}
}
const SWATCHES = ["c07a4a","9a6440","b86f44","9c2e4c","a8364a","b44a5c","7a2e5a","6b2b72","2e3350","8a8c98","c2cad0","e0c9a8"]

static func catalog(surface: String) -> Dictionary:
	return FLOORS if surface == "floor" else WALLS

static func defaults(room_type: int = 0) -> Dictionary:
	return Catalog.ROOM_FINISHES[clampi(room_type,0,Catalog.ROOM_FINISHES.size()-1)].duplicate()

static func valid_color(value: Variant) -> bool:
	if not value is String or value.length() != 6: return false
	for c in value.to_lower():
		if not c in "0123456789abcdef": return false
	return true

static func valid(data: Dictionary) -> bool:
	return FLOORS.has(data.get("floor_finish","")) and WALLS.has(data.get("wall_finish","")) and valid_color(data.get("floor_color")) and valid_color(data.get("wall_color"))

static func floor_pattern(room: Dictionary) -> String:
	return FLOORS.get(room.get("floor_finish","oak"),FLOORS.oak).pattern

static func wall_pattern(room: Dictionary) -> String:
	return WALLS.get(room.get("wall_finish","worn_plaster"),WALLS.worn_plaster).pattern

static func value(room: Dictionary) -> int:
	# Renovation value of a room's finishes, charged when they change.
	var floor_value = int(FLOORS.get(room.get("floor_finish",""),{}).get("value",0))
	var wall_value = int(WALLS.get(room.get("wall_finish",""),{}).get("value",0))
	return floor_value*int(room.w*room.h)+wall_value*int(2*(room.w+room.h))

static func is_worn(room: Dictionary) -> bool:
	return FLOORS.get(room.get("floor_finish",""),{}).get("worn",false) or WALLS.get(room.get("wall_finish",""),{}).get("worn",false)
