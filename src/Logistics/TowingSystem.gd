extends Node
class_name TowingSystem
var active_tows: Array = []
func tow_vehicle(tower: Node, towed: Node) -> bool:
    if not can_tow(tower, towed): return false
    active_tows.append({"tower": tower, "towed": towed})
    tower.speed *= 0.4
    tower.can_shoot = false
    towed.is_being_towed = true
    return true
func can_tow(tower: Node, towed: Node) -> bool:
    return tower.is_operational and towed.immobilized and tower.global_position.distance_to(towed.global_position) < 10.0 and tower.mass >= towed.mass * 0.7
func update_tows(delta: float):
    for tow in active_tows:
        var target_pos = tow.tower.global_position - tow.tower.global_transform.basis.z * 8.0
        tow.towed.global_position = tow.towed.global_position.lerp(target_pos, delta * 2.0)