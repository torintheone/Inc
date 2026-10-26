extends Node2D
## Точка входа и ход партии: меню, выбор стартовой страны и линии, недели симуляции,
## пузырьки, экраны развития и действий, важные события, автосохранение и итог.

## Допуск попадания по стране, в пикселях экрана: помогает с маленькими островами.
const TAP_TOLERANCE_PX := 12.0
## Больше шагов за кадр не делаем, даже если кадр затянулся.
const MAX_STEPS_PER_FRAME := 4
const SETTINGS_PATH := "user://settings.cfg"

## Новости, о которых игра сообщает окном и ставит паузу.
const ALERT_TITLES := {
	"NEWS_WINDOW_OPENED": "ALERT_TITLE_WINDOW",
	"NEWS_REVOLUTION": "ALERT_TITLE_REVOLUTION",
	"NEWS_UPRISING_DEFEATED": "ALERT_TITLE_DEFEAT",
	"NEWS_STRIKE_TO_REVOLUTION": "ALERT_TITLE_REVOLUTION",
	"NEWS_CRISIS": "ALERT_TITLE_CRISIS",
	"NEWS_COUNTERTENDENCY": "ALERT_TITLE_CRISIS",
	"NEWS_REACTION_20": "ALERT_TITLE_REACTION",
	"NEWS_REACTION_40": "ALERT_TITLE_REACTION",
	"NEWS_REACTION_60": "ALERT_TITLE_REACTION",
	"NEWS_REACTION_80": "ALERT_TITLE_REACTION",
	"NEWS_REACTION_100": "ALERT_TITLE_REACTION",
	"NEWS_LINE_CHANGED": "ALERT_TITLE_LINE",
	"NEWS_CIVIL_WAR": "ALERT_TITLE_CIVIL_WAR",
	"NEWS_THERMIDOR": "ALERT_TITLE_THERMIDOR",
	"NEWS_COUNTERREVOLUTION": "ALERT_TITLE_COUNTERREVOLUTION",
	"NEWS_COUNTER_THREAT": "ALERT_TITLE_COUNTER_THREAT",
}
## Во время сражения партия сохраняется раз в столько дней.
const BATTLE_SAVE_DAYS := 7

var data: GameData
var sim: SimWorld
var map: WorldMap
var bubbles: BubbleLayer
var fx: MapFx
var camera: MapCamera
var hud: Hud

## "menu", "choose" (страна), "line" (линия), "play", "ended".
var mode := "menu"
var speed := 1
var selected: Country
var _accum := 0.0
var _seen_news := 0
var _alerts: Array[Dictionary] = []
var _start_id := ""
## Сколько новостей уже показано анимацией на карте.
var _fx_seen := 0
var _tutorial := Tutorial.new()
var _tip_step := ""


func _ready() -> void:
	TranslationServer.set_locale("ru")
	RenderingServer.set_default_clear_color(MapPalette.OCEAN)
	data = GameData.load_default()
	if data == null:
		push_error("Данные игры не загружены: проверьте папку data/")
		return
	UiText.set_unlock_sources(data)

	map = WorldMap.new()
	map.setup(data.world)
	add_child(map)
	fx = MapFx.new()
	add_child(fx)
	bubbles = BubbleLayer.new()
	bubbles.world = data.world
	add_child(bubbles)

	camera = MapCamera.new()
	camera.map_bounds = data.world.bounds.grow(40.0)
	add_child(camera)
	camera.make_current()
	camera.fit_whole_map()

	hud = Hud.new()
	add_child(hud)
	hud.setup()

	camera.tapped.connect(_on_map_tapped)
	camera.zoom_changed.connect(_on_zoom)
	_on_zoom(camera.zoom_level())
	hud.speed_selected.connect(_set_speed)
	hud.development_requested.connect(_open_development)
	hud.actions_requested.connect(_open_actions)
	hud.help_requested.connect(func() -> void: _show_help(false))
	hud.country_requested.connect(_focus_country)
	hud.panel_button_pressed.connect(_on_panel_button)
	hud.panel_closed.connect(_deselect)
	hud.request_refresh.connect(_refresh_ui)
	hud.tip.closed.connect(_on_tip_closed)
	_show_menu()


func _on_zoom(zoom: float) -> void:
	map.on_zoom_changed(zoom)
	fx.zoom = zoom
	fx.queue_redraw()
	bubbles.zoom = zoom
	bubbles.queue_redraw()


func _process(delta: float) -> void:
	camera.ui_blockers = hud.blockers()
	camera.screen_insets = hud.map_insets()
	if mode != "play" or speed == 0 or hud.has_overlay() or hud.tip.visible:
		return
	var seconds_per_week := data.num("time.seconds_per_week", 2.5)
	_accum += delta * speed
	var steps := 0
	while _accum >= seconds_per_week and steps < MAX_STEPS_PER_FRAME:
		_accum -= seconds_per_week
		steps += 1
		_advance_week()
		if mode != "play" or hud.has_overlay():
			_accum = 0.0
			break
	if steps == MAX_STEPS_PER_FRAME:
		_accum = 0.0


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST \
			or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if mode == "play" and sim != null:
			SaveStore.save(sim)


# --- Меню и начало партии ----------------------------------------------------

func _show_menu() -> void:
	mode = "menu"
	hud.set_mode(mode)
	hud.hide_country()
	map.select(null)
	map.reset_colors()
	bubbles.clear()
	fx.clear()
	Audio.set_theme("menu")
	Audio.crowd(false)
	var on_continue: Variant = _continue_game if SaveStore.has_autosave() else null
	hud.show_overlay(Overlays.menu(_new_game, on_continue, _show_credits))


func _new_game() -> void:
	hud.close_overlay()
	var seed_value := int(Time.get_unix_time_from_system()) ^ Time.get_ticks_usec()
	sim = SimWorld.new_game(data, seed_value)
	_seen_news = sim.news_count
	_fx_seen = sim.news_count
	_alerts.clear()
	mode = "choose"
	hud.set_mode(mode)
	hud.hide_country()
	map.select(null)
	map.apply_sim(sim)
	bubbles.clear()
	_refresh_ui()


func _continue_game() -> void:
	var loaded := SaveStore.load_game(data)
	if loaded == null:
		SaveStore.delete_autosave()
		_show_menu()
		return
	hud.close_overlay()
	sim = loaded
	_seen_news = sim.news_count
	_fx_seen = sim.news_count
	_alerts.clear()
	if sim.line == "":
		_choose_line()
		return
	_start_play()


## После выбора страны — выбор линии движения.
func _choose_line() -> void:
	mode = "line"
	var screen := LineScreen.new(data)
	screen.line_chosen.connect(_on_line_chosen)
	hud.show_overlay(screen)


func _on_line_chosen(id: String) -> void:
	hud.close_overlay()
	sim.set_line(id)
	if sim.start_country == "" and _start_id != "":
		sim.start_movement(_start_id)
	_seen_news = sim.news_count
	_start_play()
	if not _help_seen():
		_show_help(true)


func _start_play() -> void:
	mode = "play"
	Audio.set_theme("world")
	hud.set_mode(mode)
	hud.panel.tab = CountryPanel.TAB_MOVEMENT
	_set_speed(1)
	map.apply_sim(sim)
	bubbles.show_bubbles(sim)
	if selected != null:
		hud.show_country(selected, sim.state_of(selected.id), sim, _panel_button_text())
	_refresh_ui()
	# Сохранённая партия могла остановиться посреди сражения или на нерешённом событии.
	if sim.battle != null:
		_open_battle()
	elif not sim.pending_event.is_empty():
		_show_event()


func _show_credits() -> void:
	var screen := CreditsScreen.new()
	screen.closed.connect(_show_menu)
	hud.show_overlay(screen)


func _show_help(first_time: bool) -> void:
	var screen := HelpScreen.new(first_time)
	screen.closed.connect(func() -> void:
		hud.close_overlay()
		# Подсказки могли включить заново на экране справки.
		_tutorial = Tutorial.new()
		_set_help_seen())
	hud.show_overlay(screen)


func _help_seen() -> bool:
	var cfg := ConfigFile.new()
	return cfg.load(SETTINGS_PATH) == OK and bool(cfg.get_value("help", "seen", false))


func _set_help_seen() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("help", "seen", true)
	cfg.save(SETTINGS_PATH)


# --- Ход партии -------------------------------------------------------------

func _advance_week() -> void:
	sim.step()
	Audio.set_tension(Audio.tense(sim))
	map.apply_sim(sim)
	bubbles.show_bubbles(sim)
	_collect_alerts()
	_refresh_ui()
	if sim.week % int(data.num("time.autosave_every_weeks", 4)) == 0:
		SaveStore.save(sim)
	if sim.is_over():
		_finish()
	elif sim.battle != null:
		_open_battle()
	else:
		_show_next_popup()
		_check_tutorial()


# --- Обучение ---------------------------------------------------------------

## Подсказка первой партии, если для неё пришло время (и ничего другого на экране нет).
func _check_tutorial() -> void:
	if mode != "play" or hud.has_overlay() or hud.tip.visible:
		return
	var step := _tutorial.next_step(sim)
	if step == "":
		return
	_tip_step = step
	var top := hud.top_bar.position.y + hud.top_bar.size.y + 12.0
	hud.tip.show_tip(Tutorial.text(step), _tip_target(step), top)
	Audio.play("alert", -6.0)


## Куда показывает стрелка подсказки: пузырёк, кнопка «Развитие», страна.
func _tip_target(step: String) -> Variant:
	var to_screen := func(world_pos: Vector2) -> Vector2: return get_viewport().get_canvas_transform() * world_pos
	match step:
		"bubble":
			if not sim.bubbles.is_empty():
				return to_screen.call(bubbles.position_of(sim.bubbles[0]))
		"upgrade":
			return hud.bottom_bar.button_center("upgrades")
		"action":
			var c := data.world.get_country(sim.start_country)
			if c != null:
				return to_screen.call(c.label)
		"window", "society":
			for cs in sim.countries:
				var hit := cs.is_revolutionary() if step == "society" else (cs.window_left >= 0 and cs.influence >= 10.0)
				if hit:
					return to_screen.call(cs.country.label)
	return null


func _on_tip_closed(disable_all: bool) -> void:
	hud.tip.hide()
	if disable_all:
		_tutorial.disable()
	if _tip_step != "":
		_tutorial.mark(_tip_step)
	_tip_step = ""


## Сначала важные сообщения, потом событие, которое ждёт решения.
func _show_next_popup() -> void:
	if not _alerts.is_empty():
		_show_next_alert()
	elif not sim.pending_event.is_empty():
		_show_event()


func _show_event() -> void:
	var cs := EventSystem.pending_country(sim)
	if cs != null:
		_focus_country(cs.country.id)
	var screen := EventScreen.new(sim)
	screen.option_chosen.connect(_on_event_option)
	hud.show_overlay(screen)
	Audio.play("telegraph")


func _on_event_option(option_id: String) -> void:
	var e: Dictionary = data.events.get(sim.pending_event.get("id", ""), {})
	var had_chance := false
	for o: Dictionary in e.get("options", []):
		if o["id"] == option_id and o.has("chance"):
			had_chance = true
	var id: String = sim.pending_event.get("id", "")
	var cs := EventSystem.pending_country(sim)
	var before := ChangeReport.snapshot(sim, cs)
	var result := EventSystem.resolve(sim, option_id)
	if not result["ok"]:
		return
	hud.close_overlay()
	# «Возглавить восстание» и подобные варианты открывают сражение.
	if sim.battle != null:
		_open_battle()
		return
	# Итог: что изменилось в стране события, и что — в других странах (по описанию последствий).
	var lines := ChangeReport.lines(sim, before, cs)
	var effects: Dictionary = result["effects"]
	var elsewhere := effects.duplicate()
	for key in ["country", "reaction", "solidarity", "chain"]:
		elsewhere.erase(key)
	var others := UiText.event_effects(elsewhere)
	if others != "":
		lines.append(others)
	if effects.has("chain"):
		lines.append(tr("EVENT_CHAIN"))
	var title := "%s — %s" % [tr("EVENT_" + id), tr("EVENT_%s_%s" % [id, option_id])]
	if had_chance:
		title = "%s: %s" % [tr("EVENT_RESULT_OK" if result["success"] else "EVENT_RESULT_FAIL"), tr("EVENT_%s_%s" % [id, option_id])]
	hud.show_result(title, lines, result["success"] if had_chance else null)
	Audio.play("stamp" if result["success"] or not had_chance else "fail")
	map.apply_sim(sim)
	_collect_alerts()
	_refresh_ui()
	if sim.is_over():
		_finish()
	else:
		_show_next_popup()


func _collect_alerts() -> void:
	var fresh := sim.news_count - _seen_news
	_seen_news = sim.news_count
	for i in range(maxi(sim.news.size() - fresh, 0), sim.news.size()):
		var item: Dictionary = sim.news[i]
		if not ALERT_TITLES.has(item["key"]):
			continue
		# Об окне революции сообщаем, только если там есть с чем поднимать восстание.
		if item["key"] == "NEWS_WINDOW_OPENED":
			var cs := sim.state_of(item.get("country", ""))
			if cs == null or cs.influence < 10.0:
				continue
		_alerts.append(item)


func _show_next_alert() -> void:
	var item: Dictionary = _alerts.pop_front()
	var cid: String = item.get("country", "")
	var text := UiText.news(item)
	var on_goto: Variant = null
	if cid != "":
		on_goto = func() -> void:
			hud.close_overlay()
			_focus_country(cid)
	hud.show_overlay(Overlays.alert(tr(ALERT_TITLES[item["key"]]), text, on_goto, _close_alert))
	_alert_sound(item["key"])


# --- Сражение ----------------------------------------------------------------

## Экран сражения во весь экран; мир стоит, пока он открыт.
func _open_battle() -> void:
	if sim.battle == null:
		return
	_focus_country(sim.battle.country_id)
	var screen := BattleScreen.new(sim)
	screen.finished.connect(_on_battle_finished)
	Audio.set_theme("battle")
	Audio.play("drum_roll")
	screen.day_passed.connect(func() -> void:
		if sim.battle != null and sim.battle.day % BATTLE_SAVE_DAYS == 0:
			SaveStore.save(sim))
	hud.show_overlay(screen)
	SaveStore.save(sim)


func _on_battle_finished() -> void:
	sim.finish_battle()
	hud.close_overlay()
	Audio.crowd(false)
	Audio.set_theme("world")
	map.apply_sim(sim)
	_collect_alerts()
	_refresh_ui()
	SaveStore.save(sim)
	if sim.is_over():
		_finish()
	else:
		_show_next_popup()


## Звук важного сообщения: победа — колокол и тема победы, разгром — тема поражения.
func _alert_sound(key: String) -> void:
	match key:
		"NEWS_REVOLUTION", "NEWS_STRIKE_TO_REVOLUTION":
			Audio.play("bell")
			Audio.sting("victory")
			camera.shake(1.0)
		"NEWS_UPRISING_DEFEATED", "NEWS_COUNTERREVOLUTION":
			Audio.sting("defeat")
			camera.shake(0.8)
		"NEWS_CRISIS", "NEWS_REACTION_100", "NEWS_CIVIL_WAR":
			Audio.play("drum_hit")
			camera.shake(0.6)
		"NEWS_THERMIDOR", "NEWS_COUNTER_THREAT":
			Audio.play("fail")
		_:
			Audio.play("alert")


func _close_alert() -> void:
	hud.close_overlay()
	_show_next_popup()


func _finish() -> void:
	mode = "ended"
	var won := sim.outcome == SimWorld.OUTCOME_FEDERATION or sim.outcome == SimWorld.OUTCOME_WORLD_REVOLUTION
	Audio.set_theme("")
	Audio.sting("victory" if won or sim.outcome == SimWorld.OUTCOME_TWO_SYSTEMS else "defeat")
	hud.set_mode(mode)
	SaveStore.delete_autosave()
	var screen := ResultsScreen.new(sim)
	screen.new_game_requested.connect(_new_game)
	hud.show_overlay(screen)


func _set_speed(value: int) -> void:
	speed = value
	hud.top_bar.show_speed(speed)


# --- Действия игрока --------------------------------------------------------

func _on_map_tapped(world_pos: Vector2) -> void:
	if mode == "menu" or mode == "line":
		return
	if mode == "play":
		var bubble := bubbles.bubble_at(world_pos)
		if bubble >= 0:
			_collect_bubble(bubble)
			return
	var c := data.world.country_at(world_pos, TAP_TOLERANCE_PX / camera.zoom_level())
	if c == null:
		_deselect()
		return
	_select(c)


func _collect_bubble(id: int) -> void:
	var kind := ""
	for b in sim.bubbles:
		if int(b["id"]) == id:
			kind = b["kind"]
	var result := sim.collect_bubble(id)
	if not result["ok"]:
		return
	var text := "+%s" % NumberFormat.decimal(float(result["value"]), 0)
	if kind == UnrestSystem.PROTEST:
		text = tr("BUBBLE_SUPPORTED") % text
		Audio.play("crowd_roar", -4.0)
	else:
		Audio.play("bubble", 0.0, randf_range(0.95, 1.08))
	bubbles.pop(id, text)
	bubbles.show_bubbles(sim)
	map.apply_sim(sim)
	_seen_news = sim.news_count
	_refresh_ui()


func _select(c: Country) -> void:
	selected = c
	map.select(c)
	hud.show_country(c, sim.state_of(c.id), sim, _panel_button_text())
	_refresh_ui()
	# Панель справа не должна закрывать выбранную страну (Япония, Корея, Новая Зеландия).
	camera.screen_insets = hud.map_insets()
	camera.reveal(c.label)


func _focus_country(id: String) -> void:
	var c := data.world.get_country(id)
	if c == null:
		return
	_select(c)


func _deselect() -> void:
	selected = null
	map.select(null)
	hud.hide_country()
	_refresh_ui()


func _panel_button_text() -> String:
	if mode == "choose":
		return tr("BTN_START_HERE")
	if mode == "play" and selected != null and sim.in_civil_war(selected.id):
		return tr("BTN_TO_BATTLE")
	if mode == "play" and selected != null and sim.state_of(selected.id).is_revolutionary():
		return tr("BTN_SOCIETY")
	if mode == "play" and selected != null:
		return tr("BTN_ACTIONS")
	return ""


func _on_panel_button() -> void:
	if selected == null:
		return
	if mode == "choose":
		_start_id = selected.id
		_choose_line()
	elif mode == "play" and sim.in_civil_war(selected.id):
		if sim.resume_civil_war(selected.id):
			_open_battle()
	elif mode == "play" and sim.state_of(selected.id).is_revolutionary():
		_open_society()
	elif mode == "play":
		_open_actions()


func _open_development() -> void:
	if mode != "play":
		return
	var screen := DevelopmentScreen.new()
	screen.buy_requested.connect(func(id: String) -> void:
		if PlayerActions.buy_upgrade(sim, id):
			_seen_news = sim.news_count
			screen.refresh(sim)
			_refresh_ui())
	screen.change_line_requested.connect(_open_line_change)
	screen.close_requested.connect(func() -> void:
		hud.close_overlay()
		_refresh_ui())
	hud.show_overlay(screen)
	screen.refresh(sim)


## «Новое общество» революционной страны: показатели и три политики.
func _open_society() -> void:
	if mode != "play" or selected == null:
		return
	var cs := sim.state_of(selected.id)
	if not cs.is_revolutionary():
		return
	var screen := SocietyScreen.new()
	screen.policy_requested.connect(func(policy: String, option: String) -> void:
		if NewSociety.set_policy(sim, cs, policy, option):
			_seen_news = sim.news_count
			screen.refresh(sim, cs)
			hud.show_result(tr("REPORT_POLICY") % tr("POLICY_%s_%s" % [policy, option]),
				PackedStringArray([tr("POLICY_%s_%s_DESC" % [policy, option])]), true)
			_refresh_ui())
	screen.close_requested.connect(func() -> void:
		hud.close_overlay()
		_refresh_ui())
	hud.show_overlay(screen)
	screen.refresh(sim, cs)


func _open_line_change() -> void:
	var screen := LineScreen.new(data, sim.line, true)
	screen.line_chosen.connect(func(id: String) -> void:
		sim.change_line(id)
		_seen_news = sim.news_count
		map.apply_sim(sim)
		_open_development())
	screen.close_requested.connect(_open_development)
	hud.show_overlay(screen)


func _open_actions() -> void:
	if mode != "play":
		return
	if selected == null:
		hud.toast(tr("TOAST_SELECT_COUNTRY"))
		return
	var cs := sim.state_of(selected.id)
	if cs.is_revolutionary():
		_open_society()
		return
	var screen := ActionsScreen.new()
	screen.action_requested.connect(func(id: String) -> void: _on_action(screen, id))
	screen.close_requested.connect(func() -> void:
		hud.close_overlay()
		_refresh_ui())
	hud.show_overlay(screen)
	screen.refresh(sim, cs)


func _on_action(screen: ActionsScreen, id: String) -> void:
	if mode != "play" or selected == null:
		return
	var cs := sim.state_of(selected.id)
	var before := ChangeReport.snapshot(sim, cs)
	var result := PlayerActions.perform(sim, id, cs)
	if not result["ok"]:
		return
	if result.get("battle", false):
		hud.close_overlay()
		_open_battle()
		return
	hud.show_result(tr("ACTION_RESULT_OK" if result["success"] else "ACTION_RESULT_FAIL") % tr("ACTION_" + id),
		ChangeReport.lines(sim, before, cs), result["success"])
	_action_sound(id, result["success"])
	map.apply_sim(sim)
	_collect_alerts()
	_refresh_ui()
	if sim.is_over():
		_finish()
	elif not _alerts.is_empty() or not sim.pending_event.is_empty():
		_show_next_popup()
	else:
		screen.refresh(sim, cs)
		screen.show_result(result["success"])


## Свежие новости — на карту: вспышки стран и линии распространения движения.
func _animate_news() -> void:
	var fresh := sim.news_count - _fx_seen
	_fx_seen = sim.news_count
	if fresh <= 0 or mode != "play":
		return
	for i in range(maxi(sim.news.size() - fresh, 0), sim.news.size()):
		var item: Dictionary = sim.news[i]
		var c := data.world.get_country(item.get("country", ""))
		if c == null:
			continue
		var key: String = item["key"]
		match key:
			"NEWS_REACHED":
				var source := _spread_source(sim.state_of(c.id))
				if not source.is_empty():
					fx.spread(data.world.countries[int(source[0])].label, c.label, source[1])
			"NEWS_REVOLUTION", "NEWS_STRIKE_TO_REVOLUTION":
				fx.pulse(c.label, MapPalette.VERMILION, 2.0)
			"NEWS_UPRISING_DEFEATED", "NEWS_COUNTERREVOLUTION":
				fx.pulse(c.label, MapPalette.STEEL, 2.0)
			"NEWS_CIVIL_WAR", "NEWS_BATTLE_START", "NEWS_WINDOW_OPENED":
				fx.pulse(c.label, MapPalette.OCHRE, 1.5)
			"NEWS_THERMIDOR":
				fx.pulse(c.label, MapPalette.CONCRETE, 1.5)
			_:
				if key.begins_with("NEWS_EVENT"):
					fx.pulse(c.label, MapPalette.OCHRE, 1.0)
				elif key.begins_with("NEWS_ACTION_"):
					fx.pulse(c.label, MapPalette.VERMILION if key.ends_with("_OK") else MapPalette.STEEL, 0.8)


## Откуда движение пришло в страну и каким путём: [номер страны, "train" | "ship" | "radio"].
## Сосед — поездом, торговля и эмиграция — кораблём; если связи нет — радио из самой сильной страны.
func _spread_source(target: CountryState) -> Array:
	var best := -1
	var best_score := 0.0
	var kind := "radio"
	for i in data.link_a.size():
		var other := -1
		if data.link_a[i] == target.index:
			other = data.link_b[i]
		elif data.link_b[i] == target.index:
			other = data.link_a[i]
		if other < 0:
			continue
		var cs := sim.countries[other]
		var strength := 100.0 if cs.is_revolutionary() else cs.influence
		if strength < 1.0:
			continue
		var neighbor := data.link_neighbor[i] > 0
		var score := strength * (data.link_trade[i] + data.link_migration[i] + (0.5 if neighbor else 0.0))
		if score > best_score:
			best_score = score
			best = other
			kind = "train" if neighbor else "ship"
	if best < 0:
		for cs in sim.countries:
			if cs != target and cs.influence > best_score:
				best_score = cs.influence
				best = cs.index
		kind = "radio"
	return [] if best < 0 else [best, kind]


## Звук действия: стачка — заводской гудок, демонстрация — толпа, провал — глухой удар.
func _action_sound(id: String, success: bool) -> void:
	if not success:
		Audio.play("fail")
		return
	var a: Dictionary = data.country_actions.get(id, {})
	if "strike" in a.get("tags", []):
		Audio.play("factory_whistle")
	elif id == "demonstration":
		Audio.play("crowd_roar")
	else:
		Audio.play("stamp")


func _refresh_ui() -> void:
	if sim == null:
		return
	_animate_news()
	var cs := sim.state_of(selected.id) if selected != null else null
	hud.refresh(sim, cs, _panel_button_text())
