class_name GameData
extends RefCounted
## Все неизменные данные партии: мир, связи между странами, числа баланса,
## улучшения и действия. Загружаются один раз из папки data/.

const LINKS_PATH := "res://data/links.json"
const BALANCE_PATH := "res://data/balance.json"
const ACTIONS_PATH := "res://data/actions.json"

var world: WorldData
var balance: Dictionary = {}
## id улучшения → описание (data/actions.json, раздел "upgrades").
var upgrades: Dictionary = {}
var upgrade_order: PackedStringArray
## id действия в стране → описание (data/actions.json, раздел "country_actions").
var country_actions: Dictionary = {}
var country_action_order: PackedStringArray

## Связи как параллельные массивы: так недельный шаг идёт быстрее.
var link_a: PackedInt32Array
var link_b: PackedInt32Array
var link_trade: PackedFloat32Array
var link_migration: PackedFloat32Array
var link_neighbor: PackedByteArray

## Доля страны в мировом ВВП и населении (0–1), по номеру страны.
var gdp_share: PackedFloat64Array
var population_share: PackedFloat64Array


static func load_default() -> GameData:
	return load_from(WorldData.load_default(), LINKS_PATH, BALANCE_PATH, ACTIONS_PATH)


static func load_from(world: WorldData, links_path: String, balance_path: String, actions_path: String) -> GameData:
	if world == null:
		return null
	var links_doc: Variant = _read_json(links_path)
	var balance_doc: Variant = _read_json(balance_path)
	var actions_doc: Variant = _read_json(actions_path)
	if not (links_doc is Dictionary and balance_doc is Dictionary and actions_doc is Dictionary):
		return null
	var data := GameData.new()
	data.world = world
	data.balance = balance_doc
	data._index_numbers(balance_doc, "")
	for item: Dictionary in actions_doc.get("upgrades", []):
		data.upgrades[item["id"]] = item
		data.upgrade_order.append(item["id"])
	for item: Dictionary in actions_doc.get("country_actions", []):
		data.country_actions[item["id"]] = item
		data.country_action_order.append(item["id"])
	for link: Dictionary in links_doc.get("links", []):
		var a := world.get_country(link["a"])
		var b := world.get_country(link["b"])
		if a == null or b == null:
			continue
		data.link_a.append(a.index)
		data.link_b.append(b.index)
		data.link_trade.append(float(link.get("trade", 0.0)))
		data.link_migration.append(float(link.get("migration", 0.0)))
		data.link_neighbor.append(1 if link.get("neighbor", false) else 0)
	var total_gdp := 0.0
	var total_pop := 0.0
	for c in world.countries:
		total_gdp += c.indicator("gdp_usd")
		total_pop += c.indicator("population")
	data.gdp_share.resize(world.countries.size())
	data.population_share.resize(world.countries.size())
	for c in world.countries:
		data.gdp_share[c.index] = c.indicator("gdp_usd") / maxf(total_gdp, 1.0)
		data.population_share[c.index] = c.indicator("population") / maxf(total_pop, 1.0)
	return data


## Все числа баланса по полному пути ("economy.need_wage" → 0.55): один поиск вместо обхода разделов.
var _numbers: Dictionary[String, float] = {}
## Разделы баланса по пути ("zones.core" → словарь), чтобы не обходить их каждую неделю.
var _sections: Dictionary[String, Variant] = {}


## Число баланса по пути вида "movement.growth".
func num(path: String, default: float = 0.0) -> float:
	return _numbers.get(path, default)


## Раздел баланса по пути вида "cycle.phases".
func section(path: String) -> Variant:
	if _sections.has(path):
		return _sections[path]
	var node: Variant = balance
	for part in path.split("."):
		if not (node is Dictionary) or not node.has(part):
			return null
		node = node[part]
	_sections[path] = node
	return node


func _index_numbers(node: Variant, prefix: String) -> void:
	if node is Dictionary:
		for key: String in node:
			_index_numbers(node[key], key if prefix == "" else prefix + "." + key)
	elif node is float or node is int:
		_numbers[prefix] = float(node)


static func _read_json(path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Не удалось открыть %s" % path)
		return null
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed == null:
		push_error("Ошибка разбора JSON в %s" % path)
	return parsed
