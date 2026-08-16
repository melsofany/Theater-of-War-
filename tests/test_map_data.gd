extends GutTest
## Tests for MapData feature queries (height, water, bridge, impassable, roads).

var _md: MapData


func before_each():
	_md = MapData.new()
	_md.size = 16
	_md.cell = 2.0
	_md.origin = Vector3(-16, 0, -16)
	_md.heights.resize(16 * 16)
	_md.heights.fill(0.0)


func test_height_set_and_get_grid():
	_md.set_height_at_grid(3, 4, 12.0)
	assert_eq(_md.height_at_grid(3, 4), 12.0)
	# Out of bounds returns 0.
	assert_eq(_md.height_at_grid(99, 99), 0.0)


func test_height_world_bilinear_between_cells():
	_md.set_height_at_grid(0, 0, 0.0)
	_md.set_height_at_grid(1, 0, 10.0)
	# Halfway in x should be ~5.
	var h := _md.height_at(_md.origin.x + 1.0, _md.origin.z)
	assert_almost_eq(h, 5.0, 0.5)


func test_water_is_impassable_without_bridge():
	_md.add_water(PackedVector2Array([Vector2(-10, -10), Vector2(-4, -10), Vector2(-4, -4), Vector2(-10, -4)]))
	assert_true(_md.is_water(-7, -7))
	assert_true(_md.is_impassable(-7, -7))


func test_bridge_makes_water_passable():
	_md.add_water(PackedVector2Array([Vector2(-10, -10), Vector2(-4, -10), Vector2(-4, -4), Vector2(-10, -4)]))
	_md.add_bridge(Vector2(-7, -7), 2.0)
	# At the bridge centre water is passable.
	assert_true(_md.is_bridge(-7, -7))
	assert_false(_md.is_impassable(-7, -7))


func test_mountain_is_impassable():
	_md.mountain_height = 18.0
	_md.set_height_at_grid(5, 5, 25.0)
	var w := _md.grid_to_world(5, 5)
	assert_true(_md.is_impassable(w.x, w.z))


func test_road_reduces_move_cost():
	_md.add_road(PackedVector2Array([Vector2(-16, 0), Vector2(16, 0)]))
	var cost := _md.move_cost(0.0, 0.0)
	assert_lt(cost, 1.0)
	# Off-road normal cost.
	var off := _md.move_cost(5.0, 5.0)
	assert_eq(off, 1.0)


func test_impassable_move_cost_is_inf():
	_md.add_water(PackedVector2Array([Vector2(-10, -10), Vector2(-4, -10), Vector2(-4, -4), Vector2(-10, -4)]))
	assert_true(is_inf(_md.move_cost(-7, -7)))
