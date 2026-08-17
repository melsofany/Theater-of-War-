extends Node
class_name PatrolSystem
func create_patrol_route(center: Vector3, radius: float, points: int = 6) -> Array[Vector3]:
    var route: Array[Vector3] = []
    for i in points:
        var angle = (i / float(points)) * TAU
        route.append(center + Vector3(cos(angle),0,sin(angle)) * radius)
    return route
func assign_patrol(unit: Node, route: Array[Vector3]):
    unit.patrol_route = route
    unit.patrol_index = 0
    unit.set_state("patrol")