class_name ClubDemand
extends RefCounted

const BASE_PER_HOUR = 8.0

static func reputation(note: float) -> float:
	# Unclipped, continuous progression: 5 stars attract ~8.5 times as many
	# visitors as 1 star, at the same time, prices and weather.
	var levels = [.25,.65,1.25,2.2,3.6,5.5]
	var value = clampf(note,0,5)
	var lo = mini(4,floori(value))
	return lerpf(levels[lo],levels[lo+1],value-lo)

static func factors(note: float, day: int, hour: float, rain: float, prices: Dictionary) -> Dictionary:
	var price = clampf(1.0-(float(prices.get("entry",20))-20)/160.0-(float(prices.get("drink",12))-12)/120.0,.65,1.15)
	var result = {"hour":ClubCalendar.time_factor(hour),"day":ClubCalendar.day_factor(day,hour),"reputation":reputation(note),"weather":1.0-.3*clampf(rain,0,1),"price":price}
	result.rate = result.hour*result.day*result.reputation*result.weather*result.price
	result.per_hour = BASE_PER_HOUR*result.rate
	return result

static func forecast(sim, hours: int = 24) -> Array:
	var result: Array = []
	var start = (sim.day-1)*1440+floori(sim.minute/60)*60
	for i in hours:
		var absolute = start+i*60
		var day = absolute/1440+1
		var hour = (absolute%1440)/60
		var expected = 0.0
		for part in range(4):
			var minute = hour*60+part*15+7.5
			if not sim.opening_hours.enabled or ClubCalendar.covers(sim.opening_hours,day,minute):
				expected += factors(sim.rating,day,minute/60,0,sim.prices).per_hour/4.0
		result.append({"day":day,"hour":hour,"value":expected})
	return result
