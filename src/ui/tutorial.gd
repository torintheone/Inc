class_name Tutorial
extends RefCounted
## Обучение в первой партии: короткие подсказки по ходу игры — о пузырьках, развитии, действиях,
## распространении, окне революции, Реакции и новом обществе. Каждая показывается один раз; время
## стоит, пока подсказка открыта. Показанные подсказки и выключатель хранятся в user://settings.cfg.

const SETTINGS_PATH := "user://settings.cfg"
## Порядок проверки: первая подходящая и ещё не показанная подсказка.
const STEPS: PackedStringArray = ["start", "bubble", "upgrade", "action", "spread", "window", "reaction", "society"]

var enabled := true
var shown: Dictionary[String, bool] = {}


func _init() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		enabled = bool(cfg.get_value("tutorial", "enabled", true))
		for id: String in cfg.get_value("tutorial", "shown", []):
			shown[id] = true


## Какую подсказку показать сейчас ("" — никакую). Возвращает id шага.
func next_step(sim: SimWorld) -> String:
	# Первую неделю игрок просто осматривается.
	if not enabled or sim == null or sim.start_country == "" or sim.week < 1:
		return ""
	for id in STEPS:
		if not shown.has(id) and _due(sim, id):
			return id
	return ""


func mark(id: String) -> void:
	shown[id] = true
	_save()


func disable() -> void:
	enabled = false
	_save()


## Всё сначала (для новой партии, если игрок сам попросит).
func reset() -> void:
	enabled = true
	shown.clear()
	_save()


static func text(id: String) -> String:
	return TranslationServer.translate("TUT_" + id)


func _due(sim: SimWorld, id: String) -> bool:
	match id:
		"start":
			return sim.week >= 1
		"bubble":
			return not sim.bubbles.is_empty()
		"upgrade":
			for u in sim.data.upgrade_order:
				if PlayerActions.upgrade_blockers(sim, u).is_empty():
					return true
			return false
		"action":
			var cs := sim.state_of(sim.start_country)
			return cs != null and PlayerActions.action_blockers(sim, "factory_strike", cs).is_empty()
		"spread":
			var n := 0
			for cs in sim.countries:
				if cs.influence >= 1.0:
					n += 1
			return n >= 3
		"window":
			for cs in sim.countries:
				if cs.window_left >= 0 and cs.influence >= 10.0 and not cs.is_revolutionary():
					return true
			return false
		"reaction":
			return sim.reaction >= 20.0
		"society":
			return sim.revolutionary_count() > 0
	return false


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("tutorial", "enabled", enabled)
	cfg.set_value("tutorial", "shown", shown.keys())
	cfg.save(SETTINGS_PATH)
