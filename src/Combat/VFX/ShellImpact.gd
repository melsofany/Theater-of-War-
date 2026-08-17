extends Node3D
class_name ShellImpact
enum ImpactType { HE, AP, SMOKE, ILLUM }
@onready var crater_manager = get_node("/root/World/CraterManager")
@onready var dust_system = get_node("/root/World/DustSystem")
func on_impact(pos: Vector3, impact_type: ImpactType, caliber: int, shooter: Node = null):
    match impact_type:
        ImpactType.HE:
            crater_manager.create_crater(pos, caliber)
            dust_system.emit_dust(pos, caliber/50.0, DustSystem.DustType.EXPLOSION)
            screen_shake(caliber / 100.0)
        ImpactType.SMOKE:
            var smoke = preload("res://src/Combat/VFX/SmokeGrenade.tscn").instantiate()
            smoke.global_position = pos
            smoke.deploy(20.0, 45.0)
            get_tree().current_scene.add_child(smoke)
func screen_shake(intensity: float):
    var cam = get_viewport().get_camera_3d()
    if cam and cam.has_method("shake"):
        cam.shake(intensity, 0.3)