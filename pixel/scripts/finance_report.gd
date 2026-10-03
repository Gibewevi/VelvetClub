class_name FinanceReport
extends RefCounted

# The finance report: what the club earned and spent over a chosen period,
# line by line (wages by job), the result, and the last two weeks day by day.

const DAYS_SHOWN = 14
const INCOME_COLOR = Color("7fe07a")
const SPENDING_COLOR = Color("df7798")

static func open(hud) -> void:
	hud.open_modal("Bilan financier",func(body): build(hud,body),420)

static func period_text(sim, key: String) -> String:
	var weekday = func(d): return ClubCalendar.DAYS[ClubCalendar.weekday(d)].to_lower()
	match key:
		"today": return "Jour %d · %s · en cours" % [sim.day,weekday.call(sim.day)]
		"yesterday": return "Jour %d · %s" % [sim.day-1,weekday.call(sim.day-1)] if sim.day > 1 else "Pas encore de journée précédente"
		"week": return "Jours %d à %d" % [maxi(1,sim.day-6),sim.day]
		"month": return "Jours %d à %d" % [maxi(1,sim.day-29),sim.day]
	return "Depuis le jour %d" % sim.ledger.opened if sim.ledger.opened > 0 else "Depuis l'ouverture des comptes"

static func line(hud, parent: Node, text: String, value: int, color: Color, strong: bool = false, indent: bool = false) -> void:
	var row = UiKit.hbox(parent,3)
	var l = UiKit.label(("    " if indent else "")+text,1,UiKit.INK if strong else UiKit.MUTED)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(l)
	row.add_child(UiKit.label(("%s $" % UiKit.money(value)) if value != 0 else "—",1,color if value != 0 else UiKit.DIM))

static func build(hud, body: VBoxContainer) -> void:
	var sim = hud.game.sim
	var key: String = hud.finance_period
	# the period
	var choices = HFlowContainer.new()
	choices.alignment = FlowContainer.ALIGNMENT_CENTER
	choices.add_theme_constant_override("h_separation",2*hud.S)
	choices.add_theme_constant_override("v_separation",2*hud.S)
	body.add_child(choices)
	for p in Ledger.PERIODS:
		var b = UiKit.button(p[1],func():
			hud.finance_period = p[0]
			open(hud),choices)
		UiKit.set_active(b,key == p[0])
	body.add_child(hud.wrap_label(period_text(sim,key),1,UiKit.GOLD))
	var bucket: Dictionary = sim.ledger.period(key,sim.day)
	# two columns: the lines on the left, the result and the days on the right
	var columns = UiKit.hbox(body,10)
	var left = UiKit.vbox(columns,2)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.custom_minimum_size.x = 200*hud.S
	var right = UiKit.vbox(columns,3)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.custom_minimum_size.x = 196*hud.S
	# what came in (whole dollars, the totals are the sums of the lines shown)
	hud.section("RECETTES",left)
	var income = 0
	for o in Ledger.INCOME:
		var v = roundi(float(bucket["in"].get(o[0],0.0)))
		income += v
		if v > 0 or o[0] in ["entry","bar","services"]: line(hud,left,o[1],v,INCOME_COLOR)
	line(hud,left,"Total des recettes",income,INCOME_COLOR,true)
	# what went out
	hud.section("DÉPENSES",left)
	var spending = 0
	for o in Ledger.EXPENSE:
		if o[0] == "wages":
			# the wages by job, the largest first; their total is their sum
			var jobs: Array = bucket.wages.keys()
			jobs.sort_custom(func(a,b): return float(bucket.wages[a]) > float(bucket.wages[b]))
			var lines: Array = []
			var wages = 0
			for job in jobs:
				var w = roundi(float(bucket.wages[job]))
				if w <= 0: continue
				wages += w
				lines.append([Catalog.ITEMS.get(job,{}).get("name",job),w])
			spending += wages
			line(hud,left,o[1],wages,SPENDING_COLOR)
			for l in lines: line(hud,left,"· "+String(l[0]),int(l[1]),SPENDING_COLOR,false,true)
			continue
		var v = roundi(float(bucket["out"].get(o[0],0.0)))
		if v <= 0: continue
		spending += v
		line(hud,left,o[1],v,SPENDING_COLOR)
	line(hud,left,"Total des dépenses",spending,SPENDING_COLOR,true)
	body = right
	# the result
	hud.section("RÉSULTAT",body)
	var net = income-spending
	var result = UiKit.hbox(body,3)
	var rl = UiKit.label("Recettes − dépenses",1,UiKit.INK)
	rl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	result.add_child(rl)
	result.add_child(UiKit.label(("+" if net > 0 else ("−" if net < 0 else ""))+UiKit.money(absi(net))+" $",3,UiKit.GREEN if net > 0 else (UiKit.RED if net < 0 else UiKit.MUTED)))
	if income > 0:
		body.add_child(hud.wrap_label("Marge : %d %% des recettes" % roundi(100.0*net/income),1,UiKit.MUTED))
	body.add_child(hud.wrap_label("Trésorerie actuelle : %s $" % UiKit.money(sim.money),1,UiKit.INK))
	# day by day
	# only the days the books cover, at most the last two weeks
	var first = maxi(maxi(1,sim.ledger.opened if sim.ledger.opened > 0 else sim.day),sim.day-DAYS_SHOWN+1)
	var shown = sim.day-first+1
	hud.section("JOUR PAR JOUR" if shown < DAYS_SHOWN else "%d DERNIERS JOURS" % DAYS_SHOWN,body)
	var rows: Array = sim.ledger.daily(sim.day,shown)
	var ins: Array = []
	var outs: Array = []
	var labels: Array = []
	for r in rows:
		ins.append(float(r["in"]))
		outs.append(float(r["out"]))
		labels.append("J%d" % int(r.day))
	var graph = TrafficManagement.chart(hud,body,ins,labels,outs,0,INCOME_COLOR)
	graph.other_color = SPENDING_COLOR
	graph.main_name = "Recettes ($)"
	graph.other_name = "Dépenses ($)"
	var legend = UiKit.hbox(body,6)
	legend.alignment = BoxContainer.ALIGNMENT_CENTER
	for pair in [["Recettes",INCOME_COLOR],["Dépenses",SPENDING_COLOR]]:
		var swatch = ColorRect.new()
		swatch.color = pair[1]
		swatch.custom_minimum_size = Vector2(6,6)*hud.S
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		legend.add_child(swatch)
		legend.add_child(UiKit.label(pair[0],1,UiKit.MUTED))
	body.add_child(hud.wrap_label("Travaux et achats comptent le jour de la commande ; une revente ou une annulation revient en recette. Les salaires courent à l'heure, club ouvert ou fermé."))
