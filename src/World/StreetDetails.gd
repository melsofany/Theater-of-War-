extends Node3D
class_name StreetDetails

const CONCRETE_MATERIAL: Material = preload("res://assets/materials/UrbanConcrete.tres")
const FOLIAGE_MATERIAL: Material = preload("res://assets/materials/UrbanFoliage.tres")
const WINDOW_MATERIAL: Material = preload("res://assets/materials/WindowGrid.tres")
const MARKING_MATERIAL: Material = preload("res://assets/materials/RoadMarking.tres")
const KAYKIT_CAR_PATHS: Array[String] = [
	"res://assets/cc0/kaykit_city_builder_bits/Assets/glb/car_sedan.glb",
	"res://assets/cc0/kaykit_city_builder_bits/Assets/glb/car_taxi.glb",
	"res://assets/cc0/kaykit_city_builder_bits/Assets/glb/car_hatchback.glb",
	"res://assets/cc0/kaykit_city_builder_bits/Assets/glb/car_stationwagon.glb"
]
const KAYKIT_STREETLIGHT_PATH := "res://assets/cc0/kaykit_city_builder_bits/Assets/glb/streetlight.glb"
const KAYKIT_BENCH_PATH := "res://assets/cc0/kaykit_city_builder_bits/Assets/glb/bench.glb"

var _kaykit_car_scenes: Array[Node3D] = []
var _kaykit_streetlight_scene: Node3D = null
var _kaykit_bench_scene: Node3D = null
var _kaykit_load_attempted := false
var _rng := RandomNumberGenerator.new()
var _asphalt_material: Material

func build(extent: Vector2, is_contested: bool, seed_value: int) -> void:
	_rng.seed = abs(seed_value * 977 + 41)
	_load_kaykit_assets()
	_asphalt_material = _load_asphalt_material()
	_build_city_base(extent)
	_build_urban_block_ground(extent)
	_build_roads(extent)
	_build_crosswalks()
	_build_tree_multimesh(extent)
	_build_park_islands(extent)
	_build_parked_cars(extent)
	_build_kaykit_street_props()
	if is_contested:
		_build_barricades()

func _load_kaykit_assets() -> void:
	if _kaykit_load_attempted:
		return
	_kaykit_load_attempted = true
	for path in KAYKIT_CAR_PATHS:
		var document := GLTFDocument.new()
		var state := GLTFState.new()
		if document.append_from_file(path, state) == OK:
			var scene := document.generate_scene(state)
			if scene is Node3D:
				_kaykit_car_scenes.append(scene)
	for path_and_target in [[KAYKIT_STREETLIGHT_PATH, "streetlight"], [KAYKIT_BENCH_PATH, "bench"]]:
		var document := GLTFDocument.new()
		var state := GLTFState.new()
		if document.append_from_file(path_and_target[0], state) == OK:
			var scene := document.generate_scene(state)
			if scene is Node3D:
				if path_and_target[1] == "streetlight":
					_kaykit_streetlight_scene = scene
				else:
					_kaykit_bench_scene = scene

func _load_asphalt_material() -> Material:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.075, 0.085, 0.09, 1.0)
	material.roughness = 0.88
	material.uv1_scale = Vector3(8.0, 8.0, 8.0)
	var albedo := Image.load_from_file("res://assets/textures/terrain/road_asphalt.png")
	var normal := Image.load_from_file("res://assets/textures/terrain/road_normal.png")
	var roughness := Image.load_from_file("res://assets/textures/terrain/road_roughness.png")
	if albedo:
		material.albedo_texture = ImageTexture.create_from_image(albedo)
	if normal:
		material.normal_enabled = true
		material.normal_texture = ImageTexture.create_from_image(normal)
	if roughness:
		material.roughness_texture = ImageTexture.create_from_image(roughness)
	return material

func _build_city_base(extent: Vector2) -> void:
	# A continuous paved slab is the urban fabric beneath blocks and roads.
	# It is deliberately flat; Terrain remains responsible for the surrounding world.
	var base_material := StandardMaterial3D.new()
	base_material.albedo_color = Color(0.18, 0.20, 0.21, 1.0)
	base_material.roughness = 0.96
	var base := _box(Vector3(extent.x, 0.18, extent.y), base_material)
	base.position = Vector3(0.0, 0.05, 0.0)
	add_child(base)

func _build_urban_block_ground(extent: Vector2) -> void:
	# Paved urban blocks fill the space between the road corridors. This prevents
	# the city from floating on a rural green/gray plane in the strategic view.
	var centers := [-150.0, -60.0, 60.0, 150.0]
	for z in centers:
		for x in centers:
			var block := _box(Vector3(52.0, 0.16, 52.0), CONCRETE_MATERIAL)
			block.position = Vector3(x, 0.28, z)
			add_child(block)

func _build_roads(extent: Vector2) -> void:

	# The target image is readable because the urban blocks are separated by
	# broad, dark streets instead of floating on a green plane.
	var primary_positions: Array[float] = [-120.0, 0.0, 120.0]
	for z in primary_positions:
		_add_x_corridor(extent.x, z, 18.0)
	for x in primary_positions:
		_add_z_corridor(extent.y, x, 18.0)

func _add_x_corridor(length: float, z: float, width: float) -> void:
	var road := _box(Vector3(length, 0.20, width), _asphalt_material)
	road.position = Vector3(0, 0.44, z)
	add_child(road)
	_add_sidewalk(Vector3(length, 0.18, 3.0), Vector3(0, 0.59, z - width * 0.5 - 2.0))
	_add_sidewalk(Vector3(length, 0.18, 3.0), Vector3(0, 0.59, z + width * 0.5 + 2.0))
	var median := _box(Vector3(length, 0.12, 1.25), FOLIAGE_MATERIAL)
	median.position = Vector3(0, 0.57, z)
	add_child(median)
	for x in range(-160, 161, 16):
		var dash := _box(Vector3(7.0, 0.045, 0.18), MARKING_MATERIAL)
		dash.position = Vector3(float(x), 0.57, z - 4.0)
		add_child(dash)
		dash = _box(Vector3(7.0, 0.045, 0.18), MARKING_MATERIAL)
		dash.position = Vector3(float(x), 0.57, z + 4.0)
		add_child(dash)

func _add_z_corridor(length: float, x: float, width: float) -> void:
	var road := _box(Vector3(width, 0.20, length), _asphalt_material)
	road.position = Vector3(x, 0.45, 0)
	add_child(road)
	_add_sidewalk(Vector3(3.0, 0.18, length), Vector3(x - width * 0.5 - 2.0, 0.60, 0))
	_add_sidewalk(Vector3(3.0, 0.18, length), Vector3(x + width * 0.5 + 2.0, 0.60, 0))
	var median := _box(Vector3(1.25, 0.12, length), FOLIAGE_MATERIAL)
	median.position = Vector3(x, 0.58, 0)
	add_child(median)
	for z in range(-160, 161, 16):
		var dash := _box(Vector3(0.18, 0.045, 7.0), MARKING_MATERIAL)
		dash.position = Vector3(x - 4.0, 0.58, float(z))
		add_child(dash)
		dash = _box(Vector3(0.18, 0.045, 7.0), MARKING_MATERIAL)
		dash.position = Vector3(x + 4.0, 0.58, float(z))
		add_child(dash)

func _add_sidewalk(size: Vector3, position: Vector3) -> void:
	var sidewalk := _box(size, CONCRETE_MATERIAL)
	sidewalk.position = position
	add_child(sidewalk)

func _build_crosswalks() -> void:
	var intersections: Array[Vector2] = [
		Vector2(-120.0, -120.0), Vector2(-120.0, 0.0), Vector2(-120.0, 120.0),
		Vector2(0.0, -120.0), Vector2(0.0, 0.0), Vector2(0.0, 120.0),
		Vector2(120.0, -120.0), Vector2(120.0, 0.0), Vector2(120.0, 120.0)
	]
	for intersection in intersections:
		for offset in [-6.0, -2.0, 2.0, 6.0]:
			var stripe_x := _box(Vector3(1.1, 0.055, 6.5), MARKING_MATERIAL)
			stripe_x.position = Vector3(intersection.x + offset, 0.70, intersection.y - 11.5)
			add_child(stripe_x)
			var stripe_z := _box(Vector3(6.5, 0.055, 1.1), MARKING_MATERIAL)
			stripe_z.position = Vector3(intersection.x - 11.5, 0.71, intersection.y + offset)
			add_child(stripe_z)

func _build_tree_multimesh(extent: Vector2) -> void:
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.20
	trunk_mesh.bottom_radius = 0.30
	trunk_mesh.height = 3.6
	trunk_mesh.radial_segments = 8
	var crowns := MultiMeshInstance3D.new()
	var crown_mesh := SphereMesh.new()
	crown_mesh.radius = 2.0
	crown_mesh.height = 3.8
	crown_mesh.radial_segments = 12
	crown_mesh.rings = 6
	var crown_multi := MultiMesh.new()
	crown_multi.transform_format = MultiMesh.TRANSFORM_3D
	crown_multi.mesh = crown_mesh
	var tree_positions: Array[Vector3] = []
	for z in [-131.0, -11.0, 109.0]:
		for x in range(-150, 151, 30):
			tree_positions.append(Vector3(float(x), 4.1, z))
	for x in [-131.0, -11.0, 109.0]:
		for z in range(-150, 151, 30):
			tree_positions.append(Vector3(x, 4.1, float(z)))
	crown_multi.instance_count = tree_positions.size()
	for i in range(tree_positions.size()):
		var position := tree_positions[i]
		position.x += _rng.randf_range(-1.5, 1.5)
		position.z += _rng.randf_range(-1.5, 1.5)
		crown_multi.set_instance_transform(i, Transform3D(Basis.IDENTITY, position))
	crowns.multimesh = crown_multi
	crowns.material_override = FOLIAGE_MATERIAL
	add_child(crowns)

	var trunks := MultiMeshInstance3D.new()
	var trunk_multi := MultiMesh.new()
	trunk_multi.transform_format = MultiMesh.TRANSFORM_3D
	trunk_multi.mesh = trunk_mesh
	trunk_multi.instance_count = tree_positions.size()
	for i in range(tree_positions.size()):
		var trunk_position := tree_positions[i]
		trunk_position.y = 1.8
		trunk_multi.set_instance_transform(i, Transform3D(Basis.IDENTITY, trunk_position))
	trunks.multimesh = trunk_multi
	trunks.material_override = CONCRETE_MATERIAL
	add_child(trunks)

func _build_park_islands(extent: Vector2) -> void:
	var positions: Array[Vector3] = [
		Vector3(-70, 0.2, -70), Vector3(70, 0.2, 70),
		Vector3(-70, 0.2, 70), Vector3(70, 0.2, -70)
	]
	for pos in positions:
		var curb := _box(Vector3(38.0, 0.30, 38.0), CONCRETE_MATERIAL)
		curb.position = pos
		add_child(curb)
		var island := _box(Vector3(34.0, 0.24, 34.0), FOLIAGE_MATERIAL)
		island.position = pos + Vector3(0, 0.25, 0)
		add_child(island)
		var water := _box(Vector3(8.0, 0.06, 4.0), WINDOW_MATERIAL)
		water.position = pos + Vector3(0, 0.42, 0)
		add_child(water)

func _build_parked_cars(extent: Vector2) -> void:
	# Keep a procedural fallback, but prefer the detailed CC0 KayKit vehicles below.
	if not _kaykit_car_scenes.is_empty():
		return
	var car_colors: Array[Color] = [Color(0.82, 0.10, 0.06), Color(0.08, 0.16, 0.22), Color(0.85, 0.72, 0.16), Color(0.65, 0.68, 0.70)]
	for i in range(12):
		var car_material := StandardMaterial3D.new()
		car_material.albedo_color = car_colors[i % car_colors.size()]
		car_material.metallic = 0.35
		car_material.roughness = 0.30
		var car := _box(Vector3(3.0, 0.9, 6.0), car_material)
		car.position = Vector3(-150.0 + float(i % 6) * 10.0, 0.82, -111.0 + float(i / 6) * 222.0)
		add_child(car)
		var roof := _box(Vector3(2.2, 0.28, 2.4), WINDOW_MATERIAL)
		roof.position = car.position + Vector3(0, 0.58, 0)
		add_child(roof)

func _build_kaykit_street_props() -> void:
	var car_positions: Array[Vector3] = [
		Vector3(-150.0, 0.82, -111.0), Vector3(-120.0, 0.82, -111.0),
		Vector3(-90.0, 0.82, -111.0), Vector3(90.0, 0.82, 111.0),
		Vector3(120.0, 0.82, 111.0), Vector3(150.0, 0.82, 111.0),
		Vector3(-111.0, 0.82, -150.0), Vector3(111.0, 0.82, 150.0)
	]
	for i in range(car_positions.size()):
		var car: Node3D = _kaykit_car_scenes[i % _kaykit_car_scenes.size()].duplicate()
		car.name = "KayKit_CC0_Car_%s" % i
		car.scale = Vector3.ONE * 6.0
		car.position = car_positions[i]
		car.rotation.y = PI * 0.5 if i >= 6 else 0.0
		add_child(car)

	var light_positions: Array[Vector3] = [
		Vector3(-132.0, 0.60, -12.0), Vector3(-132.0, 0.60, 108.0),
		Vector3(132.0, 0.60, -108.0), Vector3(132.0, 0.60, 12.0),
		Vector3(-12.0, 0.60, -132.0), Vector3(108.0, 0.60, -132.0),
		Vector3(-108.0, 0.60, 132.0), Vector3(12.0, 0.60, 132.0)
	]
	for i in range(light_positions.size()):
		if _kaykit_streetlight_scene == null:
			break
		var light: Node3D = _kaykit_streetlight_scene.duplicate()
		light.name = "KayKit_CC0_Streetlight_%s" % i
		light.scale = Vector3.ONE * 6.0
		light.position = light_positions[i]
		light.rotation.y = PI if i % 2 == 0 else 0.0
		add_child(light)

	var bench_positions: Array[Vector3] = [
		Vector3(-70.0, 0.52, -70.0), Vector3(70.0, 0.52, 70.0),
		Vector3(-70.0, 0.52, 70.0), Vector3(70.0, 0.52, -70.0)
	]
	for i in range(bench_positions.size()):
		if _kaykit_bench_scene == null:
			break
		var bench: Node3D = _kaykit_bench_scene.duplicate()
		bench.name = "KayKit_CC0_Bench_%s" % i
		bench.scale = Vector3.ONE * 10.0
		bench.position = bench_positions[i]
		bench.rotation.y = PI * 0.25 * float(i)
		add_child(bench)

func _build_barricades() -> void:
	for side in [-1.0, 1.0]:
		var barrier := _box(Vector3(16.0, 1.1, 1.2), CONCRETE_MATERIAL)
		barrier.position = Vector3(side * 42.0, 0.58, 0)
		add_child(barrier)
		for offset in [-5.0, 0.0, 5.0]:
			var sandbag := _box(Vector3(2.2, 0.8, 1.1), FOLIAGE_MATERIAL)
			sandbag.position = Vector3(side * 42.0 + offset, 1.35, 1.2)
			add_child(sandbag)

func _box(size: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	return node
