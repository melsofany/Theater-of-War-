extends Node3D
class_name PhotorealCityGenerator

## Modular modern-business-district renderer.
## The reference target is a dense glass-and-concrete urban block with
## readable streets, podiums, roof gardens and varied building silhouettes.
## All geometry remains procedural or uses the local Kenney CC0 package.

@export var city_extent: Vector2 = Vector2(360.0, 360.0)
@export var building_rows: int = 4
@export var building_columns: int = 4
@export var contested: bool = false
@export var showcase_density: bool = false

const GLASS_MATERIAL: Material = preload("res://assets/materials/GlassFacade.tres")
const WINDOW_MATERIAL: Material = preload("res://assets/materials/WindowGrid.tres")
const CONCRETE_MATERIAL: Material = preload("res://assets/materials/UrbanConcrete.tres")
const FOLIAGE_MATERIAL: Material = preload("res://assets/materials/UrbanFoliage.tres")
const ASPHALT_MATERIAL: Material = preload("res://assets/materials/asphalt.tres")
const KAYKIT_LOWRISE_PATHS: Array[String] = [
	"res://assets/cc0/kaykit_city_builder_bits/Assets/glb/building_A.glb",
	"res://assets/cc0/kaykit_city_builder_bits/Assets/glb/building_B.glb",
	"res://assets/cc0/kaykit_city_builder_bits/Assets/glb/building_C.glb",
	"res://assets/cc0/kaykit_city_builder_bits/Assets/glb/building_D.glb",
	"res://assets/cc0/kaykit_city_builder_bits/Assets/glb/building_E.glb"
]

var _kenney_detail_scene: Node3D = null
var _kaykit_lowrise_scenes: Array[Node3D] = []
var _kenney_lowrise_scenes: Array[Node3D] = []
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
	# The showcase district uses a denser five-by-five urban fabric; streamed cities keep the lighter grid.
	var x_values := [-150.0, -60.0, 60.0, 150.0]
	var z_values := [-150.0, -60.0, 60.0, 150.0]
	if showcase_density:
		x_values = [-150.0, -75.0, 0.0, 75.0, 150.0]
		z_values = [-150.0, -75.0, 0.0, 75.0, 150.0]
	var width := x_values.size()
	for row in range(min(building_rows + (1 if showcase_density else 0), z_values.size())):
		for col in range(min(building_columns + (1 if showcase_density else 0), x_values.size())):
			var index := row * width + col
			var center := Vector3(x_values[col], 0.0, z_values[row])
			var style := index % 10
			_build_building(center, _building_profile(style), style)

func _building_profile(style: int) -> Vector3:
	match style:
		0:
			return Vector3(38.0, 84.0, 34.0)
		1:
			return Vector3(32.0, 62.0, 30.0)
		2:
			return Vector3(42.0, 48.0, 36.0)
		3:
			return Vector3(34.0, 30.0, 34.0)
		4:
			return Vector3(46.0, 24.0, 38.0)
		5:
			return Vector3(28.0, 72.0, 28.0)
		6:
			return Vector3(36.0, 40.0, 32.0)
		7:
			return Vector3(24.0, 92.0, 26.0)
		8:
			return Vector3(54.0, 36.0, 34.0)
		9:
			return Vector3(30.0, 54.0, 44.0)
		_:
			return Vector3(36.0, 40.0, 32.0)

func _build_building(center: Vector3, size: Vector3, style: int) -> void:
	var root := Node3D.new()
	root.name = "UrbanBuilding_%s_%s" % [_city_index, style]
	root.position = center
	add_child(root)

	var podium_height := 5.6 if size.y > 36.0 else 4.4
	var podium := _mesh_box(Vector3(size.x + 12.0, podium_height, size.z + 12.0), CONCRETE_MATERIAL)
	podium.position.y = podium_height * 0.5
	root.add_child(podium)
	_add_podium_glass(root, size, podium_height)
	_add_shop_fronts(root, size, podium_height)

	var core := _mesh_box(Vector3(size.x * 0.76, size.y, size.z * 0.76), CONCRETE_MATERIAL)
	core.position.y = podium_height + size.y * 0.5
	root.add_child(core)

	var facade_material := _facade_variant(style)
	var y_center := podium_height + size.y * 0.5
	var normals := [Vector3(0, 0, -1), Vector3(0, 0, 1), Vector3(-1, 0, 0), Vector3(1, 0, 0)]
	var facade_offsets := [
		Vector3(0, y_center, -size.z * 0.39),
		Vector3(0, y_center, size.z * 0.39),
		Vector3(-size.x * 0.39, y_center, 0),
		Vector3(size.x * 0.39, y_center, 0)
	]
	var facade_sizes := [
		Vector3(size.x * 0.82, size.y * 0.95, 0.18),
		Vector3(size.x * 0.82, size.y * 0.95, 0.18),
		Vector3(0.18, size.y * 0.95, size.z * 0.82),
		Vector3(0.18, size.y * 0.95, size.z * 0.82)
	]
	for i in range(4):
		var panel := _mesh_box(facade_sizes[i], facade_material)
		panel.position = facade_offsets[i]
		root.add_child(panel)
		var grid := _mesh_box(facade_sizes[i] + Vector3(0.04, -1.1, 0.04), WINDOW_MATERIAL)
		grid.position = facade_offsets[i] + normals[i] * 0.12
		root.add_child(grid)

	_add_corner_fins(root, size, y_center)
	_add_facade_spines(root, size, podium_height, facade_material)
	_add_floor_bands(root, size, podium_height)
	if size.y > 38.0:
		_add_top_setback(root, size, podium_height, facade_material)
	if style == 1 or style == 2 or style == 5:
		_add_balcony_bands(root, size, podium_height)
	if style == 0 or style == 5 or style == 7:
		_add_kenney_detail(root, size)
	if style == 2 or style == 8:
		_add_rounded_podium(root, size, podium_height)
	_add_lowrise_annexes(root, size, podium_height)
	_add_roof_garden(root, size, podium_height)

func _add_rounded_podium(root: Node3D, size: Vector3, podium_height: float) -> void:
	var curved := CylinderMesh.new()
	curved.top_radius = size.x * 0.38
	curved.bottom_radius = size.x * 0.46
	curved.height = podium_height * 1.25
	curved.radial_segments = 24
	var podium := MeshInstance3D.new()
	podium.mesh = curved
	podium.material_override = GLASS_MATERIAL
	podium.scale = Vector3(1.0, 1.0, size.z / maxf(size.x, 0.1))
	podium.position.y = podium_height * 0.62
	root.add_child(podium)
	var roof := _mesh_cylinder(size.x * 0.48, 0.28, CONCRETE_MATERIAL)
	roof.scale = Vector3(1.0, 1.0, size.z / maxf(size.x, 0.1))
	roof.position.y = podium_height * 1.30
	root.add_child(roof)

func _add_lowrise_annexes(root: Node3D, size: Vector3, podium_height: float) -> void:
	if size.y < 28.0:
		return
	var annex_height := 11.0 if size.y > 55.0 else 8.5
	for side in [-1.0, 1.0]:
		var annex_size := Vector3(size.x * 0.42, annex_height, size.z * 0.34)
		var annex := _mesh_box(annex_size, CONCRETE_MATERIAL)
		annex.position = Vector3(side * size.x * 0.30, podium_height + annex_height * 0.5, size.z * 0.18)
		root.add_child(annex)
		var annex_glass := _mesh_box(Vector3(annex_size.x * 0.82, annex_size.y * 0.62, 0.16), GLASS_MATERIAL)
		annex_glass.position = annex.position + Vector3(0, 0.3, size.z * 0.18)
		root.add_child(annex_glass)
		var annex_roof := _mesh_box(Vector3(annex_size.x + 1.2, 0.35, annex_size.z + 1.2), CONCRETE_MATERIAL)
		annex_roof.position = annex.position + Vector3(0, annex_height * 0.5 + 0.25, 0)
		root.add_child(annex_roof)
	_add_kenney_lowrise(root, size, podium_height)
	_add_kaykit_lowrise(root, size, podium_height)
	_add_lowrise_storefronts(root, size, podium_height)

func _add_lowrise_storefronts(root: Node3D, size: Vector3, podium_height: float) -> void:
	var storefront_material := GLASS_MATERIAL.duplicate() as StandardMaterial3D
	storefront_material.albedo_color = Color(0.42, 0.62, 0.68, 1.0)
	storefront_material.metallic = 0.16
	storefront_material.roughness = 0.28
	var positions := [
		Vector3(-size.x * 0.34, 0.0, -size.z * 0.34),
		Vector3(size.x * 0.34, 0.0, -size.z * 0.34),
		Vector3(-size.x * 0.34, 0.0, size.z * 0.34),
		Vector3(size.x * 0.34, 0.0, size.z * 0.34)
	]
	for i in range(positions.size()):
		var block_size := Vector3(size.x * 0.28, 5.0, size.z * 0.22)
		var block := _mesh_box(block_size, CONCRETE_MATERIAL)
		block.position = positions[i] + Vector3(0.0, podium_height + block_size.y * 0.5, 0.0)
		root.add_child(block)
		var glass := _mesh_box(Vector3(block_size.x * 0.84, block_size.y * 0.62, 0.16), storefront_material)
		glass.position = block.position + Vector3(0.0, 0.15, -block_size.z * 0.52)
		root.add_child(glass)
		var roof := _mesh_box(Vector3(block_size.x + 1.0, 0.22, block_size.z + 1.0), CONCRETE_MATERIAL)
		roof.position = block.position + Vector3(0.0, block_size.y * 0.5 + 0.14, 0.0)
		root.add_child(roof)

func _add_kenney_lowrise(root: Node3D, size: Vector3, podium_height: float) -> void:
	if _kenney_lowrise_scenes.is_empty():
		return
	var count := 2 if size.y > 50.0 else 1
	for i in range(count):
		var model: Node3D = _kenney_lowrise_scenes[i % _kenney_lowrise_scenes.size()].duplicate()
		model.name = "Kenney_CC0_Lowrise_%s" % i
		var side := -1.0 if i == 0 else 1.0
		model.position = Vector3(side * size.x * 0.34, podium_height + 0.12, -size.z * 0.22)
		model.rotation.y = -0.08 if i == 0 else 0.10
		model.scale = Vector3(14.0, 14.0, 14.0)
		_override_model_material(model)
		root.add_child(model)

func _add_kaykit_lowrise(root: Node3D, size: Vector3, podium_height: float) -> void:
	if _kaykit_lowrise_scenes.is_empty() or size.y < 24.0:
		return
	var count := 2 if size.y > 55.0 else 1
	for i in range(count):
		var model: Node3D = _kaykit_lowrise_scenes[(_city_index + i + int(size.y)) % _kaykit_lowrise_scenes.size()].duplicate()
		model.name = "KayKit_CC0_UrbanLowrise_%s" % i
		var side := -1.0 if i == 0 else 1.0
		model.position = Vector3(side * size.x * 0.34, podium_height + 0.18, size.z * 0.25)
		model.rotation.y = (_rng.randf_range(-0.18, 0.18) + PI * 0.5 * float(i))
		model.scale = Vector3.ONE * (7.0 if size.y < 45.0 else 8.0)
		root.add_child(model)

func _override_model_material(node: Node) -> void:
	var material := CONCRETE_MATERIAL.duplicate() as StandardMaterial3D
	material.albedo_color = Color(0.78, 0.80, 0.76, 1.0)
	material.metallic = 0.08
	material.roughness = 0.34
	if node is MeshInstance3D:
		node.material_override = material
	for child in node.get_children():
		_override_model_material(child)

func _facade_variant(style: int) -> Material:
	var variant := GLASS_MATERIAL.duplicate() as StandardMaterial3D
	var palette := [
		Color(0.14, 0.27, 0.42, 1.0),
		Color(0.22, 0.38, 0.54, 1.0),
		Color(0.34, 0.46, 0.52, 1.0),
		Color(0.52, 0.55, 0.51, 1.0),
		Color(0.28, 0.40, 0.48, 1.0)
	]
	variant.albedo_color = palette[style % palette.size()]
	variant.metallic = 0.30 + float(style % 4) * 0.06
	variant.roughness = 0.18 + float(style % 3) * 0.04
	return variant

func _add_podium_glass(root: Node3D, size: Vector3, podium_height: float) -> void:
	var podium_material := GLASS_MATERIAL.duplicate() as StandardMaterial3D
	podium_material.albedo_color = Color(0.24, 0.34, 0.38, 1.0)
	podium_material.metallic = 0.55
	podium_material.roughness = 0.28
	var front := _mesh_box(Vector3(size.x + 6.0, podium_height * 0.72, 0.16), podium_material)
	front.position = Vector3(0, podium_height * 0.56, -(size.z * 0.5 + 5.95))
	root.add_child(front)
	var side := _mesh_box(Vector3(0.16, podium_height * 0.72, size.z + 6.0), podium_material)
	side.position = Vector3(-(size.x * 0.5 + 5.95), podium_height * 0.56, 0)
	root.add_child(side)

func _add_floor_bands(root: Node3D, size: Vector3, podium_height: float) -> void:
	var floor_count: int = maxi(2, int(size.y / 8.0))
	for floor in range(1, floor_count):
		var belt := _mesh_box(Vector3(size.x * 0.88, 0.20, size.z * 0.88), CONCRETE_MATERIAL)
		belt.position.y = podium_height + floor * 8.0
		root.add_child(belt)

func _add_facade_spines(root: Node3D, size: Vector3, podium_height: float, facade_material: Material) -> void:
	var y_center := podium_height + size.y * 0.5
	for side in [-1.0, 1.0]:
		var spine := _mesh_box(Vector3(1.35, size.y * 0.92, 0.24), CONCRETE_MATERIAL)
		spine.position = Vector3(side * size.x * 0.12, y_center, -size.z * 0.405)
		root.add_child(spine)
		var inset := _mesh_box(Vector3(size.x * 0.16, size.y * 0.78, 0.10), facade_material)
		inset.position = spine.position + Vector3(0.0, 0.0, 0.16)
		root.add_child(inset)

func _add_top_setback(root: Node3D, size: Vector3, podium_height: float, facade_material: Material) -> void:
	var top_height := 5.0 if size.y > 60.0 else 3.8
	var top_size := Vector3(size.x * 0.68, top_height, size.z * 0.68)
	var top := _mesh_box(top_size, CONCRETE_MATERIAL)
	top.position = Vector3(0.0, podium_height + size.y + top_height * 0.5, 0.0)
	root.add_child(top)
	var front := _mesh_box(Vector3(top_size.x * 0.86, top_size.y * 0.70, 0.14), facade_material)
	front.position = top.position + Vector3(0.0, 0.0, -top_size.z * 0.52)
	root.add_child(front)
	var roof := _mesh_box(Vector3(top_size.x + 1.2, 0.28, top_size.z + 1.2), CONCRETE_MATERIAL)
	roof.position = top.position + Vector3(0.0, top_size.y * 0.5 + 0.18, 0.0)
	root.add_child(roof)

func _add_corner_fins(root: Node3D, size: Vector3, y_center: float) -> void:
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var fin := _mesh_box(Vector3(0.55, size.y * 0.97, 0.55), CONCRETE_MATERIAL)
			fin.position = Vector3(sx * size.x * 0.405, y_center, sz * size.z * 0.405)
			root.add_child(fin)

func _add_balcony_bands(root: Node3D, size: Vector3, podium_height: float) -> void:
	var levels := [podium_height + size.y * 0.30, podium_height + size.y * 0.62]
	for level in levels:
		for side in [-1.0, 1.0]:
			var balcony := _mesh_box(Vector3(size.x * 0.72, 0.26, 1.30), CONCRETE_MATERIAL)
			balcony.position = Vector3(0.0, level, side * (size.z * 0.42 + 0.72))
			root.add_child(balcony)
			var railing := _mesh_box(Vector3(size.x * 0.66, 0.16, 0.10), WINDOW_MATERIAL)
			railing.position = balcony.position + Vector3(0, 0.48, side * 0.58)
			root.add_child(railing)

func _add_shop_fronts(root: Node3D, size: Vector3, podium_height: float) -> void:
	for side in [-1.0, 1.0]:
		var shop := _mesh_box(Vector3(size.x * 0.72, podium_height * 0.52, 0.14), WINDOW_MATERIAL)
		shop.position = Vector3(0, podium_height * 0.40, side * (size.z * 0.50 + 6.02))
		root.add_child(shop)
		var awning := _mesh_box(Vector3(size.x * 0.76, 0.16, 1.6), CONCRETE_MATERIAL)
		awning.position = Vector3(0, podium_height * 0.76, side * (size.z * 0.50 + 6.65))
		root.add_child(awning)

func _add_roof_garden(root: Node3D, size: Vector3, podium_height: float) -> void:
	var roof_y := podium_height + size.y + 0.45
	var roof := _mesh_box(Vector3(size.x + 2.0, 0.70, size.z + 2.0), CONCRETE_MATERIAL)
	roof.position.y = roof_y
	root.add_child(roof)
	for i in range(3 if size.y > 30.0 else 2):
		var planter := _mesh_box(Vector3(3.2, 0.35, 2.1), FOLIAGE_MATERIAL)
		planter.position = Vector3(_rng.randf_range(-size.x * 0.28, size.x * 0.28), roof_y + 0.55, _rng.randf_range(-size.z * 0.28, size.z * 0.28))
		root.add_child(planter)
		var trunk := _mesh_cylinder(0.16, 1.8, CONCRETE_MATERIAL)
		trunk.position = planter.position + Vector3(0, 1.0, 0)
		root.add_child(trunk)
		var crown := _mesh_sphere(1.1, FOLIAGE_MATERIAL)
		crown.position = planter.position + Vector3(0, 2.2, 0)
		root.add_child(crown)

func _load_kenney_detail() -> void:
	if _kenney_load_attempted:
		return
	_kenney_load_attempted = true
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	if document.append_from_file("res://assets/cc0/kenney_modular_buildings/building-sample-tower-a.glb", state) == OK:
		_kenney_detail_scene = document.generate_scene(state)
	for path in [
		"res://assets/cc0/kenney_modular_buildings/building-sample-house-a.glb",
		"res://assets/cc0/kenney_modular_buildings/building-sample-house-b.glb",
		"res://assets/cc0/kenney_modular_buildings/building-sample-house-c.glb"
	]:
		var low_document := GLTFDocument.new()
		var low_state := GLTFState.new()
		if low_document.append_from_file(path, low_state) == OK:
			var low_scene := low_document.generate_scene(low_state)
			if low_scene is Node3D:
				_kenney_lowrise_scenes.append(low_scene)
	for path in KAYKIT_LOWRISE_PATHS:
		var kay_document := GLTFDocument.new()
		var kay_state := GLTFState.new()
		if kay_document.append_from_file(path, kay_state) == OK:
			var kay_scene := kay_document.generate_scene(kay_state)
			if kay_scene is Node3D:
				_kaykit_lowrise_scenes.append(kay_scene)

func _add_kenney_detail(root: Node3D, size: Vector3) -> void:
	if _kenney_detail_scene == null:
		return
	var detail: Node3D = _kenney_detail_scene.duplicate()
	detail.name = "Kenney_CC0_FacadeDetail"
	detail.position = Vector3(size.x * 0.28, 5.6, size.z * 0.50)
	detail.rotation.y = _rng.randf_range(-0.16, 0.16)
	detail.scale = Vector3(4.5, 4.5, 4.5)
	root.add_child(detail)

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
	mesh.radial_segments = 10
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	return instance

func _mesh_sphere(radius: float, material: Material) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	return instance
