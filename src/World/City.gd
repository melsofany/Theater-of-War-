extends StaticBody3D
## City
##
## A settlement on the map. Visually a selectable marker; in Phase 5 a city
## grants its owning faction per-second manpower + materials income (captured
## by moving a unit onto it).

class_name City

@export var city_name: String = "City"
@export var faction: Faction = null
## Faction that currently owns the city for economy income.
var owner_faction: Faction = null
@export var income_manpower: float = 2.0
@export var income_materials: float = 1.5
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


func capture(faction: Faction) -> void:
	owner_faction = faction
	if label:
		label.modulate = faction.color if faction else Color.WHITE
	_update_visuals()


func _update_visuals() -> void:
	if body_mesh and faction:
		var mat := body_mesh.get_surface_override_material(0) as StandardMaterial3D
		if mat:
			mat.albedo_color = faction.color
