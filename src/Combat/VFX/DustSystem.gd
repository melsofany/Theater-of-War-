extends GPUParticles3D
class_name DustSystem
enum DustType { MOVEMENT, EXPLOSION, HELI_LANDING, MUZZLE }
@export var wind_direction: Vector3 = Vector3(1,0,0)
func emit_dust(pos: Vector3, intensity: float, d_type: DustType, vehicle_weight: float = 10.0):
    global_position = pos
    match d_type:
        DustType.MOVEMENT:
            amount = int(20 * intensity * vehicle_weight / 10.0)
            lifetime = 2.0
        DustType.EXPLOSION:
            amount = int(100 * intensity)
            lifetime = 4.0
        DustType.HELI_LANDING:
            amount = 150
            lifetime = 3.0
        DustType.MUZZLE:
            amount = 30
            lifetime = 0.8
    emitting = true