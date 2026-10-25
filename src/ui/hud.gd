class_name Hud
extends CanvasLayer
## Интерфейс поверх карты: заголовок, счётчик кадров, подсказка, панель страны.

const MARGIN := 16.0

var panel: CountryPanel

var _root: Control
var _title: Control
var _fps: Label
var _hint: Label
var _fps_timer := 0.0


func setup(world: WorldData) -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = GameTheme.build()
	add_child(_root)

	var title_box := VBoxContainer.new()
	title_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_box.add_theme_constant_override("separation", -4)
	title_box.add_child(GameTheme.make_label(tr("GAME_TITLE").to_upper(), 30, GameTheme.display_font(600), MapPalette.VERMILION))
	var version := str(ProjectSettings.get_setting("application/config/version", "0.0.0"))
	title_box.add_child(GameTheme.make_label(tr("STAGE_LABEL") % version, GameTheme.SMALL_SIZE, null, MapPalette.INK))
	_root.add_child(title_box)
	_title = title_box

	_fps = GameTheme.make_label("", GameTheme.SMALL_SIZE, GameTheme.BODY_BOLD_FONT)
	_fps.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_fps.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_fps)

	_hint = GameTheme.make_label(tr("HINT_TAP_COUNTRY"), GameTheme.BODY_SIZE)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.add_theme_color_override("font_outline_color", MapPalette.PAPER)
	_hint.add_theme_constant_override("outline_size", 6)
	_root.add_child(_hint)

	panel = CountryPanel.new()
	panel.world = world
	panel.hide()
	_root.add_child(panel)

	get_viewport().size_changed.connect(_layout)
	# Высота панели зависит от переносов строк: подгоняем её, когда меняется содержимое.
	panel.minimum_size_changed.connect(_fit_panel, CONNECT_DEFERRED)
	_layout()


func show_country(c: Country) -> void:
	_hint.hide()
	panel.show_country(c)
	_layout()


func hide_country() -> void:
	panel.hide()


func _process(delta: float) -> void:
	_fps_timer -= delta
	if _fps_timer <= 0.0:
		_fps_timer = 0.5
		_fps.text = tr("FPS") % Engine.get_frames_per_second()


func _layout() -> void:
	var view := _root.get_viewport_rect().size
	var insets := _safe_insets(view)
	_title.position = Vector2(insets.x + MARGIN, insets.y + MARGIN * 0.5)
	_fps.position = Vector2(view.x - insets.z - MARGIN - 200.0, insets.y + MARGIN * 0.5)
	_fps.size = Vector2(200.0, 24.0)
	_hint.size = Vector2(minf(720.0, view.x - 2.0 * MARGIN), 0.0)
	_hint.position = Vector2((view.x - _hint.size.x) * 0.5, view.y - insets.w - MARGIN - 56.0)
	var top := insets.y + MARGIN + 28.0
	panel.position = Vector2(view.x - insets.z - MARGIN - CountryPanel.WIDTH, top)
	_fit_panel()


func _fit_panel() -> void:
	panel.size = Vector2(CountryPanel.WIDTH, 0.0)   # высота по содержимому


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
