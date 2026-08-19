extends Node
class_name MedevacSystem
var ambulances: Array = []
var pending_requests: Array = []
func request_pickup(pos: Vector3, urgent: bool):
    pending_requests.append({"pos": pos, "urgent": urgent})
func find_nearest_ambulance(pos: Vector3) -> Node:
    var nearest = null
    var min_dist = 9999.0
    for amb in ambulances:
        var dist = amb.global_position.distance_to(pos)
        if dist < min_dist:
            min_dist = dist
            nearest = amb
    return nearest