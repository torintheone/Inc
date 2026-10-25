class_name SideDrawer
extends PanelContainer
## Боковая панель с содержимым вкладок: развитие движения, действия в стране,
## лента событий и статистика мира.

signal upgrade_requested(id: String)
signal action_requested(id: String)
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


## Перестроить содержимое вкладки. country — выбранная страна (для «Действий»).
func refresh(sim: SimWorld, country: CountryState) -> void:
	for child in _body.get_children():
		_body.remove_child(child)
		child.queue_free()
	_title.text = tr("TAB_" + tab)
	match tab:
		"upgrades":
			_build_upgrades(sim)
		"actions":
			_build_actions(sim, country)
		"news":
			_build_news(sim)
		"stats":
			_build_stats(sim)


func _build_upgrades(sim: SimWorld) -> void:
	for id in sim.data.upgrade_order:
		var u: Dictionary = sim.data.upgrades[id]
		var blockers := PlayerActions.upgrade_blockers(sim, id)
		var owned := sim.upgrades.has(id)
		var subtitle := "%s · %s" % [tr("BRANCH_" + str(u.get("branch", ""))), tr("COST") % int(u.get("cost", 0))]
		var button_text := tr("BLOCK_owned") if owned else tr("BTN_BUY")
		_body.add_child(_card(tr("UPGRADE_" + id), subtitle, tr("UPGRADE_" + id + "_DESC"),
			"" if owned else _reasons(blockers), button_text, blockers.is_empty(),
			func() -> void: upgrade_requested.emit(id), owned))


func _build_actions(sim: SimWorld, cs: CountryState) -> void:
	if cs == null:
		_body.add_child(_paragraph(tr("SELECT_COUNTRY")))
		return
	_title.text = tr("ACTIONS_FOR") % cs.country.name_ru
	for id in sim.data.country_action_order:
		var a: Dictionary = sim.data.country_actions[id]
		var blockers := PlayerActions.action_blockers(sim, id, cs)
		var chance := PlayerActions.action_chance(sim, id, cs)
		var subtitle := "%s · %s" % [tr("COST") % int(a.get("cost", 0)), tr("CHANCE") % int(roundf(chance * 100.0))]
		_body.add_child(_card(tr("ACTION_" + id), subtitle, tr("ACTION_" + id + "_DESC"), _reasons(blockers),
			tr("BTN_DO"), blockers.is_empty(), func() -> void: action_requested.emit(id), false))


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


func _card(title: String, subtitle: String, desc: String, reason: String, button_text: String,
		enabled: bool, on_press: Callable, done: bool) -> Control:
	var card := VBoxContainer.new()
	card.add_theme_constant_override("separation", 4)
	var head := HBoxContainer.new()
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_theme_constant_override("separation", 0)
	titles.add_child(GameTheme.make_label(title, 20, GameTheme.BODY_BOLD_FONT, MapPalette.INK if not done else MapPalette.CONCRETE))
	titles.add_child(GameTheme.make_label(subtitle, GameTheme.SMALL_SIZE, null, MapPalette.VERMILION))
	head.add_child(titles)
	var b := Button.new()
	b.text = button_text
	b.disabled = not enabled
	b.custom_minimum_size = Vector2(110, 44)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(on_press)
	head.add_child(b)
	card.add_child(head)
	card.add_child(_paragraph(desc, 15))
	if reason != "":
		var why := _paragraph(reason, GameTheme.SMALL_SIZE)
		why.add_theme_font_override("font", GameTheme.BODY_BOLD_FONT)
		why.add_theme_color_override("font_color", MapPalette.STEEL)
		card.add_child(why)
	card.add_child(HSeparator.new())
	return card


func _reasons(blockers: PackedStringArray) -> String:
	var parts := PackedStringArray()
	for b in blockers:
		parts.append(UiText.blocker(b))
	return " · ".join(parts)


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
