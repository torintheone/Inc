extends SceneTree

const Batch := preload("res://tools/battle_batch.gd")
## Ход одного сражения по неделям: godot --headless --script res://tools/battle_trace.gd -- <страна> <стратегия> [seed] [путь=значение …]
## Печатает регионы под контролем, силы, верность армии и ресурсы — для настройки data/battle.json.

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var id := args[0] if args.size() > 0 else "FRA"
	var strategy := args[1] if args.size() > 1 else "storm"
	var seed := int(args[2]) if args.size() > 2 else 100
	var data := GameData.load_default()
	var sim := SimWorld.new_game(data, seed, id, "mass_party")
	var cs := Batch.prepare(sim, id)
	var b := BattleSystem.start(sim, cs)
	print("%s regions=%d max_days=%d agitators=%d squads=%.0f gov=%.0f police=%.0f reserve=%.0f loyalty=%.0f" % [id,
		b.region_count(), b.max_days, b.agitators, b.squads_pool, _sum(b.gov), _sum(b.police), b.reserve, b.army_loyalty()])
	var last_log := 0
	while not b.is_over():
		BattleBot.play_day(sim, b, strategy)
		BattleSystem.step_day(sim, b)
		if b.day % 7 == 0 or b.is_over():
			var counts := [0, 0, 0]
			for c in b.control:
				counts[c] += 1
			var cap := b.capital()
			print("d%3d P/C/R=%d/%d/%d share=%.2f fact=%.2f squads=%.0f(pool %.0f) gov=%.0f pol=%.0f res=%.0f loy=%.0f cap[s%.0f g%.0f p%.0f q%.0f l%.0f] sup=%.0f ag=%d supl=%.0f w=%.0f trust=%.0f" % [b.day,
				counts[0], counts[1], counts[2], b.control_share(), b.factory_share(), b.squads_total(), b.squads_pool,
				_sum(b.gov), _sum(b.police), b.reserve, b.army_loyalty(), b.support[cap], b.gov[cap], b.police[cap],
				b.squads[cap], b.loyalty[cap], _avg(b.support), b.agitators, b.supplies, b.weapons, b.trust])
			var events := []
			for k in range(last_log, b.log.size()):
				var item: Dictionary = b.log[k]
				var key: String = item["key"]
				if not key.ends_with("_OK") and not key.ends_with("_FAIL") and key != "BATTLE_LOG_PROPAGANDA" and key != "BATTLE_LOG_TRANSFER":
					events.append(key.trim_prefix("BATTLE_LOG_") + str(item["args"]) if not item["args"].is_empty() else key.trim_prefix("BATTLE_LOG_"))
			last_log = b.log.size()
			if not events.is_empty():
				print("      ", ", ".join(events))
	print("ИТОГ: ", b.outcome, "/", b.outcome_reason, " день ", b.day)
	quit()


func _sum(a: PackedFloat64Array) -> float:
	var s := 0.0
	for v in a:
		s += v
	return s


func _avg(a: PackedFloat64Array) -> float:
	return _sum(a) / maxf(a.size(), 1)
