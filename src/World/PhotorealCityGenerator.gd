extends Node3D
class_name PhotorealCityGenerator

## City renderer used by World.gd instead of the old single-BoxMesh CBD scene.
## Geometry is intentionally modular so the same generator can later be replaced
## by imported GLB façade parts without changing city placement or gameplay data.

@export var city_extent: Vector2 = Vector2(360.0, 360.0)
@export var building_rows: int = 4
@export var building_columns: int = 4
@export var contested: bool = false

const GLASS_MATERIAL: Material = preload("res://assets/materials/GlassFacade.tres")
const WINDOW_MATERIAL: Material = preload("res://assets/materials/WindowGrid.tres")
const CONCRETE_MATERIAL: Material = preload("res://assets/materials/UrbanConcrete.tres")
const FOLIAGE_MATERIAL: Material = preload("res://assets/materials/UrbanFoliage.tres")
const ASPHALT_MATERIAL: Material = preload("res://assets/materials/asphalt.tres")
var _kenney_detail_scene: Node3D = null
var _kenney_load_attempted := false
var _rng := RandomNumberGenerator.new()
var _city_name := "City"
var _city_index := 0

func build_city(city_name: String, city_index: int, is_contested: bool = false) -> void:
	_city_name = city_name
	_city_index = city_index
	contested = is_contested
	_rng.seed = abs(hash(city_name)) + city_index * 7919
	_load_kenney_detail()
	var street_details = load("res://src/World/StreetDetails.gd").new()
	street_details.name = "StreetDetails"
	add_child(street_details)
	street_details.build(city_extent, contested, _city_index)
	_build_district_blocks()

func _build_district_blocks() -> void:
	var x0 := -city_extent.x * 0.5 + 42.0
	var z0 := -city_extent.y * 0.5 + 42.0
	var step_x := (city_extent.x - 84.0) / float(max(building_columns - 1, 1))
	var step_z := (city_extent.y - 84.0) / float(max(building_rows - 1, 1))
	for row in range(building_rows):
		for col in range(building_columns):
			var center := Vector3(x0 + col * step_x, 0.0, z0 + row * step_z)
			var height := _rng.randf_range(28.0, 76.0)
			var width := _rng.randf_range(24.0, 38.0)
			var depth := _rng.randf_range(24.0, 38.0)
			_build_building(center, Vector3(width, height, depth), (row + col) % 5 == 0)

func _build_building(center: Vector3, size: Vector3, use_kenney_detail: bool) -> void:
	var root := Node3D.new()
	root.name = "FacadeBuilding_%s" % _city_index
	root.position = center
	add_child(root)

	var podium := _mesh_box(Vector3(size.x + 10.0, 3.0, size.z + 10.0), CONCRETE_MATERIAL)
	podium.position.y = 1.5
	root.add_child(podium)

	var core := _mesh_box(Vector3(size.x * 0.92, size.y, size.z * 0.92), CONCRETE_MATERIAL)
	core.position.y = size.y * 0.5 + 3.0
	root.add_child(core)

	var facade_offsets := [
		Vector3(0, size.y * 0.5 + 3.0, -size.z * 0.465),
		Vector3(0, size.y * 0.5 + 3.0, size.z * 0.465),
		Vector3(-size.x * 0.465, size.y * 0.5 + 3.0, 0),
		Vector3(size.x * 0.465, size.y * 0.5 + 3.0, 0)
	]
	var facade_sizes := [
		Vector3(size.x * 0.88, size.y * 0.94, 0.16),
		Vector3(size.x * 0.88, size.y * 0.94, 0.16),
		Vector3(0.16, size.y * 0.94, size.z * 0.88),
		Vector3(0.16, size.y * 0.94, size.z * 0.88)
	]
	for i in range(4):
		var panel := _mesh_box(facade_sizes[i], GLASS_MATERIAL)
		panel.position = facade_offsets[i]
		root.add_child(panel)
		var windows := _mesh_box(facade_sizes[i] + Vector3(0.025, -1.5, 0.025), WINDOW_MATERIAL)
		windows.position = facade_offsets[i] + Vector3(0, 0, -0.10 if i == 0 else 0.10 if i == 1 else 0)
		if i >= 2:
			windows.position += Vector3(-0.10 if i == 2 else 0.10, 0, 0)
		root.add_child(windows)

	for floor in range(1, int(size.y / 8.0)):
		var belt := _mesh_box(Vector3(size.x * 0.98, 0.22, size.z * 0.98), CONCRETE_MATERIAL)
		belt.position.y = 3.0 + floor * 8.0
		root.add_child(belt)

	var roof := _mesh_box(Vector3(size.x + 2.0, 0.7, size.z + 2.0), CONCRETE_MATERIAL)
	roof.position.y = size.y + 3.35
	root.add_child(roof)
	_add_roof_garden(root, size)
	_add_shop_fronts(root, size)
	if use_kenney_detail:
		_add_kenney_detail(root, size)

func _add_shop_fronts(root: Node3D, size: Vector3) -> void:
	for side in [-1.0, 1.0]:
		var sign_panel := _mesh_box(Vector3(size.x * 0.46, 1.3, 0.12), WINDOW_MATERIAL)
		sign_panel.position = Vector3(0, 4.2, side * (size.z * 0.51))
		root.add_child(sign_panel)
		var awning := _mesh_box(Vector3(size.x * 0.48, 0.16, 1.4), CONCRETE_MATERIAL)
		awning.position = Vector3(0, 3.3, side * (size.z * 0.53))
		root.add_child(awning)

func _add_roof_garden(root: Node3D, size: Vector3) -> void:
	for i in range(3):
		var tree := Node3D.new()
		tree.name = "RoofTree"
		tree.position = Vector3(_rng.randf_range(-size.x * 0.3, size.x * 0.3), size.y + 5.0, _rng.randf_range(-size.z * 0.3, size.z * 0.3))
		var trunk := _mesh_cylinder(0.28, 2.8, CONCRETE_MATERIAL)
		trunk.position.y = 1.4
		tree.add_child(trunk)
		var crown := _mesh_sphere(1.6, FOLIAGE_MATERIAL)
		crown.position.y = 3.2
		tree.add_child(crown)
		root.add_child(tree)

func _load_kenney_detail() -> void:
	if _kenney_load_attempted:
		return
	_kenney_load_attempted = true
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	if document.append_from_file("res://assets/cc0/kenney_modular_buildings/building-sample-tower-a.glb", state) == OK:
		_kenney_detail_scene = document.generate_scene(state)

func _add_kenney_detail(root: Node3D, size: Vector3) -> void:
	if _kenney_detail_scene == null:
		return
	var detail: Node3D = _kenney_detail_scene.duplicate()
	detail.name = "Kenney_CC0_FacadeDetail"
	detail.position = Vector3(size.x * 0.30, 3.0, size.z * 0.51)
	detail.scale = Vector3(3.0, 3.0, 3.0)
	root.add_child(detail)

func _build_street_grid() -> void:
	var road_x := _mesh_box(Vector3(city_extent.x, 0.18, 18.0), ASPHALT_MATERIAL)
	road_x.position.y = 0.1
	add_child(road_x)
	var road_z := _mesh_box(Vector3(18.0, 0.20, city_extent.y), ASPHALT_MATERIAL)
	road_z.position.y = 0.11
	add_child(road_z)
	for offset in [-6.0, 0.0, 6.0]:
		var stripe := _mesh_box(Vector3(3.5, 0.04, 0.45), CONCRETE_MATERIAL)
		stripe.position = Vector3(offset, 0.23, 0)
		add_child(stripe)
		var stripe_z := _mesh_box(Vector3(0.45, 0.04, 3.5), CONCRETE_MATERIAL)
		stripe_z.position = Vector3(0, 0.24, offset)
		add_child(stripe_z)

func _build_parks_and_trees() -> void:
	for i in range(10):
		var tree := Node3D.new()
		tree.name = "StreetTree"
		tree.position = Vector3(_rng.randf_range(-city_extent.x * 0.45, city_extent.x * 0.45), 0, _rng.randf_range(-city_extent.y * 0.45, city_extent.y * 0.45))
		var trunk := _mesh_cylinder(0.35, 4.0, CONCRETE_MATERIAL)
		trunk.position.y = 2.0
		tree.add_child(trunk)
		var crown := _mesh_sphere(2.6, FOLIAGE_MATERIAL)
		crown.position.y = 5.0
		tree.add_child(crown)
		add_child(tree)

func _build_checkpoints() -> void:
	for side in [-1.0, 1.0]:
		var barrier := _mesh_box(Vector3(12.0, 1.2, 1.2), CONCRETE_MATERIAL)
		barrier.position = Vector3(side * 36.0, 0.7, 0)
		add_child(barrier)
		var post := _mesh_cylinder(0.18, 5.0, WINDOW_MATERIAL)
		post.position = Vector3(side * 36.0, 3.0, 0)
		add_child(post)

func _mesh_box(size: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	return instance

func _mesh_cylinder(radius: float, height: float, material: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	return instance

func _mesh_sphere(radius: float, material: Material) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	return instance
