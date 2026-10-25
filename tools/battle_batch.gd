extends SceneTree
## Пакет сражений для настройки: godot --headless --script res://tools/battle_batch.gd -- <страны через запятую> <стратегия> [игр] [профиль] [штраф]
## Для каждой страны готовит движение, способное поднять восстание (профиль weak/ready/strong), и разыгрывает сражение ботом.

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var ids := (args[0] if args.size() > 0 else "FRA,BRA,IND,NGA,DEU,USA,EGY,IDN").split(",")
	var strategy := args[1] if args.size() > 1 else "storm"
	var games := int(args[2]) if args.size() > 2 else 4
	var profile := args[3] if args.size() > 3 else "ready"
	var penalty := float(args[4]) if args.size() > 4 else 0.0
	var data := GameData.load_default()
	var all_days := []
	var total := {}
	for id in ids:
		var days := []
		var outcomes := {}
		for g in games:
			var sim := SimWorld.new_game(data, 100 + g, id, "mass_party")
			var cs := prepare(sim, id, profile)
			var b := BattleSystem.start(sim, cs, penalty)
			if b == null:
				print(id, ": нет карты")
				break
			BattleBot.run(sim, b, strategy)
			days.append(b.day)
			all_days.append(b.day)
			var key: String = b.outcome + "/" + b.outcome_reason
			outcomes[key] = outcomes.get(key, 0) + 1
			total[key] = total.get(key, 0) + 1
		if games > 2:
			print(id, " ", strategy, " days=", days, " ", outcomes)
	all_days.sort()
	var q := func(f: float) -> int: return all_days[int(f * (all_days.size() - 1))] if not all_days.is_empty() else 0
	var wins := 0
	for k: String in total:
		if k.begins_with("victory"):
			wins += total[k]
	print("ВСЕГО %s %s: побед %d%% %s дни 10/50/90%%: %d/%d/%d" % [profile, strategy, roundi(100.0 * wins / maxf(all_days.size(), 1)),
		total, q.call(0.1), q.call(0.5), q.call(0.9)])
	quit()


## Страна, готовая к восстанию: как в партии в момент, когда открыто окно и хватает организации.
static func prepare(sim: SimWorld, id: String, profile: String = "ready") -> CountryState:
	sim.solidarity = 25.0
	var cs := sim.state_of(id)
	match profile:
		"weak":
			cs.influence = 12.0
			cs.organization = 50.0
			cs.rev_situation = 70.0
		"strong":
			cs.influence = 50.0
			cs.organization = 80.0
			cs.rev_situation = 95.0
		_:
			cs.influence = 30.0
			cs.organization = 60.0
			cs.rev_situation = 80.0
	cs.cadres = 12.0
	cs.window_left = 12
	return cs
