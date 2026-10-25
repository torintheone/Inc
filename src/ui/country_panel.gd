class_name CountryPanel
extends PanelContainer
## Панель выбранной страны. Вкладка «Движение»: влияние, кадры, организованность,
## сознание, стихийные протесты и три условия революционной ситуации с подсказкой,
## чего не хватает. Вкладка «Страна»: жизнь рабочих, власть и состав общества.
## Касание строки показывает внизу, что означает показатель.

signal close_requested
signal main_button_pressed

const WIDTH := 410.0
## Ширина текста внутри панели: нужна, чтобы переносы строк считались сразу.
const TEXT_WIDTH := WIDTH - 44.0
const TAB_MOVEMENT := "movement"
const TAB_COUNTRY := "country"

## Цвета групп в составе общества (проверены на различимость, в том числе при дальтонизме);
## «остальные» — нейтральный серый.
const CLASS_COLORS := [Color("#C62828"), Color("#D4A13A"), Color("#2F5D9A"), Color("#8A8A84")]

var tab := TAB_MOVEMENT

var _title: Label
var _subtitle: Label
var _status: Label
var _tabs: HBoxContainer
var _tab_buttons: Dictionary[String, Button] = {}
var _scroll: ScrollContainer
var _content: VBoxContainer
var _hint: Label
var _main_button: Button
var _last: Array = []


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
	header.add_child(Screens.close_button(func() -> void: close_requested.emit()))

	_status = GameTheme.make_label("", 15, GameTheme.BODY_BOLD_FONT, MapPalette.VERMILION)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size.x = TEXT_WIDTH
	box.add_child(_status)

	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 6)
	for t in [TAB_MOVEMENT, TAB_COUNTRY]:
		var b := Button.new()
		b.text = tr("PANEL_TAB_" + t)
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(0, 38)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func() -> void: _set_tab(t))
		_tabs.add_child(b)
		_tab_buttons[t] = b
	box.add_child(_tabs)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(_scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_right", 12)
	_scroll.add_child(margin)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 5)
	margin.add_child(_content)

	_hint = GameTheme.make_label("", 14, null, Color(MapPalette.INK, 0.75))
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.custom_minimum_size.x = TEXT_WIDTH
	box.add_child(_hint)

	_main_button = Overlays.button("", func() -> void: main_button_pressed.emit(), true)
	_main_button.custom_minimum_size = Vector2(0, 50)
	box.add_child(_main_button)


## Показать страну. cs — её состояние в партии; button_text — надпись главной кнопки ("" — без кнопки).
func show_country(c: Country, cs: CountryState, sim: SimWorld, button_text: String) -> void:
	var switched: bool = _last.is_empty() or _last[0] != c
	_last = [c, cs, sim, button_text]
	_title.text = c.name_ru
	_subtitle.text = "%s · %s · %s" % [tr("ZONE_" + c.zone), NumberFormat.population(c.indicator("population")),
		NumberFormat.dollars(c.indicator("gdp_per_capita"))]
	_main_button.text = button_text
	_main_button.visible = button_text != ""
	var started := sim != null and sim.start_country != ""
	var revolutionary := cs != null and cs.is_revolutionary()
	if switched:
		_set_hint("")
		if not started:
			tab = TAB_COUNTRY
	if revolutionary:
		_status.text = tr("STATUS_REVOLUTIONARY") % UiText.date(sim, cs.revolution_week).get_slice(" ", 1)
	elif started and sim.in_civil_war(c.id):
		var war: BattleState = sim.civil_wars[c.id]
		_status.text = tr("CIVIL_WAR_STATUS") % [UiText.percent(war.control_share() * 100.0),
			maxi(war.next_round_week - sim.week, 0)]
	elif started and cs.influence > 0.0 and cs.window_left >= 0:
		_status.text = tr("WINDOW_OPEN") % cs.window_left
	elif started and UnrestSystem.has_bubble(sim, c.id, UnrestSystem.PROTEST):
		_status.text = tr("STATUS_PROTEST")
	else:
		_status.text = ""
	_status.visible = _status.text != ""
	_tabs.visible = not revolutionary
	for t: String in _tab_buttons:
		_tab_buttons[t].set_pressed_no_signal(t == tab)
	var scroll := _scroll.scroll_vertical
	_clear(_content)
	if revolutionary:
		_paragraph(tr("PANEL_REVOLUTIONARY"))
	elif tab == TAB_MOVEMENT:
		_build_movement(cs, sim, started)
	else:
		_build_country(c, cs, sim, started)
	_scroll.set_deferred("scroll_vertical", 0 if switched else scroll)
	show()


func _set_tab(t: String) -> void:
	tab = t
	_set_hint("")
	if not _last.is_empty():
		show_country(_last[0], _last[1], _last[2], _last[3])


func _build_movement(cs: CountryState, sim: SimWorld, started: bool) -> void:
	if not started or cs.influence <= 0.0:
		_paragraph(tr("NO_MOVEMENT") if started else tr("PANEL_BASE_HINT"))
		_row(tr("M_POTENTIAL"), cs.potential, UiText.percent(cs.potential), "HINT_POTENTIAL", MapPalette.VERMILION)
		_row(tr("M_UNREST"), cs.unrest, str(int(cs.unrest)), "HINT_UNREST", MapPalette.OCHRE)
		_row(tr("C_REPRESSION"), cs.repression, str(int(cs.repression)), "HINT_REPRESSION")
		return
	var tiles := HBoxContainer.new()
	tiles.add_theme_constant_override("separation", 8)
	var trend := ""
	if cs.history.size() >= 2:
		var back := cs.history[maxi(cs.history.size() - 14, 0)]
		trend = tr("TREND_YEAR") % UiText.signed_points(cs.influence - back)
	tiles.add_child(_tile(tr("M_INFLUENCE"), UiText.percent(cs.influence), trend, "", cs.history))
	tiles.add_child(_tile(tr("M_CADRES"), "%d / %d" % [int(cs.cadres), int(cs.cadre_cap(sim))], tr("CADRES_TILE"), "cadres", PackedFloat32Array()))
	_content.add_child(tiles)
	_row(tr("M_POTENTIAL"), cs.influence, tr("OF_POTENTIAL") % [int(cs.influence), int(cs.potential)], "HINT_POTENTIAL",
		MapPalette.VERMILION, -1.0, cs.potential)
	# Главное — что мешает революции: сразу под плитками.
	_section(tr("SEC_REV"))
	for row in Panels.rev_rows(cs):
		_hook(row)
		_content.add_child(row)
	var verdict := GameTheme.make_label(Panels.rev_verdict(cs), 14, GameTheme.BODY_BOLD_FONT,
		MapPalette.VERMILION if cs.rev_situation >= Panels.REV_THRESHOLD else MapPalette.INK)
	verdict.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	verdict.custom_minimum_size.x = TEXT_WIDTH - 12.0
	_content.add_child(verdict)
	_section(tr("SEC_MOVEMENT"))
	_row(tr("M_ORGANIZATION"), cs.organization, str(int(cs.organization)), "HINT_ORGANIZATION")
	_row(tr("M_CONSCIOUSNESS"), cs.consciousness, str(int(cs.consciousness)), "HINT_CONSCIOUSNESS")
	_caption(tr("STAGE_LINE") % tr("STAGE_%d" % cs.consciousness_stage()))
	_row(tr("M_UNREST"), cs.unrest, str(int(cs.unrest)), "HINT_UNREST", MapPalette.OCHRE)
	_row(tr("M_VISIBILITY"), cs.visibility, str(int(cs.visibility)), "HINT_VISIBILITY", MapPalette.STEEL)
	_row(tr("M_REFORMISM"), cs.reformism, str(int(cs.reformism)), "HINT_REFORMISM", MapPalette.STEEL)
	_row(tr("M_TRUST"), cs.trust, str(int(cs.trust)), "HINT_TRUST")


func _build_country(c: Country, cs: CountryState, sim: SimWorld, started: bool) -> void:
	_section(tr("SEC_LIFE"))
	_row(tr("C_NEED"), cs.need, str(int(cs.need)), "HINT_NEED", MapPalette.VERMILION)
	_row(tr("C_UNEMPLOYMENT"), cs.unemployment * 100.0 / 30.0, UiText.percent(cs.unemployment), "HINT_UNEMPLOYMENT")
	_row(tr("C_WAGE"), cs.real_wage, str(int(cs.real_wage)), "HINT_WAGE")
	_row(tr("C_EXPLOITATION"), cs.exploitation, str(int(cs.exploitation)), "HINT_EXPLOITATION")
	_section(tr("SEC_POWER"))
	_row(tr("C_HEGEMONY"), cs.hegemony, str(int(cs.hegemony)), "HINT_HEGEMONY", MapPalette.STEEL)
	_row(tr("C_LEGITIMACY"), cs.legitimacy, str(int(cs.legitimacy)), "HINT_LEGITIMACY", MapPalette.STEEL)
	_row(tr("C_REPRESSION"), cs.repression, str(int(cs.repression)), "HINT_REPRESSION", MapPalette.STEEL)
	_row(tr("C_ARMY"), cs.army_loyalty, str(int(cs.army_loyalty)), "HINT_ARMY", MapPalette.STEEL)
	_row(tr("C_ELITE_SPLIT"), cs.elite_split, str(int(cs.elite_split)), "HINT_ELITE_SPLIT")
	_row(tr("C_LEGALITY"), cs.legality, str(int(cs.legality)), "HINT_LEGALITY")
	_section(tr("SEC_CLASSES"))
	var groups := class_groups(c)
	var bar := _ClassBar.new()
	bar.shares = groups
	_content.add_child(bar)
	var legend := GridContainer.new()
	legend.columns = 2
	legend.add_theme_constant_override("h_separation", 12)
	legend.add_theme_constant_override("v_separation", 2)
	for i in groups.size():
		var item := HBoxContainer.new()
		item.add_theme_constant_override("separation", 6)
		var sw := ColorRect.new()
		sw.color = CLASS_COLORS[i]
		sw.custom_minimum_size = Vector2(12, 12)
		sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		item.add_child(sw)
		item.add_child(GameTheme.make_label("%s %s" % [tr("CLASS_GROUP_%d" % i), UiText.percent(groups[i] * 100.0)], 14))
		legend.add_child(item)
	_content.add_child(legend)


## Доли четырёх групп: пролетариат, крестьяне, служащие, остальные.
static func class_groups(c: Country) -> PackedFloat32Array:
	var k := c.classes
	var proletariat := float(k.get("industrial_proletariat", 0.0)) + float(k.get("rural_proletariat", 0.0))
	var peasants := float(k.get("peasantry", 0.0))
	var employees := float(k.get("employees", 0.0))
	var others := maxf(1.0 - proletariat - peasants - employees, 0.0)
	return PackedFloat32Array([proletariat, peasants, employees, others])


func _tile(title: String, value: String, caption: String, icon: String, history: PackedFloat32Array) -> Control:
	var tile := PanelContainer.new()
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = MapPalette.INK
	sb.set_content_margin_all(8)
	sb.content_margin_left = 10
	tile.add_theme_stylebox_override("panel", sb)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", -2)
	tile.add_child(box)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 4)
	if icon != "":
		head.add_child(Icons.IconView.new(icon, MapPalette.OCHRE, 16.0, MapPalette.INK))
	head.add_child(GameTheme.make_label(title.to_upper(), 12, GameTheme.BODY_BOLD_FONT, Color(MapPalette.PAPER, 0.75)))
	box.add_child(head)
	var row := HBoxContainer.new()
	row.add_child(GameTheme.make_label(value, 26, GameTheme.display_font(600), MapPalette.PAPER))
	if history.size() >= 3:
		var spark := _Sparkline.new()
		spark.values = history
		spark.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(spark)
	box.add_child(row)
	if caption != "":
		box.add_child(GameTheme.make_label(caption, 12, null, Color(MapPalette.PAPER, 0.75)))
	return tile


func _row(name: String, value: float, text: String, hint_key: String, color: Color = Color(MapPalette.INK, 0.7),
		mark: float = -1.0, ghost: float = -1.0) -> void:
	var row := Panels.meter_row(name, value, text, color, mark, ghost, hint_key)
	_hook(row)
	_content.add_child(row)


## Касание строки показывает подсказку о показателе.
func _hook(row: Control) -> void:
	if not row.has_meta("hint"):
		return
	var key: String = row.get_meta("hint")
	row.gui_input.connect(func(e: InputEvent) -> void:
		if (e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed):
			_set_hint(tr(key)))


## Объяснение показателя под списком; пустая строка — подсказка скрыта и не занимает места.
func _set_hint(text: String) -> void:
	_hint.text = text
	_hint.visible = text != ""


func _section(title: String) -> void:
	var l := GameTheme.make_label(title.to_upper(), 14, GameTheme.BODY_BOLD_FONT, MapPalette.VERMILION)
	_content.add_child(l)


func _caption(text: String) -> void:
	var l := GameTheme.make_label(text, 13, null, Color(MapPalette.INK, 0.6))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = TEXT_WIDTH - 12.0
	_content.add_child(l)


func _paragraph(text: String) -> void:
	var l := GameTheme.make_label(text, 15)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = TEXT_WIDTH - 12.0
	_content.add_child(l)


static func _clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()


## Состав общества — одна полоса из четырёх частей с промежутками.
class _ClassBar:
	extends Control
	var shares := PackedFloat32Array()

	func _init() -> void:
		custom_minimum_size = Vector2(0, 16)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var x := 0.0
		for i in shares.size():
			var w := size.x * shares[i]
			if w >= 3.0:
				var sb := StyleBoxFlat.new()
				sb.bg_color = CountryPanel.CLASS_COLORS[i]
				sb.set_corner_radius_all(3)
				draw_style_box(sb, Rect2(x, 0, w - 2.0, size.y))
			x += w


## Маленький график влияния за два года в плитке.
class _Sparkline:
	extends Control
	var values := PackedFloat32Array()

	func _init() -> void:
		custom_minimum_size = Vector2(80, 30)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var top := 1.0
		for v in values:
			top = maxf(top, v)
		var pts := PackedVector2Array()
		for i in values.size():
			pts.append(Vector2(8.0 + (size.x - 16.0) * i / maxf(values.size() - 1, 1), size.y - 4.0 - (size.y - 8.0) * values[i] / top))
		draw_polyline(pts, MapPalette.VERMILION, 2.0, true)
		draw_circle(pts[pts.size() - 1], 3.5, MapPalette.PAPER)
