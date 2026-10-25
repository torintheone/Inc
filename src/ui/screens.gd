class_name Screens
extends RefCounted
## Общие детали полноэкранных экранов: тёмная полоса заголовка, кнопки, кружки.


## Плашка заголовка экрана.
static func band(color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.content_margin_left = 24
	sb.content_margin_right = 16
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb


## Кнопка для тёмного заголовка: светлая рамка и текст.
static func light_button(text: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 40)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0, 0, 0, 0)
	normal.border_color = MapPalette.PAPER
	normal.set_border_width_all(2)
	normal.content_margin_left = 14
	normal.content_margin_right = 14
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = MapPalette.PAPER
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", normal)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_color_override("font_color", MapPalette.PAPER)
	b.add_theme_color_override("font_hover_color", MapPalette.OCHRE)
	b.add_theme_color_override("font_pressed_color", MapPalette.INK)
	b.pressed.connect(on_press)
	return b


## Крестик «закрыть». on_dark — для тёмного заголовка.
static func close_button(on_press: Callable, on_dark: bool = false) -> Button:
	var b := light_button("×", on_press) if on_dark else Button.new()
	if not on_dark:
		b.text = "×"
		b.pressed.connect(on_press)
	b.custom_minimum_size = Vector2(52, 48)
	b.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	b.add_theme_font_size_override("font_size", 28)
	b.tooltip_text = TranslationServer.translate("BTN_CLOSE")
	return b


## Кнопка внутри прокрутки: касание пропускается к прокрутке, чтобы список листался
## с любого места, а нажатие срабатывает, только если список при этом не сдвинули.
static func scroll_safe(button: Button, scroll: ScrollContainer, on_press: Callable) -> void:
	button.mouse_filter = Control.MOUSE_FILTER_PASS
	button.button_down.connect(func() -> void:
		button.set_meta("scroll_at", Vector2(scroll.scroll_horizontal, scroll.scroll_vertical)))
	button.pressed.connect(func() -> void:
		var at: Vector2 = button.get_meta("scroll_at", Vector2(scroll.scroll_horizontal, scroll.scroll_vertical))
		if at.distance_to(Vector2(scroll.scroll_horizontal, scroll.scroll_vertical)) <= 8.0:
			on_press.call())


## Цветной кружок заданного диаметра — подложка для значка.
static func disc(color: Color, diameter: float) -> Control:
	var c := _Disc.new()
	c.color = color
	c.custom_minimum_size = Vector2(diameter, diameter)
	c.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	return c


class _Disc:
	extends Control
	var color := MapPalette.VERMILION

	func _draw() -> void:
		draw_circle(size * 0.5, minf(size.x, size.y) * 0.5, color)
