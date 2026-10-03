class_name Ledger
extends RefCounted

# The club's books: what comes in and goes out, day by day and by kind, the
# wages by job. Kept for the last KEEP_DAYS days, plus the totals since the
# books were opened. Saved with the game.

const KEEP_DAYS = 60
const INCOME = [
	["entry","Entrées"],
	["bar","Boissons et alcools"],
	["stage","Spectacle sur scène"],
	["services","Prestations en chambre"],
	["private_tips","Pourboires des prestations"],
	["stage_tips","Pourboires sur scène"],
	["floor_tips","Pourboires sur la piste"],
	["resale","Reventes et remboursements"]]
const EXPENSE = [
	["wages","Salaires"],
	["ads","Annonces de recrutement"],
	["building","Travaux : pièces, cloisons, finitions"],
	["furniture","Mobilier et équipements"],
	["parking","Parkings"]]
const PERIODS = [["today","Aujourd'hui"],["yesterday","Hier"],["week","7 jours"],["month","30 jours"],["all","Depuis le début"]]

var days: Dictionary = {}     # day -> {"in":{kind:$},"out":{kind:$},"wages":{job:$}}
var totals: Dictionary = {}   # the same since the books were opened
var opened = 0                # the first day in the books

func _init() -> void:
	totals = blank()

static func blank() -> Dictionary:
	return {"in":{},"out":{},"wages":{}}

func book(day: int, side: String, kind: String, amount: float, job: String = "") -> void:
	# side "in" or "out"; job: the staff kind, for wages
	if amount <= 0.0 or not side in ["in","out"]: return
	if opened <= 0: opened = day
	if not days.has(day): days[day] = blank()
	for bucket in [days[day],totals]:
		bucket[side][kind] = float(bucket[side].get(kind,0.0))+amount
		if job != "": bucket.wages[job] = float(bucket.wages.get(job,0.0))+amount
	for d in days.keys():
		if int(d) <= day-KEEP_DAYS: days.erase(d)

func book_value(day: int, before: Dictionary, after: Dictionary) -> void:
	# building work and purchases: what each kind of spending changed by
	for kind in ["building","furniture","parking"]:
		var diff = int(after.get(kind,0))-int(before.get(kind,0))
		if diff > 0: book(day,"out",kind,diff)
		elif diff < 0: book(day,"in","resale",-diff)

func range_sum(first: int, last: int) -> Dictionary:
	var out = blank()
	for d in days:
		if int(d) < first or int(d) > last: continue
		for side in ["in","out","wages"]:
			for kind in days[d][side]: out[side][kind] = float(out[side].get(kind,0.0))+float(days[d][side][kind])
	return out

func period(key: String, today: int) -> Dictionary:
	match key:
		"today": return range_sum(today,today)
		"yesterday": return range_sum(today-1,today-1)
		"week": return range_sum(today-6,today)
		"month": return range_sum(today-29,today)
	return totals.duplicate(true)

static func total(bucket: Dictionary, side: String) -> int:
	var sum = 0.0
	for kind in bucket.get(side,{}): sum += float(bucket[side][kind])
	return roundi(sum)

func daily(today: int, count: int) -> Array:
	# [{day, in, out}] for the last days, oldest first
	var out: Array = []
	for d in range(today-count+1,today+1):
		var bucket: Dictionary = days.get(d,blank())
		out.append({"day":d,"in":total(bucket,"in"),"out":total(bucket,"out")})
	return out

func to_dict() -> Dictionary:
	var saved_days = {}
	for d in days: saved_days[str(d)] = days[d].duplicate(true)
	return {"days":saved_days,"totals":totals.duplicate(true),"opened":opened}

static func clean_bucket(raw) -> Dictionary:
	# known kinds and jobs only, finite positive amounts
	var out = blank()
	if not raw is Dictionary: return out
	var known = {"in":INCOME.map(func(o): return o[0]),"out":EXPENSE.map(func(o): return o[0])}
	for side in ["in","out","wages"]:
		var part = raw.get(side,{})
		if not part is Dictionary: continue
		for kind in part:
			var v = part[kind]
			if not (v is int or v is float) or not is_finite(float(v)) or float(v) < 0: continue
			if side == "wages" and not (kind is String and Catalog.ITEMS.has(kind)): continue
			if side != "wages" and not kind in known[side]: continue
			out[side][kind] = minf(float(v),1e12)
	return out

func from_dict(data) -> void:
	days = {}
	totals = blank()
	opened = 0
	if not data is Dictionary: return
	var raw_days = data.get("days",{})
	if raw_days is Dictionary:
		for d in raw_days:
			if not (d is String and d.is_valid_int()): continue
			days[int(d)] = clean_bucket(raw_days[d])
	totals = clean_bucket(data.get("totals",{}))
	var o = data.get("opened",0)
	if (o is int or o is float) and is_finite(float(o)): opened = maxi(0,int(o))
