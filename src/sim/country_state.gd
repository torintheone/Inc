class_name CountryState
extends RefCounted
## Изменяемое состояние страны в партии. Статичные данные (названия, полигоны,
## исходные показатели) — в Country. Шкалы 0–100, безработица — в процентах.

const CAPITALIST := "capitalist"
const REVOLUTIONARY := "revolutionary"

## Поля, которые сохраняются и которые могут менять эффекты действий (data/actions.json).
const FIELDS: PackedStringArray = [
	# базис
	"productive_forces", "contradiction", "exploitation", "real_wage", "unemployment", "inequality",
	# надстройка
	"hegemony", "legitimacy", "repression", "army_loyalty", "elite_split", "legality",
	# движение
	"need", "consciousness", "organization", "influence", "trust", "visibility",
	# революционная ситуация
	"top_cant", "bottom_wont", "mass_activity", "rev_situation",
	# память о недавних выступлениях и доля сверхприбыли
	"strikes_recent", "demos_recent", "aristocracy",
]

var country: Country
var index: int

var productive_forces := 30.0
var contradiction := 30.0
var exploitation := 40.0
var real_wage := 50.0
var unemployment := 6.0
var inequality := 40.0

var hegemony := 60.0
var legitimacy := 60.0
var repression := 40.0
var army_loyalty := 70.0
var elite_split := 20.0
var legality := 60.0

var need := 30.0
var consciousness := 5.0
var organization := 0.0
## Влияние движения, % населения.
var influence := 0.0
var trust := 50.0
var visibility := 0.0

var top_cant := 0.0
var bottom_wont := 0.0
var mass_activity := 0.0
## Итоговая революционная ситуация: минимум из трёх условий.
var rev_situation := 0.0

var strikes_recent := 0.0
var demos_recent := 0.0
## Доля сверхприбыли, которой капитал ядра подкупает верхушку рабочих (0–1).
var aristocracy := 0.0

## Исходные уровни, к которым тянутся показатели.
var base_unemployment := 6.0
var base_real_wage := 50.0
var base_exploitation := 40.0
var base_inequality := 40.0

# Производные от данных величины: не сохраняются, их пересчитывает prepare().
var zone_hegemony := 60.0
var zone_legitimacy := 60.0
var zone_repression := 40.0
var zone_legality := 60.0
var zone_army_loyalty := 70.0
var zone_growth := 1.0
## Чувствительность к мировому циклу: зона и открытость торговле.
var sensitivity := 1.0
## Доля торговли в ВВП (0–1,5) для перекачки стоимости.
var trade_factor := 0.5
var internet := 0.5
## Потенциальная база движения, % населения.
var potential := 50.0
## Вес страны в доходе солидарности.
var size := 1.0
var is_core := false
var is_periphery := false
var status := CAPITALIST
## Сколько недель осталось у открытого «окна революции» (−1 — окна нет).
var window_left := -1
var revolution_week := -1
## Неделя, с которой действие снова доступно: id действия → неделя.
var cooldowns: Dictionary[String, int] = {}
## Опыт борьбы и прочие отметки: "strike_won", "industry_strike_won", "lessons_of_defeat", "reached".
var flags: Dictionary[String, bool] = {}


## Пересчитать величины, которые зависят только от данных (после создания или загрузки).
func prepare(data: GameData) -> void:
	var c := country
	var zone: Dictionary = data.section("zones." + c.zone)
	zone_hegemony = float(zone["hegemony"])
	zone_legitimacy = float(zone["legitimacy"])
	zone_repression = float(zone["repression"])
	zone_legality = float(zone["legality"])
	zone_army_loyalty = float(zone["army_loyalty"])
	zone_growth = float(zone["growth"])
	trade_factor = clampf(c.indicator("trade", 50.0) / 100.0, 0.1, 1.5)
	sensitivity = float(zone["crisis_sensitivity"]) * (0.6 + 0.4 * minf(trade_factor, 1.5))
	internet = c.indicator("internet", 50.0) / 100.0
	is_core = c.zone == "core"
	is_periphery = c.zone == "periphery"
	var weights: Dictionary = data.section("movement.potential")
	var total := 0.0
	for key: String in c.classes:
		total += c.classes[key] * float(weights.get(key, 0.0))
	potential = clampf(total * 100.0, 5.0, 95.0)
	size = clampf(sqrt(c.indicator("population") / data.num("solidarity.size_population")),
		data.num("solidarity.size_min"), data.num("solidarity.size_max"))


func is_revolutionary() -> bool:
	return status == REVOLUTIONARY


func has_flag(flag: String) -> bool:
	return flags.get(flag, false)


## Стадия сознания: 0 — стихийное недовольство, 1 — экономическая борьба,
## 2 — политическое сознание, 3 — революционное.
func consciousness_stage() -> int:
	return clampi(int(consciousness / 25.0), 0, 3)


func get_field(field: String) -> float:
	return float(get(field))


func set_field(field: String, value: float) -> void:
	if field == "unemployment":
		set(field, clampf(value, 0.0, 60.0))
	else:
		set(field, clampf(value, 0.0, 100.0))


func to_dict() -> Dictionary:
	var d := {"id": country.id, "status": status, "window_left": window_left,
		"revolution_week": revolution_week, "cooldowns": cooldowns.duplicate(),
		"base": {"unemployment": base_unemployment, "real_wage": base_real_wage,
			"exploitation": base_exploitation, "inequality": base_inequality},
		"flags": flags.duplicate()}
	for f in FIELDS:
		d[f] = get(f)
	return d


func load_dict(d: Dictionary) -> void:
	for f in FIELDS:
		if d.has(f):
			set(f, float(d[f]))
	status = d.get("status", CAPITALIST)
	window_left = int(d.get("window_left", -1))
	revolution_week = int(d.get("revolution_week", -1))
	var b: Dictionary = d.get("base", {})
	base_unemployment = float(b.get("unemployment", base_unemployment))
	base_real_wage = float(b.get("real_wage", base_real_wage))
	base_exploitation = float(b.get("exploitation", base_exploitation))
	base_inequality = float(b.get("inequality", base_inequality))
	cooldowns.clear()
	var cd: Dictionary = d.get("cooldowns", {})
	for k: String in cd:
		cooldowns[k] = int(cd[k])
	flags.clear()
	var fl: Dictionary = d.get("flags", {})
	for k: String in fl:
		flags[k] = bool(fl[k])
