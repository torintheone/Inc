class_name UiText
extends RefCounted
## Тексты интерфейса, которые собираются из данных симуляции: даты, новости,
## причины недоступности действий, строки эффектов улучшений.

## Как показывать модификатор: pct — проценты со знаком, rpct — снижение в процентах,
## pts — пункты со знаком, rpts — снижение в пунктах, year — в год, text — без числа.
const MOD_KINDS := {
	"influence_growth": "pct", "consciousness_rate": "pct", "organization_rate": "pct", "visibility": "pct",
	"cadre_rate": "pct", "auto_support": "pct", "media_channel": "pct", "fragile_consciousness": "pct",
	"peasant_potential": "pct", "periphery_growth": "pct", "core_growth": "pct", "semi_growth": "pct",
	"strike_chance": "pct", "demo_chance": "pct", "uprising_chance": "pct", "uprising_periphery": "pct",
	"migration_channel": "pct", "trade_channel": "pct", "neighbor_channel": "pct", "core_visibility": "pct",
	"bubble_value": "pct", "arrests": "pct", "arrest_damage": "pct", "action_loss": "pct", "repression_growth": "pct",
	"underground": "rpct", "action_discount": "rpct", "strike_loss": "rpct", "drain_cut": "rpct", "legality_hold": "rpct",
	"organization_cap": "pts", "cadre_cap": "pts", "trust_target": "pts", "activity": "pts", "repression_target": "pts",
	"strike_consciousness": "pts", "reformism": "pts",
	"hegemony_culture": "rpts", "army_erosion": "rpts",
	"upkeep": "year",
	"defeat_cushion": "text", "hegemony_erosion": "text",
}


## «март 2031» по номеру недели партии.
static func date(sim: SimWorld, week: int) -> String:
	var per_year := int(sim.data.num("time.weeks_per_year"))
	var year := int(sim.data.num("time.start_year")) + week / per_year
	var month := clampi((week % per_year) * 12 / per_year, 0, 11)
	return "%s %d" % [TranslationServer.translate("MONTH_%d" % month), year]


## Текст новости: ключ перевода и аргументы; аргументы-ключи (UPGRADE_…, OUTCOME_…) тоже переводятся.
static func news(item: Dictionary) -> String:
	var template := TranslationServer.translate(item.get("key", ""))
	var args := []
	for a: Variant in item.get("args", []):
		if a is String and (a.begins_with("UPGRADE_") or a.begins_with("OUTCOME_") or a.begins_with("ACTION_") or a.begins_with("LINE_") or a.begins_with("EVENT_")):
			args.append(TranslationServer.translate(a))
		elif a is float and a == floorf(a):
			args.append(str(int(a)))
		else:
			args.append(str(a))
	if template.count("%s") == args.size():
		return template % args
	return template


## Причина, почему улучшение или действие недоступно, по коду из PlayerActions.
static func blocker(code: String) -> String:
	var parts := code.split(":")
	match parts[0]:
		"requires":
			return TranslationServer.translate("BLOCK_requires") % TranslationServer.translate("UPGRADE_" + parts[1])
		"unlock":
			return TranslationServer.translate("BLOCK_unlock") % unlock_source(parts[1])
		"cadres":
			return TranslationServer.translate("BLOCK_cadres") % parts[1]
		"min_influence":
			return TranslationServer.translate("BLOCK_min_influence") % parts[1]
		"min":
			return TranslationServer.translate("BLOCK_min_" + parts[1]) % parts[2]
		"cooldown":
			return TranslationServer.translate("BLOCK_cooldown") % parts[1]
		_:
			return TranslationServer.translate("BLOCK_" + parts[0])


static func percent(value: float) -> String:
	return NumberFormat.percent(value, 0)


## Название улучшения, которое открывает возможность (для причины «Нужно улучшение: …»).
static var _unlock_sources: Dictionary = {}


static func set_unlock_sources(data: GameData) -> void:
	_unlock_sources.clear()
	for id in data.upgrade_order:
		for unlock: String in data.upgrades[id].get("unlocks", []):
			if not _unlock_sources.has(unlock):
				_unlock_sources[unlock] = id


static func unlock_source(unlock: String) -> String:
	var id: String = _unlock_sources.get(unlock, "")
	return TranslationServer.translate("UPGRADE_" + id) if id != "" else unlock


## Значение модификатора по-человечески: «+50 %», «−15 %», «+30».
static func mod_value(key: String, value: float) -> String:
	match MOD_KINDS.get(key, "pct"):
		"pct":
			return _signed(value * 100.0) + NumberFormat.NBSP + "%"
		"rpct":
			return _signed(-value * 100.0) + NumberFormat.NBSP + "%"
		"pts":
			return _signed(value)
		"rpts":
			return _signed(-value)
		"year":
			return NumberFormat.decimal(value * 52.0, 0)
	return ""


## Изменение в пунктах со знаком: «+3,2», «−1».
static func signed_points(v: float) -> String:
	return _signed(v)


static func _signed(v: float) -> String:
	var digits := 0 if absf(v - roundf(v)) < 0.05 else 1
	return ("+" if v > 0.0 else "") + NumberFormat.decimal(v, digits)


## Строки «что даёт» для улучшения или линии: модификаторы, открытые возможности, рост Реакции.
static func effect_lines(item: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	var mods: Dictionary = item.get("modifiers", {})
	for key: String in mods:
		var template := TranslationServer.translate("MOD_" + key)
		if MOD_KINDS.get(key, "pct") == "text":
			out.append(template)
		else:
			out.append(template % mod_value(key, float(mods[key])))
	var unlocks: Array = item.get("unlocks", [])
	if not unlocks.is_empty():
		var names := PackedStringArray()
		for u: String in unlocks:
			names.append(TranslationServer.translate("UNLOCK_" + u))
		out.append(TranslationServer.translate("EFFECT_OPENS") % ", ".join(names))
	var on_buy: Dictionary = item.get("on_buy", {})
	if on_buy.has("reaction"):
		out.append(TranslationServer.translate("EFFECT_REACTION") % NumberFormat.decimal(float(on_buy["reaction"]), 0))
	return out


## Цена варианта события: кадры, которые он забирает, и солидарность из его последствий.
static func event_cost(option: Dictionary) -> String:
	var parts := PackedStringArray()
	var req: Dictionary = option.get("requires", {})
	if req.has("cadres"):
		parts.append(TranslationServer.translate("COST_CADRES") % int(req["cadres"]))
	var sol := float(option.get("effects", {}).get("solidarity", 0.0))
	if sol < 0.0:
		parts.append(TranslationServer.translate("COST") % int(-sol))
	return ", ".join(parts)


## Последствия варианта одной строкой: «Сознание +8, Организованность +3; Реакция +5».
static func event_effects(effects: Dictionary) -> String:
	var t := TranslationServer.translate
	var parts := PackedStringArray()
	for scope in ["country", "movement", "core", "periphery", "neighbors"]:
		if not effects.has(scope):
			continue
		var line := outcome_text(effects[scope])
		if line == "":
			continue
		parts.append(line if scope == "country" else "%s: %s" % [t.call("SCOPE_" + scope), line])
	if effects.has("reaction"):
		parts.append("%s %s" % [t.call("F_reaction"), _signed(float(effects["reaction"]))])
	var sol := float(effects.get("solidarity", 0.0))
	if sol > 0.0:
		parts.append("%s %s" % [t.call("F_solidarity"), _signed(sol)])
	if effects.has("chain"):
		parts.append(t.call("EVENT_CHAIN"))
	return "; ".join(parts)


## Исход для одной страны: прибавки, множители, временные отметки, особый исход.
static func outcome_text(o: Dictionary) -> String:
	var t := TranslationServer.translate
	var parts := PackedStringArray()
	if o.has("special"):
		parts.append(t.call("SPECIAL_" + str(o["special"])))
	var adds: Dictionary = o.get("add", {})
	for f: String in adds:
		var v := float(adds[f])
		if v != 0.0:
			parts.append("%s %s" % [t.call("F_" + f), _signed(v)])
	var mults: Dictionary = o.get("mult", {})
	for f: String in mults:
		parts.append("%s %s%s%%" % [t.call("F_" + f), _signed((float(mults[f]) - 1.0) * 100.0), NumberFormat.NBSP])
	var timed: Dictionary = o.get("timed", {})
	for flag: String in timed:
		if flag != "port_cells":
			parts.append(t.call("TIMED_" + flag) % int(timed[flag]))
	return ", ".join(parts)
