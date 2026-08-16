extends StaticBody3D
## Building
##
## A static, selectable structure (HQ / factory / barracks placeholder for
## Phase 0). Production is Phase 5; here it only provides a selectable target
## and a spawn anchor for new units.

class_name Building

@export var faction: Faction = null
@export var display_name: String = "Building"

var selected: bool = false

@onready var body_mesh: MeshInstance3D = $Body
@onready var selection_ring: MeshInstance3D = $SelectionRing


func _ready() -> void:
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
	return global_position + Vector3(2.0, 0.0, 0.0)
