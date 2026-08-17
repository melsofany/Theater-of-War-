extends Node3D
class_name GuardPost
enum GuardType { PATROL, STATIC_GUARD, QRF }
@export var guard_type: GuardType = GuardType.PATROL
@export var radius: float = 50.0
@export var building_id: String
var is_secured: bool = false
var guard_units: Array = []
var patrol_points: Array[Vector3] = []
func _ready():
    for i in 4:
        var angle = i * PI/2
        patrol_points.append(global_position + Vector3(cos(angle),0,sin(angle)) * radius)
func secure(building: Node, units: Array):
    is_secured = true
    guard_units = units
func _process(delta):
    if not is_secured: return
    if guard_units.is_empty():
        await get_tree().create_timer(120.0).timeout
        if guard_units.is_empty():
            is_secured = false