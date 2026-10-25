class_name MovementSystem
extends RefCounted
## Надстройка и движение: гегемония и легитимность власти, рост и распространение
## влияния, сознание и организованность рабочих, революционная ситуация.
## Каждая функция обходит все страны сразу и читает параметры баланса один раз за шаг.


## Восприимчивость к идеям движения = нужда × (1 − гегемония).
static func susceptibility(cs: CountryState) -> float:
	return cs.need / 100.0 * (1.0 - cs.hegemony / 100.0)


## Неделя надстройки в капиталистических странах: показатели тянутся к уровням,
## которые задают зона мир-системы, фаза цикла и Реакция.
static func update_superstructure(sim: SimWorld, phase: Dictionary) -> void:
	var d := sim.data
	var speed := d.num("superstructure.speed")
	var slump := EconomySystem.is_slump(phase["id"])
	var depth := sim.depth if slump else 1.0
	var ph_heg := float(phase["hegemony"]) * depth
	var ph_leg := float(phase["legitimacy"]) * depth
	var ph_split := float(phase["elite_split"]) * depth
	var heg_arist := d.num("imperialism.hegemony_bonus")
	var leg_arist := d.num("imperialism.legitimacy_bonus")
	var heg_campaign := d.num("superstructure.hegemony_ideology_campaign") if sim.reaction >= 40.0 else 0.0
	var heg_erosion := sim.mod("hegemony_erosion")
	var rep_reaction := sim.reaction * d.num("superstructure.repression_per_reaction")
	var fascism := sim.reaction >= 80.0 and slump
	var fascism_rep := d.num("superstructure.fascism_repression")
	var fascism_min := d.num("superstructure.fascism_min_influence")
	var split_speed := d.num("superstructure.elite_split_speed")
	var split_infl := d.num("superstructure.elite_split_per_influence")
	var legal_reaction := sim.reaction * d.num("superstructure.legality_per_reaction")
	for cs in sim.countries:
		if cs.is_revolutionary():
			continue
		var heg := cs.zone_hegemony + ph_heg + cs.aristocracy * heg_arist + heg_campaign - heg_erosion * cs.influence
		cs.hegemony = clampf(cs.hegemony + (heg - cs.hegemony) * speed, 0.0, 100.0)
		var leg := cs.zone_legitimacy + ph_leg + cs.aristocracy * leg_arist
		cs.legitimacy = clampf(cs.legitimacy + (leg - cs.legitimacy) * speed, 0.0, 100.0)
		var rep := cs.zone_repression + rep_reaction
		if fascism and cs.influence >= fascism_min:
			rep += fascism_rep
		cs.repression = clampf(cs.repression + (rep - cs.repression) * speed, 0.0, 100.0)
		cs.army_loyalty = clampf(cs.army_loyalty + (cs.zone_army_loyalty - cs.army_loyalty) * speed, 0.0, 100.0)
		var split := ph_split + split_infl * cs.influence
		cs.elite_split = clampf(cs.elite_split + (split - cs.elite_split) * split_speed, 0.0, 100.0)
		var legal := cs.zone_legality - legal_reaction
		cs.legality = clampf(cs.legality + (legal - cs.legality) * speed, 0.0, 100.0)


## Прирост влияния в каждой стране от связей с другими странами:
## сила движения в источнике × сила связи × восприимчивость получателя.
static func compute_spread(sim: SimWorld) -> PackedFloat64Array:
	var d := sim.data
	var n := sim.countries.size()
	var strength := PackedFloat64Array()
	strength.resize(n)
	var min_source := d.num("spread.min_source_influence")
	var rev_mult := 1.0 - (d.num("reaction.intervention_spread_penalty") if sim.reaction >= 60.0 else 0.0)
	var rev_strength := d.num("spread.revolutionary_source_influence") / 100.0 \
		* (0.5 + 0.5 * d.num("spread.revolutionary_source_organization") / 100.0) * rev_mult
	var media_total := 0.0
	var any := false
	for cs in sim.countries:
		var s := 0.0
		if cs.is_revolutionary():
			s = rev_strength
		elif cs.influence >= min_source:
			s = cs.influence / 100.0 * (0.5 + 0.5 * cs.organization / 100.0)
		strength[cs.index] = s
		if s > 0.0:
			any = true
			media_total += s * cs.internet * d.gdp_share[cs.index]
	var incoming := PackedFloat64Array()
	incoming.resize(n)
	if not any:
		return incoming
	# Приток — средняя сила движения у партнёров, взвешенная по силе связей: страна с сотней
	# слабых связей получает не больше, чем страна с несколькими сильными.
	var total_w := PackedFloat64Array()
	total_w.resize(n)

	var c_trade := d.num("spread.trade") * (1.0 + sim.mod("trade_channel"))
	var c_migr := d.num("spread.migration") * (1.0 + sim.mod("migration_channel"))
	var c_neigh := d.num("spread.neighbor")
	var link_a := d.link_a
	var link_b := d.link_b
	var link_trade := d.link_trade
	var link_migr := d.link_migration
	var link_neigh := d.link_neighbor
	for i in link_a.size():
		var a := link_a[i]
		var b := link_b[i]
		var w := link_trade[i] * c_trade + link_migr[i] * c_migr + float(link_neigh[i]) * c_neigh
		total_w[a] += w
		total_w[b] += w
		incoming[b] += strength[a] * w
		incoming[a] += strength[b] * w

	var scale := d.num("spread.scale")
	var c_media := d.num("spread.media") * (1.0 + sim.mod("media_channel")) * media_total
	for cs in sim.countries:
		var i := cs.index
		incoming[i] = (scale * incoming[i] / maxf(total_w[i], 1.0) + c_media * cs.internet) * susceptibility(cs)
	return incoming


## Неделя движения во всех капиталистических странах.
static func update_movement(sim: SimWorld, incoming: PackedFloat64Array) -> void:
	var d := sim.data
	var growth_k := d.num("movement.growth") * (1.0 + sim.mod("influence_growth"))
	var c_bonus := d.num("movement.consciousness_growth_bonus")
	var seed := d.num("movement.seed")
	var org_bonus := d.num("movement.organization_growth_bonus")
	var rep_loss := d.num("movement.repression_loss") * (1.0 - sim.mod("underground"))
	var reached_at := d.num("movement.reached_influence")
	var c_rate := d.num("movement.consciousness_rate") * (1.0 + sim.mod("consciousness_rate"))
	var c_decay := d.num("movement.consciousness_decay")
	var c_floor := d.num("movement.consciousness_floor")
	var c_damp := d.num("imperialism.consciousness_damping")
	var caps := consciousness_caps(sim)
	var o_rate := d.num("movement.organization_rate") * (1.0 + sim.mod("organization_rate"))
	var o_cap := clampf(d.num("movement.organization_base_cap") + sim.mod("organization_cap"), 1.0, 100.0)
	var o_decay := d.num("movement.organization_decay")
	var o_rep := d.num("movement.organization_repression_decay")
	var v_infl := d.num("movement.visibility_per_influence")
	var v_strike := d.num("movement.visibility_per_strike")
	var v_demo := d.num("movement.visibility_per_demo")
	var v_mult := maxf(1.0 + sim.mod("visibility"), 0.1)
	var v_speed := d.num("movement.visibility_speed")
	var t_target := d.num("movement.trust_target")
	var t_speed := d.num("movement.trust_speed")
	var recent_decay := d.num("movement.recent_decay")
	for cs in sim.countries:
		if cs.is_revolutionary():
			continue
		var inc := incoming[cs.index]
		if cs.influence <= 0.0 and inc <= 0.0:
			continue
		var room := maxf(1.0 - cs.influence / cs.potential, 0.0)
		# Влияние: логистический рост внутри страны плюс приток извне, минус потери от репрессий.
		var influence := cs.influence
		if influence > 0.0:
			influence += growth_k * susceptibility(cs) * (influence + seed) * room * (1.0 + org_bonus * cs.organization / 100.0) \
				* (0.5 + c_bonus * cs.consciousness)
			influence -= influence * cs.repression / 100.0 * cs.visibility / 100.0 * rep_loss
		influence += inc * room
		cs.influence = clampf(influence, 0.0, cs.potential)
		if cs.influence >= reached_at and not cs.has_flag("reached"):
			cs.flags["reached"] = true
			sim.on_country_reached(cs)
		if cs.influence <= 0.0:
			continue

		# Сознание растёт от нужды и агитации, гаснет при сильной гегемонии и подкупе верхушки.
		var reach := minf(1.0, cs.influence / 5.0 + 0.1)
		var dc := c_rate * reach * (0.3 + cs.need / 100.0) * (1.0 - 0.8 * cs.hegemony / 100.0) * (1.0 - cs.aristocracy * c_damp) \
			- c_decay * maxf(cs.consciousness - c_floor, 0.0)
		cs.consciousness = clampf(minf(cs.consciousness + dc, consciousness_cap(caps, cs)), 0.0, 100.0)

		# Организованность растёт там, где есть влияние, до потолка, который задают профсоюзы и партия.
		var dorg := o_rate * minf(1.0, cs.influence / 3.0) * maxf(o_cap - cs.organization, 0.0) / o_cap \
			- o_decay * cs.organization - o_rep * cs.repression / 100.0 * cs.visibility / 100.0 * cs.organization
		cs.organization = clampf(cs.organization + dorg, 0.0, 100.0)

		var vis_target := (cs.influence * v_infl + cs.strikes_recent * v_strike + cs.demos_recent * v_demo) * v_mult
		cs.visibility = clampf(cs.visibility + (vis_target - cs.visibility) * v_speed, 0.0, 100.0)
		cs.trust = clampf(cs.trust + (t_target - cs.trust) * t_speed, 0.0, 100.0)
		cs.strikes_recent *= recent_decay
		cs.demos_recent *= recent_decay


## Какие стадии сознания открыты улучшениями: [стадия 1, стадия 2, стадия 3].
static func consciousness_caps(sim: SimWorld) -> Array[bool]:
	return [sim.has_unlock("consciousness_stage_1"), sim.has_unlock("consciousness_stage_2"),
		sim.has_unlock("consciousness_stage_3")]


## Потолок сознания: следующая стадия открывается не только очками, но и опытом борьбы.
static func consciousness_cap(caps: Array[bool], cs: CountryState) -> float:
	if not caps[0]:
		return 24.9
	if not (caps[1] and cs.has_flag("industry_strike_won")):
		return 49.9
	if not (caps[2] and cs.organization >= 40.0):
		return 74.9
	return 100.0


## Три условия революционной ситуации во всех странах; итог — минимум из них.
static func update_rev_situation(sim: SimWorld, phase: Dictionary) -> void:
	var d := sim.data
	var p := "revolutionary_situation."
	var top_split := d.num(p + "top_elite_split")
	var top_illeg := d.num(p + "top_illegitimacy")
	var top_bonus := float(phase.get("top_bonus", 0.0))
	var bottom_need := d.num(p + "bottom_need")
	var bottom_u := d.num(p + "bottom_unemployment")
	var bottom_u_over := d.num(p + "bottom_unemployment_over")
	var act_infl := d.num(p + "activity_influence")
	var act_cons := d.num(p + "activity_consciousness")
	var act_strikes := d.num(p + "activity_strikes")
	var act_demos := d.num(p + "activity_demos")
	var threshold := d.num(p + "threshold")
	var reset_below := d.num(p + "window_reset_below")
	for cs in sim.countries:
		if cs.is_revolutionary():
			continue
		cs.top_cant = clampf(top_split * cs.elite_split + top_illeg * (100.0 - cs.legitimacy) + top_bonus, 0.0, 100.0)
		cs.bottom_wont = clampf(bottom_need * cs.need + bottom_u * maxf(cs.unemployment - bottom_u_over, 0.0), 0.0, 100.0)
		cs.mass_activity = clampf(act_infl * cs.influence + act_cons * cs.consciousness + act_strikes * cs.strikes_recent
			+ act_demos * cs.demos_recent, 0.0, 100.0)
		cs.rev_situation = revolutionary_situation(cs.top_cant, cs.bottom_wont, cs.mass_activity)
		# Окно революции не вечно: если им не воспользоваться, верхи сплачиваются.
		if cs.rev_situation >= threshold:
			if cs.window_left < 0:
				cs.window_left = sim.rng.randi_range(int(d.num(p + "window_min_weeks")), int(d.num(p + "window_max_weeks")))
				sim.on_window_opened(cs)
			else:
				cs.window_left -= 1
				if cs.window_left == 0:
					cs.elite_split = clampf(cs.elite_split + d.num(p + "consolidation_elite_split"), 0.0, 100.0)
					cs.legitimacy = clampf(cs.legitimacy + d.num(p + "consolidation_legitimacy"), 0.0, 100.0)
					sim.add_news("NEWS_WINDOW_CLOSED", [cs.country.name_ru], cs.country.id)
		elif cs.rev_situation < reset_below:
			cs.window_left = -1


static func revolutionary_situation(top_cant: float, bottom_wont: float, mass_activity: float) -> float:
	return minf(top_cant, minf(bottom_wont, mass_activity))
