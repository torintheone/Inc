extends GutTest
## Данные мира: загрузка, полигоны, соседство, выбор страны по точке.

var world: WorldData


func before_all() -> void:
	world = WorldData.load_default()


func test_world_loads_about_180_countries() -> void:
	assert_not_null(world, "data/world.json и data/world_shapes.json загружаются")
	assert_between(world.countries.size(), 150, 220)
	assert_gt(world.neutral_shapes.size(), 0, "есть нейтральная суша (Гренландия и др.)")


func test_ids_are_unique_and_indexed() -> void:
	var seen := {}
	for i in world.countries.size():
		var c := world.countries[i]
		assert_false(seen.has(c.id), "id не повторяется: %s" % c.id)
		seen[c.id] = true
		assert_eq(c.index, i, "номер страны совпадает с её местом в списке")
		assert_eq(world.get_country(c.id), c)


func test_every_country_has_name_zone_and_indicators() -> void:
	for c in world.countries:
		assert_ne(c.name_ru, "", "у %s есть русское название" % c.id)
		assert_has(["core", "semi", "periphery"], c.zone, "зона %s" % c.id)
		assert_gt(c.indicator("population"), 0.0, "население %s" % c.id)
		assert_gt(c.indicator("gdp_per_capita"), 0.0, "ВВП на душу %s" % c.id)
		for key in ["emp_industry", "emp_agriculture", "unemployment", "gini"]:
			assert_between(c.indicator(key, -1.0), 0.0, 100.0, "%s у %s в 0–100" % [key, c.id])


func test_triangles_reference_existing_vertices() -> void:
	for c in world.countries:
		assert_gt(c.shapes.size(), 0, "у %s есть полигоны" % c.id)
		for s in c.shapes:
			assert_eq(s.triangles.size() % 3, 0, "треугольники %s по три вершины" % c.id)
			assert_gt(s.triangles.size(), 0)
			var max_index := 0
			for t in s.triangles:
				max_index = maxi(max_index, t)
			assert_lt(max_index, s.points.size(), "индексы %s в пределах вершин" % c.id)


func test_neighbors_are_symmetric_and_known() -> void:
	for c in world.countries:
		for nid in c.neighbors:
			var n := world.get_country(nid)
			assert_not_null(n, "сосед %s у %s существует" % [nid, c.id])
			if n != null:
				assert_has(n.neighbors, c.id, "%s и %s соседи друг для друга" % [c.id, nid])
	assert_has(world.get_country("FRA").neighbors, "ESP")
	assert_has(world.get_country("FRA").neighbors, "DEU")
	assert_has(world.get_country("RUS").neighbors, "CHN")
	assert_eq(world.get_country("AUS").neighbors.size(), 0, "у Австралии нет сухопутных границ")


func test_zones_cover_world_system() -> void:
	assert_eq(world.get_country("USA").zone, "core")
	assert_eq(world.get_country("DEU").zone, "core")
	assert_eq(world.get_country("BRA").zone, "semi")
	assert_eq(world.get_country("NGA").zone, "periphery")


func test_label_point_picks_its_country() -> void:
	var hits := 0
	for c in world.countries:
		if world.country_at(c.label) == c:
			hits += 1
	# Точка подписи Natural Earth лежит внутри страны почти всегда.
	assert_gt(float(hits) / world.countries.size(), 0.95, "по точке подписи выбирается своя страна")


func test_ocean_point_picks_nothing() -> void:
	# Южная часть Тихого океана (≈ 140° з. д., 30° ю. ш.).
	assert_null(world.country_at(Vector2(-1493.0, 377.0)))


func test_tolerance_helps_hit_small_islands() -> void:
	var mlt := world.get_country("MLT")
	assert_not_null(mlt, "Мальта есть в списке стран")
	var rightmost := mlt.shapes[0].outer[0]
	for p in mlt.shapes[0].outer:
		if p.x > rightmost.x:
			rightmost = p
	var near := rightmost + Vector2(1.5, 0.0)
	assert_null(world.country_at(near, 0.0), "мимо острова без допуска")
	assert_eq(world.country_at(near, 3.0), mlt, "с допуском попадаем в остров")
