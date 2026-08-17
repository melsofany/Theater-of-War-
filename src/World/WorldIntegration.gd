extends Node
class_name WorldIntegration
@export var grand_map: GrandStrategicMap
var cities: Array = []
func _ready():
    grand_map = GrandStrategicMap.new()
func get_terrain_cost(pos: Vector2i, unit_type: String) -> float:
    var terrain = grand_map.get_terrain(pos)
    return grand_map.get_move_cost(terrain, unit_type)