class_name Meter
extends Control
## Горизонтальная шкала 0–100: скруглённая полоса, необязательная отметка порога
## и необязательная вторая, бледная полоса (например, потолок влияния).

var value := 0.0:
	set(v):
		value = clampf(v, 0.0, 100.0)
		queue_redraw()
var color := MapPalette.VERMILION:
	set(v):
		color = v
		queue_redraw()
## Отметка порога (например, 70 для революционной ситуации); меньше нуля — без отметки.
var mark := -1.0:
	set(v):
		mark = v
		queue_redraw()
## Бледная полоса под основной (потолок, предел); меньше нуля — без неё.
var ghost := -1.0:
	set(v):
		ghost = v
		queue_redraw()
## Деления шкалы (например, пороги Реакции 20/40/60/80).
var ticks := PackedFloat32Array():
	set(v):
		ticks = v
		queue_redraw()


func _init(p_color: Color = MapPalette.VERMILION, height: float = 8.0) -> void:
	color = p_color
	custom_minimum_size = Vector2(60, height)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var radius := int(size.y / 2.0)
	_bar(r, Color(MapPalette.INK, 0.1), radius)
	if ghost > 0.0:
		_bar(Rect2(r.position, Vector2(r.size.x * clampf(ghost, 0.0, 100.0) / 100.0, r.size.y)), Color(color, 0.25), radius)
	if value > 0.0:
		var w := maxf(r.size.x * value / 100.0, size.y)
		_bar(Rect2(r.position, Vector2(w, r.size.y)), color, radius)
	for t in ticks:
		var x := r.size.x * t / 100.0
		draw_line(Vector2(x, 0), Vector2(x, r.size.y), MapPalette.PAPER, 2.0)
	if mark >= 0.0:
		var x := r.size.x * mark / 100.0
		draw_line(Vector2(x, -3), Vector2(x, r.size.y + 3), MapPalette.INK, 2.0)


func _bar(rect: Rect2, c: Color, radius: int) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.set_corner_radius_all(radius)
	draw_style_box(sb, rect)
