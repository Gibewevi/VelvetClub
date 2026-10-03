class_name ClubSeasons
extends RefCounted

# The existing day counter still owns weekdays, payroll and traffic. Its first
# day is 1 April, year 1; no real-world clock is used for a saved club.
const MONTHS = ["janvier","février","mars","avril","mai","juin","juillet","août","septembre","octobre","novembre","décembre"]
const LENGTHS = [31,28,31,30,31,30,31,31,30,31,30,31]
const NAMES = ["Printemps","Été","Automne","Hiver"]
# Continuous targets on the FIRST of each month: warm foliage, leaf loss,
# snow cover. The same pixels/clusters stay in place through every blend.
const TARGETS = [
	[0.0,1.0,1.0],[0.0,1.0,1.0],[0.0,.85,.55],[0.0,0.0,0.0],
	[0.0,0.0,0.0],[0.0,0.0,0.0],[0.0,0.0,0.0],[0.0,0.0,0.0],
	[.12,0.0,0.0],[.9,.2,0.0],[1.0,.7,.06],[.3,1.0,.85]]

static func leap(year: int) -> bool:
	return year % 4 == 0 and (year % 100 != 0 or year % 400 == 0)

static func month_days(month: int, year: int) -> int:
	return 29 if month == 2 and leap(year) else int(LENGTHS[clampi(month,1,12)-1])

static func date(day: int) -> Dictionary:
	var offset = maxi(day,1)-1+90 # Jan + Feb + March in year 1
	var cycles = offset/146097
	var year = 1+cycles*400
	offset %= 146097
	while offset >= (366 if leap(year) else 365):
		offset -= 366 if leap(year) else 365
		year += 1
	var month = 1
	while offset >= month_days(month,year):
		offset -= month_days(month,year)
		month += 1
	return {"year":year,"month":month,"day":offset+1}

static func season(month: int) -> int:
	if month in [3,4,5]: return 0
	if month in [6,7,8]: return 1
	if month in [9,10,11]: return 2
	return 3

static func state(day: int, minute: float = 0.0) -> Dictionary:
	var d = date(day)
	var a: Array = TARGETS[int(d.month)-1]
	var b: Array = TARGETS[int(d.month)%12]
	var t = (float(d.day)-1.0+clampf(minute,0,1440)/1440.0)/month_days(d.month,d.year)
	# Ease the shoulders without a discontinuity at the next month.
	t = t*t*(3.0-2.0*t)
	return {"autumn":lerpf(a[0],b[0],t),"loss":lerpf(a[1],b[1],t),"snow":lerpf(a[2],b[2],t),"date":d,"season":season(d.month)}

static func text(day: int) -> String:
	var d = date(day)
	return "%d %s · %s" % [d.day,MONTHS[d.month-1],NAMES[season(d.month)]]
