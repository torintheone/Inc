class_name ResultPopup
extends PanelContainer
## Карточка «Итог» сверху по центру: чем кончилось действие или событие и что изменилось.
## Не мешает игре: исчезает сама через несколько секунд или от касания.

const WIDTH := 560.0
const SHOW_SECONDS := 6.0

var _title: Label
var _body: Label
var _time := 0.0


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


func _process(delta: float) -> void:
	if not visible:
		return
	_time -= delta
	modulate.a = clampf(_time / 0.6, 0.0, 1.0)
	if _time <= 0.0:
		hide()
