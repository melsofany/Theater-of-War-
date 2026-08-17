extends Node3D
## Hotfix_FullWorld
##
## Applies the attached Meta AI visual hotfix without replacing the existing
## projected Unified World Map. The source map is 16384x16384, while the RTS
## runtime projects it into the current playable MapData bounds.

class_name HotfixFullWorld

@export var fix_transparency: bool = true
@export var add_ground: bool = true
@export var ground_scene: PackedScene

const GROUND_SCENE_PATH := "res://scenes/terrain/Ground_Fixed_16384.tscn"
const OPAQUE_MATERIAL_PATH := "res://assets/materials/glass_fixed_opaque.tres"


func _ready() -> void:
	call_deferred("_apply_hotfix")


func _apply_hotfix() -> void:
	if add_ground:
		_add_ground()
	if fix_transparency:
		_fix_transparent_buildings()


func _add_ground() -> void:
	if get_node_or_null("Ground_Fixed_16384") != null:
		return
	var packed: PackedScene = ground_scene
	if packed == null:
		packed = load(GROUND_SCENE_PATH) as PackedScene
	if packed == null:
		push_warning("HotfixFullWorld: Ground_Fixed_16384.tscn could not be loaded")
		return
	var ground := packed.instantiate() as Node3D
	if ground == null:
		return
	ground.name = "Ground_Fixed_16384"
	# UnifiedMapAdapter projects the 16384 source map around Vector3.ZERO.
	# Keep the large safety plane centered there so it is visible to the RTS.
	ground.position = Vector3.ZERO
	add_child(ground)


func _fix_transparent_buildings() -> void:
	var opaque := load(OPAQUE_MATERIAL_PATH) as Material
	if opaque == null:
		push_warning("HotfixFullWorld: opaque glass material could not be loaded")
		return
	var world := get_node_or_null("../World")
	if world == null:
		return
	var features := world.get_node_or_null("Features")
	if features != null:
		_apply_opaque_material(features, opaque)


func _apply_opaque_material(node: Node, opaque: Material) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			var label := child.name.to_lower()
			if label.contains("tower") or label.contains("glass") or label.contains("core"):
				(child as MeshInstance3D).material_override = opaque
		_apply_opaque_material(child, opaque)
