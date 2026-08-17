extends Node3D
class_name UnifiedWorldMapV2
@export var map_config_path:String="res://data/maps/unified_world_map_16384.json"
@export var use_real_3d_assets:bool=true
var map_data:Dictionary={}
func _ready():
    var f=FileAccess.open(map_config_path,FileAccess.READ)
    if f:
        var j=JSON.new()
        j.parse(f.get_as_text())
        map_data=j.data
    if use_real_3d_assets:
        _generate_real()
func _generate_real():
    var gen_script=load("res://src/World/RealCityGeneratorV2.gd")
    for city in map_data.get("cities",[]):
        var g=gen_script.new()
        g.city_data=city
        g.position=Vector3(city["pos"][0],0,city["pos"][1])
        add_child(g)
        g.generate_city(g.position)
    var sun=DirectionalLight3D.new()
    sun.light_energy=1.2
    sun.rotation_degrees=Vector3(-45,30,0)
    sun.shadow_enabled=true
    add_child(sun)
