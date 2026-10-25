extends SceneTree
## Новое общество по годам: godot --headless --script res://tools/society_trace.gd -- <страна> <линия> [других революций] [лет]
## Делает страну революционной (и, если надо, ещё несколько стран) и печатает показатели раз в год.

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var id := args[0] if args.size() > 0 else "FRA"
	var line := args[1] if args.size() > 1 else "vanguard"
	var others := int(args[2]) if args.size() > 2 else 0
	var years := int(args[3]) if args.size() > 3 else 6
	var data := GameData.load_default()
	var sim := SimWorld.new_game(data, 42, id, line)
	var cs := sim.state_of(id)
	sim.make_revolutionary(cs)
	var added := 0
	for c in sim.countries:
		if added >= others:
			break
		if c != cs and c.country.zone != "core" and c.country.indicator("population") > 2e7:
			sim.make_revolutionary(c)
			added += 1
	print("%s %s, других революций %d: %s" % [id, line, added, cs.policies])
	for y in years + 1:
		print("год %d: демократия %.0f бюрократия %.0f (цель %.0f) еда %.0f производство %.0f оборона %.0f поддержка %.0f реакция %.0f%s" % [y,
			cs.democracy, cs.bureaucracy, NewSociety.bureaucracy_target(sim, cs), cs.food, cs.production, cs.defense, cs.support,
			sim.reaction, " ТЕРМИДОР" if NewSociety.is_thermidor(cs) else ("" if cs.is_revolutionary() else " ПАЛА")])
		sim.run_weeks(52)
	quit()
