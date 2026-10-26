extends GutTest
## Этап 6: звуки и музыка на месте (песни — в меню, сражении и победе), слои мировой темы синхронны,
## музыка меняется с обстановкой, подсказки обучения идут по порядку, картинки подхватываются, когда они есть.

const SOUNDS: PackedStringArray = ["click", "stamp", "telegraph", "page", "bubble", "alert", "fail", "drum_hit",
	"drum_roll", "crowd_loop", "crowd_roar", "factory_whistle", "bell"]
const MUSIC: PackedStringArray = ["menu", "world_calm", "world_tension", "battle", "victory", "anthem", "defeat"]
const SOUND_SCRIPT := preload("res://src/audio/sound.gd")

var data: GameData


func before_all() -> void:
	data = GameData.load_default()


func test_every_sound_and_theme_exists() -> void:
	for id in SOUNDS:
		var found := ResourceLoader.exists("res://assets/sounds/%s.wav" % id) or ResourceLoader.exists("res://assets/sounds/%s.ogg" % id)
		assert_true(found, "звук %s есть" % id)
	for id in MUSIC:
		assert_true(ResourceLoader.exists("res://assets/music/%s.ogg" % id), "тема %s есть" % id)


func test_world_layers_have_same_length() -> void:
	var calm: AudioStream = load("res://assets/music/world_calm.ogg")
	var tension: AudioStream = load("res://assets/music/world_tension.ogg")
	assert_almost_eq(calm.get_length(), tension.get_length(), 0.1, "слой напряжения звучит в лад со спокойной темой")
	assert_gt(calm.get_length(), 60.0, "петля не короче минуты")
	assert_lt(load("res://assets/music/victory.ogg").get_length(), 30.0, "тема победы короткая")
	assert_gt(load("res://assets/music/anthem.ogg").get_length(), 30.0, "в финале — весь припев")


func _sound() -> Node:
	var node: Node = SOUND_SCRIPT.new()
	add_child_autofree(node)
	node.music_on = true
	return node


func _run(node: Node, seconds: float) -> void:
	for i in int(seconds * 20.0):
		node._process(0.05)


func test_music_follows_the_situation() -> void:
	var node := _sound()
	node.set_theme("world")
	_run(node, 3.0)
	assert_almost_eq(float(node._level["world_calm"]), 1.0, 0.01, "на карте мира — спокойная тема")
	assert_almost_eq(float(node._level.get("world_tension", 0.0)), 0.0, 0.01, "напряжения пока нет")
	node.set_tension(true)
	_run(node, 3.0)
	assert_almost_eq(float(node._level["world_tension"]), 1.0, 0.01, "Реакция или окно революции — слой напряжения")
	node.set_theme("battle")
	_run(node, 3.0)
	assert_almost_eq(float(node._level["battle"]), 1.0, 0.01, "в сражении — боевая тема")
	assert_almost_eq(float(node._level["world_calm"]), 0.0, 0.01, "мировая тема стихла")
	node.set_music(false)
	_run(node, 3.0)
	assert_almost_eq(float(node._level["battle"]), 0.0, 0.01, "музыку можно выключить")


func test_tension_rule() -> void:
	var sim := SimWorld.new_game(data, 901, "FRA", "vanguard")
	assert_false(Audio.tense(sim), "в начале партии спокойно")
	sim.reaction = 65.0
	assert_true(Audio.tense(sim), "Реакция выше 60 — напряжение")
	sim.reaction = 10.0
	var cs := sim.state_of("FRA")
	cs.window_left = 10
	cs.influence = 20.0
	assert_true(Audio.tense(sim), "открыто окно революции — напряжение")


func test_tutorial_goes_step_by_step() -> void:
	var sim := SimWorld.new_game(data, 902, "FRA", "vanguard")
	var tut := Tutorial.new()
	tut.enabled = true
	tut.shown.clear()
	assert_eq(tut.next_step(sim), "", "до первой недели подсказок нет")
	sim.week = 1
	assert_eq(tut.next_step(sim), "start")
	tut.shown["start"] = true
	sim.add_bubble(UnrestSystem.SOLIDARITY, "FRA", 10, 1.0)
	assert_eq(tut.next_step(sim), "bubble", "появился пузырёк — подсказка о нём")
	tut.shown["bubble"] = true
	sim.solidarity = 100.0
	assert_eq(tut.next_step(sim), "upgrade", "хватает солидарности — подсказка о развитии")
	tut.enabled = false
	assert_eq(tut.next_step(sim), "", "подсказки можно выключить")


func test_art_falls_back_to_stubs() -> void:
	assert_null(ArtLibrary.texture("ev_no_such_picture"), "картинки нет — заглушка")
	assert_null(ArtLibrary.view("ev_no_such_picture", Vector2(10, 10)))
	assert_eq(ArtLibrary.ALIASES.get("card_factory_strike"), "card_strike_factory", "у стачки карточка из ART_LIST.md")
