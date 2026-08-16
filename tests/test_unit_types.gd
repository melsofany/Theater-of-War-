extends GutTest
## Tests for UnitType definitions and the UnitFactory registry.

func test_factory_has_all_categories():
	var keys := UnitFactory.all_keys()
	for k in ["infantry", "vehicle", "tank", "artillery", "air_defense", "aircraft", "helicopter"]:
		assert_true(keys.has(k), "missing key: %s" % k)


func test_tank_is_stronger_than_infantry():
	var inf := UnitFactory.get_type("infantry")
	var tank := UnitFactory.get_type("tank")
	assert_gt(tank.max_health, inf.max_health)
	assert_gt(tank.armor, inf.armor)
	assert_gt(tank.damage, inf.damage)


func test_air_units_are_air_domain():
	var ac := UnitFactory.get_type("aircraft")
	var heli := UnitFactory.get_type("helicopter")
	assert_true(ac.is_air())
	assert_true(heli.is_air())
	assert_gt(ac.cruise_altitude, 0.0)


func test_ground_cannot_attack_air_unless_flagged():
	var inf := UnitFactory.get_type("infantry")
	var ac := UnitFactory.get_type("aircraft")
	assert_false(inf.can_attack(ac))
	# Air defense can attack air.
	var ad := UnitFactory.get_type("air_defense")
	assert_true(ad.can_attack(ac))
	# Air defense cannot attack ground (configured).
	assert_false(ad.can_attack(inf))


func test_artillery_is_indirect():
	var art := UnitFactory.get_type("artillery")
	assert_true(art.indirect)
	assert_gt(art.range, 40.0)


func test_aircraft_can_dogfight():
	var ac := UnitFactory.get_type("aircraft")
	var other := UnitFactory.get_type("helicopter")
	assert_true(ac.can_attack(other))
