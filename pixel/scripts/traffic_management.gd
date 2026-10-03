class_name TrafficManagement
extends RefCounted

static func chart(hud, parent: Node, values: Array, labels: Array, secondary: Array = [], limit: float = 0, color: Color = Color("e0b65c")) -> TrafficChart:
	var graph = TrafficChart.new()
	graph.series = values
	graph.labels = labels
	graph.secondary = secondary
	graph.ceiling = limit
	graph.color = color
	graph.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(graph)
	return graph

static func populate(hud) -> void:
	var sim = hud.game.sim
	var body: VBoxContainer = hud.drawer_body
	UiKit.button("Régler les tarifs",hud.toggle_drawer.bind("services"),body,"Entrées, boissons, scène et prestations")
	# the books in short, the full report a click away
	hud.section("FINANCES",body)
	var today: Dictionary = sim.ledger.period("today",sim.day)
	var earned = Ledger.total(today,"in")
	var spent = Ledger.total(today,"out")
	body.add_child(hud.wrap_label("Aujourd'hui : +%s $ de recettes · −%s $ de dépenses · résultat %s%s $" % [UiKit.money(earned),UiKit.money(spent),"+" if earned >= spent else "−",UiKit.money(absi(earned-spent))],1,UiKit.INK))
	UiKit.button("Bilan financier",func(): FinanceReport.open(hud),body,"Le détail : prestations, boissons, pourboires, salaires par poste, travaux et achats")
	hud.section("EN DIRECT",body)
	var inside = sim.inside_count()
	var capacity = sim.admission.capacity
	body.add_child(hud.wrap_label("%d / %d à l'intérieur · %d en file" % [inside,capacity,sim.queue.size()],1,UiKit.INK))
	var gauge = ProgressBar.new()
	gauge.max_value = 100
	gauge.value = 100.0*inside/capacity if capacity > 0 else 0
	gauge.custom_minimum_size.y = 12*hud.S
	gauge.tooltip_text = "Capacité liée à l'espace public accessible : agrandir l'accueil et le salon permet de recevoir davantage de clients."
	gauge.add_theme_stylebox_override("background",UiKit.flat(Color("15141d"),UiKit.DIM))
	gauge.add_theme_stylebox_override("fill",UiKit.flat(Color("945575"),UiKit.ACCENT))
	body.add_child(gauge)
	body.add_child(hud.wrap_label("Demande : ~%.0f clients/h · Note %.1f/5" % [sim.demand_factors().per_hour,sim.rating]))
	var select = OptionButton.new()
	for offset in range(TrafficHistory.KEEP_DAYS):
		if sim.day-offset < 1: break
		select.add_item("Aujourd'hui" if offset == 0 else "Jour %d · %s" % [sim.day-offset,ClubCalendar.DAYS[ClubCalendar.weekday(sim.day-offset)]])
	hud.management_day_offset = clampi(hud.management_day_offset,0,select.item_count-1)
	select.select(hud.management_day_offset)
	select.item_selected.connect(func(offset):
		hud.management_day_offset = offset
		hud.fill_drawer())
	body.add_child(select)
	var selected_day = sim.day-hud.management_day_offset
	var rows = sim.traffic.day_rows(selected_day)
	var totals = sim.traffic.summary(rows)
	hud.section("BILAN DU JOUR %d" % selected_day,body)
	body.add_child(hud.wrap_label("%.0f arrivées · %.0f entrées\n%.0f abandons · %.0f renoncements avant la file" % [totals.arrivals,totals.admitted,totals.abandoned,totals.balked],1,UiKit.INK))
	var arrival_values: Array = []
	var entry_values: Array = []
	var occupancy_values: Array = []
	var hour_labels: Array = []
	var peak = -1
	var peak_count = 0
	for hour in range(24):
		var row: Dictionary = rows[hour]
		arrival_values.append(float(row.arrivals) if not row.is_empty() else -1.0)
		entry_values.append(float(row.admitted) if not row.is_empty() else -1.0)
		occupancy_values.append(100*float(row.occupied_minutes)/row.capacity_minutes if not row.is_empty() and row.capacity_minutes > 0 else (-1.0 if row.is_empty() else 0.0))
		hour_labels.append("%02d" % hour)
		if not row.is_empty() and int(row.arrivals) > peak_count:
			peak = hour
			peak_count = int(row.arrivals)
	hud.section("CLIENTS PAR HEURE",body)
	body.add_child(hud.wrap_label("Or : arrivées · Rose : entrées"))
	chart(hud,body,arrival_values,hour_labels,entry_values)
	if peak >= 0: body.add_child(hud.wrap_label("Pointe observée : %02d h–%02d h · %d arrivées." % [peak,(peak+1)%24,peak_count],1,UiKit.GOLD))
	body.add_child(hud.wrap_label("Occupation moyenne : %.0f %% · Attente : %.1f min\nFile maximale : %d · Présents au pic : %d" % [totals.occupancy,totals.wait,totals.peak_queue,totals.peak_inside]))
	hud.section("OCCUPATION PAR HEURE (%)",body)
	chart(hud,body,occupancy_values,hour_labels,[],100,Color("8ab7ad")).main_name = "Occupation (%)"
	hud.section("LES 7 DERNIERS JOURS",body)
	var daily: Array = []
	var daily_entries: Array = []
	var days: Array = []
	for offset in range(6,-1,-1):
		var day = sim.day-offset
		var summary = sim.traffic.summary(sim.traffic.day_rows(day))
		daily.append(summary.arrivals if summary.minutes > 0 else -1.0)
		daily_entries.append(summary.admitted if summary.minutes > 0 else -1.0)
		days.append(ClubCalendar.SHORT_DAYS[ClubCalendar.weekday(day)])
	chart(hud,body,daily,days,daily_entries)
	hud.section("PRÉVISION SUR 24 HEURES",body)
	var forecast = ClubDemand.forecast(sim)
	var expected: Array = []
	var labels: Array = []
	var highest = forecast[0]
	for point in forecast:
		expected.append(point.value)
		labels.append("%02d" % int(point.hour))
		if point.value > highest.value: highest = point
	chart(hud,body,expected,labels,[],0,Color("8fa6d9")).main_name = "Arrivées prévues/h"
	body.add_child(hud.wrap_label("Pointe attendue : %s vers %02d h · environ %.0f clients/h." % [ClubCalendar.DAYS[ClubCalendar.weekday(highest.day)],int(highest.hour),highest.value] if highest.value > 0 else "Aucune ouverture prévue sur ces 24 heures.",1,UiKit.GOLD))
	body.add_child(hud.wrap_label("Prévision à note et tarifs actuels, hors pluie. Respecte les horaires automatiques ; sinon suppose le club ouvert. Les arrivées restent aléatoires."))
	UiKit.button("Adapter les horaires du club",func(): hud.show_schedule(-1),body)
	body.add_child(hud.wrap_label("Prévoir l'accueil avant la pointe, le bar et le ménage pendant les heures chargées. Un club complet nécessite aussi davantage d'espace public."))
	body.add_child(hud.wrap_label("Historique conservé 28 jours. Les heures sans mesure sont marquées — ; une heure en cours reste partielle."))
