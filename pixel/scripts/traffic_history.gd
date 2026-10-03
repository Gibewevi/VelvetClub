class_name TrafficHistory
extends RefCounted

const KEEP_DAYS = 28
const COUNTS = ["attempts","arrivals","admitted","abandoned","balked","wait_count"]
const MEASURES = ["minutes","open_minutes","occupied_minutes","capacity_minutes","queue_minutes","wait_minutes","rain_minutes"]
var hours: Dictionary = {}
var pruned_day = 0

func bucket(day: int, minute: float) -> Dictionary:
	var hour = clampi(floori(minute/60),0,23)
	var key = "%d:%d" % [day,hour]
	if not hours.has(key):
		var row = {"day":day,"hour":hour,"peak_inside":0,"peak_queue":0}
		for field in COUNTS+MEASURES: row[field] = 0
		hours[key] = row
	return hours[key]

func count(day: int, minute: float, field: String, amount: int = 1) -> void:
	if field in COUNTS:
		var row = bucket(day,minute)
		row[field] = int(row[field])+maxi(0,amount)

func admitted(day: int, minute: float, wait: float) -> void:
	var row = bucket(day,minute)
	row.admitted += 1
	row.wait_count += 1
	row.wait_minutes += maxf(0,wait)

func observe(day: int, minute: float, minutes: float, opened: bool, inside: int, capacity: int, waiting: int, rain: float) -> void:
	# Split at hour AND midnight boundaries; occupancy is weighted by game
	# time, never by frame count or speed setting.
	while minutes > .000001:
		var step = minf(minutes,60-fposmod(minute,60))
		var row = bucket(day,minute)
		row.minutes += step
		if opened:
			row.open_minutes += step
			row.occupied_minutes += clampi(inside,0,capacity)*step
			row.capacity_minutes += maxi(0,capacity)*step
			row.queue_minutes += maxi(0,waiting)*step
			row.rain_minutes += clampf(rain,0,1)*step
		row.peak_inside = maxi(int(row.peak_inside),inside)
		row.peak_queue = maxi(int(row.peak_queue),waiting)
		minutes -= step
		minute += step
		if minute >= 1440-.000001:
			minute = 0
			day += 1
	if day != pruned_day:
		for key in hours.keys():
			if int(hours[key].day) < day-KEEP_DAYS+1: hours.erase(key)
		pruned_day = day

func day_rows(day: int) -> Array:
	var rows: Array = []
	for hour in range(24): rows.append(hours.get("%d:%d" % [day,hour],{}))
	return rows

func summary(rows: Array) -> Dictionary:
	var total = {"peak_inside":0,"peak_queue":0}
	for field in COUNTS+MEASURES: total[field] = 0.0
	for row in rows:
		if row.is_empty(): continue
		for field in COUNTS+MEASURES: total[field] += float(row.get(field,0))
		for field in ["peak_inside","peak_queue"]: total[field] = maxi(int(total[field]),int(row.get(field,0)))
	total.occupancy = 100*float(total.occupied_minutes)/total.capacity_minutes if total.capacity_minutes > 0 else 0.0
	total.wait = float(total.wait_minutes)/total.wait_count if total.wait_count > 0 else 0.0
	return total

func to_dict() -> Dictionary:
	return {"version":1,"hours":hours.values().duplicate(true)}

func from_dict(data: Variant) -> void:
	hours.clear()
	pruned_day = 0
	if not data is Dictionary or not data.get("hours") is Array: return
	var rows: Array = []
	for raw in data.hours.slice(0,KEEP_DAYS*24):
		if not raw is Dictionary: continue
		var day = raw.get("day")
		var hour = raw.get("hour")
		if not (day is int or day is float) or not (hour is int or hour is float): continue
		if not is_finite(day) or not is_finite(hour) or day < 1 or day > 1000000000 or day != floor(day) or hour < 0 or hour > 23 or hour != floor(hour): continue
		var row = {"day":int(day),"hour":int(hour)}
		for field in COUNTS+MEASURES+["peak_inside","peak_queue"]:
			var value = raw.get(field,0)
			row[field] = clampf(float(value),0,1000000000) if (value is int or value is float) and is_finite(float(value)) else 0.0
			if field in COUNTS or field.begins_with("peak_"): row[field] = int(row[field])
		row.minutes = minf(60,row.minutes)
		row.open_minutes = minf(row.minutes,row.open_minutes)
		rows.append(row)
	rows.sort_custom(func(a,b): return a.day*24+a.hour > b.day*24+b.hour)
	for row in rows:
		var key = "%d:%d" % [row.day,row.hour]
		if not hours.has(key): hours[key] = row
