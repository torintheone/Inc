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
		"capital":
			star(canvas, center, r, color)
		"factories":
			factory(canvas, center, r, color)
		"railway":
			rails(canvas, center, r, color)
		"port":
			anchor(canvas, center, r, color)
		"comms":
			antenna(canvas, center, r, color)
		"arsenal":
			crate(canvas, center, r, color)
		"agrarian":
			wheat(canvas, center, r, color)
		"barricade":
			barricade(canvas, center, r, color)
		"garrison":
			helmet(canvas, center, r, color)
		"squads":
			shield(canvas, center, r, color)
		"supplies":
			bread(canvas, center, r, color)
		"weapons":
			rifle(canvas, center, r, color)
		"emblem":
			emblem(canvas, center, r)
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


## Пятиконечная звезда: столица.
static func star(canvas: CanvasItem, c: Vector2, r: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := TAU * float(i) / 10.0 - PI / 2.0
		pts.append(c + Vector2(cos(a), sin(a)) * (r if i % 2 == 0 else r * 0.42))
	canvas.draw_colored_polygon(pts, color)


## Цех с пилообразной крышей и трубой: заводы.
static func factory(canvas: CanvasItem, c: Vector2, r: float, color: Color) -> void:
	var pts := PackedVector2Array([c + Vector2(-1.0, 0.9) * r, c + Vector2(-1.0, -0.1) * r, c + Vector2(-0.45, -0.5) * r,
		c + Vector2(-0.45, -0.1) * r, c + Vector2(0.1, -0.5) * r, c + Vector2(0.1, -0.1) * r, c + Vector2(0.55, -0.5) * r,
		c + Vector2(0.55, -1.0) * r, c + Vector2(0.95, -1.0) * r, c + Vector2(0.95, 0.9) * r])
	canvas.draw_colored_polygon(pts, color)


## Рельсы со шпалами: железнодорожный узел.
static func rails(canvas: CanvasItem, c: Vector2, r: float, color: Color) -> void:
	var w := maxf(r * 0.18, 1.5)
	canvas.draw_line(c + Vector2(-1.0, -0.4) * r, c + Vector2(1.0, -0.4) * r, color, w)
	canvas.draw_line(c + Vector2(-1.0, 0.4) * r, c + Vector2(1.0, 0.4) * r, color, w)
	for x in [-0.7, -0.23, 0.23, 0.7]:
		canvas.draw_line(c + Vector2(x, -0.75) * r, c + Vector2(x, 0.75) * r, color, w)


## Якорь: порт.
static func anchor(canvas: CanvasItem, c: Vector2, r: float, color: Color) -> void:
	var w := maxf(r * 0.2, 1.5)
	canvas.draw_arc(c + Vector2(0, -0.72) * r, r * 0.24, 0.0, TAU, 16, color, w)
	canvas.draw_line(c + Vector2(0, -0.48) * r, c + Vector2(0, 0.95) * r, color, w)
	canvas.draw_line(c + Vector2(-0.45, -0.2) * r, c + Vector2(0.45, -0.2) * r, color, w)
	canvas.draw_arc(c + Vector2(0, 0.2) * r, r * 0.75, 0.25, PI - 0.25, 16, color, w)


## Мачта с волнами: узел связи.
static func antenna(canvas: CanvasItem, c: Vector2, r: float, color: Color) -> void:
	var w := maxf(r * 0.18, 1.5)
	canvas.draw_colored_polygon(PackedVector2Array([c + Vector2(-0.45, 1.0) * r, c + Vector2(0, -0.4) * r,
		c + Vector2(0.45, 1.0) * r]), color)
	canvas.draw_circle(c + Vector2(0, -0.45) * r, r * 0.16, color)
	canvas.draw_arc(c + Vector2(0, -0.45) * r, r * 0.5, -PI * 0.85, -PI * 0.15, 10, color, w)
	canvas.draw_arc(c + Vector2(0, -0.45) * r, r * 0.85, -PI * 0.85, -PI * 0.15, 12, color, w)


## Ящик с перекрестьем: арсенал.
static func crate(canvas: CanvasItem, c: Vector2, r: float, color: Color) -> void:
	var w := maxf(r * 0.18, 1.5)
	canvas.draw_rect(Rect2(c - Vector2(0.85, 0.75) * r, Vector2(1.7, 1.5) * r), color)
	canvas.draw_line(c + Vector2(-0.6, -0.5) * r, c + Vector2(0.6, 0.5) * r, _hole(canvas), w)
	canvas.draw_line(c + Vector2(0.6, -0.5) * r, c + Vector2(-0.6, 0.5) * r, _hole(canvas), w)


## Колос: аграрный район.
static func wheat(canvas: CanvasItem, c: Vector2, r: float, color: Color) -> void:
	canvas.draw_line(c + Vector2(0, -0.9) * r, c + Vector2(0, 1.0) * r, color, maxf(r * 0.16, 1.5))
	for k in 3:
		var y := -0.55 + 0.42 * k
		canvas.draw_circle(c + Vector2(-0.3, y) * r, r * 0.22, color)
		canvas.draw_circle(c + Vector2(0.3, y) * r, r * 0.22, color)
	canvas.draw_circle(c + Vector2(0, -0.85) * r, r * 0.2, color)


## Перекрещённые доски: баррикада.
static func barricade(canvas: CanvasItem, c: Vector2, r: float, color: Color) -> void:
	var w := maxf(r * 0.3, 2.0)
	canvas.draw_line(c + Vector2(-0.9, 0.8) * r, c + Vector2(0.9, -0.6) * r, color, w)
	canvas.draw_line(c + Vector2(-0.9, -0.6) * r, c + Vector2(0.9, 0.8) * r, color, w)
	canvas.draw_line(c + Vector2(-1.0, 0.1) * r, c + Vector2(1.0, 0.1) * r, color, w)


## Каска: гарнизон.
static func helmet(canvas: CanvasItem, c: Vector2, r: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in 13:
		var a := PI + PI * float(i) / 12.0
		pts.append(c + Vector2(cos(a) * 0.8, sin(a) * 0.85 + 0.25) * r)
	canvas.draw_colored_polygon(pts, color)
	canvas.draw_rect(Rect2(c + Vector2(-1.0, 0.2) * r, Vector2(2.0, 0.28) * r), color)


## Буханка: снабжение.
static func bread(canvas: CanvasItem, c: Vector2, r: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in 13:
		var a := PI + PI * float(i) / 12.0
		pts.append(c + Vector2(cos(a) * 0.95, sin(a) * 0.7 + 0.15) * r)
	pts.append(c + Vector2(0.95, 0.7) * r)
	pts.append(c + Vector2(-0.95, 0.7) * r)
	canvas.draw_colored_polygon(pts, color)
	for x in [-0.4, 0.0, 0.4]:
		canvas.draw_line(c + Vector2(x - 0.12, -0.25) * r, c + Vector2(x + 0.12, 0.1) * r, _hole(canvas), maxf(r * 0.12, 1.0))


## Винтовка: оружие.
static func rifle(canvas: CanvasItem, c: Vector2, r: float, color: Color) -> void:
	var w := maxf(r * 0.2, 1.5)
	canvas.draw_line(c + Vector2(-0.95, 0.55) * r, c + Vector2(0.95, -0.6) * r, color, w)
	canvas.draw_colored_polygon(PackedVector2Array([c + Vector2(-1.0, 0.45) * r, c + Vector2(-0.45, 0.1) * r,
		c + Vector2(-0.2, 0.5) * r, c + Vector2(-0.75, 0.95) * r]), color)


## Эмблема движения — «призрак» (как на иконке игры): красная фигура с волнистым подолом
## на бумажном круге, перечёркнутом чёрной диагональю.
static func emblem(canvas: CanvasItem, c: Vector2, r: float) -> void:
	canvas.draw_circle(c, r, MapPalette.PAPER)
	# Диагональ — нижняя часть круга чёрная.
	var band := PackedVector2Array()
	for i in 33:
		var a := lerpf(-0.25, PI + 0.55, float(i) / 32.0)
		band.append(c + Vector2(cos(a), sin(a)) * r)
	canvas.draw_colored_polygon(band, MapPalette.INK)
	var body := PackedVector2Array()
	for i in 17:
		var a := PI + PI * float(i) / 16.0
		body.append(c + Vector2(cos(a) * 0.53, sin(a) * 0.62 - 0.08) * r)
	var bottom := 0.62
	var xs := [0.53, 0.35, 0.18, 0.0, -0.18, -0.35, -0.53]
	for k in xs.size():
		body.append(c + Vector2(xs[k], bottom - (0.16 if k % 2 == 1 else 0.0)) * r)
	canvas.draw_colored_polygon(body, MapPalette.VERMILION)
	canvas.draw_circle(c + Vector2(-0.2, -0.22) * r, 0.09 * r, MapPalette.PAPER)
	canvas.draw_circle(c + Vector2(0.2, -0.22) * r, 0.09 * r, MapPalette.PAPER)
	canvas.draw_arc(c, r, 0.0, TAU, 48, MapPalette.INK, maxf(r * 0.05, 2.0), true)


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
