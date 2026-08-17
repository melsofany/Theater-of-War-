extends Node3D
class_name CraterManager
var craters: Array = []
const MAX_CRATERS = 200
const CRATER_LIFETIME = 600.0
@export var crater_decal_scene: PackedScene
@export var terrain: Node
func create_crater(pos: Vector3, caliber: int):
    if craters.size() >= MAX_CRATERS:
        craters.pop_front()
    var radius = caliber / 50.0
    var depth = caliber / 100.0
    var crater = {"pos": pos, "radius": radius, "depth": depth, "caliber": caliber, "time": Time.get_ticks_msec()/1000.0, "cover": 0.6, "blocks_road": caliber > 200}
    craters.append(crater)
    spawn_crater_decal(pos, radius)
    if terrain and terrain.has_method("deform_height"):
        terrain.deform_height(pos, radius, -depth)
    SpatialGrid.register_cover(pos, radius, crater.cover)
func spawn_crater_decal(pos: Vector3, radius: float):
    if not crater_decal_scene: return
    var decal = crater_decal_scene.instantiate()
    decal.global_position = pos + Vector3(0,0.1,0)
    decal.scale = Vector3(radius, radius, radius)
    add_child(decal)
func get_cover_at(pos: Vector3) -> float:
    for c in craters:
        if pos.distance_to(c.pos) < c.radius:
            return c.cover
    return 0.0