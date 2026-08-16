extends Node3D
## StrategicZone
##
## A rectangular map objective (e.g. a bridgehead, ridge, crossroads). Phase 2
## renders it as a translucent bordered quad on the ground; capture logic is a
## later phase (command/AI scoring).

class_name StrategicZone

@export var zone_name: String = "Zone"
@export var rect: Rect2 = Rect2(-10, -10, 20, 20)
@export var faction: Faction = null

var _mesh: MeshInstance3D


func _ready() -> void:
	_build()


func set_rect(r: Rect2) -> void:
	rect = r
	if is_inside_tree():
		_build()


func _build() -> void:
	for c in get_children():
		c.queue_free()
	var plane := PlaneMesh.new()
	plane.size = rect.size
	plane.orientation = 2  # PlaneMesh.Orientation.Y
	_mesh = MeshInstance3D.new()
	_mesh.mesh = plane
	_mesh.cast_shadow = 0
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.85, 0.3, 0.25)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mesh.material_override = mat
	add_child(_mesh)
	# Center the zone on rect.center, lifted slightly to avoid z-fighting.
	global_position = Vector3(rect.position.x + rect.size.x * 0.5, 0.15, rect.position.y + rect.size.y * 0.5)
