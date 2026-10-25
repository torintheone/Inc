class_name CountryPanel
extends PanelContainer
## Панель выбранной страны: движение в ней, три условия революционной ситуации
## и главные показатели базиса и надстройки.

signal close_requested
signal main_button_pressed

const WIDTH := 400.0
## Ширина текста внутри панели: нужна, чтобы переносы строк считались сразу.
const TEXT_WIDTH := WIDTH - 40.0

var world: WorldData

var _title: Label
var _subtitle: Label
var _status: Label
var _movement: GridContainer
var _consciousness: Label
var _rev_box: VBoxContainer
var _rev_rows: Dictionary[String, Array] = {}
var _country: GridContainer
var _note: Label
var _main_button: Button


func _init() -> void:
	custom_minimum_size = Vector2(WIDTH, 0)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	add_child(box)

	var header := HBoxContainer.new()
	box.add_child(header)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_theme_constant_override("separation", -2)
	header.add_child(titles)
	_title = GameTheme.make_label("", 30, GameTheme.display_font(600))
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.custom_minimum_size.x = TEXT_WIDTH - 60.0
	titles.add_child(_title)
	_subtitle = GameTheme.make_label("", GameTheme.SMALL_SIZE, null, MapPalette.VERMILION)
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle.custom_minimum_size.x = TEXT_WIDTH - 60.0
	titles.add_child(_subtitle)
	var close := Button.new()
	close.text = "×"
	close.tooltip_text = tr("BTN_CLOSE")
	close.custom_minimum_size = Vector2(44, 44)
	close.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	close.add_theme_font_size_override("font_size", 24)
	close.pressed.connect(func() -> void: close_requested.emit())
	header.add_child(close)

	_status = GameTheme.make_label("", 16, GameTheme.BODY_BOLD_FONT, MapPalette.VERMILION)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size.x = TEXT_WIDTH
	box.add_child(_status)

	_movement = _grid()
	box.add_child(_movement)
	_consciousness = GameTheme.make_label("", 15)
	box.add_child(_consciousness)

	_rev_box = VBoxContainer.new()
	_rev_box.add_theme_constant_override("separation", 3)
	_rev_box.add_child(GameTheme.make_label(tr("SEC_REV"), 16, GameTheme.BODY_BOLD_FONT))
	for key in ["REV_TOP", "REV_BOTTOM", "REV_MASS", "REV_TOTAL"]:
		var row := HBoxContainer.new()
		var name := GameTheme.make_label(tr(key), 15, GameTheme.BODY_BOLD_FONT if key == "REV_TOTAL" else null)
		name.custom_minimum_size.x = 190
		row.add_child(name)
		var meter := Meter.new(MapPalette.VERMILION if key == "REV_TOTAL" else Color(MapPalette.INK, 0.55), 9.0)
		meter.mark = 70.0
		meter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		meter.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(meter)
		var value := GameTheme.make_label("", 15, GameTheme.BODY_BOLD_FONT)
		value.custom_minimum_size.x = 34
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(value)
		_rev_box.add_child(row)
		_rev_rows[key] = [meter, value]
	box.add_child(_rev_box)

	box.add_child(HSeparator.new())
	_country = _grid()
	box.add_child(_country)

	_note = GameTheme.make_label("", GameTheme.SMALL_SIZE, null, MapPalette.CONCRETE)
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.custom_minimum_size.x = TEXT_WIDTH
	box.add_child(_note)

	_main_button = Button.new()
	_main_button.custom_minimum_size = Vector2(0, 48)
	_main_button.pressed.connect(func() -> void: main_button_pressed.emit())
	box.add_child(_main_button)


## Показать страну. cs — её состояние в партии (null — партия не начата);
## button_text — надпись главной кнопки ("" — без кнопки).
func show_country(c: Country, cs: CountryState, sim: SimWorld, button_text: String) -> void:
	_title.text = c.name_ru
	_subtitle.text = "%s · %s · %s · %s" % [tr("ZONE_" + c.zone), c.subregion_ru,
		NumberFormat.population(c.indicator("population")), NumberFormat.dollars(c.indicator("gdp_per_capita"))]
	_main_button.text = button_text
	_main_button.visible = button_text != ""
	_clear(_movement)
	_clear(_country)
	var revolutionary := cs != null and cs.is_revolutionary()
	var active := cs != null and cs.influence > 0.0 and not revolutionary
	if revolutionary:
		_status.text = tr("STATUS_REVOLUTIONARY") % UiText.date(sim, cs.revolution_week).get_slice(" ", 1)
	elif active and cs.window_left >= 0:
		_status.text = tr("WINDOW_OPEN") % cs.window_left
	elif cs != null and not active and sim.start_country != "":
		_status.text = tr("NO_MOVEMENT")
	else:
		_status.text = ""
	_status.visible = _status.text != ""
	_movement.visible = active
	_consciousness.visible = active
	_rev_box.visible = active
	if active:
		_row(_movement, tr("M_INFLUENCE"), UiText.percent(cs.influence))
		_row(_movement, tr("M_ORGANIZATION"), str(int(cs.organization)))
		_row(_movement, tr("M_TRUST"), str(int(cs.trust)))
		_row(_movement, tr("M_VISIBILITY"), str(int(cs.visibility)))
		_consciousness.text = tr("M_CONSCIOUSNESS_LINE") % [int(cs.consciousness), tr("STAGE_%d" % cs.consciousness_stage())]
		_set_rev("REV_TOP", cs.top_cant)
		_set_rev("REV_BOTTOM", cs.bottom_wont)
		_set_rev("REV_MASS", cs.mass_activity)
		_set_rev("REV_TOTAL", cs.rev_situation)
	if cs != null and not revolutionary:
		_row(_country, tr("C_NEED"), str(int(cs.need)))
		_row(_country, tr("C_UNEMPLOYMENT"), UiText.percent(cs.unemployment), c.is_estimated("unemployment"))
		_row(_country, tr("C_WAGE"), str(int(cs.real_wage)))
		_row(_country, tr("C_EXPLOITATION"), str(int(cs.exploitation)))
		_row(_country, tr("C_HEGEMONY"), str(int(cs.hegemony)))
		_row(_country, tr("C_LEGITIMACY"), str(int(cs.legitimacy)))
		_row(_country, tr("C_REPRESSION"), str(int(cs.repression)))
	else:
		_row(_country, tr("IND_EMP_INDUSTRY"), NumberFormat.percent(c.indicator("emp_industry")), c.is_estimated("emp_industry"))
		_row(_country, tr("IND_UNEMPLOYMENT"), NumberFormat.percent(c.indicator("unemployment")), c.is_estimated("unemployment"))
		_row(_country, tr("IND_GINI"), NumberFormat.decimal(c.indicator("gini"), 1), c.is_estimated("gini"))
	# Источник данных — при выборе страны; в партии место нужнее показателям.
	_note.visible = sim == null or sim.start_country == ""
	_note.text = tr("SOURCE_LINE") % (world.sources.get("indicators_fetched", "") if world != null else "")
	show()


func _set_rev(key: String, value: float) -> void:
	var row: Array = _rev_rows[key]
	(row[0] as Meter).value = value
	(row[1] as Label).text = str(int(value))


## Сетка из двух пар «название — значение» в строке.
func _grid() -> GridContainer:
	var g := GridContainer.new()
	g.columns = 4
	g.add_theme_constant_override("h_separation", 8)
	g.add_theme_constant_override("v_separation", 0)
	return g


func _row(grid: GridContainer, name: String, value: String, estimated: bool = false) -> void:
	var n := GameTheme.make_label(name, 15, null, Color(MapPalette.INK, 0.75))
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(n)
	var v := GameTheme.make_label(("≈ " if estimated else "") + value, 15, GameTheme.BODY_BOLD_FONT)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.custom_minimum_size.x = 44
	grid.add_child(v)


static func _clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()
