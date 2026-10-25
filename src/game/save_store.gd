class_name SaveStore
extends RefCounted
## Автосохранение партии в JSON в папке пользователя (user://).

const AUTOSAVE_PATH := "user://autosave.json"


static func has_autosave() -> bool:
	return FileAccess.file_exists(AUTOSAVE_PATH)


static func save(sim: SimWorld, path: String = AUTOSAVE_PATH) -> bool:
	var tmp := path + ".tmp"
	var file := FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		push_warning("Не удалось сохранить партию: %s" % error_string(FileAccess.get_open_error()))
		return false
	file.store_string(JSON.stringify(sim.to_dict(), "", false, true))
	file.close()
	# Сначала пишем во временный файл: если приложение закроют посреди записи, старое сохранение уцелеет.
	return DirAccess.rename_absolute(tmp, path) == OK


static func load_game(data: GameData, path: String = AUTOSAVE_PATH) -> SimWorld:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		return null
	return SimWorld.from_dict(data, parsed)


static func delete_autosave() -> void:
	if has_autosave():
		DirAccess.remove_absolute(AUTOSAVE_PATH)
