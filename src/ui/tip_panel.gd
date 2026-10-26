class_name TipPanel
extends Control
## Подсказка обучения: карточка сверху по центру и стрелка к тому, о чём речь (пузырёк, кнопка,
## страна). Карту под ней можно трогать — например, коснуться того самого пузырька.

signal closed(disable_all: bool)

const WIDTH := 560.0

var target: Variant = null
var _card: PanelContainer
var _text: Label


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card = PanelContainer.new()
	_card.custom_minimum_size = Vector2(WIDTH, 0)
	_card.mouse_filter = Control.MOUSE_FILTER_STOP
	var sb := StyleBoxFlat.new()
	sb.bg_color = MapPalette.PAPER
	sb.border_color = MapPalette.VERMILION
	sb.set_border_width_all(3)
	sb.set_content_margin_all(14)
	sb.shadow_color = Color(0, 0, 0, 0.25)
	sb.shadow_size = 8
	_card.add_theme_stylebox_override("panel", sb)
	add_child(_card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	_card.add_child(box)
	var head := GameTheme.make_label(tr("TUT_TITLE").to_upper(), 15, GameTheme.BODY_BOLD_FONT, MapPalette.VERMILION)
	box.add_child(head)
	_text = GameTheme.make_label("", 18)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size.x = WIDTH - 30.0
	box.add_child(_text)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 10)
	var off := Button.new()
	off.text = tr("TUT_DISABLE")
	off.custom_minimum_size = Vector2(0, 44)
	off.pressed.connect(func() -> void: closed.emit(true))
	row.add_child(off)
	row.add_child(Overlays.button(tr("TUT_OK"), func() -> void: closed.emit(false), true))
	box.add_child(row)


func show_tip(text: String, p_target: Variant, top: float) -> void:
	_text.text = text
	target = p_target
	_card.reset_size()
	_card.position = Vector2((size.x - WIDTH) * 0.5, top)
	show()
	queue_redraw()


func card() -> Control:
	return _card


func _process(_delta: float) -> void:
	if visible and target != null:
		queue_redraw()


func _draw() -> void:
	if not (target is Vector2):
		return
	var to: Vector2 = target
	var from := _card.position + Vector2(_card.size.x * 0.5, _card.size.y)
	if to.y < from.y:
		from.y = _card.position.y
	var dir := (to - from).normalized()
	var end := to - dir * 26.0
	draw_line(from, end, MapPalette.VERMILION, 4.0, true)
	var side := dir.orthogonal() * 10.0
	draw_colored_polygon(PackedVector2Array([end + dir * 16.0, end + side, end - side]), MapPalette.VERMILION)
	draw_arc(to, 24.0, 0.0, TAU, 32, MapPalette.VERMILION, 3.0, true)
