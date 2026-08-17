extends Node3D
class_name FullWorldRealGenerator
# مولد العالم الكامل بأصول 3D حقيقية - كل شيء مش BoxMesh بسيط

@export var map_config_path:String="res://data/maps/unified_world_map_16384.json"
@export var use_real_assets:bool=true

var map_data:Dictionary={}

func _ready():
    _load_config()
    if use_real_assets:
        print("[FullWorldReal] Generating FULL world with REAL 3D assets - villages, forests, roads, desert, mountains")
        _generate_terrain_real()
        _generate_villages_real()
        _generate_roads_real()
        _generate_forests_farms_real()
        _generate_infrastructure_real()

func _load_config():
    var f=FileAccess.open(map_config_path,FileAccess.READ)
    if f:
        var j=JSON.new()
        j.parse(f.get_as_text())
        map_data=j.data

func _generate_terrain_real():
    # الصحراء الغربية - كثبان + واحات + مناجم
    var desert_scenes=["res://scenes/terrain/Desert_Dunes_Field.tscn","res://scenes/terrain/Oasis_With_Palms.tscn","res://scenes/terrain/Mining_Facility.tscn"]
    for i in range(15):
        var pos=Vector3(randf_range(0,4000),0,randf_range(3500,10500))
        var scene_path=desert_scenes.pick_random()
        var inst=load(scene_path).instantiate()
        inst.position=pos
        add_child(inst)

func _generate_villages_real():
    # قرى في وسط الصحراء - قرى جبلية - بلدات دلتا - قرى زراعية
    var village_data=[
        {"scene":"res://scenes/villages/Desert_Village_Small.tscn","zone":"western_desert","count":8},
        {"scene":"res://scenes/villages/Mountain_Village.tscn","zone":"eastern_heights","count":6},
        {"scene":"res://scenes/villages/Delta_Town_Connected.tscn","zone":"delta_ops","count":10},
        {"scene":"res://scenes/villages/Farming_Village.tscn","zone":"delta_ops","count":12}
    ]
    for vd in village_data:
        for i in range(vd["count"]):
            var inst=load(vd["scene"]).instantiate()
            # موقع عشوائي داخل المنطقة
            var zone_bounds=_get_zone_bounds(vd["zone"])
            inst.position=Vector3(randf_range(zone_bounds[0],zone_bounds[2]),0,randf_range(zone_bounds[1],zone_bounds[3]))
            add_child(inst)

func _generate_roads_real():
    # كل الطرق بأصول حقيقية
    var roads=map_data.get("roads",{}).get("highways",[])
    for road in roads:
        var scene_path=_get_road_scene_for_type(road["type"])
        var inst=load(scene_path).instantiate()
        # حساب المواقع بين المدن
        var from_city=_find_city(road["from"])
        var to_city=_find_city(road["to"])
        if from_city and to_city:
            var mid=(Vector3(from_city["pos"][0],0,from_city["pos"][1])+Vector3(to_city["pos"][0],0,to_city["pos"][1]))/2
            inst.position=mid
            # دوران حسب الاتجاه
            var dir=Vector3(to_city["pos"][0]-from_city["pos"][0],0,to_city["pos"][1]-from_city["pos"][1]).normalized()
            inst.rotation.y=atan2(dir.x,dir.z)
            add_child(inst)

func _generate_forests_farms_real():
    # غابات خفيفة وكثيفة + مزارع بين المدن
    for i in range(20):
        var forest=load("res://scenes/nature/Forest_Light_Patch.tscn").instantiate()
        forest.position=Vector3(randf_range(4000,11000),0,randf_range(3500,7500))
        add_child(forest)
    for i in range(15):
        var dense=load("res://scenes/nature/Forest_Dense.tscn").instantiate()
        dense.position=Vector3(randf_range(11000,13000),0,randf_range(0,6000))
        add_child(dense)
    for i in range(25):
        var farm=load("res://scenes/nature/Farm_Fields_Cluster.tscn").instantiate()
        farm.position=Vector3(randf_range(4000,8000),0,randf_range(4000,7000))
        add_child(farm)

func _generate_infrastructure_real():
    # نقاط تفتيش + جسور + محطات وقود صحراوية + أنفاق
    var checkpoints=map_data.get("roads",{}).get("checkpoints",[])
    for cp in checkpoints:
        var inst=load("res://scenes/infrastructure/Checkpoint.tscn").instantiate()
        inst.position=Vector3(cp["pos"][0],0,cp["pos"][1])
        add_child(inst)
    # جسور على الأنهار
    for i in range(12):
        var bridge=load("res://scenes/roads/Bridge_River.tscn").instantiate()
        bridge.position=Vector3(randf_range(3000,10000),0,randf_range(3000,8000))
        add_child(bridge)
    # محطات وقود صحراوية
    for i in range(10):
        var gas=load("res://scenes/infrastructure/Gas_Station_Desert.tscn").instantiate()
        gas.position=Vector3(randf_range(0,4000),0,randf_range(3500,10500))
        add_child(gas)
    # أنفاق جبلية
    for i in range(5):
        var tunnel=load("res://scenes/roads/Mountain_Road_Tunnel.tscn").instantiate()
        tunnel.position=Vector3(randf_range(11000,16000),0,randf_range(6000,10000))
        add_child(tunnel)

func _get_zone_bounds(zone_id:String)->Array:
    for zone in map_data.get("zones",[]):
        if zone["id"]==zone_id:
            return zone["bounds"]
    return [0,0,1000,1000]

func _find_city(city_id:String):
    for city in map_data.get("cities",[]):
        if city["id"]==city_id:
            return city
    return null

func _get_road_scene_for_type(type:String)->String:
    match type:
        "highway": return "res://scenes/roads/Highway_6Lanes.tscn"
        "desert_highway": return "res://scenes/roads/Desert_Highway_2Lanes.tscn"
        "mountain_road": return "res://scenes/roads/Mountain_Road_Tunnel.tscn"
        "coastal_road": return "res://scenes/roads/Highway_6Lanes.tscn"
        _: return "res://scenes/roads/Desert_Highway_2Lanes.tscn"
