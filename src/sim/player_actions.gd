class_name PlayerActions
extends RefCounted
## Улучшения движения и действия в стране (описания — в data/actions.json):
## можно ли их сделать, с каким шансом и что из этого выходит.


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
	for req: String in u.get("requires", []):
		if not sim.upgrades.has(req):
			out.append("requires:" + req)
	if sim.solidarity < float(u.get("cost", 0)):
		out.append("cost")
	return out


static func buy_upgrade(sim: SimWorld, id: String) -> bool:
	if not upgrade_blockers(sim, id).is_empty():
		return false
	var u: Dictionary = sim.data.upgrades[id]
	sim.solidarity -= float(u.get("cost", 0))
	sim.upgrades[id] = true
	recompute_mods(sim)
	var on_buy: Dictionary = u.get("on_buy", {})
	if on_buy.has("reaction"):
		ReactionSystem.add(sim, float(on_buy["reaction"]))
	sim.add_news("NEWS_UPGRADE", ["UPGRADE_" + id])
	return true


## Сумма модификаторов всех купленных улучшений и список открытых возможностей.
static func recompute_mods(sim: SimWorld) -> void:
	sim.mods.clear()
	sim.unlocks.clear()
	for id in sim.data.upgrade_order:
		if not sim.upgrades.has(id):
			continue
		var u: Dictionary = sim.data.upgrades[id]
		var mods: Dictionary = u.get("modifiers", {})
		for key: String in mods:
			sim.mods[key] = sim.mods.get(key, 0.0) + float(mods[key])
		for unlock: String in u.get("unlocks", []):
			sim.unlocks[unlock] = true


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
	if sim.solidarity < float(a.get("cost", 0)):
		out.append("cost")
	return out


## Число для текста причины: 50.0 → «50», 2.5 → «2.5».
static func _num(v: Variant) -> String:
	var f := float(v)
	return str(int(f)) if f == floorf(f) else str(f)


## Шанс успеха: база + коэффициент × (показатель − 50) + поправки на фазу цикла и опыт.
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
		if cs.get_field(rule["field"]) > float(rule["value"]):
			p += float(rule["add"])
	var flags: Dictionary = ch.get("flags", {})
	for flag: String in flags:
		if cs.has_flag(flag):
			p += float(flags[flag])
	return clampf(p, float(ch.get("min", 0.05)), float(ch.get("max", 0.95)))


## Провести действие. Возвращает {"ok": bool, "success": bool, "chance": float}.
static func perform(sim: SimWorld, id: String, cs: CountryState) -> Dictionary:
	if not action_blockers(sim, id, cs).is_empty():
		return {"ok": false, "success": false, "chance": 0.0}
	var a: Dictionary = sim.data.country_actions[id]
	var chance := action_chance(sim, id, cs)
	sim.solidarity -= float(a.get("cost", 0))
	cs.cooldowns[id] = sim.week + int(a.get("cooldown_weeks", 0))
	var success := sim.rng.randf() < chance
	if cs.is_core and a.has("core_reaction"):
		ReactionSystem.add(sim, float(a["core_reaction"]))
	apply_outcome(sim, cs, a.get("success" if success else "failure", {}))
	if not outcome_is_special(a, success):
		sim.add_news("NEWS_ACTION_%s_%s" % [id, "OK" if success else "FAIL"], [cs.country.name_ru], cs.country.id)
	return {"ok": true, "success": success, "chance": chance}


## Восстание сообщает о себе само (революция или разгром), остальным действиям нужна новость.
static func outcome_is_special(action: Dictionary, success: bool) -> bool:
	var outcome: Dictionary = action.get("success" if success else "failure", {})
	return outcome.has("special")


static func apply_outcome(sim: SimWorld, cs: CountryState, outcome: Dictionary) -> void:
	var adds: Dictionary = outcome.get("add", {})
	for field: String in adds:
		if field == "strikes_recent" or field == "demos_recent":
			cs.set(field, cs.get_field(field) + float(adds[field]))
		else:
			cs.set_field(field, cs.get_field(field) + float(adds[field]))
	var mults: Dictionary = outcome.get("mult", {})
	for field: String in mults:
		cs.set_field(field, cs.get_field(field) * float(mults[field]))
	for flag: String in outcome.get("flags", []):
		cs.flags[flag] = true
	match outcome.get("special", ""):
		"revolution":
			sim.make_revolutionary(cs)
		"defeat":
			sim.defeat_uprising(cs)
