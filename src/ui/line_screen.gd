class_name LineScreen
extends Control
## Выбор стратегической линии: пять карточек с сильными и слабыми сторонами.
## В начале партии линию выбирают один раз; позже её можно сменить — один раз,
## ценой половины организованности.

signal line_chosen(id: String)
signal close_requested

## Значок для каждой линии, пока нет эмблем из Grok.
var _scroll: ScrollContainer

const ICONS := {"vanguard": "flag", "councils": "organization", "syndicalism": "struggle",
	"mass_party": "agitation", "peoples_war": "defense"}


## changing — смена линии в середине партии (с предупреждением и кнопкой «Отмена»).
func _init(data: GameData, current: String = "", changing: bool = false) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_meta("paper", true)
	var bg := ColorRect.new()
	bg.color = MapPalette.PAPER
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)

	var bar := PanelContainer.new()
	bar.custom_minimum_size = Vector2(0, 64)
	bar.add_theme_stylebox_override("panel", Screens.band(MapPalette.INK))
	var head := HBoxContainer.new()
	bar.add_child(head)
	var title := GameTheme.make_label(tr("LINE_CHANGE_TITLE" if changing else "LINE_CHOOSE_TITLE").to_upper(), 32,
		GameTheme.display_font(600), MapPalette.PAPER)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	if changing:
		head.add_child(Screens.close_button(func() -> void: close_requested.emit(), true))
	root.add_child(bar)

	var margin := MarginContainer.new()
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 18)
	root.add_child(margin)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	margin.add_child(body)
	var intro := GameTheme.make_label(tr("LINE_CHANGE_INTRO" if changing else "LINE_CHOOSE_INTRO"), 17)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(intro)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(row)
	_scroll = scroll
	for id in data.line_order:
		row.add_child(_card(data, id, id == current, changing))


func _card(data: GameData, id: String, is_current: bool, changing: bool) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(236, 0)
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = MapPalette.PAPER
	sb.border_color = MapPalette.VERMILION if is_current else MapPalette.INK
	sb.set_border_width_all(4 if is_current else 2)
	sb.set_content_margin_all(14)
	card.add_theme_stylebox_override("panel", sb)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	card.add_child(box)

	var emblem := Screens.disc(MapPalette.VERMILION, 64.0)
	emblem.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var icon := Icons.IconView.new(ICONS.get(id, "organization"), MapPalette.PAPER, 52.0, MapPalette.VERMILION)
	icon.position = Vector2(6, 6)
	emblem.add_child(icon)
	box.add_child(emblem)
	var name := GameTheme.make_label(tr("LINE_" + id).to_upper(), 22, GameTheme.display_font(600))
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name.custom_minimum_size.x = 206
	box.add_child(name)
	var current := GameTheme.make_label(tr("LINE_" + id + "_CURRENT"), 13, null, Color(MapPalette.INK, 0.6))
	current.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	current.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	current.custom_minimum_size.x = 206
	box.add_child(current)
	box.add_child(_section(tr("LINE_PLUS"), tr("LINE_" + id + "_PLUS"), MapPalette.VERMILION))
	box.add_child(_section(tr("LINE_MINUS"), tr("LINE_" + id + "_MINUS"), MapPalette.STEEL))
	box.add_child(_section(tr("LINE_WHERE"), tr("LINE_" + id + "_WHERE"), MapPalette.INK))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)
	if is_current:
		var mark := GameTheme.make_label(tr("LINE_CURRENT_MARK"), 16, GameTheme.BODY_BOLD_FONT, MapPalette.VERMILION)
		mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(mark)
	else:
		var b := Overlays.button(tr("LINE_PICK_CHANGE" if changing else "LINE_PICK"), func() -> void: pass, true)
		Screens.scroll_safe(b, _scroll, func() -> void: line_chosen.emit(id))
		b.custom_minimum_size = Vector2(0, 50)
		box.add_child(b)
	return card


func _section(title: String, text: String, color: Color) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	box.add_child(GameTheme.make_label(title, 13, GameTheme.BODY_BOLD_FONT, color))
	var l := GameTheme.make_label(text, 14)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 206
	box.add_child(l)
	return box
