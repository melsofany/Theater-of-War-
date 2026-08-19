# UnifiedWorldMap.gd - Godot 4.3
# الخريطة الموحدة 16384x16384 - دولة كاملة متصلة
# يتكامل مع Phase 2 World & Phase 10c ChunkManager & Phase 10b SpatialGrid
extends Node3D
class_name UnifiedWorldMap

@export var map_config_path: String = "res://data/maps/unified_world_map_16384.json"
@export var chunk_size: int = 256
@export var enable_streaming: bool = true

var map_data: Dictionary = {}
var zones: Array[Dictionary] = []
var cities: Array[Dictionary] = []
var chunk_manager: Node = null
var spatial_grid: Node = null

# تحميل الخريطة
func _ready():
    _load_map_config()
    _init_chunk_manager()
    _generate_terrain()
    _generate_zones()
    _generate_cities()
    _generate_roads_and_rivers()
    print("[UnifiedWorldMap] Loaded %s - %d zones, %d cities" % [map_data.get("name", ""), zones.size(), cities.size()])

func _load_map_config():
    var file = FileAccess.open(map_config_path, FileAccess.READ)
    if file == null:
        push_error("Failed to load map config: %s" % map_config_path)
        return
    var json_text = file.get_as_text()
    var json = JSON.new()
    var err = json.parse(json_text)
    if err != OK:
        push_error("JSON parse error: %s" % json.get_error_message())
        return
    map_data = json.data
    zones = map_data.get("zones", [])
    cities = map_data.get("cities", [])

func _init_chunk_manager():
    # يتكامل مع Phase 10c ChunkManager الموجود
    if has_node("/root/ChunkManager"):
        chunk_manager = get_node("/root/ChunkManager")
    else:
        chunk_manager = load("res://src/World/ChunkManager.gd").new()
        add_child(chunk_manager)
    chunk_manager.chunk_size = chunk_size
    chunk_manager.world_size = Vector2i(16384, 16384)

func _generate_terrain():
    # يولد تضاريس لكل منطقة حسب نوعها
    # شمال: سهول + صناعية
    # صحراء: dunes + rocky
    # دلتا: fertile + rivers
    # ساحل: beach + shallow/deep sea
    # مرتفعات: plateau + mountains + tunnels
    # جنوب: fortified
    for zone in zones:
        var bounds = zone.get("bounds", [0,0,100,100])
        # استدعاء TerrainGenerator الموجود في Phase 2
        pass

func _generate_zones():
    for zone in zones:
        var zone_node = Node3D.new()
        zone_node.name = zone["id"]
        zone_node.set_meta("zone_data", zone)
        add_child(zone_node)
        print("Zone: %s - %s" % [zone["name"], zone["terrain"]])

func _generate_cities():
    var city_gen_script = load("res://src/World/ModernCityGenerator.gd")
    for city_data in cities:
        var city_gen = city_gen_script.new()
        city_gen.city_data = city_data
        city_gen.position = Vector3(city_data["pos"][0], 0, city_data["pos"][1])
        add_child(city_gen)
        city_gen.generate_city(city_gen.position)

func _generate_roads_and_rivers():
    var roads = map_data.get("roads", {}).get("highways", [])
    for road in roads:
        # كل طريق له travel_time - مهم للـ Logistics Phase 6
        # مثال: alex_new -> cairo_war 8 دقايق
        # لو انقطع checkpoint يبقى supply مقطوع
        pass

func get_zone_at_position(world_pos: Vector2) -> Dictionary:
    for zone in zones:
        var b = zone["bounds"]
        if world_pos.x >= b[0] and world_pos.x <= b[2] and world_pos.y >= b[1] and world_pos.y <= b[3]:
            return zone
    return {}

func get_travel_time(city_a_id: String, city_b_id: String) -> int:
    var highways = map_data.get("roads", {}).get("highways", [])
    for h in highways:
        if (h["from"] == city_a_id and h["to"] == city_b_id) or (h["from"] == city_b_id and h["to"] == city_a_id):
            return h.get("time_min", 10)
    return 15

# للـ AI Phase 8: يعرف يتحرك من منطقة لمنطقة
func get_path_between_zones(from_zone: String, to_zone: String) -> Array:
    # A* عبر checkpoints
    return []
