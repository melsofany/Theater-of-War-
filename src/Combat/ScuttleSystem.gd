extends Node
class_name ScuttleSystem
func scuttle_vehicle(vehicle: Node, by: Node) -> bool:
    if vehicle.has_wounded_inside():
        return false
    var enemies_near = SpatialGrid.query_enemies_in_radius(vehicle.global_position, 50.0)
    if enemies_near.is_empty():
        return false
    vehicle.is_scuttling = true
    await get_tree().create_timer(10.0).timeout
    var crater_mgr = get_node_or_null("/root/World/CraterManager")
    if crater_mgr:
        crater_mgr.create_crater(vehicle.global_position, 300)
    vehicle.queue_free()
    return true