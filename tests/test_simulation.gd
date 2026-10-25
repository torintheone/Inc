extends GutTest
## Модель мира: детерминизм, цикл, ограниченность показателей, революционная
## ситуация, сохранение и загрузка, улучшения и действия.

var data: GameData


func before_all() -> void:
	data = GameData.load_default()


func _snapshot(sim: SimWorld) -> String:
	# Через JSON с полной точностью: так сравниваются и числа, и типы после загрузки.
	return JSON.stringify(JSON.parse_string(JSON.stringify(sim.to_dict(), "", true, true)), "", true, true)


## Состояния совпадают: всё дискретное — точно, дробные числа — до 1e-6
## (JSON хранит дробные числа почти, но не до последнего бита).
func _same_state(a: Variant, b: Variant, path: String = "") -> String:
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size():
			return "%s: разное число полей" % path
		for k in a:
			if not b.has(k):
				return "%s.%s: нет после загрузки" % [path, k]
			var diff := _same_state(a[k], b[k], "%s.%s" % [path, k])
			if diff != "":
				return diff
		return ""
	if a is Array and b is Array:
		if a.size() != b.size():
			return "%s: разная длина" % path
		for i in a.size():
			var diff := _same_state(a[i], b[i], "%s[%d]" % [path, i])
			if diff != "":
				return diff
		return ""
	if (a is float or a is int) and (b is float or b is int):
		return "" if absf(float(a) - float(b)) <= 1e-6 * maxf(1.0, absf(float(a))) else "%s: %s ≠ %s" % [path, a, b]
	return "" if a == b else "%s: %s ≠ %s" % [path, a, b]


func _plain(sim: SimWorld) -> Variant:
	return JSON.parse_string(JSON.stringify(sim.to_dict(), "", true, true))


func test_data_loads() -> void:
	assert_not_null(data)
	assert_eq(data.upgrade_order.size() + data.country_action_order.size(), 10, "10 базовых улучшений и действий")
	assert_gt(data.link_a.size(), 500, "связи между странами загружены")
	assert_almost_eq(Array(data.gdp_share).reduce(func(a: float, b: float) -> float: return a + b, 0.0), 1.0, 0.0001)


func test_same_seed_gives_same_game() -> void:
	var a := SimWorld.new_game(data, 42, "FRA")
	var b := SimWorld.new_game(data, 42, "FRA")
	for i in 260:
		BotPlayer.play_week(a)
		a.step()
		BotPlayer.play_week(b)
		b.step()
	assert_eq(_snapshot(a), _snapshot(b), "одинаковый seed — одинаковая партия")
	var c := SimWorld.new_game(data, 43, "FRA")
	c.run_weeks(260)
	assert_ne(_snapshot(a), _snapshot(c), "другой seed — другая партия")


func test_cycle_passes_all_phases_with_crises_every_8_to_11_years() -> void:
	var sim := SimWorld.new_game(data, 7)
	var seen := {}
	for i in 50 * 52:
		sim.step()
		seen[sim.phase_id()] = true
	for id in ["recovery", "boom", "overheat", "crisis", "depression"]:
		assert_true(seen.has(id), "фаза %s встречается" % id)
	assert_between(sim.crisis_weeks.size(), 4, 7, "за 50 лет 4–7 кризисов")
	for i in range(1, sim.crisis_weeks.size()):
		var years := float(sim.crisis_weeks[i] - sim.crisis_weeks[i - 1]) / 52.0
		assert_between(years, 8.0, 11.0, "между кризисами 8–11 лет")


func test_crises_deepen_without_countertendencies() -> void:
	var sim := SimWorld.new_game(data, 11)
	var depths := []
	var cycle := sim.cycle_number
	for i in 40 * 52:
		sim.step()
		if sim.cycle_number != cycle:
			cycle = sim.cycle_number
			depths.append(sim.depth)
	assert_gt(depths.size(), 2)
	for i in range(1, depths.size()):
		assert_gt(depths[i], depths[i - 1], "каждый следующий кризис глубже")


func test_indicators_stay_bounded_for_50_years() -> void:
	var sim := SimWorld.new_game(data, 3, "BRA")
	for i in 50 * 52:
		if sim.is_over():
			break
		BotPlayer.play_week(sim)
		sim.step()
	for cs in sim.countries:
		for f in CountryState.FIELDS:
			var v := cs.get_field(f)
			assert_false(is_nan(v), "%s у %s — число" % [f, cs.country.id])
			if f == "strikes_recent" or f == "demos_recent":
				assert_between(v, 0.0, 50.0, "%s у %s" % [f, cs.country.id])
			elif f == "aristocracy":
				assert_between(v, 0.0, 1.0)
			else:
				assert_between(v, 0.0, 100.0, "%s у %s" % [f, cs.country.id])
	assert_between(sim.reaction, 0.0, 100.0)
	assert_between(sim.depth, data.num("cycle.min_depth"), data.num("cycle.max_depth"))


func test_revolutionary_situation_is_minimum_of_three() -> void:
	assert_eq(MovementSystem.revolutionary_situation(80.0, 90.0, 40.0), 40.0, "одной нищеты мало")
	assert_eq(MovementSystem.revolutionary_situation(30.0, 90.0, 95.0), 30.0)
	var sim := SimWorld.new_game(data, 5, "NGA")
	sim.run_weeks(300)
	for cs in sim.countries:
		if cs.is_revolutionary():
			continue
		assert_almost_eq(cs.rev_situation, minf(cs.top_cant, minf(cs.bottom_wont, cs.mass_activity)), 0.0001)


func test_save_then_load_gives_same_state() -> void:
	var sim := SimWorld.new_game(data, 99, "IND")
	for i in 400:
		BotPlayer.play_week(sim)
		sim.step()
	var text := JSON.stringify(sim.to_dict(), "", true, true)
	var loaded := SimWorld.from_dict(data, JSON.parse_string(text))
	assert_not_null(loaded)
	assert_eq(_same_state(_plain(sim), _plain(loaded)), "", "загруженная партия совпадает с сохранённой")
	for i in 200:
		BotPlayer.play_week(sim)
		sim.step()
		BotPlayer.play_week(loaded)
		loaded.step()
	assert_eq(_same_state(_plain(sim), _plain(loaded)), "", "и дальше идёт так же")


func test_upgrade_needs_solidarity_and_prerequisites() -> void:
	var sim := SimWorld.new_game(data, 1, "FRA")
	sim.solidarity = 100.0
	assert_has(PlayerActions.upgrade_blockers(sim, "workers_party"), "requires:trade_unions")
	assert_false(PlayerActions.buy_upgrade(sim, "workers_party"))
	assert_true(PlayerActions.buy_upgrade(sim, "trade_unions"))
	assert_almost_eq(sim.solidarity, 90.0, 0.001)
	assert_true(sim.has_unlock("strikes"), "профсоюзы открывают стачки")
	assert_has(PlayerActions.upgrade_blockers(sim, "trade_unions"), "owned")
	var reaction_before := sim.reaction
	assert_true(PlayerActions.buy_upgrade(sim, "workers_party"))
	assert_almost_eq(sim.reaction, reaction_before + 5.0, 0.001, "партия поднимает Реакцию на 5")
	sim.solidarity = 1.0
	assert_has(PlayerActions.upgrade_blockers(sim, "leaflets"), "cost")


func test_strikes_require_unions_and_have_cooldown() -> void:
	var sim := SimWorld.new_game(data, 1, "FRA")
	sim.solidarity = 100.0
	var fra := sim.state_of("FRA")
	fra.influence = 10.0
	assert_has(PlayerActions.action_blockers(sim, "factory_strike", fra), "unlock:strikes")
	PlayerActions.buy_upgrade(sim, "trade_unions")
	assert_eq(PlayerActions.action_blockers(sim, "factory_strike", fra).size(), 0)
	var chance := PlayerActions.action_chance(sim, "factory_strike", fra)
	assert_between(chance, 0.05, 0.92)
	var result := PlayerActions.perform(sim, "factory_strike", fra)
	assert_true(result["ok"])
	assert_true(PlayerActions.action_blockers(sim, "factory_strike", fra)[0].begins_with("cooldown:"))


func test_uprising_needs_situation_and_organization() -> void:
	var sim := SimWorld.new_game(data, 1, "FRA")
	sim.solidarity = 100.0
	var fra := sim.state_of("FRA")
	fra.influence = 40.0
	fra.organization = 30.0
	fra.rev_situation = 75.0
	assert_has(PlayerActions.action_blockers(sim, "uprising", fra), "min:organization:50")
	fra.organization = 60.0
	assert_eq(PlayerActions.action_blockers(sim, "uprising", fra).size(), 0)
	sim.make_revolutionary(fra)
	assert_true(fra.is_revolutionary())
	assert_almost_eq(sim.reaction, 10.0, 0.001, "победа революции пугает Реакцию")
	assert_has(PlayerActions.action_blockers(sim, "uprising", fra), "revolutionary")


func test_periphery_revolution_cuts_core_superprofit() -> void:
	var sim := SimWorld.new_game(data, 1)
	var before := sim.core_aristocracy
	assert_gt(before, 0.0, "в начале у ядра есть сверхприбыль")
	for cs in sim.countries:
		if cs.country.zone == "periphery":
			cs.status = CountryState.REVOLUTIONARY
	sim.step()
	assert_lt(sim.core_aristocracy, before * 0.2, "без периферии рабочая аристократия сокращается")


func test_movement_spreads_to_neighbors() -> void:
	var sim := SimWorld.new_game(data, 1, "DEU")
	sim.run_weeks(10 * 52)
	var reached := 0
	for nid in sim.state_of("DEU").country.neighbors:
		if sim.state_of(nid).influence > 0.0:
			reached += 1
	assert_gt(reached, 3, "за 10 лет движение приходит к соседям")


func test_step_is_fast_enough() -> void:
	var sim := SimWorld.new_game(data, 1, "CHN")
	sim.run_weeks(520)
	var t0 := Time.get_ticks_usec()
	sim.run_weeks(104)
	var ms := (Time.get_ticks_usec() - t0) / 1000.0 / 104.0
	gut.p("шаг симуляции: %.3f мс" % ms)
	assert_lt(ms, 5.0, "шаг на 180 стран не дольше 5 мс")


func test_bot_finishes_a_game() -> void:
	var sim := SimWorld.new_game(data, 2024, "EGY")
	while not sim.is_over():
		BotPlayer.play_week(sim)
		sim.step()
	assert_has([SimWorld.OUTCOME_FEDERATION, SimWorld.OUTCOME_WORLD_REVOLUTION, SimWorld.OUTCOME_TWO_SYSTEMS,
		SimWorld.OUTCOME_DEFEAT], sim.outcome)
	assert_lte(sim.week, 50 * 52)
