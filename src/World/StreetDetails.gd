extends Node3D
class_name StreetDetails

const CONCRETE_MATERIAL: Material = preload("res://assets/materials/UrbanConcrete.tres")
const FOLIAGE_MATERIAL: Material = preload("res://assets/materials/UrbanFoliage.tres")
const WINDOW_MATERIAL: Material = preload("res://assets/materials/WindowGrid.tres")

var _rng := RandomNumberGenerator.new()
var _asphalt_material: Material

func build(extent: Vector2, is_contested: bool, seed_value: int) -> void:
	_rng.seed = abs(seed_value * 977 + 41)
	_asphalt_material = _load_asphalt_material()
	_build_roads(extent)
	_build_crosswalks()
	_build_tree_multimesh(extent)
	_build_park_islands(extent)
	_build_parked_cars(extent)
	if is_contested:
		_build_barricades()

func _load_asphalt_material() -> Material:
	var material := StandardMaterial3D.new()
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

func _build_roads(extent: Vector2) -> void:
	var road_x := _box(Vector3(extent.x, 0.16, 16.0), _asphalt_material)
	road_x.position.y = 0.08
	add_child(road_x)
	var road_z := _box(Vector3(16.0, 0.18, extent.y), _asphalt_material)
	road_z.position.y = 0.09
	add_child(road_z)
	for offset in [-120.0, 120.0]:
		var side_x := _box(Vector3(extent.x, 0.12, 8.0), _asphalt_material)
		side_x.position = Vector3(0, 0.07, offset)
		add_child(side_x)
		var side_z := _box(Vector3(8.0, 0.12, extent.y), _asphalt_material)
		side_z.position = Vector3(offset, 0.06, 0)
		add_child(side_z)

func _build_crosswalks() -> void:
	for offset in [-6.0, -2.0, 2.0, 6.0]:
		var stripe_x := _box(Vector3(1.4, 0.035, 7.0), CONCRETE_MATERIAL)
		stripe_x.position = Vector3(offset, 0.19, 0)
		add_child(stripe_x)
		var stripe_z := _box(Vector3(7.0, 0.04, 1.4), CONCRETE_MATERIAL)
		stripe_z.position = Vector3(0, 0.20, offset)
		add_child(stripe_z)

func _build_tree_multimesh(extent: Vector2) -> void:
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.22
	trunk_mesh.bottom_radius = 0.32
	trunk_mesh.height = 3.2
	var trunks := MultiMeshInstance3D.new()
	var trunk_multi := MultiMesh.new()
	trunk_multi.transform_format = MultiMesh.TRANSFORM_3D
	trunk_multi.mesh = trunk_mesh
	trunk_multi.instance_count = 22
	for i in range(trunk_multi.instance_count):
		var x := _rng.randf_range(-extent.x * 0.46, extent.x * 0.46)
		var z := _rng.randf_range(-extent.y * 0.46, extent.y * 0.46)
		trunk_multi.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(x, 1.6, z)))
	trunks.multimesh = trunk_multi
	trunks.material_override = CONCRETE_MATERIAL
	add_child(trunks)

	var crown_mesh := SphereMesh.new()
	crown_mesh.radius = 2.0
	crown_mesh.height = 3.8
	var crowns := MultiMeshInstance3D.new()
	var crown_multi := MultiMesh.new()
	crown_multi.transform_format = MultiMesh.TRANSFORM_3D
	crown_multi.mesh = crown_mesh
	crown_multi.instance_count = trunk_multi.instance_count
	for i in range(crown_multi.instance_count):
		var transform := trunk_multi.get_instance_transform(i)
		transform.origin.y = 4.1
		transform.origin.x += _rng.randf_range(-0.6, 0.6)
		transform.origin.z += _rng.randf_range(-0.6, 0.6)
		crown_multi.set_instance_transform(i, transform)
	crowns.multimesh = crown_multi
	crowns.material_override = FOLIAGE_MATERIAL
	add_child(crowns)

func _build_park_islands(extent: Vector2) -> void:
	for pos in [Vector3(-70, 0.2, -70), Vector3(70, 0.2, 70), Vector3(-70, 0.2, 70), Vector3(70, 0.2, -70)]:
		var island := _box(Vector3(34.0, 0.22, 34.0), FOLIAGE_MATERIAL)
		island.position = pos
		add_child(island)

func _build_parked_cars(extent: Vector2) -> void:
	for i in range(8):
		var car := _box(Vector3(3.8, 1.0, 7.0), WINDOW_MATERIAL)
		car.position = Vector3(-extent.x * 0.35 + i * 9.0, 0.62, -11.0)
		add_child(car)
		var roof := _box(Vector3(3.0, 0.35, 3.3), CONCRETE_MATERIAL)
		roof.position = car.position + Vector3(0, 0.68, 0)
		add_child(roof)

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
