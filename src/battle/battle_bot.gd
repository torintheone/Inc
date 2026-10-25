class_name BattleBot
extends RefCounted
## Бот для сражений: решает за игрока в безголовых прогонах, тестах и гражданской войне.
## Две стратегии: «штурм» — собрать отряды и брать слабые районы, заводы и столицу; «армия» —
## поднимать поддержку и агитировать гарнизоны, пока армия не перейдёт на сторону революции.

const STORM := "storm"
const ARMY := "army"
## Ничего не делать — для проверки, что без игрока восстание не побеждает.
const IDLE := "idle"
## Раунд гражданской войны без игрока: штурм, но солидарность мира не тратится.
const AUTO := "auto"
## Сколько агитаторов бот держит про запас для гарнизонов.
const ARMY_RESERVE := 2


## Довести сражение до итога (или до дня limit_day, если он задан).
static func run(sim: SimWorld, b: BattleState, strategy: String = STORM, limit_day: int = -1) -> void:
	while not b.is_over() and (limit_day < 0 or b.day < limit_day):
		play_day(sim, b, strategy)
		BattleSystem.step_day(sim, b)


static func play_day(sim: SimWorld, b: BattleState, strategy: String) -> void:
	if strategy == IDLE:
		return
	var n := b.region_count()
	var cap := b.capital()
	if b.supplies < 15.0 and strategy != AUTO:
		BattleSystem.perform(sim, b, "solidarity_aid", -1)
	if not b.land_reform:
		for i in n:
			if b.has_object(i, "agrarian"):
				BattleSystem.perform(sim, b, "land_to_peasants", -1)
				break
	for i in n:
		BattleSystem.perform(sim, b, "council", i)
	if strategy == ARMY:
		_army(sim, b, cap)
	else:
		_storm(sim, b, cap)
	for object in ["comms", "arsenal", "railway", "port"]:
		for i in n:
			if b.has_object(i, object) and b.squads[i] >= 3.0:
				BattleSystem.perform(sim, b, "seize_" + object, i)


static func _storm(sim: SimWorld, b: BattleState, cap: int) -> void:
	_gather(b)
	var target := _target(b, cap)
	BattleSystem.perform(sim, b, "strike", target)
	BattleSystem.perform(sim, b, "strike", cap)
	BattleSystem.perform(sim, b, "garrison_agitation", target)
	for i in _by_importance(b, cap):
		if b.agitators <= 1:
			break
		BattleSystem.perform(sim, b, "agitation", i)
	if b.squads_pool >= 1.0:
		BattleSystem.deploy(b, target, b.squads_pool)
	if b.supplies >= 20.0:
		BattleSystem.perform(sim, b, "barricades", target)


static func _army(sim: SimWorld, b: BattleState, cap: int) -> void:
	var garrisons := _by_garrison(b)
	if b.agitators >= 4 and not garrisons.is_empty():
		BattleSystem.perform(sim, b, "officers_talks", garrisons[0])
	for k in mini(garrisons.size(), 4):
		if b.agitators <= 0:
			break
		BattleSystem.perform(sim, b, "garrison_agitation", garrisons[k])
	for k in mini(garrisons.size(), 3):
		if k < 2 and b.supplies >= 25.0:
			BattleSystem.perform(sim, b, "strike", garrisons[k])
		if b.agitators > ARMY_RESERVE:
			BattleSystem.perform(sim, b, "agitation", garrisons[k])
	# Отряды берут районы, где гарнизон перешёл к революции или ослаб.
	_gather(b)
	var weakest := -1
	for i in b.region_count():
		if b.control[i] != BattleState.REVOLUTION and (weakest < 0 or b.gov[i] + b.police[i] < b.gov[weakest] + b.police[weakest]):
			weakest = i
	if weakest >= 0 and b.squads_pool >= 1.0:
		BattleSystem.deploy(b, weakest, b.squads_pool)


## Отвести отряды из освобождённых районов в резерв, оставив по одному для охраны.
static func _gather(b: BattleState) -> void:
	for i in b.region_count():
		if b.control[i] == BattleState.REVOLUTION and b.squads[i] > 1.0:
			BattleSystem.deploy(b, i, -(b.squads[i] - 1.0))


## Регионы с гарнизонами, от сильнейшего к слабейшему.
static func _by_garrison(b: BattleState) -> Array[int]:
	var out: Array[int] = []
	for i in b.region_count():
		if b.gov[i] > 1.0 and b.control[i] != BattleState.REVOLUTION:
			out.append(i)
	out.sort_custom(func(x: int, y: int) -> bool: return b.gov[x] > b.gov[y])
	return out


## Важные регионы (столица, заводы) с низкой поддержкой — первыми.
static func _by_importance(b: BattleState, cap: int) -> Array[int]:
	var out: Array[int] = []
	for i in b.region_count():
		if b.control[i] != BattleState.REVOLUTION and (i == cap or b.has_object(i, "factories")):
			out.append(i)
	out.sort_custom(func(x: int, y: int) -> bool: return b.support[x] < b.support[y])
	return out


## Куда бить: столица, если сил хватает; иначе самый слабый район, заводы — в первую очередь.
static func _target(b: BattleState, cap: int) -> int:
	var ours := b.squads_total()
	var cap_power := b.gov[cap] + b.police[cap]
	if ours >= cap_power * 0.8 or b.control[cap] != BattleState.POWER:
		if b.control[cap] != BattleState.REVOLUTION:
			return cap
	var best := -1
	var best_power := INF
	for i in b.region_count():
		if b.control[i] == BattleState.REVOLUTION:
			continue
		var power := b.gov[i] + b.police[i] - b.squads[i] * 0.5
		if b.has_object(i, "factories"):
			power *= 0.7
		if power < best_power:
			best_power = power
			best = i
	return best if best >= 0 else cap
