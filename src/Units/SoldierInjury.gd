extends Node3D
class_name SoldierInjury
enum InjuryState { HEALTHY, WOUNDED_LIGHT, WOUNDED_HEAVY, INCAPACITATED, KIA }
var state: InjuryState = InjuryState.HEALTHY
@export var soldier: Node
func on_hit(damage: float, hit_pos: Vector3):
    match state:
        InjuryState.HEALTHY:
            if damage < 30:
                state = InjuryState.WOUNDED_LIGHT
                soldier.speed *= 0.7
            elif damage < 70:
                state = InjuryState.WOUNDED_HEAVY
                soldier.can_shoot = false
                request_medevac()
            elif damage < 90:
                state = InjuryState.INCAPACITATED
                soldier.can_move = false
                request_medevac(true)
            else:
                state = InjuryState.KIA
                soldier.die()
func request_medevac(urgent: bool = false):
    var medevac = get_node_or_null("/root/World/MedevacSystem")
    if medevac:
        medevac.request_pickup(global_position, urgent)
func heal(amount: float):
    match state:
        InjuryState.WOUNDED_LIGHT: state = InjuryState.HEALTHY
        InjuryState.WOUNDED_HEAVY: state = InjuryState.WOUNDED_LIGHT
        InjuryState.INCAPACITATED: state = InjuryState.WOUNDED_HEAVY