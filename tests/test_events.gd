extends GutTest
## События: загрузка, разнообразие за партию, цепочка «Фашистская угроза», ответные
## события на действия игрока, недоступные варианты, автоответ и сохранение.

var data: GameData


func before_all() -> void:
	data = GameData.load_default()


func _open(sim: SimWorld, id: String, country: String) -> void:
	sim.pending_event = {"id": id, "country": country, "week": sim.week}
	sim.last_event_week = sim.week


## Шагать, пока не откроется нужное событие; другие события решаются по умолчанию.
func _step_until(sim: SimWorld, id: String, weeks: int) -> bool:
	for i in weeks:
		sim.step()
		if sim.pending_event.is_empty():
			continue
		if sim.pending_event["id"] == id:
			return true
		EventSystem.resolve(sim, EventSystem.default_option(sim))
	return false


func test_events_load() -> void:
	assert_gte(data.event_order.size(), 40, "не меньше 40 событий")
	for id in data.event_order:
		assert_true(TranslationServer.translate("EVENT_" + id) != "EVENT_" + id, "у события %s есть название" % id)


func test_player_sees_15_to_25_different_events_per_game() -> void:
	var setups := [[501, "FRA", "vanguard"], [502, "BRA", "councils"], [503, "IND", "peoples_war"]]
	for s: Array in setups:
		var sim := SimWorld.new_game(data, s[0], s[1], s[2])
		while not sim.is_over():
			BotPlayer.play_week(sim)
			sim.step()
		gut.p("%s: разных событий %d" % [s[1], sim.events_seen.size()])
		assert_between(sim.events_seen.size(), 15, 25, "за партию 15–25 разных событий (%s)" % s[1])


func test_fascist_threat_stops_at_first_step() -> void:
	var sim := SimWorld.new_game(data, 21, "DEU", "vanguard")
	var deu := sim.state_of("DEU")
	deu.influence = 20.0
	deu.cadres = 10.0
	_open(sim, "fascist_squads", "DEU")
	assert_true(EventSystem.resolve(sim, "self_defense", 1)["ok"])
	assert_true(sim.event_queue.is_empty(), "самооборона обрывает цепочку на первом шаге")
	assert_true(deu.active("antifascist", sim.week))


func test_fascist_threat_stops_at_second_step() -> void:
	var sim := SimWorld.new_game(data, 22, "DEU", "syndicalism")
	var deu := sim.state_of("DEU")
	deu.influence = 20.0
	_open(sim, "fascist_squads", "DEU")
	EventSystem.resolve(sim, "ignore")
	assert_eq(sim.event_queue.size(), 1)
	assert_true(_step_until(sim, "power_crisis", 30), "без отпора приходит кризис власти")
	sim.unlocks["general_strike"] = true
	deu.cadres = 10.0
	assert_true(EventSystem.resolve(sim, "general_strike", 1)["ok"])
	assert_true(sim.event_queue.is_empty(), "всеобщая стачка обрывает цепочку на втором шаге")


func test_fascist_threat_ends_in_regime_if_not_stopped() -> void:
	var sim := SimWorld.new_game(data, 23, "ITA", "mass_party")
	var ita := sim.state_of("ITA")
	ita.influence = 25.0
	ita.organization = 50.0
	_open(sim, "fascist_squads", "ITA")
	EventSystem.resolve(sim, "ignore")
	assert_true(_step_until(sim, "power_crisis", 30))
	EventSystem.resolve(sim, "nothing")
	assert_true(_step_until(sim, "fascist_regime", 30), "третий шаг — фашистский режим")
	EventSystem.resolve(sim, "underground")
	assert_true(ita.active("fascist_regime", sim.week))
	assert_gt(ita.repression, 90.0)
	assert_lt(ita.influence, 10.0, "движение почти уничтожено")
	sim.run_weeks(30)
	assert_lt(ita.legality, 20.0, "легальной работы при режиме нет")


func test_failed_strike_can_bring_a_lockout() -> void:
	var d := GameData.load_default()
	d.events["lockout"]["weight"] = 1.0
	var sim := SimWorld.new_game(d, 31, "FRA")
	var fra := sim.state_of("FRA")
	fra.influence = 10.0
	EventSystem.notify(sim, "action_fail:factory_strike", fra)
	assert_eq(sim.pending_event.get("id", ""), "lockout")
	assert_eq(sim.pending_event.get("country", ""), "FRA")


func test_option_needs_its_price() -> void:
	var sim := SimWorld.new_game(data, 32, "FRA")
	sim.state_of("FRA").influence = 10.0
	_open(sim, "lockout", "FRA")
	sim.solidarity = 0.0
	var fund: Dictionary = data.events["lockout"]["options"][0]
	assert_has(EventSystem.option_blockers(sim, fund), "cost")
	assert_false(EventSystem.resolve(sim, "fund")["ok"], "без солидарности стачечный фонд недоступен")
	sim.solidarity = 10.0
	assert_true(EventSystem.resolve(sim, "fund")["ok"])
	assert_lt(sim.solidarity, 10.0, "фонд стоит солидарности")


func test_unanswered_event_takes_default_option() -> void:
	var sim := SimWorld.new_game(data, 33, "BRA")
	sim.state_of("BRA").influence = 5.0
	_open(sim, "migrant_workers", "BRA")
	sim.run_weeks(int(data.num("events.auto_resolve_weeks")) + 1)
	assert_eq(sim.events_seen.get("migrant_workers", 0), 1, "событие решено по умолчанию")
	assert_true(sim.pending_event.is_empty() or sim.pending_event["id"] != "migrant_workers")


func test_events_survive_save_and_load() -> void:
	var sim := SimWorld.new_game(data, 34, "DEU", "vanguard")
	sim.state_of("DEU").influence = 20.0
	_open(sim, "fascist_squads", "DEU")
	EventSystem.resolve(sim, "ignore")
	_open(sim, "migrant_workers", "DEU")
	var loaded := SimWorld.from_dict(data, JSON.parse_string(JSON.stringify(sim.to_dict(), "", true, true)))
	assert_eq(loaded.pending_event, sim.pending_event)
	assert_eq(loaded.event_queue.size(), 1)
	assert_eq(loaded.events_seen, sim.events_seen)
