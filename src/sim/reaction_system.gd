class_name ReactionSystem
extends RefCounted
## Реакция — мировая шкала координации правящих классов (0–100). Растёт от заметности
## движения, особенно в ядре; её финансирует крупная буржуазия ядра. Пороги открывают ответные меры.

const THRESHOLDS: PackedInt32Array = [20, 40, 60, 80, 100]


static func update(sim: SimWorld) -> void:
	var d := sim.data
	var weighted := 0.0
	var weight := 0.0
	var core_capitalist := 0.0
	var revolutionary := 0
	var core_weight := d.num("reaction.core_weight")
	for cs in sim.countries:
		if cs.is_revolutionary():
			revolutionary += 1
			continue
		var w := d.gdp_share[cs.index] * (core_weight if cs.is_core else 1.0)
		weighted += cs.visibility * w
		weight += w
		if cs.is_core:
			core_capitalist += d.gdp_share[cs.index]
	var visibility := weighted / maxf(weight, 1e-9)
	# Чем меньше в ядре осталось капиталистических стран, тем меньше у Реакции денег.
	var funding := core_capitalist / maxf(sim.initial_core_share, 1e-9)
	var floor_value := d.num("reaction.floor_per_revolution") * revolutionary
	# Поддержка освободительных движений пугает капитал ядра: Реакция растёт быстрее.
	var growth := d.num("reaction.visibility") * (1.0 + sim.mod("core_visibility"))
	var delta := growth * visibility * funding - d.num("reaction.decay") * maxf(sim.reaction - floor_value, 0.0)
	set_reaction(sim, sim.reaction + delta)
	_ongoing_measures(sim)


static func add(sim: SimWorld, amount: float) -> void:
	set_reaction(sim, sim.reaction + amount)


static func set_reaction(sim: SimWorld, value: float) -> void:
	var old := sim.reaction
	sim.reaction = clampf(value, 0.0, 100.0)
	for t in THRESHOLDS:
		if old < t and sim.reaction >= t:
			_on_threshold(sim, t)


static func _on_threshold(sim: SimWorld, threshold: int) -> void:
	var d := sim.data
	var first := not sim.reaction_reached.has(threshold)
	sim.reaction_reached[threshold] = true
	match threshold:
		40:
			if first:
				var add := d.num("reaction.ideology_campaign_hegemony")
				for cs in sim.countries:
					if not cs.is_revolutionary():
						cs.set_field("hegemony", cs.hegemony + add)
		100:
			_white_terror(sim)
			return
	sim.add_news("NEWS_REACTION_%d" % threshold, [], "", true)


## «Белый террор»: волна репрессий, организованность везде вдвое ниже, шкала откатывается.
static func _white_terror(sim: SimWorld) -> void:
	var d := sim.data
	var mult := d.num("reaction.white_terror_organization_mult")
	var cadre_mult := d.num("cadres.white_terror_mult")
	for cs in sim.countries:
		if not cs.is_revolutionary():
			cs.set_field("organization", cs.organization * mult)
			cs.cadres *= cadre_mult
	sim.white_terror_count += 1
	sim.last_white_terror_week = sim.week
	sim.reaction = d.num("reaction.white_terror_rollback")
	sim.add_news("NEWS_REACTION_100", [], "", true)


## Меры, которые действуют, пока Реакция выше порога.
static func _ongoing_measures(sim: SimWorld) -> void:
	var d := sim.data
	if sim.reaction < 20.0:
		return
	# Координация полиций: аресты лидеров-эмигрантов там, где движение на виду.
	# Юридическая служба делает аресты реже, контрразведка — мягче.
	var chance := d.num("reaction.police_coordination_chance") * maxf(1.0 + sim.mod("arrests"), 0.0)
	var min_vis := d.num("reaction.police_coordination_min_visibility")
	var damage := maxf(1.0 + sim.mod("arrest_damage"), 0.0)
	var org_hit := d.num("reaction.police_coordination_organization") * damage
	var cadre_keep := 1.0 - (1.0 - d.num("reaction.police_coordination_cadres_mult")) * damage
	for cs in sim.countries:
		if cs.is_revolutionary() or cs.visibility < min_vis:
			continue
		if sim.rng.randf() < chance:
			cs.set_field("organization", cs.organization + org_hit)
			cs.cadres *= clampf(cadre_keep, 0.0, 1.0)
			sim.add_news("NEWS_POLICE_ARRESTS", [cs.country.name_ru], cs.country.id)
