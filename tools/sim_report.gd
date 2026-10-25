extends SceneTree
## Безголовый прогон симуляции без игрока и отчёт для проверки модели.
## Запуск: godot --headless --script res://tools/sim_report.gd -- [seed] [страна] [лет] [bot] [линия]
## Без страны движение не зарождается: проверяется только мир (цикл, империализм, Реакция).
## С «bot» за движение играет BotPlayer; линия — vanguard, councils, syndicalism, mass_party, peoples_war.

const FIELDS: PackedStringArray = [
	"unemployment", "real_wage", "need", "exploitation", "productive_forces", "contradiction",
	"hegemony", "legitimacy", "elite_split", "influence", "consciousness", "organization", "rev_situation",
]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var seed_value := int(args[0]) if args.size() > 0 else 1
	var start := args[1] if args.size() > 1 else ""
	var years := int(args[2]) if args.size() > 2 else 20
	var bot := args.size() > 3 and args[3] == "bot"
	var line := args[4] if args.size() > 4 else ("vanguard" if bot else "")
	var data := GameData.load_default()
	var sim := SimWorld.new_game(data, seed_value, start, line)
	var weeks_per_year := int(data.num("time.weeks_per_year"))
	var mins := {}
	var maxs := {}
	for f in FIELDS:
		mins[f] = INF
		maxs[f] = -INF
	var step_usec := 0
	var steps := 0
	var peak := {"rev": -1.0}
	print("seed=%d start=%s years=%d line=%s" % [seed_value, start if start != "" else "—", years, line])
	print("year  phase        depth  reaction  aristo  infl(M)  rev  | FRA unemp wage need  | NGA unemp need hegem  | старт: infl cons org rev кадры  солид. стран упгр")
	for y in years:
		for w in weeks_per_year:
			if sim.is_over():
				break
			if bot:
				BotPlayer.play_week(sim)
			var s0 := Time.get_ticks_usec()
			sim.step()
			step_usec += Time.get_ticks_usec() - s0
			steps += 1
			if start != "":
				var sc := sim.state_of(start)
				if not sc.is_revolutionary() and sc.rev_situation > peak["rev"]:
					peak = {"rev": sc.rev_situation, "top": sc.top_cant, "bottom": sc.bottom_wont, "mass": sc.mass_activity,
						"org": sc.organization, "need": sc.need, "u": sc.unemployment, "week": sim.week}
			for cs in sim.countries:
				for f in FIELDS:
					var v := cs.get_field(f)
					mins[f] = minf(mins[f], v)
					maxs[f] = maxf(maxs[f], v)
		var fra := sim.state_of("FRA")
		var nga := sim.state_of("NGA")
		var st := sim.state_of(start) if start != "" else fra
		var present := 0
		for cs in sim.countries:
			if cs.influence >= 1.0 and not cs.is_revolutionary():
				present += 1
		print("%4d  %-11s  %4.2f   %6.1f    %4.2f  %7.1f  %3d  |  %5.1f %5.1f %5.1f  |  %5.1f %5.1f %5.1f  |  %5.1f %4.1f %4.1f %4.1f %4.1f  %5.1f %4d %3d" % [
			sim.year(), sim.phase_id(), sim.depth, sim.reaction, sim.core_aristocracy,
			sim.influenced_people() / 1.0e6, sim.revolutionary_count(),
			fra.unemployment, fra.real_wage, fra.need, nga.unemployment, nga.need, nga.hegemony,
			st.influence, st.consciousness, st.organization, st.rev_situation, st.cadres, sim.solidarity,
			present, sim.upgrades.size()])
		if sim.is_over():
			break
	var elapsed := step_usec / 1000.0
	var crisis_years := PackedStringArray()
	for wk in sim.crisis_weeks:
		crisis_years.append("%.1f" % (float(wk) / weeks_per_year))
	print("кризисы (год партии): ", ", ".join(crisis_years))
	var gaps := PackedStringArray()
	for i in range(1, sim.crisis_weeks.size()):
		gaps.append("%.1f" % (float(sim.crisis_weeks[i] - sim.crisis_weeks[i - 1]) / weeks_per_year))
	print("промежутки, лет: ", ", ".join(gaps))
	for f in FIELDS:
		print("  %-18s %7.2f … %7.2f" % [f, mins[f], maxs[f]])
	var revs := PackedStringArray()
	for cs in sim.countries:
		if cs.is_revolutionary():
			revs.append("%s (%d)" % [cs.country.id, sim.data.num("time.start_year") + cs.revolution_week / 52])
	print("революции: ", ", ".join(revs))
	if start != "":
		print("пик ситуации в стартовой стране: ", peak)
	var top := sim.countries.duplicate()
	top.sort_custom(func(a: CountryState, b: CountryState) -> bool: return a.influence > b.influence)
	var tops := PackedStringArray()
	for cs: CountryState in top.slice(0, 8):
		tops.append("%s %.0f%%" % [cs.country.id, cs.influence])
	print("влияние: ", ", ".join(tops))
	var unrest_news := 0
	print("пузырьков собрано: %d, протестов поддержано: %d, подавлено: %d" % [sim.bubbles_collected,
		sim.protests_supported, sim.protests_suppressed])
	print("очки: ", sim.score())
	print("исход: %s на неделе %d; шаг: %.3f мс" % [sim.outcome if sim.outcome != "" else "—", sim.week, elapsed / maxf(steps, 1)])
	quit()
