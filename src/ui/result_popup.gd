class_name ResultPopup
extends PanelContainer
## Карточка «Итог» сверху по центру: чем кончилось действие или событие и что изменилось.
## Не мешает игре: исчезает сама через несколько секунд или от касания.

const WIDTH := 560.0
const SHOW_SECONDS := 6.0

var _title: Label
var _body: Label
var _time := 0.0
## Печать на решении: «УСПЕХ», «ПРОВАЛ» или «ПРИНЯТО». Ставится с размаху и замирает.
var _stamp: Label
var _stamp_t := 1.0


func _init() -> void:
	custom_minimum_size = Vector2(WIDTH, 0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var sb := StyleBoxFlat.new()
	sb.bg_color = MapPalette.PAPER
	sb.border_color = MapPalette.INK
	sb.set_border_width_all(3)
	sb.set_content_margin_all(14)
	sb.shadow_color = Color(0, 0, 0, 0.25)
	sb.shadow_size = 8
	add_theme_stylebox_override("panel", sb)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 4)
	add_child(box)
	_title = GameTheme.make_label("", 22, GameTheme.display_font(600))
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.custom_minimum_size.x = WIDTH - 30.0
	box.add_child(_title)
	_body = GameTheme.make_label("", 16)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size.x = WIDTH - 30.0
	box.add_child(_body)
	_stamp = GameTheme.make_label("", 30, GameTheme.display_font(700), MapPalette.VERMILION)
	_stamp.top_level = true
	_stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb_stamp := StyleBoxFlat.new()
	sb_stamp.bg_color = Color(0, 0, 0, 0)
	sb_stamp.border_color = MapPalette.VERMILION
	sb_stamp.set_border_width_all(3)
	sb_stamp.set_corner_radius_all(4)
	sb_stamp.content_margin_left = 10
	sb_stamp.content_margin_right = 10
	_stamp.add_theme_stylebox_override("normal", sb_stamp)
	add_child(_stamp)
	hide()
	gui_input.connect(func(e: InputEvent) -> void:
		if (e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed):
			hide())


## success: true — успех (киноварь), false — неудача (сталь), null — без оценки.
func show_result(title: String, lines: PackedStringArray, success: Variant = null) -> void:
	_title.text = title
	var color := MapPalette.INK
	if success is bool:
		color = MapPalette.VERMILION if success else MapPalette.STEEL
	_title.add_theme_color_override("font_color", color)
	_body.text = " · ".join(lines) if not lines.is_empty() else TranslationServer.translate("REPORT_NOTHING")
	_time = SHOW_SECONDS
	modulate.a = 1.0
	reset_size()
	show()
	var stamp_color := color if success is bool else MapPalette.VERMILION
	_stamp.text = TranslationServer.translate("STAMP_OK" if success == true else ("STAMP_FAIL" if success == false else "STAMP_DONE"))
	_stamp.add_theme_color_override("font_color", stamp_color)
	(_stamp.get_theme_stylebox("normal") as StyleBoxFlat).border_color = stamp_color
	_stamp.reset_size()
	_stamp.pivot_offset = _stamp.size * 0.5
	_stamp_t = 0.0


func _process(delta: float) -> void:
	if visible and _stamp_t < 1.0:
		_stamp_t = minf(_stamp_t + delta / 0.25, 1.0)
	_stamp.visible = visible
	if visible:
		# Печать ложится в правый верхний угол карточки, чуть наискось, с размаху.
		_stamp.global_position = global_position + Vector2(size.x - _stamp.size.x - 14.0, -_stamp.size.y * 0.4)
		_stamp.rotation = -0.14
		var s := 1.0 + 1.2 * (1.0 - ease(_stamp_t, 0.3))
		_stamp.scale = Vector2(s, s)
		_stamp.modulate.a = minf(_stamp_t * 3.0, 1.0) * modulate.a
	if not visible:
		return
	_time -= delta
	modulate.a = clampf(_time / 0.6, 0.0, 1.0)
	if _time <= 0.0:
		hide()
