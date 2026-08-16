extends GutTest
## Tests for the AI: pure strategy decisions (posture/objective selection) and
## AIController integration (snapshot building, operational movement, tactical
## retreat). The AI must decide only on the information in the snapshot.

var Strat := AIStrategy.new()


func test_offensive_when_strong_and_ready():
	var d := Strat.decide({
		"own_force": 500.0,
		"enemy_force": 100.0,
		"avg_readiness": 0.9,
		"enemy_known_positions": [Vector3(50, 0, 0)],
		"own_buildings": [Vector3(0, 0, 0)],
		"home_pos": Vector3(0, 0, 0),
		"rally_pos": Vector3(0, 0, 0),
	})
	assert_eq(d["posture"], AIStrategy.Posture.OFFENSIVE)


func test_defensive_when_outnumbered():
	var d := Strat.decide({
		"own_force": 50.0,
		"enemy_force": 500.0,
		"avg_readiness": 0.8,
		"enemy_known_positions": [Vector3(50, 0, 0)],
		"own_buildings": [Vector3(0, 0, 0), Vector3(10, 0, 0)],
		"home_pos": Vector3(0, 0, 0),
		"rally_pos": Vector3(0, 0, 0),
	})
	assert_eq(d["posture"], AIStrategy.Posture.DEFENSIVE)


func test_defensive_when_low_readiness():
	var d := Strat.decide({
		"own_force": 500.0,
		"enemy_force": 500.0,
		"avg_readiness": 0.1,
		"enemy_known_positions": [Vector3(50, 0, 0)],
		"own_buildings": [Vector3(0, 0, 0)],
		"home_pos": Vector3(0, 0, 0),
		"rally_pos": Vector3(0, 0, 0),
	})
	assert_eq(d["posture"], AIStrategy.Posture.DEFENSIVE)


func test_regroup_when_even():
	var d := Strat.decide({
		"own_force": 100.0,
		"enemy_force": 100.0,
		"avg_readiness": 0.7,
		"enemy_known_positions": [Vector3(50, 0, 0)],
		"own_buildings": [Vector3(0, 0, 0)],
		"home_pos": Vector3(0, 0, 0),
		"rally_pos": Vector3(5, 0, 5),
	})
	assert_eq(d["posture"], AIStrategy.Posture.REGROUP)
	assert_eq(d["objective"], Vector3(5, 0, 5))


func test_offensive_objective_is_nearest_enemy():
	var d := Strat.decide({
		"own_force": 500.0,
		"enemy_force": 100.0,
		"avg_readiness": 0.9,
		"enemy_known_positions": [Vector3(100, 0, 0), Vector3(20, 0, 0)],
		"own_buildings": [Vector3(0, 0, 0)],
		"home_pos": Vector3(0, 0, 0),
		"rally_pos": Vector3(0, 0, 0),
	})
	assert_eq(d["posture"], AIStrategy.Posture.OFFENSIVE)
	assert_eq(d["objective"], Vector3(20, 0, 0))  # nearest to home/rally


func test_defensive_objective_is_building_centroid():
	var d := Strat.decide({
		"own_force": 50.0,
		"enemy_force": 500.0,
		"avg_readiness": 0.8,
		"enemy_known_positions": [Vector3(50, 0, 0)],
		"own_buildings": [Vector3(0, 0, 0), Vector3(10, 0, 0)],
		"home_pos": Vector3(0, 0, 0),
		"rally_pos": Vector3(0, 0, 0),
	})
	assert_eq(d["posture"], AIStrategy.Posture.DEFENSIVE)
	assert_eq(d["objective"], Vector3(5, 0, 0))  # centroid


func test_force_ratio_computed():
	var d := Strat.decide({
		"own_force": 300.0,
		"enemy_force": 100.0,
		"avg_readiness": 0.9,
		"enemy_known_positions": [Vector3(50, 0, 0)],
		"own_buildings": [Vector3(0, 0, 0)],
		"home_pos": Vector3(0, 0, 0),
		"rally_pos": Vector3(0, 0, 0),
	})
	assert_eq(d["force_ratio"], 3.0)


func _make_unit(faction: Faction, at: Vector3, hp: float = 100.0) -> Unit:
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
	AIController.clear()
	AIController.set_process(false)
	Intelligence.clear()
	Intelligence.set_process(false)


func after_each():
	AIController.set_process(true)
	AIController.clear()
	Intelligence.set_process(true)
	Intelligence.clear()


func test_controller_builds_snapshot_and_decides():
	var blue := Faction.make("blue", "Blue", Color.BLUE, ["red"], true)
	var red := Faction.make("red", "Red", Color.RED, ["blue"], false)
	var enemy_visible := _make_unit(blue, Vector3(0, 0, 0))   # blue spots
	var red_unit := _make_unit(red, Vector3(10, 0, 0))
	var red_building: Building = load("res://src/Units/Building.tscn").instantiate()
	red_building.faction = red
	red_building.global_position = Vector3(20, 0, 0)
	var w := _make_world_with([enemy_visible, red_unit, red_building])
	AIController.world = w
	Intelligence.world = w
	Intelligence.tick(1.0)  # red_unit becomes visible to blue; red sees blue too
	# Run red AI: red is outnumbered-ish? red own_force=100 (one unit), enemy_force from intel.
	AIController._run(red, 3.0)
	var dec := AIController.decision_for(red)
	assert_false(dec.is_empty())
	assert_true(dec.has("posture"))


func test_tactical_retreat_for_low_health_unit():
	var red := Faction.make("red", "Red", Color.RED, ["blue"], false)
	var blue := Faction.make("blue", "Blue", Color.BLUE, ["red"], true)
	var red_unit := _make_unit(red, Vector3(0, 0, 0))
	var blue_unit := _make_unit(blue, Vector3(5, 0, 0))
	var w := _make_world_with([red_unit, blue_unit])
	AIController.world = w
	Intelligence.world = w
	Intelligence.tick(1.0)
	red_unit.health = 5.0  # low health -> should retreat
	var pos_before := red_unit.target_position
	AIController._tactical(red)
	# Retreat order sets a target position away from the enemy.
	assert_ne(red_unit.target_position, pos_before)


func test_offensive_ai_moves_unit_toward_objective():
	var red := Faction.make("red", "Red", Color.RED, ["blue"], false)
	var blue := Faction.make("blue", "Blue", Color.BLUE, ["red"], true)
	var red_unit := _make_unit(red, Vector3(0, 0, 0))
	var blue_unit := _make_unit(blue, Vector3(15, 0, 0))  # within red sight (18)
	var red_building: Building = load("res://src/Units/Building.tscn").instantiate()
	red_building.faction = red
	red_building.global_position = Vector3(0, 0, 0)
	var w := _make_world_with([red_unit, blue_unit, red_building])
	AIController.world = w
	Intelligence.world = w
	Intelligence.tick(1.0)
	# Force an offensive decision: red strong, blue weak.
	red_unit.health = 1000.0
	red_unit.max_health = 1000.0
	AIController._run(red, 3.0)
	var dec := AIController.decision_for(red)
	assert_eq(dec["posture"], AIStrategy.Posture.OFFENSIVE)
	# The red unit should have a move order toward the blue unit (~15 on x).
	assert_gt(red_unit.target_position.x, 5.0)
