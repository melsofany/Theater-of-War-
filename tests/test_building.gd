extends GutTest
## Tests for Building production queue + rally point (Phase 1).

const BuildingScenePath := "res://src/Units/Building.tscn"


func test_queue_unit_grows_queue():
	var b = load(BuildingScenePath).instantiate()
	add_child(b)
	# No unit_scene assigned -> spawn is skipped, but queueing still records.
	b.unit_scene = null
	assert_true(b.queue_unit())
	assert_eq(b.production_queue.size(), 1)
	assert_true(b.queue_unit())
	assert_eq(b.production_queue.size(), 2)
	b.queue_free()


func test_queue_respects_max():
	var b = load(BuildingScenePath).instantiate()
	add_child(b)
	b.max_queue = 2
	assert_true(b.queue_unit())
	assert_true(b.queue_unit())
	# Third should be rejected.
	assert_false(b.queue_unit())
	assert_eq(b.production_queue.size(), 2)
	b.queue_free()


func test_rally_point_defaults_and_set():
	var b = load(BuildingScenePath).instantiate()
	add_child(b)
	# _ready ran: rally defaults to spawn point.
	assert_ne(b.rally_point, Vector3.ZERO)
	b.set_rally_point(Vector3(10, 0, 5))
	assert_eq(b.rally_point, Vector3(10, 0, 5))
	b.queue_free()


func test_production_tick_consumes_queue():
	var b = load(BuildingScenePath).instantiate()
	add_child(b)
	b.build_time = 0.5
	b.unit_scene = null
	b.queue_unit()
	assert_eq(b.production_queue.size(), 1)
	# Simulate enough frames to exceed build_time.
	for i in 60:
		b._process(0.016)
	# Item consumed after time elapsed (spawn skipped because no scene).
	assert_eq(b.production_queue.size(), 0)
	b.queue_free()
