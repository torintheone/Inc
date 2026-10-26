class_name DevelopmentScreen
extends Control
## «Развитие» во весь экран: дерево улучшений в пять ветвей. Сверху — линия движения
## и запас солидарности, внизу — подробности выбранного улучшения и кнопка «Купить».
## Пока экран открыт, время в партии стоит.

signal buy_requested(id: String)
signal change_line_requested
signal close_requested

const HEADER_H := 64.0
const DETAIL_H := 150.0

var sim: SimWorld
var selected := ""

var _tree: _TreeCanvas
var _solidarity: Label
var _line_label: Label
var _line_button: Button
var _detail_icon: Icons.IconView
var _detail_icon_bg: Control
var _detail_art: TextureRect
var _detail_title: Label
var _detail_sub: Label
var _detail_desc: Label
var _detail_effects: Label
var _detail_reason: Label
var _buy: Button


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
	_tree = _TreeCanvas.new()
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tree.node_pressed.connect(_select)
	root.add_child(_tree)
	root.add_child(_build_detail())


func _build_header() -> Control:
	var bar := PanelContainer.new()
	bar.custom_minimum_size = Vector2(0, HEADER_H)
	bar.add_theme_stylebox_override("panel", Screens.band(MapPalette.INK))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	bar.add_child(row)
	row.add_child(GameTheme.make_label(tr("DEV_TITLE").to_upper(), 32, GameTheme.display_font(600), MapPalette.PAPER))
	var line_box := HBoxContainer.new()
	line_box.add_theme_constant_override("separation", 8)
	line_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_line_label = GameTheme.make_label("", 17, GameTheme.BODY_BOLD_FONT, MapPalette.PAPER)
	_line_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line_box.add_child(_line_label)
	_line_button = Screens.light_button(tr("LINE_CHANGE"), func() -> void: change_line_requested.emit())
	line_box.add_child(_line_button)
	row.add_child(line_box)
	row.add_child(Icons.IconView.new("solidarity", MapPalette.VERMILION, 30.0, MapPalette.INK))
	var sol := VBoxContainer.new()
	sol.add_theme_constant_override("separation", -4)
	sol.add_child(GameTheme.make_label(tr("SOLIDARITY"), 13, null, Color(MapPalette.PAPER, 0.75)))
	_solidarity = GameTheme.make_label("0", 26, GameTheme.display_font(600), MapPalette.PAPER)
	sol.add_child(_solidarity)
	row.add_child(sol)
	row.add_child(Screens.close_button(func() -> void: close_requested.emit(), true))
	return bar


func _build_detail() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, DETAIL_H)
	var sb := StyleBoxFlat.new()
	sb.bg_color = MapPalette.PAPER
	sb.border_color = MapPalette.INK
	sb.border_width_top = 3
	sb.content_margin_left = 24
	sb.content_margin_right = 24
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", sb)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	panel.add_child(row)
	_detail_icon = Icons.IconView.new("", MapPalette.PAPER, 72.0, MapPalette.VERMILION)
	_detail_icon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var icon_bg := Screens.disc(MapPalette.VERMILION, 84.0)
	icon_bg.add_child(_detail_icon)
	_detail_icon.position = Vector2(6, 6)
	row.add_child(icon_bg)
	_detail_icon_bg = icon_bg
	# Карточка улучшения из иллюстраций, когда она есть, — вместо значка ветви.
	_detail_art = TextureRect.new()
	_detail_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_detail_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_detail_art.custom_minimum_size = Vector2(84, 84)
	_detail_art.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_detail_art.visible = false
	row.add_child(_detail_art)

	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 2)
	_detail_title = GameTheme.make_label("", 26, GameTheme.display_font(600))
	text.add_child(_detail_title)
	_detail_sub = GameTheme.make_label("", 14, GameTheme.BODY_BOLD_FONT, MapPalette.VERMILION)
	text.add_child(_detail_sub)
	_detail_desc = GameTheme.make_label("", 16)
	_detail_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_child(_detail_desc)
	row.add_child(text)

	var effects := VBoxContainer.new()
	effects.custom_minimum_size = Vector2(330, 0)
	effects.add_theme_constant_override("separation", 2)
	effects.add_child(GameTheme.make_label(tr("DEV_EFFECTS"), 14, GameTheme.BODY_BOLD_FONT, Color(MapPalette.INK, 0.6)))
	_detail_effects = GameTheme.make_label("", 15)
	_detail_effects.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_effects.custom_minimum_size.x = 330
	effects.add_child(_detail_effects)
	row.add_child(effects)

	var act := VBoxContainer.new()
	act.custom_minimum_size = Vector2(220, 0)
	act.alignment = BoxContainer.ALIGNMENT_CENTER
	act.add_theme_constant_override("separation", 6)
	_buy = Overlays.button("", func() -> void:
		if selected != "":
			buy_requested.emit(selected), true)
	_buy.custom_minimum_size = Vector2(220, 56)
	act.add_child(_buy)
	_detail_reason = GameTheme.make_label("", 14, GameTheme.BODY_BOLD_FONT, MapPalette.STEEL)
	_detail_reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_reason.custom_minimum_size.x = 220
	_detail_reason.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	act.add_child(_detail_reason)
	row.add_child(act)
	return panel


func refresh(p_sim: SimWorld) -> void:
	sim = p_sim
	_solidarity.text = str(int(sim.solidarity))
	if sim.line != "":
		_line_label.text = tr("LINE_LABEL") % tr("LINE_" + sim.line)
	else:
		_line_label.text = ""
	_line_button.visible = sim.can_change_line()
	if selected == "":
		selected = _first_available()
	_tree.sim = sim
	_tree.selected = selected
	_tree.queue_redraw()
	_show_detail()


func _first_available() -> String:
	for id in sim.data.upgrade_order:
		if PlayerActions.upgrade_blockers(sim, id).is_empty():
			return id
	for id in sim.data.upgrade_order:
		if not sim.upgrades.has(id):
			return id
	return sim.data.upgrade_order[0]


func _select(id: String) -> void:
	selected = id
	_tree.selected = id
	_tree.queue_redraw()
	_show_detail()


func _show_detail() -> void:
	if selected == "" or not sim.data.upgrades.has(selected):
		return
	var u: Dictionary = sim.data.upgrades[selected]
	var branch := str(u.get("branch", ""))
	_detail_icon.icon = branch
	_detail_icon.queue_redraw()
	var art := ArtLibrary.texture("card_" + selected)
	_detail_art.texture = art
	_detail_art.visible = art != null
	_detail_icon_bg.visible = art == null
	_detail_title.text = tr("UPGRADE_" + selected)
	var cost := PlayerActions.upgrade_cost(sim, selected)
	_detail_sub.text = "%s · %s" % [tr("BRANCH_" + branch).to_upper(), tr("COST") % cost]
	_detail_desc.text = tr("UPGRADE_" + selected + "_DESC")
	_detail_effects.text = "\n".join(Array(UiText.effect_lines(u)).map(func(l: String) -> String: return "• " + l))
	var blockers := PlayerActions.upgrade_blockers(sim, selected)
	var owned := sim.upgrades.has(selected)
	_buy.disabled = not blockers.is_empty()
	_buy.text = tr("BLOCK_owned") if owned else tr("BTN_BUY_FOR") % cost
	var reasons := PackedStringArray()
	for b in blockers:
		if b == "cost":
			reasons.append(tr("DEV_NEED_MORE") % [int(sim.solidarity), cost])
		elif b != "owned":
			reasons.append(UiText.blocker(b))
	_detail_reason.text = "\n".join(reasons)


## Дерево: колонки ветвей, ярусы, связи. Рисуется целиком, касание выбирает улучшение.
class _TreeCanvas:
	extends Control
	signal node_pressed(id: String)

	var sim: SimWorld
	var selected := ""
	var _positions: Dictionary[String, Vector2] = {}
	var _radius := 30.0
	var _time := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		set_meta("icon_hole", MapPalette.PAPER)

	func _process(delta: float) -> void:
		_time += delta
		if visible and sim != null:
			queue_redraw()

	## Высота подписи под кружком (две строки) и отступы яруса.
	const LABEL_H := 40.0
	const LABEL_SIZE := 14
	const HEAD_H := 52.0

	func _layout() -> void:
		_positions.clear()
		var d := sim.data
		var cols := d.branches.size()
		var col_w := size.x / cols
		var tiers := 1
		for id in d.upgrade_order:
			tiers = maxi(tiers, int(d.upgrades[id].get("tier", 0)) + 1)
		var row_h := (size.y - HEAD_H) / tiers
		_radius = clampf(minf((row_h - LABEL_H - 26.0) / 2.0, col_w * 0.12), 16.0, 30.0)
		for c in cols:
			var branch := d.branches[c]
			var by_tier := {}
			for id in d.upgrades_of(branch):
				var t := int(d.upgrades[id].get("tier", 0))
				if not by_tier.has(t):
					by_tier[t] = []
				by_tier[t].append(id)
			for t: int in by_tier:
				var ids: Array = by_tier[t]
				for k in ids.size():
					# Один узел — по центру колонки, два — на четвертях: подписям хватает места.
					var x := col_w * c + (col_w * 0.5 if ids.size() == 1 else col_w * (0.25 + 0.5 * k))
					var y := HEAD_H + row_h * t + 6.0 + _radius
					_positions[ids[k]] = Vector2(x, y)

	## Обход сбоку: от края кружка-требования к краю колонки, вниз и к кружку-улучшению.
	func _side_path(parent: Vector2, child: Vector2) -> PackedVector2Array:
		var col_w := size.x / sim.data.branches.size()
		var x0 := col_w * floorf(parent.x / col_w)
		var rel := parent.x - x0
		var right := rel > col_w * 0.6 or (rel >= col_w * 0.4 and child.x > parent.x)
		var edge := x0 + col_w - 5.0 if right else x0 + 5.0
		var dx := _radius + 2.0 if right else -_radius - 2.0
		return PackedVector2Array([parent + Vector2(dx, 0), Vector2(edge, parent.y), Vector2(edge, child.y),
			child + Vector2(dx, 0)])

	## Ширина подписи узла: вся колонка или её половина.
	func _label_width(id: String) -> float:
		var d := sim.data
		var u: Dictionary = d.upgrades[id]
		var per_tier := 0
		for other in d.upgrades_of(str(u.get("branch", ""))):
			if int(d.upgrades[other].get("tier", 0)) == int(u.get("tier", 0)):
				per_tier += 1
		return size.x / d.branches.size() / maxf(per_tier, 1) - (18.0 if per_tier > 1 else 10.0)

	func _draw() -> void:
		if sim == null:
			return
		_layout()
		var d := sim.data
		var col_w := size.x / d.branches.size()
		var font := GameTheme.BODY_FONT
		var bold := GameTheme.BODY_BOLD_FONT
		# Колонки и заголовки ветвей.
		for c in d.branches.size():
			var x0 := col_w * c
			if c > 0:
				draw_line(Vector2(x0, 44), Vector2(x0, size.y), Color(MapPalette.INK, 0.12), 1.0)
			var head := Rect2(x0 + 8, 8, col_w - 16, 34)
			draw_rect(head, MapPalette.INK)
			var slash := PackedVector2Array([head.position, head.position + Vector2(18, 0),
				head.position + Vector2(8, head.size.y), head.position + Vector2(-10, head.size.y)])
			draw_colored_polygon(slash, MapPalette.VERMILION)
			set_meta("icon_hole", MapPalette.INK)
			Icons.draw(self, d.branches[c], head.position + Vector2(34, 17), 11.0, MapPalette.PAPER)
			set_meta("icon_hole", MapPalette.PAPER)
			draw_string(GameTheme.display_font(600), head.position + Vector2(52, 25), tr("BRANCH_" + d.branches[c]).to_upper(),
				HORIZONTAL_ALIGNMENT_LEFT, head.size.x - 58, 18, MapPalette.PAPER)
		# Связи внутри ветви: от требования вниз к улучшению.
		for id in d.upgrade_order:
			var u: Dictionary = d.upgrades[id]
			for req in PlayerActions.upgrade_requires(sim, id):
				if not _positions.has(req) or d.upgrades[req].get("branch") != u.get("branch"):
					continue
				var a := _positions[req] + Vector2(0, _radius + LABEL_H + 6.0)
				var b := _positions[id] - Vector2(0, _radius + 2.0)
				var mid := a.y + 6.0
				var both := sim.upgrades.has(id) and sim.upgrades.has(req)
				var col := MapPalette.VERMILION if both else (MapPalette.INK if sim.upgrades.has(req) else Color(MapPalette.INK, 0.25))
				var w := 4.0 if both else 3.0
				var path := PackedVector2Array([a, Vector2(a.x, mid), Vector2(b.x, mid), b])
				# Через ярус — сбоку от узла по краю колонки, чтобы линия не шла сквозь другие узлы и подписи.
				if int(d.upgrades[id].get("tier", 0)) - int(d.upgrades[req].get("tier", 0)) > 1:
					path = _side_path(_positions[req], _positions[id])
				draw_polyline(path, col, w, true)
		# Узлы.
		for id in d.upgrade_order:
			_draw_node(id, font, bold)

	func _draw_node(id: String, font: Font, bold: Font) -> void:
		var d := sim.data
		var u: Dictionary = d.upgrades[id]
		var p := _positions[id]
		var r := _radius
		var owned := sim.upgrades.has(id)
		var blockers := PlayerActions.upgrade_blockers(sim, id)
		var open := owned or Array(blockers).filter(func(b: String) -> bool: return b.begins_with("requires:")).is_empty()
		var affordable := blockers.is_empty()
		if id == selected:
			draw_circle(p, r + 9.0, MapPalette.OCHRE)
			draw_circle(p, r + 5.0, MapPalette.PAPER)
		if affordable:
			var pulse := 0.5 + 0.5 * sin(_time * 3.0)
			draw_circle(p, r + 3.0 + 4.0 * pulse, Color(MapPalette.VERMILION, 0.25 * (1.0 - pulse) + 0.1))
		var fill := MapPalette.VERMILION if owned else (MapPalette.PAPER if open else Color("#DDD3BD"))
		var ring := MapPalette.INK if open or owned else MapPalette.CONCRETE
		draw_circle(p, r, ring)
		draw_circle(p, r - (3.0 if open else 2.0), fill)
		var icon_color := MapPalette.PAPER if owned else (MapPalette.VERMILION if affordable else (MapPalette.INK if open else MapPalette.CONCRETE))
		set_meta("icon_hole", fill)
		Icons.draw(self, str(u.get("branch", "")), p, r * 0.5, icon_color)
		set_meta("icon_hole", MapPalette.PAPER)
		if owned:
			var c := p + Vector2(r * 0.72, -r * 0.72)
			draw_circle(c, 10.0, MapPalette.INK)
			draw_polyline(PackedVector2Array([c + Vector2(-5, 0), c + Vector2(-1.5, 4), c + Vector2(5, -4)]), MapPalette.PAPER, 2.5, true)
		else:
			# Цена — плашка у нижнего края кружка.
			var cost := str(PlayerActions.upgrade_cost(sim, id))
			var w := font.get_string_size(cost, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 22.0
			var pill := Rect2(p + Vector2(-w / 2.0, r - 9.0), Vector2(w, 19.0))
			var sb := StyleBoxFlat.new()
			sb.bg_color = MapPalette.INK if open else MapPalette.CONCRETE
			sb.set_corner_radius_all(9)
			draw_style_box(sb, pill)
			set_meta("icon_hole", sb.bg_color)
			Icons.coin(self, pill.position + Vector2(10, 9.5), 5.5, MapPalette.OCHRE)
			set_meta("icon_hole", MapPalette.PAPER)
			draw_string(bold, pill.position + Vector2(18, 15), cost, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, MapPalette.PAPER)
		# Название под кружком, в две строки при необходимости.
		var text_w := _label_width(id)
		var color := MapPalette.INK if open or owned else MapPalette.CONCRETE
		draw_multiline_string(bold if owned or affordable else font, Vector2(p.x - text_w / 2.0, p.y + r + 25.0),
			tr("UPGRADE_" + id), HORIZONTAL_ALIGNMENT_CENTER, text_w, LABEL_SIZE, 2, color)

	func _gui_input(event: InputEvent) -> void:
		var pos := Vector2(-1, -1)
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			pos = event.position
		elif event is InputEventScreenTouch and event.pressed:
			pos = event.position
		if pos.x < 0.0:
			return
		var best := ""
		var best_d := INF
		for id: String in _positions:
			var dist := pos.distance_to(_positions[id] + Vector2(0, LABEL_H * 0.4))
			if dist < best_d:
				best_d = dist
				best = id
		if best != "" and best_d <= _radius + LABEL_H:
			node_pressed.emit(best)
			accept_event()
