class_name GameData
extends RefCounted
## Все неизменные данные партии: мир, связи между странами, числа баланса,
## улучшения, действия и стратегические линии. Загружаются один раз из папки data/.

const LINKS_PATH := "res://data/links.json"
const BALANCE_PATH := "res://data/balance.json"
const ACTIONS_PATH := "res://data/actions.json"
const LINES_PATH := "res://data/lines.json"
const EVENTS_PATH := "res://data/events.json"
const BATTLE_PATH := "res://data/battle.json"

var world: WorldData
var balance: Dictionary = {}
## id улучшения → описание (data/actions.json, раздел "upgrades").
var upgrades: Dictionary = {}
var upgrade_order: PackedStringArray
## id действия в стране → описание (data/actions.json, раздел "country_actions").
var country_actions: Dictionary = {}
var country_action_order: PackedStringArray
## Ветви дерева развития и группы действий — в порядке показа.
var branches: PackedStringArray
var action_groups: PackedStringArray
## id линии → описание (data/lines.json).
var lines: Dictionary = {}
var line_order: PackedStringArray
## Во сколько раз падает организованность при смене линии.
var line_change_organization_mult := 0.5
## id события → описание (data/events.json).
var events: Dictionary = {}
var event_order: PackedStringArray
## Числа и действия местных сражений (data/battle.json); числа доступны через num("battle.…").
var battle: Dictionary = {}
var battle_actions: Dictionary = {}
var battle_action_order: PackedStringArray

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
	return load_from(WorldData.load_default(), LINKS_PATH, BALANCE_PATH, ACTIONS_PATH, LINES_PATH, EVENTS_PATH)


static func load_from(world: WorldData, links_path: String, balance_path: String, actions_path: String,
		lines_path: String, events_path: String) -> GameData:
	if world == null:
		return null
	var links_doc: Variant = _read_json(links_path)
	var balance_doc: Variant = _read_json(balance_path)
	var actions_doc: Variant = _read_json(actions_path)
	var lines_doc: Variant = _read_json(lines_path)
	var events_doc: Variant = _read_json(events_path)
	var battle_doc: Variant = _read_json(BATTLE_PATH)
	if not (links_doc is Dictionary and balance_doc is Dictionary and actions_doc is Dictionary and lines_doc is Dictionary
			and events_doc is Dictionary and battle_doc is Dictionary):
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
	data.branches = PackedStringArray(actions_doc.get("branches", []))
	data.action_groups = PackedStringArray(actions_doc.get("action_groups", []))
	for item: Dictionary in lines_doc.get("lines", []):
		data.lines[item["id"]] = item
		data.line_order.append(item["id"])
	data.line_change_organization_mult = float(lines_doc.get("change_organization_mult", 0.5))
	for item: Dictionary in events_doc.get("events", []):
		data.events[item["id"]] = item
		data.event_order.append(item["id"])
	data.battle = battle_doc
	data._index_numbers(battle_doc, "battle")
	for item: Dictionary in battle_doc.get("actions", []):
		data.battle_actions[item["id"]] = item
		data.battle_action_order.append(item["id"])
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


## Улучшения одной ветви в порядке показа.
func upgrades_of(branch: String) -> PackedStringArray:
	var out := PackedStringArray()
	for id in upgrade_order:
		if upgrades[id].get("branch", "") == branch:
			out.append(id)
	return out


## Действия одной группы в порядке показа.
func actions_of(group: String) -> PackedStringArray:
	var out := PackedStringArray()
	for id in country_action_order:
		if country_actions[id].get("group", "") == group:
			out.append(id)
	return out


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
