class_name Audio
extends RefCounted
## Звук из любого места кода: обращается к узлу /root/Sound (автозагрузка, src/audio/sound.gd).
## Если узла нет — в тестах и безголовых прогонах — просто тишина.


## Нужен ли слой напряжения в музыке: Реакция выше 60 или где-то открыто окно революции.
static func tense(sim: SimWorld) -> bool:
	if sim.reaction > 60.0:
		return true
	for cs in sim.countries:
		if cs.window_left >= 0 and cs.influence >= 10.0 and not cs.is_revolutionary():
			return true
	return false


static func _node() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("Sound") if tree != null and tree.root != null else null


static func play(id: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	var n := _node()
	if n != null:
		n.play(id, volume_db, pitch)


static func set_theme(theme: String) -> void:
	var n := _node()
	if n != null:
		n.set_theme(theme)


static func set_tension(on: bool) -> void:
	var n := _node()
	if n != null:
		n.set_tension(on)


static func sting(id: String) -> void:
	var n := _node()
	if n != null:
		n.sting(id)


static func crowd(on: bool) -> void:
	var n := _node()
	if n != null:
		n.crowd(on)


static func sfx_on() -> bool:
	var n := _node()
	return n.sfx_on if n != null else false


static func music_on() -> bool:
	var n := _node()
	return n.music_on if n != null else false


static func set_sfx(on: bool) -> void:
	var n := _node()
	if n != null:
		n.set_sfx(on)


static func set_music(on: bool) -> void:
	var n := _node()
	if n != null:
		n.set_music(on)
