extends StaticBody3D
## City
##
## A settlement on the map. In Phase 2 it is a visual + selectable marker with
## a name; production/capture mechanics arrive in later phases (Economy,
## command).

class_name City

@export var city_name: String = "City"
@export var faction: Faction = null
var selected: bool = false

@onready var body_mesh: MeshInstance3D = $Body
@onready var label: Label3D = $Label


func _ready() -> void:
	if label:
		label.text = city_name
	_update_visuals()


func set_selected(value: bool) -> void:
	selected = value
	_update_visuals()


func _update_visuals() -> void:
	if body_mesh and faction:
		var mat := body_mesh.get_surface_override_material(0) as StandardMaterial3D
		if mat:
			mat.albedo_color = faction.color
