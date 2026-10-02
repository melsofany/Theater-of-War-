extends Node3D
## CommandMarker
##
## Visual feedback drawn at a move-order destination: a ring that expands and
## fades over ~0.6s so the player sees where they ordered units to go.
## Pooled by spawning on demand; auto-frees when the animation finishes.

class_name CommandMarker

@export var duration: float = 0.6
@export var start_radius: float = 0.4
@export var end_radius: float = 2.2

var _t: float = 0.0
var _mesh: MeshInstance3D
var _inner_mesh: MeshInstance3D
var _mat: StandardMaterial3D
var _inner_mat: StandardMaterial3D


func _ready() -> void:
	_mesh = MeshInstance3D.new()
	_mesh.mesh = TorusMesh.new()
	_mesh.cast_shadow = 0  # GeometryInstance3D.ShadowCastingSetting.OFF
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.albedo_color = Color(0.0, 0.95, 1.0, 0.95)
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.no_depth_test = true
	_mesh.material_override = _mat
	_mesh.rotation_degrees.x = 90.0
	add_child(_mesh)

	_inner_mesh = MeshInstance3D.new()
	_inner_mesh.mesh = TorusMesh.new()
	_inner_mesh.cast_shadow = 0
	_inner_mat = StandardMaterial3D.new()
	_inner_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_inner_mat.albedo_color = Color(0.85, 0.2, 1.0, 0.9)
	_inner_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_inner_mat.no_depth_test = true
	_inner_mesh.material_override = _inner_mat
	_inner_mesh.rotation_degrees.x = 90.0
	add_child(_inner_mesh)


func play_at(pos: Vector3) -> void:
	global_position = pos
	global_position.y = 0.05
	_t = 0.0


func _process(delta: float) -> void:
	_t += delta
	var p: float = clamp(_t / duration, 0.0, 1.0)
	var r: float = lerpf(start_radius, end_radius, p)
	var torus := _mesh.mesh as TorusMesh
	if torus:
		torus.inner_radius = r * 0.78
		torus.outer_radius = r
	var inner_torus := _inner_mesh.mesh as TorusMesh
	if inner_torus:
		var r_in := lerpf(start_radius * 0.5, end_radius * 0.65, p)
		inner_torus.inner_radius = r_in * 0.6
		inner_torus.outer_radius = r_in

	_mat.albedo_color = Color(0.0, 0.95, 1.0, lerpf(0.95, 0.0, p))
	_inner_mat.albedo_color = Color(0.85, 0.2, 1.0, lerpf(0.9, 0.0, p))

	if _t >= duration:
		queue_free()
