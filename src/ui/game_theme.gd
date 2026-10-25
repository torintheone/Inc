class_name GameTheme
extends RefCounted
## Оформление интерфейса: шрифты PT Sans и Oswald (OFL), бумажные панели.

const BODY_FONT := preload("res://assets/fonts/PT_Sans-Web-Regular.ttf")
const BODY_BOLD_FONT := preload("res://assets/fonts/PT_Sans-Web-Bold.ttf")
const DISPLAY_FONT := preload("res://assets/fonts/Oswald[wght].ttf")

const BODY_SIZE := 18
const SMALL_SIZE := 14


static func build() -> Theme:
	var theme := Theme.new()
	theme.default_font = BODY_FONT
	theme.default_font_size = BODY_SIZE

	theme.set_color("font_color", "Label", MapPalette.INK)

	var panel := StyleBoxFlat.new()
	panel.bg_color = MapPalette.PAPER
	panel.border_color = MapPalette.INK
	panel.set_border_width_all(2)
	panel.set_content_margin_all(18)
	panel.shadow_color = Color(0, 0, 0, 0.18)
	panel.shadow_size = 6
	panel.shadow_offset = Vector2(3, 3)
	theme.set_stylebox("panel", "PanelContainer", panel)

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0, 0, 0, 0)
	normal.border_color = MapPalette.INK
	normal.set_border_width_all(2)
	normal.set_content_margin_all(6)
	normal.content_margin_left = 12
	normal.content_margin_right = 12
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = MapPalette.INK
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.border_color = Color(MapPalette.INK, 0.25)
	theme.set_stylebox("normal", "Button", normal)
	theme.set_stylebox("hover", "Button", normal)
	theme.set_stylebox("pressed", "Button", pressed)
	theme.set_stylebox("disabled", "Button", disabled)
	theme.set_color("font_disabled_color", "Button", Color(MapPalette.INK, 0.35))
	theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	theme.set_color("font_color", "Button", MapPalette.INK)
	theme.set_color("font_hover_color", "Button", MapPalette.VERMILION)
	theme.set_color("font_pressed_color", "Button", MapPalette.PAPER)
	theme.set_font("font", "Button", BODY_BOLD_FONT)

	var sep := StyleBoxLine.new()
	sep.color = Color(MapPalette.INK, 0.35)
	sep.thickness = 1
	theme.set_stylebox("separator", "HSeparator", sep)
	theme.set_constant("separation", "HSeparator", 14)
	return theme


## Плашка верхней и нижней строки: тоньше обычной панели, чтобы карте оставалось больше места.
static func bar_panel() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = MapPalette.PAPER
	sb.border_color = MapPalette.INK
	sb.set_border_width_all(2)
	sb.content_margin_left = 14
	sb.content_margin_right = 10
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	sb.shadow_color = Color(0, 0, 0, 0.18)
	sb.shadow_size = 4
	sb.shadow_offset = Vector2(2, 2)
	return sb


## Шрифт заголовков: Oswald нужной насыщенности.
static func display_font(weight: int = 600) -> Font:
	var f := FontVariation.new()
	f.base_font = DISPLAY_FONT
	f.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
	return f


static func make_label(text: String, size: int = BODY_SIZE, font: Font = null, color: Color = MapPalette.INK) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	if font != null:
		label.add_theme_font_override("font", font)
	return label
