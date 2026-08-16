extends CharacterBody3D
## Unit
##
## Base class for every controllable entity on the battlefield. Handles
## selection highlighting, simple move-to-point steering and faction ownership.
## Combat (Phase 3), command hierarchy (Phase 4) and the like build on this.

class_name Unit

signal died(unit: Unit)

@export var faction: Faction = null
@export var max_speed: float = 8.0
@export var turn_speed: float = 6.0
@export var radius: float = 0.5

var selected: bool = false
var target_position: Vector3 = Vector3.ZERO
var moving: bool = false

@onready var body_mesh: MeshInstance3D = $Body
@onready var selection_ring: MeshInstance3D = $SelectionRing
@onready var agent: NavigationAgent3D = $NavigationAgent


func _ready() -> void:
	target_position = global_position
	_update_visuals()
	if agent:
		agent.radius = radius


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


func move_to(pos: Vector3) -> void:
	target_position = pos
	moving = true
	if agent:
		agent.set_target_position(pos)


func _physics_process(delta: float) -> void:
	if not agent:
		return
	if agent.is_navigation_finished():
		moving = false
		return
	var next := agent.get_next_path_position()
	var dir := (next - global_position)
	dir.y = 0
	var dist := dir.length()
	if dist < 0.05:
		return
	dir = dir.normalized()
	var step: float = min(max_speed * delta, dist)
	global_position += dir * step
	# Keep on the ground plane (y = 0).
	global_position.y = 0.0
	# Face direction of travel.
	if dir.length_squared() > 0.001:
		var look := global_position + dir
		look.y = global_position.y
		var target_basis := Transform3D().looking_at(look - global_position, Vector3.UP).basis
		basis = basis.slerp(target_basis, clamp(turn_speed * delta, 0.0, 1.0))
