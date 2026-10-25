class_name MapCamera
extends Camera2D
## Камера карты: перетаскивание одним пальцем, щипок двумя, колесо мыши,
## инерция после броска. Короткое касание без сдвига — тап по карте.

signal tapped(world_position: Vector2)
signal zoom_changed(zoom: float)

const MAX_ZOOM_FACTOR := 14.0   ## во сколько раз можно приблизить относительно всей карты
const TAP_SLOP_PX := 14.0       ## сдвиг пальца, после которого касание уже не тап
const TAP_MAX_MSEC := 450
const WHEEL_STEP := 1.15
const INERTIA_DAMPING := 5.0
const INERTIA_MIN_SPEED := 20.0

## Границы карты в мировых координатах.
var map_bounds := Rect2(-2000, -1000, 4000, 1700)
## Элементы интерфейса поверх карты: касания по ним карта не обрабатывает.
var ui_blockers: Array[Control] = []

var _touches: Dictionary[int, Vector2] = {}
var _tap_start := Vector2.ZERO
var _tap_start_msec := 0
var _tap_moved := false
var _velocity := Vector2.ZERO
var _last_drag_msec := 0


func _ready() -> void:
	get_viewport().size_changed.connect(_on_viewport_resized)
	_on_viewport_resized()


func fit_whole_map() -> void:
	position = map_bounds.get_center()
	_set_zoom_level(min_zoom())


func min_zoom() -> float:
	var view := _view_size()
	return minf(view.x / map_bounds.size.x, view.y / map_bounds.size.y)


func max_zoom() -> float:
	return min_zoom() * MAX_ZOOM_FACTOR


func zoom_level() -> float:
	return zoom.x


func screen_to_world(screen_pos: Vector2) -> Vector2:
	return position + (screen_pos - _view_size() * 0.5) / zoom_level()


## Приблизить или отдалить так, чтобы точка под screen_pos осталась на месте.
func zoom_at(screen_pos: Vector2, factor: float) -> void:
	var before := screen_to_world(screen_pos)
	_set_zoom_level(zoom_level() * factor)
	var after := screen_to_world(screen_pos)
	position += before - after
	position = clamp_position(position, zoom_level(), _view_size(), map_bounds)


func pan_screen(delta_px: Vector2) -> void:
	position = clamp_position(position - delta_px / zoom_level(), zoom_level(), _view_size(), map_bounds)


## Центр камеры, при котором карта не уезжает с экрана. Если карта по какой-то
## оси меньше экрана, она центрируется по этой оси.
static func clamp_position(pos: Vector2, zoom_value: float, view_size: Vector2, bounds: Rect2) -> Vector2:
	var half := view_size * 0.5 / zoom_value
	var result := pos
	for axis in 2:
		var lo := bounds.position[axis] + half[axis]
		var hi := bounds.end[axis] - half[axis]
		result[axis] = bounds.get_center()[axis] if lo > hi else clampf(pos[axis], lo, hi)
	return result


func _process(delta: float) -> void:
	if _touches.is_empty() and _velocity.length() > INERTIA_MIN_SPEED:
		pan_screen(_velocity * delta)
		_velocity *= exp(-INERTIA_DAMPING * delta)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_on_touch(event)
	elif event is InputEventScreenDrag:
		_on_drag(event)
	elif event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_at(mb.position, WHEEL_STEP)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_at(mb.position, 1.0 / WHEEL_STEP)
	elif event is InputEventMagnifyGesture:
		var mg := event as InputEventMagnifyGesture
		zoom_at(mg.position, mg.factor)
	elif event is InputEventPanGesture:
		pan_screen(-(event as InputEventPanGesture).delta * 12.0)


func _on_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		if _is_over_ui(event.position):
			return
		_touches[event.index] = event.position
		_velocity = Vector2.ZERO
		if _touches.size() == 1:
			_tap_start = event.position
			_tap_start_msec = Time.get_ticks_msec()
			_tap_moved = false
		else:
			_tap_moved = true
		return
	if not _touches.has(event.index):
		return
	_touches.erase(event.index)
	if not _touches.is_empty():
		return
	var quick := Time.get_ticks_msec() - _tap_start_msec <= TAP_MAX_MSEC
	if not _tap_moved and quick:
		tapped.emit(screen_to_world(event.position))
	elif Time.get_ticks_msec() - _last_drag_msec > 80:
		_velocity = Vector2.ZERO   # палец остановился перед отрывом — без инерции


func _on_drag(event: InputEventScreenDrag) -> void:
	if not _touches.has(event.index):
		return
	var prev: Vector2 = _touches[event.index]
	_touches[event.index] = event.position
	if _touches.size() == 1:
		if not _tap_moved and event.position.distance_to(_tap_start) > TAP_SLOP_PX:
			_tap_moved = true
		if _tap_moved:
			var delta_px := event.position - prev
			pan_screen(delta_px)
			var now := Time.get_ticks_msec()
			var dt := maxf((now - _last_drag_msec) / 1000.0, 1.0 / 120.0)
			_velocity = _velocity.lerp(delta_px / dt, 0.4) if now - _last_drag_msec < 100 else delta_px / dt
			_last_drag_msec = now
		return
	# Щипок: берём два первых пальца.
	var keys := _touches.keys()
	var other_index: int = keys[0] if keys[0] != event.index else keys[1]
	var other: Vector2 = _touches[other_index]
	var old_mid := (prev + other) * 0.5
	var new_mid := (event.position + other) * 0.5
	var old_dist := prev.distance_to(other)
	var new_dist := event.position.distance_to(other)
	if old_dist > 1.0 and new_dist > 1.0:
		zoom_at(new_mid, new_dist / old_dist)
	pan_screen(new_mid - old_mid)


func _is_over_ui(screen_pos: Vector2) -> bool:
	for c in ui_blockers:
		if c.is_visible_in_tree() and c.get_global_rect().has_point(screen_pos):
			return true
	return false


func _set_zoom_level(value: float) -> void:
	var z := clampf(value, min_zoom(), max_zoom())
	zoom = Vector2(z, z)
	zoom_changed.emit(z)


func _view_size() -> Vector2:
	return get_viewport_rect().size


func _on_viewport_resized() -> void:
	_set_zoom_level(zoom_level())
	position = clamp_position(position, zoom_level(), _view_size(), map_bounds)
