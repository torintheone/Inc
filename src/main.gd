extends Node2D
## Точка входа и ход партии: меню, выбор стартовой страны, недели симуляции,
## действия игрока, важные события, автосохранение и итог.

## Допуск попадания по стране, в пикселях экрана: помогает с маленькими островами.
const TAP_TOLERANCE_PX := 12.0
## Больше шагов за кадр не делаем, даже если кадр затянулся.
const MAX_STEPS_PER_FRAME := 4

## Новости, о которых игра сообщает окном и ставит паузу.
const ALERT_TITLES := {
	"NEWS_WINDOW_OPENED": "ALERT_TITLE_WINDOW",
	"NEWS_REVOLUTION": "ALERT_TITLE_REVOLUTION",
	"NEWS_UPRISING_DEFEATED": "ALERT_TITLE_DEFEAT",
	"NEWS_CRISIS": "ALERT_TITLE_CRISIS",
	"NEWS_COUNTERTENDENCY": "ALERT_TITLE_CRISIS",
	"NEWS_REACTION_20": "ALERT_TITLE_REACTION",
	"NEWS_REACTION_40": "ALERT_TITLE_REACTION",
	"NEWS_REACTION_60": "ALERT_TITLE_REACTION",
	"NEWS_REACTION_80": "ALERT_TITLE_REACTION",
	"NEWS_REACTION_100": "ALERT_TITLE_REACTION",
}

var data: GameData
var sim: SimWorld
var map: WorldMap
var camera: MapCamera
var hud: Hud

## "menu", "choose", "play", "ended".
var mode := "menu"
var speed := 1
var selected: Country
var _accum := 0.0
var _seen_news := 0
var _alerts: Array[Dictionary] = []
var _peak_reaction := 0.0


func _ready() -> void:
	TranslationServer.set_locale("ru")
	RenderingServer.set_default_clear_color(MapPalette.OCEAN)
	data = GameData.load_default()
	if data == null:
		push_error("Данные игры не загружены: проверьте папку data/")
		return

	map = WorldMap.new()
	map.setup(data.world)
	add_child(map)

	camera = MapCamera.new()
	camera.map_bounds = data.world.bounds.grow(40.0)
	add_child(camera)
	camera.make_current()
	camera.fit_whole_map()

	hud = Hud.new()
	add_child(hud)
	hud.setup(data.world)

	camera.tapped.connect(_on_map_tapped)
	camera.zoom_changed.connect(map.on_zoom_changed)
	map.on_zoom_changed(camera.zoom_level())
	hud.speed_selected.connect(_set_speed)
	hud.upgrade_requested.connect(_on_upgrade)
	hud.action_requested.connect(_on_action)
	hud.country_requested.connect(_focus_country)
	hud.panel_button_pressed.connect(_on_panel_button)
	hud.panel_closed.connect(_deselect)
	hud.request_refresh.connect(_refresh_ui)
	_show_menu()


func _process(delta: float) -> void:
	camera.ui_blockers = hud.blockers()
	if mode != "play" or speed == 0 or hud.has_overlay():
		return
	var seconds_per_week := data.num("time.seconds_per_week", 1.2)
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
	var on_continue: Variant = _continue_game if SaveStore.has_autosave() else null
	hud.show_overlay(Overlays.menu(_new_game, on_continue))


func _new_game() -> void:
	hud.close_overlay()
	var seed_value := int(Time.get_unix_time_from_system()) ^ Time.get_ticks_usec()
	sim = SimWorld.new_game(data, seed_value)
	_seen_news = sim.news_count
	_alerts.clear()
	_peak_reaction = 0.0
	mode = "choose"
	hud.set_mode(mode)
	hud.hide_country()
	map.select(null)
	map.apply_sim(sim)
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
	_peak_reaction = sim.reaction
	_start_play()


func _start_play() -> void:
	mode = "play"
	hud.set_mode(mode)
	_set_speed(1)
	map.apply_sim(sim)
	_refresh_ui()


# --- Ход партии -------------------------------------------------------------

func _advance_week() -> void:
	sim.step()
	_peak_reaction = maxf(_peak_reaction, sim.reaction)
	map.apply_sim(sim)
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
	hud.show_overlay(Overlays.ending(sim, _peak_reaction, _new_game))


func _set_speed(value: int) -> void:
	speed = value
	hud.top_bar.show_speed(speed)


# --- Действия игрока --------------------------------------------------------

func _on_map_tapped(world_pos: Vector2) -> void:
	if mode == "menu":
		return
	var c := data.world.country_at(world_pos, TAP_TOLERANCE_PX / camera.zoom_level())
	if c == null:
		_deselect()
		return
	_select(c)


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
	if mode == "play":
		hud.open_tab("actions")


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
		sim.start_movement(selected.id)
		_seen_news = sim.news_count
		_start_play()
		hud.show_country(selected, sim.state_of(selected.id), sim, _panel_button_text())
	elif mode == "play":
		hud.open_tab("actions")


func _on_upgrade(id: String) -> void:
	if mode == "play" and PlayerActions.buy_upgrade(sim, id):
		_seen_news = sim.news_count
		_refresh_ui()


func _on_action(id: String) -> void:
	if mode != "play" or selected == null:
		return
	var result := PlayerActions.perform(sim, id, sim.state_of(selected.id))
	if result["ok"]:
		map.apply_sim(sim)
		_collect_alerts()
		_refresh_ui()
		if sim.is_over():
			_finish()
		elif not _alerts.is_empty():
			_show_next_alert()


func _refresh_ui() -> void:
	if sim == null:
		return
	var cs := sim.state_of(selected.id) if selected != null else null
	hud.refresh(sim, cs, _panel_button_text())
