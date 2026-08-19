extends Node3D
## ModernCity
##
## Original, low-poly modern-city dressing for the RTS battlefield. The system
## deliberately uses procedural primitives so the project owns the visual style
## and does not depend on protected game assets.

class_name ModernCity

@export var city_name: String = "Modern District"
@export var city_seed: int = 2026
@export var district_size: Vector2 = Vector2(104.0, 84.0)
var rng := RandomNumberGenerator.new()
var mats: Dictionary = {}


func _ready() -> void:
	rng.seed = city_seed
	_build_materials()
	_build_district()


func _build_materials() -> void:
	mats["asphalt"] = _mat(Color("#202832"), 0.05, 0.82)
	mats["road_line"] = _mat(Color("#e7bd45"), 0.0, 0.48)
	mats["concrete"] = _mat(Color("#aeb7bd"), 0.0, 0.78)
	mats["glass_blue"] = _mat(Color("#247da8"), 0.72, 0.16)
	mats["glass_dark"] = _mat(Color("#102b43"), 0.84, 0.12)
	mats["window"] = _mat(Color("#79c9e0"), 0.55, 0.22)
	mats["white"] = _mat(Color("#e8edf0"), 0.05, 0.56)
	mats["shop"] = _mat(Color("#d77b45"), 0.0, 0.56)
	mats["roof"] = _mat(Color("#3d4750"), 0.05, 0.7)
	mats["green"] = _mat(Color("#39714f"), 0.0, 0.88)
	mats["grass"] = _mat(Color("#567e45"), 0.0, 0.94)
	mats["water"] = _mat(Color("#237d9e"), 0.3, 0.18)
	mats["red"] = _mat(Color("#b7423d"), 0.0, 0.6)


func _mat(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	return material


func _build_district() -> void:
	# A dark urban pad makes the city readable against the surrounding terrain.
	_box("UrbanPad", Vector3(district_size.x, 0.12, district_size.y), Vector3(0, 0.02, 0), mats["asphalt"])
	_build_roads()
	_build_towers()
	_build_commercial_strip()
	_build_residential_blocks()
	_build_services()
	_build_landscape()


func _build_roads() -> void:
	# Four-lane boulevard crossing the district, plus a perpendicular avenue.
	_box("Boulevard", Vector3(district_size.x, 0.05, 13.0), Vector3(0, 0.1, 0), mats["asphalt"])
	_box("Avenue", Vector3(13.0, 0.052, district_size.y), Vector3(0, 0.105, 0), mats["asphalt"])
	_box("Median", Vector3(district_size.x, 0.09, 1.25), Vector3(0, 0.17, 0), mats["concrete"])
	_box("MedianGreen", Vector3(district_size.x - 4.0, 0.1, 0.72), Vector3(0, 0.24, 0), mats["green"])
	for x in range(-48, 49, 8):
		_box("LaneMark", Vector3(4.0, 0.025, 0.18), Vector3(x, 0.18, -3.2), mats["road_line"])
		_box("LaneMark", Vector3(4.0, 0.025, 0.18), Vector3(x, 0.18, 3.2), mats["road_line"])
	for z in range(-38, 39, 8):
		_box("LaneMark", Vector3(0.18, 0.025, 4.0), Vector3(-3.2, 0.19, z), mats["road_line"])
		_box("LaneMark", Vector3(0.18, 0.025, 4.0), Vector3(3.2, 0.19, z), mats["road_line"])
	for side in [-1.0, 1.0]:
		_box("Sidewalk", Vector3(district_size.x, 0.16, 2.2), Vector3(0, 0.2, side * 9.0), mats["concrete"])
		_box("Sidewalk", Vector3(2.2, 0.16, district_size.y), Vector3(side * 9.0, 0.2, 0), mats["concrete"])


func _build_towers() -> void:
	var towers := [
		Vector3(-35, 0, -27), Vector3(-16, 0, -29), Vector3(20, 0, -28),
		Vector3(39, 0, -23), Vector3(-36, 0, 24), Vector3(30, 0, 25)
	]
	var heights := [22.0, 30.0, 25.0, 18.0, 20.0, 27.0]
	for i in towers.size():
		_build_glass_tower(towers[i], heights[i], 7.0 + float(i % 2) * 2.0)


func _build_glass_tower(pos: Vector3, height: float, width: float) -> void:
	_box("GlassTowerCore", Vector3(width, height, width), pos + Vector3(0, height * 0.5, 0), mats["glass_blue"])
	_box("TowerPodium", Vector3(width + 2.4, 1.4, width + 2.4), pos + Vector3(0, 0.7, 0), mats["concrete"])
	for y in range(3, int(height) - 1, 4):
		_box("WindowBand", Vector3(width + 0.04, 0.18, width + 0.04), pos + Vector3(0, float(y), 0), mats["window"])
	for side in [-1.0, 1.0]:
		_box("GlassFacade", Vector3(0.08, height - 2.0, width * 0.82), pos + Vector3(side * width * 0.51, height * 0.5 + 1.0, 0), mats["glass_dark"])
		_box("GlassFacade", Vector3(width * 0.82, height - 2.0, 0.08), pos + Vector3(0, height * 0.5 + 1.0, side * width * 0.51), mats["glass_dark"])
	_box("Helipad", Vector3(width * 0.65, 0.16, width * 0.65), pos + Vector3(0, height + 0.15, 0), mats["roof"])
	_box("HelipadCrossA", Vector3(width * 0.42, 0.03, 0.34), pos + Vector3(0, height + 0.25, 0), mats["white"])
	_box("HelipadCrossB", Vector3(0.34, 0.03, width * 0.42), pos + Vector3(0, height + 0.25, 0), mats["white"])


func _build_commercial_strip() -> void:
	# Mall at the south-east corner and a row of illuminated ground-floor shops.
	_box("GrandMall", Vector3(25.0, 7.0, 15.0), Vector3(31, 3.5, 8), mats["glass_dark"])
	_box("MallRoof", Vector3(27.0, 0.6, 17.0), Vector3(31, 7.3, 8), mats["concrete"])
	for x in range(22, 41, 6):
		_box("MallWindow", Vector3(4.0, 4.0, 0.12), Vector3(x, 3.2, 0.35), mats["window"])
	for i in range(7):
		var x := -38.0 + float(i) * 10.0
		_box("Shop", Vector3(8.0, 4.0, 6.0), Vector3(x, 2.0, 12.5), mats["shop"])
		_box("ShopAwning", Vector3(8.6, 0.35, 1.8), Vector3(x, 4.1, 9.3), mats["white"])
		_box("ShopWindow", Vector3(6.0, 2.2, 0.12), Vector3(x, 2.4, 9.42), mats["window"])


func _build_residential_blocks() -> void:
	for pos in [Vector3(-35, 0, 38), Vector3(-18, 0, 37), Vector3(5, 0, 37), Vector3(22, 0, 38)]:
		_box("ResidentialBlock", Vector3(13.0, 8.0, 8.0), pos + Vector3(0, 4.0, 0), mats["white"])
		_box("ResidentialRoof", Vector3(13.6, 0.5, 8.6), pos + Vector3(0, 8.25, 0), mats["roof"])
		for x in [-4.0, 0.0, 4.0]:
			_box("BalconyWindow", Vector3(2.0, 1.0, 0.12), pos + Vector3(x, 4.8, -4.08), mats["window"])
			_box("BalconyWindow", Vector3(2.0, 1.0, 0.12), pos + Vector3(x, 2.3, -4.08), mats["window"])


func _build_services() -> void:
	# Original silhouettes for hospital, police, school and utilities.
	_box("Hospital", Vector3(14.0, 8.0, 10.0), Vector3(-28, 4.0, 8), mats["white"])
	_box("HospitalWing", Vector3(5.0, 11.0, 8.0), Vector3(-21, 5.5, 8), mats["glass_blue"])
	_box("HospitalCrossV", Vector3(2.2, 0.22, 0.45), Vector3(-28, 8.2, 2.85), mats["red"])
	_box("HospitalCrossH", Vector3(0.45, 0.22, 2.2), Vector3(-28, 8.2, 2.85), mats["red"])
	_box("PoliceStation", Vector3(12.0, 4.0, 8.0), Vector3(18, 2.0, 22), mats["concrete"])
	_box("PoliceRoof", Vector3(13.0, 0.5, 9.0), Vector3(18, 4.25, 22), mats["blue"] if mats.has("blue") else mats["glass_dark"])
	_box("School", Vector3(16.0, 4.5, 9.0), Vector3(-2, 2.25, 22), mats["shop"])
	_box("UtilityPlant", Vector3(10.0, 6.0, 9.0), Vector3(40, 3.0, 27), mats["roof"])
	_box("WaterTower", Vector3(2.0, 10.0, 2.0), Vector3(42, 5.0, 36), mats["concrete"])
	_cylinder("WaterTank", 4.0, 2.2, Vector3(42, 11.0, 36), mats["water"])


func _build_landscape() -> void:
	_box("CentralPark", Vector3(18.0, 0.12, 12.0), Vector3(-30, 0.32, -15), mats["grass"])
	for pos in [Vector3(-36, 0, -18), Vector3(-24, 0, -18), Vector3(-36, 0, -12), Vector3(-24, 0, -12), Vector3(15, 0, 12), Vector3(44, 0, 10), Vector3(12, 0, 30)]:
		_cylinder("PalmTrunk", 0.35, 3.2, pos + Vector3(0, 1.6, 0), mats["roof"])
		_cylinder("PalmCrown", 2.0, 0.7, pos + Vector3(0, 3.6, 0), mats["green"])
	for x in range(-46, 47, 12):
		_streetlight(Vector3(x, 0, 10.3))
		_streetlight(Vector3(x, 0, -10.3))
	for pos in [Vector3(-32, 0, 3.0), Vector3(-8, 0, -3.0), Vector3(16, 0, 3.0), Vector3(38, 0, -3.0), Vector3(4, 0, 26.0)]:
		_car(pos, pos.x > 0.0)
	_crosswalk(Vector3(-8, 0, 0))
	_crosswalk(Vector3(9, 0, 0))


func _streetlight(pos: Vector3) -> void:
	_cylinder("StreetLightPole", 0.12, 3.0, pos + Vector3(0, 1.5, 0), mats["roof"])
	_box("StreetLight", Vector3(0.7, 0.15, 0.35), pos + Vector3(0, 3.1, 0), mats["white"])


func _car(pos: Vector3, rotated: bool) -> void:
	var body := _box("TrafficCar", Vector3(3.0, 0.8, 1.45), pos + Vector3(0, 0.55, 0), mats["red"] if rng.randf() > 0.5 else mats["glass_dark"])
	if rotated:
		body.rotation.y = PI * 0.5
	var roof := _box("TrafficCarRoof", Vector3(1.5, 0.45, 1.25), pos + Vector3(0, 1.12, 0), mats["window"])
	if rotated:
		roof.rotation.y = PI * 0.5


func _crosswalk(pos: Vector3) -> void:
	for i in range(-3, 4):
		_box("Crosswalk", Vector3(0.65, 0.025, 4.2), pos + Vector3(float(i) * 1.0, 0.23, 0), mats["white"])


func _box(node_name: String, size: Vector3, pos: Vector3, material: Material) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	mesh_instance.position = pos
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(mesh_instance)
	return mesh_instance


func _cylinder(node_name: String, radius: float, height: float, pos: Vector3, material: Material) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	mesh_instance.position = pos
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(mesh_instance)
	return mesh_instance
