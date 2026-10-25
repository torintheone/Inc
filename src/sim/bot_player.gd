class_name BotPlayer
extends RefCounted
## Простой бот-игрок для прогонов и тестов: собирает пузырьки, покупает улучшения по
## списку приоритетов, посылает организаторов в соседние страны, проводит стачки и
## демонстрации там, где движение сильнее всего, и поднимает восстание, как только оно доступно.

const ACTION_PRIORITY: PackedStringArray = ["uprising", "general_strike", "industry_strike", "elections",
	"factory_strike", "army_work", "unemployed_agitation", "demonstration", "shorter_workday", "cooperatives"]
## Улучшения, которые бот берёт в первую очередь; остальные — самые дешёвые из доступных.
const UPGRADE_PRIORITY: PackedStringArray = ["leaflets", "study_circles", "trade_unions", "emigrant_links",
	"workers_newspaper", "workers_party", "industry_federations", "strike_fund", "cadre_school",
	"self_defense", "occupation_tactic", "general_strike_prep", "workers_councils"]
## Сколько стран с самым сильным влиянием бот обходит каждую неделю.
const TOP_COUNTRIES := 6
## Сколько солидарности бот оставляет сверх цены следующего улучшения, прежде чем посылать организаторов.
const ORGANIZERS_RESERVE := 6.0


static func play_week(sim: SimWorld) -> void:
	_collect_bubbles(sim)
	_buy_upgrade(sim)
	var ranked := sim.countries.filter(func(cs: CountryState) -> bool: return not cs.is_revolutionary() and cs.influence >= 1.0)
	ranked.sort_custom(func(a: CountryState, b: CountryState) -> bool:
		return a.rev_situation + a.influence > b.rev_situation + b.influence)
	for cs: CountryState in ranked.slice(0, TOP_COUNTRIES):
		for id in ACTION_PRIORITY:
			if PlayerActions.action_blockers(sim, id, cs).is_empty():
				# Стачки и демонстрации — только при хорошем шансе, восстание — всегда.
				if id == "uprising" or PlayerActions.action_chance(sim, id, cs) >= 0.5:
					PlayerActions.perform(sim, id, cs)
					break
	_send_organizers(sim, ranked)


static func _collect_bubbles(sim: SimWorld) -> void:
	var ids := []
	for b in sim.bubbles:
		ids.append(int(b["id"]))
	for id: int in ids:
		sim.collect_bubble(id)


static func _buy_upgrade(sim: SimWorld) -> void:
	var id := _wanted_upgrade(sim)
	if id != "" and PlayerActions.upgrade_blockers(sim, id).is_empty():
		PlayerActions.buy_upgrade(sim, id)


## Улучшение, на которое бот копит: первое открытое из списка приоритетов, иначе самое дешёвое открытое.
static func _wanted_upgrade(sim: SimWorld) -> String:
	for id in UPGRADE_PRIORITY:
		if sim.data.upgrades.has(id) and _requirements_met(sim, id):
			return id
	var best := ""
	var best_cost := INF
	for id in sim.data.upgrade_order:
		if not _requirements_met(sim, id):
			continue
		var cost := float(sim.data.upgrades[id].get("cost", 0))
		if cost < best_cost:
			best_cost = cost
			best = id
	return best


static func _requirements_met(sim: SimWorld, id: String) -> bool:
	if sim.upgrades.has(id):
		return false
	for req in PlayerActions.upgrade_requires(sim, id):
		if not sim.upgrades.has(req):
			return false
	return true


## Организаторы — туда, где движение уже есть, но кадров мало.
static func _send_organizers(sim: SimWorld, ranked: Array) -> void:
	if sim.solidarity < _next_upgrade_cost(sim) + ORGANIZERS_RESERVE:
		return
	for cs: CountryState in ranked:
		if cs.cadres < 3.0 and PlayerActions.action_blockers(sim, "send_organizers", cs).is_empty():
			PlayerActions.perform(sim, "send_organizers", cs)
			return


## Цена улучшения, на которое бот копит (0 — всё куплено).
static func _next_upgrade_cost(sim: SimWorld) -> float:
	var id := _wanted_upgrade(sim)
	return float(sim.data.upgrades[id].get("cost", 0)) if id != "" else 0.0
