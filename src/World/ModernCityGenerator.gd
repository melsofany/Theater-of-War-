# ModernCityGenerator.gd - يولد مدن حديثة قابلة للدخول بالكامل
# يتكامل مع Phase 2 World + Phase 10c Streaming
extends Node3D
class_name ModernCityGenerator

@export var city_data: Dictionary = {}
@export var district_size: float = 130.0
@export var enable_destruction: bool = true

enum DistrictType { CBD_GLASS, COMMERCIAL, RES_HIGH, RES_LOW, INDUSTRIAL, OLD_TOWN, PORT, GOV_HQ, SUBURB }
enum BuildingType { GLASS_TOWER_10_30, MALL, SHOP_RESTAURANT, BANK_OFFICE, HOSPITAL, SCHOOL, GAS_STATION, PARKING_GARAGE, RES_HIGH_TOWER, RES_LOW_VILLA, GOV_BUILDING, WAREHOUSE_FACTORY }

var districts: Array[Dictionary] = []
var building_system: Node = null
var civilian_system: Node = null

func generate_city(city_center: Vector3) -> void:
    var city_id = city_data.get("id", "unknown")
    var city_name = city_data.get("arabic", city_id)
    print("[ModernCity] Generating %s at %s - %d districts" % [city_name, city_center, 9])
    
    # تحميل الأنظمة
    building_system = load("res://src/World/EnterableBuildingSystem.gd").new()
    civilian_system = load("res://src/World/CivilianTrafficSystem.gd").new()
    add_child(building_system)
    add_child(civilian_system)
    
    # 3x3 grid = 9 districts
    var idx = 0
    for x in range(-1, 2):
        for z in range(-1, 2):
            var district_pos = city_center + Vector3(x * district_size, 0, z * district_size)
            var dtype = _get_district_type_for_index(idx, city_data.get("type", ""))
            var district = _generate_district(district_pos, dtype, idx)
            districts.append(district)
            idx += 1
    
    _spawn_all_buildings()
    _spawn_streets_and_infrastructure()
    _spawn_npcs()
    _init_district_control()

func _get_district_type_for_index(i: int, city_type: String) -> DistrictType:
    # توزيع ذكي حسب نوع المدينة
    if city_type == "coastal_metropolis":
        match i:
            0: return DistrictType.CBD_GLASS
            1: return DistrictType.COMMERCIAL
            2: return DistrictType.PORT
            3: return DistrictType.RES_HIGH
            4: return DistrictType.GOV_HQ
            5: return DistrictType.COMMERCIAL
            6: return DistrictType.RES_LOW
            7: return DistrictType.INDUSTRIAL
            8: return DistrictType.SUBURB
    match i:
        0: return DistrictType.CBD_GLASS
        1: return DistrictType.COMMERCIAL
        2: return DistrictType.PORT
        3: return DistrictType.RES_HIGH
        4: return DistrictType.GOV_HQ
        5: return DistrictType.OLD_TOWN
        6: return DistrictType.RES_LOW
        7: return DistrictType.INDUSTRIAL
        8: return DistrictType.SUBURB
    return DistrictType.COMMERCIAL

func _generate_district(pos: Vector3, dtype: DistrictType, index: int) -> Dictionary:
    var config = {
        "CBD_GLASS": {"height": [10, 30], "street_width": 30.0, "move_cost": 1.0, "cover": 0.2, "visibility": 1.5, "building_count": 55},
        "COMMERCIAL": {"height": [2, 6], "street_width": 25.0, "move_cost": 1.0, "cover": 0.4, "visibility": 1.2, "building_count": 40},
        "RES_HIGH": {"height": [15, 35], "street_width": 15.0, "move_cost": 1.2, "cover": 0.5, "building_count": 45},
        "RES_LOW": {"height": [1, 3], "street_width": 12.0, "move_cost": 1.1, "cover": 0.5, "building_count": 35},
        "OLD_TOWN": {"height": [2, 4], "street_width": 3.0, "move_cost": 2.8, "cover": 0.7, "visibility": 0.5, "building_count": 50}, # حرب عصابات
        "INDUSTRIAL": {"height": [1, 3], "street_width": 20.0, "move_cost": 1.3, "cover": 0.6, "building_count": 30},
        "PORT": {"height": [1, 5], "street_width": 22.0, "move_cost": 1.2, "cover": 0.4, "building_count": 25},
        "GOV_HQ": {"height": [3, 6], "street_width": 28.0, "move_cost": 1.0, "cover": 0.6, "building_count": 20},
        "SUBURB": {"height": [1, 2], "street_width": 10.0, "move_cost": 1.1, "cover": 0.4, "building_count": 30},
    }
    var key = DistrictType.keys()[dtype]
    var c = config.get(key, config["COMMERCIAL"])
    return {
        "id": "%s_d%d" % [city_data.get("id", ""), index],
        "index": index,
        "type": dtype,
        "type_name": key,
        "position": pos,
        "control": "UNCONTROLLED",
        "controlling_faction": null,
        "capture_progress": 0.0,
        "config": c,
        "buildings": [],
        "npcs": [],
        "is_contested": false,
        "combat_intensity": 0.0
    }

func _spawn_all_buildings():
    for district in districts:
        var count = district["config"]["building_count"]
        for i in range(count):
            var btype = _pick_building_for_district(district["type"])
            var building = building_system.create_building(btype, district["position"] + Vector3(randf_range(-50,50), 0, randf_range(-50,50)))
            district["buildings"].append(building)

func _pick_building_for_district(dtype: DistrictType) -> BuildingType:
    match dtype:
        DistrictType.CBD_GLASS: return BuildingType.GLASS_TOWER_10_30
        DistrictType.COMMERCIAL: return [BuildingType.MALL, BuildingType.SHOP_RESTAURANT, BuildingType.BANK_OFFICE].pick_random()
        DistrictType.OLD_TOWN: return [BuildingType.SHOP_RESTAURANT, BuildingType.RES_LOW_VILLA].pick_random()
        DistrictType.RES_HIGH: return BuildingType.RES_HIGH_TOWER
        DistrictType.RES_LOW: return BuildingType.RES_LOW_VILLA
        DistrictType.INDUSTRIAL: return BuildingType.WAREHOUSE_FACTORY
        DistrictType.PORT: return BuildingType.WAREHOUSE_FACTORY
        DistrictType.GOV_HQ: return BuildingType.GOV_BUILDING
        DistrictType.SUBURB: return [BuildingType.RES_LOW_VILLA, BuildingType.SCHOOL, BuildingType.HOSPITAL].pick_random()
        _: return BuildingType.SHOP_RESTAURANT

func _spawn_streets_and_infrastructure():
    # شوارع رئيسية واسعة 25-30م + جانبية ضيقة 3م
    # أنفاق + جسور + مداخل متعددة
    # كل شارع هو supply route للـ Logistics
    for district in districts:
        var width = district["config"]["street_width"]
        # إنشاء Street mesh
        pass

func _spawn_npcs():
    for district in districts:
        var base = 5 if district["type"] == DistrictType.COMMERCIAL else 3
        for i in range(base):
            var npc = civilian_system.spawn_civilian(district["position"], district["id"])
            district["npcs"].append(npc)

func _init_district_control():
    var control_script = load("res://src/World/DistrictControl.gd").new()
    add_child(control_script)
    control_script.init_districts(districts)

func get_control_percentage(faction: String) -> float:
    var count = 0
    for d in districts:
        if d["controlling_faction"] == faction:
            count += 1
    return float(count) / float(districts.size()) * 100.0
