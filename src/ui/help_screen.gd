class_name HelpScreen
extends Control
## Справка: что значат цвета карты и пузырьки, откуда берутся ресурсы, как победить.

signal closed


func _init(first_time: bool = false) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(MapPalette.INK, 0.5)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(1180, 0)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	box.add_child(GameTheme.make_label(tr("HELP_TITLE").to_upper(), 32, GameTheme.display_font(600), MapPalette.VERMILION))
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 24)
	box.add_child(cols)

	var map_col := _column(tr("HELP_MAP"))
	map_col.add_child(_legend(_Swatch.new("gradient"), tr("HELP_MAP_INFLUENCE")))
	map_col.add_child(_legend(_Swatch.new("revolution"), tr("HELP_MAP_REVOLUTION")))
	map_col.add_child(_legend(_Swatch.new("window"), tr("HELP_MAP_WINDOW")))
	map_col.add_child(_legend(_Swatch.new("neutral"), tr("HELP_MAP_NEUTRAL")))
	map_col.add_child(_legend(_Swatch.new("solidarity"), tr("HELP_BUBBLE_SOLIDARITY")))
	map_col.add_child(_legend(_Swatch.new("protest"), tr("HELP_BUBBLE_PROTEST")))
	cols.add_child(map_col)

	var res := _column(tr("HELP_RESOURCES"))
	res.add_child(_legend(Icons.IconView.new("solidarity", MapPalette.VERMILION, 30.0), tr("HELP_SOLIDARITY")))
	res.add_child(_legend(Icons.IconView.new("cadres", MapPalette.INK, 30.0), tr("HELP_CADRES")))
	res.add_child(_paragraph(tr("HELP_SPONTANEOUS")))
	cols.add_child(res)

	var win := _column(tr("HELP_WIN"))
	win.add_child(_paragraph(tr("HELP_REV")))
	win.add_child(_paragraph(tr("HELP_REACTION")))
	win.add_child(_paragraph(tr("HELP_GOAL")))
	cols.add_child(win)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_child(Overlays.button(tr("HELP_START" if first_time else "ALERT_OK"), func() -> void: closed.emit(), true))
	box.add_child(row)


func _column(title: String) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(360, 0)
	col.add_theme_constant_override("separation", 10)
	col.add_child(GameTheme.make_label(title, 20, GameTheme.BODY_BOLD_FONT))
	return col


func _legend(mark: Control, text: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	mark.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(mark)
	var l := GameTheme.make_label(text, 15)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 300
	row.add_child(l)
	return row


func _paragraph(text: String) -> Label:
	var l := GameTheme.make_label(text, 15)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 360
	return l


## Образец цвета карты или пузырька для легенды.
class _Swatch:
	extends Control
	var kind := ""

	func _init(p_kind: String) -> void:
		kind = p_kind
		custom_minimum_size = Vector2(44, 30)

	func _draw() -> void:
		var r := Rect2(Vector2(2, 4), Vector2(40, 22))
		match kind:
			"gradient":
				for i in 8:
					var t := float(i) / 7.0
					draw_rect(Rect2(r.position + Vector2(r.size.x * i / 8.0, 0), Vector2(r.size.x / 8.0 + 0.5, r.size.y)),
						MapPalette.LAND.lerp(MapPalette.VERMILION, 0.06 + 0.86 * t))
			"revolution":
				draw_rect(r, MapPalette.REVOLUTIONARY_LAND)
			"window":
				draw_rect(r, MapPalette.LAND.lerp(MapPalette.VERMILION, 0.4))
				draw_rect(r, MapPalette.OCHRE, false, 3.0)
			"neutral":
				draw_rect(r, MapPalette.NEUTRAL_LAND)
			"solidarity", "protest":
				BubbleLayer.draw_bubble(self, kind, Vector2(22, 15), 14.0, 1.0)
		if kind in ["gradient", "revolution", "neutral"]:
			draw_rect(r, MapPalette.BORDER, false, 1.0)
