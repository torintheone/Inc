extends GutTest
## Местные сражения: карты стран, длительность 10–30 минут, два пути к победе (штурм столицы
## и переход армии), бездействие проигрывает, сохранение посреди боя и связь с мировой картой.

const COUNTRIES: PackedStringArray = ["FRA", "DEU", "BRA", "IND", "EGY", "MEX", "RUS", "ZAF", "TUR", "IDN"]

var data: GameData


func before_all() -> void:
	data = GameData.load_default()


## Страна, готовая к восстанию: окно открыто, организованность и влияние достаточные.
func _ready_country(sim: SimWorld, id: String) -> CountryState:
	sim.solidarity = 25.0
	var cs := sim.state_of(id)
	cs.influence = 30.0
	cs.organization = 60.0
	cs.rev_situation = 80.0
	cs.cadres = 12.0
	cs.window_left = 12
	return cs


func _battle(seed: int, id: String, strategy: String, penalty: float = 0.0) -> BattleState:
	var sim := SimWorld.new_game(data, seed, id, "mass_party")
	var b := BattleSystem.start(sim, _ready_country(sim, id), penalty)
	BattleBot.run(sim, b, strategy)
	return b


func test_every_country_has_a_battle_map() -> void:
	for c in data.world.countries:
		var map := BattleMaps.country(c.id)
		assert_false(map.is_empty(), "карта сражения есть у %s" % c.id)
		if map.is_empty():
			continue
		var regions: Array = map["regions"]
		assert_between(regions.size(), 5, 20, "в %s 5–20 регионов" % c.id)
		var capitals := 0
		var factories := 0
		for i in regions.size():
			var r: Dictionary = regions[i]
			if "capital" in r["objects"]:
				capitals += 1
			if "factories" in r["objects"]:
				factories += 1
			for nb: int in r["neighbors"]:
				assert_true(i in Array(regions[nb]["neighbors"]), "соседство взаимно (%s, %d—%d)" % [c.id, i, nb])
		assert_eq(capitals, 1, "одна столица в %s" % c.id)
		assert_gt(factories, 0, "есть промышленный регион в %s" % c.id)


func test_battle_lasts_10_to_30_minutes() -> void:
	var minutes: Array[float] = []
	var seconds := data.num("battle.time.seconds_per_day")
	for id in COUNTRIES:
		for strategy in [BattleBot.STORM, BattleBot.ARMY]:
			var b := _battle(700, id, strategy)
			assert_true(b.is_over(), "сражение в %s закончилось" % id)
			assert_lte(b.day, b.max_days, "не дольше окна революции")
			minutes.append(b.day * seconds / 60.0)
	minutes.sort()
	var median := minutes[minutes.size() / 2]
	gut.p("минут: медиана %.1f, от %.1f до %.1f" % [median, minutes[0], minutes[-1]])
	assert_between(median, 10.0, 30.0, "обычное сражение длится 10–30 минут")
	assert_lte(minutes[-1], 30.0, "и не дольше 30 минут")


func test_two_ways_to_win() -> void:
	var reasons := {}
	var wins := 0
	var games := 0
	for id in COUNTRIES:
		for strategy in [BattleBot.STORM, BattleBot.ARMY]:
			var b := _battle(710, id, strategy)
			games += 1
			if b.outcome == BattleState.OUTCOME_VICTORY:
				wins += 1
				reasons[b.outcome_reason] = reasons.get(b.outcome_reason, 0) + 1
	gut.p("победы: %d из %d, %s" % [wins, games, reasons])
	assert_true(reasons.has("capital"), "побеждают штурмом столицы")
	assert_true(reasons.has("army"), "побеждают переходом армии")
	assert_lt(wins, games, "хорошая подготовка не гарантирует победы")


func test_doing_nothing_loses() -> void:
	for id in COUNTRIES:
		var b := _battle(720, id, BattleBot.IDLE)
		assert_ne(b.outcome, BattleState.OUTCOME_VICTORY, "без действий восстание не побеждает (%s)" % id)


func test_spontaneous_uprising_is_harder() -> void:
	var prepared := 0
	var spontaneous := 0
	for id in COUNTRIES:
		if _battle(730, id, BattleBot.STORM).outcome == BattleState.OUTCOME_VICTORY:
			prepared += 1
		if _battle(730, id, BattleBot.STORM, data.num("battle.start.spontaneous_penalty")).outcome == BattleState.OUTCOME_VICTORY:
			spontaneous += 1
	gut.p("побед: подготовленных %d, стихийных %d" % [prepared, spontaneous])
	assert_lt(spontaneous, prepared, "стихийное восстание без подготовки побеждает реже")


func test_save_mid_battle_continues_identically() -> void:
	var sim := SimWorld.new_game(data, 740, "FRA", "councils")
	var cs := _ready_country(sim, "FRA")
	assert_true(sim.begin_battle(cs, 0.0, 12))
	BattleBot.run(sim, sim.battle, BattleBot.STORM, 20)
	var copy := SimWorld.from_dict(data, JSON.parse_string(JSON.stringify(sim.to_dict())))
	assert_not_null(copy.battle, "сражение сохранилось")
	BattleBot.run(sim, sim.battle, BattleBot.STORM)
	BattleBot.run(copy, copy.battle, BattleBot.STORM)
	assert_eq(copy.battle.day, sim.battle.day, "после загрузки сражение идёт так же")
	assert_eq(copy.battle.outcome, sim.battle.outcome)
	assert_eq(Array(copy.battle.control), Array(sim.battle.control))


func test_uprising_starts_battle_and_pauses_world() -> void:
	var sim := SimWorld.new_game(data, 750, "FRA", "vanguard")
	var cs := _ready_country(sim, "FRA")
	cs.organization = 60.0
	cs.rev_situation = 80.0
	sim.solidarity = 30.0
	assert_true(PlayerActions.action_blockers(sim, "uprising", cs).is_empty(), "восстание доступно")
	var result := PlayerActions.perform(sim, "uprising", cs)
	assert_true(result.get("battle", false), "восстание открывает сражение")
	assert_not_null(sim.battle)
	assert_eq(sim.battle.agitators, 12, "кадры восстания стали агитаторами")
	var week := sim.week
	sim.step()
	assert_eq(sim.week, week, "пока идёт сражение, мир стоит")


func test_victory_makes_country_revolutionary() -> void:
	var sim := SimWorld.new_game(data, 760, "FRA", "vanguard")
	assert_true(sim.begin_battle(_ready_country(sim, "FRA")))
	sim.battle.outcome = BattleState.OUTCOME_VICTORY
	sim.finish_battle()
	assert_null(sim.battle)
	assert_true(sim.state_of("FRA").is_revolutionary())


func test_defeat_brings_lessons_and_white_terror() -> void:
	var sim := SimWorld.new_game(data, 761, "FRA", "vanguard")
	var cs := _ready_country(sim, "FRA")
	assert_true(sim.begin_battle(cs))
	var influence := cs.influence
	sim.battle.outcome = BattleState.OUTCOME_DEFEAT
	sim.finish_battle()
	assert_false(cs.is_revolutionary())
	assert_true(cs.has_flag("lessons_of_defeat"), "«Уроки поражения»")
	assert_almost_eq(cs.influence, influence * 0.3, 0.5, "влияние −70%")


func test_civil_war_goes_on_in_rounds() -> void:
	var sim := SimWorld.new_game(data, 762, "BRA", "vanguard")
	var cs := _ready_country(sim, "BRA")
	assert_true(sim.begin_battle(cs))
	sim.battle.outcome = BattleState.OUTCOME_CIVIL_WAR
	sim.finish_battle()
	assert_true(sim.in_civil_war("BRA"), "страна разделена")
	assert_false(PlayerActions.action_blockers(sim, "uprising", cs).is_empty(), "нового восстания нет, пока идёт война")
	var b: BattleState = sim.civil_wars["BRA"]
	var day := b.day
	var rounds_weeks := int(data.num("battle.outcome.civil_war_round_weeks"))
	for i in rounds_weeks:
		sim.step()
	assert_gt(b.day, day, "раунд рассчитан автоматически")
	# Вернуться на карту страны можно самому.
	if sim.in_civil_war("BRA"):
		assert_true(sim.resume_civil_war("BRA"))
		assert_eq(sim.battle, b)
		BattleBot.run(sim, sim.battle, BattleBot.STORM)
		sim.finish_battle()
		assert_null(sim.battle)


func test_civil_war_ends_after_rounds_limit() -> void:
	var sim := SimWorld.new_game(data, 763, "IND", "vanguard")
	var cs := _ready_country(sim, "IND")
	assert_true(sim.begin_battle(cs))
	var b := sim.battle
	b.outcome = BattleState.OUTCOME_CIVIL_WAR
	b.rounds = int(data.num("battle.outcome.civil_war_max_rounds")) - 1
	sim.finish_battle()
	assert_false(sim.in_civil_war("IND"), "затянувшаяся война решается перевесом сил")
	assert_eq(b.outcome_reason, "exhaustion")


func test_lead_spontaneous_uprising_opens_battle() -> void:
	var sim := SimWorld.new_game(data, 770, "EGY", "syndicalism")
	var cs := sim.state_of("EGY")
	cs.influence = 20.0
	cs.organization = 30.0
	cs.rev_situation = 80.0
	sim.pending_event = {"id": "spontaneous_uprising", "country": "EGY", "week": sim.week}
	assert_true(EventSystem.resolve(sim, "lead")["ok"])
	assert_not_null(sim.battle, "возглавить — значит вступить в сражение")
	assert_eq(sim.battle.country_id, "EGY")
