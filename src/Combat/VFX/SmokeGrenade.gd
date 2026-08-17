extends Node3D
class_name SmokeGrenade
@export var smoke_width: float = 20.0
@export var smoke_height: float = 8.0
@export var duration: float = 45.0
@onready var particles: GPUParticles3D = $SmokeParticles
@onready var vision_blocker: Area3D = $VisionBlocker
var deployed: bool = false
var deploy_time: float = 0.0
func throw(from: Vector3, to: Vector3):
    global_position = from
    var tween = create_tween()
    tween.tween_property(self, "global_position", to, 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
    tween.tween_callback(deploy)
func deploy(width: float = 20.0, dur: float = 45.0):
    smoke_width = width
    duration = dur
    deployed = true
    deploy_time = Time.get_ticks_msec()/1000.0
    particles.emitting = true
    vision_blocker.monitoring = true
func _process(delta):
    if not deployed: return
    var now = Time.get_ticks_msec()/1000.0
    if now - deploy_time > duration:
        queue_free()
    global_position += Vector3(0.5,0,0) * delta
func is_blocking_vision(pos: Vector3) -> bool:
    return deployed and global_position.distance_to(pos) < smoke_width/2.0