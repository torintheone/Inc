class_name UiText
extends RefCounted
## Тексты интерфейса, которые собираются из данных симуляции: даты, новости,
## причины недоступности действий.


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
		if a is String and (a.begins_with("UPGRADE_") or a.begins_with("OUTCOME_") or a.begins_with("ACTION_")):
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
			return TranslationServer.translate("BLOCK_unlock_" + parts[1])
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
