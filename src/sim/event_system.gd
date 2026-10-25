class_name EventSystem
extends RefCounted
## События из data/events.json. Время от времени выбирается событие, условия которого
## выполнены, — в стране, где есть движение, или во всём мире. Игрок выбирает один из
## вариантов; вариант может удаться или нет и продолжить цепочку («Фашистская угроза»).
## Некоторые события — ответ на действие игрока («Локаут» после проигранной стачки).
## Пока решение не принято, событие ждёт; через несколько недель без ответа берётся
## вариант по умолчанию (в игре время на это время стоит, так что это — для прогонов).

const WORLD := "world"


## Неделя событий: продолжения цепочек, автоответ, новое случайное событие.
static func update(sim: SimWorld) -> void:
	if sim.start_country == "":
		return
	var d := sim.data
	if not sim.pending_event.is_empty():
		if sim.week - int(sim.pending_event["week"]) >= int(d.num("events.auto_resolve_weeks")):
			resolve(sim, default_option(sim))
		return
	if _start_due_chain(sim):
		return
	if sim.week - sim.last_event_week < int(d.num("events.min_gap_weeks")):
		return
	var chance := d.num("events.chance_per_week") * (d.num("events.slump_mult") if EconomySystem.is_slump(sim.phase_id()) else 1.0)
	if sim.rng.randf() >= chance:
		return
	var picked := _pick(sim)
	if not picked.is_empty():
		_open(sim, picked["id"], picked["country"])


## Продолжение цепочки, срок которого настал. true — событие открыто.
static func _start_due_chain(sim: SimWorld) -> bool:
	for i in sim.event_queue.size():
		var q: Dictionary = sim.event_queue[i]
		if int(q["week"]) > sim.week:
			continue
		sim.event_queue.remove_at(i)
		var cid: String = q["country"]
		var cs := sim.state_of(cid) if cid != WORLD else null
		# Страна стала революционной — цепочка в ней обрывается сама.
		if cs != null and cs.is_revolutionary() and not bool(sim.data.events[q["id"]]["trigger"].get("revolutionary", false)):
			return false
		_open(sim, q["id"], cid)
		return true
	return false


## Выбрать событие: вес события × (втрое, если игрок его ещё не видел).
static func _pick(sim: SimWorld) -> Dictionary:
	var d := sim.data
	var unseen := d.num("events.unseen_mult")
	var ids := PackedStringArray()
	var countries := PackedStringArray()
	var weights := PackedFloat64Array()
	var total := 0.0
	for id in d.event_order:
		var e: Dictionary = d.events[id]
		if e.get("chain_only", false) or e.has("on") or not available(sim, id):
			continue
		var cid := ""
		if e["scope"] == WORLD:
			if not world_trigger_ok(sim, e["trigger"]):
				continue
			cid = WORLD
		else:
			cid = _pick_country(sim, e)
			if cid == "":
				continue
		var w := float(e.get("weight", 1.0)) * (unseen if not sim.events_seen.has(id) else 1.0)
		ids.append(id)
		countries.append(cid)
		weights.append(w)
		total += w
	if total <= 0.0:
		return {}
	var r := sim.rng.randf() * total
	for i in ids.size():
		r -= weights[i]
		if r <= 0.0:
			return {"id": ids[i], "country": countries[i]}
	return {"id": ids[-1], "country": countries[-1]}


## Страна для события: среди подходящих — пропорционально силе движения и размеру страны.
static func _pick_country(sim: SimWorld, e: Dictionary) -> String:
	if not world_trigger_ok(sim, e["trigger"]):
		return ""
	var candidates: Array[CountryState] = []
	var weights := PackedFloat64Array()
	var total := 0.0
	var min_influence := sim.data.num("events.country_min_influence")
	for cs in sim.countries:
		if not _country_ok(sim, e, cs, min_influence):
			continue
		var w := (maxf(cs.influence, 1.0) if not cs.is_revolutionary() else 30.0) * cs.size
		candidates.append(cs)
		weights.append(w)
		total += w
	if candidates.is_empty():
		return ""
	var r := sim.rng.randf() * total
	for i in candidates.size():
		r -= weights[i]
		if r <= 0.0:
			return candidates[i].country.id
	return candidates[-1].country.id


## Событие не на перерыве и не исчерпало число повторов.
static func available(sim: SimWorld, id: String) -> bool:
	var e: Dictionary = sim.data.events[id]
	if int(sim.events_seen.get(id, 0)) >= int(e.get("max_times", 99)):
		return false
	return int(sim.event_cooldowns.get(id, -1)) <= sim.week


static func world_trigger_ok(sim: SimWorld, t: Dictionary) -> bool:
	if t.has("phase") and not (sim.phase_id() in t["phase"]):
		return false
	if t.has("phase_week_min") and sim.phase_week < int(t["phase_week_min"]):
		return false
	if sim.reaction < float(t.get("reaction_min", 0.0)) or sim.reaction > float(t.get("reaction_max", 100.0)):
		return false
	if t.has("upgrade") and not sim.upgrades.has(t["upgrade"]):
		return false
	if t.has("no_upgrade") and sim.upgrades.has(t["no_upgrade"]):
		return false
	if t.has("unlock") and not sim.has_unlock(t["unlock"]):
		return false
	if t.has("line") and not (sim.line in t["line"]):
		return false
	if t.has("revolutionary_count_min") and sim.revolutionary_count() < int(t["revolutionary_count_min"]):
		return false
	return true


## Условия события для конкретной страны (вместе с общими условиями мира).
static func country_trigger_ok(sim: SimWorld, e: Dictionary, cs: CountryState) -> bool:
	return world_trigger_ok(sim, e["trigger"]) and _country_ok(sim, e, cs, sim.data.num("events.country_min_influence"))


## Условия страны без общих условий мира: их при выборе страны проверяют один раз.
static func _country_ok(sim: SimWorld, e: Dictionary, cs: CountryState, min_influence: float) -> bool:
	var t: Dictionary = e["trigger"]
	var revolutionary := bool(t.get("revolutionary", false))
	if cs.is_revolutionary() != revolutionary:
		return false
	var mins: Dictionary = t.get("min", {})
	# Сначала дешёвая проверка: событие — там, где есть движение.
	if not revolutionary and cs.influence < float(mins.get("influence", min_influence)):
		return false
	if cs.timed.get("ev_" + str(e["id"]), -1) > sim.week:
		return false
	if revolutionary:
		return true
	# В стране идёт гражданская война: мирных событий там нет.
	if sim.civil_wars.has(cs.country.id):
		return false
	for f: String in mins:
		if cs.get_field(f) < float(mins[f]):
			return false
	var maxs: Dictionary = t.get("max", {})
	for f: String in maxs:
		if cs.get_field(f) > float(maxs[f]):
			return false
	if t.has("zone") and not (cs.country.zone in t["zone"]):
		return false
	if t.has("flag") and not cs.active(t["flag"], sim.week):
		return false
	if t.has("no_flag") and cs.active(t["no_flag"], sim.week):
		return false
	if t.has("timed") and not (sim.upgrades.has(t["timed"]) or cs.active(t["timed"], sim.week)):
		return false
	if t.has("no_timed") and cs.active(t["no_timed"], sim.week):
		return false
	if not _country_data_ok(cs, t):
		return false
	if t.has("neighbor_flag_any"):
		var found := false
		for nid in cs.country.neighbors:
			var n := sim.state_of(nid)
			if n == null:
				continue
			for flag: String in t["neighbor_flag_any"]:
				if n.active(flag, sim.week):
					found = true
		if not found:
			return false
	if t.has("any_of"):
		var any := false
		for alt: Dictionary in t["any_of"]:
			if _country_data_ok(cs, alt) and (not alt.has("flag") or cs.active(alt["flag"], sim.week)):
				any = true
		if not any:
			return false
	return true


## Условия по классам и показателям Всемирного банка.
static func _country_data_ok(cs: CountryState, t: Dictionary) -> bool:
	var classes: Dictionary = t.get("class_min", {})
	for k: String in classes:
		if float(cs.country.classes.get(k, 0.0)) < float(classes[k]):
			return false
	var ind_min: Dictionary = t.get("indicator_min", {})
	for k: String in ind_min:
		if cs.country.indicator(k, 0.0) < float(ind_min[k]):
			return false
	return true


## Ответное событие: на действие игрока ("action_fail:factory_strike"), победу революции
## у соседа ("revolution_neighbor"), разгром восстания ("defeat"), смену линии ("line_change").
## Мировое событие в ответ на перемену в мире ("crisis_start") приходит с cs = null.
static func notify(sim: SimWorld, key: String, cs: CountryState) -> void:
	if not sim.pending_event.is_empty() or sim.start_country == "":
		return
	# Ответные события не идут одно за другим: иначе бот или азартный игрок тонет в окнах.
	var quiet := sim.week - sim.last_event_week < int(sim.data.num("events.reactive_gap_weeks"))
	for id in sim.data.event_order:
		var e: Dictionary = sim.data.events[id]
		if not (key in e.get("on", [])) or not available(sim, id):
			continue
		var world := str(e["scope"]) == WORLD
		if quiet and not world:
			continue
		if world and not world_trigger_ok(sim, e["trigger"]):
			continue
		if not world and (cs == null or not country_trigger_ok(sim, e, cs)):
			continue
		if sim.rng.randf() < float(e.get("weight", 1.0)):
			_open(sim, id, WORLD if world else cs.country.id)
			return


static func _open(sim: SimWorld, id: String, country_id: String) -> void:
	sim.pending_event = {"id": id, "country": country_id, "week": sim.week}
	sim.last_event_week = sim.week


## Страна открытого события (null — событие мировое).
static func pending_country(sim: SimWorld) -> CountryState:
	if sim.pending_event.is_empty():
		return null
	var cid: String = sim.pending_event["country"]
	return sim.state_of(cid) if cid != WORLD else null


## Почему вариант сейчас недоступен. Пустой список — доступен.
static func option_blockers(sim: SimWorld, option: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	var req: Dictionary = option.get("requires", {})
	var cs := pending_country(sim)
	if req.has("solidarity") and sim.solidarity < float(req["solidarity"]):
		out.append("cost")
	if req.has("cadres") and (cs == null or cs.cadres + 0.001 < float(req["cadres"])):
		out.append("cadres:%d" % int(req["cadres"]))
	if req.has("upgrade") and not sim.upgrades.has(req["upgrade"]):
		out.append("requires:" + str(req["upgrade"]))
	if req.has("any_upgrade"):
		var any := false
		for u: String in req["any_upgrade"]:
			if sim.upgrades.has(u):
				any = true
		if not any:
			out.append("requires:" + str(req["any_upgrade"][0]))
	if req.has("unlock") and not sim.has_unlock(req["unlock"]):
		out.append("unlock:" + str(req["unlock"]))
	var mins: Dictionary = req.get("min", {})
	for f: String in mins:
		if cs == null or cs.get_field(f) < float(mins[f]):
			out.append("min:%s:%s" % [f, PlayerActions._num(mins[f])])
	var world: Dictionary = req.get("world", {})
	if world.has("core_consciousness_max"):
		var best := 0.0
		for c in sim.countries:
			if c.is_core and not c.is_revolutionary():
				best = maxf(best, c.consciousness)
		if best < float(world["core_consciousness_max"]):
			out.append("core_consciousness")
	return out


## Вариант по умолчанию — тот, что выбирается без ответа игрока.
static func default_option(sim: SimWorld) -> String:
	var e: Dictionary = sim.data.events[sim.pending_event["id"]]
	for o: Dictionary in e["options"]:
		if o.get("default", false):
			return o["id"]
	return e["options"][-1]["id"]


## Принять решение по открытому событию. forced: 1 — вариант удаётся, 0 — нет, −1 — по шансу.
## Возвращает {"ok", "success", "chance"}.
static func resolve(sim: SimWorld, option_id: String, forced: int = -1) -> Dictionary:
	if sim.pending_event.is_empty():
		return {"ok": false, "success": false, "chance": 0.0}
	var id: String = sim.pending_event["id"]
	var e: Dictionary = sim.data.events[id]
	var option: Dictionary = {}
	for o: Dictionary in e["options"]:
		if o["id"] == option_id:
			option = o
	if option.is_empty() or not option_blockers(sim, option).is_empty():
		return {"ok": false, "success": false, "chance": 0.0}
	var cs := pending_country(sim)
	var chance := float(option.get("chance", 1.0))
	var success := forced == 1 if forced >= 0 else (chance >= 1.0 or sim.rng.randf() < chance)
	var req: Dictionary = option.get("requires", {})
	if req.has("cadres") and cs != null:
		cs.cadres = maxf(cs.cadres - float(req["cadres"]), 0.0)
	var effects: Dictionary = option.get("effects", {}) if success or not option.has("fail") else option["fail"]
	var cid: String = sim.pending_event["country"]
	sim.pending_event = {}
	sim.events_seen[id] = int(sim.events_seen.get(id, 0)) + 1
	sim.event_cooldowns[id] = sim.week + int(e.get("cooldown_weeks", 0))
	if cs != null and e.has("country_cooldown_weeks"):
		cs.timed["ev_" + id] = sim.week + int(e["country_cooldown_weeks"])
	var place := cs.country.name_ru if cs != null else ""
	sim.add_news("NEWS_EVENT" if cs != null else "NEWS_EVENT_WORLD",
		([place] if cs != null else []) + ["EVENT_" + id, "EVENT_%s_%s" % [id, option_id]], cid if cs != null else "",
		false)
	apply_effects(sim, effects, cs)
	return {"ok": true, "success": success, "chance": chance, "effects": effects}


## Последствия варианта: страна события, все страны с движением, ядро, периферия, соседи,
## Реакция, солидарность и продолжение цепочки.
static func apply_effects(sim: SimWorld, effects: Dictionary, cs: CountryState) -> void:
	if effects.has("country") and cs != null:
		PlayerActions.apply_outcome(sim, cs, effects["country"])
	for scope in ["movement", "core", "periphery", "neighbors"]:
		if not effects.has(scope):
			continue
		for other in targets(sim, scope, cs):
			PlayerActions.apply_outcome(sim, other, effects[scope])
	if effects.has("reaction"):
		ReactionSystem.add(sim, float(effects["reaction"]))
	if effects.has("solidarity"):
		sim.solidarity = maxf(sim.solidarity + float(effects["solidarity"]), 0.0)
	if effects.has("chain"):
		var chain: Dictionary = effects["chain"]
		var after: Array = chain.get("after", [4, 8])
		var week := sim.week + sim.rng.randi_range(int(after[0]), int(after[1]))
		sim.event_queue.append({"id": chain["event"], "country": cs.country.id if cs != null else WORLD, "week": week})


## Страны, на которые действует часть последствий.
static func targets(sim: SimWorld, scope: String, cs: CountryState) -> Array[CountryState]:
	var out: Array[CountryState] = []
	match scope:
		"movement":
			for c in sim.countries:
				if not c.is_revolutionary() and c.influence >= 1.0:
					out.append(c)
		"core":
			for c in sim.countries:
				if c.is_core and not c.is_revolutionary():
					out.append(c)
		"periphery":
			for c in sim.countries:
				if c.is_periphery and not c.is_revolutionary():
					out.append(c)
		"neighbors":
			if cs != null:
				for nid in cs.country.neighbors:
					var n := sim.state_of(nid)
					if n != null and not n.is_revolutionary() and n.influence > 0.0:
						out.append(n)
	return out
