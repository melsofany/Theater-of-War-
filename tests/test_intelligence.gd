extends GutTest
## Tests for intelligence: reconnaissance, fog of war, last-known positions,
## memory decay, enemy estimates, and reports.

func _make_unit(faction: Faction, at: Vector3) -> Unit:
	var u: Unit = load("res://src/Units/Unit.tscn").instantiate()
	u.unit_type = UnitFactory.get_type("infantry")
	u.faction = faction
	u.global_position = at
	return u


func _make_world_with(bodies: Array) -> World:
	var w := World.new()
	add_child(w)
	var root := Node3D.new()
	w.add_child(root)
	w.units_root = root
	for b in bodies:
		root.add_child(b)
	return w


func before_each():
	Intelligence.clear()
	Intelligence.set_process(false)


func after_each():
	Intelligence.set_process(true)
	Intelligence.clear()


func test_enemy_out_of_sight_not_visible():
	var blue := Faction.make("blue", "Blue", Color.BLUE, ["red"], true)
	var red := Faction.make("red", "Red", Color.RED, ["blue"], false)
	var spotter := _make_unit(blue, Vector3(0, 0, 0))
	var enemy := _make_unit(red, Vector3(200, 0, 0))  # far beyond sight (18)
	var w := _make_world_with([spotter, enemy])
	Intelligence.world = w
	assert_false(Intelligence.is_visible(blue, enemy))


func test_enemy_within_sight_visible():
	var blue := Faction.make("blue", "Blue", Color.BLUE, ["red"], true)
	var red := Faction.make("red", "Red", Color.RED, ["blue"], false)
	var spotter := _make_unit(blue, Vector3(0, 0, 0))
	var enemy := _make_unit(red, Vector3(10, 0, 0))  # within sight (18)
	var w := _make_world_with([spotter, enemy])
	Intelligence.world = w
	assert_true(Intelligence.is_visible(blue, enemy))


func test_tick_records_visible_and_remembered():
	var blue := Faction.make("blue", "Blue", Color.BLUE, ["red"], true)
	var red := Faction.make("red", "Red", Color.RED, ["blue"], false)
	var spotter := _make_unit(blue, Vector3(0, 0, 0))
	var enemy := _make_unit(red, Vector3(10, 0, 0))
	var w := _make_world_with([spotter, enemy])
	Intelligence.world = w
	Intelligence.tick(0.0)
	assert_eq(Intelligence.visible_enemies_of(blue).size(), 1)
	var lkp = Intelligence.last_known_position(blue, enemy)
	assert_not_null(lkp)


func test_last_known_decays_after_sight_lost():
	var blue := Faction.make("blue", "Blue", Color.BLUE, ["red"], true)
	var red := Faction.make("red", "Red", Color.RED, ["blue"], false)
	var spotter := _make_unit(blue, Vector3(0, 0, 0))
	var enemy := _make_unit(red, Vector3(10, 0, 0))
	var w := _make_world_with([spotter, enemy])
	Intelligence.world = w
	Intelligence.remember_seconds = 5.0
	Intelligence.tick(1.0)
	assert_not_null(Intelligence.last_known_position(blue, enemy))
	# Move enemy out of sight and advance sim time past the remember window.
	enemy.global_position = Vector3(500, 0, 0)
	Intelligence.tick(6.0)  # 6 > 5 -> memory decays
	assert_null(Intelligence.last_known_position(blue, enemy))


func test_enemy_estimate_counts_categories():
	var blue := Faction.make("blue", "Blue", Color.BLUE, ["red"], true)
	var red := Faction.make("red", "Red", Color.RED, ["blue"], false)
	var spotter := _make_unit(blue, Vector3(0, 0, 0))
	var e1 := _make_unit(red, Vector3(10, 0, 0))
	var e2: Unit = load("res://src/Units/Unit.tscn").instantiate()
	e2.unit_type = UnitFactory.get_type("tank")
	e2.faction = red
	e2.global_position = Vector3(12, 0, 0)
	var w := _make_world_with([spotter, e1, e2])
	Intelligence.world = w
	Intelligence.tick(0.0)
	var est: Dictionary = Intelligence.enemy_estimate(blue)
	assert_eq(est.size(), 2)  # infantry + tank categories
	assert_true(est.has(UnitType.Category.INFANTRY))
	assert_true(est.has(UnitType.Category.TANK))


func test_friendly_units_not_counted_as_enemies():
	var blue := Faction.make("blue", "Blue", Color.BLUE, ["red"], true)
	var u1 := _make_unit(blue, Vector3(0, 0, 0))
	var u2 := _make_unit(blue, Vector3(5, 0, 0))
	var w := _make_world_with([u1, u2])
	Intelligence.world = w
	Intelligence.tick(0.0)
	assert_eq(Intelligence.visible_enemies_of(blue).size(), 0)


func test_report_is_nonempty_string():
	var blue := Faction.make("blue", "Blue", Color.BLUE, ["red"], true)
	var red := Faction.make("red", "Red", Color.RED, ["blue"], false)
	var spotter := _make_unit(blue, Vector3(0, 0, 0))
	var enemy := _make_unit(red, Vector3(10, 0, 0))
	var w := _make_world_with([spotter, enemy])
	Intelligence.world = w
	Intelligence.tick(0.0)
	var r: String = Intelligence.report(blue)
	assert_gt(r.length(), 0)
