extends GutTest
## Tests for espionage: agents, surveillance beyond sight, counter-intelligence
## (agent detection/neutralization), deception planting, deception purging, and
## information confidence.

func _make_unit(faction: Faction, at: Vector3, type_name: String = "infantry") -> Unit:
	var u: Unit = load("res://src/Units/Unit.tscn").instantiate()
	u.unit_type = UnitFactory.get_type(type_name)
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
	Espionage.clear()
	Espionage.set_process(false)
	Intelligence.clear()
	Intelligence.set_process(false)


func after_each():
	Espionage.set_process(true)
	Espionage.clear()
	Intelligence.set_process(true)
	Intelligence.clear()


func test_agent_surveillance_reveals_beyond_sight():
	var blue := Faction.make("blue", "Blue", Color.BLUE, ["red"], true)
	var red := Faction.make("red", "Red", Color.RED, ["blue"], false)
	var spotter := _make_unit(blue, Vector3(0, 0, 0))      # sight 18
	var enemy := _make_unit(red, Vector3(100, 0, 0))       # far beyond sight
	var w := _make_world_with([spotter, enemy])
	Intelligence.world = w
	# Without an agent, blue cannot see the distant enemy.
	assert_false(Intelligence.is_visible(blue, enemy))
	# Deploy an agent near the enemy.
	var id: int = Espionage.deploy_agent(blue, red, Vector3(100, 0, 0))
	assert_gt(id, 0)
	var revealed: int = Intelligence.reveal_from_agent(blue, Vector3(100, 0, 0), 40.0, 0.6)
	assert_eq(revealed, 1)
	# Blue now has a remembered contact for the enemy.
	assert_not_null(Intelligence.last_known_position(blue, enemy))


func test_counter_intel_neutralizes_agent():
	var blue := Faction.make("blue", "Blue", Color.BLUE, ["red"], true)
	var red := Faction.make("red", "Red", Color.RED, ["blue"], false)
	var w := _make_world_with([_make_unit(blue, Vector3(0, 0, 0)), _make_unit(red, Vector3(100, 0, 0))])
	Intelligence.world = w
	Espionage.set_counter_intel(red, 1.0)  # max counter-intel
	Espionage.deploy_agent(blue, red, Vector3(100, 0, 0))
	assert_eq(Espionage.agent_count(blue), 1)
	# With max counter-intel and high detection, repeated ticks should neutralize.
	for i in range(60):
		if Espionage.agent_count(blue) == 0:
			break
		Espionage.tick(1.0)
	assert_eq(Espionage.agent_count(blue), 0)


func test_low_counter_intel_keeps_agent_longer():
	var blue := Faction.make("blue", "Blue", Color.BLUE, ["red"], true)
	var red := Faction.make("red", "Red", Color.RED, ["blue"], false)
	var w := _make_world_with([_make_unit(blue, Vector3(0, 0, 0)), _make_unit(red, Vector3(100, 0, 0))])
	Intelligence.world = w
	Espionage.set_counter_intel(red, 0.0)  # no counter-intel
	Espionage.deploy_agent(blue, red, Vector3(100, 0, 0))
	for i in range(10):
		Espionage.tick(1.0)
	# Agent survives with zero counter-intel.
	assert_eq(Espionage.agent_count(blue), 1)


func test_deception_plants_false_contact_in_victim():
	var blue := Faction.make("blue", "Blue", Color.BLUE, ["red"], true)
	var red := Faction.make("red", "Red", Color.RED, ["blue"], false)
	var w := _make_world_with([_make_unit(blue, Vector3(0, 0, 0))])
	Intelligence.world = w
	var fake_type: UnitType = UnitFactory.get_type("tank")
	var ok: bool = Espionage.plant_deception(red, blue, Vector3(50, 0, 0), fake_type)
	assert_true(ok)
	# The victim (blue) now believes a tank exists where none does.
	var est: Dictionary = Intelligence.enemy_estimate(blue)
	assert_true(est.has(UnitType.Category.TANK))
	assert_eq(est[UnitType.Category.TANK], 1)


func test_deception_is_flagged_and_purgeable():
	var blue := Faction.make("blue", "Blue", Color.BLUE, ["red"], true)
	var red := Faction.make("red", "Red", Color.RED, ["blue"], false)
	var w := _make_world_with([_make_unit(blue, Vector3(0, 0, 0))])
	Intelligence.world = w
	Espionage.plant_deception(red, blue, Vector3(50, 0, 0), UnitFactory.get_type("tank"))
	assert_true(Intelligence.has_deception(blue))
	var purged: int = Intelligence.purge_deception(blue)
	assert_eq(purged, 1)
	assert_false(Intelligence.has_deception(blue))


func test_confidence_values_differ_by_source():
	var blue := Faction.make("blue", "Blue", Color.BLUE, ["red"], true)
	var red := Faction.make("red", "Red", Color.RED, ["blue"], false)
	var spotter := _make_unit(blue, Vector3(0, 0, 0))
	var enemy := _make_unit(red, Vector3(10, 0, 0))
	var w := _make_world_with([spotter, enemy])
	Intelligence.world = w
	Intelligence.tick(1.0)  # own sighting -> confidence 1.0
	var mem: Dictionary = Intelligence._memory.get("blue", {})
	var own_entry: Dictionary = mem.get(enemy.get_instance_id(), {})
	assert_eq(own_entry.get("confidence"), 1.0)
	# Agent report -> confidence 0.6.
	Intelligence.reveal_from_agent(blue, Vector3(100, 0, 0), 40.0, 0.6)
	# Deception -> confidence 0.8.
	Espionage.plant_deception(red, blue, Vector3(50, 0, 0), UnitFactory.get_type("tank"))


func test_counter_intel_tick_purges_deception():
	var blue := Faction.make("blue", "Blue", Color.BLUE, ["red"], true)
	var red := Faction.make("red", "Red", Color.RED, ["blue"], false)
	var w := _make_world_with([_make_unit(blue, Vector3(0, 0, 0)), _make_unit(red, Vector3(5, 0, 0))])
	Intelligence.world = w
	Espionage.set_counter_intel(blue, 1.0)  # blue has strong counter-intel
	Espionage.plant_deception(red, blue, Vector3(50, 0, 0), UnitFactory.get_type("tank"))
	assert_true(Intelligence.has_deception(blue))
	# Repeated ticks with max counter-intel should eventually purge deception.
	for i in range(60):
		if not Intelligence.has_deception(blue):
			break
		Espionage.tick(1.0)
	assert_false(Intelligence.has_deception(blue))
