extends SceneTree
## Пачка партий бота для настройки баланса: по одной строке на партию и сводка.
## Запуск: godot --headless --script res://tools/sim_batch.gd -- [партий] [линия|all] [страна|-] [путь=число …]
## Страна по умолчанию — по очереди из десяти разных зон и регионов. Аргументы вида
## «movement.growth=0.06» подменяют числа баланса — так удобно пробовать настройки.

const STARTS: PackedStringArray = ["FRA", "BRA", "IND", "NGA", "DEU", "MEX", "IDN", "EGY", "TUR", "ZAF"]


func _initialize() -> void:
	var all_args := OS.get_cmdline_user_args()
	var args := PackedStringArray()
	var overrides := {}
	for a in all_args:
		if "=" in a:
			overrides[a.get_slice("=", 0)] = float(a.get_slice("=", 1))
		else:
			args.append(a)
	var games := int(args[0]) if args.size() > 0 else 10
	var line_arg := args[1] if args.size() > 1 else "all"
	var fixed_start := args[2] if args.size() > 2 and args[2] != "-" else ""
	var data := GameData.load_default()
	for key: String in overrides:
		data._numbers[key] = overrides[key]
	if not overrides.is_empty():
		print("подмена: ", overrides)
	var lines := data.line_order if line_arg == "all" else PackedStringArray([line_arg])
	var per_year := int(data.num("time.weeks_per_year"))
	for line in lines:
		var outcomes := {}
		var first_years := []
		var revs_total := 0
		var thermidor_total := 0
		var fallen_total := 0
		print("— линия %s —" % line)
		for g in games:
			var start := fixed_start if fixed_start != "" else STARTS[g % STARTS.size()]
			var sim := SimWorld.new_game(data, 1000 + g, start, line)
			var first := -1
			var present_2 := 0
			var present_5 := 0
			var tree_done := -1
			while not sim.is_over():
				BotPlayer.play_week(sim)
				sim.step()
				if tree_done < 0 and sim.upgrades.size() == data.upgrade_order.size():
					tree_done = sim.week
				if first < 0 and sim.revolutionary_count() > 0:
					first = sim.week
				if sim.week == 2 * per_year:
					present_2 = _present(sim)
				elif sim.week == 5 * per_year:
					present_5 = _present(sim)
			var zones := {"core": 0, "semi": 0, "periphery": 0}
			var thermidor := 0
			var bureaucracy := 0.0
			for cs in sim.countries:
				if cs.is_revolutionary():
					zones[cs.country.zone] += 1
					bureaucracy += cs.bureaucracy
					if NewSociety.is_thermidor(cs):
						thermidor += 1
			var fallen := 0
			for item: Dictionary in sim.chronicle:
				if item["key"] == "NEWS_COUNTERREVOLUTION":
					fallen += 1
			thermidor_total += thermidor
			fallen_total += fallen
			revs_total += sim.revolutionary_count()
			outcomes[sim.outcome] = outcomes.get(sim.outcome, 0) + 1
			if first >= 0:
				first_years.append(float(first) / per_year)
			print("%s seed %d: %-16s неделя %4d, первая революция %s, революций %d (ядро %d, полупер. %d, пер. %d; Термидор %d, пало %d, бюрокр. %.0f), стран с движением: 2 г. %d, 5 лет %d, улучшений %d (все — %s), солидарность %d, реакция-пик %d, очки %d" % [
				start, 1000 + g, sim.outcome, sim.week, ("%.1f г." % (float(first) / per_year)) if first >= 0 else "—",
				sim.revolutionary_count(), zones["core"], zones["semi"], zones["periphery"], thermidor, fallen,
				bureaucracy / maxf(sim.revolutionary_count(), 1), present_2, present_5,
				sim.upgrades.size(), ("%.1f г." % (float(tree_done) / per_year)) if tree_done >= 0 else "—",
				int(sim.solidarity_earned), int(sim.peak_reaction), sim.score()["total"]])
		var avg := 0.0
		for y: float in first_years:
			avg += y
		print("итог %s: исходы %s, первая революция в среднем %.1f г. (%d из %d партий), революций в среднем %.1f, Термидор %.1f, пало %.1f" % [
			line, outcomes, avg / maxf(first_years.size(), 1), first_years.size(), games, float(revs_total) / games,
			float(thermidor_total) / games, float(fallen_total) / games])
	quit()


func _present(sim: SimWorld) -> int:
	var n := 0
	for cs in sim.countries:
		if cs.influence >= 1.0 or cs.is_revolutionary():
			n += 1
	return n
