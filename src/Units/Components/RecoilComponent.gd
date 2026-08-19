extends Node3D
class_name RecoilComponent
@export var barrel: Node3D
@export var chassis: Node3D
@export var recoil_distance: float = 0.5
@export var recoil_time: float = 0.15
@export var muzzle_flash: GPUParticles3D
func fire():
    if not barrel: return
    var tween = create_tween()
    tween.tween_property(barrel, "position:z", -recoil_distance, recoil_time/2).set_trans(Tween.TRANS_QUAD)
    tween.tween_property(barrel, "position:z", 0, recoil_time/2).set_ease(Tween.EASE_OUT)
    if chassis:
        chassis.position.z -= recoil_distance * 0.3
        var t2 = create_tween()
        t2.tween_property(chassis, "position:z", 0, recoil_time).set_ease(Tween.EASE_OUT)
    if muzzle_flash:
        muzzle_flash.restart()
        muzzle_flash.emitting = true