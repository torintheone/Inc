class_name Hud
extends CanvasLayer
## Интерфейс поверх карты: верхняя строка, нижние вкладки, боковая панель,
## панель страны, подсказка и окна поверх всего.

signal speed_selected(speed: int)
signal upgrade_requested(id: String)
signal action_requested(id: String)
signal country_requested(id: String)
signal panel_button_pressed
signal panel_closed
## Содержимое нужно обновить сейчас, не дожидаясь следующей недели.
signal request_refresh

const MARGIN := 12.0

var top_bar: TopBar
var bottom_bar: BottomBar
var drawer: SideDrawer
var panel: CountryPanel

var _root: Control
var _hint: Label
var _overlay: Control
var _fps_timer := 0.0
var _drawer_signature := ""


func setup(world: WorldData) -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = GameTheme.build()
	add_child(_root)

	top_bar = TopBar.new()
	top_bar.speed_selected.connect(func(s: int) -> void: speed_selected.emit(s))
	_root.add_child(top_bar)

	bottom_bar = BottomBar.new()
	bottom_bar.tab_selected.connect(toggle_tab)
	_root.add_child(bottom_bar)

	drawer = SideDrawer.new()
	drawer.hide()
	drawer.upgrade_requested.connect(func(id: String) -> void: upgrade_requested.emit(id))
	drawer.action_requested.connect(func(id: String) -> void: action_requested.emit(id))
	drawer.country_requested.connect(func(id: String) -> void: country_requested.emit(id))
	drawer.close_requested.connect(close_drawer)
	_root.add_child(drawer)

	panel = CountryPanel.new()
	panel.world = world
	panel.hide()
	panel.close_requested.connect(func() -> void: panel_closed.emit())
	panel.main_button_pressed.connect(func() -> void: panel_button_pressed.emit())
	_root.add_child(panel)

	_hint = GameTheme.make_label("", 22, GameTheme.BODY_BOLD_FONT, MapPalette.INK)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_color_override("font_outline_color", MapPalette.PAPER)
	_hint.add_theme_constant_override("outline_size", 8)
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_hint)

	get_viewport().size_changed.connect(_layout)
	panel.minimum_size_changed.connect(_layout, CONNECT_DEFERRED)
	_layout()


## Элементы, касания по которым карта не обрабатывает.
func blockers() -> Array[Control]:
	var list: Array[Control] = [top_bar, bottom_bar, drawer, panel]
	if _overlay != null:
		list.append(_overlay)
	return list


## Режим партии: "menu", "choose" (выбор стартовой страны), "play", "ended".
func set_mode(mode: String) -> void:
	var playing := mode == "play" or mode == "ended"
	top_bar.visible = mode != "menu"
	bottom_bar.visible = playing
	if not playing:
		close_drawer()
	_hint.text = tr("CHOOSE_HINT") if mode == "choose" else ""
	_hint.visible = mode == "choose"
	_layout()


func toggle_tab(tab: String) -> void:
	if drawer.visible and drawer.tab == tab:
		close_drawer()
	else:
		open_tab(tab)


func open_tab(tab: String) -> void:
	drawer.tab = tab
	drawer.show()
	bottom_bar.show_tab(tab)
	_drawer_signature = ""
	request_refresh.emit()


func close_drawer() -> void:
	drawer.hide()
	drawer.tab = ""
	bottom_bar.show_tab("")


## Обновить всё, что зависит от партии. selected — выбранная страна или null.
func refresh(sim: SimWorld, selected: CountryState, panel_button: String) -> void:
	top_bar.refresh(sim)
	if not sim.news.is_empty():
		bottom_bar.show_news("%s · %s" % [UiText.date(sim, int(sim.news[-1]["week"])), UiText.news(sim.news[-1])])
	if drawer.visible:
		var sig := _signature(sim, selected)
		if sig != _drawer_signature:
			_drawer_signature = sig
			drawer.refresh(sim, selected)
	if panel.visible and selected != null:
		panel.show_country(selected.country, selected, sim, panel_button)


func show_country(c: Country, cs: CountryState, sim: SimWorld, button_text: String) -> void:
	panel.show_country(c, cs, sim, button_text)
	_layout()


func hide_country() -> void:
	panel.hide()


## Окно поверх всего (меню, сообщение, итог). Предыдущее закрывается.
func show_overlay(overlay: Control) -> void:
	close_overlay()
	_overlay = overlay
	_root.add_child(overlay)


func close_overlay() -> void:
	if _overlay != null:
		_overlay.queue_free()
		_overlay = null


func has_overlay() -> bool:
	return _overlay != null


## Подпись изменилась — содержимое боковой панели нужно перестроить. Так кнопки не
## пересоздаются каждую неделю и не теряют нажатие.
func _signature(sim: SimWorld, cs: CountryState) -> String:
	match drawer.tab:
		"upgrades":
			var parts := PackedStringArray()
			for id in sim.data.upgrade_order:
				parts.append(",".join(PlayerActions.upgrade_blockers(sim, id)))
			return "|".join(parts)
		"actions":
			if cs == null:
				return "none"
			var parts := PackedStringArray([cs.country.id])
			for id in sim.data.country_action_order:
				parts.append(",".join(PlayerActions.action_blockers(sim, id, cs)))
				parts.append(str(int(PlayerActions.action_chance(sim, id, cs) * 20.0)))
			return "|".join(parts)
		"news":
			return str(sim.news_count)
		_:
			return "%d|%d" % [sim.week / 13, sim.revolutionary_count()]


func _process(delta: float) -> void:
	_fps_timer -= delta
	if _fps_timer <= 0.0:
		_fps_timer = 0.5
		top_bar.set_fps(Engine.get_frames_per_second())


func _layout() -> void:
	if _root == null:
		return
	var view := _root.get_viewport_rect().size
	var insets := _safe_insets(view)
	var left := insets.x + MARGIN
	var right := view.x - insets.z - MARGIN
	top_bar.position = Vector2(left, insets.y + MARGIN * 0.5)
	top_bar.size = Vector2(right - left, 0.0)
	var top := top_bar.position.y + top_bar.size.y + MARGIN if top_bar.visible else insets.y + MARGIN
	bottom_bar.size = Vector2(right - left, 0.0)
	bottom_bar.position = Vector2(left, view.y - insets.w - MARGIN * 0.5 - bottom_bar.size.y)
	var bottom := bottom_bar.position.y - MARGIN if bottom_bar.visible else view.y - insets.w - MARGIN
	drawer.position = Vector2(left, top)
	drawer.size = Vector2(SideDrawer.WIDTH, bottom - top)
	panel.size = Vector2(CountryPanel.WIDTH, 0.0)   # высота по содержимому
	panel.position = Vector2(right - CountryPanel.WIDTH, top)
	_hint.size = Vector2(view.x, 0.0)
	_hint.position = Vector2(0.0, top + 4.0)


## Отступы от выреза камеры и системных панелей: (лево, верх, право, низ) в координатах интерфейса.
func _safe_insets(view: Vector2) -> Vector4:
	if not OS.has_feature("mobile"):
		return Vector4.ZERO
	var window := Vector2(DisplayServer.window_get_size())
	if window.x <= 0.0 or window.y <= 0.0:
		return Vector4.ZERO
	var safe := Rect2(DisplayServer.get_display_safe_area())
	var k := view / window
	return Vector4(safe.position.x * k.x, safe.position.y * k.y,
		(window.x - safe.end.x) * k.x, (window.y - safe.end.y) * k.y)
