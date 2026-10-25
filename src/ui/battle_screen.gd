class_name BattleScreen
extends Control
## Местное сражение во весь экран: сверху — день и таймер окна революции, доверие масс,
## верность армии и скорость; слева — карта страны; справа — выбранный район и его действия
## (или цели сражения, если район не выбран); снизу — ресурсы и последняя строка журнала.
## Пока экран открыт, мир стоит. Сражение идёт по дням, как партия по неделям.

## Сражение кончилось, игрок нажал «На карту мира».
signal finished
## Прошёл день: можно сохранить партию.
signal day_passed

const SIDE_W := 390.0
const SPEEDS: Array[int] = [0, 1, 2, 3]
const LOG_LINES := 6

var sim: SimWorld
var b: BattleState
var speed := 0
var selected := -1

var _accum := 0.0
var _title: Label
var _day: Label
var _timer: Meter
var _trust_label: Label
var _trust: Meter
var _army_label: Label
var _army: Meter
var _speed_buttons: Array[Button] = []
var _map: BattleMapView
var _side: VBoxContainer
var _side_scroll: ScrollContainer
var _res: Dictionary = {}
var _log_line: Label
var _popup: Control
var _stamp: Label
var _stamp_time := 0.0
var _outcome_shown := false


func _init(p_sim: SimWorld) -> void:
	sim = p_sim
	b = sim.battle
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_meta("paper", true)
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)
	root.add_child(_build_header())
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 0)
	root.add_child(body)
	_map = BattleMapView.new()
	_map.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_map.region_tapped.connect(_select)
	body.add_child(_map)
	body.add_child(_build_side())
	root.add_child(_build_footer())

	_stamp = GameTheme.make_label("", 52, GameTheme.display_font(700), MapPalette.VERMILION)
	_stamp.add_theme_color_override("font_outline_color", MapPalette.PAPER)
	_stamp.add_theme_constant_override("outline_size", 10)
	_stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stamp.visible = false
	add_child(_stamp)

	_map.setup(b)
	_refresh()
	if b.is_over():
		_show_outcome()
	else:
		_show_intro()


# --- Построение -------------------------------------------------------------

func _build_header() -> Control:
	var bar := PanelContainer.new()
	bar.custom_minimum_size = Vector2(0, 58)
	bar.add_theme_stylebox_override("panel", Screens.band(MapPalette.INK))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	bar.add_child(row)
	_title = GameTheme.make_label("", 26, GameTheme.display_font(600), MapPalette.PAPER)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.clip_text = true
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(_title)
	var day_box := _header_meter(MapPalette.OCHRE)
	_day = day_box[1]
	_timer = day_box[2]
	row.add_child(day_box[0])
	var trust_box := _header_meter(MapPalette.VERMILION)
	_trust_label = trust_box[1]
	_trust = trust_box[2]
	_trust.mark = sim.data.num("battle.daily.low_trust")
	row.add_child(trust_box[0])
	var army_box := _header_meter(Color("#8FA7C7"))
	_army_label = army_box[1]
	_army = army_box[2]
	_army.mark = sim.data.num("battle.daily.army_defects_loyalty")
	row.add_child(army_box[0])
	var speeds := HBoxContainer.new()
	speeds.add_theme_constant_override("separation", 4)
	speeds.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for s in SPEEDS:
		var btn := Screens.light_button("II" if s == 0 else "×%d" % s, func() -> void: _set_speed(s))
		btn.custom_minimum_size = Vector2(50, 42)
		btn.toggle_mode = true
		speeds.add_child(btn)
		_speed_buttons.append(btn)
	row.add_child(speeds)
	return bar


## Подпись и шкала в заголовке: [узел, подпись, шкала].
func _header_meter(color: Color) -> Array:
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(170, 0)
	box.add_theme_constant_override("separation", 3)
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var label := GameTheme.make_label("", 14, GameTheme.BODY_BOLD_FONT, MapPalette.PAPER)
	box.add_child(label)
	var m := Meter.new(color, 9.0)
	box.add_child(m)
	return [box, label, m]


func _build_side() -> Control:
	var side := PanelContainer.new()
	side.custom_minimum_size = Vector2(SIDE_W, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#E6DCC6")
	sb.content_margin_left = 16
	sb.content_margin_right = 10
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	side.add_theme_stylebox_override("panel", sb)
	_side_scroll = ScrollContainer.new()
	_side_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	side.add_child(_side_scroll)
	_side = VBoxContainer.new()
	_side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_side.add_theme_constant_override("separation", 7)
	_side_scroll.add_child(_side)
	return side


func _build_footer() -> Control:
	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", GameTheme.bar_panel())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	bar.add_child(row)
	for item: Array in [["agitators", "agitation", MapPalette.INK], ["squads", "squads", MapPalette.VERMILION],
			["supplies", "supplies", MapPalette.OCHRE], ["weapons", "weapons", MapPalette.INK],
			["solidarity", "solidarity", MapPalette.VERMILION]]:
		var cell := HBoxContainer.new()
		cell.add_theme_constant_override("separation", 5)
		cell.add_child(Icons.IconView.new(item[1], item[2], 26.0))
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", -5)
		col.add_child(GameTheme.make_label(tr("RES_" + item[0]) if item[0] != "solidarity" else tr("SOLIDARITY"), 12, null,
			Color(MapPalette.INK, 0.65)))
		var value := GameTheme.make_label("0", 20, GameTheme.display_font(600))
		col.add_child(value)
		cell.add_child(col)
		row.add_child(cell)
		_res[item[0]] = value
	_log_line = GameTheme.make_label("", 15, null, Color(MapPalette.INK, 0.8))
	_log_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_log_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_log_line.clip_text = true
	_log_line.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_log_line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_log_line)
	return bar


# --- Ход сражения -----------------------------------------------------------

func _process(delta: float) -> void:
	if _stamp_time > 0.0:
		_stamp_time -= delta
		_stamp.modulate.a = clampf(_stamp_time / 0.4, 0.0, 1.0)
		if _stamp_time <= 0.0:
			_stamp.visible = false
	if b.is_over() or speed == 0 or _popup != null:
		return
	var seconds := sim.data.num("battle.time.seconds_per_day", 12.0)
	_accum += delta * speed
	if _accum >= seconds:
		_accum -= seconds
		BattleSystem.step_day(sim, b)
		_refresh()
		day_passed.emit()
		if b.is_over():
			_show_outcome()
			return
	_map.day_progress = _accum / seconds
	if not b.transfers.is_empty():
		_map.queue_redraw()


func _set_speed(value: int) -> void:
	speed = value
	for i in SPEEDS.size():
		_speed_buttons[i].set_pressed_no_signal(SPEEDS[i] == speed)


func _select(i: int) -> void:
	selected = i
	_map.selected = i
	_refresh()


func _refresh() -> void:
	var cap := b.capital()
	var name := sim.state_of(b.country_id).country.name_ru
	_title.text = (tr("BATTLE_TITLE_CIVIL_WAR" if b.rounds > 0 else "BATTLE_TITLE") % name).to_upper()
	_day.text = tr("BATTLE_DAY") % [b.day, b.max_days]
	var start := b.max_days - int(sim.data.num("battle.outcome.civil_war_round_days")) if b.rounds > 0 else 0
	_timer.value = 100.0 * float(b.day - start) / maxf(b.max_days - start, 1)
	_trust_label.text = "%s %d" % [tr("BATTLE_TRUST"), roundi(b.trust)]
	_trust.value = b.trust
	_army_label.text = "%s %d" % [tr("BATTLE_ARMY"), roundi(b.army_loyalty())]
	_army.value = b.army_loyalty()
	var busy := b.agitators_total() - b.agitators
	_res["agitators"].text = str(b.agitators) + (" " + tr("RES_agitators_busy") % busy if busy > 0 else "")
	_res["squads"].text = str(int(b.squads_pool))
	_res["supplies"].text = str(int(b.supplies))
	_res["weapons"].text = str(int(b.weapons))
	_res["solidarity"].text = str(int(sim.solidarity))
	_log_line.text = _log_text(b.log[-1]) if not b.log.is_empty() else ""
	_map.queue_redraw()
	_build_side_content(cap)


func _log_text(item: Dictionary) -> String:
	return "%s %d: %s" % [tr("DAY_SHORT"), int(item["day"]), UiText.news(item)]


# --- Боковая панель ---------------------------------------------------------

func _build_side_content(cap: int) -> void:
	var keep := _side_scroll.scroll_vertical
	for c in _side.get_children():
		c.queue_free()
	for note in _notes():
		_add_text(note, 15, MapPalette.VERMILION)
	if selected >= 0:
		_build_region(selected)
	else:
		_build_goals(cap)
	_add_separator()
	_add_text(tr("BATTLE_WHOLE_COUNTRY"), 18, MapPalette.INK, GameTheme.display_font(600))
	for id in sim.data.battle_action_order:
		if sim.data.battle_actions[id].get("target", "any") == "global":
			_add_action(id, -1)
	if selected < 0:
		_add_separator()
		_add_text(tr("BATTLE_LOG"), 18, MapPalette.INK, GameTheme.display_font(600))
		for k in range(b.log.size() - 1, maxi(b.log.size() - 1 - LOG_LINES, -1), -1):
			_add_text(_log_text(b.log[k]), 14, Color(MapPalette.INK, 0.8))
	# Прокрутка не должна прыгать вверх от каждого нового дня.
	_side_scroll.set_deferred("scroll_vertical", keep)


func _notes() -> PackedStringArray:
	var out := PackedStringArray()
	if b.leadership_arrested:
		out.append(tr("BATTLE_LEADERSHIP_OUT") % maxi(b.leadership_back - b.day, 0))
	if b.day < b.curfew_until:
		out.append(tr("BATTLE_CURFEW") % (b.curfew_until - b.day))
	if b.hungry:
		out.append(tr("BATTLE_HUNGRY"))
	return out


func _build_goals(cap: int) -> void:
	_add_text(tr("BATTLE_GOALS"), 22, MapPalette.INK, GameTheme.display_font(600))
	var cap_name: String = b.region(cap)["name_ru"]
	_add_text(tr("BATTLE_GOAL_CAPITAL") % "%s (%s)" % [cap_name, tr("CONTROL_%d" % b.control[cap])], 16,
		MapPalette.VERMILION if b.control[cap] == BattleState.REVOLUTION else MapPalette.INK)
	var total := 0
	var ours := 0
	for i in b.region_count():
		if b.has_object(i, "factories"):
			total += 1
			if b.control[i] == BattleState.REVOLUTION:
				ours += 1
	var need := ceili(total * sim.data.num("battle.outcome.factory_share") - 0.001)
	_add_text(tr("BATTLE_GOAL_FACTORIES") % [ours, total, need], 16)
	_add_text(tr("BATTLE_GOAL_ARMY") % [roundi(b.army_loyalty()), roundi(sim.data.num("battle.daily.army_defects_loyalty"))], 16)
	_add_text(tr("BATTLE_GOAL_SHARE") % UiText.percent(b.control_share() * 100.0), 16)
	_add_text(tr("BATTLE_GOAL_ROUND" if b.rounds > 0 else "BATTLE_GOAL_TIMER") % maxi(b.max_days - b.day, 0), 14,
		Color(MapPalette.INK, 0.75))
	_add_text(tr("BATTLE_SELECT_REGION"), 15, MapPalette.STEEL)


func _build_region(i: int) -> void:
	var r := b.region(i)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	var name := GameTheme.make_label(str(r["name_ru"]), 24, GameTheme.display_font(600))
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.add_child(name)
	var chip := GameTheme.make_label(tr("CONTROL_%d" % b.control[i]), 15, GameTheme.BODY_BOLD_FONT, MapPalette.PAPER)
	var chip_sb := StyleBoxFlat.new()
	chip_sb.bg_color = _map.region_color(i).darkened(0.15) if b.control[i] != BattleState.POWER else MapPalette.CONCRETE
	chip_sb.set_content_margin_all(5)
	chip_sb.set_corner_radius_all(4)
	chip.add_theme_stylebox_override("normal", chip_sb)
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(chip)
	_side.add_child(head)
	var objects: Array = r.get("objects", [])
	if not objects.is_empty():
		var names := PackedStringArray()
		for o: String in objects:
			names.append(tr("OBJECT_" + o))
		var obj_row := HBoxContainer.new()
		obj_row.add_theme_constant_override("separation", 4)
		for o: String in objects:
			obj_row.add_child(Icons.IconView.new(o, MapPalette.VERMILION if b.seized.has(o) else MapPalette.INK, 20.0, Color("#E6DCC6")))
		var obj_label := GameTheme.make_label(", ".join(names), 14, null, Color(MapPalette.INK, 0.8))
		obj_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		obj_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		obj_row.add_child(obj_label)
		_side.add_child(obj_row)
	_side.add_child(Panels.meter_row(tr("BATTLE_SUPPORT"), b.support[i], UiText.percent(b.support[i]), MapPalette.VERMILION, 50.0))
	if b.gov[i] > 0.5:
		# Шкала — верность гарнизона, отметка — порог, ниже которого солдаты переходят к нам.
		_side.add_child(Panels.meter_row(tr("BATTLE_GARRISON_VALUE") % [roundi(b.gov[i]), ""], b.loyalty[i],
			UiText.percent(b.loyalty[i]), BattleMapView.GARRISON, sim.data.num("battle.daily.defect_loyalty")))
	_add_pair(tr("BATTLE_POLICE"), str(roundi(b.police[i])))
	_add_pair(tr("BATTLE_SQUADS"), str(roundi(b.squads[i])))
	if b.barricades[i] > 0:
		_add_text(tr("BATTLE_BARRICADES") % [b.barricades[i], int(sim.data.battle_actions["barricades"].get("max_level", 3))], 14)
	if b.council[i]:
		_add_text(tr("BATTLE_COUNCIL"), 14, MapPalette.VERMILION)
	if b.strike_days[i] > 0:
		_add_text(tr("BATTLE_STRIKE") % b.strike_days[i], 14, MapPalette.VERMILION)
	if b.neutral[i]:
		_add_text(tr("BATTLE_NEUTRAL"), 14, MapPalette.STEEL)
	if b.defected[i]:
		_add_text(tr("BATTLE_DEFECTED"), 14, MapPalette.VERMILION)
	for t: Dictionary in b.transfers:
		if int(t["to"]) == i:
			_add_text(tr("BATTLE_TRANSFER_COMING") % [roundi(float(t["strength"])), maxi(int(t["arrive"]) - b.day, 0)], 14,
				MapPalette.STEEL)
	# Отряды.
	_add_separator()
	_add_text(tr("BATTLE_SEND") % int(b.squads_pool), 16, MapPalette.INK, GameTheme.BODY_BOLD_FONT)
	var send := HBoxContainer.new()
	send.add_theme_constant_override("separation", 6)
	send.add_child(_small_button(tr("BTN_SEND_5"), b.squads_pool >= 1.0, func() -> void: _deploy(i, 5.0)))
	send.add_child(_small_button(tr("BTN_SEND_ALL"), b.squads_pool >= 1.0, func() -> void: _deploy(i, b.squads_pool)))
	send.add_child(_small_button(tr("BTN_WITHDRAW"), b.squads[i] > 0.0, func() -> void: _deploy(i, -b.squads[i])))
	_side.add_child(send)
	_add_separator()
	for id in sim.data.battle_action_order:
		var a: Dictionary = sim.data.battle_actions[id]
		var target: String = a.get("target", "any")
		if target == "global":
			continue
		if target.begins_with("object:") and not b.has_object(i, target.get_slice(":", 1)):
			continue
		_add_action(id, i)


func _add_action(id: String, i: int) -> void:
	var blockers := BattleSystem.blockers(sim, b, id, i)
	var btn := Button.new()
	btn.text = tr("BATTLE_ACTION_" + id)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.custom_minimum_size = Vector2(0, 44)
	btn.disabled = not blockers.is_empty()
	Screens.scroll_safe(btn, _side_scroll, func() -> void: _perform(id, i))
	_side.add_child(btn)
	var parts := PackedStringArray()
	var cost := BattleSystem.cost(sim, b, id)
	for k: String in cost:
		parts.append(tr("BATTLE_COST_" + k) % int(cost[k]))
	var p := BattleSystem.chance(sim, b, id, i)
	if p < 1.0:
		parts.append(tr("BATTLE_CHANCE") % UiText.percent(p * 100.0))
	var line := " · ".join(parts)
	var color := Color(MapPalette.INK, 0.7)
	if not blockers.is_empty():
		line += " — " + _blocker(blockers[0])
		color = MapPalette.VERMILION
	else:
		line += " — " + tr("BATTLE_ACTION_%s_DESC" % id)
	var desc := GameTheme.make_label(line, 13, null, color)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size.x = SIDE_W - 40.0
	_side.add_child(desc)


func _blocker(code: String) -> String:
	var parts := code.split(":")
	var template := tr("BBLOCK_" + parts[0])
	if parts.size() > 1 and template.contains("%s"):
		return template % parts[1]
	return template


func _small_button(text: String, enabled: bool, on_press: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.disabled = not enabled
	btn.custom_minimum_size = Vector2(0, 42)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.add_theme_font_size_override("font_size", 15)
	Screens.scroll_safe(btn, _side_scroll, on_press)
	return btn


func _add_text(text: String, size_px: int, color: Color = MapPalette.INK, font: Font = null) -> void:
	var l := GameTheme.make_label(text, size_px, font, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = SIDE_W - 40.0
	_side.add_child(l)


func _add_pair(name: String, value: String) -> void:
	var row := HBoxContainer.new()
	var n := GameTheme.make_label(name, 15, null, Color(MapPalette.INK, 0.8))
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(n)
	row.add_child(GameTheme.make_label(value, 15, GameTheme.BODY_BOLD_FONT))
	_side.add_child(row)


func _add_separator() -> void:
	_side.add_child(HSeparator.new())


# --- Действия ---------------------------------------------------------------

func _perform(id: String, i: int) -> void:
	if b.is_over():
		return
	var result := BattleSystem.perform(sim, b, id, i)
	if not result["ok"]:
		return
	if sim.data.battle_actions[id].has("chance"):
		_show_stamp(result["success"])
	_refresh()
	if b.is_over():
		_show_outcome()


func _deploy(i: int, amount: float) -> void:
	BattleSystem.deploy(b, i, amount)
	_refresh()


func _show_stamp(success: bool) -> void:
	_stamp.text = tr("STAMP_OK" if success else "STAMP_FAIL")
	_stamp.add_theme_color_override("font_color", MapPalette.VERMILION if success else MapPalette.STEEL)
	_stamp.visible = true
	_stamp.modulate.a = 1.0
	_stamp.reset_size()
	_stamp.position = Vector2((_map.size.x - _stamp.size.x) * 0.5, _map.position.y + 70.0)
	_stamp.pivot_offset = _stamp.size * 0.5
	_stamp.rotation = -0.1
	_stamp_time = 1.2


# --- Начало и итог ----------------------------------------------------------

func _show_intro() -> void:
	var title := tr("BATTLE_INTRO_TITLE")
	if b.rounds > 0:
		title = tr("BATTLE_INTRO_ROUND") % [b.rounds + 1, b.max_days - b.day]
	var texts := PackedStringArray([tr("BATTLE_INTRO_TEXT"), tr("BATTLE_INTRO_HINTS")])
	if b.rounds > 0:
		texts = PackedStringArray([tr("BATTLE_GOAL_ROUND") % (b.max_days - b.day), tr("BATTLE_INTRO_HINTS")])
	_open_popup(title, MapPalette.INK, texts, tr("BTN_BEGIN"), func() -> void:
		_close_popup()
		_set_speed(1))


func _show_outcome() -> void:
	if _outcome_shown:
		return
	_outcome_shown = true
	_set_speed(0)
	var color := MapPalette.INK
	match b.outcome:
		BattleState.OUTCOME_VICTORY:
			color = MapPalette.VERMILION
		BattleState.OUTCOME_DEFEAT:
			color = MapPalette.STEEL
		_:
			color = MapPalette.OCHRE.darkened(0.25)
	var texts := PackedStringArray([tr("BATTLE_REASON_%s_%s" % [b.outcome, b.outcome_reason]), tr("BATTLE_AFTER_" + b.outcome)])
	_open_popup(tr("BATTLE_OUTCOME_" + b.outcome).to_upper(), color, texts, tr("BTN_TO_WORLD"), func() -> void:
		finished.emit())


func _open_popup(title: String, color: Color, texts: PackedStringArray, button: String, on_press: Callable) -> void:
	_close_popup()
	var dim := ColorRect.new()
	dim.color = Color(MapPalette.INK, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(620, 0)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	var t := GameTheme.make_label(title, 34, GameTheme.display_font(700), color)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(t)
	for text in texts:
		var l := GameTheme.make_label(text, 17)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 580
		box.add_child(l)
	var btn := Button.new()
	btn.text = button
	btn.custom_minimum_size = Vector2(240, 52)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	btn.add_theme_font_size_override("font_size", 20)
	btn.pressed.connect(on_press)
	box.add_child(btn)
	_popup = dim


func _close_popup() -> void:
	if _popup != null:
		_popup.queue_free()
		_popup = null
