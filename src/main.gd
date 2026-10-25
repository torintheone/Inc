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
}

var data: GameData
var sim: SimWorld
var map: WorldMap
var bubbles: BubbleLayer
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
	hud.setup(data.world)

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
	_show_menu()


func _on_zoom(zoom: float) -> void:
	map.on_zoom_changed(zoom)
	bubbles.zoom = zoom
	bubbles.queue_redraw()


func _process(delta: float) -> void:
	camera.ui_blockers = hud.blockers()
	if mode != "play" or speed == 0 or hud.has_overlay():
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
	var on_continue: Variant = _continue_game if SaveStore.has_autosave() else null
	hud.show_overlay(Overlays.menu(_new_game, on_continue))


func _new_game() -> void:
	hud.close_overlay()
	var seed_value := int(Time.get_unix_time_from_system()) ^ Time.get_ticks_usec()
	sim = SimWorld.new_game(data, seed_value)
	_seen_news = sim.news_count
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
	hud.set_mode(mode)
	hud.panel.tab = CountryPanel.TAB_MOVEMENT
	_set_speed(1)
	map.apply_sim(sim)
	bubbles.show_bubbles(sim)
	if selected != null:
		hud.show_country(selected, sim.state_of(selected.id), sim, _panel_button_text())
	_refresh_ui()


func _show_help(first_time: bool) -> void:
	var screen := HelpScreen.new(first_time)
	screen.closed.connect(func() -> void:
		hud.close_overlay()
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
	map.apply_sim(sim)
	bubbles.show_bubbles(sim)
	_collect_alerts()
	_refresh_ui()
	if sim.week % int(data.num("time.autosave_every_weeks", 4)) == 0:
		SaveStore.save(sim)
	if sim.is_over():
		_finish()
	elif not _alerts.is_empty():
		_show_next_alert()


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


func _close_alert() -> void:
	hud.close_overlay()
	if not _alerts.is_empty():
		_show_next_alert()


func _finish() -> void:
	mode = "ended"
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


func _focus_country(id: String) -> void:
	var c := data.world.get_country(id)
	if c == null:
		return
	_select(c)
	camera.position = MapCamera.clamp_position(c.label, camera.zoom_level(), get_viewport_rect().size, camera.map_bounds)


func _deselect() -> void:
	selected = null
	map.select(null)
	hud.hide_country()
	_refresh_ui()


func _panel_button_text() -> String:
	if mode == "choose":
		return tr("BTN_START_HERE")
	if mode == "play" and selected != null and not sim.state_of(selected.id).is_revolutionary():
		return tr("BTN_ACTIONS")
	return ""


func _on_panel_button() -> void:
	if selected == null:
		return
	if mode == "choose":
		_start_id = selected.id
		_choose_line()
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
		hud.toast(tr("BLOCK_revolutionary"))
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
	var result := PlayerActions.perform(sim, id, cs)
	if not result["ok"]:
		return
	map.apply_sim(sim)
	_collect_alerts()
	_refresh_ui()
	if sim.is_over():
		_finish()
	elif not _alerts.is_empty():
		_show_next_alert()
	else:
		screen.refresh(sim, cs)
		screen.show_result(result["success"])


func _refresh_ui() -> void:
	if sim == null:
		return
	var cs := sim.state_of(selected.id) if selected != null else null
	hud.refresh(sim, cs, _panel_button_text())
