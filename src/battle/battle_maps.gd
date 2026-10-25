class_name BattleMaps
extends RefCounted
## Карты стран для сражений (data/battle_maps.json): регионы, их соседи, население и
## ключевые объекты. Файл большой, поэтому читается один раз — при первом сражении.

const PATH := "res://data/battle_maps.json"

static var _doc: Dictionary = {}


static func country(id: String) -> Dictionary:
	if _doc.is_empty():
		var file := FileAccess.open(PATH, FileAccess.READ)
		if file == null:
			push_error("Не удалось открыть %s" % PATH)
			return {}
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		if parsed is Dictionary:
			_doc = parsed
	var c: Dictionary = _doc.get("countries", {}).get(id, {})
	# JSON отдаёт числа дробными; номера соседей переводим в целые один раз.
	if not c.is_empty() and not c.has("_ready"):
		for r: Dictionary in c["regions"]:
			r["neighbors"] = PackedInt32Array(r["neighbors"])
		c["_ready"] = true
	return c


static func has_country(id: String) -> bool:
	return not country(id).is_empty()
