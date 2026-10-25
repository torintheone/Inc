class_name SimWorld
extends RefCounted
## Состояние партии и недельный шаг симуляции. Без узлов сцены: одно и то же
## состояние используют игра, тесты и безголовые прогоны. При одинаковом seed
## партия повторяется в точности: весь случай берётся из rng.

const SAVE_VERSION := 1
const NEWS_LIMIT := 120

## Исходы партии.
const OUTCOME_NONE := ""
const OUTCOME_FEDERATION := "federation"
const OUTCOME_WORLD_REVOLUTION := "world_revolution"
const OUTCOME_TWO_SYSTEMS := "two_systems"
const OUTCOME_DEFEAT := "defeat"

## Новости, ради которых игра ставит паузу и показывает сообщение.
const IMPORTANT_NEWS: PackedStringArray = ["NEWS_WINDOW_OPENED", "NEWS_REVOLUTION", "NEWS_UPRISING_DEFEATED", "NEWS_OUTCOME"]

var data: GameData
var seed_value := 0
var rng := RandomNumberGenerator.new()
var week := 0
var countries: Array[CountryState] = []
var start_country := ""

var solidarity := 0.0
var reaction := 0.0
var reaction_reached: Dictionary[int, bool] = {}
var white_terror_count := 0
var last_white_terror_week := -1

# Мировой цикл.
var cycle_number := 0
var cycle_length := 0
var phase_index := 0
var phase_week := 0
var phase_lengths := PackedInt32Array()
var depth := 1.0
var depth_relief := 0.0
var countertendency_used := false
var crisis_weeks := PackedInt32Array()

# Империализм.
var core_aristocracy := 0.0
var initial_aristocracy := -1.0
var initial_core_share := 0.0
## Средняя противоречивость ядра в начале партии: от неё отсчитывается углубление кризисов.
var initial_core_contradiction := -1.0

# Улучшения движения.
var upgrades: Dictionary[String, bool] = {}
var mods: Dictionary[String, float] = {}
var unlocks: Dictionary[String, bool] = {}

var news: Array[Dictionary] = []
## Сколько новостей появилось за партию: интерфейс по нему узнаёт о свежих.
var news_count := 0
var outcome := OUTCOME_NONE
## Раз в 4 недели: влияние (млн человек), Реакция, доля революционных стран в ВВП.
var history: Array[Dictionary] = []


## Новая партия. start_id — страна, где зарождается движение ("" — без движения, для прогонов).
static func new_game(p_data: GameData, p_seed: int, start_id: String = "") -> SimWorld:
	var sim := SimWorld.new()
	sim.data = p_data
	sim.seed_value = p_seed
	sim.rng.seed = p_seed
	for c in p_data.world.countries:
		var cs := CountryState.new()
		cs.country = c
		cs.index = c.index
		EconomySystem.init_country(sim, cs)
		sim.countries.append(cs)
	for cs in sim.countries:
		if cs.is_core:
			sim.initial_core_share += p_data.gdp_share[cs.index]
	sim.solidarity = p_data.num("start.solidarity")
	_start_world_cycle(sim)
	EconomySystem.update_imperialism(sim)
	if start_id != "":
		sim.start_movement(start_id)
	return sim


## Партия начинается в случайной точке оживления или подъёма.
static func _start_world_cycle(sim: SimWorld) -> void:
	EconomySystem.start_cycle(sim)
	sim.news.clear()
	sim.news_count = 0
	sim.phase_index = sim.rng.randi_range(0, 1)
	sim.phase_week = sim.rng.randi_range(0, maxi(sim.phase_lengths[sim.phase_index] - 1, 0))


func start_movement(id: String) -> void:
	var cs := state_of(id)
	if cs == null:
		return
	start_country = id
	cs.influence = data.num("start.influence")
	cs.consciousness = data.num("start.consciousness")
	cs.organization = data.num("start.organization")
	cs.trust = data.num("start.trust")
	cs.flags["reached"] = true
	add_news("NEWS_START", [cs.country.name_ru], id)


func state_of(id: String) -> CountryState:
	var c := data.world.get_country(id)
	return countries[c.index] if c != null else null


func phase() -> Dictionary:
	var phases: Array = data.section("cycle.phases")
	return phases[phase_index]


func phase_id() -> String:
	return phase()["id"]


## Сумма модификатора по всем купленным улучшениям (0, если такого нет).
func mod(key: String) -> float:
	return mods.get(key, 0.0)


func has_unlock(key: String) -> bool:
	return unlocks.has(key)


func year() -> int:
	return int(data.num("time.start_year")) + week / int(data.num("time.weeks_per_year"))


func is_over() -> bool:
	return outcome != OUTCOME_NONE


## Один шаг симуляции — неделя.
func step() -> void:
	if is_over():
		return
	week += 1
	EconomySystem.advance_cycle(self)
	EconomySystem.update_imperialism(self)
	var ph := phase()
	EconomySystem.update_countries(self, ph)
	MovementSystem.update_superstructure(self, ph)
	MovementSystem.update_movement(self, MovementSystem.compute_spread(self))
	MovementSystem.update_rev_situation(self, ph)
	ReactionSystem.update(self)
	solidarity += weekly_income()
	if week % 4 == 0:
		_record_history()
	_check_outcome()


func run_weeks(n: int) -> void:
	for i in n:
		if is_over():
			return
		step()


## Доход солидарности за неделю: от охвата движения и от революционных стран.
func weekly_income() -> float:
	var d := data
	var income := d.num("solidarity.base")
	var per_influence := d.num("solidarity.per_influence")
	var per_rev := d.num("solidarity.revolutionary_country") * (1.0 - (d.num("reaction.intervention_income_penalty") if reaction >= 60.0 else 0.0))
	var reach := 0.0
	for cs in countries:
		if cs.is_revolutionary():
			income += per_rev * cs.size
		else:
			reach += cs.influence * cs.size
	# Доход растёт медленнее, чем охват: иначе к середине партии солидарности некуда девать.
	return income + per_influence * sqrt(reach)


func on_country_reached(cs: CountryState) -> void:
	if cs.country.id == start_country:
		return
	solidarity += data.num("solidarity.new_country")
	add_news("NEWS_REACHED", [cs.country.name_ru], cs.country.id)


func on_window_opened(cs: CountryState) -> void:
	add_news("NEWS_WINDOW_OPENED", [cs.country.name_ru], cs.country.id, true)


## Победа восстания: страна становится революционной.
func make_revolutionary(cs: CountryState) -> void:
	var d := data
	cs.status = CountryState.REVOLUTIONARY
	cs.revolution_week = week
	cs.window_left = -1
	ReactionSystem.add(self, d.num("revolution.reaction"))
	# Победа где угодно даёт рывок активности по всему миру, а соседям — пример.
	var boost := d.num("revolution.world_influence_boost")
	for other in countries:
		if other.is_revolutionary() or other.influence <= 0.0:
			continue
		other.demos_recent += d.num("revolution.world_activity")
		other.set_field("influence", other.influence * boost)
	for nid in cs.country.neighbors:
		var n := state_of(nid)
		if n != null and not n.is_revolutionary():
			n.demos_recent += d.num("revolution.neighbor_activity")
			n.set_field("repression", n.repression + d.num("revolution.neighbor_repression"))
	add_news("NEWS_REVOLUTION", [cs.country.name_ru], cs.country.id, true)


## Разгром восстания: влияние падает, приходит белый террор, остаётся опыт.
func defeat_uprising(cs: CountryState) -> void:
	var d := data
	cs.set_field("influence", cs.influence * d.num("revolution.defeat_influence_mult"))
	cs.set_field("organization", cs.organization * d.num("revolution.defeat_organization_mult"))
	cs.set_field("repression", cs.repression + d.num("revolution.defeat_repression"))
	cs.flags["lessons_of_defeat"] = true
	cs.window_left = -1
	add_news("NEWS_UPRISING_DEFEATED", [cs.country.name_ru], cs.country.id, true)


func add_news(key: String, args: Array, country_id: String = "", important: bool = false) -> void:
	news.append({"week": week, "key": key, "args": args, "country": country_id,
		"important": important or IMPORTANT_NEWS.has(key)})
	news_count += 1
	if news.size() > NEWS_LIMIT:
		news.pop_front()


## Доли революционных стран в мировом ВВП (x) и населении (y).
func revolutionary_shares() -> Vector2:
	var gdp := 0.0
	var pop := 0.0
	for cs in countries:
		if cs.is_revolutionary():
			gdp += data.gdp_share[cs.index]
			pop += data.population_share[cs.index]
	return Vector2(gdp, pop)


func revolutionary_count(zone: String = "") -> int:
	var n := 0
	for cs in countries:
		if cs.is_revolutionary() and (zone == "" or cs.country.zone == zone):
			n += 1
	return n


## Сколько людей под влиянием движения.
func influenced_people() -> float:
	var total := 0.0
	for cs in countries:
		var share := 100.0 if cs.is_revolutionary() else cs.influence
		total += share / 100.0 * cs.country.indicator("population")
	return total


func _record_history() -> void:
	history.append({"week": week, "influenced": influenced_people(), "reaction": reaction,
		"revolutionary_gdp": revolutionary_shares().x})


func _check_outcome() -> void:
	var d := data
	var shares := revolutionary_shares()
	var result := OUTCOME_NONE
	if minf(shares.x, shares.y) >= d.num("outcome.federation_share"):
		result = OUTCOME_FEDERATION
	elif minf(shares.x, shares.y) >= d.num("outcome.world_revolution_share") \
			and revolutionary_count("core") >= int(d.num("outcome.world_revolution_core")):
		result = OUTCOME_WORLD_REVOLUTION
	elif start_country != "" and week >= int(d.num("outcome.grace_weeks")) and _movement_crushed():
		result = OUTCOME_DEFEAT
	elif week >= int(d.num("time.max_years")) * int(d.num("time.weeks_per_year")):
		result = OUTCOME_TWO_SYSTEMS if revolutionary_count() > 0 else OUTCOME_DEFEAT
	if result != OUTCOME_NONE:
		outcome = result
		add_news("NEWS_OUTCOME", ["OUTCOME_" + result], "", true)


## Поражение: движение почти исчезло везде или белый террор держится больше года без революций.
func _movement_crushed() -> bool:
	if revolutionary_count() > 0:
		return false
	var limit := data.num("outcome.defeat_influence")
	var alive := false
	for cs in countries:
		if cs.influence >= limit:
			alive = true
			break
	if not alive:
		return true
	return white_terror_count > 0 and reaction >= data.num("reaction.white_terror_rollback") \
		and week - last_white_terror_week >= int(data.num("outcome.white_terror_weeks"))


# --- Сохранение -------------------------------------------------------------

func to_dict() -> Dictionary:
	var states := []
	for cs in countries:
		states.append(cs.to_dict())
	var reached := []
	for t: int in reaction_reached:
		reached.append(t)
	return {
		"version": SAVE_VERSION,
		"seed": seed_value,
		"rng_state": str(rng.state),
		"week": week,
		"start_country": start_country,
		"solidarity": solidarity,
		"reaction": reaction,
		"reaction_reached": reached,
		"white_terror_count": white_terror_count,
		"last_white_terror_week": last_white_terror_week,
		"cycle": {
			"number": cycle_number, "length": cycle_length, "phase_index": phase_index, "phase_week": phase_week,
			"phase_lengths": Array(phase_lengths), "depth": depth, "depth_relief": depth_relief,
			"countertendency_used": countertendency_used, "crisis_weeks": Array(crisis_weeks),
		},
		"core_aristocracy": core_aristocracy,
		"initial_aristocracy": initial_aristocracy,
		"initial_core_share": initial_core_share,
		"initial_core_contradiction": initial_core_contradiction,
		"upgrades": upgrades.keys(),
		"countries": states,
		"news": news.duplicate(true),
		"news_count": news_count,
		"outcome": outcome,
		"history": history.duplicate(true),
	}


static func from_dict(p_data: GameData, d: Dictionary) -> SimWorld:
	if int(d.get("version", 0)) != SAVE_VERSION:
		return null
	var sim := SimWorld.new()
	sim.data = p_data
	sim.seed_value = int(d["seed"])
	sim.rng.seed = sim.seed_value
	sim.rng.state = int(str(d["rng_state"]))
	sim.week = int(d["week"])
	sim.start_country = d.get("start_country", "")
	sim.solidarity = float(d["solidarity"])
	sim.reaction = float(d["reaction"])
	for t in d.get("reaction_reached", []):
		sim.reaction_reached[int(t)] = true
	sim.white_terror_count = int(d.get("white_terror_count", 0))
	sim.last_white_terror_week = int(d.get("last_white_terror_week", -1))
	var cy: Dictionary = d["cycle"]
	sim.cycle_number = int(cy["number"])
	sim.cycle_length = int(cy["length"])
	sim.phase_index = int(cy["phase_index"])
	sim.phase_week = int(cy["phase_week"])
	sim.phase_lengths = PackedInt32Array(cy["phase_lengths"])
	sim.depth = float(cy["depth"])
	sim.depth_relief = float(cy["depth_relief"])
	sim.countertendency_used = bool(cy["countertendency_used"])
	sim.crisis_weeks = PackedInt32Array(cy["crisis_weeks"])
	sim.core_aristocracy = float(d["core_aristocracy"])
	sim.initial_aristocracy = float(d["initial_aristocracy"])
	sim.initial_core_share = float(d["initial_core_share"])
	sim.initial_core_contradiction = float(d.get("initial_core_contradiction", -1.0))
	for id: String in d.get("upgrades", []):
		sim.upgrades[id] = true
	PlayerActions.recompute_mods(sim)
	var by_id := {}
	for item: Dictionary in d["countries"]:
		by_id[item["id"]] = item
	for c in p_data.world.countries:
		var cs := CountryState.new()
		cs.country = c
		cs.index = c.index
		if by_id.has(c.id):
			cs.prepare(p_data)
			cs.load_dict(by_id[c.id])
		else:
			EconomySystem.init_country(sim, cs)
		sim.countries.append(cs)
	for item: Dictionary in d.get("news", []):
		sim.news.append(item)
	sim.news_count = int(d.get("news_count", sim.news.size()))
	sim.outcome = d.get("outcome", OUTCOME_NONE)
	for item: Dictionary in d.get("history", []):
		sim.history.append(item)
	return sim
