class_name EconomySystem
extends RefCounted
## Базис: мировой экономический цикл, экономика стран и империализм —
## перекачка стоимости с периферии в ядро.


## Исходные значения показателей страны из данных Всемирного банка.
static func init_country(sim: SimWorld, cs: CountryState) -> void:
	var c := cs.country
	cs.prepare(sim.data)
	var gini := c.indicator("gini", 35.0)
	var gdp_pc := maxf(c.indicator("gdp_per_capita", 1000.0), 100.0)
	cs.productive_forces = clampf(10.0 + 20.0 * log(gdp_pc / 300.0) / log(10.0), 5.0, 95.0)
	cs.unemployment = clampf(c.indicator("unemployment", 6.0), 0.5, 40.0)
	cs.inequality = clampf((gini - 20.0) * 1.6 + 20.0, 10.0, 95.0)
	cs.real_wage = clampf(55.0 - (gini - 35.0) * 0.5, 25.0, 75.0)
	cs.exploitation = clampf(40.0 + (gini - 35.0) * 0.6 + (10.0 if cs.is_periphery else 0.0), 15.0, 85.0)
	cs.contradiction = clampf(0.45 * cs.inequality + 0.45 * cs.productive_forces - 10.0, 5.0, 90.0)
	cs.hegemony = cs.zone_hegemony
	cs.legitimacy = cs.zone_legitimacy
	cs.repression = cs.zone_repression
	cs.legality = cs.zone_legality
	cs.army_loyalty = cs.zone_army_loyalty
	cs.elite_split = 20.0
	cs.reformism = cs.zone_reformism
	cs.base_unemployment = maxf(cs.unemployment, sim.data.num("economy.min_base_unemployment", 2.0))
	cs.base_real_wage = cs.real_wage
	cs.base_exploitation = cs.exploitation
	cs.base_inequality = cs.inequality
	cs.need = need_of(sim, cs, 0.0)


## Шаг мирового цикла: смена фаз, глубина кризиса, противодействующие тенденции.
static func advance_cycle(sim: SimWorld) -> void:
	sim.phase_week += 1
	if sim.phase_week < sim.phase_lengths[sim.phase_index]:
		return
	sim.phase_week = 0
	sim.phase_index += 1
	if sim.phase_index >= sim.phase_lengths.size():
		start_cycle(sim)
		return
	var phase_id := sim.phase_id()
	if phase_id == "overheat":
		_try_countertendency(sim)
	elif phase_id == "crisis":
		sim.crisis_weeks.append(sim.week)
		sim.add_news("NEWS_CRISIS", [NumberFormat.decimal(sim.depth, 1)], "", true)
		EventSystem.notify(sim, "crisis_start", null)
	else:
		sim.add_news("NEWS_PHASE_" + phase_id, [])


## Новый цикл: длина 5–7 лет, глубина следующего кризиса растёт.
static func start_cycle(sim: SimWorld) -> void:
	var d := sim.data
	sim.cycle_number += 1
	sim.phase_index = 0
	sim.phase_week = 0
	sim.countertendency_used = false
	var length := sim.rng.randi_range(int(d.num("cycle.min_weeks")), int(d.num("cycle.max_weeks")))
	sim.cycle_length = length
	sim.phase_lengths = _phase_lengths(sim, length)
	if sim.cycle_number == 1:
		sim.depth = d.num("cycle.first_depth", 1.0)
	else:
		var core_k := 0.0
		var core_n := 0
		for cs in sim.countries:
			if cs.is_core and not cs.is_revolutionary():
				core_k += cs.contradiction
				core_n += 1
		core_k = core_k / maxf(core_n, 1)
		if sim.initial_core_contradiction < 0.0:
			sim.initial_core_contradiction = core_k
		var lost := 0.0
		if sim.initial_aristocracy > 0.0:
			lost = clampf(1.0 - sim.core_aristocracy / sim.initial_aristocracy, 0.0, 1.0)
		sim.depth = clampf(sim.depth + d.num("cycle.depth_growth") + d.num("cycle.depth_per_contradiction") * (core_k - sim.initial_core_contradiction)
			+ d.num("cycle.depth_per_lost_superprofit") * lost - sim.depth_relief,
			d.num("cycle.min_depth"), d.num("cycle.max_depth"))
		sim.depth_relief = 0.0
		sim.add_news("NEWS_PHASE_recovery", [])


static func _phase_lengths(sim: SimWorld, length: int) -> PackedInt32Array:
	var phases: Array = sim.data.section("cycle.phases")
	var out := PackedInt32Array()
	var used := 0
	for i in phases.size():
		var w := int(roundf(float(phases[i]["share"]) * length)) if i < phases.size() - 1 else length - used
		w = maxi(w, 1)
		out.append(w)
		used += w
	return out


## Реакция может отодвинуть кризис и смягчить его — ценой роста эксплуатации и урезания зарплат.
static func _try_countertendency(sim: SimWorld) -> void:
	var d := sim.data
	if sim.countertendency_used or sim.reaction < d.num("cycle.countertendency.min_reaction"):
		return
	if sim.rng.randf() >= sim.reaction / 100.0:
		return
	sim.countertendency_used = true
	var room := int(d.num("cycle.max_weeks_with_countertendency")) - sim.cycle_length
	var postpone := mini(int(d.num("cycle.countertendency.postpone_weeks")), maxi(room, 0))
	sim.phase_lengths[sim.phase_index] += postpone
	sim.cycle_length += postpone
	sim.depth_relief += d.num("cycle.countertendency.depth_relief")
	var exploitation := d.num("cycle.countertendency.exploitation")
	var wage_cut := d.num("cycle.countertendency.wage_cut")
	for cs in sim.countries:
		if cs.is_revolutionary():
			continue
		if cs.is_periphery:
			cs.set_field("exploitation", cs.exploitation + exploitation)
		else:
			cs.set_field("real_wage", cs.real_wage - wage_cut)
	sim.add_news("NEWS_COUNTERTENDENCY", [postpone], "", true)


## Перекачка стоимости: периферия отдаёт часть стоимости пропорционально торговле и норме
## эксплуатации, ядро делится сверхприбылью с верхушкой своих рабочих.
static func update_imperialism(sim: SimWorld) -> void:
	var d := sim.data
	# Поддержка освободительных движений урезает поток стоимости с периферии.
	var drain_coef := d.num("imperialism.drain", 1.0) * maxf(1.0 - sim.mod("drain_cut"), 0.0)
	var drain := 0.0
	var core_share := 0.0
	for cs in sim.countries:
		if cs.is_revolutionary():
			continue
		var share := d.gdp_share[cs.index]
		if cs.is_periphery:
			drain += share * cs.exploitation / 100.0 * cs.trade_factor * drain_coef
		elif cs.is_core:
			core_share += share
	var a := 0.0
	if core_share > 0.0:
		a = clampf(drain / core_share * d.num("imperialism.aristocracy"), 0.0, d.num("imperialism.aristocracy_max"))
	sim.core_aristocracy = a
	if sim.initial_aristocracy < 0.0:
		sim.initial_aristocracy = a
	for cs in sim.countries:
		cs.aristocracy = a if cs.is_core and not cs.is_revolutionary() else 0.0


static func is_slump(phase_id: String) -> bool:
	return phase_id == "crisis" or phase_id == "depression"


## Неделя экономики во всех капиталистических странах. Параметры читаются один раз за шаг.
static func update_countries(sim: SimWorld, phase: Dictionary) -> void:
	var d := sim.data
	var slump := is_slump(phase["id"])
	var depth := sim.depth if slump else 1.0
	var ph_unemp := float(phase["unemployment"]) - 1.0
	var ph_wage := float(phase["wage"]) * depth
	var ph_growth := float(phase["growth"]) * depth * 2.5
	var prices := float(phase.get("prices", 0.0))
	var u_speed := d.num("economy.unemployment_speed")
	var swing_cap := d.num("economy.unemployment_swing_cap")
	var w_arist := d.num("economy.wage_per_aristocracy")
	var w_rev := d.num("economy.wage_mean_reversion")
	var x_unemp := d.num("economy.exploitation_per_unemployment")
	var x_org := d.num("economy.exploitation_per_organization")
	var x_crisis := d.num("economy.exploitation_crisis") * depth if slump else 0.0
	var x_speed := d.num("economy.exploitation_speed")
	var q_x := d.num("economy.inequality_per_exploitation")
	var q_speed := d.num("economy.inequality_speed")
	var k_drop := d.num("economy.contradiction_crisis_drop") * depth
	var k_pf := d.num("economy.contradiction_per_forces")
	var k_q := d.num("economy.contradiction_per_inequality")
	var k_speed := d.num("economy.contradiction_speed")
	var need := _need_params(d)
	for cs in sim.countries:
		if cs.is_revolutionary():
			continue
		# Безработица тянется к уровню фазы цикла; размах ограничен: в стране с безработицей 30%
		# кризис не удваивает её до 60%.
		var base_u := cs.base_unemployment
		var target_u := maxf(base_u + ph_unemp * cs.sensitivity * depth * minf(base_u, swing_cap), base_u * 0.3)
		cs.unemployment = clampf(cs.unemployment + (target_u - cs.unemployment) * u_speed, 0.0, 60.0)
		# Реальная зарплата: дрейф по фазе плюс возврат к норме страны (в ядре — выше за счёт сверхприбыли).
		var target_w := cs.base_real_wage + cs.aristocracy * w_arist
		cs.real_wage = clampf(cs.real_wage + ph_wage * cs.sensitivity + (target_w - cs.real_wage) * w_rev, 0.0, 100.0)
		# Производительные силы растут со временем, медленнее у вершины шкалы.
		cs.productive_forces = clampf(cs.productive_forces + ph_growth * cs.zone_growth * (1.0 - cs.productive_forces / 100.0), 0.0, 100.0)
		# Эксплуатация растёт с безработицей и в кризис, падает с организованностью рабочих.
		var target_x := cs.base_exploitation + x_unemp * (cs.unemployment - base_u) - x_org * maxf(cs.organization - 20.0, 0.0) + x_crisis
		cs.exploitation = clampf(cs.exploitation + (target_x - cs.exploitation) * x_speed, 0.0, 100.0)
		var target_q := cs.base_inequality + q_x * (cs.exploitation - cs.base_exploitation)
		cs.inequality = clampf(cs.inequality + (target_q - cs.inequality) * q_speed, 0.0, 100.0)
		# Противоречие копится, пока силы растут при прежних отношениях; кризис разрушает капитал и сбрасывает его.
		if slump:
			cs.contradiction = maxf(cs.contradiction - k_drop, 0.0)
		else:
			var target_k := k_pf * cs.productive_forces + k_q * cs.inequality
			cs.contradiction = clampf(cs.contradiction + (target_k - cs.contradiction) * k_speed, 0.0, 100.0)
		cs.need = _need(need, cs, prices)


## Нужда: низкая зарплата, безработица, эксплуатация, бедность, рост цен.
static func need_of(sim: SimWorld, cs: CountryState, prices: float) -> float:
	return _need(_need_params(sim.data), cs, prices)


static func _need_params(d: GameData) -> PackedFloat64Array:
	return PackedFloat64Array([d.num("economy.need_wage"), d.num("economy.need_unemployment"),
		d.num("economy.need_exploitation"), d.num("economy.need_offset"),
		d.num("economy.need_poverty"), d.num("economy.poverty_forces")])


static func _need(p: PackedFloat64Array, cs: CountryState, prices: float) -> float:
	# Бедность: чем ниже производительные силы, тем тяжелее жизнь при той же «норме» зарплаты.
	var poverty := p[4] * maxf(p[5] - cs.productive_forces, 0.0) / p[5]
	return clampf(p[0] * (100.0 - cs.real_wage) + p[1] * cs.unemployment + p[2] * cs.exploitation + p[3] + poverty + prices,
		0.0, 100.0)
