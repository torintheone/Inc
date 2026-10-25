class_name LineChart
extends Control
## Линейный график одного ряда с заливкой под линией: подписи осей, бледная сетка,
## необязательные пороговые линии. Касание или наведение показывает перекрестье
## и значение в точке. Название графика — снаружи, в заголовке над ним.

## Значения ряда и подписи по оси X (например, годы) — одинаковой длины.
var values := PackedFloat32Array()
var x_labels := PackedStringArray()
var color := MapPalette.VERMILION
## Верх шкалы; 0 — подобрать по данным.
var y_max := 0.0
## Пороговые линии, например пороги Реакции.
var thresholds := PackedFloat32Array()
## Как подписывать значения (число → текст).
var format: Callable = func(v: float) -> String: return str(int(roundf(v)))

const PAD_LEFT := 52.0
const PAD_BOTTOM := 26.0
const PAD_TOP := 10.0
const PAD_RIGHT := 12.0

var _hover := -1


func _init() -> void:
	custom_minimum_size = Vector2(320, 160)
	mouse_filter = Control.MOUSE_FILTER_STOP


func set_series(p_values: PackedFloat32Array, p_labels: PackedStringArray) -> void:
	values = p_values
	x_labels = p_labels
	_hover = -1
	queue_redraw()


func _top() -> float:
	if y_max > 0.0:
		return y_max
	var m := 0.0
	for v in values:
		m = maxf(m, v)
	return _nice(maxf(m, 1.0))


## Круглое число не меньше v: 1, 2, 5 × 10^n.
static func _nice(v: float) -> float:
	var p := pow(10.0, floorf(log(v) / log(10.0)))
	for k: float in [1.0, 2.0, 5.0, 10.0]:
		if v <= k * p:
			return k * p
	return 10.0 * p


func _plot_rect() -> Rect2:
	return Rect2(PAD_LEFT, PAD_TOP, size.x - PAD_LEFT - PAD_RIGHT, size.y - PAD_TOP - PAD_BOTTOM)


func _point(i: int, plot: Rect2, top: float) -> Vector2:
	var t := float(i) / maxf(values.size() - 1, 1)
	return Vector2(plot.position.x + t * plot.size.x, plot.end.y - clampf(values[i] / top, 0.0, 1.0) * plot.size.y)


func _draw() -> void:
	var plot := _plot_rect()
	var top := _top()
	var font := GameTheme.BODY_FONT
	var muted := Color(MapPalette.INK, 0.6)
	# Сетка и подписи по Y: 0, половина, верх.
	for k: float in [0.0, 0.5, 1.0]:
		var y := plot.end.y - k * plot.size.y
		draw_line(Vector2(plot.position.x, y), Vector2(plot.end.x, y), Color(MapPalette.INK, 0.12 if k > 0.0 else 0.4), 1.0)
		draw_string(font, Vector2(0, y + 5), format.call(top * k), HORIZONTAL_ALIGNMENT_RIGHT, PAD_LEFT - 8, 13, muted)
	for t in thresholds:
		if t <= top:
			var y := plot.end.y - t / top * plot.size.y
			_dashed(Vector2(plot.position.x, y), Vector2(plot.end.x, y), Color(MapPalette.STEEL, 0.45))
	if values.size() < 2:
		draw_string(font, plot.get_center() + Vector2(-60, 0), tr("CHART_NO_DATA"), HORIZONTAL_ALIGNMENT_CENTER, 120, 14, muted)
		return
	# Подписи по X: не больше шести, без наложений.
	var step := maxi(1, int(ceilf(values.size() / 6.0)))
	for i in range(0, values.size(), step):
		var p := _point(i, plot, top)
		if i < x_labels.size():
			draw_string(font, Vector2(p.x - 30, size.y - 6), x_labels[i], HORIZONTAL_ALIGNMENT_CENTER, 60, 13, muted)
	var line := PackedVector2Array()
	for i in values.size():
		line.append(_point(i, plot, top))
	var area := line.duplicate()
	area.append(Vector2(plot.end.x, plot.end.y))
	area.append(Vector2(plot.position.x, plot.end.y))
	draw_colored_polygon(area, Color(color, 0.14))
	draw_polyline(line, color, 2.0, true)
	if _hover >= 0 and _hover < values.size():
		var p := _point(_hover, plot, top)
		draw_line(Vector2(p.x, plot.position.y), Vector2(p.x, plot.end.y), Color(MapPalette.INK, 0.35), 1.0)
		draw_circle(p, 6.0, MapPalette.PAPER)
		draw_circle(p, 4.0, color)
		var label := "%s: %s" % [x_labels[_hover] if _hover < x_labels.size() else "", format.call(values[_hover])]
		var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 16.0
		var box := Rect2(clampf(p.x - w / 2.0, 0.0, size.x - w), maxf(p.y - 34.0, 0.0), w, 24.0)
		var sb := StyleBoxFlat.new()
		sb.bg_color = MapPalette.INK
		sb.set_corner_radius_all(4)
		draw_style_box(sb, box)
		draw_string(font, box.position + Vector2(8, 17), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, MapPalette.PAPER)


func _dashed(a: Vector2, b: Vector2, c: Color) -> void:
	var length := a.distance_to(b)
	var dir := (b - a) / maxf(length, 1.0)
	var t := 0.0
	while t < length:
		draw_line(a + dir * t, a + dir * minf(t + 6.0, length), c, 1.0)
		t += 12.0


func _gui_input(event: InputEvent) -> void:
	var pos := Vector2(-1, -1)
	if event is InputEventMouseMotion or event is InputEventScreenDrag:
		pos = event.position
	elif event is InputEventMouseButton and event.pressed:
		pos = event.position
	elif event is InputEventScreenTouch and event.pressed:
		pos = event.position
	if pos.x < 0.0 or values.size() < 2:
		return
	var plot := _plot_rect()
	var t := clampf((pos.x - plot.position.x) / plot.size.x, 0.0, 1.0)
	var i := int(roundf(t * (values.size() - 1)))
	if i != _hover:
		_hover = i
		queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT and _hover >= 0:
		_hover = -1
		queue_redraw()
