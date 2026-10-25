class_name NewSociety
extends RefCounted
## Революционная страна после победы: шесть показателей нового общества (рабочая демократия,
## бюрократизация, продовольствие, производство, оборона, поддержка населения) и три политики
## (деревня, экономика, внешняя линия). Каждую неделю показатели тянутся к уровню, который задают
## обстановка и политики. Бюрократизация растёт от изоляции, разрухи, войны, «твёрдой руки» и
## культа вождя; на 100 наступает Термидор. При низкой поддержке и интервенции страна может пасть.
## Числа — в data/society.json, доступны через data.num("society.…").

const POLICIES: PackedStringArray = ["village", "economy", "foreign"]
const THERMIDOR := "thermidor"


## Страна только что победила: стартовые показатели и политики линии движения.
## battle — сражение, которым кончилось восстание (null, если революция пришла иначе).
static func begin(sim: SimWorld, cs: CountryState, battle: BattleState = null) -> void:
	var d := sim.data
	var p := "society.start."
	var line: Dictionary = d.lines.get(sim.line, {}).get("society", {})
	cs.democracy = clampf(d.num(p + "democracy") + float(line.get("democracy", 0.0)), 0.0, 100.0)
	cs.bureaucracy = clampf(d.num(p + "bureaucracy") + float(line.get("bureaucracy", 0.0))
		+ (d.num(p + "leader_cult_bureaucracy") if cs.has_flag("leader_cult") else 0.0), 0.0, 100.0)
	cs.food = clampf(d.num(p + "food") + float(line.get("food", 0.0))
		+ (10.0 if battle != null and battle.land_reform else 0.0), 0.0, 100.0)
	cs.production = cs.productive_forces * d.num(p + "production_ruin")
	cs.defense = d.num(p + "defense") + (d.num(p + "defense_army_victory") if battle != null and battle.army_defected else 0.0)
	var trust := battle.trust if battle != null else cs.trust
	cs.support = clampf(d.num(p + "support_base") + trust * d.num(p + "support_per_trust"), 0.0, 100.0)
	cs.flags.erase(THERMIDOR)
	var defaults: Dictionary = line.get("policies", {})
	cs.policies.clear()
	cs.policy_week.clear()
	for policy in POLICIES:
		var options: PackedStringArray = d.society_options.get(policy, PackedStringArray())
		var chosen := str(defaults.get(policy, options[0] if not options.is_empty() else ""))
		cs.policies[policy] = chosen
		# Первые политики можно сменить сразу: их выбрала линия, а не игрок.
		cs.policy_week[policy] = -100000


# --- Политики ----------------------------------------------------------------

static func option(sim: SimWorld, policy: String, option_id: String) -> Dictionary:
	return sim.data.policy_options.get(policy, {}).get(option_id, {})


## Через сколько недель политику можно сменить (0 — можно сейчас).
static func weeks_to_change(sim: SimWorld, cs: CountryState, policy: String) -> int:
	var last: int = cs.policy_week.get(policy, -100000)
	return maxi(last + int(sim.data.num("society.policy_weeks")) - sim.week, 0)


static func can_change(sim: SimWorld, cs: CountryState, policy: String, option_id: String) -> bool:
	return cs.is_revolutionary() and not option(sim, policy, option_id).is_empty() \
		and cs.policies.get(policy, "") != option_id and weeks_to_change(sim, cs, policy) == 0


static func set_policy(sim: SimWorld, cs: CountryState, policy: String, option_id: String) -> bool:
	if not can_change(sim, cs, policy, option_id):
		return false
	cs.policies[policy] = option_id
	cs.policy_week[policy] = sim.week
	sim.add_news("NEWS_POLICY", [cs.country.name_ru, "POLICY_%s_%s" % [policy, option_id]], cs.country.id)
	return true


## Сумма поправки key по выбранным политикам, действующим отметкам событий и постоянным флагам.
static func effect(sim: SimWorld, cs: CountryState, key: String) -> float:
	var total := 0.0
	for policy: String in cs.policies:
		total += float(option(sim, policy, cs.policies[policy]).get(key, 0.0))
	var timed: Dictionary = sim.data.society.get("timed", {})
	for flag: String in timed:
		if cs.timed.get(flag, -1) > sim.week:
			total += float(timed[flag].get(key, 0.0))
	var flags: Dictionary = sim.data.society.get("flags", {})
	for flag: String in flags:
		if cs.has_flag(flag):
			total += float(flags[flag].get(key, 0.0))
	return total


## Произведение множителя key по выбранным политикам (1 — без поправки).
static func mult(sim: SimWorld, cs: CountryState, key: String) -> float:
	var m := 1.0
	for policy: String in cs.policies:
		m *= float(option(sim, policy, cs.policies[policy]).get(key, 1.0))
	return m


static func has_option_flag(sim: SimWorld, cs: CountryState, key: String) -> bool:
	for policy: String in cs.policies:
		if bool(option(sim, policy, cs.policies[policy]).get(key, false)):
			return true
	return false


# --- Обстановка --------------------------------------------------------------

static func is_thermidor(cs: CountryState) -> bool:
	return cs.has_flag(THERMIDOR)


## Революционные страны, которые ещё помогают движению (без Термидора).
static func living_revolutions(sim: SimWorld) -> int:
	var n := 0
	for other in sim.countries:
		if other.is_revolutionary() and not is_thermidor(other):
			n += 1
	return n


## Изоляция: 1 — страна одна, ½ — есть ещё одна революция, ⅓ — две…
static func isolation(sim: SimWorld, cs: CountryState) -> float:
	var others := living_revolutions(sim) - (0 if is_thermidor(cs) else 1)
	return 1.0 / (1.0 + maxf(others, 0.0))


## Сколько революций победило в других странах за последние два года.
static func recent_revolutions(sim: SimWorld, cs: CountryState) -> int:
	var since := sim.week - int(sim.data.num("society.bureaucracy.recent_weeks"))
	var n := 0
	for other in sim.countries:
		if other != cs and other.is_revolutionary() and other.revolution_week >= since:
			n += 1
	return n


## Интервенция: Реакция от 60 (как в сражениях) или событие «Интервенция».
static func under_intervention(sim: SimWorld, cs: CountryState) -> bool:
	return sim.reaction >= sim.data.num("battle.ai.intervention_reaction") or cs.active("intervention", sim.week)


static func at_war(sim: SimWorld, cs: CountryState) -> bool:
	return under_intervention(sim, cs) or cs.active("blockade", sim.week)


## Рост производства в год: от политик, минус война и голод.
static func growth(sim: SimWorld, cs: CountryState) -> float:
	var d := sim.data
	var g := effect(sim, cs, "growth")
	if at_war(sim, cs):
		g += d.num("society.production.war_growth")
	if cs.food < d.num("society.food.famine"):
		g += d.num("society.food.famine_growth")
	return g


## К какому уровню тянется бюрократизация сейчас (может быть выше 100 — тогда Термидор).
static func bureaucracy_target(sim: SimWorld, cs: CountryState) -> float:
	var d := sim.data
	var q := "society.bureaucracy."
	var ruin := clampf((50.0 - cs.production) / 50.0, 0.0, 1.0)
	var recent := minf(recent_revolutions(sim, cs) * d.num(q + "per_recent_revolution"), d.num(q + "recent_revolution_cap"))
	return d.num(q + "base") + isolation(sim, cs) * d.num(q + "isolation") * mult(sim, cs, "isolation") \
		+ ruin * d.num(q + "ruin") + (d.num(q + "war") if at_war(sim, cs) else 0.0) \
		+ (d.num(q + "leader_cult") if cs.has_flag("leader_cult") else 0.0) + effect(sim, cs, "bureaucracy") \
		- cs.democracy * d.num(q + "per_democracy") - maxf(growth(sim, cs), 0.0) * d.num(q + "per_growth") - recent


# --- Неделя ------------------------------------------------------------------

static func update(sim: SimWorld) -> void:
	for cs in sim.countries:
		if cs.is_revolutionary():
			_update_country(sim, cs)


static func _update_country(sim: SimWorld, cs: CountryState) -> void:
	var d := sim.data
	var sp := "society.speed."
	var war := at_war(sim, cs)
	# Бюрократизация растёт быстро, а спадает вдвое медленнее: аппарат держится за места.
	var b_target := bureaucracy_target(sim, cs)
	var b_speed := d.num(sp + "bureaucracy") * (1.0 if b_target > cs.bureaucracy else d.num(sp + "bureaucracy_down_mult"))
	cs.bureaucracy = clampf(cs.bureaucracy + (b_target - cs.bureaucracy) * b_speed, 0.0, 100.0)
	var dem := d.num("society.democracy.base") + effect(sim, cs, "democracy") \
		- cs.bureaucracy * d.num("society.democracy.per_bureaucracy")
	cs.democracy = clampf(cs.democracy + (dem - cs.democracy) * d.num(sp + "democracy"), 0.0, 100.0)
	var f := "society.food."
	var blockade := cs.active("blockade", sim.week)
	var food := d.num(f + "base") + effect(sim, cs, "food") + (cs.production - 50.0) * d.num(f + "per_production") \
		- (d.num(f + "war") if under_intervention(sim, cs) else 0.0) \
		- (d.num(f + "blockade") * mult(sim, cs, "blockade") if blockade else 0.0)
	cs.food = clampf(cs.food + (food - cs.food) * d.num(sp + "food"), 0.0, 100.0)
	cs.production = clampf(cs.production + growth(sim, cs) / d.num("time.weeks_per_year"), 0.0,
		d.num("society.production.max"))
	var df := "society.defense."
	var defense := d.num(df + "base") + cs.production * d.num(df + "per_production") + cs.support * d.num(df + "per_support") \
		+ effect(sim, cs, "defense")
	cs.defense = clampf(cs.defense + (defense - cs.defense) * d.num(sp + "defense"), 0.0, 100.0)
	var s := "society.support."
	var support := d.num(s + "base") + cs.democracy * d.num(s + "per_democracy") + (cs.food - 50.0) * d.num(s + "per_food") \
		- cs.bureaucracy * d.num(s + "per_bureaucracy") - (d.num(s + "war") if war else 0.0) + effect(sim, cs, "support")
	cs.support = clampf(cs.support + (support - cs.support) * d.num(sp + "support"), 0.0, 100.0)
	var reaction := effect(sim, cs, "reaction")
	if reaction != 0.0 and not is_thermidor(cs):
		ReactionSystem.add(sim, reaction)
	if not is_thermidor(cs) and cs.bureaucracy >= d.num("society.bureaucracy.thermidor") - 0.01:
		cs.flags[THERMIDOR] = true
		sim.add_news("NEWS_THERMIDOR", [cs.country.name_ru], cs.country.id, true)
	_counterrevolution(sim, cs)


## Контрреволюция: при поддержке ниже 30 во время интервенции страна может пасть. Оборона
## и политика деревни меняют шанс; о растущей угрозе игра предупреждает заранее.
static func _counterrevolution(sim: SimWorld, cs: CountryState) -> void:
	var d := sim.data
	var c := "society.counter."
	var warning := d.num(c + "warning_support")
	# Предупреждение повторится, только если поддержка сначала заметно поднимется.
	if cs.support >= warning + 10.0:
		cs.flags.erase("counter_warned")
	if not under_intervention(sim, cs):
		return
	if cs.support < warning and not cs.has_flag("counter_warned"):
		cs.flags["counter_warned"] = true
		sim.add_news("NEWS_COUNTER_THREAT", [cs.country.name_ru], cs.country.id, true)
	var limit := d.num(c + "support_below")
	if cs.support >= limit:
		return
	var p := d.num(c + "chance") * (limit - cs.support) / limit * mult(sim, cs, "counter") \
		* maxf(1.0 - cs.defense / d.num(c + "defense_scale"), 0.0)
	if sim.rng.randf() < p:
		sim.fall_revolution(cs)


# --- Что революционная страна даёт движению ------------------------------------

## Множитель силы примера (канал распространения): Термидор его гасит, поддержка населения усиливает.
static func spread_mult(sim: SimWorld, cs: CountryState) -> float:
	if is_thermidor(cs):
		return 0.0
	var d := sim.data
	return mult(sim, cs, "spread") * (d.num("society.world.spread_support_base") + d.num("society.world.spread_per_support") * cs.support / 100.0)


## Множитель солидарности, которую страна даёт движению.
static func solidarity_mult(sim: SimWorld, cs: CountryState) -> float:
	return 0.0 if is_thermidor(cs) else mult(sim, cs, "solidarity")


## Сколько революционных стран помогают чужим сражениям (политика «Поддержка революций»).
static func battle_allies(sim: SimWorld) -> int:
	var n := 0
	for cs in sim.countries:
		if cs.is_revolutionary() and not is_thermidor(cs) and has_option_flag(sim, cs, "battle_aid"):
			n += 1
	return mini(n, int(sim.data.num("society.world.battle_allies_max")))
