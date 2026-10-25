class_name Country
extends RefCounted
## Страна мира: названия, показатели из data/world.json и полигоны карты.
## Данные без узлов сцены — их использует и симуляция, и отображение.

var id: String
## Номер страны в мире; по нему карта красит страну.
var index: int
var name_ru: String
var name_en: String
var continent: String
var subregion: String
## Субрегион по-русски, для интерфейса.
var subregion_ru: String
## Зона мир-системы: "core", "semi" или "periphery".
var zone: String
## Точка для подписи на карте.
var label: Vector2
var neighbors: PackedStringArray
## Показатели Всемирного банка (см. data/README.md).
var indicators: Dictionary[String, float] = {}
## Год, к которому относится каждый показатель.
var years: Dictionary[String, int] = {}
## Показатели, которых нет у Всемирного банка: они оценены по группе дохода.
var estimated: PackedStringArray
var shapes: Array[CountryShape] = []
var bbox: Rect2


static func from_dict(data: Dictionary, index: int) -> Country:
	var c := Country.new()
	c.id = data["id"]
	c.index = index
	c.name_ru = data.get("name_ru", c.id)
	c.name_en = data.get("name_en", c.id)
	c.continent = data.get("continent", "")
	c.subregion = data.get("subregion", "")
	c.subregion_ru = data.get("subregion_ru", c.subregion)
	c.zone = data.get("zone", "periphery")
	var lbl: Array = data.get("label", [0.0, 0.0])
	c.label = Vector2(lbl[0], lbl[1])
	c.neighbors = PackedStringArray(data.get("neighbors", []))
	var ind: Dictionary = data.get("indicators", {})
	for key: String in ind:
		c.indicators[key] = float(ind[key])
	var yrs: Dictionary = data.get("years", {})
	for key: String in yrs:
		c.years[key] = int(yrs[key])
	c.estimated = PackedStringArray(data.get("estimated", []))
	return c


func set_shapes(list: Array) -> void:
	shapes.clear()
	for item: Dictionary in list:
		shapes.append(CountryShape.from_dict(item))
	if shapes.is_empty():
		bbox = Rect2(label, Vector2.ZERO)
		return
	bbox = shapes[0].bbox
	for s in shapes:
		bbox = bbox.merge(s.bbox)


func indicator(key: String, default: float = 0.0) -> float:
	return indicators.get(key, default)


func is_estimated(key: String) -> bool:
	return estimated.has(key)


func contains(point: Vector2) -> bool:
	if not bbox.has_point(point):
		return false
	for s in shapes:
		if s.contains(point):
			return true
	return false


func distance_to(point: Vector2) -> float:
	var best := INF
	for s in shapes:
		best = minf(best, s.distance_to(point))
	return best
