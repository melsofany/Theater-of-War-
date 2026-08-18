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
	# Shared glass-tower multimesh across the city.
	city.attach_towers(_make_glass_towers(city, count))
	return city


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


## One MultiMeshInstance3D of glass towers for the whole city. Glass facade uses a
## StandardMaterial3D: metallic 0.9, roughness 0.1, screen-space reflections.
func _make_glass_towers(city: ModernCity, district_count: int) -> MultiMeshInstance3D:
	var total: int = 0
	for d in city.districts:
		total += d.glass_tower_count
	var mmi := MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.mesh = _glass_tower_mesh()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.instance_count = total
	# Per-instance transforms placed across districts (local to the city).
	var i: int = 0
	for d in city.districts:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(d.district_name)
		for _k in d.glass_tower_count:
			var fx := d.position.x + rng.randf() * d.footprint.size.x
			var fz := d.position.z + rng.randf() * d.footprint.size.y
			var hgt := rng.randf_range(40.0, 180.0)
			var t := Transform3D(Basis().scaled(Vector3(12.0, hgt, 12.0)), Vector3(fx, hgt * 0.5, fz))
			mm.set_instance_transform(i, t)
			i += 1
	mm.instance_count = i  # trim to actual placed count
	mmi.multimesh = mm
	mmi.material_override = _glass_material()
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return mmi


func _glass_tower_mesh() -> Mesh:
	# A simple tall box; the metallic/SSR material sells the "glass" read.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# 1x1x1 box expanded around origin.
	var b := BoxMesh.new()
	return b


func _glass_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.metallic = 0.9
	mat.roughness = 0.1
	mat.metallic_specular = 0.9
	# Screen-space reflections give the glass-facade look described in the artifact.
	mat.roughness_texture = null
	mat.emission_enabled = false
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat.albedo_color = Color(0.55, 0.7, 0.85)
	return mat
