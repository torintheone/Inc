class_name BattleAI
extends RefCounted
## Ход власти в сражении: переброска армии по железной дороге, аресты, арест руководства,
## комендантский час, контрпропаганда, добровольческие отряды имущих, интервенция.


static func act(sim: SimWorld, b: BattleState) -> void:
	var d := sim.data
	var a := "battle.ai."
	var n := b.region_count()
	var cap := b.capital()
	# Прибывают войска, отправленные раньше.
	var i := 0
	while i < b.transfers.size():
		var t: Dictionary = b.transfers[i]
		if int(t["arrive"]) <= b.day:
			b.reinforce(int(t["to"]), float(t["strength"]), float(t.get("loyalty", b.reserve_loyalty)))
			b.transfers.remove_at(i)
		else:
			i += 1
	# Мобилизация пополняет резерв; советы забирают налоги и замедляют её.
	if b.day % int(d.num(a + "reinforce_income_days")) == 0:
		var councils := 0
		for k in n:
			if b.council[k]:
				councils += 1
		b.reserve += maxf(d.num(a + "reinforce_income") - 0.5 * councils, 0.0)
	# Переброска: к самому опасному месту. Без узла связи власть действует медленнее.
	var every := int(d.num(a + "transfer_every_days") * (1.5 if b.seized.has("comms") else 1.0))
	if b.day % maxi(every, 1) == 0:
		_transfer(sim, b, cap)
	# Аресты агитаторов полицией.
	var police_cap := b.police[cap]
	var arrest := d.num(a + "arrest_chance") * police_cap / 20.0 * (0.5 if b.seized.has("comms") else 1.0)
	if sim.upgrades.has("legal_service"):
		arrest *= 0.5
	if b.agitators > 0 and b.rng.randf() < arrest:
		b.agitators -= 1
		b.add_log("BATTLE_LOG_ARRESTS")
	# Арест руководства.
	var lead := d.num(a + "leadership_arrest_chance") * police_cap / 20.0
	if b.seized.has("comms"):
		lead *= d.num(a + "leadership_comms_mult")
	lead *= float(d.battle.get("lines", {}).get(b.line, {}).get("leadership_arrest_mult", 1.0))
	if sim.upgrades.has("conspiracy"):
		lead *= 0.7
	if not b.leadership_arrested and b.rng.randf() < lead:
		BattleSystem.arrest_leadership(sim, b)
	# Комендантский час, когда спорных районов много.
	var contested := 0
	for k in n:
		if b.control[k] != BattleState.POWER:
			contested += 1
	if b.day >= b.curfew_until and contested >= int(d.num(a + "curfew_contested")) and b.curfew_until < 0:
		b.curfew_until = b.day + int(d.num(a + "curfew_days"))
		b.add_log("BATTLE_LOG_CURFEW")
	# Контрпропаганда.
	if b.day % int(d.num(a + "propaganda_every_days")) == 0:
		for k in n:
			if b.control[k] == BattleState.POWER:
				b.support[k] = maxf(b.support[k] - d.num(a + "propaganda_support"), 0.0)
		if b.trust > 50.0:
			b.trust -= d.num(a + "propaganda_trust")
		b.add_log("BATTLE_LOG_PROPAGANDA")
	# Добровольческие отряды имущих классов — в столице и аграрных районах.
	var days: Array = d.battle["ai"].get("volunteers_days", [])
	for vd in days:
		if b.day == int(vd) and not b.volunteers_done.has(int(vd)):
			b.volunteers_done[int(vd)] = true
			var strength := d.num(a + "volunteers_strength")
			b.reinforce(cap, strength, 100.0)
			for k in n:
				if b.has_object(k, "agrarian") and b.control[k] != BattleState.REVOLUTION:
					b.reinforce(k, strength * 0.3, 100.0)
			b.add_log("BATTLE_LOG_VOLUNTEERS")
	# Интервенция при сильной Реакции, если порт не в руках революции.
	if not b.intervention_done and sim.reaction >= d.num(a + "intervention_reaction") and b.day >= int(d.num(a + "intervention_day")):
		b.intervention_done = true
		if not b.seized.has("port"):
			var target := cap
			for k in n:
				if b.has_object(k, "port"):
					target = k
					break
			b.reinforce(target, d.num(a + "intervention_strength"), 100.0)
			b.add_log("BATTLE_LOG_INTERVENTION", [b.region(target)["name_ru"]])
		else:
			b.add_log("BATTLE_LOG_INTERVENTION_BLOCKED")


## Отправить часть резерва (или сильнейшего спокойного гарнизона) туда, где революция сильнее всего.
static func _transfer(sim: SimWorld, b: BattleState, cap: int) -> void:
	var d := sim.data
	var n := b.region_count()
	var target := -1
	var best := 0.0
	for k in n:
		var threat := b.squads[k] + (12.0 * b.support[k] / 100.0 if b.support[k] >= 50.0 else 0.0)
		# Контрудар по освобождённым заводам и столице.
		if b.control[k] == BattleState.REVOLUTION and (k == cap or b.has_object(k, "factories")):
			threat += d.num("battle.ai.counterattack_threat")
		if threat <= 0.0:
			continue
		if k == cap:
			threat *= 2.0
		elif b.has_object(k, "factories"):
			threat *= 1.3
		if b.council[k]:
			threat *= 1.3
		if threat > best:
			best = threat
			target = k
	if target < 0:
		return
	var source := cap
	var strength := 0.0
	var loyalty := b.reserve_loyalty
	if b.reserve > 1.0:
		strength = b.reserve * d.num("battle.ai.transfer_share")
		b.reserve -= strength
	else:
		var richest := -1
		for k in n:
			if k != target and b.control[k] == BattleState.POWER and not b.neutral[k] and b.gov[k] > 8.0 \
					and (richest < 0 or b.gov[k] > b.gov[richest]):
				richest = k
		if richest < 0:
			return
		source = richest
		loyalty = b.loyalty[richest]
		strength = b.gov[richest] * d.num("battle.ai.transfer_share")
		b.gov[richest] -= strength
	var steps := _distance(b, source, target)
	var travel := steps * d.num("battle.ai.travel_days_per_step") * (d.num("battle.ai.railway_cut_mult") if b.seized.has("railway") else 1.0)
	b.transfers.append({"from": source, "to": target, "strength": strength, "loyalty": loyalty, "sent": b.day,
		"arrive": b.day + maxi(int(ceilf(travel)), 1)})
	b.add_log("BATTLE_LOG_TRANSFER", [b.region(target)["name_ru"]])


## Сколько переходов между регионами (поиск в ширину по соседям).
static func _distance(b: BattleState, from: int, to: int) -> int:
	if from == to:
		return 0
	var seen := {from: 0}
	var queue := [from]
	while not queue.is_empty():
		var cur: int = queue.pop_front()
		for nb in b.region(cur)["neighbors"]:
			if not seen.has(nb):
				seen[nb] = int(seen[cur]) + 1
				if nb == to:
					return int(seen[nb])
				queue.append(nb)
	return 3
