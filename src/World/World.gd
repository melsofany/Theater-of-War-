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


func _ready() -> void:
	if not map_data:
		map_data = TerrainGenerator.new().generate()
	_build_terrain()
	_build_features()
	GameManager.start_game(self)


func _build_terrain() -> void:
	if terrain_scene:
		terrain = terrain_scene.instantiate() as Terrain
	else:
		terrain = Terrain.new()
	add_child(terrain)
	terrain.set_map_data(map_data)


func _build_features() -> void:
	if not features_root:
		return
	for c in features_root.get_children():
		c.queue_free()
	for city in map_data.cities:
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
	for z in map_data.zones:
		var node: StrategicZone = null
		if zone_scene:
			node = zone_scene.instantiate() as StrategicZone
		else:
			node = StrategicZone.new()
		features_root.add_child(node)
		node.zone_name = z["name"]
		node.set_rect(z["rect"])


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
	return u


func ground_height_at(wx: float, wz: float) -> float:
	if map_data:
		return map_data.height_at(wx, wz)
	return 0.0


func is_passable(wx: float, wz: float) -> bool:
	if map_data:
		return not map_data.is_impassable(wx, wz)
	return true


func move_cost_at(wx: float, wz: float) -> float:
	if map_data:
		return map_data.move_cost(wx, wz)
	return 1.0
