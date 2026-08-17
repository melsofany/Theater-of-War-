extends Node
class_name CarryState
var carrier: Node
var wounded: Node
var target_pos: Vector3
func enter(c: Node, w: Node, target: Vector3):
    carrier = c
    wounded = w
    target_pos = target
    carrier.speed *= 0.5
    carrier.can_shoot = false
func update(delta: float) -> String:
    carrier.move_to(target_pos)
    if carrier.global_position.distance_to(target_pos) < 3.0:
        carrier.speed *= 2.0
        carrier.can_shoot = true
        return "idle"
    return "carry"