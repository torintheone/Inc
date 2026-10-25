extends GutTest
## Новое общество: изолированная революция заметно бюрократизируется, распространение революции это
## сдерживает; политики меняются раз в год; Термидор гасит помощь движению; контрреволюция;
## события новой власти; сохранение.

var data: GameData


func before_all() -> void:
	data = GameData.load_default()


## Революция во Франции и, если надо, ещё в нескольких странах вне ядра.
func _world(seed: int, line: String, others: int) -> SimWorld:
	var sim := SimWorld.new_game(data, seed, "FRA", line)
	sim.make_revolutionary(sim.state_of("FRA"))
	var added := 0
	for c in sim.countries:
		if added >= others:
			break
		if c.country.id != "FRA" and not c.is_core and c.country.indicator("population") > 2e7:
			sim.make_revolutionary(c)
			added += 1
	return sim


func _years(sim: SimWorld, years: int) -> void:
	for i in years * 52:
		sim.pending_event = {}
		sim.step()


func test_isolated_revolution_bureaucratizes_and_spreading_holds_it_back() -> void:
	for line in ["vanguard", "mass_party"]:
		var alone := _world(801, line, 0)
		var together := _world(801, line, 3)
		_years(alone, 5)
		_years(together, 5)
		var a := alone.state_of("FRA").bureaucracy
		var t := together.state_of("FRA").bureaucracy
		gut.p("%s: бюрократизация в изоляции %.0f, при трёх других революциях %.0f" % [line, a, t])
		assert_gte(a, 55.0, "изолированная революция заметно бюрократизируется (%s)" % line)
		assert_lte(t, a - 20.0, "распространение революции это сдерживает (%s)" % line)


func test_workers_control_holds_back_bureaucracy() -> void:
	var plan := _world(802, "vanguard", 0)
	var councils := _world(802, "vanguard", 0)
	var fra := councils.state_of("FRA")
	fra.policies["economy"] = "workers_control"
	_years(plan, 5)
	_years(councils, 5)
	assert_lt(fra.bureaucracy, plan.state_of("FRA").bureaucracy - 15.0, "рабочий контроль сдерживает аппарат")
	assert_gt(plan.state_of("FRA").production, fra.production, "но план быстрее растит производство")


func test_policy_changes_once_a_year() -> void:
	var sim := _world(803, "vanguard", 0)
	var fra := sim.state_of("FRA")
	assert_true(NewSociety.set_policy(sim, fra, "economy", "mixed"), "первую смену можно сразу")
	assert_false(NewSociety.set_policy(sim, fra, "economy", "workers_control"), "вторую — не раньше чем через год")
	assert_eq(NewSociety.weeks_to_change(sim, fra, "economy"), 52)
	assert_true(NewSociety.set_policy(sim, fra, "village", "market"), "другие политики — независимо")
	sim.run_weeks(52)
	assert_true(NewSociety.set_policy(sim, fra, "economy", "workers_control"), "через год — можно")


func test_thermidor_stops_help_to_the_movement() -> void:
	var sim := _world(804, "vanguard", 0)
	var fra := sim.state_of("FRA")
	var before := sim.weekly_income()
	# Изоляция, план, война, культ вождя и «твёрдая рука» вместе толкают аппарат за 100.
	fra.bureaucracy = 99.5
	fra.flags["leader_cult"] = true
	fra.timed["firm_hand"] = sim.week + 200
	sim.reaction = 70.0
	assert_gt(NewSociety.bureaucracy_target(sim, fra), 100.0)
	for i in 104:
		sim.reaction = 70.0
		sim.pending_event = {}
		sim.step()
		if NewSociety.is_thermidor(fra):
			break
	assert_true(NewSociety.is_thermidor(fra), "на 100 — Термидор")
	assert_true(fra.is_revolutionary(), "страна остаётся революционной")
	assert_eq(NewSociety.spread_mult(sim, fra), 0.0, "её пример больше не вдохновляет")
	assert_lt(sim.weekly_income(), before, "и солидарности она не даёт")


func test_counterrevolution_when_support_low_during_intervention() -> void:
	var sim := _world(805, "vanguard", 0)
	var fra := sim.state_of("FRA")
	sim.reaction = 70.0
	var fell := false
	for i in 400:
		fra.support = 5.0
		fra.defense = 0.0
		sim.reaction = 70.0
		sim.pending_event = {}
		sim.step()
		if not fra.is_revolutionary():
			fell = true
			break
	assert_true(fell, "при низкой поддержке и интервенции страна может пасть")
	assert_true(fra.has_flag("lessons_of_defeat"))
	assert_true(fra.policies.is_empty())


func test_no_counterrevolution_without_intervention() -> void:
	var sim := _world(806, "vanguard", 0)
	var fra := sim.state_of("FRA")
	sim.reaction = 10.0
	for i in 200:
		fra.support = 5.0
		sim.reaction = 10.0
		sim.pending_event = {}
		sim.step()
	assert_true(fra.is_revolutionary(), "без интервенции низкая поддержка не опрокидывает революцию")


func test_new_power_events_come_in_revolutionary_country() -> void:
	var sim := _world(807, "vanguard", 0)
	var fra := sim.state_of("FRA")
	fra.food = 20.0
	var e: Dictionary = data.events["city_famine"]
	assert_true(EventSystem.country_trigger_ok(sim, e, fra), "голод в городах при продовольствии ниже 30")
	fra.food = 60.0
	assert_false(EventSystem.country_trigger_ok(sim, e, fra))
	assert_true(EventSystem.country_trigger_ok(sim, data.events["plan_error"], fra), "ошибка плана — при плановой экономике")
	fra.policies["economy"] = "mixed"
	assert_false(EventSystem.country_trigger_ok(sim, data.events["plan_error"], fra))
	var cap := sim.state_of("DEU")
	cap.influence = 30.0
	assert_false(EventSystem.country_trigger_ok(sim, e, cap), "в капиталистической стране событий новой власти нет")


func test_firm_hand_raises_bureaucracy() -> void:
	var sim := _world(808, "councils", 0)
	var fra := sim.state_of("FRA")
	var calm := NewSociety.bureaucracy_target(sim, fra)
	sim.pending_event = {"id": "bureaucracy_threat", "country": "FRA", "week": sim.week}
	assert_true(EventSystem.resolve(sim, "firm_hand")["ok"])
	assert_gt(NewSociety.bureaucracy_target(sim, fra), calm + 15.0, "«твёрдая рука» тянет аппарат вверх")


func test_revolutions_help_battles_elsewhere() -> void:
	var sim := _world(809, "vanguard", 2)
	var deu := sim.state_of("DEU")
	deu.influence = 30.0
	deu.organization = 60.0
	var with_allies := BattleSystem.start(sim, deu)
	var alone_sim := SimWorld.new_game(data, 809, "FRA", "vanguard")
	var alone := BattleSystem.start(alone_sim, alone_sim.state_of("DEU"))
	assert_gt(with_allies.supplies, alone.supplies + 10.0, "революционные страны шлют снабжение чужому восстанию")


func test_society_survives_save() -> void:
	var sim := _world(810, "councils", 1)
	_years(sim, 1)
	var fra := sim.state_of("FRA")
	NewSociety.set_policy(sim, fra, "village", "market")
	var copy := SimWorld.from_dict(data, JSON.parse_string(JSON.stringify(sim.to_dict())))
	var c := copy.state_of("FRA")
	assert_almost_eq(c.bureaucracy, fra.bureaucracy, 0.001)
	assert_almost_eq(c.support, fra.support, 0.001)
	assert_eq(c.policies, fra.policies)
	assert_eq(NewSociety.weeks_to_change(copy, c, "village"), NewSociety.weeks_to_change(sim, fra, "village"))
	_years(sim, 1)
	_years(copy, 1)
	assert_almost_eq(copy.state_of("FRA").bureaucracy, sim.state_of("FRA").bureaucracy, 0.001, "после загрузки всё идёт так же")
