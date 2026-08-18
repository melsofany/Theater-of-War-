extends GutTest
## Tests for the Mega World Map (Phase 10c+): biome terrain costs, modern city
## district control split, civilian flee, urban guerrilla / line of sight,
## 9-chunk streaming and contested-city supply cuts.

var _gen: MegaWorldGenerator
var _city_gen: ModernCityGenerator
var _faction_red: Faction
var _faction_blue: Faction


func before_each():
	_gen = MegaWorldGenerator.new(42)
	_city_gen = ModernCityGenerator.new()
	_faction_red = Faction.make("red", "Red", Color(0.9, 0.2, 0.2), ["blue"])
	_faction_blue = Faction.make("blue", "Blue", Color(0.2, 0.4, 0.9), ["red"])


func after_each():
	Logistics.clear()
	Economy.clear()


# --- Terrain ----------------------------------------------------------------

func test_generator_produces_full_grid():
	_gen.generate(false)
	assert_eq(_gen.biomes.size(), MegaWorldGenerator.GRID_RES * MegaWorldGenerator.GRID_RES)
	assert_eq(_gen.heights.size(), MegaWorldGenerator.GRID_RES * MegaWorldGenerator.GRID_RES)


func test_all_fourteen_biomes_present():
	_gen.generate(false)
	var counts := _gen.biome_counts()
	for i in MegaWorldGenerator.Biome.size():
		assert_gt(counts.get(i, 0), 0, "biome %s missing" % MegaWorldGenerator.BIOME_NAME[i])


func test_plains_cost_is_baseline():
	_gen.generate(false)
	# Find a plains cell somewhere in the interior and confirm cost 1.0.
	var found := false
	for gz in range(1024, 3072, 64):
		for gx in range(1024, 3072, 64):
			if _gen.biome_at_grid(gx, gz) == MegaWorldGenerator.Biome.PLAINS:
				var w := _gen.grid_to_world(gx, gz)
				assert_eq(_gen.move_cost_at(w.x, w.z), 1.0)
				found = true
				break
		if found:
			break
	assert_true(found, "expected at least one plains cell")


func test_forest_costs_match_spec():
	_gen.generate(false)
	assert_eq(MegaWorldGenerator.MOVE_COST[MegaWorldGenerator.Biome.FOREST_LIGHT], 1.6)
	assert_eq(MegaWorldGenerator.MOVE_COST[MegaWorldGenerator.Biome.FOREST_DENSE], 2.2)


func test_swamp_cost_and_fuel_penalty():
	_gen.generate(false)
	assert_eq(MegaWorldGenerator.MOVE_COST[MegaWorldGenerator.Biome.SWAMP], 2.8)
	assert_true(MegaWorldGenerator.FUEL_PENALTY_BIOMES.has(MegaWorldGenerator.Biome.SWAMP))


func test_mountains_impassable():
	_gen.generate(false)
	assert_eq(MegaWorldGenerator.MOVE_COST[MegaWorldGenerator.Biome.MOUNTAIN], INF)
	assert_eq(MegaWorldGenerator.MOVE_COST[MegaWorldGenerator.Biome.SNOWY_MOUNTAIN], INF)
	assert_eq(MegaWorldGenerator.MOVE_COST[MegaWorldGenerator.Biome.SEA_DEEP], INF)


func test_hills_defence_bonus():
	assert_eq(MegaWorldGenerator.DEFENCE_BONUS[MegaWorldGenerator.Biome.HILLS], 1.5)


func test_travel_time_takes_real_time():
	# A ~4 km plains crossing at 4 m/s should take ~1000 s (cost 1.0).
	var from := Vector3(-2000.0, 0.0, 0.0)
	var to := Vector3(2000.0, 0.0, 0.0)
	# Generate the grid first, then force the corridor to plains for a
	# deterministic baseline-cost traversal.
	_gen.generate(false)
	_force_corridor_biome(from, to, MegaWorldGenerator.Biome.PLAINS)
	var t: float = _gen.travel_time_seconds(from, to, 4.0)
	assert_false(is_inf(t))
	assert_gt(t, 900.0)
	assert_lt(t, 1300.0)


func _force_corridor_biome(from: Vector3, to: Vector3, biome: int) -> void:
	# Overwrite the biome along a straight corridor for a deterministic cost test.
	var dist: float = from.distance_to(to)
	var dir: Vector3 = (to - from) / dist
	var steps: int = int(dist / MegaWorldGenerator.CELL) + 1
	for i in steps:
		var p: Vector3 = from + dir * float(i) * MegaWorldGenerator.CELL
		var g := _gen.world_to_grid(p.x, p.z)
		if _gen.in_bounds(g.x, g.y):
			_gen.biomes[_gen._idx(g.x, g.y)] = biome


# --- Modern city districts & control split ---------------------------------

func test_generates_six_cities():
	var centres: Array = []
	for i in 6:
		centres.append(Vector3(-4000.0 + i * 2000.0, 0.0, 0.0))
	var cities := _city_gen.generate(centres)
	assert_eq(cities.size(), 6)
	assert_eq(cities[0].city_name, "العاصمة الزجاجية")
	assert_eq(cities[5].city_name, "معقل الرماد")


func test_city_has_4_to_6_districts():
	var city := _city_gen.generate_city("Test", Vector3.ZERO, ["District_North", "District_South", "Downtown", "Industrial", "Port"])
	assert_gte(city.districts.size(), 4)
	assert_lte(city.districts.size(), 6)


func test_district_has_glass_towers_and_spawns():
	var city := _city_gen.generate_city("Test", Vector3.ZERO, ["Downtown", "District_North", "District_South", "Industrial"])
	var d: CityDistrict = city.districts[0]
	assert_gt(d.glass_tower_count, 0)
	assert_gte(d.civilian_spawn_points.size(), 150)
	assert_lte(d.civilian_spawn_points.size(), 400)


func test_glass_material_is_metallic_low_roughness():
	var city := _city_gen.generate_city("Test", Vector3.ZERO, ["Downtown", "District_North", "District_South", "Industrial"])
	var mmi := city.get_towers()
	assert_not_null(mmi)
	var mat := mmi.material_override as StandardMaterial3D
	assert_not_null(mat)
	assert_almost_eq(mat.metallic, 0.9, 0.01)
	assert_almost_eq(mat.roughness, 0.1, 0.01)


func test_city_district_control_split():
	var city := _city_gen.generate_city("Split", Vector3.ZERO, ["District_North", "District_South", "Downtown", "Industrial", "Port"])
	# Red holds north + industrial; blue holds south + downtown + port -> majority blue.
	city.get_district("District_North").control_faction = _faction_red
	city.get_district("Industrial").control_faction = _faction_red
	city.get_district("District_South").control_faction = _faction_blue
	city.get_district("Downtown").control_faction = _faction_blue
	city.get_district("Port").control_faction = _faction_blue
	# The city is split between two factions.
	assert_true(city.is_split())
	# Blue holds 3 of 5 -> majority.
	assert_eq(city.majority_owner().name, "blue")


func test_city_can_be_half_and_half():
	var city := _city_gen.generate_city("Half", Vector3.ZERO, ["District_North", "District_South", "Downtown", "Industrial"])
	city.get_district("District_North").control_faction = _faction_red
	city.get_district("District_South").control_faction = _faction_red
	city.get_district("Downtown").control_faction = _faction_blue
	city.get_district("Industrial").control_faction = _faction_blue
	assert_true(city.is_split())
	# Exactly 2-2 -> no majority -> contested (null).
	assert_eq(city.majority_owner(), null)


func test_district_capture_flips_control():
	var city := _city_gen.generate_city("Cap", Vector3.ZERO, ["District_North", "District_South", "Downtown", "Industrial"])
	var d := city.get_district("District_North")
	d.control_faction = _faction_blue
	d.resolve_capture(_faction_red)
	assert_eq(d.control_faction.name, "red")


# --- Civilian flee ----------------------------------------------------------

func test_civilian_flees_under_heavy_combat():
	var city := _city_gen.generate_city("Flee", Vector3.ZERO, ["Downtown", "District_North", "District_South", "Industrial"])
	add_child(city)
	var home := city.get_district("District_North")
	home.control_faction = _faction_blue
	home.set_population(100.0)
	var civ := CivilianNPC.new()
	civ.home_district = home
	civ.current_district = home
	civ.global_position = home.global_position
	add_child(civ)
	# Drive combat intensity above the flee threshold.
	home.add_combat_intensity(5.0)
	# Step the civilian; it should begin fleeing and drop home population.
	civ._process(0.1)
	assert_true(civ.is_fleeing)
	assert_lt(home.civilian_population, 100.0)
	remove_child(civ)
	civ.queue_free()
	remove_child(city)
	city.queue_free()


func test_civilian_exodus_reported():
	var city := _city_gen.generate_city("Exodus", Vector3.ZERO, ["Downtown", "District_North", "District_South", "Industrial"])
	add_child(city)
	var home := city.get_district("District_North")
	home.set_population(50.0)
	var reported := {"name": "", "count": 0}
	var civ := CivilianNPC.new()
	civ.home_district = home
	civ.current_district = home
	civ.global_position = home.global_position
	add_child(civ)
	civ.exodus_reported.connect(func(name: String, count: int):
		reported["name"] = name
		reported["count"] = count
	)
	home.add_combat_intensity(5.0)
	civ._process(0.1)
	assert_eq(reported["name"], "District_North")
	assert_gte(reported["count"], 1)
	remove_child(civ)
	civ.queue_free()
	remove_child(city)
	city.queue_free()


# --- Urban warfare ----------------------------------------------------------

func test_guerrilla_only_when_city_split():
	var city := _city_gen.generate_city("G", Vector3.ZERO, ["District_North", "District_South", "Downtown", "Industrial"])
	var uws := UrbanWarfareSystem.new()
	assert_false(uws.is_guerrilla_active(city))
	city.get_district("District_North").control_faction = _faction_red
	city.get_district("District_South").control_faction = _faction_blue
	assert_true(uws.is_guerrilla_active(city))


func test_building_cover_bonus_x1_8():
	var city := _city_gen.generate_city("G", Vector3.ZERO, ["District_North", "District_South", "Downtown", "Industrial"])
	city.get_district("District_North").control_faction = _faction_red
	city.get_district("District_South").control_faction = _faction_blue
	var uws := UrbanWarfareSystem.new()
	# A position inside the north district footprint.
	var north := city.get_district("District_North")
	var pos := north.global_position + Vector3(north.footprint.size.x * 0.25, 0.0, north.footprint.size.y * 0.25)
	assert_almost_eq(uws.cover_bonus_for(city, pos), UrbanWarfareSystem.BUILDING_COVER_BONUS, 0.01)
	assert_almost_eq(uws.cover_bonus_for(city, pos), 1.8, 0.01)


func test_los_blocked_by_tower():
	var city := _city_gen.generate_city("G", Vector3.ZERO, ["District_North", "District_South", "Downtown", "Industrial"])
	city.get_district("District_North").control_faction = _faction_red
	city.get_district("District_South").control_faction = _faction_blue
	var uws := UrbanWarfareSystem.new()
	var mmi := city.get_towers()
	assert_not_null(mmi)
	# Pick a segment that crosses a tower footprint centre.
	var mm := mmi.multimesh
	assert_gt(mm.instance_count, 0)
	var t: Transform3D = mm.get_instance_transform(0)
	var c := Vector3(t.origin.x, 0.0, t.origin.z)
	# From one side of the tower to the other -> LOS blocked.
	var from := c + Vector3(-100.0, 0.0, 0.0)
	var to := c + Vector3(100.0, 0.0, 0.0)
	assert_false(uws.has_line_of_sight(city, from, to))
	# A clear segment far from any tower -> LOS open.
	var open_from := Vector3(-20000.0, 0.0, -20000.0)
	var open_to := Vector3(-19000.0, 0.0, -19000.0)
	assert_true(uws.has_line_of_sight(city, open_from, open_to))


# --- Streaming & logistics --------------------------------------------------

func test_nine_chunk_streaming():
	var cm := ChunkManager.configure_for_9_chunks(256.0)
	var focus := Vector3(1000.0, 0.0, 1000.0)
	var diff := cm.update(focus)
	assert_eq(cm.active_count(), 9)


func test_contested_city_cuts_supply_route():
	Logistics.clear()
	var city_centre := Vector3(0.0, 0.0, 0.0)
	Logistics.register_contested_city(city_centre)
	# A supply route passing straight through the city centre is cut.
	assert_true(Logistics.is_supply_route_cut(Vector3(-2000.0, 0.0, 0.0), Vector3(2000.0, 0.0, 0.0)))
	# A route far from the contested city is not cut.
	assert_false(Logistics.is_supply_route_cut(Vector3(-19000.0, 0.0, -19000.0), Vector3(-18000.0, 0.0, -18000.0)))


func test_supply_travel_time_inf_when_cut():
	Logistics.clear()
	Logistics.register_contested_city(Vector3.ZERO)
	var cost_fn := func(_p: Vector3) -> float:
		return 1.0
	var t: float = Logistics.supply_travel_time(Vector3(-1000.0, 0.0, 0.0), Vector3(1000.0, 0.0, 0.0), cost_fn)
	assert_true(is_inf(t))


func test_supply_travel_time_finite_when_clear():
	Logistics.clear()
	var cost_fn := func(_p: Vector3) -> float:
		return 1.0
	var t: float = Logistics.supply_travel_time(Vector3(-1000.0, 0.0, 0.0), Vector3(1000.0, 0.0, 0.0), cost_fn)
	assert_false(is_inf(t))
	assert_gt(t, 0.0)


# --- Road network (OSM roads for supply trucks) -----------------------------

func test_road_network_connects_nearby_cities():
	_gen.generate(false)
	var rng := RoadNetworkGenerator.new()
	var centres := [Vector3(-5000.0, 0.0, 0.0), Vector3(5000.0, 0.0, 0.0), Vector3(0.0, 0.0, 8000.0)]
	var roads := rng.generate_procedural(centres, _gen)
	# Three nearby pairs -> at least 3 roads.
	assert_gte(roads.size(), 3)
	for r in roads:
		assert_gte(r.size(), 2)


func test_road_route_bends_around_impassable():
	# Place two centres separated by a wall of mountains (impassable) so the
	# generator must bend the road through a passable midpoint.
	_gen.generate(false)
	var centres := [Vector3(-3000.0, 0.0, 0.0), Vector3(3000.0, 0.0, 0.0)]
	# Paint an impassable mountain wall along x=0 between the two centres.
	for z in range(-1024, 1024, 8):
		var gx := _gen.world_to_grid(0.0, float(z)).x
		var gz := _gen.world_to_grid(0.0, float(z)).y
		for dx in range(-4, 5):
			if _gen.in_bounds(gx + dx, gz):
				_gen.biomes[_gen._idx(gx + dx, gz)] = MegaWorldGenerator.Biome.MOUNTAIN
	var rng := RoadNetworkGenerator.new()
	var roads := rng.generate_procedural(centres, _gen)
	assert_gte(roads.size(), 1)
	var r: PackedVector2Array = roads[0]
	# A bent road has more than the two endpoint waypoints.
	assert_gt(r.size(), 2)
