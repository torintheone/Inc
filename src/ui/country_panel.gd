class_name CountryPanel
extends PanelContainer
## Панель выбранной страны: название, зона мир-системы и показатели.

signal close_requested

const WIDTH := 400.0
const NEIGHBORS_SHOWN := 8
## Ширина текста внутри панели: нужна, чтобы переносы строк считались сразу.
const TEXT_WIDTH := WIDTH - 40.0

var world: WorldData

var _shown_estimated := false
var _title: Label
var _subtitle: Label
var _grid: GridContainer
var _neighbors: Label
var _note: Label
var _source: Label


func _init() -> void:
	custom_minimum_size = Vector2(WIDTH, 0)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	add_child(box)

	var header := HBoxContainer.new()
	box.add_child(header)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_theme_constant_override("separation", 0)
	header.add_child(titles)
	_title = GameTheme.make_label("", 34, GameTheme.display_font(600))
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	titles.add_child(_title)
	_subtitle = GameTheme.make_label("", GameTheme.BODY_SIZE, null, MapPalette.VERMILION)
	titles.add_child(_subtitle)
	var close := Button.new()
	close.text = "×"
	close.tooltip_text = tr("BTN_CLOSE")
	close.custom_minimum_size = Vector2(44, 44)
	close.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	close.add_theme_font_size_override("font_size", 26)
	close.pressed.connect(func() -> void: close_requested.emit())
	header.add_child(close)

	box.add_child(HSeparator.new())
	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.add_theme_constant_override("h_separation", 16)
	_grid.add_theme_constant_override("v_separation", 6)
	box.add_child(_grid)
	box.add_child(HSeparator.new())

	_neighbors = GameTheme.make_label("")
	_neighbors.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_neighbors.custom_minimum_size.x = TEXT_WIDTH
	box.add_child(_neighbors)
	_note = GameTheme.make_label(tr("NOTE_ESTIMATED"), GameTheme.SMALL_SIZE, null, MapPalette.CONCRETE)
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.custom_minimum_size.x = TEXT_WIDTH
	box.add_child(_note)
	_source = GameTheme.make_label("", GameTheme.SMALL_SIZE, null, MapPalette.CONCRETE)
	_source.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_source.custom_minimum_size.x = TEXT_WIDTH
	box.add_child(_source)


func show_country(c: Country) -> void:
	_title.text = c.name_ru
	_subtitle.text = "%s · %s" % [tr("ZONE_" + c.zone), c.subregion_ru]
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	_shown_estimated = false
	_add_row(c, "IND_POPULATION", "population", NumberFormat.population(c.indicator("population")))
	_add_row(c, "IND_GDP_PER_CAPITA", "gdp_per_capita", NumberFormat.dollars(c.indicator("gdp_per_capita")))
	_add_row(c, "IND_EMP_INDUSTRY", "emp_industry", NumberFormat.percent(c.indicator("emp_industry")))
	_add_row(c, "IND_EMP_AGRICULTURE", "emp_agriculture", NumberFormat.percent(c.indicator("emp_agriculture")))
	_add_row(c, "IND_UNEMPLOYMENT", "unemployment", NumberFormat.percent(c.indicator("unemployment")))
	_add_row(c, "IND_GINI", "gini", NumberFormat.decimal(c.indicator("gini"), 1))
	_add_row(c, "IND_TRADE", "trade", NumberFormat.percent(c.indicator("trade"), 0))
	_add_row(c, "IND_ZONE", "", tr("ZONE_" + c.zone))

	var names := PackedStringArray()
	for nid in c.neighbors:
		var n: Country = world.get_country(nid) if world != null else null
		if n != null:
			names.append(n.name_ru)
	names.sort()
	if names.is_empty():
		_neighbors.text = tr("NO_NEIGHBORS")
	else:
		var shown := names.slice(0, NEIGHBORS_SHOWN)
		var text := ", ".join(shown)
		if names.size() > NEIGHBORS_SHOWN:
			text += " +%d" % (names.size() - NEIGHBORS_SHOWN)
		_neighbors.text = tr("NEIGHBORS") % text
	_note.visible = _shown_estimated
	var fetched: String = world.sources.get("indicators_fetched", "") if world != null else ""
	_source.text = tr("SOURCE_LINE") % fetched
	show()


func _add_row(c: Country, label_key: String, indicator_key: String, value: String) -> void:
	var name_label := GameTheme.make_label(tr(label_key), GameTheme.BODY_SIZE, null, Color(MapPalette.INK, 0.75))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_grid.add_child(name_label)
	var estimated := indicator_key != "" and c.is_estimated(indicator_key)
	_shown_estimated = _shown_estimated or estimated
	var value_label := GameTheme.make_label(("≈ " if estimated else "") + value, GameTheme.BODY_SIZE, GameTheme.BODY_BOLD_FONT)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if indicator_key != "" and c.years.has(indicator_key):
		value_label.tooltip_text = tr("YEAR_SUFFIX") % c.years[indicator_key]
	_grid.add_child(value_label)
