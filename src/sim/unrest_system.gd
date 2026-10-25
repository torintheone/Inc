class_name UnrestSystem
extends RefCounted
## Стихийное рабочее движение и пузырьки на карте. Протесты вспыхивают сами — чаще
## там, где нужда выше, и в кризис. Государство их подавляет, если партия не поддержит:
## над страной появляется пузырёк протеста, касание — поддержка. Пузырьки солидарности
## появляются там, где движение уже есть, и пополняют общий запас солидарности.

const PROTEST := "protest"
const SOLIDARITY := "solidarity"

## Виды вспышек — для разнообразия новостей.
const KIND_STRIKE := "strike"
const KIND_PRICES := "prices"
const KIND_UNEMPLOYED := "unemployed"
const KIND_PEASANTS := "peasants"


## Неделя стихийного движения: вспышки, затухание, пузырьки протестов.
static func update(sim: SimWorld, phase: Dictionary) -> void:
	var d := sim.data
	var base := d.num("unrest.flare_base") * float(phase.get("unrest", 1.0))
	var need_ref := d.num("unrest.need_ref")
	var boost := d.num("unrest.influence_boost")
	var f_min := d.num("unrest.flare_min")
	var f_max := d.num("unrest.flare_max")
	var decay := d.num("unrest.decay")
	var rep_decay := d.num("unrest.repression_decay")
	var supported_mult := d.num("unrest.supported_decay_mult")
	var protests := count(sim, PROTEST)
	var max_protests := int(d.num("bubbles.max_protest"))
	for cs in sim.countries:
		if cs.is_revolutionary():
			cs.unrest = 0.0
			continue
		var n := cs.need / need_ref
		var chance := base * cs.size * n * n * (1.0 + boost * cs.influence)
		if sim.rng.randf() < chance:
			cs.unrest = clampf(cs.unrest + sim.rng.randf_range(f_min, f_max), 0.0, 100.0)
			cs.demos_recent += 0.5
			var kind := _flare_kind(sim, cs, phase["id"])
			if protests < max_protests and not has_bubble(sim, cs.country.id, PROTEST):
				sim.add_bubble(PROTEST, cs.country.id, int(d.num("bubbles.protest_weeks")), d.num("unrest.support_solidarity"))
				protests += 1
			sim.add_news("NEWS_UNREST_" + kind, [cs.country.name_ru], cs.country.id)
		if cs.unrest > 0.0:
			var k := decay + rep_decay * cs.repression / 100.0
			if cs.timed.has("supported") and cs.active("supported", sim.week):
				k *= supported_mult
			cs.unrest = maxf(cs.unrest - cs.unrest * k, 0.0)
			if cs.unrest < 0.5:
				cs.unrest = 0.0


static func _flare_kind(sim: SimWorld, cs: CountryState, phase_id: String) -> String:
	var kinds: PackedStringArray = [KIND_STRIKE]
	if phase_id == "overheat":
		kinds.append(KIND_PRICES)
	if cs.unemployment >= 12.0:
		kinds.append(KIND_UNEMPLOYED)
	if cs.peasant_share >= 0.25:
		kinds.append(KIND_PEASANTS)
	return kinds[sim.rng.randi_range(0, kinds.size() - 1)]


## Пузырьки солидарности: шанс растёт с охватом движения, место — пропорционально его силе.
static func spawn_solidarity(sim: SimWorld) -> void:
	var d := sim.data
	if count(sim, SOLIDARITY) >= int(d.num("bubbles.max_solidarity")):
		return
	var reach := 0.0
	for cs in sim.countries:
		if not cs.is_revolutionary() and cs.influence > 0.0:
			reach += cs.influence * cs.size
	if reach <= 0.0:
		return
	var chance := minf(d.num("bubbles.solidarity_chance") + d.num("bubbles.solidarity_per_reach") * sqrt(reach),
		d.num("bubbles.solidarity_max_chance"))
	if sim.rng.randf() >= chance:
		return
	var pick := sim.rng.randf() * reach
	var target: CountryState = null
	for cs in sim.countries:
		if cs.is_revolutionary() or cs.influence <= 0.0:
			continue
		pick -= cs.influence * cs.size
		target = cs
		if pick <= 0.0:
			break
	var value := float(sim.rng.randi_range(int(d.num("bubbles.solidarity_min")), int(d.num("bubbles.solidarity_max"))))
	sim.add_bubble(SOLIDARITY, target.country.id, int(d.num("bubbles.solidarity_weeks")), value)


## Пузырьки, время которых вышло. Неподдержанный протест подавляют — если только местная
## организация не возглавит его сама.
static func expire(sim: SimWorld) -> void:
	var i := 0
	while i < sim.bubbles.size():
		var b: Dictionary = sim.bubbles[i]
		if int(b["expires"]) > sim.week:
			i += 1
			continue
		sim.bubbles.remove_at(i)
		if b["kind"] == PROTEST:
			var cs := sim.state_of(b["country"])
			if cs != null and not cs.is_revolutionary():
				_resolve_unsupported(sim, cs)


static func _resolve_unsupported(sim: SimWorld, cs: CountryState) -> void:
	var d := sim.data
	var auto := 0.0
	if cs.influence > 0.0:
		auto = clampf(cs.organization / 100.0 * (1.0 + sim.mod("auto_support")), 0.0, 0.9)
	if sim.rng.randf() < auto:
		support(sim, cs, d.num("unrest.auto_support_mult"))
		sim.add_news("NEWS_AUTO_SUPPORTED", [cs.country.name_ru], cs.country.id)
		return
	cs.set_field("repression", cs.repression + d.num("unrest.suppress_repression"))
	cs.unrest *= d.num("unrest.suppress_unrest_mult")
	cs.set_field("influence", cs.influence * d.num("unrest.suppress_influence_mult"))
	sim.protests_suppressed += 1
	sim.add_news("NEWS_SUPPRESSED", [cs.country.name_ru], cs.country.id)


## Партия поддерживает стихийный протест: движение закрепляется в стране. k — доля эффекта.
static func support(sim: SimWorld, cs: CountryState, k: float = 1.0) -> void:
	var d := sim.data
	var was_present := cs.influence > 0.0
	var gain := k * (d.num("unrest.support_influence") + d.num("unrest.support_influence_per_unrest") * cs.unrest)
	cs.set_field("influence", cs.influence + gain)
	cs.set_field("organization", cs.organization + k * d.num("unrest.support_organization"))
	cs.set_field("consciousness", cs.consciousness + k * d.num("unrest.support_consciousness"))
	cs.cadres = minf(cs.cadres + k * d.num("unrest.support_cadres"), maxf(cs.cadre_cap(sim), cs.cadres))
	cs.timed["supported"] = sim.week + int(d.num("unrest.supported_weeks"))
	sim.protests_supported += 1
	if not was_present and not cs.has_flag("reached"):
		cs.flags["reached"] = true
		sim.add_news("NEWS_FOOTHOLD", [cs.country.name_ru], cs.country.id)


## Игрок коснулся пузырька. Возвращает {"ok", "kind", "value", "country"}.
static func collect(sim: SimWorld, id: int) -> Dictionary:
	for i in sim.bubbles.size():
		var b: Dictionary = sim.bubbles[i]
		if int(b["id"]) != id:
			continue
		sim.bubbles.remove_at(i)
		var value := float(b["value"]) * maxf(1.0 + sim.mod("bubble_value"), 0.0)
		sim.solidarity += value
		sim.solidarity_earned += value
		sim.bubbles_collected += 1
		if b["kind"] == PROTEST:
			var cs := sim.state_of(b["country"])
			if cs != null and not cs.is_revolutionary():
				support(sim, cs)
				sim.add_news("NEWS_SUPPORTED", [cs.country.name_ru], cs.country.id)
		return {"ok": true, "kind": b["kind"], "value": value, "country": b["country"]}
	return {"ok": false, "kind": "", "value": 0.0, "country": ""}


static func count(sim: SimWorld, kind: String) -> int:
	var n := 0
	for b in sim.bubbles:
		if b["kind"] == kind:
			n += 1
	return n


static func has_bubble(sim: SimWorld, country_id: String, kind: String) -> bool:
	for b in sim.bubbles:
		if b["kind"] == kind and b["country"] == country_id:
			return true
	return false
