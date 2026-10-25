class_name SideDrawer
extends PanelContainer
## Боковая панель с содержимым вкладок «События» и «Статистика».
## Развитие и действия открываются отдельными экранами во весь экран.

signal close_requested
signal country_requested(id: String)

const WIDTH := 440.0

var tab := ""
var _title: Label
var _scroll: ScrollContainer
var _body: VBoxContainer


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(WIDTH, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	add_child(box)
	var header := HBoxContainer.new()
	box.add_child(header)
	_title = GameTheme.make_label("", 26, GameTheme.display_font(600))
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title)
	var close := Button.new()
	close.text = "×"
	close.custom_minimum_size = Vector2(44, 44)
	close.add_theme_font_size_override("font_size", 24)
	close.pressed.connect(func() -> void: close_requested.emit())
	header.add_child(close)
	box.add_child(HSeparator.new())
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(_scroll)
	# Отступ справа — под полосу прокрутки.
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_right", 16)
	_scroll.add_child(margin)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 12)
	margin.add_child(_body)


## Перестроить содержимое вкладки.
func refresh(sim: SimWorld) -> void:
	for child in _body.get_children():
		_body.remove_child(child)
		child.queue_free()
	_title.text = tr("TAB_" + tab)
	match tab:
		"news":
			_build_news(sim)
		"stats":
			_build_stats(sim)


func _build_news(sim: SimWorld) -> void:
	if sim.news.is_empty():
		_body.add_child(_paragraph(tr("NEWS_EMPTY")))
		return
	for i in range(sim.news.size() - 1, maxi(sim.news.size() - 60, 0) - 1, -1):
		var item: Dictionary = sim.news[i]
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 0)
		var color := MapPalette.VERMILION if item.get("important", false) else Color(MapPalette.INK, 0.6)
		row.add_child(GameTheme.make_label(UiText.date(sim, int(item["week"])), GameTheme.SMALL_SIZE, GameTheme.BODY_BOLD_FONT, color))
		var text := _paragraph(UiText.news(item))
		row.add_child(text)
		var cid: String = item.get("country", "")
		if cid != "":
			text.mouse_filter = Control.MOUSE_FILTER_STOP
			text.gui_input.connect(func(e: InputEvent) -> void:
				if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
					country_requested.emit(cid))
		_body.add_child(row)


func _build_stats(sim: SimWorld) -> void:
	var shares := sim.revolutionary_shares()
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 8)
	_stat(grid, tr("ST_DATE"), "%d" % (sim.week / 52 + 1))
	if sim.line != "":
		_stat(grid, tr("ST_LINE"), tr("LINE_" + sim.line))
	_stat(grid, tr("ST_PHASE"), tr("PHASE_" + sim.phase_id()))
	_stat(grid, tr("ST_DEPTH"), NumberFormat.decimal(sim.depth, 2))
	_stat(grid, tr("ST_CRISES"), str(sim.crisis_weeks.size()))
	_stat(grid, tr("ST_INFLUENCED"), NumberFormat.population(sim.influenced_people()))
	_stat(grid, tr("ST_ARISTOCRACY"), UiText.percent(sim.core_aristocracy * 100.0))
	_stat(grid, tr("ST_REVOLUTIONARY"), str(sim.revolutionary_count()))
	_stat(grid, tr("ST_CORE"), "%d / %d" % [sim.revolutionary_count("core"), int(sim.data.num("outcome.world_revolution_core"))])
	_body.add_child(grid)
	_body.add_child(_goal_bar(tr("ST_GDP_SHARE"), shares.x * 100.0))
	_body.add_child(_goal_bar(tr("ST_POP_SHARE"), shares.y * 100.0))
	_body.add_child(_paragraph(tr("ST_GOAL"), GameTheme.SMALL_SIZE))
	var windows := PackedStringArray()
	for cs in sim.countries:
		if cs.window_left >= 0 and not cs.is_revolutionary():
			windows.append(cs.country.name_ru)
	_body.add_child(_paragraph("%s: %s" % [tr("ST_WINDOWS"), ", ".join(windows) if not windows.is_empty() else tr("ST_NONE")]))
	var influence := PackedFloat32Array()
	var reaction := PackedFloat32Array()
	var years := PackedStringArray()
	for h in sim.history:
		influence.append(float(h["influenced"]) / 1.0e6)
		reaction.append(float(h["reaction"]))
		years.append(str(int(sim.data.num("time.start_year")) + int(h["week"]) / 52))
	_body.add_child(GameTheme.make_label(tr("CHART_INFLUENCE"), 16, GameTheme.BODY_BOLD_FONT))
	var c1 := LineChart.new()
	c1.custom_minimum_size = Vector2(WIDTH - 76.0, 140)
	c1.format = func(v: float) -> String: return NumberFormat.decimal(v, 0)
	c1.set_series(influence, years)
	_body.add_child(c1)
	_body.add_child(GameTheme.make_label(tr("CHART_REACTION"), 16, GameTheme.BODY_BOLD_FONT))
	var c2 := LineChart.new()
	c2.custom_minimum_size = Vector2(WIDTH - 76.0, 140)
	c2.color = MapPalette.STEEL
	c2.y_max = 100.0
	c2.thresholds = PackedFloat32Array([20, 40, 60, 80])
	c2.set_series(reaction, years)
	_body.add_child(c2)


func _paragraph(text: String, size: int = GameTheme.BODY_SIZE) -> Label:
	var l := GameTheme.make_label(text, size)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = WIDTH - 76.0
	return l


func _stat(grid: GridContainer, name: String, value: String) -> void:
	var n := GameTheme.make_label(name, 16, null, Color(MapPalette.INK, 0.75))
	n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	n.custom_minimum_size.x = 240
	grid.add_child(n)
	var v := GameTheme.make_label(value, 16, GameTheme.BODY_BOLD_FONT)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(v)


func _goal_bar(name: String, value: float) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	box.add_child(GameTheme.make_label("%s: %s" % [name, UiText.percent(value)], 16))
	var m := Meter.new(MapPalette.VERMILION, 12.0)
	m.value = value
	m.mark = 50.0
	box.add_child(m)
	return box
