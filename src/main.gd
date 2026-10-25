extends Node2D
## Точка входа: загружает мир, собирает карту, камеру и интерфейс.

## Допуск попадания по стране, в пикселях экрана: помогает с маленькими островами.
const TAP_TOLERANCE_PX := 12.0

var world: WorldData
var map: WorldMap
var camera: MapCamera
var hud: Hud


func _ready() -> void:
	TranslationServer.set_locale("ru")
	RenderingServer.set_default_clear_color(MapPalette.OCEAN)
	world = WorldData.load_default()
	if world == null:
		push_error("Данные мира не загружены: проверьте data/world.json и data/world_shapes.json")
		return

	map = WorldMap.new()
	map.setup(world)
	add_child(map)

	camera = MapCamera.new()
	camera.map_bounds = world.bounds.grow(40.0)
	add_child(camera)
	camera.make_current()
	camera.fit_whole_map()

	hud = Hud.new()
	add_child(hud)
	hud.setup(world)
	camera.ui_blockers.append(hud.panel)

	camera.tapped.connect(_on_map_tapped)
	camera.zoom_changed.connect(map.on_zoom_changed)
	hud.panel.close_requested.connect(_deselect)
	map.on_zoom_changed(camera.zoom_level())


func _on_map_tapped(world_pos: Vector2) -> void:
	var c := world.country_at(world_pos, TAP_TOLERANCE_PX / camera.zoom_level())
	if c == null:
		_deselect()
		return
	map.select(c)
	hud.show_country(c)


func _deselect() -> void:
	map.select(null)
	hud.hide_country()
