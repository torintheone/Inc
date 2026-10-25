extends GutTest
## Камера карты: карта не уезжает с экрана, масштаб держится в пределах.

const BOUNDS := Rect2(-2000, -1000, 4000, 1700)
const VIEW := Vector2(1600, 720)


func test_clamp_keeps_view_inside_map() -> void:
	var zoom := 2.0
	var far := MapCamera.clamp_position(Vector2(10000, 10000), zoom, VIEW, BOUNDS)
	var half := VIEW * 0.5 / zoom
	assert_almost_eq(far.x, BOUNDS.end.x - half.x, 0.01)
	assert_almost_eq(far.y, BOUNDS.end.y - half.y, 0.01)
	var near := MapCamera.clamp_position(Vector2(-10000, -10000), zoom, VIEW, BOUNDS)
	assert_almost_eq(near.x, BOUNDS.position.x + half.x, 0.01)
	assert_almost_eq(near.y, BOUNDS.position.y + half.y, 0.01)


func test_small_map_is_centered() -> void:
	var zoom := 0.1   # карта целиком меньше экрана
	var pos := MapCamera.clamp_position(Vector2(500, -300), zoom, VIEW, BOUNDS)
	assert_almost_eq(pos.x, BOUNDS.get_center().x, 0.01)
	assert_almost_eq(pos.y, BOUNDS.get_center().y, 0.01)


func test_zoom_limits_and_zoom_at_keeps_point() -> void:
	var cam := MapCamera.new()
	cam.map_bounds = BOUNDS
	add_child_autofree(cam)
	cam.fit_whole_map()
	assert_almost_eq(cam.zoom_level(), cam.min_zoom(), 0.0001, "старт — вся карта")
	cam.zoom_at(Vector2.ZERO, 0.5)
	assert_almost_eq(cam.zoom_level(), cam.min_zoom(), 0.0001, "дальше всей карты не отдалить")
	for i in 40:
		cam.zoom_at(Vector2.ZERO, 1.5)
	assert_almost_eq(cam.zoom_level(), cam.max_zoom(), 0.0001, "ближе предела не приблизить")

	cam.fit_whole_map()
	cam.zoom_at(cam.get_viewport_rect().size * 0.5, 3.0)
	var screen := cam.get_viewport_rect().size * 0.5 + Vector2(40, 20)
	var before := cam.screen_to_world(screen)
	cam.zoom_at(screen, 1.3)
	assert_almost_eq(cam.screen_to_world(screen).distance_to(before), 0.0, 0.01,
		"точка под пальцами остаётся на месте")
