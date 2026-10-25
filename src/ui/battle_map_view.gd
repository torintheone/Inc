class_name BattleMapView
extends Control
## Карта страны в сражении: районы окрашены по контролю (власть, спорный, революция), на них —
## значки объектов, наши отряды (красные жетоны) и силы власти (синие), баррикады, советы и стачки.
## Колонны войск власти ползут к цели. Касание района выбирает его.

signal region_tapped(index: int)

const MARGIN := 18.0
const TOKEN_R := 13.0
const ICON_R := 7.0
## Касание мимо всех районов, но рядом с подписью района, тоже выбирает его.
const TAP_RADIUS := 34.0

const POWER_LAND := Color("#B9B1A0")
const SUPPORT_TINT := Color("#E3A493")
const CONTESTED_LAND := Color("#D9AE55")
const GARRISON := MapPalette.STEEL

var battle: BattleState
var selected := -1
## Доля текущего дня, которая уже прошла (0–1): по ней движутся колонны.
var day_progress := 0.0

# Контуры районов в координатах карты: [{"rings": [PackedVector2Array], "tris": PackedInt32Array, "points": PackedVector2Array}]
var _shapes: Array = []
var _bounds := Rect2()
var _scale := 1.0
var _offset := Vector2.ZERO
var _font: Font


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	_font = GameTheme.BODY_BOLD_FONT
	resized.connect(_fit)


func setup(p_battle: BattleState) -> void:
	battle = p_battle
	_shapes.clear()
	var first := true
	for r: Dictionary in battle.map["regions"]:
		var polys: Array = []
		for poly: Dictionary in r["polygons"]:
			var rings: Array[PackedVector2Array] = []
			for flat: Array in poly["rings"]:
				var pts := PackedVector2Array()
				for k in range(0, flat.size() - 1, 2):
					var p := Vector2(flat[k], flat[k + 1])
					pts.append(p)
					if first:
						_bounds = Rect2(p, Vector2.ZERO)
						first = false
					else:
						_bounds = _bounds.expand(p)
				rings.append(pts)
			var all_points := PackedVector2Array()
			for ring in rings:
				all_points.append_array(ring)
			polys.append({"rings": rings, "points": all_points, "tris": PackedInt32Array(poly.get("tris", []))})
		_shapes.append(polys)
	_fit()


func _fit() -> void:
	if _bounds.size.x <= 0.0 or size.x <= 0.0:
		return
	var avail := size - Vector2(MARGIN, MARGIN) * 2.0
	_scale = minf(avail.x / _bounds.size.x, avail.y / _bounds.size.y)
	_offset = (size - _bounds.size * _scale) * 0.5 - _bounds.position * _scale
	queue_redraw()


func to_screen(p: Vector2) -> Vector2:
	return p * _scale + _offset


func label_pos(i: int) -> Vector2:
	var l: Array = battle.region(i)["label"]
	return to_screen(Vector2(l[0], l[1]))


func region_color(i: int) -> Color:
	match battle.control[i]:
		BattleState.REVOLUTION:
			return MapPalette.VERMILION
		BattleState.CONTESTED:
			return CONTESTED_LAND
	return POWER_LAND.lerp(SUPPORT_TINT, clampf(battle.support[i] / 100.0, 0.0, 1.0) * 0.7)


func _draw() -> void:
	if battle == null:
		return
	var ci := get_canvas_item()
	var n := battle.region_count()
	# Заливка.
	for i in n:
		var color := region_color(i)
		for poly: Dictionary in _shapes[i]:
			var pts: PackedVector2Array = poly["points"]
			var screen := PackedVector2Array()
			screen.resize(pts.size())
			for k in pts.size():
				screen[k] = to_screen(pts[k])
			var tris: PackedInt32Array = poly["tris"]
			if tris.is_empty():
				draw_colored_polygon(screen, color)
			else:
				var colors := PackedColorArray()
				colors.resize(screen.size())
				colors.fill(color)
				RenderingServer.canvas_item_add_triangle_array(ci, tris, screen, colors)
	# Границы районов, выбранный район — поверх остальных.
	for i in n:
		if i != selected:
			_outline(i, Color(MapPalette.INK, 0.45), 1.2)
	if selected >= 0 and selected < n:
		_outline(selected, MapPalette.INK, 3.5)
	_draw_transfers()
	for i in n:
		_draw_region_marks(i)


func _outline(i: int, color: Color, width: float) -> void:
	for poly: Dictionary in _shapes[i]:
		for ring: PackedVector2Array in poly["rings"]:
			var screen := PackedVector2Array()
			for p in ring:
				screen.append(to_screen(p))
			if not screen.is_empty():
				screen.append(screen[0])
				draw_polyline(screen, color, width, true)


func _draw_transfers() -> void:
	for t: Dictionary in battle.transfers:
		var a := label_pos(int(t.get("from", t["to"])))
		var b := label_pos(int(t["to"]))
		if a.distance_to(b) < 4.0:
			continue
		draw_dashed_line(a, b, Color(GARRISON, 0.7), 2.0, 7.0)
		var sent := float(t.get("sent", battle.day))
		var total := maxf(float(t["arrive"]) - sent, 1.0)
		var k := clampf((float(battle.day) + day_progress - sent) / total, 0.0, 1.0)
		var at := a.lerp(b, k)
		var dir := (b - a).normalized()
		# Колонна: три прямоугольника друг за другом.
		for m in 3:
			var c := at - dir * (m * 9.0)
			draw_rect(Rect2(c - Vector2(4, 4), Vector2(8, 8)), GARRISON)
		_text(at + Vector2(0, -12), str(roundi(float(t["strength"]))), 13, GARRISON)


func _draw_region_marks(i: int) -> void:
	var at := label_pos(i)
	var r := battle.region(i)
	# Объекты — строкой над жетонами.
	var objects: Array = r.get("objects", [])
	var count := objects.size()
	for k in count:
		var obj: String = objects[k]
		var c := at + Vector2((k - (count - 1) * 0.5) * (ICON_R * 2.4), -TOKEN_R - ICON_R - 4.0)
		var seized := battle.seized.has(obj)
		draw_circle(c, ICON_R + 2.5, MapPalette.PAPER)
		set_meta("icon_hole", MapPalette.PAPER)
		var col := MapPalette.VERMILION if seized or (obj == "capital" and battle.control[i] == BattleState.REVOLUTION) else MapPalette.INK
		Icons.draw(self, obj, c, ICON_R, col)
	# Жетоны: наши отряды слева, власть справа.
	var ours := battle.squads[i]
	var theirs := battle.gov[i] + battle.police[i]
	var has_ours := ours >= 0.5
	var has_theirs := theirs >= 0.5
	var shift := TOKEN_R + 1.0 if has_ours and has_theirs else 0.0
	if has_ours:
		# На красном районе жетон темнее, чтобы не сливался.
		var ours_color := MapPalette.REVOLUTIONARY_LAND if battle.control[i] == BattleState.REVOLUTION else MapPalette.VERMILION
		_token(at - Vector2(shift, 0), str(roundi(ours)), ours_color)
	if has_theirs:
		_token(at + Vector2(shift, 0), str(roundi(theirs)), GARRISON if not battle.neutral[i] else MapPalette.CONCRETE)
	# Справа от жетонов — баррикады (с числом), совет, стачка: столбиком, чтобы не наезжать на соседей снизу.
	var marks: Array[String] = []
	if battle.barricades[i] > 0:
		marks.append("barricade")
	if battle.council[i]:
		marks.append("flag")
	if battle.strike_days[i] > 0:
		marks.append("struggle")
	var right := (shift if has_ours or has_theirs else 0.0) + TOKEN_R + 10.0
	for k in marks.size():
		var c := at + Vector2(right, (k - (marks.size() - 1) * 0.5) * 16.0)
		draw_circle(c, 7.5, MapPalette.PAPER)
		Icons.draw(self, marks[k], c, 5.5, MapPalette.INK if marks[k] == "barricade" else MapPalette.VERMILION)
		if marks[k] == "barricade" and battle.barricades[i] > 1:
			_text(c + Vector2(13, 0), "×%d" % battle.barricades[i], 12, MapPalette.INK)
	# Название — у выбранного района, у столицы и там, где хватает места.
	if i == selected or "capital" in objects or _screen_width(i) > 110.0:
		_text(at + Vector2(0, TOKEN_R + 12.0), str(r["name_ru"]), 14, MapPalette.INK)


func _token(c: Vector2, text: String, color: Color) -> void:
	draw_circle(c, TOKEN_R + 2.5, MapPalette.PAPER)
	draw_circle(c, TOKEN_R, color)
	var size_px := 14 if text.length() < 3 else 12
	var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, size_px).x
	draw_string(_font, c + Vector2(-w * 0.5, size_px * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, MapPalette.PAPER)


func _text(c: Vector2, text: String, size_px: int, color: Color) -> void:
	var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, size_px).x
	var pos := c + Vector2(-w * 0.5, size_px * 0.36)
	draw_string_outline(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, 5, MapPalette.PAPER)
	draw_string(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, color)


func _screen_width(i: int) -> float:
	var lo := INF
	var hi := -INF
	for poly: Dictionary in _shapes[i]:
		for p: Vector2 in poly["points"]:
			lo = minf(lo, p.x)
			hi = maxf(hi, p.x)
	return (hi - lo) * _scale


## Район под точкой экрана (−1 — мимо всех).
func region_at(screen_pos: Vector2) -> int:
	if battle == null or _scale <= 0.0:
		return -1
	var p := (screen_pos - _offset) / _scale
	for i in battle.region_count():
		for poly: Dictionary in _shapes[i]:
			var rings: Array = poly["rings"]
			if rings.is_empty() or not Geometry2D.is_point_in_polygon(p, rings[0]):
				continue
			var in_hole := false
			for h in range(1, rings.size()):
				if Geometry2D.is_point_in_polygon(p, rings[h]):
					in_hole = true
			if not in_hole:
				return i
	var best := -1
	var best_d := TAP_RADIUS
	for i in battle.region_count():
		var d := label_pos(i).distance_to(screen_pos)
		if d < best_d:
			best_d = d
			best = i
	return best


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		region_tapped.emit(region_at(event.position))
		accept_event()
