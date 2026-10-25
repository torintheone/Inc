class_name EventScreen
extends Control
## Окно события: слева иллюстрация (пока — заглушка с значком категории), справа —
## что случилось и где, и 2–3 варианта решения. У каждого варианта видно, что он даст,
## сколько стоит и с каким шансом удастся; недоступный вариант объясняет почему.

signal option_chosen(id: String)

const ART_W := 380.0
const TEXT_W := 640.0

## Значок категории на заглушке иллюстрации.
const CATEGORY_ICONS := {"economy": "struggle", "state": "defense", "world": "international", "movement": "flag"}


func _init(sim: SimWorld) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(MapPalette.INK, 0.5)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	panel.add_child(row)

	var id: String = sim.pending_event["id"]
	var e: Dictionary = sim.data.events[id]
	var cs := EventSystem.pending_country(sim)
	var stub := _ArtStub.new()
	stub.icon = CATEGORY_ICONS.get(e.get("category", ""), "flag")
	stub.custom_minimum_size = Vector2(ART_W, 520)
	row.add_child(stub)

	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(TEXT_W, 0)
	box.add_theme_constant_override("separation", 8)
	row.add_child(box)
	box.add_child(GameTheme.make_label(tr("CATEGORY_" + str(e.get("category", ""))).to_upper(), 14, GameTheme.BODY_BOLD_FONT,
		MapPalette.VERMILION))
	var title := GameTheme.make_label(tr("EVENT_" + id), 30, GameTheme.display_font(600))
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.custom_minimum_size.x = TEXT_W
	box.add_child(title)
	box.add_child(GameTheme.make_label(cs.country.name_ru if cs != null else tr("EVENT_WORLD"), 16, GameTheme.BODY_BOLD_FONT,
		Color(MapPalette.INK, 0.6)))
	var text := GameTheme.make_label(situation(tr("EVENT_%s_TEXT" % id)), 18)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size.x = TEXT_W
	box.add_child(text)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 6)
	box.add_child(spacer)
	for o: Dictionary in e["options"]:
		box.add_child(_option(sim, id, o))


## Текст события без «Страна: » в начале — страна и так подписана над ним.
static func situation(template: String) -> String:
	if template.begins_with("%s: "):
		var rest := template.substr(4)
		return rest.left(1).to_upper() + rest.substr(1)
	return template.replace("%s", "")


func _option(sim: SimWorld, event_id: String, o: Dictionary) -> Control:
	var blockers := EventSystem.option_blockers(sim, o)
	var enabled := blockers.is_empty()
	# Карточка-кнопка: PanelContainer подстраивает высоту под текст, касание выбирает вариант.
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(TEXT_W, 0)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	var normal := StyleBoxFlat.new()
	normal.bg_color = MapPalette.PAPER
	normal.border_color = MapPalette.INK if enabled else Color(MapPalette.INK, 0.25)
	normal.set_border_width_all(3 if enabled else 2)
	normal.set_content_margin_all(12)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.border_color = MapPalette.VERMILION
	hover.bg_color = Color(MapPalette.VERMILION, 0.08)
	card.add_theme_stylebox_override("panel", normal)
	if enabled:
		card.mouse_entered.connect(func() -> void: card.add_theme_stylebox_override("panel", hover))
		card.mouse_exited.connect(func() -> void: card.add_theme_stylebox_override("panel", normal))
		card.gui_input.connect(func(ev: InputEvent) -> void:
			if (ev is InputEventMouseButton and not ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT) \
					or (ev is InputEventScreenTouch and not ev.pressed):
				option_chosen.emit(o["id"]))
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 2)
	card.add_child(box)
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var name := GameTheme.make_label(tr("EVENT_%s_%s" % [event_id, o["id"]]), 18, GameTheme.BODY_BOLD_FONT,
		MapPalette.INK if enabled else MapPalette.CONCRETE)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.add_child(name)
	if o.has("chance"):
		head.add_child(ActionsScreen._chip(tr("EVENT_CHANCE") % int(roundf(float(o["chance"]) * 100.0)),
			ActionsScreen._chance_color(float(o["chance"]))))
	box.add_child(head)
	var lines := PackedStringArray()
	var cost := UiText.event_cost(o)
	if cost != "":
		lines.append(tr("EVENT_PAY") % cost)
	var effect := UiText.event_effects(o.get("effects", {}))
	lines.append(effect if effect != "" else tr("EVENT_NOTHING"))
	if o.has("fail"):
		var fail := UiText.event_effects(o["fail"])
		lines.append(tr("EVENT_FAIL") % (fail if fail != "" else tr("EVENT_NOTHING")))
	var details := GameTheme.make_label("\n".join(lines), 14, null, Color(MapPalette.INK, 0.75 if enabled else 0.45))
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.custom_minimum_size.x = TEXT_W - 30.0
	box.add_child(details)
	if not enabled:
		var reasons := PackedStringArray()
		for code in blockers:
			reasons.append(UiText.blocker(code))
		var why := GameTheme.make_label(" · ".join(reasons), 14, GameTheme.BODY_BOLD_FONT, MapPalette.STEEL)
		why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		why.custom_minimum_size.x = TEXT_W - 30.0
		box.add_child(why)
	return card


## Заглушка иллюстрации, пока нет картинки из Grok: тёмное поле, косая полоса, значок категории.
class _ArtStub:
	extends Control
	var icon := "flag"

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, MapPalette.INK)
		var band := PackedVector2Array([Vector2(0, size.y * 0.62), Vector2(size.x, size.y * 0.28),
			Vector2(size.x, size.y * 0.44), Vector2(0, size.y * 0.78)])
		draw_colored_polygon(band, MapPalette.VERMILION)
		# Растровые точки, как на старом плакате.
		for y in range(12, int(size.y), 18):
			for x in range(12 + (y / 18 % 2) * 9, int(size.x), 18):
				draw_circle(Vector2(x, y), 1.6, Color(MapPalette.PAPER, 0.08))
		set_meta("icon_hole", MapPalette.INK)
		Icons.draw(self, icon, Vector2(size.x * 0.5, size.y * 0.38), size.x * 0.22, MapPalette.PAPER)
