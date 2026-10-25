class_name SimWorld
extends RefCounted
## Состояние партии и недельный шаг симуляции. Без узлов сцены: одно и то же
## состояние используют игра, тесты и безголовые прогоны. При одинаковом seed
## партия повторяется в точности: весь случай берётся из rng.

const SAVE_VERSION := 3
const NEWS_LIMIT := 120
## Точек в графике влияния у страны: раз в 4 недели за два года.
const COUNTRY_HISTORY := 26

## Исходы партии.
const OUTCOME_NONE := ""
const OUTCOME_FEDERATION := "federation"
const OUTCOME_WORLD_REVOLUTION := "world_revolution"
const OUTCOME_TWO_SYSTEMS := "two_systems"
const OUTCOME_DEFEAT := "defeat"

## Новости, ради которых игра ставит паузу и показывает сообщение.
const IMPORTANT_NEWS: PackedStringArray = ["NEWS_WINDOW_OPENED", "NEWS_REVOLUTION", "NEWS_UPRISING_DEFEATED", "NEWS_OUTCOME",
	"NEWS_CIVIL_WAR"]
## Новости, которые попадают в хронику партии на экране итогов (вместе с важными).
const CHRONICLE_NEWS: PackedStringArray = ["NEWS_START", "NEWS_BATTLE_START", "NEWS_CIVIL_WAR", "NEWS_LINE", "NEWS_LINE_CHANGED", "NEWS_CRISIS",
	"NEWS_COUNTERTENDENCY", "NEWS_REVOLUTION", "NEWS_UPRISING_DEFEATED", "NEWS_REACTION_20", "NEWS_REACTION_40",
	"NEWS_REACTION_60", "NEWS_REACTION_80", "NEWS_REACTION_100", "NEWS_OUTCOME", "NEWS_STRIKE_TO_REVOLUTION",
	"NEWS_WINDOW_OPENED", "NEWS_EVENT", "NEWS_EVENT_WORLD"]

var data: GameData
var seed_value := 0
var rng := RandomNumberGenerator.new()
var week := 0
var countries: Array[CountryState] = []
var start_country := ""
## Стратегическая линия движения ("" — ещё не выбрана) и была ли она уже сменена.
var line := ""
var line_changed := false

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

## Пузырьки на карте: {"id", "kind", "country", "born", "expires", "value"}.
var bubbles: Array[Dictionary] = []
var next_bubble_id := 1
var bubbles_collected := 0
## Сколько солидарности движение собрало за партию.
var solidarity_earned := 0.0
var protests_supported := 0
var protests_suppressed := 0
var peak_reaction := 0.0

## Открытое событие, ждущее решения: {"id", "country", "week"} ("country" — "world" для мировых).
var pending_event: Dictionary = {}
## Продолжения цепочек: {"id", "country", "week"}.
var event_queue: Array[Dictionary] = []
## Сколько раз было каждое событие и с какой недели оно снова возможно.
var events_seen: Dictionary[String, int] = {}
var event_cooldowns: Dictionary[String, int] = {}
var last_event_week := -100

## Сражение, которое идёт сейчас: пока оно не закончится, мир стоит на паузе.
var battle: BattleState = null
## Гражданские войны: страна → сражение, которое продолжается раундами раз в несколько недель.
var civil_wars: Dictionary[String, BattleState] = {}

## Ключевые события партии для экрана итогов.
var chronicle: Array[Dictionary] = []
var news: Array[Dictionary] = []
## Сколько новостей появилось за партию: интерфейс по нему узнаёт о свежих.
var news_count := 0
var outcome := OUTCOME_NONE
## Раз в 4 недели: влияние (млн человек), Реакция, доля революционных стран в ВВП.
var history: Array[Dictionary] = []


## Новая партия. start_id — страна, где зарождается движение ("" — без движения, для прогонов);
## line_id — стратегическая линия ("" — выбрать позже).
static func new_game(p_data: GameData, p_seed: int, start_id: String = "", line_id: String = "") -> SimWorld:
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
	if line_id != "":
		sim.set_line(line_id)
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
	cs.cadres = data.num("start.cadres")
	cs.flags["reached"] = true
	add_news("NEWS_START", [cs.country.name_ru], id)


## Выбрать линию в начале партии.
func set_line(id: String) -> void:
	if not data.lines.has(id):
		return
	line = id
	PlayerActions.recompute_mods(self)
	add_news("NEWS_LINE", ["LINE_" + id])


## Сменить линию: один раз за партию, ценой половины организованности везде.
func can_change_line() -> bool:
	return line != "" and not line_changed


func change_line(id: String) -> bool:
	if not can_change_line() or id == line or not data.lines.has(id):
		return false
	line = id
	line_changed = true
	var mult := data.line_change_organization_mult
	for cs in countries:
		if not cs.is_revolutionary():
			cs.set_field("organization", cs.organization * mult)
	PlayerActions.recompute_mods(self)
	add_news("NEWS_LINE_CHANGED", ["LINE_" + id], "", true)
	EventSystem.notify(self, "line_change", _strongest_country())
	return true


## Страна, где движение сильнее всего (null — движения нигде нет).
func _strongest_country() -> CountryState:
	var best: CountryState = null
	for cs in countries:
		if not cs.is_revolutionary() and (best == null or cs.influence > best.influence):
			best = cs
	return best if best != null and best.influence > 0.0 else null


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
	if is_over() or battle != null:
		return
	week += 1
	EconomySystem.advance_cycle(self)
	EconomySystem.update_imperialism(self)
	var ph := phase()
	EconomySystem.update_countries(self, ph)
	MovementSystem.update_superstructure(self, ph)
	UnrestSystem.update(self, ph)
	MovementSystem.update_movement(self, MovementSystem.compute_spread(self))
	MovementSystem.update_rev_situation(self, ph)
	ReactionSystem.update(self)
	peak_reaction = maxf(peak_reaction, reaction)
	var income := weekly_income()
	solidarity = maxf(solidarity + income, 0.0)
	solidarity_earned += maxf(income, 0.0)
	UnrestSystem.spawn_solidarity(self)
	UnrestSystem.expire(self)
	EventSystem.update(self)
	_civil_war_rounds()
	if week % 4 == 0:
		_record_history()
	_check_outcome()


func run_weeks(n: int) -> void:
	for i in n:
		if is_over():
			return
		step()


## Постоянный доход солидарности за неделю: небольшой взнос, помощь революционных стран,
## минус содержание стачечного фонда. Основное — пузырьки на карте.
func weekly_income() -> float:
	if start_country == "":
		return 0.0
	var d := data
	var income := d.num("solidarity.base") - mod("upkeep")
	var per_rev := d.num("solidarity.revolutionary_country") * (1.0 - (d.num("reaction.intervention_income_penalty") if reaction >= 60.0 else 0.0))
	for cs in countries:
		if cs.is_revolutionary() and not cs.active("blockade", week):
			income += per_rev * cs.size
	return income


func on_country_reached(cs: CountryState) -> void:
	if cs.country.id == start_country:
		return
	add_bubble(UnrestSystem.SOLIDARITY, cs.country.id, int(data.num("bubbles.solidarity_weeks")), data.num("bubbles.reached_value"))
	add_news("NEWS_REACHED", [cs.country.name_ru], cs.country.id)


func add_bubble(kind: String, country_id: String, weeks: int, value: float) -> void:
	bubbles.append({"id": next_bubble_id, "kind": kind, "country": country_id, "born": week,
		"expires": week + weeks, "value": value})
	next_bubble_id += 1


## Игрок коснулся пузырька. Возвращает {"ok", "kind", "value", "country"}.
func collect_bubble(id: int) -> Dictionary:
	return UnrestSystem.collect(self, id)


func on_window_opened(cs: CountryState) -> void:
	add_news("NEWS_WINDOW_OPENED", [cs.country.name_ru], cs.country.id, true)


## Победа восстания: страна становится революционной.
func make_revolutionary(cs: CountryState) -> void:
	var d := data
	cs.status = CountryState.REVOLUTIONARY
	cs.revolution_week = week
	cs.window_left = -1
	cs.unrest = 0.0
	ReactionSystem.add(self, d.num("revolution.reaction"))
	# Победа где угодно даёт рывок активности по всему миру, а соседям — пример.
	var boost := d.num("revolution.world_influence_boost")
	for other in countries:
		if other.is_revolutionary() or other.influence <= 0.0:
			continue
		other.demos_recent += d.num("revolution.world_activity")
		other.set_field("influence", other.influence * boost)
	var inspired: CountryState = null
	for nid in cs.country.neighbors:
		var n := state_of(nid)
		if n != null and not n.is_revolutionary():
			n.demos_recent += d.num("revolution.neighbor_activity")
			n.set_field("repression", n.repression + d.num("revolution.neighbor_repression"))
			if inspired == null or n.influence > inspired.influence:
				inspired = n
	add_news("NEWS_REVOLUTION", [cs.country.name_ru], cs.country.id, true)
	EventSystem.notify(self, "revolution_neighbor", inspired)


## Восстание: начинается сражение на карте страны. false — карты страны нет или сражение уже идёт.
func begin_battle(cs: CountryState, penalty: float = 0.0, agitators: int = -1) -> bool:
	if battle != null or civil_wars.has(cs.country.id):
		return false
	var b := BattleSystem.start(self, cs, penalty, agitators)
	if b == null:
		return false
	battle = b
	add_news("NEWS_BATTLE_START", [cs.country.name_ru], cs.country.id)
	return true


## Сыграть очередной раунд гражданской войны самому.
func resume_civil_war(id: String) -> bool:
	if battle != null or not civil_wars.has(id):
		return false
	battle = civil_wars[id]
	BattleSystem.begin_round(self, battle)
	return true


func in_civil_war(id: String) -> bool:
	return civil_wars.has(id)


## Сражение закончено: итог переносится на мировую карту.
func finish_battle() -> void:
	if battle == null or not battle.is_over():
		return
	var b := battle
	battle = null
	_apply_battle(b)


func _apply_battle(b: BattleState) -> void:
	var d := data
	var cs := state_of(b.country_id)
	if cs == null:
		civil_wars.erase(b.country_id)
		return
	var ongoing := civil_wars.has(b.country_id)
	if b.outcome == BattleState.OUTCOME_CIVIL_WAR:
		b.rounds += 1
		# Затянувшаяся война решается перевесом сил.
		if b.rounds >= int(d.num("battle.outcome.civil_war_max_rounds")):
			var won := b.control_share() >= d.num("battle.outcome.civil_war_final_share")
			b.outcome = BattleState.OUTCOME_VICTORY if won else BattleState.OUTCOME_DEFEAT
			b.outcome_reason = "exhaustion"
	match b.outcome:
		BattleState.OUTCOME_VICTORY:
			civil_wars.erase(b.country_id)
			make_revolutionary(cs)
		BattleState.OUTCOME_DEFEAT:
			civil_wars.erase(b.country_id)
			defeat_uprising(cs)
		BattleState.OUTCOME_CIVIL_WAR:
			civil_wars[b.country_id] = b
			b.next_round_week = week + int(d.num("battle.outcome.civil_war_round_weeks"))
			cs.window_left = -1
			if ongoing:
				add_news("NEWS_CIVIL_WAR_GOES_ON", [cs.country.name_ru, roundi(b.control_share() * 100.0)], cs.country.id)
			else:
				add_news("NEWS_CIVIL_WAR", [cs.country.name_ru], cs.country.id, true)


## Раунды гражданских войн, которые игрок не сыграл сам, рассчитываются автоматически.
func _civil_war_rounds() -> void:
	for id: String in civil_wars.keys():
		var b: BattleState = civil_wars[id]
		if week < b.next_round_week:
			continue
		BattleSystem.begin_round(self, b)
		BattleBot.run(self, b, BattleBot.AUTO)
		_apply_battle(b)


## Разгром восстания: влияние падает, приходит белый террор, остаётся опыт.
func defeat_uprising(cs: CountryState) -> void:
	var d := data
	# Явочные квартиры сохраняют часть движения после разгрома.
	var cushion := clampf(mod("defeat_cushion"), 0.0, 1.0) * 0.5
	var infl_mult := d.num("revolution.defeat_influence_mult")
	var org_mult := d.num("revolution.defeat_organization_mult")
	var cadre_mult := d.num("cadres.defeat_mult")
	cs.set_field("influence", cs.influence * (infl_mult + (1.0 - infl_mult) * cushion))
	cs.set_field("organization", cs.organization * (org_mult + (1.0 - org_mult) * cushion))
	cs.cadres *= cadre_mult + (1.0 - cadre_mult) * cushion
	cs.set_field("repression", cs.repression + d.num("revolution.defeat_repression"))
	cs.flags["lessons_of_defeat"] = true
	cs.window_left = -1
	add_news("NEWS_UPRISING_DEFEATED", [cs.country.name_ru], cs.country.id, true)
	EventSystem.notify(self, "defeat", cs)


func add_news(key: String, args: Array, country_id: String = "", important: bool = false) -> void:
	var item := {"week": week, "key": key, "args": args, "country": country_id,
		"important": important or IMPORTANT_NEWS.has(key)}
	news.append(item)
	news_count += 1
	if CHRONICLE_NEWS.has(key):
		chronicle.append(item.duplicate())
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
	for cs in countries:
		if cs.influence <= 0.0 and cs.history.is_empty():
			continue
		cs.history.append(100.0 if cs.is_revolutionary() else cs.influence)
		if cs.history.size() > COUNTRY_HISTORY:
			cs.history.remove_at(0)


## Очки партии и из чего они сложились: {"total", "share", "revolutions", "victory", "speed"}.
func score() -> Dictionary:
	var d := data
	var shares := revolutionary_shares()
	var share := d.num("score.share") * (shares.x + shares.y) / 2.0
	var revs := d.num("score.revolution") * revolutionary_count() \
		+ (d.num("score.core_revolution") - d.num("score.revolution")) * revolutionary_count("core")
	var victory := 0.0
	var speed := 0.0
	if outcome == OUTCOME_FEDERATION or outcome == OUTCOME_WORLD_REVOLUTION:
		victory = d.num("score." + outcome)
		var years_left := d.num("time.max_years") - float(week) / d.num("time.weeks_per_year")
		speed = d.num("score.per_year_left") * maxf(years_left, 0.0)
	var total := roundf(share + revs + victory + speed)
	return {"total": int(total), "share": int(roundf(share)), "revolutions": int(roundf(revs)),
		"victory": int(victory), "speed": int(roundf(speed))}


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
		"line": line,
		"line_changed": line_changed,
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
		"bubbles": bubbles.duplicate(true),
		"next_bubble_id": next_bubble_id,
		"bubbles_collected": bubbles_collected,
		"solidarity_earned": solidarity_earned,
		"protests_supported": protests_supported,
		"protests_suppressed": protests_suppressed,
		"peak_reaction": peak_reaction,
		"chronicle": chronicle.duplicate(true),
		"pending_event": pending_event.duplicate(),
		"event_queue": event_queue.duplicate(true),
		"events_seen": events_seen.duplicate(),
		"event_cooldowns": event_cooldowns.duplicate(),
		"last_event_week": last_event_week,
		"battle": battle.to_dict() if battle != null and not civil_wars.has(battle.country_id) else {},
		"battle_civil_war": battle.country_id if battle != null and civil_wars.has(battle.country_id) else "",
		"civil_wars": _civil_wars_dict(),
		"news": news.duplicate(true),
		"news_count": news_count,
		"outcome": outcome,
		"history": history.duplicate(true),
	}


func _civil_wars_dict() -> Dictionary:
	var out := {}
	for id: String in civil_wars:
		out[id] = civil_wars[id].to_dict()
	return out


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
	sim.line = d.get("line", "")
	sim.line_changed = bool(d.get("line_changed", false))
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
	for item: Dictionary in d.get("bubbles", []):
		item["id"] = int(item["id"])
		item["born"] = int(item["born"])
		item["expires"] = int(item["expires"])
		sim.bubbles.append(item)
	sim.next_bubble_id = int(d.get("next_bubble_id", 1))
	sim.bubbles_collected = int(d.get("bubbles_collected", 0))
	sim.solidarity_earned = float(d.get("solidarity_earned", 0.0))
	sim.protests_supported = int(d.get("protests_supported", 0))
	sim.protests_suppressed = int(d.get("protests_suppressed", 0))
	sim.peak_reaction = float(d.get("peak_reaction", sim.reaction))
	for item: Dictionary in d.get("chronicle", []):
		sim.chronicle.append(item)
	var pe: Dictionary = d.get("pending_event", {})
	if not pe.is_empty():
		sim.pending_event = {"id": str(pe["id"]), "country": str(pe["country"]), "week": int(pe["week"])}
	for q: Dictionary in d.get("event_queue", []):
		sim.event_queue.append({"id": str(q["id"]), "country": str(q["country"]), "week": int(q["week"])})
	var seen: Dictionary = d.get("events_seen", {})
	for k: String in seen:
		sim.events_seen[k] = int(seen[k])
	var cds: Dictionary = d.get("event_cooldowns", {})
	for k: String in cds:
		sim.event_cooldowns[k] = int(cds[k])
	sim.last_event_week = int(d.get("last_event_week", -100))
	var cw: Dictionary = d.get("civil_wars", {})
	for id: String in cw:
		sim.civil_wars[id] = BattleState.from_dict(cw[id])
	var bd: Dictionary = d.get("battle", {})
	if not bd.is_empty():
		sim.battle = BattleState.from_dict(bd)
	elif sim.civil_wars.has(str(d.get("battle_civil_war", ""))):
		sim.battle = sim.civil_wars[str(d["battle_civil_war"])]
	for item: Dictionary in d.get("news", []):
		sim.news.append(item)
	sim.news_count = int(d.get("news_count", sim.news.size()))
	sim.outcome = d.get("outcome", OUTCOME_NONE)
	for item: Dictionary in d.get("history", []):
		sim.history.append(item)
	return sim
