class_name BubbleLayer
extends Node2D
## Пузырьки на карте: красные — солидарность, охристые — стихийный протест.
## Размер на экране постоянный при любом масштабе карты; пузырёк выскакивает,
## покачивается, а дуга вокруг показывает, сколько ему осталось.

const RADIUS_PX := 22.0
const HIT_PX := 34.0
const POP_SEC := 0.25
const FLOAT_SEC := 1.2

var world: WorldData
## Масштаб камеры: радиусы задаются в пикселях экрана.
var zoom := 1.0

var _bubbles: Array[Dictionary] = []
var _week := 0
var _born_at: Dictionary[int, float] = {}
var _time := 0.0
## Всплывающие «+3» после касания: {"pos", "text", "t"}.
var _floats: Array[Dictionary] = []


func show_bubbles(sim: SimWorld) -> void:
	_bubbles = sim.bubbles.duplicate()
	_week = sim.week
	var alive := {}
	for b in _bubbles:
		var id := int(b["id"])
		alive[id] = true
		if not _born_at.has(id):
			_born_at[id] = _time
	for id: int in _born_at.keys():
		if not alive.has(id):
			_born_at.erase(id)
	queue_redraw()


func clear() -> void:
	_bubbles.clear()
	_born_at.clear()
	_floats.clear()
	queue_redraw()


## Центр пузырька в координатах карты.
func position_of(b: Dictionary) -> Vector2:
	var c := world.get_country(b["country"])
	var base := c.label if c != null else Vector2.ZERO
	var id := int(b["id"])
	var offset := Vector2(0.0, -14.0) if b["kind"] == UnrestSystem.PROTEST else Vector2(18.0, 6.0)
	offset += Vector2(cos(id * 2.39996), sin(id * 2.39996)) * 6.0
	return base + offset / zoom


## Пузырёк под точкой касания (id) или −1.
func bubble_at(world_pos: Vector2) -> int:
	var best := -1
	var best_d := HIT_PX / zoom
	for b in _bubbles:
		var d := world_pos.distance_to(position_of(b))
		if d <= best_d:
			best_d = d
			best = int(b["id"])
	return best


## Всплывающая надпись над собранным пузырьком.
func pop(id: int, text: String) -> void:
	for b in _bubbles:
		if int(b["id"]) == id:
			_floats.append({"pos": position_of(b), "text": text, "t": 0.0})
			break


func _process(delta: float) -> void:
	_time += delta
	for f in _floats:
		f["t"] = float(f["t"]) + delta
	_floats = _floats.filter(func(f: Dictionary) -> bool: return float(f["t"]) < FLOAT_SEC)
	if not _bubbles.is_empty() or not _floats.is_empty():
		queue_redraw()


func _draw() -> void:
	var k := 1.0 / zoom
	for b in _bubbles:
		var id := int(b["id"])
		var age := _time - float(_born_at.get(id, _time))
		var appear := clampf(age / POP_SEC, 0.0, 1.0)
		var scale := 1.0 + 0.25 * sin(appear * PI) if appear < 1.0 else 1.0
		scale *= appear
		var bob := sin(_time * 2.2 + id) * 2.0 * k
		var left := float(int(b["expires"]) - _week)
		var total := maxf(float(int(b["expires"]) - int(b["born"])), 1.0)
		var p := position_of(b) + Vector2(0, bob)
		draw_bubble(self, b["kind"], p, RADIUS_PX * k * scale, clampf(left / total, 0.0, 1.0), k)
	var font := GameTheme.BODY_BOLD_FONT
	for f in _floats:
		var t := float(f["t"]) / FLOAT_SEC
		var pos: Vector2 = f["pos"] + Vector2(-30.0, -30.0 - 40.0 * t) * k
		var col := Color(MapPalette.INK, 1.0 - t)
		draw_set_transform(pos, 0.0, Vector2(k, k))
		draw_string_outline(font, Vector2.ZERO, f["text"], HORIZONTAL_ALIGNMENT_CENTER, 60, 22, 6, Color(MapPalette.PAPER, 1.0 - t))
		draw_string(font, Vector2.ZERO, f["text"], HORIZONTAL_ALIGNMENT_CENTER, 60, 22, col)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Один пузырёк: тень, круг, светлое кольцо, значок и дуга оставшегося времени.
## k — сколько единиц холста в пикселе экрана (для толщины линий).
static func draw_bubble(canvas: CanvasItem, kind: String, p: Vector2, r: float, life: float, k: float = 1.0) -> void:
	if r <= 0.0:
		return
	var fill := MapPalette.OCHRE if kind == UnrestSystem.PROTEST else MapPalette.VERMILION
	canvas.draw_circle(p + Vector2(2.0, 3.0) * k, r, Color(MapPalette.INK, 0.25))
	canvas.draw_circle(p, r, MapPalette.PAPER)
	canvas.draw_circle(p, r - 2.5 * k, fill)
	canvas.set_meta("icon_hole", fill)
	if kind == UnrestSystem.PROTEST:
		Icons.flag(canvas, p, r * 0.5, MapPalette.INK)
	else:
		Icons.coin(canvas, p, r * 0.45, MapPalette.PAPER)
	canvas.set_meta("icon_hole", MapPalette.PAPER)
	if life < 1.0:
		canvas.draw_arc(p, r + 3.5 * k, -PI / 2.0, -PI / 2.0 + TAU * life, 32, Color(MapPalette.INK, 0.7), 2.0 * k, true)
