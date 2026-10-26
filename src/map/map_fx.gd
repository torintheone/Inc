class_name MapFx
extends Node2D
## Анимации на карте мира: вспышки стран при событиях (расходящиеся кольца) и линии распространения
## движения — дуга от страны к стране, по которой плывёт корабль, идёт поезд или бегут радиоволны.
## Размеры заданы в пикселях экрана и не зависят от масштаба карты.

const PULSE_SECONDS := 1.6
const SPREAD_SECONDS := 2.8
const ICON_PX := 9.0

## Масштаб камеры.
var zoom := 1.0

## {"pos", "color", "size", "t"}
var _pulses: Array[Dictionary] = []
## {"from", "to", "kind", "t"}
var _spreads: Array[Dictionary] = []


## Вспышка в точке карты. size 1 — обычная, 2 — крупное событие.
func pulse(at: Vector2, color: Color, size: float = 1.0) -> void:
	_pulses.append({"pos": at, "color": color, "size": size, "t": 0.0})
	set_process(true)


## Движение пришло из одной страны в другую: kind — "ship", "train" или "radio".
func spread(from: Vector2, to: Vector2, kind: String) -> void:
	_spreads.append({"from": from, "to": to, "kind": kind, "t": 0.0})
	set_process(true)


func clear() -> void:
	_pulses.clear()
	_spreads.clear()
	queue_redraw()


func busy() -> bool:
	return not _pulses.is_empty() or not _spreads.is_empty()


func _process(delta: float) -> void:
	if not busy():
		set_process(false)
		queue_redraw()
		return
	_advance(_pulses, delta / PULSE_SECONDS)
	_advance(_spreads, delta / SPREAD_SECONDS)
	queue_redraw()


static func _advance(items: Array[Dictionary], dt: float) -> void:
	var i := 0
	while i < items.size():
		items[i]["t"] = float(items[i]["t"]) + dt
		if float(items[i]["t"]) >= 1.0:
			items.remove_at(i)
		else:
			i += 1


func _draw() -> void:
	var k := 1.0 / zoom
	for p: Dictionary in _pulses:
		var t: float = p["t"]
		var size: float = p["size"]
		var color: Color = p["color"]
		for ring in 2:
			var tt := clampf(t * 1.25 - ring * 0.25, 0.0, 1.0)
			if tt <= 0.0:
				continue
			var r := (10.0 + 46.0 * size * ease(tt, 0.4)) * k
			draw_arc(p["pos"], r, 0.0, TAU, 48, Color(color, (1.0 - tt) * 0.9), (3.0 + size) * (1.0 - tt) * k + k, true)
		draw_circle(p["pos"], 6.0 * size * k * (1.0 - t), Color(color, 0.6 * (1.0 - t)))
	for s: Dictionary in _spreads:
		_draw_spread(s, k)


func _draw_spread(s: Dictionary, k: float) -> void:
	var t: float = s["t"]
	var a: Vector2 = s["from"]
	var b: Vector2 = s["to"]
	# Дуга: середина приподнята над прямой, тем выше, чем дальше страны.
	var mid := (a + b) * 0.5 + (b - a).orthogonal().normalized() * minf(a.distance_to(b) * 0.25, 260.0)
	var fade := clampf((1.0 - t) * 4.0, 0.0, 1.0)
	var head := minf(t * 1.3, 1.0)
	var pts := PackedVector2Array()
	var steps := 32
	for i in steps + 1:
		var u := head * float(i) / steps
		pts.append(_bezier(a, mid, b, u))
	if pts.size() >= 2:
		draw_polyline(pts, Color(MapPalette.VERMILION, 0.7 * fade), 2.5 * k, true)
	var pos := _bezier(a, mid, b, head)
	var dir := (_bezier(a, mid, b, minf(head + 0.02, 1.0)) - _bezier(a, mid, b, maxf(head - 0.02, 0.0))).normalized()
	var color := Color(MapPalette.INK, fade)
	match s["kind"]:
		"ship":
			_ship(pos, dir, ICON_PX * k, color)
		"train":
			_train(pos, dir, ICON_PX * k, color)
		_:
			_radio(pos, t, ICON_PX * k, Color(MapPalette.VERMILION, fade))
	if head >= 1.0:
		var land := clampf((t - 0.77) / 0.23, 0.0, 1.0)
		draw_arc(b, (8.0 + 30.0 * land) * k, 0.0, TAU, 32, Color(MapPalette.VERMILION, 1.0 - land), 3.0 * k, true)


static func _bezier(a: Vector2, c: Vector2, b: Vector2, u: float) -> Vector2:
	return a.lerp(c, u).lerp(c.lerp(b, u), u)


## Кораблик: корпус и труба с дымом, нос по направлению движения.
func _ship(at: Vector2, dir: Vector2, r: float, color: Color) -> void:
	var side := 1.0 if dir.x >= 0.0 else -1.0
	var hull := PackedVector2Array([at + Vector2(-1.1 * side, -0.1) * r, at + Vector2(1.3 * side, -0.1) * r,
		at + Vector2(0.8 * side, 0.6) * r, at + Vector2(-0.8 * side, 0.6) * r])
	draw_circle(at, r * 1.7, Color(MapPalette.PAPER, color.a * 0.85))
	draw_colored_polygon(hull, color)
	draw_rect(Rect2(at + Vector2(-0.2, -0.9) * r, Vector2(0.45, 0.8) * r), color)
	draw_circle(at + Vector2(-0.45 * side, -1.25) * r, 0.3 * r, Color(color, color.a * 0.5))


## Паровоз: будка, котёл и колёса.
func _train(at: Vector2, dir: Vector2, r: float, color: Color) -> void:
	var side := 1.0 if dir.x >= 0.0 else -1.0
	draw_circle(at, r * 1.7, Color(MapPalette.PAPER, color.a * 0.85))
	draw_rect(Rect2(at + Vector2(-1.1 if side > 0 else 0.3, -0.9) * r, Vector2(0.8, 1.1) * r), color)
	draw_rect(Rect2(at + Vector2(-0.4 if side > 0 else -1.2, -0.5) * r, Vector2(1.6, 0.7) * r), color)
	for x in [-0.7, 0.0, 0.7]:
		draw_circle(at + Vector2(x, 0.5) * r, 0.32 * r, color)


## Радиоволны: мачта и расходящиеся дуги.
func _radio(at: Vector2, t: float, r: float, color: Color) -> void:
	draw_circle(at, r * 0.35, color)
	for i in 3:
		var phase := fmod(t * 3.0 + i / 3.0, 1.0)
		draw_arc(at, r * (0.6 + 1.6 * phase), -PI * 0.8, -PI * 0.2, 12, Color(color, color.a * (1.0 - phase)), 0.25 * r, true)
		draw_arc(at, r * (0.6 + 1.6 * phase), PI * 0.2, PI * 0.8, 12, Color(color, color.a * (1.0 - phase)), 0.25 * r, true)
