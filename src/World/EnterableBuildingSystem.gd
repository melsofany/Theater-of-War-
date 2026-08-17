# EnterableBuildingSystem.gd - المباني قابلة للدخول بدرجات مختلفة
# كل مبنى له طوابق قابلة للتحصين، غطاء، ميزات
extends Node3D
class_name EnterableBuildingSystem

enum BuildingType { GLASS_TOWER_10_30, MALL, SHOP_RESTAURANT, BANK_OFFICE, HOSPITAL, SCHOOL, GAS_STATION, PARKING_GARAGE, RES_HIGH_TOWER, RES_LOW_VILLA, GOV_BUILDING, WAREHOUSE_FACTORY }
enum DestructionStage { INTACT, GLASS_BROKEN, FACADE_FALLEN, SMOKE_FIRE, PARTIAL_COLLAPSE, RUBBLE }

var buildings: Array[Dictionary] = []

func create_building(btype: BuildingType, pos: Vector3) -> Dictionary:
    var defs = {
        BuildingType.GLASS_TOWER_10_30: {"floors": [10,30], "enter": "full_all_floors", "cover": 0.2, "visibility": 1.5, "sniper": 0.5, "material": "glass", "stages": 4, "width": 25},
        BuildingType.MALL: {"floors": [2,4], "enter": "2_floors_plus_roof", "cover": 0.4, "loot": "supplies", "stages": 3, "width": 40},
        BuildingType.SHOP_RESTAURANT: {"floors": [1,2], "enter": "ground_plus_storage", "cover": 0.6, "ambush": 0.4, "stages": 2, "width": 12},
        BuildingType.BANK_OFFICE: {"floors": [5,15], "enter": "office_fortifiable", "cover": 0.5, "intel": "documents", "stages": 3, "width": 20},
        BuildingType.HOSPITAL: {"floors": [4,8], "enter": "full_plus_basement", "cover": 0.7, "medic": true, "stages": 4, "width": 30},
        BuildingType.SCHOOL: {"floors": [2,4], "enter": "classrooms_plus_roof", "cover": 0.6, "civilian": "kids", "stages": 3, "width": 35},
        BuildingType.GAS_STATION: {"floors": [1,1], "enter": "shop_plus_tanks", "cover": 0.1, "fuel": true, "explosion": 80, "stages": 1, "width": 15},
        BuildingType.PARKING_GARAGE: {"floors": [3,6], "enter": "multi_level", "cover": "vehicles", "stages": 2, "width": 30},
        BuildingType.RES_HIGH_TOWER: {"floors": [15,35], "enter": "apartments", "cover": 0.5, "stages": 3, "width": 22},
        BuildingType.RES_LOW_VILLA: {"floors": [1,3], "enter": "villa", "cover": 0.5, "stages": 2, "width": 15},
        BuildingType.GOV_BUILDING: {"floors": [3,6], "enter": "full_fortified", "cover": 0.6, "hq": true, "stages": 4, "width": 28},
        BuildingType.WAREHOUSE_FACTORY: {"floors": [1,3], "enter": "open_space", "cover": "crates", "production": "ammo", "stages": 3, "width": 45},
    }
    var key = BuildingType.keys()[btype]
    var def = defs.get(btype, defs[BuildingType.SHOP_RESTAURANT])
    var floors = randi_range(def["floors"][0], def["floors"][1])
    
    var building = {
        "id": "b_%d_%d" % [pos.x, pos.z],
        "type": btype,
        "type_name": key,
        "position": pos,
        "floors": floors,
        "enterability": def["enter"],
        "cover": def["cover"],
        "destruction_stage": DestructionStage.INTACT,
        "health": 100.0,
        "is_entered": false,
        "garrison": [],
        "definition": def
    }
    buildings.append(building)
    
    # إنشاء MeshInstance3D فعلي (مبسط)
    var mesh_instance = _create_mesh_for_building(building)
    
    return building

func _create_mesh_for_building(b: Dictionary) -> MeshInstance3D:
    var mi = MeshInstance3D.new()
    # ارتفاع = طوابق * 3.5م
    var height = b["floors"] * 3.5
    var box = BoxMesh.new()
    box.size = Vector3(b["definition"]["width"], height, b["definition"]["width"])
    mi.mesh = box
    mi.position = b["position"] + Vector3(0, height/2.0, 0)
    
    # ماتيريال حسب النوع
    var mat = StandardMaterial3D.new()
    if b["type"] == BuildingType.GLASS_TOWER_10_30:
        mat.albedo_color = Color(0.66, 0.85, 1.0, 0.6)
        mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        mat.metallic = 0.1
        mat.roughness = 0.05
        mat.emission_enabled = true
        mat.emission = Color(0.2, 0.4, 0.8) * 0.3 # إضاءة زجاجية
    elif b["type"] == BuildingType.GAS_STATION:
        mat.albedo_color = Color(1.0, 0.8, 0.2)
    else:
        mat.albedo_color = Color(0.8, 0.8, 0.82)
    
    mi.set_surface_override_material(0, mat)
    add_child(mi)
    return mi

func damage_building(building_id: String, damage: float, damage_type: String):
    for b in buildings:
        if b["id"] == building_id:
            b["health"] -= damage
            _update_destruction_stage(b)
            if b["type"] == BuildingType.GAS_STATION and b["health"] <= 0:
                _trigger_gas_explosion(b)
            break

func _update_destruction_stage(b: Dictionary):
    var h = b["health"]
    var old_stage = b["destruction_stage"]
    if h <= 0:
        b["destruction_stage"] = DestructionStage.RUBBLE
    elif h <= 25:
        b["destruction_stage"] = DestructionStage.PARTIAL_COLLAPSE
    elif h <= 50:
        b["destruction_stage"] = DestructionStage.SMOKE_FIRE
    elif h <= 75:
        b["destruction_stage"] = DestructionStage.FACADE_FALLEN
    elif h <= 90:
        b["destruction_stage"] = DestructionStage.GLASS_BROKEN
    else:
        b["destruction_stage"] = DestructionStage.INTACT
    
    if old_stage != b["destruction_stage"]:
        print("[Building] %s %s: %s -> %s (%.0f HP)" % [b["type_name"], b["id"], DestructionStage.keys()[old_stage], DestructionStage.keys()[b["destruction_stage"]], h])
        # يغلق الطريق بالأنقاض لو انهيار
        if b["destruction_stage"] == DestructionStage.RUBBLE:
            _block_road_with_rubble(b)

func _trigger_gas_explosion(b: Dictionary):
    print("[EXPLOSION] Gas station %s exploded! Radius 80m" % b["id"])
    # انفجار ضخم + حريق + دخان أسود يحجب Intelligence
    # يؤثر على كل المباني في 80م
    for other in buildings:
        if other["position"].distance_to(b["position"]) < 80:
            damage_building(other["id"], 60, "explosion")

func _block_road_with_rubble(b: Dictionary):
    # الأنقاض تغلق الشارع - يغير خريطة الحركة
    # يتكامل مع Phase 2 movement cost
    pass

func can_enter(building_id: String, unit_type: String) -> bool:
    # المشاة يدخلوا كل المباني، المركبات لا
    if unit_type in ["infantry", "special_forces"]:
        return true
    if unit_type in ["vehicle", "tank"] and building_id.contains("PARKING"):
        return true # الدبابات تدخل مواقف السيارات فقط
    return false

func get_cover_bonus(building_id: String) -> float:
    for b in buildings:
        if b["id"] == building_id:
            if b["type"] == BuildingType.GLASS_TOWER_10_30:
                return 0.2 if b["destruction_stage"] == DestructionStage.INTACT else 0.8 # بعد التدمير غطاء أفضل
            return b["cover"]
    return 0.5
