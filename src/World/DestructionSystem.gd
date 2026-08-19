# DestructionSystem.gd - نظام التدمير الديناميكي
# المدينة في أول المباراة ≠ المدينة بعد 3 ساعات
# يتكامل مع Phase 3 Combat + Phase 7 Intelligence
extends Node3D
class_name DestructionSystem

signal building_damaged(building_id: String, stage: int, rubble_blocks_road: bool)
signal crater_created(pos: Vector3, radius: float)
signal smoke_cloud_created(pos: Vector3, radius: float, blocks_vision: bool)

var craters: Array[Dictionary] = []
var smoke_clouds: Array[Dictionary] = []
var rubble_blocks: Array[Dictionary] = []

func create_crater(pos: Vector3, radius: float, cause: String):
    var crater = {
        "position": pos,
        "radius": radius,
        "cause": cause, # "artillery", "airstrike", "gas_explosion"
        "movement_penalty": 2.0 if radius < 5 else 3.5
    }
    craters.append(crater)
    emit_signal("crater_created", pos, radius)
    print("[Destruction] Crater at %s radius %.1fm cause %s" % [pos, radius, cause])
    
    # حفرة تعيق الحركة
    # يتكامل مع Phase 2 movement cost

func create_smoke(pos: Vector3, radius: float, duration: float, blocks_intel: bool):
    var smoke = {
        "position": pos,
        "radius": radius,
        "duration": duration,
        "blocks_vision": blocks_intel,
        "created_at": Time.get_ticks_msec()
    }
    smoke_clouds.append(smoke)
    if blocks_intel:
        emit_signal("smoke_cloud_created", pos, radius, true)
        # يحجب رؤية Intelligence Phase 7

func apply_artillery_damage(pos: Vector3, radius: float, damage: float):
    # قذيفة مدفعية
    create_crater(pos, radius * 0.5, "artillery")
    create_smoke(pos, radius * 1.5, 30.0, true)
    
    # يدمر مباني في النطاق
    var building_system = get_node_or_null("../EnterableBuildingSystem")
    if building_system:
        for building in building_system.buildings:
            var dist = building["position"].distance_to(pos)
            if dist < radius:
                var dmg = damage * (1.0 - dist / radius)
                building_system.damage_building(building["id"], dmg, "artillery")

func apply_airstrike_damage(pos: Vector3):
    # ضربة جوية - تدمير واسع
    create_crater(pos, 8.0, "airstrike")
    create_smoke(pos, 20.0, 60.0, true)
    # يدمر كل شيء في 15م

func _process(delta: float):
    # تنظيف دخان قديم
    var now = Time.get_ticks_msec()
    smoke_clouds = smoke_clouds.filter(func(s): return (now - s["created_at"]) < s["duration"] * 1000)

func get_destruction_summary() -> Dictionary:
    return {
        "craters": craters.size(),
        "smoke_clouds": smoke_clouds.size(),
        "rubble_blocks": rubble_blocks.size(),
        "total_destruction": craters.size() + rubble_blocks.size()
    }

func is_position_blocked(pos: Vector3) -> bool:
    for crater in craters:
        if pos.distance_to(crater["position"]) < crater["radius"]:
            if crater["movement_penalty"] > 3.0:
                return true
    for rubble in rubble_blocks:
        if pos.distance_to(rubble["position"]) < rubble["radius"]:
            return true
    return false
