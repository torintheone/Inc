class_name Icons
extends RefCounted
## Значки, которые рисует код: ветви развития, ресурсы, пузырьки. Пока нет иллюстраций из
## Grok, они различают улучшения и действия. Каждая функция рисует значок на canvas
## (любой CanvasItem) с центром center и радиусом r.


static func draw(canvas: CanvasItem, name: String, center: Vector2, r: float, color: Color) -> void:
	match name:
		"organization":
			gear(canvas, center, r, color)
		"agitation":
			megaphone(canvas, center, r, color)
		"struggle":
			bolt(canvas, center, r, color)
		"international":
			globe(canvas, center, r, color)
		"defense":
			shield(canvas, center, r, color)
		"solidarity":
			coin(canvas, center, r, color)
		"cadres":
			person(canvas, center, r, color)
		"protest", "flag":
			flag(canvas, center, r, color)
		"economic":
			bolt(canvas, center, r, color)
		"political":
			flag(canvas, center, r, color)
		"organizing":
			gear(canvas, center, r, color)
		_:
			canvas.draw_circle(center, r * 0.5, color)


## Шестерёнка: организация.
static func gear(canvas: CanvasItem, c: Vector2, r: float, color: Color) -> void:
	var pts := PackedVector2Array()
	var teeth := 8
	for i in teeth * 4:
		var a := TAU * float(i) / (teeth * 4) - PI / 2.0
		var rr := r if (i % 4) < 2 else r * 0.74
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	canvas.draw_colored_polygon(pts, color)
	canvas.draw_circle(c, r * 0.32, _hole(canvas))


## Рупор: агитация.
static func megaphone(canvas: CanvasItem, c: Vector2, r: float, color: Color) -> void:
	var horn := PackedVector2Array([c + Vector2(-0.55, -0.22) * r, c + Vector2(0.75, -0.8) * r,
		c + Vector2(0.75, 0.8) * r, c + Vector2(-0.55, 0.22) * r])
	canvas.draw_colored_polygon(horn, color)
	canvas.draw_rect(Rect2(c + Vector2(-0.95, -0.3) * r, Vector2(0.45, 0.6) * r), color)
	canvas.draw_line(c + Vector2(-0.4, 0.25) * r, c + Vector2(-0.2, 0.85) * r, color, maxf(r * 0.22, 2.0))


## Молния: борьба, стачки.
static func bolt(canvas: CanvasItem, c: Vector2, r: float, color: Color) -> void:
	var pts := PackedVector2Array([c + Vector2(0.25, -1.0) * r, c + Vector2(-0.6, 0.12) * r, c + Vector2(-0.02, 0.12) * r,
		c + Vector2(-0.3, 1.0) * r, c + Vector2(0.62, -0.18) * r, c + Vector2(0.05, -0.18) * r])
	canvas.draw_colored_polygon(pts, color)


## Глобус: интернационал.
static func globe(canvas: CanvasItem, c: Vector2, r: float, color: Color) -> void:
	var w := maxf(r * 0.16, 2.0)
	canvas.draw_arc(c, r * 0.9, 0.0, TAU, 40, color, w, true)
	canvas.draw_line(c + Vector2(-0.9, 0) * r, c + Vector2(0.9, 0) * r, color, w)
	canvas.draw_line(c + Vector2(0, -0.9) * r, c + Vector2(0, 0.9) * r, color, w)
	var ellipse := PackedVector2Array()
	for i in 33:
		var a := TAU * float(i) / 32.0
		ellipse.append(c + Vector2(cos(a) * 0.42, sin(a) * 0.9) * r)
	canvas.draw_polyline(ellipse, color, w, true)


## Щит: защита.
static func shield(canvas: CanvasItem, c: Vector2, r: float, color: Color) -> void:
	var pts := PackedVector2Array()
	pts.append(c + Vector2(-0.8, -0.8) * r)
	pts.append(c + Vector2(0.8, -0.8) * r)
	pts.append(c + Vector2(0.8, 0.0) * r)
	for i in range(1, 8):
		var t := float(i) / 8.0
		pts.append(c + Vector2(0.8 * (1.0 - t), 0.0 + t * 1.0) * r)
	pts.append(c + Vector2(0.0, 1.0) * r)
	for i in range(1, 8):
		var t := float(i) / 8.0
		pts.append(c + Vector2(-0.8 * t, 1.0 - t * 1.0) * r)
	pts.append(c + Vector2(-0.8, 0.0) * r)
	canvas.draw_colored_polygon(pts, color)
	canvas.draw_line(c + Vector2(0, -0.6) * r, c + Vector2(0, 0.7) * r, _hole(canvas), maxf(r * 0.16, 2.0))


## Монета-кружок: солидарность.
static func coin(canvas: CanvasItem, c: Vector2, r: float, color: Color) -> void:
	canvas.draw_circle(c, r, color)
	canvas.draw_arc(c, r * 0.68, 0.0, TAU, 32, _hole(canvas), maxf(r * 0.16, 1.5), true)
	canvas.draw_circle(c, r * 0.24, _hole(canvas))


## Человек: кадры.
static func person(canvas: CanvasItem, c: Vector2, r: float, color: Color) -> void:
	canvas.draw_circle(c + Vector2(0, -0.48) * r, r * 0.36, color)
	var body := PackedVector2Array([c + Vector2(-0.72, 1.0) * r, c + Vector2(-0.6, 0.15) * r, c + Vector2(-0.3, -0.05) * r,
		c + Vector2(0.3, -0.05) * r, c + Vector2(0.6, 0.15) * r, c + Vector2(0.72, 1.0) * r])
	canvas.draw_colored_polygon(body, color)


## Флаг: протест, политическая борьба.
static func flag(canvas: CanvasItem, c: Vector2, r: float, color: Color) -> void:
	canvas.draw_line(c + Vector2(-0.6, -0.95) * r, c + Vector2(-0.6, 1.0) * r, color, maxf(r * 0.2, 2.0))
	var cloth := PackedVector2Array([c + Vector2(-0.55, -0.9) * r, c + Vector2(0.9, -0.62) * r,
		c + Vector2(0.45, -0.3) * r, c + Vector2(0.9, 0.05) * r, c + Vector2(-0.55, 0.1) * r])
	canvas.draw_colored_polygon(cloth, color)


## Цвет «прорези» в значке — цвет фона, на котором он нарисован.
static func _hole(canvas: CanvasItem) -> Color:
	var bg: Variant = canvas.get_meta("icon_hole", MapPalette.PAPER)
	return bg


## Готовый узел-значок для интерфейса.
class IconView:
	extends Control
	var icon := ""
	var color := MapPalette.INK
	var hole := MapPalette.PAPER

	func _init(p_icon: String = "", p_color: Color = MapPalette.INK, p_size: float = 24.0, p_hole: Color = MapPalette.PAPER) -> void:
		icon = p_icon
		color = p_color
		hole = p_hole
		custom_minimum_size = Vector2(p_size, p_size)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		set_meta("icon_hole", hole)
		Icons.draw(self, icon, size * 0.5, minf(size.x, size.y) * 0.42, color)
