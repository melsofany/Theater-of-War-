extends Area3D
class_name SecuredZone
@export var building_id: String
@export var radius: float = 50.0
@export var secured: bool = false
func set_secured(s: bool):
    secured = s
    visible = s
    monitoring = s