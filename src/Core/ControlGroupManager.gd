extends Node
## ControlGroupManager (autoload)
##
## StarCraft-style control groups. Ctrl+1..9 binds the current selection to a
## group; pressing 1..9 (no modifier) reselects it. Pressing the group key with
## Control held re-centers the view on the group.

signal group_assigned(group_index: int, units: Array)
signal group_selected(group_index: int, units: Array)

const GROUP_COUNT := 9

var _groups: Array = []  # Array of Array[Unit]


func _ready() -> void:
	_groups.resize(GROUP_COUNT)
	for i in GROUP_COUNT:
		_groups[i] = []


func assign(group_index: int, units: Array) -> void:
	if group_index < 0 or group_index >= GROUP_COUNT:
		return
	var g: Array = _groups[group_index]
	g.clear()
	for u in units:
		if is_instance_valid(u):
			g.append(u)
	group_assigned.emit(group_index, g.duplicate())


func select_group(group_index: int) -> void:
	if group_index < 0 or group_index >= GROUP_COUNT:
		return
	var g: Array = _groups[group_index]
	# Drop freed units and rebuild a clean selection.
	var live: Array = []
	for u in g:
		if is_instance_valid(u):
			live.append(u)
	SelectionManager.clear(true)
	for u in live:
		SelectionManager.add(u)
	group_selected.emit(group_index, live.duplicate())


func get_group(group_index: int) -> Array:
	if group_index < 0 or group_index >= GROUP_COUNT:
		return []
	return _groups[group_index]


func center_view_on_group(group_index: int, camera: Camera3D, world_bounds: Rect2) -> Vector2:
	var g := get_group(group_index)
	if g.is_empty():
		return Vector2.ZERO
	var sum := Vector3.ZERO
	var n := 0
	for u in g:
		if is_instance_valid(u):
			sum += u.global_position
			n += 1
	if n == 0:
		return Vector2.ZERO
	var center := sum / float(n)
	if camera:
		camera.global_position.x = center.x
		camera.global_position.z = center.z - 30.0
	return Vector2(center.x, center.z)
