extends Node
class_name Hospital
@export var beds: int = 10
var patients: Array = []
var heal_queue: Array = []
func admit_patient(soldier: Node) -> bool:
    if patients.size() >= beds: return false
    patients.append(soldier)
    var heal_time = 120.0 if soldier.injury_state == 1 else 300.0
    heal_queue.append({"soldier": soldier, "time_left": heal_time})
    soldier.is_in_hospital = true
    return true
func _process(delta):
    for data in heal_queue:
        data.time_left -= delta
        if data.time_left <= 0:
            data.soldier.is_in_hospital = false
            patients.erase(data.soldier)
            heal_queue.erase(data)