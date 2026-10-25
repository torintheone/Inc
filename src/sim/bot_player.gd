class_name BotPlayer
extends RefCounted
## Простой бот-игрок для прогонов и тестов: покупает самое дешёвое доступное
## улучшение, проводит стачки и демонстрации там, где движение сильнее всего,
## и поднимает восстание, как только оно доступно.

const ACTION_PRIORITY: PackedStringArray = ["uprising", "industry_strike", "factory_strike", "demonstration"]
## Сколько стран с самым сильным влиянием бот обходит каждую неделю.
const TOP_COUNTRIES := 6


static func play_week(sim: SimWorld) -> void:
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


static func _buy_upgrade(sim: SimWorld) -> void:
	var best := ""
	var best_cost := INF
	for id in sim.data.upgrade_order:
		if not PlayerActions.upgrade_blockers(sim, id).is_empty():
			continue
		var cost := float(sim.data.upgrades[id].get("cost", 0))
		if cost < best_cost:
			best_cost = cost
			best = id
	if best != "":
		PlayerActions.buy_upgrade(sim, best)
