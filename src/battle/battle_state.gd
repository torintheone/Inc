class_name BattleState
extends RefCounted
## Состояние местного сражения: регионы страны, силы сторон, ресурсы игрока, доверие масс,
## перерывы действий, переброски войск власти, журнал и итог. Шаг — один день.

const POWER := 0
const CONTESTED := 1
const REVOLUTION := 2

const OUTCOME_NONE := ""
const OUTCOME_VICTORY := "victory"
const OUTCOME_CIVIL_WAR := "civil_war"
const OUTCOME_DEFEAT := "defeat"

var country_id := ""
var day := 0
var max_days := 90
var rng := RandomNumberGenerator.new()
var line := ""
## Карта страны из data/battle_maps.json (только для чтения).
var map: Dictionary = {}

# Регионы (индекс — номер региона на карте).
var support := PackedFloat64Array()
var control := PackedInt32Array()
var gov := PackedFloat64Array()
var police := PackedFloat64Array()
var loyalty := PackedFloat64Array()
var squads := PackedFloat64Array()
var barricades := PackedInt32Array()
var strike_days := PackedInt32Array()
var council: Array[bool] = []
var neutral: Array[bool] = []
var defected: Array[bool] = []
## Доля населения страны в регионе (0–1) и есть ли там объект.
var pop_share := PackedFloat64Array()

# Ресурсы игрока.
var squads_pool := 0.0
## Свободные агитаторы; занятые возвращаются через несколько дней: {"n", "back"}.
var agitators := 0
var busy: Array[Dictionary] = []
var supplies := 0.0
var weapons := 0.0
var trust := 50.0
var hungry := false

# Власть.
var reserve := 0.0
## Верность войск резерва: с ней прибывают подкрепления.
var reserve_loyalty := 70.0
## Сила гарнизонов, перешедших на сторону революции: в верности армии считается как нулевая.
var defected_strength := 0.0
## Войска в пути: {"from", "to", "strength", "loyalty", "sent", "arrive"}.
var transfers: Array[Dictionary] = []

## Захваченные объекты: "comms", "railway", "arsenal", "port" → true.
var seized: Dictionary[String, bool] = {}
var appeal_done := false
var land_reform := false
var leadership_arrested := false
## День, когда сложится новое руководство после ареста.
var leadership_back := -1
var army_defected := false
var curfew_until := -1
var intervention_done := false
var volunteers_done: Dictionary[int, bool] = {}
## День, с которого действие снова доступно.
var cooldowns: Dictionary[String, int] = {}
## Солидарность, потраченная в сражении (списывается с мировой).
var solidarity_spent := 0.0

## Журнал: {"day", "key", "args"}.
var log: Array[Dictionary] = []
var outcome := OUTCOME_NONE
var outcome_reason := ""
## Гражданская война: сколько раундов уже прошло и на какой неделе мира следующий.
var rounds := 0
var next_round_week := -1


func region_count() -> int:
	return support.size()


func region(i: int) -> Dictionary:
	return map["regions"][i]


func has_object(i: int, object: String) -> bool:
	return object in region(i).get("objects", [])


func capital() -> int:
	for i in region_count():
		if has_object(i, "capital"):
			return i
	return 0


func is_over() -> bool:
	return outcome != OUTCOME_NONE


func add_log(key: String, args: Array = []) -> void:
	log.append({"day": day, "key": key, "args": args})
	if log.size() > 80:
		log.pop_front()


## Доля населения под контролем революции: спорные регионы с отрядами — наполовину,
## без отрядов (только восставшие жители) — на четверть.
func control_share() -> float:
	var s := 0.0
	for i in region_count():
		if control[i] == REVOLUTION:
			s += pop_share[i]
		elif control[i] == CONTESTED:
			s += pop_share[i] * (0.5 if squads[i] > 0.0 else 0.25)
	return s


## Доля промышленных регионов под контролем революции.
func factory_share() -> float:
	var total := 0
	var ours := 0
	for i in region_count():
		if has_object(i, "factories"):
			total += 1
			if control[i] == REVOLUTION:
				ours += 1
	return float(ours) / maxf(total, 1)


## Средняя верность армии, взвешенная по силе гарнизонов; перешедшие солдаты — с нулевой верностью.
func army_loyalty() -> float:
	var w := defected_strength
	var s := 0.0
	for i in region_count():
		if gov[i] > 0.0:
			w += gov[i]
			s += gov[i] * loyalty[i]
	return s / w if w > 0.0 else 100.0


## Перезарядка действия: у действий в регионе — своя в каждом регионе.
static func cooldown_key(id: String, i: int) -> String:
	return id if i < 0 else "%s:%d" % [id, i]


## Подкрепление власти в регионе: верность гарнизона смешивается с верностью прибывших.
func reinforce(i: int, strength: float, p_loyalty: float) -> void:
	if strength <= 0.0:
		return
	var total := gov[i] + strength
	loyalty[i] = (gov[i] * loyalty[i] + strength * p_loyalty) / total
	gov[i] = total


## Все агитаторы: свободные и занятые.
func agitators_total() -> int:
	var t := agitators
	for item in busy:
		t += int(item["n"])
	return t


func squads_total() -> float:
	var t := squads_pool
	for v in squads:
		t += v
	return t


func to_dict() -> Dictionary:
	return {
		"country": country_id, "day": day, "max_days": max_days, "rng_state": str(rng.state), "seed": rng.seed,
		"line": line,
		"support": Array(support), "control": Array(control), "gov": Array(gov), "police": Array(police),
		"loyalty": Array(loyalty), "squads": Array(squads), "barricades": Array(barricades),
		"strike_days": Array(strike_days), "council": council.duplicate(), "neutral": neutral.duplicate(),
		"defected": defected.duplicate(), "pop_share": Array(pop_share),
		"squads_pool": squads_pool, "agitators": agitators, "busy": busy.duplicate(true), "supplies": supplies, "weapons": weapons, "trust": trust,
		"hungry": hungry, "reserve": reserve, "reserve_loyalty": reserve_loyalty, "defected_strength": defected_strength, "transfers": transfers.duplicate(true), "seized": seized.duplicate(),
		"appeal_done": appeal_done, "land_reform": land_reform, "leadership_arrested": leadership_arrested, "leadership_back": leadership_back,
		"army_defected": army_defected, "curfew_until": curfew_until, "intervention_done": intervention_done,
		"volunteers_done": volunteers_done.keys(), "cooldowns": cooldowns.duplicate(),
		"solidarity_spent": solidarity_spent, "log": log.duplicate(true), "outcome": outcome,
		"outcome_reason": outcome_reason, "rounds": rounds, "next_round_week": next_round_week,
	}


static func from_dict(d: Dictionary) -> BattleState:
	var b := BattleState.new()
	b.country_id = d["country"]
	b.map = BattleMaps.country(b.country_id)
	b.day = int(d["day"])
	b.max_days = int(d["max_days"])
	b.rng.seed = int(d.get("seed", 0))
	b.rng.state = int(str(d["rng_state"]))
	b.line = d.get("line", "")
	b.support = PackedFloat64Array(d["support"])
	b.control = PackedInt32Array(d["control"])
	b.gov = PackedFloat64Array(d["gov"])
	b.police = PackedFloat64Array(d["police"])
	b.loyalty = PackedFloat64Array(d["loyalty"])
	b.squads = PackedFloat64Array(d["squads"])
	b.barricades = PackedInt32Array(d["barricades"])
	b.strike_days = PackedInt32Array(d["strike_days"])
	for v in d["council"]:
		b.council.append(bool(v))
	for v in d["neutral"]:
		b.neutral.append(bool(v))
	for v in d["defected"]:
		b.defected.append(bool(v))
	b.pop_share = PackedFloat64Array(d["pop_share"])
	b.squads_pool = float(d["squads_pool"])
	b.agitators = int(d["agitators"])
	for item: Dictionary in d.get("busy", []):
		b.busy.append({"n": int(item["n"]), "back": int(item["back"])})
	b.supplies = float(d["supplies"])
	b.weapons = float(d["weapons"])
	b.trust = float(d["trust"])
	b.hungry = bool(d.get("hungry", false))
	b.reserve = float(d["reserve"])
	b.reserve_loyalty = float(d.get("reserve_loyalty", 70.0))
	b.defected_strength = float(d.get("defected_strength", 0.0))
	for t: Dictionary in d.get("transfers", []):
		b.transfers.append({"from": int(t.get("from", t["to"])), "to": int(t["to"]), "strength": float(t["strength"]),
			"loyalty": float(t.get("loyalty", b.reserve_loyalty)), "sent": int(t.get("sent", b.day)), "arrive": int(t["arrive"])})
	var seized: Dictionary = d.get("seized", {})
	for k: String in seized:
		b.seized[k] = bool(seized[k])
	b.appeal_done = bool(d.get("appeal_done", false))
	b.land_reform = bool(d.get("land_reform", false))
	b.leadership_arrested = bool(d.get("leadership_arrested", false))
	b.leadership_back = int(d.get("leadership_back", -1))
	b.army_defected = bool(d.get("army_defected", false))
	b.curfew_until = int(d.get("curfew_until", -1))
	b.intervention_done = bool(d.get("intervention_done", false))
	for v in d.get("volunteers_done", []):
		b.volunteers_done[int(v)] = true
	var cds: Dictionary = d.get("cooldowns", {})
	for k: String in cds:
		b.cooldowns[k] = int(cds[k])
	b.solidarity_spent = float(d.get("solidarity_spent", 0.0))
	for item: Dictionary in d.get("log", []):
		b.log.append(item)
	b.outcome = d.get("outcome", OUTCOME_NONE)
	b.outcome_reason = d.get("outcome_reason", "")
	b.rounds = int(d.get("rounds", 0))
	b.next_round_week = int(d.get("next_round_week", -1))
	return b
