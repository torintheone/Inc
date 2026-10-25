class_name Panels
extends RefCounted
## Строки показателей для панели страны и экрана действий: название, шкала, значение.

const NAME_W := 150.0
const VALUE_W := 52.0
const REV_THRESHOLD := 70.0


## Строка «название — шкала — значение». mark — отметка порога, ghost — бледный предел.
static func meter_row(name: String, value: float, text: String, color: Color = Color(MapPalette.INK, 0.7),
		mark: float = -1.0, ghost: float = -1.0, hint_key: String = "") -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	if hint_key != "":
		row.set_meta("hint", hint_key)
	var n := GameTheme.make_label(name, 15, null, Color(MapPalette.INK, 0.8))
	n.custom_minimum_size.x = NAME_W
	n.clip_text = true
	n.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(n)
	var m := Meter.new(color, 10.0)
	m.value = value
	m.mark = mark
	m.ghost = ghost
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(m)
	var v := GameTheme.make_label(text, 15, GameTheme.BODY_BOLD_FONT)
	v.custom_minimum_size.x = VALUE_W
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(v)
	return row


## Три условия революционной ситуации. Условие, которое уже набрано, закрашено киноварью.
static func rev_rows(cs: CountryState) -> Array[Control]:
	var out: Array[Control] = []
	var items := [["REV_TOP", cs.top_cant, "HINT_REV_TOP"], ["REV_BOTTOM", cs.bottom_wont, "HINT_REV_BOTTOM"],
		["REV_MASS", cs.mass_activity, "HINT_REV_MASS"]]
	for item: Array in items:
		var v: float = item[1]
		var done := v >= REV_THRESHOLD
		out.append(meter_row(TranslationServer.translate(item[0]), v, str(int(v)),
			MapPalette.VERMILION if done else Color(MapPalette.INK, 0.55), REV_THRESHOLD, -1.0, item[2]))
	return out


## Что мешает революции — одной фразой.
static func rev_verdict(cs: CountryState) -> String:
	if cs.is_revolutionary():
		return _t("REV_DONE")
	var missing := PackedStringArray()
	if cs.top_cant < REV_THRESHOLD:
		missing.append(_t("REV_MISS_TOP"))
	if cs.bottom_wont < REV_THRESHOLD:
		missing.append(_t("REV_MISS_BOTTOM"))
	if cs.mass_activity < REV_THRESHOLD:
		missing.append(_t("REV_MISS_MASS"))
	if missing.is_empty():
		if cs.organization < 50.0:
			return _t("REV_NEED_ORG") % int(cs.organization)
		return _t("REV_READY")
	return _t("REV_MISSING") % [int(cs.rev_situation), ", ".join(missing)]


static func _t(key: String) -> String:
	return TranslationServer.translate(key)
