class_name Hud
extends CanvasLayer
## Интерфейс поверх карты: верхняя строка, нижние вкладки, боковая панель событий
## и статистики, панель страны, подсказка и экраны поверх всего (развитие, действия,
## линии, справка, итоги, сообщения).

signal speed_selected(speed: int)
signal development_requested
signal actions_requested
signal help_requested
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
var _toast: Label
var _toast_time := 0.0
var _overlay: Control
var _overlay_content: Control
var _drawer_signature := ""


func setup() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = GameTheme.build()
	add_child(_root)

	top_bar = TopBar.new()
	top_bar.speed_selected.connect(func(s: int) -> void: speed_selected.emit(s))
	top_bar.help_requested.connect(func() -> void: help_requested.emit())
	_root.add_child(top_bar)

	bottom_bar = BottomBar.new()
	bottom_bar.tab_selected.connect(_on_tab)
	_root.add_child(bottom_bar)

	drawer = SideDrawer.new()
	drawer.hide()
	drawer.country_requested.connect(func(id: String) -> void: country_requested.emit(id))
	drawer.close_requested.connect(close_drawer)
	_root.add_child(drawer)

	panel = CountryPanel.new()
	panel.hide()
	panel.close_requested.connect(func() -> void: panel_closed.emit())
	panel.main_button_pressed.connect(func() -> void: panel_button_pressed.emit())
	_root.add_child(panel)

	_hint = _floating_label(22)
	_root.add_child(_hint)
	_toast = _floating_label(20)
	_toast.hide()
	_root.add_child(_toast)

	get_viewport().size_changed.connect(_layout)
	panel.minimum_size_changed.connect(_layout, CONNECT_DEFERRED)
	_layout()


func _floating_label(size_px: int) -> Label:
	var l := GameTheme.make_label("", size_px, GameTheme.BODY_BOLD_FONT, MapPalette.INK)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_outline_color", MapPalette.PAPER)
	l.add_theme_constant_override("outline_size", 8)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


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


func _on_tab(tab: String) -> void:
	match tab:
		"upgrades":
			bottom_bar.show_tab("")
			development_requested.emit()
		"actions":
			bottom_bar.show_tab("")
			actions_requested.emit()
		_:
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


## Короткое сообщение посреди экрана, например «Выберите страну».
func toast(text: String, seconds: float = 2.5) -> void:
	_toast.text = text
	_toast.show()
	_toast_time = seconds
	_layout()


## Обновить всё, что зависит от партии. selected — выбранная страна или null.
func refresh(sim: SimWorld, selected: CountryState, panel_button: String) -> void:
	top_bar.refresh(sim)
	if not sim.news.is_empty():
		bottom_bar.show_news("%s · %s" % [UiText.date(sim, int(sim.news[-1]["week"])), UiText.news(sim.news[-1])])
	if drawer.visible:
		var sig := _signature(sim)
		if sig != _drawer_signature:
			_drawer_signature = sig
			drawer.refresh(sim)
	if panel.visible and selected != null:
		panel.show_country(selected.country, selected, sim, panel_button)


func show_country(c: Country, cs: CountryState, sim: SimWorld, button_text: String) -> void:
	panel.show_country(c, cs, sim, button_text)
	_layout()


func hide_country() -> void:
	panel.hide()


## Экран поверх всего (меню, развитие, действия, сообщение, итог). Предыдущий закрывается.
## Содержимое не заходит под вырез камеры; фон бумаги — на весь экран.
func show_overlay(overlay: Control) -> void:
	close_overlay()
	var holder := Control.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_STOP
	if overlay.has_meta("paper"):
		var bg := ColorRect.new()
		bg.color = MapPalette.PAPER
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		holder.add_child(bg)
	var insets := _safe_insets(_root.get_viewport_rect().size)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.offset_left = insets.x
	overlay.offset_top = insets.y
	overlay.offset_right = -insets.z
	overlay.offset_bottom = -insets.w
	holder.add_child(overlay)
	_overlay = holder
	_overlay_content = overlay
	_root.add_child(holder)


func close_overlay() -> void:
	if _overlay != null:
		_overlay.queue_free()
		_overlay = null
		_overlay_content = null


func has_overlay() -> bool:
	return _overlay != null


## Экран, который сейчас открыт поверх карты (или null).
func overlay() -> Control:
	return _overlay_content


## Подпись изменилась — содержимое боковой панели нужно перестроить. Так список не
## пересоздаётся каждую неделю и не сбрасывает прокрутку.
func _signature(sim: SimWorld) -> String:
	match drawer.tab:
		"news":
			return str(sim.news_count)
		_:
			return "%d|%d" % [sim.week / 4, sim.revolutionary_count()]


func _process(delta: float) -> void:
	if _toast_time > 0.0:
		_toast_time -= delta
		_toast.modulate.a = clampf(_toast_time / 0.5, 0.0, 1.0)
		if _toast_time <= 0.0:
			_toast.hide()


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
	panel.size = Vector2(CountryPanel.WIDTH, bottom - top)
	panel.position = Vector2(right - CountryPanel.WIDTH, top)
	_hint.size = Vector2(view.x, 0.0)
	_hint.position = Vector2(0.0, top + 4.0)
	_toast.size = Vector2(view.x, 0.0)
	_toast.position = Vector2(0.0, view.y * 0.42)


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
