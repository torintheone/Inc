class_name ResultsScreen
extends Control
## Итоги партии: концовка, очки, главные цифры, графики влияния и Реакции, хроника.

signal new_game_requested

const LEFT_W := 430.0


func _init(sim: SimWorld) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_meta("paper", true)
	var bg := ColorRect.new()
	bg.color = MapPalette.PAPER
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 22)
	add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 26)
	margin.add_child(row)
	row.add_child(_left(sim))
	row.add_child(_right(sim))


func _left(sim: SimWorld) -> Control:
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(LEFT_W, 0)
	box.add_theme_constant_override("separation", 10)
	var key := "OUTCOME_" + sim.outcome
	var win := sim.outcome == SimWorld.OUTCOME_FEDERATION or sim.outcome == SimWorld.OUTCOME_WORLD_REVOLUTION
	var title := GameTheme.make_label(tr(key).to_upper(), 44, GameTheme.display_font(700),
		MapPalette.VERMILION if win else MapPalette.STEEL)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.custom_minimum_size.x = LEFT_W
	box.add_child(title)
	box.add_child(_text(tr(key + "_TEXT"), 17))
	if sim.line != "":
		box.add_child(GameTheme.make_label(tr("LINE_LABEL") % tr("LINE_" + sim.line), 15, GameTheme.BODY_BOLD_FONT, MapPalette.VERMILION))

	var score := sim.score()
	var tile := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = MapPalette.INK
	sb.set_content_margin_all(14)
	tile.add_theme_stylebox_override("panel", sb)
	var t := VBoxContainer.new()
	t.add_theme_constant_override("separation", 0)
	t.add_child(GameTheme.make_label(tr("RES_SCORE"), 14, GameTheme.BODY_BOLD_FONT, Color(MapPalette.PAPER, 0.7)))
	t.add_child(GameTheme.make_label(NumberFormat.decimal(score["total"], 0), 52, GameTheme.display_font(700), MapPalette.PAPER))
	var parts := tr("RES_SCORE_PARTS") % [score["share"], score["revolutions"], score["victory"], score["speed"]]
	var p := GameTheme.make_label(parts, 14, null, Color(MapPalette.PAPER, 0.85))
	p.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	p.custom_minimum_size.x = LEFT_W - 30.0
	t.add_child(p)
	tile.add_child(t)
	box.add_child(tile)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 4)
	var shares := sim.revolutionary_shares()
	_stat(grid, tr("RES_YEARS"), NumberFormat.decimal(float(sim.week) / 52.0, 1))
	_stat(grid, tr("ST_REVOLUTIONARY"), "%d (%s %d)" % [sim.revolutionary_count(), tr("RES_CORE"), sim.revolutionary_count("core")])
	_stat(grid, tr("ST_GDP_SHARE"), UiText.percent(shares.x * 100.0))
	_stat(grid, tr("ST_POP_SHARE"), UiText.percent(shares.y * 100.0))
	_stat(grid, tr("RES_PEAK_REACTION"), str(int(sim.peak_reaction)))
	_stat(grid, tr("RES_SOLIDARITY"), str(int(sim.solidarity_earned)))
	_stat(grid, tr("RES_PROTESTS"), "%d / %d" % [sim.protests_supported, sim.protests_supported + sim.protests_suppressed])
	_stat(grid, tr("RES_UPGRADES"), "%d / %d" % [sim.upgrades.size(), sim.data.upgrade_order.size()])
	box.add_child(grid)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)
	box.add_child(Overlays.button(tr("END_NEW"), func() -> void: new_game_requested.emit(), true))
	return box


func _right(sim: SimWorld) -> Control:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 6)
	var influence := PackedFloat32Array()
	var reaction := PackedFloat32Array()
	var years := PackedStringArray()
	for h in sim.history:
		influence.append(float(h["influenced"]) / 1.0e6)
		reaction.append(float(h["reaction"]))
		years.append(str(int(sim.data.num("time.start_year")) + int(h["week"]) / 52))
	box.add_child(GameTheme.make_label(tr("CHART_INFLUENCE"), 16, GameTheme.BODY_BOLD_FONT))
	var c1 := LineChart.new()
	c1.color = MapPalette.VERMILION
	c1.custom_minimum_size = Vector2(0, 150)
	c1.format = func(v: float) -> String: return NumberFormat.decimal(v, 0)
	c1.set_series(influence, years)
	box.add_child(c1)
	box.add_child(GameTheme.make_label(tr("CHART_REACTION"), 16, GameTheme.BODY_BOLD_FONT))
	var c2 := LineChart.new()
	c2.color = MapPalette.STEEL
	c2.y_max = 100.0
	c2.thresholds = PackedFloat32Array([20, 40, 60, 80])
	c2.custom_minimum_size = Vector2(0, 150)
	c2.set_series(reaction, years)
	box.add_child(c2)
	box.add_child(GameTheme.make_label(tr("RES_CHRONICLE"), 16, GameTheme.BODY_BOLD_FONT))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 4)
	scroll.add_child(list)
	for item in sim.chronicle:
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 10)
		var date := GameTheme.make_label(UiText.date(sim, int(item["week"])), 14, GameTheme.BODY_BOLD_FONT,
			MapPalette.VERMILION if item.get("important", false) else Color(MapPalette.INK, 0.6))
		date.custom_minimum_size.x = 120
		line.add_child(date)
		var text := GameTheme.make_label(UiText.news(item), 14)
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(text)
		list.add_child(line)
	box.add_child(scroll)
	return box


func _text(text: String, size_px: int) -> Label:
	var l := GameTheme.make_label(text, size_px)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = LEFT_W
	return l


func _stat(grid: GridContainer, name: String, value: String) -> void:
	var n := GameTheme.make_label(name, 15, null, Color(MapPalette.INK, 0.75))
	n.custom_minimum_size.x = 270
	n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	grid.add_child(n)
	var v := GameTheme.make_label(value, 15, GameTheme.BODY_BOLD_FONT)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(v)
