class_name ClubCalendar
extends RefCounted

const DAYS = ["Lundi","Mardi","Mercredi","Jeudi","Vendredi","Samedi","Dimanche"]
const SHORT_DAYS = ["Lu","Ma","Me","Je","Ve","Sa","Di"]
const ALL_DAYS = 127

static func default_shift() -> Dictionary:
	# Existing employees keep their continuous availability until explicitly planned.
	return {"days":ALL_DAYS,"start":0,"end":0}

static func default_opening() -> Dictionary:
	return {"days":ALL_DAYS,"start":1200,"end":240,"enabled":false}

static func valid(data: Variant, opening: bool = false) -> bool:
	if not data is Dictionary: return false
	for key in ["days","start","end"]:
		var n = data.get(key)
		if not (n is int or n is float) or not is_finite(float(n)) or n != floor(n): return false
		if n < 0 or n > (ALL_DAYS if key == "days" else 1439): return false
	return not opening or data.get("enabled") is bool

static func normalized(data: Dictionary) -> Dictionary:
	var result = {"days":int(data.days),"start":int(data.start),"end":int(data.end)}
	if data.has("enabled"): result.enabled = data.enabled
	return result

static func weekday(day: int) -> int:
	return posmod(day-1,7)

static func covers(schedule: Dictionary, day: int, minute: float) -> bool:
	var today = weekday(day)
	var start = int(schedule.start)
	var end = int(schedule.end)
	if start < end:
		return bool(int(schedule.days) & (1 << today)) and minute >= start and minute < end
	# Equal start/end is a full 24-hour shift, anchored on its start day.
	var owner = today if minute >= start else posmod(today-1,7)
	return bool(int(schedule.days) & (1 << owner)) and (start == end or minute >= start or minute < end)

static func time_text(minutes: int) -> String:
	return "%02d:%02d" % [minutes/60,minutes%60]

static func summary(schedule: Dictionary) -> String:
	var days: Array = []
	for i in range(7):
		if int(schedule.days) & (1 << i): days.append(SHORT_DAYS[i])
	if days.is_empty(): return "Repos toute la semaine"
	var text = "Tous les jours" if int(schedule.days) == ALL_DAYS else " · ".join(days)
	return text+" · "+time_text(schedule.start)+"–"+time_text(schedule.end)+( " (24 h)" if schedule.start == schedule.end else (" (+1 jour)" if schedule.end < schedule.start else ""))

static func time_factor(hour: float) -> float:
	# Smooth shoulders around a clear late-evening peak; never zero if open.
	var points = [[0.0,1.05],[1.0,1.0],[3.0,.65],[5.0,.16],[8.0,.08],[12.0,.13],[16.0,.24],[18.0,.55],[20.0,.85],[22.0,1.15],[24.0,1.05]]
	for i in range(points.size()-1):
		if hour < points[i+1][0]:
			return lerpf(points[i][1],points[i+1][1],(hour-points[i][0])/(points[i+1][0]-points[i][0]))
	return 1.05

static func day_factor(day: int, hour: float) -> float:
	# Friday/Saturday nights keep their weekend peak after midnight.
	var owner = weekday(day-1 if hour < 6.0 else day)
	return [0.8,.85,.9,1.0,1.35,1.55,1.1][owner]
