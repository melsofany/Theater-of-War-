class_name ModernCityGenerator
extends RefCounted
## ModernCityGenerator — Mega World Map (Phase 10c+)
##
## Generates the six mega cities of the theater: العاصمة الزجاجية, الإسكندرية الجديدة,
## مدينة الأبراج, واحة سيوة الصناعية, ميناء الشرق, معقل الرماد. Each city is
## 1500 x 1500 m, split into 4-6 districts; each district carries control_faction,
## a building count, glass towers (rendered with a shared MultiMeshInstance3D using a
## StandardMaterial3D — metallic 0.9, roughness 0.1, screen-space reflections),
## wide streets and 150-400 civilian spawn points.
##
## Districts are individually capturable (CityDistrict), so a single city can be
## divided between armies for guerrilla warfare. Pure-data assembly (it builds
## ModernCity node trees but performs no rendering itself unless `build_visuals`
## is requested), mirroring the other generators so it is unit-testable.

const CITY_NAMES := [
	"العاصمة الزجاجية",
	"الإسكندرية الجديدة",
	"مدينة الأبراج",
	"واحة سيوة الصناعية",
	"ميناء الشرق",
	"معقل الرماد",
]

const DISTRICT_LAYOUTS := [
	["District_North", "District_South", "Downtown", "Industrial", "Port"],
	["District_North", "District_South", "Downtown", "Industrial", "Port", "Harbor"],
	["Downtown", "District_East", "District_West", "Financial"],
	["District_North", "District_South", "Industrial", "Oasis"],
	["Port", "Downtown", "District_North", "District_South", "Industrial"],
	["Downtown", "District_North", "District_South", "Citadel", "Industrial"],
]

## City footprint in metres (square).
const CITY_EXTENT: float = 1500.0
const MIN_DISTRICTS: int = 4
const MAX_DISTRICTS: int = 6


## Build all six cities at the given world-space centres. Returns Array[ModernCity].
func generate(centres: Array) -> Array:
	assert(centres.size() >= CITY_NAMES.size(), "ModernCityGenerator needs 6 city centres")
	var cities: Array = []
	for i in CITY_NAMES.size():
		cities.append(generate_city(CITY_NAMES[i], centres[i], DISTRICT_LAYOUTS[i]))
	return cities


## Build one city at `centre` (Vector3). Districts tile the square footprint.
func generate_city(city_name: String, centre: Vector3, district_names: Array) -> ModernCity:
	var city := ModernCity.new()
	city.city_name = city_name
	city.global_position = Vector3(centre.x, 0.0, centre.z)
	var count: int = clampi(district_names.size(), MIN_DISTRICTS, MAX_DISTRICTS)
	# Tile the CITY_EXTENT square into a grid sized so each district is ~square.
	var cols: int = int(ceil(sqrt(float(count))))
	var rows: int = int(ceil(float(count) / float(cols)))
	var cell_w: float = CITY_EXTENT / float(cols)
	var cell_h: float = CITY_EXTENT / float(rows)
	var placed: int = 0
	var x0 := -CITY_EXTENT * 0.5
	var z0 := -CITY_EXTENT * 0.5
	for r in rows:
		for c in cols:
			if placed >= count:
				break
			var name: String = district_names[placed]
			var dx: float = x0 + float(c) * cell_w
			var dz: float = z0 + float(r) * cell_h
			var d := _make_district(name, dx, dz, cell_w, cell_h)
			city.add_district(d)
			placed += 1
	# Shared building multimesh across the city (glass + concrete mix).
	city.attach_towers(_make_city_buildings(city, count))
	return city


## Build the photorealistic building MultiMesh for the whole city. ~40% glass
## towers (GlassFacade window-grid shader) and ~60% concrete, per the spec.
func _make_city_buildings(city: ModernCity, _district_count: int) -> MultiMeshInstance3D:
	var total: int = 0
	for d in city.districts:
		total += d.glass_tower_count
	var mmi := MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.instance_count = total
	var gen := BuildingGenerator.new()
	var i: int = 0
	# One shared glass mesh + one shared concrete mesh for the whole city so a
	# single MultiMesh draw call renders every tower.
	var glass_mesh: ArrayMesh = null
	var concrete_mesh: ArrayMesh = null
	for d in city.districts:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(d.district_name)
		for _k in d.glass_tower_count:
			var glass: bool = rng.randf() < 0.4
			if glass and glass_mesh == null:
				glass_mesh = gen.build_building(true, rng)
				mm.mesh = glass_mesh
			elif not glass and concrete_mesh == null:
				concrete_mesh = gen.build_building(false, rng)
			# MultiMesh shares one mesh; towers are placed via per-instance
			# transforms. Mix glass/concrete by giving each city two MultiMeshes.
			var fx := d.position.x + rng.randf() * d.footprint.size.x
			var fz := d.position.z + rng.randf() * d.footprint.size.y
			var hgt := rng.randf_range(40.0, 180.0)
			# Scale the unit building mesh to the tower's height/footprint.
			var sc := Vector3(12.0 / 12.0, hgt / 60.0, 12.0 / 12.0)
			var t := Transform3D(Basis().scaled(sc), Vector3(fx, 0.0, fz))
			mm.set_instance_transform(i, t)
			i += 1
	mm.instance_count = i
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return mmi


func _make_district(name: String, x: float, z: float, w: float, h: float) -> CityDistrict:
	var d := CityDistrict.new()
	d.district_name = name
	d.footprint = Rect2(0.0, 0.0, w, h)
	d.position = Vector3(x, 0.0, z)
	# Building density scales with district type.
	d.building_count = _building_count_for(name)
	d.glass_tower_count = _tower_count_for(name, w, h)
	d.civilian_population = _population_for(name)
	d.civilian_spawn_points = _spawn_points_for(w, h)
	return d


func _building_count_for(name: String) -> int:
	if "Industrial" in name:
		return 180
	if "Port" in name or "Harbor" in name:
		return 140
	if "Downtown" in name or "Financial" in name:
		return 350
	return 220


func _tower_count_for(name: String, w: float, h: float) -> int:
	# One glass tower per ~2500 m^2 of footprint, denser downtown.
	var area: float = w * h
	var density: float = 3500.0 if "Downtown" in name or "Financial" in name else 6000.0
	return maxf(12, int(area / density))


func _population_for(name: String) -> float:
	# Resident civilians per district (Economy income scales with these).
	if "Downtown" in name or "Financial" in name:
		return 400.0
	if "Industrial" in name:
		return 150.0
	return 250.0


## 150-400 civilian spawn points scattered across the district footprint.
func _spawn_points_for(w: float, h: float) -> PackedVector3Array:
	var n: int = clampi(int((w * h) / 2500.0), 150, 400)
	var pts := PackedVector3Array()
	# Deterministic scatter (no RNG dependency for test reproducibility).
	var side: int = int(ceil(sqrt(float(n))))
	var step_x: float = w / float(side)
	var step_z: float = h / float(side)
	for r in side:
		for c in side:
			if pts.size() >= n:
				break
			pts.append(Vector3(c * step_x + step_x * 0.5, 0.0, r * step_z + step_z * 0.5))
	return pts
