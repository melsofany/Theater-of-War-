extends GutTest
## Tests for the logistics system: supply/fuel state, consumption on fire/move,
## resupply near a friendly building, attrition when cut off, and readiness.

func _make_unit(faction: Faction = null) -> Unit:
	var u: Unit = load("res://src/Units/Unit.tscn").instantiate()
	u.unit_type = UnitFactory.get_type("infantry")
	u._apply_type()
	if faction:
		u.faction = faction
	return u


func _make_building(faction: Faction, at: Vector3) -> Building:
	var b: Building = load("res://src/Units/Building.tscn").instantiate()
	b.faction = faction
	b.global_position = at
	return b


func _make_world_with(bodies: Array) -> World:
	# Build a bare World with a units_root so get_buildings/get_units work,
	# without triggering terrain generation.
	var w := World.new()
	add_child(w)
	var root := Node3D.new()
	w.add_child(root)
	w.units_root = root
	for b in bodies:
		root.add_child(b)
	return w


func before_each():
	Logistics.clear()
	Logistics.set_process(false)  # stop the live autoload; tests drive _process manually


func after_each():
	Logistics.set_process(true)
	Logistics.clear()


func test_readiness_full_when_supplied_and_healthy():
	var u := _make_unit()
	add_child(u)
	assert_almost_eq(u.compute_readiness(), 1.0, 0.01)


func test_readiness_drops_with_low_supply():
	var u := _make_unit()
	add_child(u)
	u.supply = 0.0
	var r := u.compute_readiness()
	assert_lt(r, 0.61)


func test_fire_consumes_ammo_and_scales_damage():
	var attacker := _make_unit()
	var target := _make_unit()
	add_child(attacker)
	add_child(target)
	var hp_before := target.health
	attacker._fire(target)
	assert_lt(target.health, hp_before)  # took damage
	assert_lt(attacker.supply, attacker.max_supply)  # ammo consumed


func test_fire_blocked_without_ammo():
	var attacker := _make_unit()
	var target := _make_unit()
	add_child(attacker)
	add_child(target)
	attacker.supply = 0.0
	var hp_before := target.health
	attacker._fire(target)
	assert_eq(target.health, hp_before)  # no damage (out of ammo)


func test_resupply_near_friendly_building():
	var f := Faction.make("blue", "Blue", Color.BLUE, [], true)
	var b := _make_building(f, Vector3(0, 0, 0))
	var u := _make_unit(f)
	u.global_position = Vector3(5, 0, 0)
	var w := _make_world_with([b, u])
	u.supply = 0.0  # set after add_child
	u.fuel = 0.0
	Logistics.world = w
	Logistics._process(1.0)
	assert_gt(u.supply, 0.0)
	assert_gt(u.fuel, 0.0)


func test_attrition_when_cut_off():
	var f := Faction.make("blue", "Blue", Color.BLUE, [], true)
	var u := _make_unit(f)
	u.global_position = Vector3(100, 0, 0)
	var w := _make_world_with([u])
	u.supply = 5.0  # set after add_child so _ready/_apply_type doesn't reset it
	Logistics.world = w
	Logistics._process(1.0)
	assert_lt(u.supply, 5.0)  # drained by attrition


func test_is_in_supply_true_near_friendly_building():
	var f := Faction.make("blue", "Blue", Color.BLUE, [], true)
	var b := _make_building(f, Vector3(0, 0, 0))
	var u := _make_unit(f)
	u.global_position = Vector3(10, 0, 0)
	var w := _make_world_with([b, u])
	Logistics.world = w
	assert_true(Logistics.is_in_supply(u))


func test_is_in_supply_false_for_enemy_building():
	var f_blue := Faction.make("blue", "Blue", Color.BLUE, [], true)
	var f_red := Faction.make("red", "Red", Color.RED, ["blue"], false)
	var b := _make_building(f_red, Vector3(0, 0, 0))
	var u := _make_unit(f_blue)
	u.global_position = Vector3(5, 0, 0)
	var w := _make_world_with([b, u])
	Logistics.world = w
	assert_false(Logistics.is_in_supply(u))
