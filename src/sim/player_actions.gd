class_name PlayerActions
extends RefCounted
## Улучшения движения и действия в стране (описания — в data/actions.json, линии — в
## data/lines.json): можно ли их сделать, сколько они стоят, с каким шансом удаются
## и что из этого выходит. Улучшения покупаются за солидарность, действия — за кадры страны.


## Какие улучшения нужны раньше этого (с учётом линии: у советов свой путь к рабочим советам).
static func upgrade_requires(sim: SimWorld, id: String) -> PackedStringArray:
	var line: Dictionary = sim.data.lines.get(sim.line, {})
	var override: Dictionary = line.get("requires_override", {})
	if override.has(id):
		return PackedStringArray(override[id])
	return PackedStringArray(sim.data.upgrades.get(id, {}).get("requires", []))


## Цена улучшения сейчас: каждое уже купленное улучшение делает остальные дороже
## (как в Plague Inc), чтобы солидарность ценилась до конца партии.
static func upgrade_cost(sim: SimWorld, id: String) -> int:
	var base := float(sim.data.upgrades.get(id, {}).get("cost", 0))
	return int(ceilf(base * (1.0 + sim.data.num("solidarity.upgrade_escalation") * sim.upgrades.size()) - 0.001))


## Почему улучшение нельзя купить. Пустой список — можно.
static func upgrade_blockers(sim: SimWorld, id: String) -> PackedStringArray:
	var out := PackedStringArray()
	var u: Dictionary = sim.data.upgrades.get(id, {})
	if u.is_empty():
		out.append("unknown")
		return out
	if sim.upgrades.has(id):
		out.append("owned")
		return out
	for req in upgrade_requires(sim, id):
		if not sim.upgrades.has(req):
			out.append("requires:" + req)
	if sim.solidarity < float(upgrade_cost(sim, id)):
		out.append("cost")
	return out


static func buy_upgrade(sim: SimWorld, id: String) -> bool:
	if not upgrade_blockers(sim, id).is_empty():
		return false
	var u: Dictionary = sim.data.upgrades[id]
	sim.solidarity -= float(upgrade_cost(sim, id))
	sim.upgrades[id] = true
	recompute_mods(sim)
	var on_buy: Dictionary = u.get("on_buy", {})
	if on_buy.has("reaction"):
		ReactionSystem.add(sim, float(on_buy["reaction"]))
	sim.add_news("NEWS_UPGRADE", ["UPGRADE_" + id])
	return true


## Сумма модификаторов линии и всех купленных улучшений и список открытых возможностей.
static func recompute_mods(sim: SimWorld) -> void:
	sim.mods.clear()
	sim.unlocks.clear()
	var line: Dictionary = sim.data.lines.get(sim.line, {})
	_add_mods(sim, line.get("modifiers", {}))
	for id in sim.data.upgrade_order:
		if not sim.upgrades.has(id):
			continue
		var u: Dictionary = sim.data.upgrades[id]
		_add_mods(sim, u.get("modifiers", {}))
		for unlock: String in u.get("unlocks", []):
			sim.unlocks[unlock] = true


static func _add_mods(sim: SimWorld, mods: Dictionary) -> void:
	for key: String in mods:
		sim.mods[key] = sim.mods.get(key, 0.0) + float(mods[key])


## Цена действия: {"cadres": int, "solidarity": int}. Школа кадров и линия её снижают,
## чрезвычайное положение в стране — повышает в полтора раза.
static func action_cost(sim: SimWorld, id: String, cs: CountryState = null) -> Dictionary:
	var a: Dictionary = sim.data.country_actions.get(id, {})
	var line: Dictionary = sim.data.lines.get(sim.line, {})
	var line_mult := float(line.get("action_cost", {}).get(id, 1.0))
	if cs != null and not cs.timed.is_empty() and cs.active("emergency", sim.week):
		line_mult *= 1.5
	var discount := clampf(1.0 - sim.mod("action_discount"), 0.2, 1.0)
	var cadres := float(a.get("cadres", 0))
	return {"cadres": int(ceilf(cadres * discount * line_mult - 0.001)) if cadres > 0.0 else 0,
		"solidarity": int(ceilf(float(a.get("solidarity", 0)) * line_mult - 0.001))}


## Почему действие в стране недоступно. Пустой список — доступно.
static func action_blockers(sim: SimWorld, id: String, cs: CountryState) -> PackedStringArray:
	var out := PackedStringArray()
	var a: Dictionary = sim.data.country_actions.get(id, {})
	if a.is_empty() or cs == null:
		out.append("unknown")
		return out
	if cs.is_revolutionary():
		out.append("revolutionary")
		return out
	var line: Dictionary = sim.data.lines.get(sim.line, {})
	if id in line.get("blocked_actions", []):
		out.append("line")
		return out
	var req: Dictionary = a.get("requires", {})
	if req.has("unlock") and not sim.has_unlock(req["unlock"]):
		out.append("unlock:" + str(req["unlock"]))
	if cs.influence < float(req.get("min_influence", 0.0)):
		out.append("min_influence:%s" % _num(req.get("min_influence", 0.0)))
	var mins: Dictionary = req.get("min", {})
	for field: String in mins:
		if cs.get_field(field) < float(mins[field]):
			out.append("min:%s:%s" % [field, _num(mins[field])])
	if cs.cooldowns.get(id, 0) > sim.week:
		out.append("cooldown:%d" % (cs.cooldowns[id] - sim.week))
	var cost := action_cost(sim, id, cs)
	if cs.cadres + 0.001 < float(cost["cadres"]):
		out.append("cadres:%d" % cost["cadres"])
	if sim.solidarity < float(cost["solidarity"]):
		out.append("cost")
	return out


## Число для текста причины: 50.0 → «50», 2.5 → «2.5».
static func _num(v: Variant) -> String:
	var f := float(v)
	return str(int(f)) if f == floorf(f) else str(f)


## Шанс успеха: база + коэффициент × (показатель − 50) + поправки на фазу цикла, опыт,
## улучшения и линию.
static func action_chance(sim: SimWorld, id: String, cs: CountryState) -> float:
	var a: Dictionary = sim.data.country_actions.get(id, {})
	var ch: Dictionary = a.get("chance", {})
	var p := float(ch.get("base", 0.5))
	var terms: Dictionary = ch.get("terms", {})
	for field: String in terms:
		p += float(terms[field]) * (cs.get_field(field) - 50.0)
	var phase: Dictionary = ch.get("phase", {})
	p += float(phase.get(sim.phase_id(), 0.0))
	for rule: Dictionary in ch.get("above", []):
		if cs.get_field(rule["field"]) > float(rule["value"]) and not (rule.has("unless") and cs.active(rule["unless"], sim.week)):
			p += float(rule["add"])
	var flags: Dictionary = ch.get("flags", {})
	for flag: String in flags:
		if cs.active(flag, sim.week):
			p += float(flags[flag])
	if "strike" in a.get("tags", []):
		p += sim.mod("strike_chance")
	match id:
		"demonstration":
			p += sim.mod("demo_chance")
		"uprising":
			p += sim.mod("uprising_chance") + (sim.mod("uprising_periphery") if cs.is_periphery else 0.0)
	return clampf(p, float(ch.get("min", 0.05)), float(ch.get("max", 0.95)))


## Провести действие. Возвращает {"ok": bool, "success": bool, "chance": float}.
static func perform(sim: SimWorld, id: String, cs: CountryState) -> Dictionary:
	if not action_blockers(sim, id, cs).is_empty():
		return {"ok": false, "success": false, "chance": 0.0}
	var a: Dictionary = sim.data.country_actions[id]
	var chance := action_chance(sim, id, cs)
	var cost := action_cost(sim, id, cs)
	cs.cadres = maxf(cs.cadres - float(cost["cadres"]), 0.0)
	sim.solidarity -= float(cost["solidarity"])
	cs.cooldowns[id] = sim.week + int(a.get("cooldown_weeks", 0))
	var success := sim.rng.randf() < chance
	if cs.is_core and a.has("core_reaction"):
		ReactionSystem.add(sim, float(a["core_reaction"]))
	var outcome: Dictionary = a.get("success" if success else "failure", {})
	var scale := 1.0
	var loss := 1.0
	var bonus: Dictionary = sim.data.lines.get(sim.line, {}).get("action_bonus", {}).get(id, {})
	if success:
		scale = float(bonus.get("success_mult", 1.0))
	else:
		# Стачечный фонд смягчает поражения стачек, контрразведка — любых действий.
		if "strike" in a.get("tags", []):
			loss *= maxf(1.0 - sim.mod("strike_loss"), 0.0)
		loss *= maxf(1.0 + sim.mod("action_loss"), 0.0)
	if success and "strike" in a.get("tags", []) and sim.mod("strike_consciousness") > 0.0:
		cs.set_field("consciousness", cs.consciousness + sim.mod("strike_consciousness"))
	apply_outcome(sim, cs, outcome, scale, loss)
	var special := str(outcome.get("special", ""))
	if not (special == "revolution" or special == "defeat"):
		sim.add_news("NEWS_ACTION_%s_%s" % [id, "OK" if success else "FAIL"], [cs.country.name_ru], cs.country.id)
	if success and not bonus.is_empty():
		_line_bonus(sim, cs, bonus)
	if not cs.is_revolutionary():
		EventSystem.notify(sim, ("action_ok:" if success else "action_fail:") + id, cs)
		EventSystem.notify(sim, "action:" + id, cs)
	return {"ok": true, "success": success, "chance": chance}


## Особые последствия линии: у синдикалистов всеобщая стачка может перерасти в революцию,
## у массовой партии победа на выборах грозит переворотом.
static func _line_bonus(sim: SimWorld, cs: CountryState, bonus: Dictionary) -> void:
	if bonus.has("reaction"):
		ReactionSystem.add(sim, float(bonus["reaction"]))
	var adds: Dictionary = bonus.get("add", {})
	for field: String in adds:
		cs.set_field(field, cs.get_field(field) + float(adds[field]))
	if bonus.has("revolution_chance") and not cs.is_revolutionary() \
			and cs.rev_situation >= float(bonus.get("min_rev_situation", 0.0)) \
			and cs.organization >= float(bonus.get("min_organization", 0.0)) \
			and sim.rng.randf() < float(bonus["revolution_chance"]):
		sim.add_news("NEWS_STRIKE_TO_REVOLUTION", [cs.country.name_ru], cs.country.id, true)
		sim.make_revolutionary(cs)


## Применить исход: scale — множитель прибавок при успехе, loss — множитель потерь при провале.
static func apply_outcome(sim: SimWorld, cs: CountryState, outcome: Dictionary, scale: float = 1.0, loss: float = 1.0) -> void:
	var adds: Dictionary = outcome.get("add", {})
	for field: String in adds:
		var v := float(adds[field])
		v *= loss if v < 0.0 else scale
		if field == "strikes_recent" or field == "demos_recent":
			cs.set(field, cs.get_field(field) + v)
		elif field == "cadres":
			cs.cadres = clampf(cs.cadres + v, 0.0, maxf(cs.cadre_cap(sim), cs.cadres))
		else:
			cs.set_field(field, cs.get_field(field) + v)
	var mults: Dictionary = outcome.get("mult", {})
	for field: String in mults:
		var m := float(mults[field])
		if m > 1.0:
			m = 1.0 + (m - 1.0) * scale
		cs.set_field(field, cs.get_field(field) * m)
	for flag: String in outcome.get("flags", []):
		cs.flags[flag] = true
	var timed: Dictionary = outcome.get("timed", {})
	for flag: String in timed:
		cs.timed[flag] = sim.week + int(timed[flag])
	if outcome.has("reaction"):
		ReactionSystem.add(sim, float(outcome["reaction"]))
	match outcome.get("special", ""):
		"revolution":
			sim.make_revolutionary(cs)
		"defeat":
			sim.defeat_uprising(cs)
		"organizers":
			# Организаторы закладывают движение и там, где его ещё нет.
			if cs.influence < 0.5:
				cs.set_field("influence", 0.5)
			if not cs.has_flag("reached"):
				cs.flags["reached"] = true
		"solidarity":
			_solidarity_strike(sim, cs)


## Солидарная стачка: поддержка движения в странах, связанных с этой.
static func _solidarity_strike(sim: SimWorld, cs: CountryState) -> void:
	var d := sim.data
	var partners := {}
	for i in d.link_a.size():
		if d.link_a[i] == cs.index:
			partners[d.link_b[i]] = true
		elif d.link_b[i] == cs.index:
			partners[d.link_a[i]] = true
	for idx: int in partners:
		var other := sim.countries[idx]
		if other.is_revolutionary() or other.influence <= 0.0:
			continue
		other.set_field("trust", other.trust + 3.0)
		other.demos_recent += 0.5
		other.set_field("influence", other.influence + 0.3)
	sim.solidarity += 3.0
