# CivilianTrafficSystem.gd - دورة حياة السكان والمرور
# قبل المعركة -> ذعر -> هروب جماعي -> مدينة فارغة
extends Node3D
class_name CivilianTrafficSystem

signal civilians_fleeing(district_id: String, count: int, traffic_jam: bool)
signal road_blocked_by_abandoned_cars(road_id: String)
signal city_empty(city_id: String)

enum CivilianState { NORMAL, PANIC, FLEEING, HIDING, EVACUATED, TRAPPED }

var civilians: Array[Dictionary] = []
var traffic_level: float = 1.0 # 1.0 طبيعي، 1.5 زحمة هروب، 0.2 فارغة
var shops_open: float = 1.0
var combat_intensity_map: Dictionary = {} # district_id -> intensity 0-1

func spawn_civilian(pos: Vector3, district_id: String) -> Dictionary:
    var types = ["family", "employee", "student", "shopkeeper", "driver", "teacher", "doctor"]
    var civ = {
        "id": "civ_%d" % civilians.size(),
        "type": types.pick_random(),
        "position": pos,
        "district_id": district_id,
        "state": CivilianState.NORMAL,
        "has_car": randf() > 0.4,
        "flee_threshold": randf_range(0.4, 0.8),
        "panic_level": 0.0,
        "target_safe_zone": null
    }
    civilians.append(civ)
    return civ

func update_civilian_system(delta: float, district_combat: Dictionary):
    combat_intensity_map = district_combat
    
    for civ in civilians:
        var intensity = combat_intensity_map.get(civ["district_id"], 0.0)
        _update_civilian_state(civ, intensity, delta)
    
    _update_traffic_level()
    _update_shops_state()

func _update_civilian_state(civ: Dictionary, intensity: float, delta: float):
    match civ["state"]:
        CivilianState.NORMAL:
            if intensity > civ["flee_threshold"]:
                civ["state"] = CivilianState.PANIC
                civ["panic_level"] = intensity
                print("[Civilian] %s panic in %s (intensity %.2f)" % [civ["id"], civ["district_id"], intensity])
        CivilianState.PANIC:
            civ["panic_level"] = lerp(civ["panic_level"], intensity, delta * 2.0)
            if civ["has_car"]:
                civ["state"] = CivilianState.FLEEING
                civ["target_safe_zone"] = _find_safe_district(civ["district_id"])
                emit_signal("civilians_fleeing", civ["district_id"], 1, false)
            else:
                if intensity > 0.7:
                    civ["state"] = CivilianState.HIDING
        CivilianState.FLEEING:
            # يحاول يهرب بسيارته
            # لو الطريق مسدود، يترك السيارة ويهرب مشي
            if _is_road_blocked(civ["district_id"]):
                civ["has_car"] = false
                civ["state"] = CivilianState.HIDING
                emit_signal("road_blocked_by_abandoned_cars", civ["district_id"])
                # سيارة متروكة تسد الشارع - تؤثر على حركة الجيش
            elif _reached_safe_zone(civ):
                civ["state"] = CivilianState.EVACUATED
        CivilianState.HIDING:
            if intensity < 0.3:
                civ["state"] = CivilianState.FLEEING

func _find_safe_district(current_district: String) -> String:
    # يبحث عن منطقة آمنة (intensity < 0.3) في نفس المدينة أو مدينة أخرى
    for district_id in combat_intensity_map:
        if combat_intensity_map[district_id] < 0.3 and district_id != current_district:
            return district_id
    return "outside_city"

func _is_road_blocked(district_id: String) -> bool:
    var intensity = combat_intensity_map.get(district_id, 0)
    # لو intensity عالي + سيارات كتير متروكة = طريق مسدود
    return intensity > 0.8 and randf() > 0.6

func _reached_safe_zone(civ: Dictionary) -> bool:
    return randf() > 0.7 # مبسط

func _update_traffic_level():
    var fleeing = 0
    var normal = 0
    for civ in civilians:
        if civ["state"] == CivilianState.FLEEING:
            fleeing += 1
        elif civ["state"] == CivilianState.NORMAL:
            normal += 1
    
    if fleeing > normal:
        traffic_level = 1.5 # زحمة هروب
    elif fleeing == 0 and normal == 0:
        traffic_level = 0.2 # مدينة فارغة
    else:
        traffic_level = 1.0

func _update_shops_state():
    var avg_intensity = 0.0
    for v in combat_intensity_map.values():
        avg_intensity += v
    if combat_intensity_map.size() > 0:
        avg_intensity /= combat_intensity_map.size()
    
    if avg_intensity > 0.6:
        shops_open = 0.0 # كل المحلات قفلت
    elif avg_intensity > 0.3:
        shops_open = 0.3
    else:
        shops_open = 1.0

func get_movement_penalty_for_military(district_id: String) -> float:
    # تأثير زحمة السكان على حركة الجيش
    if traffic_level > 1.3:
        return 2.5 # زحمة هروب تبطئ الجيش
    if _is_road_blocked(district_id):
        return 3.0 # طريق مسدود بسيارات متروكة وأنقاض
    return 1.0

func get_civilian_count_in_district(district_id: String) -> int:
    var count = 0
    for civ in civilians:
        if civ["district_id"] == district_id and civ["state"] != CivilianState.EVACUATED:
            count += 1
    return count
