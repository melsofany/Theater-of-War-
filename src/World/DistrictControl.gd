# DistrictControl.gd - نظام السيطرة على أجزاء المدينة - كر وفر حقيقي
# يتكامل مع Phase 5 Economy + Phase 6 Logistics + Phase 7 Intelligence
extends Node
class_name DistrictControl

signal district_contested(district_id: String, old_faction, new_faction)
signal district_captured(district_id: String, faction: String)
signal city_fall_started(city_id: String, faction: String, remaining_districts: int)
signal guerrilla_war_started(city_id: String)

enum ControlState { UNCONTROLLED, CONTESTED, CONTROLLED, FORTIFIED }

var districts_control: Dictionary = {} # district_id -> {state, faction, capture_progress, garrison, combat_intensity}
var city_id: String = ""

func init_districts(districts: Array[Dictionary]):
    for d in districts:
        districts_control[d["id"]] = {
            "state": ControlState.UNCONTROLLED,
            "faction": null,
            "capture_progress": 0.0,
            "garrison": 0,
            "combat_intensity": 0.0,
            "type": d["type_name"],
            "position": d["position"],
            "supply_level": 1.0
        }
    if districts.size() > 0:
        city_id = districts[0]["id"].split("_")[0]

func update_control(district_id: String, attacking_faction: String, infantry_count: int, vehicle_count: int, delta: float):
    if not districts_control.has(district_id):
        return
    var data = districts_control[district_id]
    
    # قانون حرب المدن: المركبات لوحدها لا تسيطر
    if infantry_count == 0:
        return
    
    # لو المنطقة محاصرة (منطقتين حواليها للعدو) - إمداد مقطوع
    if _is_encircled(district_id, attacking_faction):
        data["supply_level"] = max(0.1, data["supply_level"] - delta * 0.5)
    
    var base_speed = infantry_count * 0.12 - data["garrison"] * 0.06
    base_speed *= data["supply_level"]
    
    # قتال عنيف يبطئ الاستيلاء - كر وفر
    if data["combat_intensity"] > 0.6:
        base_speed *= 0.3
    
    # OLD_TOWN أصعب في الاستيلاء
    if data["type"] == "OLD_TOWN":
        base_speed *= 0.5
    
    data["capture_progress"] += base_speed * delta
    
    if data["capture_progress"] >= 100.0:
        _capture_district(district_id, attacking_faction)
    elif data["capture_progress"] > 5.0 and data["faction"] != attacking_faction and data["faction"] != null:
        _set_contested(district_id, attacking_faction)

func _capture_district(id: String, new_faction: String):
    var old_faction = districts_control[id]["faction"]
    districts_control[id]["faction"] = new_faction
    districts_control[id]["state"] = ControlState.CONTROLLED
    districts_control[id]["capture_progress"] = 0.0
    districts_control[id]["combat_intensity"] = 0.0
    emit_signal("district_captured", id, new_faction)
    print("[DistrictControl] %s captured by %s (was %s)" % [id, new_faction, old_faction])
    check_city_fall()

func _set_contested(id: String, attacker: String):
    if districts_control[id]["state"] != ControlState.CONTESTED:
        districts_control[id]["state"] = ControlState.CONTESTED
        districts_control[id]["combat_intensity"] = 0.8
        emit_signal("district_contested", id, districts_control[id]["faction"], attacker)

func _is_encircled(district_id: String, attacker: String) -> bool:
    # لو منطقتين مجاورتين للمهاجم والمنطقة الحالية للمدافع = تطويق
    # يقطع الإمداد
    return false # مبسط - يحتاج A* حقيقي

func check_city_fall():
    var counts = {}
    for id in districts_control:
        var f = districts_control[id]["faction"]
        if f == null: continue
        counts[f] = counts.get(f, 0) + 1
    
    for f in counts:
        if counts[f] >= 6:
            # المدينة سقطت لكن 3 مناطق لسه بتقاوم - حرب عصابات
            var remaining = 9 - counts[f]
            emit_signal("city_fall_started", city_id, f, remaining)
            print("[CITY FALL] %s falls to %s but %d districts still contested - GUERRILLA WAR!" % [city_id, f, remaining])
            if remaining > 0:
                emit_signal("guerrilla_war_started", city_id)
            return f
    return null

func get_control_percentage(faction: String) -> float:
    var c = 0
    for id in districts_control:
        if districts_control[id]["faction"] == faction:
            c += 1
    return float(c) / 9.0 * 100.0

func get_guerrilla_bonus(district_id: String, defender_faction: String) -> float:
    var d = districts_control.get(district_id)
    if not d: return 1.0
    if d["faction"] != defender_faction: return 1.0
    if d["type"] == "OLD_TOWN":
        return 1.7
    if d["type"] == "CBD_GLASS" and d["state"] == ControlState.FORTIFIED:
        return 1.5
    return 1.2

func get_supply_penalty(district_id: String) -> float:
    var d = districts_control.get(district_id)
    if not d: return 1.0
    return d["supply_level"] # 0.1 - 1.0 - يؤثر على Phase 6 Logistics
