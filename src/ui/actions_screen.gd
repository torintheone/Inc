class_name ActionsScreen
extends Control
## «Действия в стране» во весь экран: слева — сводка по стране, справа — карточки
## действий тремя группами. Действия оплачиваются кадрами страны (организаторов —
## солидарностью). Пока экран открыт, время в партии стоит.

signal action_requested(id: String)
signal close_requested

const SIDE_W := 330.0

var sim: SimWorld
var cs: CountryState

var _title: Label
var _cadres: Label
var _solidarity: Label
var _summary: VBoxContainer
var _cards: VBoxContainer
var _cards_scroll: ScrollContainer
var _stamp: Label
var _stamp_time := 0.0


func _init() -> void:
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
	root.add_child(_build_header())

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 0)
	root.add_child(body)

	var side := PanelContainer.new()
	side.custom_minimum_size = Vector2(SIDE_W, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#E6DCC6")
	sb.set_content_margin_all(18)
	side.add_theme_stylebox_override("panel", sb)
	var side_scroll := ScrollContainer.new()
	side_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	side.add_child(side_scroll)
	_summary = VBoxContainer.new()
	_summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_summary.add_theme_constant_override("separation", 8)
	side_scroll.add_child(_summary)
	body.add_child(side)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_cards_scroll = scroll
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side_name in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side_name, 18)
	scroll.add_child(margin)
	_cards = VBoxContainer.new()
	_cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cards.add_theme_constant_override("separation", 10)
	margin.add_child(_cards)
	body.add_child(scroll)

	_stamp = GameTheme.make_label("", 56, GameTheme.display_font(700), MapPalette.VERMILION)
	_stamp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stamp.add_theme_color_override("font_outline_color", MapPalette.PAPER)
	_stamp.add_theme_constant_override("outline_size", 10)
	_stamp.set_anchors_preset(Control.PRESET_CENTER)
	_stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stamp.visible = false
	add_child(_stamp)
	# Ширина карточек зависит от экрана: перестраиваем, когда размер известен.
	resized.connect(func() -> void:
		if sim != null:
			_build_cards())


func _build_header() -> Control:
	var bar := PanelContainer.new()
	bar.custom_minimum_size = Vector2(0, 64)
	bar.add_theme_stylebox_override("panel", Screens.band(MapPalette.INK))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	bar.add_child(row)
	_title = GameTheme.make_label("", 30, GameTheme.display_font(600), MapPalette.PAPER)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.clip_text = true
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(_title)
	row.add_child(Icons.IconView.new("cadres", MapPalette.OCHRE, 30.0, MapPalette.INK))
	var cad := VBoxContainer.new()
	cad.add_theme_constant_override("separation", -4)
	cad.add_child(GameTheme.make_label(tr("CADRES_HERE"), 13, null, Color(MapPalette.PAPER, 0.75)))
	_cadres = GameTheme.make_label("0", 26, GameTheme.display_font(600), MapPalette.PAPER)
	cad.add_child(_cadres)
	row.add_child(cad)
	row.add_child(Icons.IconView.new("solidarity", MapPalette.VERMILION, 30.0, MapPalette.INK))
	var sol := VBoxContainer.new()
	sol.add_theme_constant_override("separation", -4)
	sol.add_child(GameTheme.make_label(tr("SOLIDARITY"), 13, null, Color(MapPalette.PAPER, 0.75)))
	_solidarity = GameTheme.make_label("0", 26, GameTheme.display_font(600), MapPalette.PAPER)
	sol.add_child(_solidarity)
	row.add_child(sol)
	row.add_child(Screens.close_button(func() -> void: close_requested.emit(), true))
	return bar


func refresh(p_sim: SimWorld, p_cs: CountryState) -> void:
	sim = p_sim
	cs = p_cs
	_title.text = (tr("ACTIONS_FOR") % cs.country.name_ru).to_upper()
	_cadres.text = "%d / %d" % [int(cs.cadres), int(cs.cadre_cap(sim))]
	_solidarity.text = str(int(sim.solidarity))
	_build_summary()
	_build_cards()


## Показать итог действия печатью поверх экрана.
func show_result(success: bool) -> void:
	_stamp.text = tr("STAMP_OK" if success else "STAMP_FAIL")
	_stamp.add_theme_color_override("font_color", MapPalette.VERMILION if success else MapPalette.STEEL)
	_stamp.rotation = -0.12
	_stamp.visible = true
	_stamp.reset_size()
	_stamp.position = (size - _stamp.size) * 0.5
	_stamp.pivot_offset = _stamp.size * 0.5
	_stamp_time = 1.4


func _process(delta: float) -> void:
	if _stamp_time > 0.0:
		_stamp_time -= delta
		_stamp.scale = Vector2.ONE * (1.0 + maxf(_stamp_time - 1.2, 0.0) * 2.0)
		_stamp.modulate.a = clampf(_stamp_time / 0.4, 0.0, 1.0)
		if _stamp_time <= 0.0:
			_stamp.visible = false


func _build_summary() -> void:
	_clear(_summary)
	var c := cs.country
	_summary.add_child(GameTheme.make_label("%s · %s" % [tr("ZONE_" + c.zone), c.subregion_ru], 14, GameTheme.BODY_BOLD_FONT, MapPalette.VERMILION))
	_summary.add_child(_note(tr("PHASE_HINT_" + sim.phase_id()), 15))
	_summary.add_child(Panels.meter_row(tr("M_INFLUENCE"), cs.influence, UiText.percent(cs.influence), MapPalette.VERMILION))
	_summary.add_child(Panels.meter_row(tr("M_ORGANIZATION"), cs.organization, str(int(cs.organization))))
	_summary.add_child(Panels.meter_row(tr("M_CONSCIOUSNESS"), cs.consciousness, str(int(cs.consciousness))))
	_summary.add_child(_note(tr("STAGE_LINE") % tr("STAGE_%d" % cs.consciousness_stage()), 14))
	_summary.add_child(Panels.meter_row(tr("M_UNREST"), cs.unrest, str(int(cs.unrest)), MapPalette.OCHRE))
	_summary.add_child(Panels.meter_row(tr("M_VISIBILITY"), cs.visibility, str(int(cs.visibility)), MapPalette.STEEL))
	_summary.add_child(HSeparator.new())
	_summary.add_child(GameTheme.make_label(tr("SEC_REV"), 16, GameTheme.BODY_BOLD_FONT))
	for row in Panels.rev_rows(cs):
		_summary.add_child(row)
	_summary.add_child(_note(Panels.rev_verdict(cs), 14))
	_summary.add_child(HSeparator.new())
	_summary.add_child(_note(tr("CADRES_HINT"), 14))


func _build_cards() -> void:
	_clear(_cards)
	var d := sim.data
	var width := maxf(size.x - SIDE_W - 60.0, 600.0)
	var cols := 2 if width >= 640.0 else 1
	for group in d.action_groups:
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 8)
		head.add_child(Icons.IconView.new(group, MapPalette.VERMILION, 26.0))
		head.add_child(GameTheme.make_label(tr("GROUP_" + group).to_upper(), 20, GameTheme.display_font(600)))
		_cards.add_child(head)
		var grid := GridContainer.new()
		grid.columns = cols
		grid.add_theme_constant_override("h_separation", 12)
		grid.add_theme_constant_override("v_separation", 12)
		for id in d.actions_of(group):
			grid.add_child(_card(id, (width - 12.0 * (cols - 1)) / cols))
		_cards.add_child(grid)


func _card(id: String, width: float) -> Control:
	var a: Dictionary = sim.data.country_actions[id]
	var blockers := PlayerActions.action_blockers(sim, id, cs)
	var available := blockers.is_empty()
	var locked := false
	for b in blockers:
		if b.begins_with("unlock:") or b == "line":
			locked = true
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(width, 0)
	# Касание по карточке уходит к прокрутке: список листается с любого места.
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	var sb := StyleBoxFlat.new()
	sb.bg_color = MapPalette.PAPER if not locked else Color("#E6DCC6")
	sb.border_color = MapPalette.INK if available else Color(MapPalette.INK, 0.3)
	sb.set_border_width_all(3 if available else 2)
	sb.set_content_margin_all(12)
	card.add_theme_stylebox_override("panel", sb)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	card.add_child(box)

	var head := HBoxContainer.new()
	var title := GameTheme.make_label(tr("ACTION_" + id), 19, GameTheme.BODY_BOLD_FONT, MapPalette.INK if not locked else MapPalette.CONCRETE)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.add_child(title)
	if not locked:
		var chance := PlayerActions.action_chance(sim, id, cs)
		head.add_child(_chip(tr("CHANCE") % int(roundf(chance * 100.0)), _chance_color(chance)))
	box.add_child(head)

	var cost := PlayerActions.action_cost(sim, id)
	var costs := HBoxContainer.new()
	costs.add_theme_constant_override("separation", 6)
	if int(cost["cadres"]) > 0:
		costs.add_child(Icons.IconView.new("cadres", MapPalette.INK, 18.0))
		costs.add_child(GameTheme.make_label(tr("COST_CADRES") % int(cost["cadres"]), 15, GameTheme.BODY_BOLD_FONT))
	if int(cost["solidarity"]) > 0:
		costs.add_child(Icons.IconView.new("solidarity", MapPalette.VERMILION, 18.0))
		costs.add_child(GameTheme.make_label(tr("COST") % int(cost["solidarity"]), 15, GameTheme.BODY_BOLD_FONT))
	costs.add_child(GameTheme.make_label("·  " + tr("COOLDOWN") % int(a.get("cooldown_weeks", 0)), 14, null, Color(MapPalette.INK, 0.6)))
	box.add_child(costs)

	var desc := GameTheme.make_label(tr("ACTION_" + id + "_DESC"), 15, null, MapPalette.INK if not locked else Color(MapPalette.INK, 0.55))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size.x = width - 30.0
	box.add_child(desc)

	var foot := HBoxContainer.new()
	var reasons := PackedStringArray()
	for b in blockers:
		reasons.append(UiText.blocker(b))
	var why := GameTheme.make_label(" · ".join(reasons), 14, GameTheme.BODY_BOLD_FONT, MapPalette.STEEL)
	why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	why.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(why)
	var b := Overlays.button(tr("BTN_DO"), func() -> void: pass, available)
	Screens.scroll_safe(b, _cards_scroll, func() -> void: action_requested.emit(id))
	b.custom_minimum_size = Vector2(150, 46)
	b.disabled = not available
	foot.add_child(b)
	box.add_child(foot)
	return card


static func _chance_color(chance: float) -> Color:
	if chance >= 0.65:
		return MapPalette.INK
	if chance >= 0.4:
		return MapPalette.OCHRE.darkened(0.35)
	return MapPalette.STEEL


static func _chip(text: String, color: Color) -> Label:
	var l := GameTheme.make_label(text, 14, GameTheme.BODY_BOLD_FONT, MapPalette.PAPER)
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	l.add_theme_stylebox_override("normal", sb)
	l.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	return l


func _note(text: String, size_px: int) -> Label:
	var l := GameTheme.make_label(text, size_px)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = SIDE_W - 40.0
	return l


static func _clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()
