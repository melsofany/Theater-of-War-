extends GutTest
## Tests for Phase 10b: modding (data-driven units), spatial grid (performance),
## balance config, chunk streaming math, networking session state.

# --- Modding ---------------------------------------------------------------

func test_register_from_dict_creates_unit_type():
	UnitFactory.register_from_dict("test_gunner", {
		"display_name": "Test Gunner",
		"category": "INFANTRY",
		"max_health": 120,
		"damage": 15,
		"range": 20,
	})
	var t: UnitType = UnitFactory.get_type("test_gunner")
	assert_eq(t.display_name, "Test Gunner")
	assert_eq(t.max_health, 120)
	assert_eq(t.damage, 15)
	assert_eq(t.category, UnitType.Category.INFANTRY)


func test_register_from_dict_domain_naval():
	UnitFactory.register_from_dict("test_boat", {
		"category": "VEHICLE",
		"domain": "NAVAL",
		"max_health": 300,
	})
	var t: UnitType = UnitFactory.get_type("test_boat")
	assert_true(t.is_naval())
	assert_false(t.is_air())


func test_register_from_dict_air_attacks_air_by_default():
	UnitFactory.register_from_dict("test_jet", {
		"category": "AIRCRAFT",
		"domain": "AIR",
		"max_health": 70,
	})
	var t: UnitType = UnitFactory.get_type("test_jet")
	assert_true(t.can_attack_air)


func test_modloader_loads_sample_mod():
	var before: int = ModLoader.loaded_count
	ModLoader.load_all()
	# The sample mod ships two unit types.
	assert_gte(ModLoader.loaded_count, 2)
	assert_true(ModLoader.loaded_keys.has("heavy_tank"))
	assert_true(ModLoader.loaded_keys.has("frigate"))
	var t: UnitType = UnitFactory.get_type("heavy_tank")
	assert_eq(t.display_name, "Heavy Tank")
	assert_eq(t.max_health, 450)
	var fr: UnitType = UnitFactory.get_type("frigate")
	assert_true(fr.is_naval())
	# Sanity: pre-existing types still present.
	assert_not_null(UnitFactory.get_type("infantry"))


# --- SpatialGrid -----------------------------------------------------------

func _make_unit_at(at: Vector3) -> Unit:
	var u: Unit = load("res://src/Units/Unit.tscn").instantiate()
	u.unit_type = UnitFactory.get_type("infantry")
	u.global_position = at
	add_child(u)
	return u


func test_spatial_grid_query_radius():
	var grid := SpatialGrid.new(10.0)
	var a := _make_unit_at(Vector3(0, 0, 0))
	var b := _make_unit_at(Vector3(5, 0, 0))
	var c := _make_unit_at(Vector3(50, 0, 0))
	grid.insert(a)
	grid.insert(b)
	grid.insert(c)
	var near: Array = grid.query_radius(Vector3(0, 0, 0), 8.0)
	assert_eq(near.size(), 2)
	var far: Array = grid.query_radius(Vector3(0, 0, 0), 100.0)
	assert_eq(far.size(), 3)


func test_spatial_grid_remove_and_count():
	var grid := SpatialGrid.new(10.0)
	var a := _make_unit_at(Vector3(0, 0, 0))
	var b := _make_unit_at(Vector3(3, 0, 0))
	grid.insert(a)
	grid.insert(b)
	assert_eq(grid.count(), 2)
	grid.remove(a)
	assert_eq(grid.count(), 1)
	assert_eq(grid.query_radius(Vector3(0, 0, 0), 10.0).size(), 1)


func test_spatial_grid_update_moves_cell():
	var grid := SpatialGrid.new(10.0)
	var a := _make_unit_at(Vector3(0, 0, 0))
	grid.insert(a)
	grid.update(a, Vector3(0, 0, 0))  # no move
	assert_eq(grid.count(), 1)
	a.global_position = Vector3(100, 0, 0)
	grid.update(a, Vector3(0, 0, 0))
	assert_eq(grid.query_radius(Vector3(0, 0, 0), 10.0).size(), 0)
	assert_eq(grid.query_radius(Vector3(100, 0, 0), 10.0).size(), 1)


# --- Balance ---------------------------------------------------------------

func before_each_balance():
	Balance.reset()


func test_balance_defaults_are_neutral():
	Balance.reset()
	assert_eq(Balance.damage_multiplier, 1.0)
	assert_eq(Balance.income_multiplier, 1.0)
	assert_eq(Balance.cost_multiplier, 1.0)


func test_balance_scaled_damage():
	Balance.damage_multiplier = 2.0
	assert_eq(Balance.scaled_damage(10.0), 20.0)
	Balance.reset()
	assert_eq(Balance.scaled_damage(10.0), 10.0)


func test_balance_preset_easy():
	Balance.apply_preset("easy")
	assert_eq(Balance.damage_multiplier, 1.2)
	assert_eq(Balance.income_multiplier, 1.3)


func test_balance_preset_hard():
	Balance.apply_preset("hard")
	assert_eq(Balance.damage_multiplier, 0.8)
	assert_eq(Balance.income_multiplier, 0.8)


func test_balance_preset_normal_resets():
	Balance.damage_multiplier = 5.0
	Balance.apply_preset("normal")
	assert_eq(Balance.damage_multiplier, 1.0)


# --- ChunkManager ----------------------------------------------------------

func test_chunk_key_of():
	var k: Vector2i = ChunkManager.chunk_key_of(Vector3(70, 0, 0), 64.0)
	assert_eq(k, Vector2i(1, 0))
	var k2: Vector2i = ChunkManager.chunk_key_of(Vector3(-70, 0, 0), 64.0)
	assert_eq(k2, Vector2i(-2, 0))


func test_chunk_manager_update_loads_unloads():
	var cm := ChunkManager.new(64.0, 160.0)
	cm.clear()
	var r1: Dictionary = cm.update(Vector3(0, 0, 0))
	assert_true(r1["loaded"].size() > 0)
	assert_eq(r1["unloaded"].size(), 0)
	assert_true(cm.active_count() > 0)
	# Move far away; old chunks unload, new ones load.
	var r2: Dictionary = cm.update(Vector3(10000, 0, 0))
	assert_true(r2["unloaded"].size() > 0)
	assert_true(r2["loaded"].size() > 0)


func test_chunk_manager_desired_around_focus():
	var cm := ChunkManager.new(64.0, 100.0)
	var desired: Array = cm.desired_chunks(Vector3(0, 0, 0))
	# The origin chunk must be included.
	assert_true(desired.has(Vector2i(0, 0)))
	# A chunk far outside the radius must not be.
	assert_false(desired.has(Vector2i(100, 100)))


# --- Networking ------------------------------------------------------------

func before_each_net():
	Networking.disconnect_peer()

func after_each_net():
	Networking.disconnect_peer()


func test_networking_starts_offline():
	Networking.disconnect_peer()
	assert_eq(Networking.state, Networking.State.OFFLINE)
	assert_false(Networking.is_online())


func test_networking_host_enters_hosting():
	var ok: bool = Networking.host(13099, 4)
	assert_true(ok)
	assert_eq(Networking.state, Networking.State.HOSTING)
	assert_true(Networking.is_server())
	Networking.disconnect_peer()
	assert_eq(Networking.state, Networking.State.OFFLINE)


func test_networking_join_enters_connecting():
	# Joining a likely-dead address still enters CONNECTING.
	var ok: bool = Networking.join("127.0.0.1", 13098)
	assert_true(ok)
	assert_eq(Networking.state, Networking.State.CONNECTING)
	Networking.disconnect_peer()
	assert_eq(Networking.state, Networking.State.OFFLINE)
