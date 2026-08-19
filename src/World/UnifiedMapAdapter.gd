extends RefCounted
## UnifiedMapAdapter
##
## Reads the attached Unified World Map JSON and projects its 16384x16384
## coordinates into the current RTS MapData world. The terrain heightfield
## remains owned by TerrainGenerator; only the supplied map features are loaded.

class_name UnifiedMapAdapter

const DEFAULT_CONFIG_PATH := "res://data/maps/unified_world_map_16384.json"


static func apply_to_map(map_data: MapData, config_path: String = DEFAULT_CONFIG_PATH) -> bool:
	if map_data == null:
		return false
	var file := FileAccess.open(config_path, FileAccess.READ)
	if file == null:
		return false
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK or not (json.data is Dictionary):
		return false
	var config: Dictionary = json.data
	var source_size := float(config.get("size", [16384, 16384])[0])
	if source_size <= 0.0:
		return false
	var world_width := float(map_data.size) * map_data.cell
	var half_world := world_width * 0.5
	map_data.cities.clear()
	map_data.zones.clear()
	map_data.roads.clear()
	var city_positions: Dictionary = {}
	for city in config.get("cities", []):
		if not (city is Dictionary):
			continue
		var source_pos: Array = city.get("pos", [0, 0])
		var pos := _project_point(source_pos, source_size, half_world)
		var label := str(city.get("arabic", city.get("name", city.get("id", "City"))))
		map_data.add_city(label, Vector3(pos.x, 0.0, pos.y))
		city_positions[str(city.get("id", ""))] = pos
	for zone in config.get("zones", []):
		if not (zone is Dictionary):
			continue
		var bounds: Array = zone.get("bounds", [0, 0, 1, 1])
		if bounds.size() < 4:
			continue
		var top_left := _project_point([bounds[0], bounds[1]], source_size, half_world)
		var bottom_right := _project_point([bounds[2], bounds[3]], source_size, half_world)
		var rect := Rect2(top_left.x, top_left.y, bottom_right.x - top_left.x, bottom_right.y - top_left.y)
		map_data.add_zone(str(zone.get("name", zone.get("id", "Zone"))), rect)
	for road in config.get("roads", {}).get("highways", []):
		if not (road is Dictionary):
			continue
		var from_id := str(road.get("from", ""))
		var to_id := str(road.get("to", ""))
		if city_positions.has(from_id) and city_positions.has(to_id):
			var a: Vector2 = city_positions[from_id]
			var b: Vector2 = city_positions[to_id]
			map_data.add_road(PackedVector2Array([a, b]))
	return map_data.cities.size() > 0 and map_data.zones.size() > 0


static func _project_point(source_pos: Array, source_size: float, half_world: float) -> Vector2:
	var sx := float(source_pos[0]) if source_pos.size() > 0 else 0.0
	var sz := float(source_pos[1]) if source_pos.size() > 1 else 0.0
	return Vector2((sx / source_size - 0.5) * half_world * 2.0, (sz / source_size - 0.5) * half_world * 2.0)
