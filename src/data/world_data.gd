class_name WorldData
extends RefCounted
## Мир целиком: страны и нейтральная суша. Загружается из data/world.json
## и data/world_shapes.json, которые собирает tools/build_world.py.

const WORLD_PATH := "res://data/world.json"
const SHAPES_PATH := "res://data/world_shapes.json"

var countries: Array[Country] = []
var by_id: Dictionary[String, Country] = {}
## Территории вне партии (слишком малое население): рисуются серым, их нельзя выбрать.
var neutral_shapes: Array[CountryShape] = []
var neutral_names: PackedStringArray
var bounds: Rect2
var sources: Dictionary = {}
var zone_names: Dictionary = {}


static func load_default() -> WorldData:
	return load_from(WORLD_PATH, SHAPES_PATH)


static func load_from(world_path: String, shapes_path: String) -> WorldData:
	var world_doc: Variant = _read_json(world_path)
	var shapes_doc: Variant = _read_json(shapes_path)
	if not (world_doc is Dictionary and shapes_doc is Dictionary):
		return null
	var world := WorldData.new()
	world.sources = world_doc.get("sources", {})
	world.zone_names = world_doc.get("zones", {})
	var shape_map: Dictionary = shapes_doc.get("countries", {})
	for item: Dictionary in world_doc.get("countries", []):
		var c := Country.from_dict(item, world.countries.size())
		c.set_shapes(shape_map.get(c.id, []))
		world.countries.append(c)
		world.by_id[c.id] = c
	for item: Dictionary in shapes_doc.get("neutral", []):
		world.neutral_names.append(item.get("name_ru", ""))
		for poly: Dictionary in item.get("polygons", []):
			world.neutral_shapes.append(CountryShape.from_dict(poly))
	var b: Array = shapes_doc.get("bounds", [0, 0, 0, 0])
	world.bounds = Rect2(Vector2(b[0], b[1]), Vector2(b[2] - b[0], b[3] - b[1]))
	return world


func get_country(id: String) -> Country:
	return by_id.get(id)


## Страна под точкой карты. Если точка в море, берётся ближайшая страна
## не дальше tolerance (так проще попасть по маленьким островам).
func country_at(point: Vector2, tolerance: float = 0.0) -> Country:
	var nearest: Country = null
	var nearest_dist := tolerance
	for c in countries:
		if not c.bbox.grow(tolerance).has_point(point):
			continue
		if c.contains(point):
			return c
		if tolerance > 0.0:
			var d := c.distance_to(point)
			if d <= nearest_dist:
				nearest_dist = d
				nearest = c
	return nearest


func zone_name(zone: String) -> String:
	return zone_names.get(zone, zone)


static func _read_json(path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Не удалось открыть %s: %s" % [path, error_string(FileAccess.get_open_error())])
		return null
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed == null:
		push_error("Ошибка разбора JSON в %s" % path)
	return parsed
