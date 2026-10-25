class_name Meter
extends Control
## Горизонтальная шкала 0–100 с необязательной отметкой порога.

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


func _init(p_color: Color = MapPalette.VERMILION, height: float = 8.0) -> void:
	color = p_color
	custom_minimum_size = Vector2(60, height)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, Color(MapPalette.INK, 0.12))
	draw_rect(Rect2(r.position, Vector2(r.size.x * value / 100.0, r.size.y)), color)
	if mark >= 0.0:
		var x := r.size.x * mark / 100.0
		draw_line(Vector2(x, -2), Vector2(x, r.size.y + 2), MapPalette.INK, 2.0)
