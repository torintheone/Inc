class_name TopBar
extends PanelContainer
## Верхняя строка: дата и год партии, фаза цикла, солидарность, шкала Реакции
## с порогами, справка и скорость.

signal speed_selected(speed: int)
signal help_requested

## Скорости: 0 — пауза, 1, 2, 4 — во сколько раз быстрее.
const SPEEDS: PackedInt32Array = [0, 1, 2, 4]

var _date: Label
var _phase: Label
var _solidarity: Label
var _reaction_label: Label
var _reaction_next: Label
var _reaction: Meter
var _fps: Label
var _speed_buttons: Array[Button] = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	add_child(row)

	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", -2)
	left.add_child(GameTheme.make_label(tr("GAME_TITLE").to_upper(), 22, GameTheme.display_font(600), MapPalette.VERMILION))
	_date = GameTheme.make_label("", GameTheme.SMALL_SIZE)
	left.add_child(_date)
	row.add_child(left)

	_phase = GameTheme.make_label("", 16, GameTheme.BODY_BOLD_FONT, MapPalette.PAPER)
	_phase.add_theme_stylebox_override("normal", _chip(MapPalette.INK))
	_phase.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_phase)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	var sol_icon := Icons.IconView.new("solidarity", MapPalette.VERMILION, 28.0)
	sol_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(sol_icon)
	var sol := VBoxContainer.new()
	sol.add_theme_constant_override("separation", -4)
	sol.add_child(GameTheme.make_label(tr("SOLIDARITY"), 12, null, Color(MapPalette.INK, 0.7)))
	_solidarity = GameTheme.make_label("0", 24, GameTheme.display_font(600), MapPalette.VERMILION)
	sol.add_child(_solidarity)
	row.add_child(sol)

	var reaction := VBoxContainer.new()
	reaction.custom_minimum_size = Vector2(230, 0)
	reaction.add_theme_constant_override("separation", 2)
	_reaction_label = GameTheme.make_label("", 14, GameTheme.BODY_BOLD_FONT, MapPalette.STEEL)
	reaction.add_child(_reaction_label)
	_reaction = Meter.new(MapPalette.STEEL, 10.0)
	_reaction.ticks = PackedFloat32Array([20, 40, 60, 80])
	reaction.add_child(_reaction)
	_reaction_next = GameTheme.make_label("", 12, null, Color(MapPalette.INK, 0.65))
	_reaction_next.clip_text = true
	_reaction_next.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_reaction_next.custom_minimum_size.x = 230
	reaction.add_child(_reaction_next)
	reaction.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(reaction)

	var spacer2 := Control.new()
	spacer2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer2)

	var help := Button.new()
	help.text = "?"
	help.tooltip_text = tr("HELP_TITLE")
	help.custom_minimum_size = Vector2(44, 44)
	help.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	help.add_theme_font_size_override("font_size", 22)
	help.pressed.connect(func() -> void: help_requested.emit())
	row.add_child(help)

	var speeds := HBoxContainer.new()
	speeds.add_theme_constant_override("separation", 4)
	for s in SPEEDS:
		var b := Button.new()
		b.text = "II" if s == 0 else "×%d" % s
		b.tooltip_text = tr("SPEED_PAUSE") if s == 0 else "×%d" % s
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(52, 44)
		b.pressed.connect(func() -> void: speed_selected.emit(s))
		speeds.add_child(b)
		_speed_buttons.append(b)
	speeds.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(speeds)

	_fps = GameTheme.make_label("", 12, null, Color(MapPalette.INK, 0.5))
	_fps.custom_minimum_size = Vector2(54, 0)
	_fps.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_fps)


func show_speed(speed: int) -> void:
	for i in SPEEDS.size():
		_speed_buttons[i].set_pressed_no_signal(SPEEDS[i] == speed)


func refresh(sim: SimWorld) -> void:
	var per_year := int(sim.data.num("time.weeks_per_year"))
	_date.text = tr("DATE_LINE") % [UiText.date(sim, sim.week), sim.week / per_year + 1, int(sim.data.num("time.max_years"))]
	var ph := sim.phase_id()
	_phase.text = "  %s  " % tr("PHASE_" + ph).to_upper()
	var slump := EconomySystem.is_slump(ph)
	_phase.add_theme_stylebox_override("normal", _chip(MapPalette.VERMILION if slump else MapPalette.INK))
	_phase.tooltip_text = tr("PHASE_HINT_" + ph)
	_solidarity.text = str(int(sim.solidarity))
	_reaction.value = sim.reaction
	_reaction_label.text = "%s %d" % [tr("REACTION"), int(sim.reaction)]
	_reaction_next.text = _next_threshold(sim.reaction)


static func _next_threshold(reaction: float) -> String:
	for t in ReactionSystem.THRESHOLDS:
		if reaction < t:
			return TranslationServer.translate("REACTION_NEXT_%d" % t)
	return TranslationServer.translate("REACTION_NEXT_MAX")


func set_fps(fps: float) -> void:
	_fps.text = tr("FPS") % fps


static func _chip(color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	return sb
