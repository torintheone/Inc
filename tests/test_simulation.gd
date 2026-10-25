extends GutTest
## Модель мира: детерминизм, цикл, ограниченность показателей, революционная
## ситуация, сохранение и загрузка, улучшения, действия, кадры, стихийные протесты,
## пузырьки и стратегические линии.

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
	assert_gte(data.upgrade_order.size(), 25, "не меньше 25 улучшений")
	assert_gte(data.country_action_order.size(), 14, "все действия в стране")
	assert_eq(data.line_order.size(), 5, "пять стратегических линий")
	assert_eq(data.branches.size(), 5, "пять ветвей развития")
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


func test_cycle_passes_all_phases_with_crises_every_5_to_7_years() -> void:
	for seed_value in [7, 8, 9]:
		var sim := SimWorld.new_game(data, seed_value)
		var seen := {}
		for i in 20 * 52:
			sim.step()
			seen[sim.phase_id()] = true
		for id in ["recovery", "boom", "overheat", "crisis", "depression"]:
			assert_true(seen.has(id), "фаза %s встречается" % id)
		assert_between(sim.crisis_weeks.size(), 2, 4, "за 20 лет 2–4 кризиса")
		for i in range(1, sim.crisis_weeks.size()):
			var years := float(sim.crisis_weeks[i] - sim.crisis_weeks[i - 1]) / 52.0
			assert_between(years, 5.0, 7.5, "между кризисами 5–7 лет")


func test_crises_deepen_without_countertendencies() -> void:
	var sim := SimWorld.new_game(data, 11)
	var depths := []
	var cycle := sim.cycle_number
	for i in 20 * 52:
		sim.step()
		if sim.cycle_number != cycle:
			cycle = sim.cycle_number
			depths.append(sim.depth)
	assert_gt(depths.size(), 1)
	for i in range(1, depths.size()):
		assert_gt(depths[i], depths[i - 1], "каждый следующий кризис глубже")


func test_indicators_stay_bounded_for_whole_game() -> void:
	var sim := SimWorld.new_game(data, 3, "BRA", "councils")
	for i in 20 * 52:
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
	var sim := SimWorld.new_game(data, 99, "IND", "syndicalism")
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


func test_save_file_roundtrip() -> void:
	var path := "user://test_autosave.json"
	var sim := SimWorld.new_game(data, 5, "FRA")
	sim.run_weeks(150)
	assert_true(SaveStore.save(sim, path), "партия сохраняется в файл")
	var loaded := SaveStore.load_game(data, path)
	assert_not_null(loaded)
	assert_eq(_same_state(_plain(sim), _plain(loaded)), "")
	DirAccess.remove_absolute(path)


func test_upgrade_needs_solidarity_and_prerequisites() -> void:
	var sim := SimWorld.new_game(data, 1, "FRA")
	sim.solidarity = 100.0
	assert_has(PlayerActions.upgrade_blockers(sim, "workers_party"), "requires:trade_unions")
	assert_false(PlayerActions.buy_upgrade(sim, "workers_party"))
	assert_has(PlayerActions.upgrade_blockers(sim, "trade_unions"), "requires:study_circles")
	assert_true(PlayerActions.buy_upgrade(sim, "study_circles"))
	assert_true(PlayerActions.buy_upgrade(sim, "trade_unions"))
	assert_almost_eq(sim.solidarity, 100.0 - 4.0 - 8.0, 0.001)
	assert_true(sim.has_unlock("strikes"), "профсоюзы открывают стачки")
	assert_has(PlayerActions.upgrade_blockers(sim, "trade_unions"), "owned")
	var reaction_before := sim.reaction
	assert_true(PlayerActions.buy_upgrade(sim, "workers_party"))
	assert_almost_eq(sim.reaction, reaction_before + 5.0, 0.001, "партия поднимает Реакцию на 5")
	sim.solidarity = 1.0
	assert_has(PlayerActions.upgrade_blockers(sim, "leaflets"), "cost")


func test_strikes_require_unions_cadres_and_have_cooldown() -> void:
	var sim := SimWorld.new_game(data, 1, "FRA", "vanguard")
	sim.solidarity = 100.0
	var fra := sim.state_of("FRA")
	fra.influence = 10.0
	fra.organization = 40.0
	fra.cadres = 0.0
	assert_has(PlayerActions.action_blockers(sim, "factory_strike", fra), "unlock:strikes")
	PlayerActions.buy_upgrade(sim, "study_circles")
	PlayerActions.buy_upgrade(sim, "trade_unions")
	assert_has(PlayerActions.action_blockers(sim, "factory_strike", fra), "cadres:2", "стачка стоит кадров")
	fra.cadres = 5.0
	assert_eq(PlayerActions.action_blockers(sim, "factory_strike", fra).size(), 0)
	var chance := PlayerActions.action_chance(sim, "factory_strike", fra)
	assert_between(chance, 0.05, 0.92)
	var result := PlayerActions.perform(sim, "factory_strike", fra)
	assert_true(result["ok"])
	assert_almost_eq(sim.solidarity, 88.0, 0.001, "действие не тратит солидарность")
	assert_between(fra.cadres, 2.0, 4.0, "кадры потрачены: 5 − 2, ±1 за исход")
	assert_true(PlayerActions.action_blockers(sim, "factory_strike", fra)[0].begins_with("cooldown:"))


func test_uprising_needs_situation_and_organization() -> void:
	var sim := SimWorld.new_game(data, 1, "FRA")
	sim.solidarity = 100.0
	var fra := sim.state_of("FRA")
	fra.influence = 40.0
	fra.organization = 30.0
	fra.cadres = 20.0
	fra.rev_situation = 75.0
	assert_has(PlayerActions.action_blockers(sim, "uprising", fra), "min:organization:50")
	fra.organization = 60.0
	assert_eq(PlayerActions.action_blockers(sim, "uprising", fra).size(), 0)
	sim.make_revolutionary(fra)
	assert_true(fra.is_revolutionary())
	assert_almost_eq(sim.reaction, data.num("revolution.reaction"), 0.001, "победа революции пугает Реакцию")
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
	var sim := SimWorld.new_game(data, 1, "DEU", "vanguard")
	sim.run_weeks(8 * 52)
	var reached := 0
	for nid in sim.state_of("DEU").country.neighbors:
		if sim.state_of(nid).influence > 0.0:
			reached += 1
	assert_gt(reached, 3, "за 8 лет движение приходит к соседям")


func test_step_is_fast_enough() -> void:
	var sim := SimWorld.new_game(data, 1, "CHN")
	sim.run_weeks(520)
	var t0 := Time.get_ticks_usec()
	sim.run_weeks(104)
	var ms := (Time.get_ticks_usec() - t0) / 1000.0 / 104.0
	gut.p("шаг симуляции: %.3f мс" % ms)
	assert_lt(ms, 5.0, "шаг на 180 стран не дольше 5 мс")


func test_bot_finishes_a_game() -> void:
	var sim := SimWorld.new_game(data, 2024, "EGY", "peoples_war")
	while not sim.is_over():
		BotPlayer.play_week(sim)
		sim.step()
	assert_has([SimWorld.OUTCOME_FEDERATION, SimWorld.OUTCOME_WORLD_REVOLUTION, SimWorld.OUTCOME_TWO_SYSTEMS,
		SimWorld.OUTCOME_DEFEAT], sim.outcome)
	assert_lte(sim.week, 20 * 52, "партия длится не дольше 20 лет")
	assert_gt(sim.revolutionary_count(), 0, "бот совершает хотя бы одну революцию")
	assert_false(sim.chronicle.is_empty(), "у партии есть хроника")
	assert_gt(int(sim.score()["total"]), 0)


func test_protests_flare_by_themselves_and_are_suppressed_without_support() -> void:
	var sim := SimWorld.new_game(data, 4)
	sim.run_weeks(5 * 52)
	assert_gt(sim.protests_suppressed, 5, "без партии стихийные протесты вспыхивают и подавляются")
	assert_eq(sim.protests_supported, 0)
	var flared := 0
	for item in sim.news:
		if str(item["key"]).begins_with("NEWS_UNREST_"):
			flared += 1
	assert_gt(flared, 0, "о протестах пишут в новостях")


func test_supporting_a_protest_gives_a_foothold() -> void:
	var sim := SimWorld.new_game(data, 4, "FRA", "councils")
	var bra := sim.state_of("BRA")
	assert_eq(bra.influence, 0.0)
	bra.unrest = 30.0
	sim.add_bubble(UnrestSystem.PROTEST, "BRA", 8, 1.0)
	var id := int(sim.bubbles[-1]["id"])
	var before := sim.solidarity
	var result := sim.collect_bubble(id)
	assert_true(result["ok"])
	assert_gt(sim.solidarity, before, "пузырёк даёт солидарность")
	assert_gt(bra.influence, 0.0, "поддержка закрепляет движение в стране")
	assert_gt(bra.cadres, 0.0, "и даёт кадры")
	assert_false(sim.collect_bubble(id)["ok"], "пузырёк собирается один раз")


func test_unsupported_protest_bubble_expires_into_repression() -> void:
	var sim := SimWorld.new_game(data, 4, "FRA")
	var nga := sim.state_of("NGA")
	nga.unrest = 30.0
	var repression := nga.repression
	sim.add_bubble(UnrestSystem.PROTEST, "NGA", 1, 1.0)
	sim.week += 1
	UnrestSystem.expire(sim)
	assert_false(UnrestSystem.has_bubble(sim, "NGA", UnrestSystem.PROTEST))
	assert_gt(nga.repression, repression, "власть подавила протест")
	assert_lt(nga.unrest, 30.0)


func test_solidarity_bubbles_appear_where_the_movement_is() -> void:
	var sim := SimWorld.new_game(data, 6, "IND", "mass_party")
	sim.state_of("IND").influence = 20.0
	var found := false
	for i in 200:
		sim.step()
		for b in sim.bubbles:
			if b["kind"] == UnrestSystem.SOLIDARITY:
				found = true
				assert_gt(sim.state_of(b["country"]).influence, 0.0, "солидарность — там, где есть движение")
	assert_true(found, "пузырьки солидарности появляются")


func test_cadres_grow_from_organization_up_to_cap() -> void:
	var sim := SimWorld.new_game(data, 2, "DEU", "vanguard")
	var deu := sim.state_of("DEU")
	deu.organization = 40.0
	deu.influence = 10.0
	deu.cadres = 0.0
	sim.run_weeks(52)
	assert_gt(deu.cadres, 0.5, "кадры растут из организованности")
	assert_lte(deu.cadres, deu.cadre_cap(sim) + 0.001)


func test_send_organizers_turns_solidarity_into_cadres_anywhere() -> void:
	var sim := SimWorld.new_game(data, 2, "DEU")
	var chl := sim.state_of("CHL")
	assert_eq(chl.influence, 0.0)
	sim.solidarity = 3.0
	assert_has(PlayerActions.action_blockers(sim, "send_organizers", chl), "cost")
	sim.solidarity = 10.0
	var result := PlayerActions.perform(sim, "send_organizers", chl)
	assert_true(result["ok"])
	assert_almost_eq(sim.solidarity, 4.0, 0.001)
	assert_gte(chl.cadres, 3.0)
	assert_gt(chl.influence, 0.0, "организаторы закладывают движение")


func test_lines_change_rules() -> void:
	var syn := SimWorld.new_game(data, 3, "FRA", "syndicalism")
	var fra := syn.state_of("FRA")
	fra.influence = 10.0
	assert_has(PlayerActions.action_blockers(syn, "elections", fra), "line", "у синдикалистов нет выборов")
	assert_lt(int(PlayerActions.action_cost(syn, "general_strike")["cadres"]), int(data.country_actions["general_strike"]["cadres"]),
		"всеобщая стачка дешевле")
	var councils := SimWorld.new_game(data, 3, "FRA", "councils")
	assert_eq(PlayerActions.upgrade_requires(councils, "workers_councils"), PackedStringArray(["trade_unions"]),
		"у советов рабочие советы — без партии")
	var vanguard := SimWorld.new_game(data, 3, "FRA", "vanguard")
	assert_lt(vanguard.mod("visibility"), 0.0, "авангард незаметнее")


func test_lines_play_differently() -> void:
	# Народная война сильна на периферии, массовая партия — в ядре.
	var shares := {}
	for line in ["peoples_war", "mass_party"]:
		var sim := SimWorld.new_game(data, 77, "IND", line)
		for i in 6 * 52:
			BotPlayer.play_week(sim)
			sim.step()
		var periphery := 0.0
		var core := 0.0
		for cs in sim.countries:
			var v := 100.0 if cs.is_revolutionary() else cs.influence
			if cs.is_periphery:
				periphery += v
			elif cs.is_core:
				core += v
		shares[line] = periphery / maxf(periphery + core, 1.0)
	assert_gt(shares["peoples_war"], shares["mass_party"], "у народной войны доля периферии выше")


func test_line_change_once_halves_organization() -> void:
	var sim := SimWorld.new_game(data, 5, "FRA", "vanguard")
	var fra := sim.state_of("FRA")
	fra.organization = 40.0
	assert_true(sim.change_line("mass_party"))
	assert_eq(sim.line, "mass_party")
	assert_almost_eq(fra.organization, 20.0, 0.001)
	assert_false(sim.change_line("councils"), "второй раз сменить нельзя")
	assert_eq(sim.line, "mass_party")


func test_save_keeps_bubbles_line_and_chronicle() -> void:
	var sim := SimWorld.new_game(data, 12, "BRA", "peoples_war")
	for i in 150:
		sim.step()
	sim.add_bubble(UnrestSystem.SOLIDARITY, "BRA", 5, 3.0)
	var loaded := SimWorld.from_dict(data, JSON.parse_string(JSON.stringify(sim.to_dict(), "", true, true)))
	assert_eq(loaded.line, "peoples_war")
	assert_eq(loaded.bubbles.size(), sim.bubbles.size())
	assert_eq(loaded.chronicle.size(), sim.chronicle.size())
	assert_eq(loaded.next_bubble_id, sim.next_bubble_id)
	assert_eq(_same_state(_plain(sim), _plain(loaded)), "")
