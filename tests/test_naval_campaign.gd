extends GutTest
## Tests for Phase 10: naval domain (water-only movement) and the campaign
## objective system (capture cities, eliminate enemy, hold position, win/lose).

func _make_unit(faction: Faction, at: Vector3, type_name: String = "infantry") -> Unit:
	var u: Unit = load("res://src/Units/Unit.tscn").instantiate()
	u.unit_type = UnitFactory.get_type(type_name)
	u.faction = faction
	u.global_position = at
	return u


func _make_world_with_water(bodies: Array, water_loops: Array) -> World:
	var w := World.new()
	add_child(w)
	var md := MapData.new()
	# heights already zero-filled by _init; water polygons added below.
	for loop in water_loops:
		md.add_water(loop)
	w.map_data = md
	var root := Node3D.new()
	w.add_child(root)
	w.units_root = root
	for b in bodies:
		root.add_child(b)
	return w


func _water_rect(x0: float, z0: float, x1: float, z1: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x0, z0), Vector2(x1, z0), Vector2(x1, z1), Vector2(x0, z1)])


# --- Naval ------------------------------------------------------------------

func test_destroyer_is_naval_domain():
	var t: UnitType = UnitFactory.get_type("destroyer")
	assert_true(t.is_naval())
	assert_false(t.is_air())


func test_naval_unit_moves_on_water():
	var blue := Faction.make("blue", "Blue", Color.BLUE, ["red"], true)
	var dest := _make_unit(blue, Vector3(5, 0, 0), "destroyer")
	# Water covers x in [0,20], z in [0,20].
	var w := _make_world_with_water([dest], [_water_rect(0, 0, 20, 20)])
	dest.world = w
	dest.move_to(Vector3(15, 0, 0))
	# Run several physics steps; the destroyer should advance toward x=15.
	for i in range(30):
		dest._physics_process(0.1)
	assert_gt(dest.global_position.x, 10.0)


func test_naval_unit_stops_at_shoreline():
	var blue := Faction.make("blue", "Blue", Color.BLUE, ["red"], true)
	var dest := _make_unit(blue, Vector3(5, 0, 5), "destroyer")
	# Water only x in [0,10]; target on land at x=20.
	var w := _make_world_with_water([dest], [_water_rect(0, 0, 10, 20)])
	dest.world = w
	dest.move_to(Vector3(20, 0, 5))
	for i in range(40):
		dest._physics_process(0.1)
	# Should not have crossed onto land (x stays <= ~10).
	assert_lt(dest.global_position.x, 11.0)


func test_world_is_water_at():
	var w := _make_world_with_water([], [_water_rect(0, 0, 10, 10)])
	assert_true(w.is_water_at(5, 5))
	assert_false(w.is_water_at(50, 50))


# --- Campaign --------------------------------------------------------------

func before_each():
	Campaign.clear()
	Campaign.set_process(false)


func after_each():
	Campaign.set_process(true)
	Campaign.clear()


func test_capture_cities_objective_completes():
	var blue := Faction.make("blue", "Blue", Color.BLUE, ["red"], true)
	var w := World.new()
	add_child(w)
	var root := Node3D.new()
	w.add_child(root)
	w.units_root = root
	var city := City.new()
	root.add_child(city)
	city.global_position = Vector3(0, 0, 0)
	Campaign.world = w
	Campaign.add_objective(blue, {"type": Campaign.ObjectiveType.CAPTURE_CITIES, "cities": [city]})
	assert_false(Campaign.is_won(blue))
	city.capture(blue)
	Campaign.tick(0.0)
	assert_true(Campaign.is_won(blue))


func test_capture_cities_not_done_when_uncaptured():
	var blue := Faction.make("blue", "Blue", Color.BLUE, ["red"], true)
	var red := Faction.make("red", "Red", Color.RED, ["blue"], false)
	var w := World.new()
	add_child(w)
	var root := Node3D.new()
	w.add_child(root)
	w.units_root = root
	var city := City.new()
	root.add_child(city)
	Campaign.world = w
	Campaign.add_objective(blue, {"type": Campaign.ObjectiveType.CAPTURE_CITIES, "cities": [city]})
	city.capture(red)
	Campaign.tick(0.0)
	assert_false(Campaign.is_won(blue))


func test_eliminate_enemy_objective():
	var blue := Faction.make("blue", "Blue", Color.BLUE, ["red"], true)
	var red := Faction.make("red", "Red", Color.RED, ["blue"], false)
	var w := World.new()
	add_child(w)
	var root := Node3D.new()
	w.add_child(root)
	w.units_root = root
	var enemy := _make_unit(red, Vector3(0, 0, 0))
	root.add_child(enemy)
	Campaign.world = w
	Campaign.add_objective(blue, {"type": Campaign.ObjectiveType.ELIMINATE_ENEMY, "threshold": 0})
	Campaign.tick(0.0)
	assert_false(Campaign.is_won(blue))
	enemy.alive = false
	Campaign.tick(0.0)
	assert_true(Campaign.is_won(blue))


func test_hold_position_objective_accumulates():
	var blue := Faction.make("blue", "Blue", Color.BLUE, ["red"], true)
	var w := World.new()
	add_child(w)
	var root := Node3D.new()
	w.add_child(root)
	w.units_root = root
	var u := _make_unit(blue, Vector3(0, 0, 0))
	root.add_child(u)
	Campaign.world = w
	Campaign.add_objective(blue, {
		"type": Campaign.ObjectiveType.HOLD_POSITION,
		"pos": Vector3(0, 0, 0),
		"radius": 5.0,
		"count": 1,
		"hold_seconds": 2.0,
	})
	# Tick enough sim time to accumulate 2 seconds.
	for i in range(25):
		Campaign.tick(0.1)
	assert_true(Campaign.is_won(blue))


func test_hold_position_resets_when_no_units():
	var blue := Faction.make("blue", "Blue", Color.BLUE, ["red"], true)
	var w := World.new()
	add_child(w)
	var root := Node3D.new()
	w.add_child(root)
	w.units_root = root
	Campaign.world = w
	Campaign.add_objective(blue, {
		"type": Campaign.ObjectiveType.HOLD_POSITION,
		"pos": Vector3(0, 0, 0),
		"radius": 5.0,
		"count": 1,
		"hold_seconds": 2.0,
	})
	Campaign.tick(1.0)
	assert_false(Campaign.is_won(blue))


func test_multiple_objectives_all_required():
	var blue := Faction.make("blue", "Blue", Color.BLUE, ["red"], true)
	var red := Faction.make("red", "Red", Color.RED, ["blue"], false)
	var w := World.new()
	add_child(w)
	var root := Node3D.new()
	w.add_child(root)
	w.units_root = root
	var city := City.new()
	root.add_child(city)
	var enemy := _make_unit(red, Vector3(0, 0, 0))
	root.add_child(enemy)
	Campaign.world = w
	Campaign.add_objective(blue, {"type": Campaign.ObjectiveType.CAPTURE_CITIES, "cities": [city]})
	Campaign.add_objective(blue, {"type": Campaign.ObjectiveType.ELIMINATE_ENEMY, "threshold": 0})
	city.capture(blue)
	Campaign.tick(0.0)
	assert_false(Campaign.is_won(blue))  # enemy still alive
	enemy.alive = false
	Campaign.tick(0.0)
	assert_true(Campaign.is_won(blue))
