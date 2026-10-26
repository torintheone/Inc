extends Node
## Звук и музыка (автозагрузка Sound). Короткие эффекты: щелчок, печать, телеграф, толпа, гудок,
## барабаны, колокол. Музыка меняется с обстановкой: меню («Смело, товарищи, в ногу»), мировая карта
## (и слой напряжения поверх неё — звучит синхронно), сражение («Варшавянка»); темы победы
## («Интернационал») и поражения приглушают остальное.
## Звук и музыку можно выключить; выбор хранится в user://settings.cfg.

const SETTINGS_PATH := "user://settings.cfg"
const SFX_PLAYERS := 8
## Секунд на плавный переход громкости музыки.
const FADE_SECONDS := 1.6
const MUSIC_DB := -4.0
const DUCK := 0.25
## Громкость эффектов по умолчанию, дБ: щелчок тихий, гудок и толпа — фоном.
const SFX_DB := {"click": -12.0, "telegraph": -14.0, "page": -10.0, "crowd_roar": -6.0, "factory_whistle": -6.0,
	"bubble": -4.0, "bell": -3.0}
const THEMES := {"menu": ["menu"], "world": ["world_calm", "world_tension"], "battle": ["battle"]}

var sfx_on := true
var music_on := true

var _sfx: Array[AudioStreamPlayer] = []
var _next := 0
var _cache: Dictionary[String, AudioStream] = {}
var _crowd: AudioStreamPlayer
var _music: Dictionary[String, AudioStreamPlayer] = {}
var _level: Dictionary[String, float] = {}
var _theme := ""
var _tension := false
var _sting: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_settings()
	for i in SFX_PLAYERS:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_sfx.append(p)
	_crowd = AudioStreamPlayer.new()
	_crowd.volume_db = -14.0
	add_child(_crowd)
	_sting = AudioStreamPlayer.new()
	_sting.volume_db = MUSIC_DB
	add_child(_sting)
	# Щелчок на любой кнопке интерфейса.
	get_tree().node_added.connect(func(node: Node) -> void:
		if node is BaseButton:
			(node as BaseButton).pressed.connect(func() -> void: play("click")))


# --- Эффекты -------------------------------------------------------------------

func play(id: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if not sfx_on:
		return
	var stream := _stream("res://assets/sounds/" + id)
	if stream == null:
		return
	var p := _sfx[_next]
	_next = (_next + 1) % _sfx.size()
	p.stream = stream
	p.volume_db = volume_db + float(SFX_DB.get(id, 0.0))
	p.pitch_scale = pitch
	p.play()


## Гул толпы фоном (демонстрации, восстание).
func crowd(on: bool) -> void:
	if on and sfx_on:
		if not _crowd.playing:
			_crowd.stream = _stream("res://assets/sounds/crowd_loop", true)
			_crowd.play()
	else:
		_crowd.stop()


# --- Музыка --------------------------------------------------------------------

## "menu", "world", "battle" или "" — тишина.
func set_theme(theme: String) -> void:
	if theme == _theme:
		return
	_theme = theme
	# Слои мировой темы начинаются вместе, чтобы звучать в лад.
	if theme == "world":
		for name: String in THEMES["world"]:
			var p := _player(name)
			if not p.playing:
				p.play()
		_player("world_tension").seek(_player("world_calm").get_playback_position())


func theme() -> String:
	return _theme


## Слой напряжения: Реакция выше 60 или открыто окно революции.
func set_tension(on: bool) -> void:
	_tension = on


## Тема поверх приглушённой музыки: "victory", "defeat" или "anthem" (финал выигранной партии).
func sting(id: String) -> void:
	if not music_on:
		return
	_sting.stream = _stream("res://assets/music/" + id)
	_sting.play()


func set_sfx(on: bool) -> void:
	sfx_on = on
	if not on:
		_crowd.stop()
	_save_settings()


func set_music(on: bool) -> void:
	music_on = on
	if not on:
		_sting.stop()
	_save_settings()


func _process(delta: float) -> void:
	var duck := DUCK if _sting.playing else 1.0
	var step := delta / FADE_SECONDS
	for name: String in ["menu", "world_calm", "world_tension", "battle"]:
		var target := 0.0
		if music_on and name in THEMES.get(_theme, []):
			target = 0.0 if name == "world_tension" and not _tension else 1.0
		target *= duck
		var level: float = _level.get(name, 0.0)
		level = move_toward(level, target, step)
		_level[name] = level
		if level <= 0.0 and target <= 0.0:
			if _music.has(name) and _music[name].playing:
				# Слои мировой темы не останавливаются, а молчат: так они не расходятся.
				if _theme == "world" and name.begins_with("world"):
					_music[name].volume_db = -80.0
				else:
					_music[name].stop()
			continue
		var p := _player(name)
		if not p.playing:
			p.play()
		p.volume_db = MUSIC_DB + linear_to_db(maxf(level, 0.0001))


func _player(name: String) -> AudioStreamPlayer:
	if not _music.has(name):
		var p := AudioStreamPlayer.new()
		p.stream = _stream("res://assets/music/" + name, true)
		p.volume_db = -80.0
		add_child(p)
		_music[name] = p
	return _music[name]


## Поток по пути без расширения: сначала .ogg, потом .wav. loop — зациклить.
func _stream(base: String, loop: bool = false) -> AudioStream:
	var key := base + ("#loop" if loop else "")
	if _cache.has(key):
		return _cache[key]
	var stream: AudioStream = null
	for ext in [".ogg", ".wav"]:
		if ResourceLoader.exists(base + ext):
			stream = load(base + ext)
			break
	if stream == null:
		return null
	if loop:
		stream = stream.duplicate()
		if stream is AudioStreamOggVorbis:
			(stream as AudioStreamOggVorbis).loop = true
		elif stream is AudioStreamWAV:
			var wav := stream as AudioStreamWAV
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
			wav.loop_end = int(wav.get_length() * wav.mix_rate)
	_cache[key] = stream
	return stream


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		sfx_on = bool(cfg.get_value("audio", "sfx", true))
		music_on = bool(cfg.get_value("audio", "music", true))


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("audio", "sfx", sfx_on)
	cfg.set_value("audio", "music", music_on)
	cfg.save(SETTINGS_PATH)
