extends GutTest
## Tests for the procedural TerrainGenerator output.

func test_generator_produces_valid_map():
	var md := TerrainGenerator.new(42).generate(64, 2.0)
	assert_eq(md.size, 64)
	assert_eq(md.cell, 2.0)
	assert_eq(md.heights.size(), 64 * 64)


func test_generator_has_features():
	var md := TerrainGenerator.new().generate()
	# At least one river, one road, one bridge, two cities, two zones.
	assert_true(md.waters.size() >= 1)
	assert_true(md.roads.size() >= 1)
	assert_true(md.bridges.size() >= 1)
	assert_true(md.cities.size() >= 2)
	assert_true(md.zones.size() >= 2)


func test_bridge_at_river_crossing_is_passable():
	var md := TerrainGenerator.new().generate()
	for b in md.bridges:
		var bp: Vector2 = b["position"]
		# Even if the bridge sits in water, it must be passable.
		if md.is_water(bp.x, bp.y):
			assert_false(md.is_impassable(bp.x, bp.y))


func test_some_mountains_exist():
	var md := TerrainGenerator.new().generate()
	var found_mountain := false
	for gz in md.size:
		for gx in md.size:
			if md.height_at_grid(gx, gz) >= md.mountain_height:
				found_mountain = true
				break
		if found_mountain:
			break
	assert_true(found_mountain)
