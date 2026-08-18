extends Node3D

## StrategicZone
##
## Renders a strategic objective as a readable, non-obstructive border on the
## battlefield. The previous full translucent quad hid terrain and city detail.

class_name StrategicZone

@export var zone_name: String = "Zone"
@export var rect: Rect2 = Rect2(-10, -10, 20, 20)
@export var faction: Faction = null

const BORDER_WIDTH := 1.4
const BORDER_HEIGHT := 0.22

var _root: Node3D


func _ready() -> void:
	_build()


func set_rect(r: Rect2) -> void:
	rect = r
	if is_inside_tree():
		_build()


func _build() -> void:
	for c in get_children():
		c.queue_free()
	_root = Node3D.new()
	_root.name = "ObjectiveBorder"
	add_child(_root)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.96, 0.68, 0.16, 1.0)
	mat.roughness = 0.62
	mat.metallic = 0.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	var width := maxf(absf(rect.size.x), BORDER_WIDTH * 2.0)
	var depth := maxf(absf(rect.size.y), BORDER_WIDTH * 2.0)
	_add_border_piece("North", Vector3(width, BORDER_HEIGHT, BORDER_WIDTH), Vector3(0.0, BORDER_HEIGHT * 0.5, -depth * 0.5 + BORDER_WIDTH * 0.5), mat)
	_add_border_piece("South", Vector3(width, BORDER_HEIGHT, BORDER_WIDTH), Vector3(0.0, BORDER_HEIGHT * 0.5, depth * 0.5 - BORDER_WIDTH * 0.5), mat)
	_add_border_piece("West", Vector3(BORDER_WIDTH, BORDER_HEIGHT, depth), Vector3(-width * 0.5 + BORDER_WIDTH * 0.5, BORDER_HEIGHT * 0.5, 0.0), mat)
	_add_border_piece("East", Vector3(BORDER_WIDTH, BORDER_HEIGHT, depth), Vector3(width * 0.5 - BORDER_WIDTH * 0.5, BORDER_HEIGHT * 0.5, 0.0), mat)

	# Center the border on the source map rectangle, slightly above the terrain.
	global_position = Vector3(rect.position.x + rect.size.x * 0.5, 0.22, rect.position.y + rect.size.y * 0.5)


func _add_border_piece(piece_name: String, dimensions: Vector3, offset: Vector3, mat: Material) -> void:
	var box := BoxMesh.new()
	box.size = dimensions
	var mesh := MeshInstance3D.new()
	mesh.name = piece_name
	mesh.mesh = box
	mesh.material_override = mat
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh.position = offset
	_root.add_child(mesh)
