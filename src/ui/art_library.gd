class_name ArtLibrary
extends RefCounted
## Иллюстрации из assets/art — их делает tools/process_art.py из картинок, загруженных в art/incoming.
## Пока картинки нет, texture() возвращает null, и экран рисует процедурную заглушку.

const DIR := "res://assets/art/"
## Карточки, у которых в ART_LIST.md другое имя, чем у действия.
const ALIASES := {"card_factory_strike": "card_strike_factory", "card_officers_talks": "card_officer_talks",
	"card_solidarity_strike": "card_solidarity_strikes"}

static var _cache: Dictionary[String, Texture2D] = {}
static var _missing: Dictionary[String, bool] = {}


static func texture(id: String) -> Texture2D:
	id = ALIASES.get(id, id)
	if _cache.has(id):
		return _cache[id]
	if _missing.has(id):
		return null
	var path := DIR + id + ".webp"
	if not ResourceLoader.exists(path):
		_missing[id] = true
		return null
	var t: Texture2D = load(path)
	_cache[id] = t
	return t


static func has(id: String) -> bool:
	return texture(id) != null


## Картинка, заполняющая прямоугольник size (лишнее по краям обрезается); null — картинки нет.
static func view(id: String, size: Vector2) -> Control:
	var t := texture(id)
	if t == null:
		return null
	var r := TextureRect.new()
	r.texture = t
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	r.custom_minimum_size = size
	r.clip_contents = true
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r
