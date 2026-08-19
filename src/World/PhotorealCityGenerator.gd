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
var _kenney_tower_scenes: Array[Node3D] = []
var _kenney_window_middle_scene: Node3D = null
var _kenney_window_top_scene: Node3D = null
var _kenney_roof_detail_scene: Node3D = null
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
	if showcase_density:
		_build_showcase_background_city()

func _build_showcase_background_city() -> void:
	# A restrained ring of distant blocks gives the hero district a believable city horizon.
	# They remain deliberately simple so the RTS view does not pay the hero-asset cost everywhere.
	var background_positions := [
		Vector3(-228.0, 0.0, -188.0), Vector3(-160.0, 0.0, -222.0), Vector3(-84.0, 0.0, -232.0),
		Vector3(12.0, 0.0, -230.0), Vector3(104.0, 0.0, -226.0), Vector3(188.0, 0.0, -205.0),
		Vector3(228.0, 0.0, -146.0), Vector3(238.0, 0.0, -70.0), Vector3(236.0, 0.0, 18.0),
		Vector3(232.0, 0.0, 102.0), Vector3(214.0, 0.0, 180.0), Vector3(154.0, 0.0, 226.0),
		Vector3(72.0, 0.0, 232.0), Vector3(-18.0, 0.0, 230.0), Vector3(-108.0, 0.0, 228.0),
		Vector3(-194.0, 0.0, 208.0), Vector3(-232.0, 0.0, 132.0), Vector3(-238.0, 0.0, 48.0),
		Vector3(-236.0, 0.0, -42.0), Vector3(-232.0, 0.0, -116.0)
	]
	for i in range(background_positions.size()):
		# The camera approaches from positive Z; do not place "background" blocks in its foreground.
		if showcase_density and background_positions[i].z > 120.0:
			continue
		var height := 18.0 + float((i * 17) % 38)
		var width := 22.0 + float((i * 11) % 22)
		var depth := 20.0 + float((i * 7) % 18)
		var root := Node3D.new()
		root.name = "Showcase_BackgroundBlock_%02d" % i
		root.position = background_positions[i]
		add_child(root)
		var podium := _mesh_box(Vector3(width + 10.0, 6.0, depth + 10.0), CONCRETE_MATERIAL)
		podium.position.y = 3.0
		root.add_child(podium)
		var body := _mesh_box(Vector3(width, height, depth), _facade_variant(i + 3))
		body.position.y = 6.0 + height * 0.5
		root.add_child(body)
		var front := _mesh_box(Vector3(width * 0.82, height * 0.84, 0.12), WINDOW_MATERIAL)
		front.position = Vector3(0.0, 6.0 + height * 0.5, -depth * 0.51)
		root.add_child(front)
		var roof := _mesh_box(Vector3(width + 1.4, 0.28, depth + 1.4), CONCRETE_MATERIAL)
		roof.position.y = 6.0 + height + 0.18
		root.add_child(roof)

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
			if showcase_density and row == z_values.size() - 1:
				# Leave the camera-facing edge open: the boulevard is the foreground hero element.
				# A full row of podiums created large blank slabs that hid the urban street layer.
				continue
			if showcase_density and col == 2 and row >= 1:
				# Keep a continuous central boulevard sightline through the near and middle rows.
				continue
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
		10:
			return Vector3(18.0, 8.0, 16.0)
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
	if showcase_density and size.y <= 48.0:
		_add_showcase_commercial_facade(root, size, podium_height, style)

	var facade_material := _facade_variant(style)
	var y_center := podium_height + size.y * 0.5
	var use_kenney_hero := showcase_density and (style == 0 or style == 2 or style == 5 or style == 7 or style == 9) and _kenney_window_middle_scene != null
	if use_kenney_hero:
		_add_kenney_hero_tower(root, size, podium_height, style)
	else:
		if style == 2 or style == 8:
			_add_rounded_tower_mass(root, size, podium_height, facade_material, style)
		elif style == 5 or style == 9:
			_add_split_tower_mass(root, size, podium_height, facade_material, style)
		else:
			_add_rectangular_tower_mass(root, size, podium_height, facade_material)
		_add_corner_fins(root, size, y_center)
		_add_facade_spines(root, size, podium_height, facade_material)
		_add_facade_modules(root, size, podium_height)
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
	# Tall procedural roofs read as detached floating platforms at this camera distance.
	# Keep planted terraces on low-rise podiums only; hero tower assets supply their own tops.
	if size.y <= 36.0:
		_add_roof_garden(root, size, podium_height)

func _add_rectangular_tower_mass(root: Node3D, size: Vector3, podium_height: float, facade_material: Material) -> void:
	var core := _mesh_box(Vector3(size.x * 0.76, size.y, size.z * 0.76), CONCRETE_MATERIAL)
	core.position.y = podium_height + size.y * 0.5
	root.add_child(core)
	var y_center := podium_height + size.y * 0.5
	var normals := [Vector3(0, 0, -1), Vector3(0, 0, 1), Vector3(-1, 0, 0), Vector3(1, 0, 0)]
	var facade_offsets := [
		Vector3(0, y_center, -size.z * 0.39), Vector3(0, y_center, size.z * 0.39),
		Vector3(-size.x * 0.39, y_center, 0), Vector3(size.x * 0.39, y_center, 0)
	]
	var facade_sizes := [
		Vector3(size.x * 0.82, size.y * 0.95, 0.18), Vector3(size.x * 0.82, size.y * 0.95, 0.18),
		Vector3(0.18, size.y * 0.95, size.z * 0.82), Vector3(0.18, size.y * 0.95, size.z * 0.82)
	]
	for i in range(4):
		var panel := _mesh_box(facade_sizes[i], facade_material)
		panel.position = facade_offsets[i]
		root.add_child(panel)
		var grid := _mesh_box(facade_sizes[i] + Vector3(0.04, -1.1, 0.04), WINDOW_MATERIAL)
		grid.position = facade_offsets[i] + normals[i] * 0.12
		root.add_child(grid)

func _add_rounded_tower_mass(root: Node3D, size: Vector3, podium_height: float, facade_material: Material, style: int) -> void:
	var tower_mesh := CylinderMesh.new()
	tower_mesh.top_radius = 0.50
	tower_mesh.bottom_radius = 0.56
	tower_mesh.height = size.y
	tower_mesh.radial_segments = 32
	var tower := MeshInstance3D.new()
	tower.mesh = tower_mesh
	tower.material_override = facade_material
	tower.scale = Vector3(size.x, 1.0, size.z) * 0.88
	tower.position.y = podium_height + size.y * 0.5
	root.add_child(tower)
	var window_shell_mesh := CylinderMesh.new()
	window_shell_mesh.top_radius = 0.505
	window_shell_mesh.bottom_radius = 0.565
	window_shell_mesh.height = size.y * 0.94
	window_shell_mesh.radial_segments = 32
	var window_shell := MeshInstance3D.new()
	window_shell.mesh = window_shell_mesh
	window_shell.material_override = WINDOW_MATERIAL
	window_shell.scale = Vector3(size.x, 1.0, size.z) * 0.89
	window_shell.position.y = podium_height + size.y * 0.5
	root.add_child(window_shell)
	for i in range(8):
		var angle := TAU * float(i) / 8.0
		var fin := _mesh_box(Vector3(0.55, size.y * 0.94, 0.75), CONCRETE_MATERIAL)
		fin.position = Vector3(cos(angle) * size.x * 0.39, podium_height + size.y * 0.5, sin(angle) * size.z * 0.39)
		fin.rotation.y = angle
		root.add_child(fin)
	for level in [0.30, 0.58, 0.82]:
		var balcony := _mesh_cylinder(maxf(size.x, size.z) * 0.47, 0.24, CONCRETE_MATERIAL)
		balcony.scale = Vector3(1.0, 1.0, size.z / maxf(size.x, 0.1))
		balcony.position.y = podium_height + size.y * level
		root.add_child(balcony)
	var crown := _mesh_cylinder(maxf(size.x, size.z) * 0.38, 2.8, CONCRETE_MATERIAL)
	crown.scale = Vector3(1.0, 1.0, size.z / maxf(size.x, 0.1))
	crown.position.y = podium_height + size.y + 1.4
	root.add_child(crown)

func _add_split_tower_mass(root: Node3D, size: Vector3, podium_height: float, facade_material: Material, style: int) -> void:
	var left_size := Vector3(size.x * 0.48, size.y * 0.86, size.z * 0.72)
	var right_size := Vector3(size.x * 0.38, size.y * (0.62 if style == 9 else 0.74), size.z * 0.92)
	var left := _mesh_box(left_size, facade_material)
	left.position = Vector3(-size.x * 0.18, podium_height + left_size.y * 0.5, 0.0)
	root.add_child(left)
	var right := _mesh_box(right_size, facade_material)
	right.position = Vector3(size.x * 0.22, podium_height + right_size.y * 0.5, size.z * 0.06)
	root.add_child(right)
	var left_grid := _mesh_box(Vector3(left_size.x * 0.92, left_size.y * 0.88, 0.14), WINDOW_MATERIAL)
	left_grid.position = left.position + Vector3(0.0, 0.0, -left_size.z * 0.51)
	root.add_child(left_grid)
	var right_grid := _mesh_box(Vector3(right_size.x * 0.92, right_size.y * 0.88, 0.14), WINDOW_MATERIAL)
	right_grid.position = right.position + Vector3(0.0, 0.0, -right_size.z * 0.51)
	root.add_child(right_grid)
	var spine := _mesh_box(Vector3(2.0, size.y * 0.9, size.z * 0.86), CONCRETE_MATERIAL)
	spine.position = Vector3(0.0, podium_height + size.y * 0.5, -size.z * 0.02)
	root.add_child(spine)
	for side in [-1.0, 1.0]:
		var balcony := _mesh_box(Vector3(size.x * 0.86, 0.28, 1.25), CONCRETE_MATERIAL)
		balcony.position = Vector3(0.0, podium_height + size.y * 0.46, side * size.z * 0.47)
		root.add_child(balcony)
	var roof := _mesh_box(Vector3(size.x * 0.72, 1.2, size.z * 0.76), CONCRETE_MATERIAL)
	roof.position = Vector3(-size.x * 0.18, podium_height + left_size.y + 0.6, 0.0)
	root.add_child(roof)

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

func _add_showcase_commercial_facade(root: Node3D, size: Vector3, podium_height: float, style: int) -> void:
	# Hero low-rise treatment: break the podium into readable retail bays instead of one flat box.
	var glass := GLASS_MATERIAL.duplicate() as StandardMaterial3D
	glass.albedo_color = [Color(0.16, 0.30, 0.38, 1.0), Color(0.22, 0.40, 0.46, 1.0), Color(0.30, 0.45, 0.48, 1.0)][style % 3]
	glass.metallic = 0.48
	glass.roughness = 0.22
	var frontage := size.x * 0.92
	var bays := clampi(int(size.x / 7.0), 4, 8)
	var bay_width := frontage / float(bays)
	for face in [-1.0, 1.0]:
		var z: float = face * (size.z * 0.50 + 6.10)
		for bay in range(bays):
			var x := -frontage * 0.5 + bay_width * (float(bay) + 0.5)
			var panel := _mesh_box(Vector3(bay_width * 0.82, podium_height * 0.66, 0.22), glass)
			panel.position = Vector3(x, podium_height * 0.43, z)
			root.add_child(panel)
			var mullion := _mesh_box(Vector3(0.18, podium_height * 0.76, 0.30), CONCRETE_MATERIAL)
			mullion.position = Vector3(-frontage * 0.5 + bay_width * float(bay), podium_height * 0.48, z - face * 0.06)
			root.add_child(mullion)
			if bay % 2 == 0:
				var awning := _mesh_box(Vector3(bay_width * 0.76, 0.14, 1.20), CONCRETE_MATERIAL)
				awning.position = Vector3(x, podium_height * 0.78, z + face * 0.62)
				root.add_child(awning)
		var fascia := _mesh_box(Vector3(frontage, 0.32, 0.34), CONCRETE_MATERIAL)
		fascia.position = Vector3(0.0, podium_height * 0.84, z - face * 0.05)
		root.add_child(fascia)
	# A shallow planted terrace makes the commercial roof read as a real podium.
	var terrace := _mesh_box(Vector3(size.x * 0.86, 0.24, size.z * 0.72), CONCRETE_MATERIAL)
	terrace.position = Vector3(0.0, podium_height + 0.20, 0.0)
	root.add_child(terrace)
	for i in range(3):
		var planter := _mesh_box(Vector3(3.6, 0.38, 1.5), CONCRETE_MATERIAL)
		planter.position = Vector3(-size.x * 0.28 + i * size.x * 0.28, podium_height + 0.55, -size.z * 0.12)
		root.add_child(planter)
		var shrub := _mesh_sphere(0.72, FOLIAGE_MATERIAL)
		shrub.position = planter.position + Vector3(0.0, 0.72, 0.0)
		root.add_child(shrub)

func _add_lowrise_annexes(root: Node3D, size: Vector3, podium_height: float) -> void:
	if size.y < 28.0 and not showcase_density:
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

func _add_facade_modules(root: Node3D, size: Vector3, podium_height: float) -> void:
	# Real mullions and slab edges break the procedural glass shell into readable bays.
	# Keep the count bounded because this layer is only used for hero/showcase buildings.
	if size.y < 30.0:
		return
	var floor_count := clampi(int(size.y / 7.0), 4, 12)
	var bay_count := clampi(int(size.x / 6.0), 3, 8)
	var y_step := size.y / float(floor_count + 1)
	for face in [-1.0, 1.0]:
		for floor in range(1, floor_count + 1):
			var sill := _mesh_box(Vector3(size.x * 0.78, 0.14, 0.34), CONCRETE_MATERIAL)
			sill.position = Vector3(0.0, podium_height + y_step * floor, face * size.z * 0.415)
			root.add_child(sill)
		for bay in range(1, bay_count):
			var mullion := _mesh_box(Vector3(0.20, size.y * 0.90, 0.24), CONCRETE_MATERIAL)
			mullion.position = Vector3(-size.x * 0.39 + size.x * 0.78 * float(bay) / float(bay_count), podium_height + size.y * 0.5, face * size.z * 0.42)
			root.add_child(mullion)
	for face in [-1.0, 1.0]:
		for floor in range(1, floor_count + 1):
			var sill := _mesh_box(Vector3(0.34, 0.14, size.z * 0.78), CONCRETE_MATERIAL)
			sill.position = Vector3(face * size.x * 0.415, podium_height + y_step * floor, 0.0)
			root.add_child(sill)
		for bay in range(1, bay_count):
			var mullion := _mesh_box(Vector3(0.24, size.y * 0.90, 0.20), CONCRETE_MATERIAL)
			mullion.position = Vector3(face * size.x * 0.42, podium_height + size.y * 0.5, -size.z * 0.39 + size.z * 0.78 * float(bay) / float(bay_count))
			root.add_child(mullion)

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
		var planter := _mesh_box(Vector3(4.4, 0.42, 2.8), CONCRETE_MATERIAL)
		planter.position = Vector3(_rng.randf_range(-size.x * 0.28, size.x * 0.28), roof_y + 0.55, _rng.randf_range(-size.z * 0.28, size.z * 0.28))
		root.add_child(planter)
		for tree_index in range(3):
			var trunk := _mesh_cylinder(0.14, 1.65 + tree_index * 0.12, CONCRETE_MATERIAL)
			trunk.position = planter.position + Vector3(-1.25 + tree_index * 1.25, 1.0, (tree_index % 2) * 0.45 - 0.22)
			root.add_child(trunk)
			var crown := _mesh_sphere(0.92 + tree_index * 0.12, FOLIAGE_MATERIAL)
			crown.position = trunk.position + Vector3(0, 1.95 + tree_index * 0.10, 0)
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
	for tower_path in [
		"res://assets/cc0/kenney_modular_buildings/building-sample-tower-a.glb",
		"res://assets/cc0/kenney_modular_buildings/building-sample-tower-b.glb",
		"res://assets/cc0/kenney_modular_buildings/building-sample-tower-c.glb",
		"res://assets/cc0/kenney_modular_buildings/building-sample-tower-d.glb"
	]:
		var tower_scene := _load_kenney_scene(tower_path)
		if tower_scene != null:
			_kenney_tower_scenes.append(tower_scene)
	_kenney_window_middle_scene = _load_kenney_scene("res://assets/cc0/kenney_modular_buildings/building-windows-high-middle.glb")
	_kenney_window_top_scene = _load_kenney_scene("res://assets/cc0/kenney_modular_buildings/building-windows-high-top-square.glb")
	_kenney_roof_detail_scene = _load_kenney_scene("res://assets/cc0/kenney_modular_buildings/roof-flat-detail-b.glb")
	for path in KAYKIT_LOWRISE_PATHS:
		var kay_document := GLTFDocument.new()
		var kay_state := GLTFState.new()
		if kay_document.append_from_file(path, kay_state) == OK:
			var kay_scene := kay_document.generate_scene(kay_state)
			if kay_scene is Node3D:
				_kaykit_lowrise_scenes.append(kay_scene)

func _load_kenney_scene(path: String) -> Node3D:
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	if document.append_from_file(path, state) != OK:
		return null
	var scene := document.generate_scene(state)
	return scene as Node3D

func _add_kenney_hero_tower(root: Node3D, size: Vector3, podium_height: float, style: int) -> void:
	# Use a complete CC0 modular tower where the camera sees the building front.
	# These models contain actual window/roof geometry and give the hero skyline
	# a silhouette that cannot be achieved by a single BoxMesh plus a shader.
	if not _kenney_tower_scenes.is_empty():
		var tower_index := 0 if style == 0 else (1 if style == 5 else 2)
		tower_index = tower_index % _kenney_tower_scenes.size()
		var tower: Node3D = _kenney_tower_scenes[tower_index].duplicate()
		tower.name = "Kenney_CC0_HeroTower_%02d" % tower_index
		var source_heights := [2.5, 1.8875, 3.1375, 3.7625]
		var source_height: float = source_heights[tower_index]
		var horizontal_scale := minf(size.x / 1.10, size.z / 1.20) * 0.92
		var vertical_scale := size.y / source_height * 0.88
		var tower_scale := minf(horizontal_scale, vertical_scale)
		tower.scale = Vector3.ONE * tower_scale
		tower.position = Vector3(-size.x * 0.04 if style == 5 else 0.0, podium_height, 0.0)
		root.add_child(tower)
		var crown := _mesh_box(Vector3(size.x * 0.74, 0.38, size.z * 0.74), CONCRETE_MATERIAL)
		crown.position = tower.position + Vector3(0.0, source_height * tower_scale + 0.28, 0.0)
		root.add_child(crown)
		return
	# Fallback retained for projects where the GLB importer is unavailable.
	var module_scale := minf(size.x, size.z) * (0.72 if style == 0 else 0.78)
	var module_height := 0.625 * module_scale
	var level_count := clampi(roundi(size.y / module_height), 3, 6)
	var actual_height := module_height * float(level_count)
	for level in range(level_count):
		var module: Node3D = _kenney_window_middle_scene.duplicate()
		module.name = "Kenney_Hero_WindowModule_%02d" % level
		module.scale = Vector3.ONE * module_scale
		module.position = Vector3(0.0, podium_height + float(level) * module_height, 0.0)
		root.add_child(module)
	var core := _mesh_box(Vector3(size.x * 0.58, maxf(actual_height - 1.0, 4.0), size.z * 0.58), CONCRETE_MATERIAL)
	core.position = Vector3(0.0, podium_height + maxf(actual_height - 1.0, 4.0) * 0.5, 0.0)
	root.add_child(core)

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
