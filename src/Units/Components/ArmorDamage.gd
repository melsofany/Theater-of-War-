extends Node3D
class_name ArmorDamage
enum DamageZone { FRONT, SIDE, REAR, TRACKS, TURRET, ENGINE }
var damage_zones: Dictionary = {DamageZone.FRONT:0.0, DamageZone.SIDE:0.0, DamageZone.REAR:0.0, DamageZone.TRACKS:0.0, DamageZone.TURRET:0.0, DamageZone.ENGINE:0.0}
var immobilized: bool = false
var engine_dead: bool = false
var turret_jammed: bool = false
@export var vehicle: Node
func take_hit(zone: DamageZone, penetration: float, caliber: int):
    damage_zones[zone] += penetration
    match zone:
        DamageZone.TRACKS:
            if damage_zones[zone] > 0.7:
                immobilized = true
                if vehicle.has_method("request_tow"):
                    vehicle.request_tow()
        DamageZone.ENGINE:
            if damage_zones[zone] > 0.8:
                engine_dead = true
        DamageZone.TURRET:
            if damage_zones[zone] > 0.6:
                turret_jammed = true
func can_be_towed() -> bool:
    return immobilized and not engine_dead
func repair(amount: float):
    for zone in damage_zones:
        damage_zones[zone] = max(0, damage_zones[zone] - amount)