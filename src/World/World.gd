extends Node3D
## World
##
## Root of the playable battlefield. Owns the terrain (heightfield + features),
## the unit container and exposes lookup helpers used by the rest of the game.
## Phase 2 replaces the flat plane with a procedural terrain (mountains,
## plateaus, rivers, roads, bridges, cities, strategic zones).

class_name World

@export var map_data: MapData
@export var terrain_scene: PackedScene
@export var city_scene: PackedScene
@export var zone_scene: PackedScene

@onready var units_root: Node3D = $Units
@onready var features_root: Node3D = $Features
var terrain: Terrain
## Spatial index used by combat, AI and intelligence radius queries.
var spatial_grid: SpatialGrid = SpatialGrid.new(16.0)


func _ready() -> void:
	if not map_data:
		map_data = TerrainGenerator.new().generate(512, 4.0)
	_build_terrain()
	_build_features()
	if units_root:
		units_root.child_entered_tree.connect(_on_unit_entered_tree)
		units_root.child_exiting_tree.connect(_on_unit_exiting_tree)
		for child in units_root.get_children():
			_register_spatial_entity(child)
	GameManager.start_game(self)


func _build_terrain() -> void:
	if terrain_scene:
		terrain = terrain_scene.instantiate() as Terrain
	else:
		terrain = Terrain.new()
	add_child(terrain)
	# Stream the continuous world around the active battlefield. The map data
	# remains full-size while only nearby terrain chunks are rendered.
	terrain.streaming = true
	terrain.chunk_size = 128.0
	terrain.stream_view_radius = 512.0
	terrain.set_map_data(map_data)


func _build_features() -> void:
	if not features_root:
		return
	for c in features_root.get_children():
		c.queue_free()
	var city_script = load("res://src/World/PhotorealCityGenerator.gd")
	for city_index in range(map_data.cities.size()):
		var city = map_data.cities[city_index]
		var node: City = null
		if city_scene:
			node = city_scene.instantiate() as City
		else:
			node = City.new()
		features_root.add_child(node)
		var pos: Vector3 = city["position"]
		pos.y = map_data.height_at(pos.x, pos.z)
		node.global_position = pos
		node.city_name = city["name"]
		if node.body_mesh:
			node.body_mesh.visible = false
		if city_script:
			var real_city: Node3D = city_script.new()
			real_city.name = "PhotorealCity_" + str(city["name"])
			features_root.add_child(real_city)
			real_city.global_position = pos
			var contested: bool = bool(city.get("contested", false)) or city_index % 7 == 0
			if real_city.has_method("build_city"):
				real_city.build_city(str(city["name"]), city_index, contested)

	for z in map_data.zones:
		var node: StrategicZone = null
		if zone_scene:
			node = zone_scene.instantiate() as StrategicZone
		else:
			node = StrategicZone.new()
		features_root.add_child(node)
		node.zone_name = z["name"]
		node.set_rect(z["rect"])


func _on_unit_entered_tree(node: Node) -> void:
	_register_spatial_entity(node)


func _on_unit_exiting_tree(node: Node) -> void:
	if node is Unit:
		spatial_grid.remove(node)


func _register_spatial_entity(node: Node) -> void:
	if node is Unit:
		spatial_grid.insert(node)


## Public spatial-index hooks. Production units are indexed automatically via the
## units_root tree signals (and spawn_unit); callers that build a World manually
## (e.g. tests) should register units through here so radius queries are correct.
func register_unit(unit: Unit) -> void:
	if unit == null:
		return
	spatial_grid.insert(unit)


func unregister_unit(unit: Unit) -> void:
	if unit == null:
		return
	spatial_grid.remove(unit)


func update_unit_spatial(unit: Unit, old_pos: Vector3) -> void:
	spatial_grid.update(unit, old_pos)


func query_units_radius(pos: Vector3, radius: float) -> Array:
	return spatial_grid.query_radius(pos, radius)


func get_units() -> Array:
	var out: Array = []
	if units_root:
		for c in units_root.get_children():
			if c is Unit:
				out.append(c)
	return out


func get_buildings() -> Array:
	var out: Array = []
	if units_root:
		for c in units_root.get_children():
			if c is Building:
				out.append(c)
	return out


## All distinct factions present among units and buildings (AI uses this).
func get_factions() -> Array:
	var seen: Dictionary = {}
	var out: Array = []
	for u in get_units():
		if u.faction != null and not seen.has(u.faction.name):
			seen[u.faction.name] = true
			out.append(u.faction)
	for b in get_buildings():
		if b.faction != null and not seen.has(b.faction.name):
			seen[b.faction.name] = true
			out.append(b.faction)
	return out


func get_cities() -> Array:
	var out: Array = []
	if features_root:
		for c in features_root.get_children():
			if c is City:
				out.append(c)
	return out


func get_enemy_units_of(faction: Faction) -> Array:
	var out: Array = []
	for u in get_units():
		if u.faction != null and u.faction.is_enemy_of(faction):
			out.append(u)
	return out


func spawn_unit(scene: PackedScene, at: Vector3) -> Unit:
	var u := scene.instantiate() as Unit
	units_root.add_child(u)
	u.global_position = at
	spatial_grid.insert(u)
	return u


func ground_height_at(wx: float, wz: float) -> float:
	if map_data:
		return map_data.height_at(wx, wz)
	return 0.0


func is_water_at(wx: float, wz: float) -> bool:
	if map_data:
		return map_data.is_water(wx, wz)
	return false


func is_passable(wx: float, wz: float) -> bool:
	if map_data:
		return not map_data.is_impassable(wx, wz)
	return true


func move_cost_at(wx: float, wz: float) -> float:
	if map_data:
		return map_data.move_cost(wx, wz)
	return 1.0
