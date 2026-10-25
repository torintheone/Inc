class_name WorldMap
extends Node2D
## Карта мира: заливка стран (один меш на всю карту), границы и обводка
## выбранной страны. Ввод обрабатывает MapCamera.

const FILL_SHADER := preload("res://src/map/country_fill.gdshader")
const OUTLINE_WIDTH_PX := 3.0
const WINDOW_WIDTH_PX := 2.5

var world: WorldData
var selected: Country

var _palette_image: Image
var _palette_texture: ImageTexture
var _fill: MeshInstance2D
var _neutral: MeshInstance2D
var _borders: _BorderLayer
var _windows: _OutlineLayer
var _outline: _OutlineLayer


func setup(p_world: WorldData) -> void:
	world = p_world
	_build_palette()
	_neutral = _make_mesh_node(_build_neutral_mesh(), null)
	_neutral.modulate = MapPalette.NEUTRAL_LAND
	add_child(_neutral)
	var mat := ShaderMaterial.new()
	mat.shader = FILL_SHADER
	mat.set_shader_parameter("country_colors", _palette_texture)
	_fill = _make_mesh_node(_build_country_mesh(), mat)
	add_child(_fill)
	_borders = _BorderLayer.new()
	_borders.segments = _build_border_segments()
	add_child(_borders)
	_windows = _OutlineLayer.new()
	_windows.color = MapPalette.OCHRE
	add_child(_windows)
	_outline = _OutlineLayer.new()
	_outline.color = MapPalette.SELECTED_OUTLINE
	add_child(_outline)


func set_country_color(country: Country, color: Color) -> void:
	_palette_image.set_pixel(country.index, 0, color)
	_palette_texture.update(_palette_image)


## Выделить страну обводкой (null — снять выделение). Заливка показывает влияние движения.
func select(country: Country) -> void:
	if selected == country:
		return
	selected = country
	_outline.countries.clear()
	if selected != null:
		_outline.countries.append(selected)
	_outline.queue_redraw()


## Перекрасить страны по состоянию партии: чем сильнее движение, тем краснее; революционные —
## тёмно-красные. Страны с открытым окном революции обведены охрой.
func apply_sim(sim: SimWorld) -> void:
	var windows: Array[Country] = []
	for cs in sim.countries:
		_palette_image.set_pixel(cs.index, 0, color_for(cs))
		if cs.window_left >= 0 and not cs.is_revolutionary():
			windows.append(cs.country)
	_palette_texture.update(_palette_image)
	if windows != _windows.countries:
		_windows.countries = windows
		_windows.queue_redraw()


func reset_colors() -> void:
	_palette_image.fill(MapPalette.LAND)
	_palette_texture.update(_palette_image)
	_windows.countries.clear()
	_windows.queue_redraw()


static func color_for(cs: CountryState) -> Color:
	if cs.is_revolutionary():
		return MapPalette.REVOLUTIONARY_LAND
	if cs.influence <= 0.0:
		return MapPalette.LAND
	return MapPalette.LAND.lerp(MapPalette.VERMILION, clampf(pow(cs.influence / 45.0, 0.7), 0.06, 0.92))


## Толщина обводки задаётся в пикселях экрана, поэтому при смене масштаба её пересчитываем.
func on_zoom_changed(zoom: float) -> void:
	_outline.width = OUTLINE_WIDTH_PX / zoom
	_outline.queue_redraw()
	_windows.width = WINDOW_WIDTH_PX / zoom
	_windows.queue_redraw()


func _build_palette() -> void:
	_palette_image = Image.create(maxi(world.countries.size(), 1), 1, false, Image.FORMAT_RGBA8)
	_palette_image.fill(MapPalette.LAND)
	_palette_texture = ImageTexture.create_from_image(_palette_image)


func _build_country_mesh() -> ArrayMesh:
	var verts := PackedVector2Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for c in world.countries:
		var uv := Vector2(c.index, 0.0)
		for s in c.shapes:
			var base := verts.size()
			verts.append_array(s.points)
			for i in s.points.size():
				uvs.append(uv)
			for t in s.triangles:
				indices.append(base + t)
	return _array_mesh(verts, uvs, indices)


func _build_neutral_mesh() -> ArrayMesh:
	var verts := PackedVector2Array()
	var indices := PackedInt32Array()
	for s in world.neutral_shapes:
		var base := verts.size()
		verts.append_array(s.points)
		for t in s.triangles:
			indices.append(base + t)
	return _array_mesh(verts, PackedVector2Array(), indices)


func _build_border_segments() -> PackedVector2Array:
	var segs := PackedVector2Array()
	var rings: Array[PackedVector2Array] = []
	for c in world.countries:
		for s in c.shapes:
			rings.append(s.outer)
			rings.append_array(s.holes)
	for s in world.neutral_shapes:
		rings.append(s.outer)
	for ring in rings:
		var n := ring.size()
		for i in n:
			segs.append(ring[i])
			segs.append(ring[(i + 1) % n])
	return segs


static func _array_mesh(verts: PackedVector2Array, uvs: PackedVector2Array, indices: PackedInt32Array) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	if not uvs.is_empty():
		arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	if not indices.is_empty():
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func _make_mesh_node(mesh: ArrayMesh, mat: Material) -> MeshInstance2D:
	var node := MeshInstance2D.new()
	node.mesh = mesh
	node.material = mat
	return node


## Все границы одним вызовом рисования: тонкие линии в 1 пиксель при любом масштабе.
class _BorderLayer:
	extends Node2D
	var segments: PackedVector2Array

	func _draw() -> void:
		draw_multiline(segments, MapPalette.BORDER, -1.0)


class _OutlineLayer:
	extends Node2D
	var countries: Array[Country] = []
	var width := 2.0
	var color := MapPalette.INK

	func _draw() -> void:
		for country in countries:
			for s in country.shapes:
				var ring := s.outer.duplicate()
				ring.append(ring[0])
				draw_polyline(ring, color, width, true)
