class_name CountryShape
extends RefCounted
## Один полигон страны (материк или остров) в координатах карты.

## Все кольца подряд: сначала внешний контур, затем дыры.
var points: PackedVector2Array
## Индексы вершин треугольников заливки (по три на треугольник).
var triangles: PackedInt32Array
var outer: PackedVector2Array
var holes: Array[PackedVector2Array] = []
var bbox: Rect2


static func from_dict(data: Dictionary) -> CountryShape:
	var shape := CountryShape.new()
	var rings: Array = data.get("rings", [])
	for i in rings.size():
		var ring := _ring_from_flat(rings[i])
		shape.points.append_array(ring)
		if i == 0:
			shape.outer = ring
		else:
			shape.holes.append(ring)
	shape.triangles = PackedInt32Array(data.get("tris", []))
	shape.bbox = _bbox_of(shape.outer)
	return shape


func contains(point: Vector2) -> bool:
	if not bbox.has_point(point):
		return false
	if not Geometry2D.is_point_in_polygon(point, outer):
		return false
	for hole in holes:
		if Geometry2D.is_point_in_polygon(point, hole):
			return false
	return true


## Расстояние от точки до ближайшего края полигона (0, если точка внутри).
func distance_to(point: Vector2) -> float:
	if contains(point):
		return 0.0
	var best := INF
	var n := outer.size()
	for i in n:
		var a := outer[i]
		var b := outer[(i + 1) % n]
		best = minf(best, point.distance_to(Geometry2D.get_closest_point_to_segment(point, a, b)))
	return best


static func _ring_from_flat(flat: Array) -> PackedVector2Array:
	var ring := PackedVector2Array()
	ring.resize(flat.size() / 2)
	for i in ring.size():
		ring[i] = Vector2(flat[i * 2], flat[i * 2 + 1])
	return ring


static func _bbox_of(ring: PackedVector2Array) -> Rect2:
	if ring.is_empty():
		return Rect2()
	var rect := Rect2(ring[0], Vector2.ZERO)
	for p in ring:
		rect = rect.expand(p)
	return rect
