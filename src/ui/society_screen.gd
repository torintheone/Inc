class_name SocietyScreen
extends Control
## «Новое общество» во весь экран: слева — шесть показателей революционной страны и что на них
## давит; справа — три политики (деревня, экономика, внешняя линия) карточками вариантов.
## Политику можно менять не чаще раза в год. Пока экран открыт, время в партии стоит.

signal policy_requested(policy: String, option: String)
signal close_requested

const SIDE_W := 400.0
const SIDE_BG := Color("#E6DCC6")
## Цвет шкалы и отметка порога для каждого показателя.
const INDICATORS := [["democracy", MapPalette.VERMILION, -1.0], ["bureaucracy", MapPalette.STEEL, -1.0],
	["food", MapPalette.OCHRE, 30.0], ["production", MapPalette.INK, -1.0], ["defense", MapPalette.STEEL, -1.0],
	["support", MapPalette.VERMILION, 30.0]]

var sim: SimWorld
var cs: CountryState

var _title: Label
var _summary: VBoxContainer
var _cards: VBoxContainer
var _cards_scroll: ScrollContainer


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

	var bar := PanelContainer.new()
	bar.custom_minimum_size = Vector2(0, 64)
	bar.add_theme_stylebox_override("panel", Screens.band(MapPalette.INK))
	var row := HBoxContainer.new()
	bar.add_child(row)
	_title = GameTheme.make_label("", 30, GameTheme.display_font(600), MapPalette.PAPER)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.clip_text = true
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(_title)
	row.add_child(Screens.close_button(func() -> void: close_requested.emit(), true))
	root.add_child(bar)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 0)
	root.add_child(body)
	var side := PanelContainer.new()
	side.custom_minimum_size = Vector2(SIDE_W, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = SIDE_BG
	sb.set_content_margin_all(18)
	side.add_theme_stylebox_override("panel", sb)
	var side_scroll := ScrollContainer.new()
	side_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	side.add_child(side_scroll)
	_summary = VBoxContainer.new()
	_summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_summary.add_theme_constant_override("separation", 6)
	side_scroll.add_child(_summary)
	body.add_child(side)

	_cards_scroll = ScrollContainer.new()
	_cards_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cards_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side_name in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side_name, 18)
	_cards_scroll.add_child(margin)
	_cards = VBoxContainer.new()
	_cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cards.add_theme_constant_override("separation", 10)
	margin.add_child(_cards)
	body.add_child(_cards_scroll)
	resized.connect(func() -> void:
		if sim != null:
			_build_cards())


func refresh(p_sim: SimWorld, p_cs: CountryState) -> void:
	sim = p_sim
	cs = p_cs
	_title.text = (tr("SOCIETY_TITLE") % cs.country.name_ru).to_upper()
	_build_summary()
	_build_cards()


## Строки показателей нового общества — для этого экрана и для панели страны.
static func indicator_rows(p_cs: CountryState) -> Array[Control]:
	var out: Array[Control] = []
	for item: Array in INDICATORS:
		var f: String = item[0]
		var v := p_cs.get_field(f)
		out.append(Panels.meter_row(TranslationServer.translate("F_" + f), v, str(roundi(v)), item[1], item[2], -1.0, "SOC_" + f))
	return out


## Что сейчас давит на революцию: изоляция, война, Термидор, угроза контрреволюции.
static func notes(p_sim: SimWorld, p_cs: CountryState) -> PackedStringArray:
	var t := TranslationServer.translate
	var out := PackedStringArray()
	if NewSociety.is_thermidor(p_cs):
		out.append(t.call("SOCIETY_THERMIDOR"))
		return out
	var revs := NewSociety.living_revolutions(p_sim)
	out.append(t.call("SOCIETY_ISOLATED") if revs <= 1 else t.call("SOCIETY_ALLIES") % revs)
	if NewSociety.at_war(p_sim, p_cs):
		out.append(t.call("SOCIETY_WAR"))
	if NewSociety.under_intervention(p_sim, p_cs) and p_cs.support < p_sim.data.num("society.counter.support_below"):
		out.append(t.call("SOCIETY_COUNTER_RISK"))
	return out


func _build_summary() -> void:
	CountryPanel._clear(_summary)
	_summary.add_child(_label(tr("SOCIETY_INDICATORS"), 22, GameTheme.display_font(600)))
	for r in indicator_rows(cs):
		_summary.add_child(r)
		# Подсказка — сразу под строкой: на этом экране места хватает.
		_summary.add_child(_label(tr(r.get_meta("hint")), 13, null, Color(MapPalette.INK, 0.6)))
	var target := NewSociety.bureaucracy_target(sim, cs)
	var arrow := "↑" if target > cs.bureaucracy + 1.0 else ("↓" if target < cs.bureaucracy - 1.0 else "→")
	_summary.add_child(HSeparator.new())
	_summary.add_child(_label(tr("SOCIETY_BUREAUCRACY_TREND") % [roundi(minf(target, 100.0)), arrow], 15,
		GameTheme.BODY_BOLD_FONT, MapPalette.STEEL))
	for note in notes(sim, cs):
		_summary.add_child(_label(note, 15, null, MapPalette.VERMILION))
	_summary.add_child(_label(tr("SOCIETY_GIVES"), 14, null, Color(MapPalette.INK, 0.75)))


func _build_cards() -> void:
	CountryPanel._clear(_cards)
	_cards.add_child(_label(tr("SOCIETY_POLICY_HINT"), 15, null, Color(MapPalette.INK, 0.7)))
	var avail := maxf(_cards_scroll.size.x - 36.0, 600.0)
	for policy in NewSociety.POLICIES:
		var head := HBoxContainer.new()
		var name := _label(tr("POLICY_" + policy).to_upper(), 20, GameTheme.display_font(600), MapPalette.VERMILION)
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name.autowrap_mode = TextServer.AUTOWRAP_OFF
		head.add_child(name)
		var weeks := NewSociety.weeks_to_change(sim, cs, policy)
		var when := _label(tr("SOCIETY_CHANGE_NOW") if weeks == 0 else tr("SOCIETY_CHANGE_IN") % weeks, 14,
			GameTheme.BODY_BOLD_FONT, MapPalette.INK if weeks == 0 else MapPalette.CONCRETE)
		when.custom_minimum_size.x = 0.0
		when.autowrap_mode = TextServer.AUTOWRAP_OFF
		when.size_flags_vertical = Control.SIZE_SHRINK_END
		head.add_child(when)
		_cards.add_child(head)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var options: PackedStringArray = sim.data.society_options.get(policy, PackedStringArray())
		var card_w := (avail - 10.0 * (options.size() - 1)) / maxf(options.size(), 1)
		for o in options:
			row.add_child(_card(policy, o, card_w))
		_cards.add_child(row)


func _card(policy: String, option_id: String, width: float) -> Control:
	var current: bool = cs.policies.get(policy, "") == option_id
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(width, 0)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = MapPalette.INK if current else Color("#F4ECDA")
	sb.border_color = MapPalette.INK
	sb.set_border_width_all(2)
	sb.set_content_margin_all(12)
	card.add_theme_stylebox_override("panel", sb)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	card.add_child(box)
	var ink := MapPalette.PAPER if current else MapPalette.INK
	var title := _label(tr("POLICY_%s_%s" % [policy, option_id]), 18, GameTheme.BODY_BOLD_FONT, ink)
	title.custom_minimum_size.x = width - 28.0
	box.add_child(title)
	var desc := _label(tr("POLICY_%s_%s_DESC" % [policy, option_id]), 14, null, Color(ink, 0.85))
	desc.custom_minimum_size.x = width - 28.0
	desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(desc)
	if current:
		box.add_child(_label(tr("SOCIETY_CURRENT").to_upper(), 13, GameTheme.BODY_BOLD_FONT, MapPalette.OCHRE))
	else:
		var btn := Button.new()
		btn.text = tr("BTN_CHOOSE")
		btn.custom_minimum_size = Vector2(0, 42)
		btn.disabled = not NewSociety.can_change(sim, cs, policy, option_id)
		Screens.scroll_safe(btn, _cards_scroll, func() -> void: policy_requested.emit(policy, option_id))
		box.add_child(btn)
	return card


func _label(text: String, size_px: int, font: Font = null, color: Color = MapPalette.INK) -> Label:
	var l := GameTheme.make_label(text, size_px, font, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = SIDE_W - 40.0 if size_px < 20 else 0.0
	return l
