class_name BattleSystem
extends RefCounted
## Местное сражение: начало, день боя, действия игрока, ход власти и итог.
## Числа — в data/battle.json, доступны через data.num("battle.…").


# --- Начало ------------------------------------------------------------------

## Начать сражение в стране. penalty (0–1) — насколько слабее старт (стихийное восстание без подготовки);
## agitators — сколько кадров ушло руководить восстанием (−1 — все кадры страны).
static func start(sim: SimWorld, cs: CountryState, penalty: float = 0.0, agitators: int = -1) -> BattleState:
	var d := sim.data
	var map := BattleMaps.country(cs.country.id)
	if map.is_empty():
		return null
	var b := BattleState.new()
	b.country_id = cs.country.id
	b.map = map
	b.line = sim.line
	b.rng.seed = sim.rng.randi()
	var weeks := maxi(cs.window_left, 0)
	b.max_days = clampi(weeks * int(d.num("battle.time.days_per_window_week")), int(d.num("battle.time.min_days")),
		int(d.num("battle.time.max_days")))
	var regions: Array = map["regions"]
	var n := regions.size()
	var total_pop := 0.0
	for r: Dictionary in regions:
		total_pop += float(r.get("population", 1.0))
	var line_cfg: Dictionary = d.battle.get("lines", {}).get(sim.line, {})
	var p := "battle.start."
	# Поддержка в регионах: от влияния движения в стране, больше в городах.
	for i in n:
		var r: Dictionary = regions[i]
		var share := float(r.get("population", 1.0)) / maxf(total_pop, 1.0)
		var urban := float(r.get("urban", 0.3))
		var s := d.num(p + "support_base") + cs.influence * d.num(p + "support_per_influence") + urban * d.num(p + "support_urban") \
			+ cs.rev_situation * d.num(p + "support_rev_situation") + b.rng.randf_range(-6.0, 6.0)
		if "agrarian" in r.get("objects", []):
			s += float(line_cfg.get("agrarian_support", 0.0))
		if urban >= 0.4:
			s += float(line_cfg.get("urban_support", 0.0))
		s *= 1.0 - 0.4 * penalty
		b.support.append(clampf(s, d.num(p + "support_min"), d.num(p + "support_max")))
		b.control.append(BattleState.CONTESTED if b.support[i] >= d.num(p + "contested_support") else BattleState.POWER)
		b.pop_share.append(share)
		b.squads.append(float(line_cfg.get("agrarian_squads", 0.0)) if "agrarian" in r.get("objects", []) else 0.0)
		b.barricades.append(0)
		b.strike_days.append(0)
		b.council.append(false)
		b.neutral.append(false)
		b.defected.append(false)
	# Армия и полиция: гарнизоны по населению, столица сильнее, часть армии — в резерве.
	var army := d.num(p + "army_base") + d.num(p + "army_per_loyalty") * cs.army_loyalty
	b.reserve = army * d.num(p + "reserve_share")
	var spread := army - b.reserve
	var weights := PackedFloat64Array()
	var wsum := 0.0
	for i in n:
		var w := sqrt(b.pop_share[i]) + (d.num(p + "capital_garrison") if "capital" in regions[i].get("objects", []) else 0.0)
		weights.append(w)
		wsum += w
	var police_total := cs.repression * d.num(p + "police_per_repression")
	var loyalty0 := cs.army_loyalty - (sim.mod("army_erosion") if sim.upgrades.has("antiwar_network") else 0.0)
	b.reserve_loyalty = clampf(loyalty0 + d.num(p + "reserve_loyalty_bonus"), 0.0, 100.0)
	for i in n:
		b.gov.append(spread * weights[i] / wsum)
		b.police.append(police_total * weights[i] / wsum)
		b.loyalty.append(clampf(loyalty0 + b.rng.randf_range(-1.0, 1.0) * d.num(p + "loyalty_noise"), 0.0, 100.0))
	# Ресурсы движения.
	var squads := d.num(p + "squads_base") + cs.organization * d.num(p + "squads_per_organization") \
		+ cs.influence * d.num(p + "squads_per_influence")
	squads *= float(line_cfg.get("squads_mult", 1.0)) * (1.3 if sim.upgrades.has("self_defense") else 1.0) * (1.0 - 0.4 * penalty)
	b.squads_pool = roundf(squads)
	var sent := roundi(cs.cadres) if agitators < 0 else agitators
	b.agitators = maxi(sent, int(d.num(p + "agitators_min"))) + (3 if sim.upgrades.has("cadre_school") else 0)
	b.supplies = d.num(p + "supplies") + cs.organization * 0.5
	b.weapons = d.num(p + "weapons") + (10.0 if cs.has_flag("workers_control") else 0.0)
	b.trust = cs.trust
	b.add_log("BATTLE_LOG_START", [cs.country.name_ru])
	return b


# --- День --------------------------------------------------------------------

static func step_day(sim: SimWorld, b: BattleState) -> void:
	if b.is_over():
		return
	var d := sim.data
	b.day += 1
	var q := "battle.daily."
	var n := b.region_count()
	var line_cfg: Dictionary = d.battle.get("lines", {}).get(b.line, {})
	# Снабжение: советы и порт дают, отряды едят.
	var income := 0.0
	for i in n:
		if b.council[i]:
			income += d.num(q + "council_supplies") * float(line_cfg.get("council_supplies_mult", 1.0))
	if b.seized.has("port"):
		income += d.num(q + "port_supplies")
	if b.land_reform:
		income += float(d.battle_actions["land_to_peasants"].get("supplies_per_day", 0.0))
	b.supplies += income - b.squads_total() * d.num(q + "squad_upkeep")
	b.hungry = b.supplies < 0.0
	if b.hungry:
		b.supplies = 0.0
	# Агитаторы возвращаются с заданий.
	var k := 0
	while k < b.busy.size():
		if int(b.busy[k]["back"]) <= b.day:
			b.agitators += int(b.busy[k]["n"])
			b.busy.remove_at(k)
		else:
			k += 1
	if b.leadership_arrested and b.day >= b.leadership_back:
		b.leadership_arrested = false
		b.add_log("BATTLE_LOG_LEADERSHIP_BACK")
	# Новые агитаторы: из рабочих районов и из советов.
	if not b.leadership_arrested and b.day % int(d.num(q + "agitator_regen_days")) == 0:
		var councils := 0
		for i in n:
			if b.council[i]:
				councils += 1
		b.agitators += 1 + int(councils * d.num(q + "agitators_per_council"))
	var curfew := b.day < b.curfew_until
	var wmult := 0.5 + minf(b.weapons, 100.0) / 100.0
	var coord := d.num("battle.ai.comms_coordination_mult") if b.seized.has("comms") else 1.0
	for i in n:
		_region_day(sim, b, i, wmult, coord, curfew, line_cfg)
	BattleAI.act(sim, b)
	# Доверие масс: реквизиции при голоде, самоуправство отрядов.
	if b.hungry:
		b.trust -= d.num(q + "requisition_trust_loss")
	if b.squads_total() > 20.0 and b.trust < 50.0 and b.rng.randf() < d.num(q + "excess_chance"):
		b.trust -= d.num(q + "excess_trust")
		b.add_log("BATTLE_LOG_EXCESS")
	b.trust = clampf(b.trust, 0.0, 100.0)
	check_outcome(sim, b)


static func _region_day(sim: SimWorld, b: BattleState, i: int, wmult: float, coord: float, curfew: bool,
		line_cfg: Dictionary) -> void:
	var d := sim.data
	var q := "battle.daily."
	var revolution_neighbors := 0
	for nb: int in b.region(i)["neighbors"]:
		if b.control[nb] == BattleState.REVOLUTION:
			revolution_neighbors += 1
	# Поддержка.
	var ds := 0.0
	match b.control[i]:
		BattleState.REVOLUTION:
			ds += 0.3
		BattleState.POWER:
			ds -= d.num(q + "support_decay_power") * (2.0 if curfew else 1.0)
	ds += d.num(q + "support_from_revolution_neighbors") * revolution_neighbors
	if b.strike_days[i] > 0:
		b.strike_days[i] -= 1
		var strike: Dictionary = d.battle_actions["strike"]
		var mult := float(line_cfg.get("strike_mult", 1.0))
		ds += float(strike["support_per_day"]) * mult * (0.5 if curfew else 1.0)
		b.gov[i] = maxf(b.gov[i] - b.gov[i] * float(strike["garrison_loss"]) * mult, 0.0)
	if b.trust < d.num(q + "low_trust"):
		ds -= d.num(q + "low_trust_support_loss")
	b.support[i] = clampf(b.support[i] + ds, 0.0, 100.0)
	# Солдаты — из народа: там, где поддержка высока, верность гарнизона тает.
	var from := d.num(q + "loyalty_support_from")
	if b.support[i] > from:
		b.loyalty[i] = maxf(b.loyalty[i] - d.num(q + "loyalty_from_support") * (b.support[i] - from) / (100.0 - from), 0.0)
	# Бой.
	# Вооружённые рабочие района встают рядом с отрядами или по зову совета.
	var organized := b.squads[i] > 0.0 or b.council[i]
	var armed := d.num(q + "armed_workers") * b.support[i] / 100.0 \
		if organized and b.control[i] != BattleState.POWER and b.support[i] >= 50.0 else 0.0
	var rev := b.squads[i] * wmult * (1.0 + d.num(q + "barricade_defense") * b.barricades[i]) + armed
	var garrison := b.gov[i] * (0.4 + 0.6 * b.loyalty[i] / 100.0) * coord * (0.5 if b.neutral[i] else 1.0)
	var power := garrison + b.police[i]
	if rev > 0.0 and power > 0.0:
		var rate := d.num(q + "combat_rate")
		var hit := rev * rate
		var share := garrison / power
		b.gov[i] = maxf(b.gov[i] - hit * share, 0.0)
		b.police[i] = maxf(b.police[i] - hit * (1.0 - share), 0.0)
		b.squads[i] = maxf(b.squads[i] - power * rate, 0.0)
		if b.support[i] > 50.0:
			b.trust -= d.num(q + "civilian_trust_loss") * power / 10.0
		if b.squads[i] < 0.05:
			b.squads[i] = 0.0
	# Переход гарнизона на сторону революции: часть солдат уходит с оружием.
	if not b.defected[i] and b.loyalty[i] < d.num(q + "defect_loyalty") and b.gov[i] > 1.0:
		var defect := b.gov[i] * d.num(q + "defect_share")
		b.gov[i] -= defect
		b.squads[i] += defect
		b.defected_strength += defect
		b.defected[i] = true
		# Пример заразителен: верность падает во всей армии.
		for j in b.region_count():
			if j != i:
				b.loyalty[j] = maxf(b.loyalty[j] - d.num(q + "defect_example"), 0.0)
		b.add_log("BATTLE_LOG_DEFECT", [b.region(i)["name_ru"]])
	# Кто держит регион.
	var power_left := b.gov[i] + b.police[i]
	var ours := b.squads[i] > 0.0 or armed > 0.0
	var before := b.control[i]
	if power_left <= d.num(q + "take_region_garrison") and ours:
		b.control[i] = BattleState.REVOLUTION
	elif b.squads[i] <= 0.0 and armed <= 0.0 and before != BattleState.POWER and power_left > d.num(q + "take_region_garrison"):
		b.control[i] = BattleState.POWER
	elif ours and power_left > 0.0:
		b.control[i] = BattleState.CONTESTED
	if b.control[i] != before:
		_on_control_change(sim, b, i, before)
	# Пополнение отрядов в освобождённых регионах и там, где есть совет.
	if b.control[i] == BattleState.REVOLUTION or b.council[i]:
		var mult := float(line_cfg.get("agrarian_recruit_mult", 1.0)) if b.has_object(i, "agrarian") else 1.0
		if b.control[i] != BattleState.REVOLUTION:
			mult *= d.num(q + "council_recruit_mult")
		b.squads_pool += d.num(q + "recruit_rate") * b.support[i] / 100.0 * sqrt(b.pop_share[i] * 100.0) * mult


static func _on_control_change(sim: SimWorld, b: BattleState, i: int, before: int) -> void:
	var d := sim.data
	var name: String = b.region(i)["name_ru"]
	if b.control[i] == BattleState.REVOLUTION:
		for object in ["comms", "railway", "arsenal", "port"]:
			if b.has_object(i, object) and not b.seized.has(object):
				_seize(sim, b, object)
		b.add_log("BATTLE_LOG_TAKEN", [name])
		for j in b.region_count():
			b.loyalty[j] = maxf(b.loyalty[j] - 1.0, 0.0)
	elif b.control[i] == BattleState.POWER:
		if b.barricades[i] > 0:
			b.squads_pool = maxf(b.squads_pool * (1.0 - d.num("battle.daily.fallen_barricade_loss") * 0.2), 0.0)
		b.barricades[i] = 0
		b.council[i] = false
		b.add_log("BATTLE_LOG_LOST", [name])
		for j in b.region_count():
			b.loyalty[j] = minf(b.loyalty[j] + d.num("battle.daily.loyalty_victory"), 100.0)


## Объект в руках революции.
static func _seize(sim: SimWorld, b: BattleState, object: String) -> void:
	b.seized[object] = true
	match object:
		"comms":
			if not b.appeal_done:
				b.appeal_done = true
				var add := float(sim.data.battle_actions["seize_comms"].get("appeal_support", 10.0))
				for j in b.region_count():
					b.support[j] = minf(b.support[j] + add, 100.0)
		"arsenal":
			b.weapons += float(sim.data.battle_actions["seize_arsenal"].get("weapons", 40.0))
	b.add_log("BATTLE_LOG_SEIZED_" + object)


# --- Итог --------------------------------------------------------------------

static func check_outcome(sim: SimWorld, b: BattleState) -> void:
	if b.is_over():
		return
	var d := sim.data
	var cap := b.capital()
	if b.army_loyalty() < d.num("battle.daily.army_defects_loyalty"):
		b.army_defected = true
		_finish(b, BattleState.OUTCOME_VICTORY, "army")
		return
	if b.control[cap] == BattleState.REVOLUTION and b.factory_share() >= d.num("battle.outcome.factory_share"):
		_finish(b, BattleState.OUTCOME_VICTORY, "capital")
		return
	if b.leadership_arrested and b.support[cap] < d.num("battle.outcome.capital_support_defeat"):
		_finish(b, BattleState.OUTCOME_DEFEAT, "leadership")
		return
	var alive := b.squads_total() > 0.5
	for i in b.region_count():
		if b.control[i] != BattleState.POWER:
			alive = true
	if not alive:
		_finish(b, BattleState.OUTCOME_DEFEAT, "crushed")
		return
	if b.day >= b.max_days:
		var share := b.control_share()
		# В гражданской войне перевес решает: большая часть страны — победа, меньшая часть — разгром.
		if b.rounds > 0 and share >= d.num("battle.outcome.civil_war_max"):
			_finish(b, BattleState.OUTCOME_VICTORY, "civil_war")
		elif share >= d.num("battle.outcome.civil_war_min"):
			_finish(b, BattleState.OUTCOME_CIVIL_WAR, "timer")
		else:
			_finish(b, BattleState.OUTCOME_DEFEAT, "timer")


## Новый раунд гражданской войны: бои идут ещё civil_war_round_days дней.
static func begin_round(sim: SimWorld, b: BattleState) -> void:
	b.outcome = BattleState.OUTCOME_NONE
	b.outcome_reason = ""
	b.max_days = b.day + int(sim.data.num("battle.outcome.civil_war_round_days"))
	b.add_log("BATTLE_LOG_ROUND", [b.rounds + 1])


static func _finish(b: BattleState, result: String, reason: String) -> void:
	b.outcome = result
	b.outcome_reason = reason
	b.add_log("BATTLE_LOG_OUTCOME_" + result + "_" + reason)


# --- Действия игрока ---------------------------------------------------------

## Цена действия с поправкой линии.
static func cost(sim: SimWorld, b: BattleState, id: String) -> Dictionary:
	var a: Dictionary = sim.data.battle_actions[id]
	var c: Dictionary = a.get("cost", {}).duplicate()
	if id == "strike" and c.has("supplies"):
		var line_cfg: Dictionary = sim.data.battle.get("lines", {}).get(b.line, {})
		c["supplies"] = roundf(float(c["supplies"]) * float(line_cfg.get("strike_cost_mult", 1.0)))
	return c


## Почему действие в регионе недоступно (region = −1 для общих действий).
static func blockers(sim: SimWorld, b: BattleState, id: String, i: int) -> PackedStringArray:
	var out := PackedStringArray()
	var a: Dictionary = sim.data.battle_actions.get(id, {})
	if a.is_empty() or b.is_over():
		out.append("unknown")
		return out
	var key := BattleState.cooldown_key(id, -1 if a.get("target", "any") == "global" else i)
	if b.cooldowns.get(key, 0) > b.day:
		out.append("cooldown:%d" % (b.cooldowns[key] - b.day))
	var c := cost(sim, b, id)
	if b.agitators < int(c.get("agitators", 0)):
		out.append("agitators")
	if b.supplies < float(c.get("supplies", 0.0)):
		out.append("supplies")
	if sim.solidarity < float(c.get("solidarity", 0.0)):
		out.append("cost")
	var target: String = a.get("target", "any")
	if target != "global":
		if i < 0:
			out.append("region")
			return out
		if c.has("squads") and b.squads[i] < float(c["squads"]):
			out.append("squads:%d" % int(c["squads"]))
		match target:
			"garrison":
				if b.gov[i] <= 1.0 or b.control[i] == BattleState.REVOLUTION:
					out.append("no_garrison")
			"not_power":
				if b.control[i] == BattleState.POWER:
					out.append("not_power")
			"squads":
				if b.squads[i] <= 0.0:
					out.append("no_squads")
		if target.begins_with("object:"):
			var object := target.get_slice(":", 1)
			if not b.has_object(i, object):
				out.append("no_object:" + object)
			elif b.seized.has(object):
				out.append("seized")
	var min_support := float(a.get("min_support", 0.0))
	if id == "council":
		min_support = float(sim.data.battle.get("lines", {}).get(b.line, {}).get("council_support", min_support))
	if i >= 0 and b.support[i] < min_support:
		out.append("battle_support:%d" % int(min_support))
	if a.get("once_per_region", false) and i >= 0 and b.council[i]:
		out.append("done")
	if a.get("once", false) and id == "land_to_peasants" and b.land_reform:
		out.append("done")
	if id == "barricades" and i >= 0 and b.barricades[i] >= int(a.get("max_level", 3)):
		out.append("done")
	return out


## Шанс тайной операции или агитации в гарнизоне (1 — без риска).
static func chance(sim: SimWorld, b: BattleState, id: String, i: int) -> float:
	var a: Dictionary = sim.data.battle_actions[id]
	if not a.has("chance") or i < 0:
		return 1.0
	var p := float(a["chance"])
	match id:
		"garrison_agitation":
			p += (b.support[i] - 50.0) / 200.0 + b.trust / 400.0
			p += float(sim.data.battle.get("lines", {}).get(b.line, {}).get("garrison_chance", 0.0))
		"officers_talks":
			p += (100.0 - b.loyalty[i]) / 250.0 + (0.1 if sim.upgrades.has("counterintelligence") else 0.0)
		_:
			# Захват объекта: чем больше отрядов против охраны, тем вернее.
			var guard := b.police[i] + b.gov[i] * 0.3
			p += (b.squads[i] - guard) / 60.0
	return clampf(p, 0.05, 0.95)


## Провести действие. Возвращает {"ok", "success"}.
static func perform(sim: SimWorld, b: BattleState, id: String, i: int) -> Dictionary:
	if not blockers(sim, b, id, i).is_empty():
		return {"ok": false, "success": false}
	var a: Dictionary = sim.data.battle_actions[id]
	var c := cost(sim, b, id)
	var p := chance(sim, b, id, i)
	var sent := int(c.get("agitators", 0))
	var team := {"n": sent, "back": b.day + int(a.get("busy_days", a.get("cooldown_days", 0)))}
	if sent > 0:
		b.agitators -= sent
		b.busy.append(team)
	b.supplies -= float(c.get("supplies", 0.0))
	if c.has("solidarity"):
		sim.solidarity -= float(c["solidarity"])
		b.solidarity_spent += float(c["solidarity"])
	b.cooldowns[BattleState.cooldown_key(id, -1 if a.get("target", "any") == "global" else i)] = b.day + int(a.get("cooldown_days", 0))
	var success := p >= 1.0 or b.rng.randf() < p
	var name: String = b.region(i)["name_ru"] if i >= 0 else ""
	match id:
		"agitation":
			b.support[i] = minf(b.support[i] + float(a["support"]) * (0.5 + b.trust / 100.0)
				* (0.5 if b.day < b.curfew_until else 1.0), 100.0)
			var risk := float(a["arrest_risk"]) * (0.5 if b.seized.has("comms") else 1.0) * (0.7 if sim.upgrades.has("conspiracy") else 1.0)
			if b.rng.randf() < risk:
				team["n"] = maxi(int(team["n"]) - 1, 0)
				b.add_log("BATTLE_LOG_AGITATOR_ARRESTED", [name])
		"strike":
			b.strike_days[i] = int(a["days"])
		"garrison_agitation":
			if success:
				b.loyalty[i] = maxf(b.loyalty[i] + float(a["loyalty"]), 0.0)
			else:
				b.loyalty[i] = minf(b.loyalty[i] + float(a["fail_loyalty"]), 100.0)
				team["n"] = maxi(int(team["n"]) - 1, 0)
		"council":
			b.council[i] = true
		"barricades":
			b.barricades[i] += 1
		"seize_comms", "seize_railway", "seize_arsenal", "seize_port":
			var object := id.get_slice("_", 1)
			if success:
				_seize(sim, b, object)
			else:
				b.squads[i] = maxf(b.squads[i] - float(c.get("squads", 0.0)), 0.0)
		"land_to_peasants":
			b.land_reform = true
			for j in b.region_count():
				if b.has_object(j, "agrarian"):
					b.support[j] = minf(b.support[j] + float(a["agrarian_support"]), 100.0)
					b.reinforce(j, float(a["volunteers"]) / 3.0, 100.0)
		"officers_talks":
			if success:
				b.neutral[i] = true
				b.loyalty[i] = maxf(b.loyalty[i] + float(a["loyalty"]), 0.0)
			else:
				team["n"] = 0
				if b.rng.randf() < float(a["trap_leadership"]):
					arrest_leadership(sim, b)
		"solidarity_aid":
			b.supplies += float(a["supplies"])
			b.weapons += float(a["weapons"])
	b.add_log("BATTLE_LOG_%s_%s" % [id, "OK" if success else "FAIL"], [name])
	check_outcome(sim, b)
	return {"ok": true, "success": success}


## Арест руководства: половина агитаторов потеряна, новые не приходят, пока не сложится новое руководство.
static func arrest_leadership(sim: SimWorld, b: BattleState) -> void:
	if b.leadership_arrested:
		return
	b.leadership_arrested = true
	b.leadership_back = b.day + int(sim.data.num("battle.ai.leadership_recover_days"))
	b.agitators /= 2
	b.add_log("BATTLE_LOG_LEADERSHIP")


## Отправить отряды из резерва в регион (amount > 0) или отвести обратно (amount < 0).
static func deploy(b: BattleState, i: int, amount: float) -> void:
	if amount > 0.0:
		var n := minf(amount, b.squads_pool)
		b.squads_pool -= n
		b.squads[i] += n
		if b.control[i] == BattleState.POWER and n > 0.0:
			b.control[i] = BattleState.CONTESTED
	else:
		var n := minf(-amount, b.squads[i])
		b.squads[i] -= n
		b.squads_pool += n
