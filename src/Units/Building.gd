extends StaticBody3D
## Building
##
## A static, selectable structure (HQ / factory / barracks placeholder). In
## Phase 1 the HQ can queue unit production (no resource cost yet — Economy is
## Phase 5) and emit finished units at a rally point.

class_name Building

@export var faction: Faction = null
@export var display_name: String = "Building"
@export var unit_scene: PackedScene
@export var build_time: float = 3.0
@export var max_queue: int = 5

var selected: bool = false
var production_queue: Array[float] = []
var rally_point: Vector3 = Vector3.ZERO

@onready var body_mesh: MeshInstance3D = $Body
@onready var selection_ring: MeshInstance3D = $SelectionRing


func _ready() -> void:
	rally_point = get_spawn_point()
	_update_visuals()


func set_selected(value: bool) -> void:
	selected = value
	_update_visuals()


func _update_visuals() -> void:
	if selection_ring:
		selection_ring.visible = selected
	if body_mesh and faction:
		var mat := body_mesh.get_surface_override_material(0) as StandardMaterial3D
		if mat:
			mat.albedo_color = faction.color


func get_spawn_point() -> Vector3:
	return global_position + Vector3(3.0, 0.0, 0.0)


func queue_unit() -> bool:
	if production_queue.size() >= max_queue:
		return false
	production_queue.append(build_time)
	return true


func set_rally_point(pos: Vector3) -> void:
	rally_point = pos


func _process(delta: float) -> void:
	if production_queue.is_empty():
		return
	production_queue[0] -= delta
	if production_queue[0] <= 0.0:
		production_queue.pop_front()
		_spawn_unit()


func _spawn_unit() -> void:
	if not unit_scene:
		return
	var u := unit_scene.instantiate() as Unit
	if not u:
		return
	# Add to the world's unit root if reachable, else to our parent.
	var host: Node = get_parent()
	while host and not (host is World):
		host = host.get_parent()
	if host and host is World:
		(host as World).units_root.add_child(u)
	else:
		get_parent().add_child(u)
	u.faction = faction
	u.global_position = get_spawn_point()
	# Send the freshly built unit to the rally point.
	u.move_to(rally_point)

