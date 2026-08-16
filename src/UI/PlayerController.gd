extends Node3D
## PlayerController
##
## Bridges mouse input to selection + movement orders. Handles single-click
## select, box-drag multi-select, right-click move-to-ground commands and
## control-group assignment/selection (Ctrl+1..9 / 1..9).

class_name PlayerController

@export var unit_scene: PackedScene
@export var building_scene: PackedScene
@export var camera: RTSCamera
@export var world: World
@export var command_marker_scene: PackedScene

var _player_faction: Faction
var _enemy_faction: Faction


func _ready() -> void:
	_player_faction = Faction.make("blue", "Blue Force", Color(0.2, 0.4, 0.9), ["red"], true)
	_enemy_faction = Faction.make("red", "Red Force", Color(0.85, 0.2, 0.2), ["blue"], false)
	if not command_marker_scene:
		command_marker_scene = preload("res://src/UI/CommandMarker.tscn")
	_seed_battlefield()


func _seed_battlefield() -> void:
	if building_scene and world:
		var b := building_scene.instantiate() as Building
		world.units_root.add_child(b)
		b.faction = _player_faction
		b.global_position = Vector3(-8, 0, 0)
		b.unit_scene = unit_scene

	if unit_scene and world:
		for i in 4:
			var u := unit_scene.instantiate() as Unit
			world.units_root.add_child(u)
			u.faction = _player_faction
			u.global_position = Vector3(-4.0 + i * 2.0, 0, 6.0)
			u.set_selected(false)

	if unit_scene and world:
		var e := unit_scene.instantiate() as Unit
		world.units_root.add_child(e)
		e.faction = _enemy_faction
		e.global_position = Vector3(14, 0, -6.0)
		e.set_selected(false)
		# Simple patrol loop for the enemy dummy (real AI is Phase 8).
		e.patrol_points = [
			Vector3(14, 0, -6),
			Vector3(14, 0, 8),
			Vector3(20, 0, 8),
			Vector3(20, 0, -6),
		]


func _unhandled_input(event: InputEvent) -> void:
	if not camera:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			SelectionManager.begin_drag(event.position)
		else:
			_finish_drag(event.position, event.shift_pressed)
	elif event is InputEventMouseMotion and SelectionManager.drag_active:
		SelectionManager.update_drag(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		_issue_move()
	elif event is InputEventKey and event.pressed and not event.echo:
		_handle_key(event)


func _finish_drag(pos: Vector2, additive: bool) -> void:
	var rect: Rect2 = SelectionManager.get_drag_rect()
	if rect.size.length() < 4.0:
		# Treat as single click.
		var sel := _pick_selectable(pos)
		if additive and sel != null and sel.faction and sel.faction.is_player:
			if sel in SelectionManager.selected:
				SelectionManager.remove(sel)
			else:
				SelectionManager.add(sel)
		elif sel != null and sel.faction and sel.faction.is_player:
			SelectionManager.select_single(sel)
		elif not additive:
			SelectionManager.clear()
		return
	var found: Array = []
	for u in world.get_units():
		if not (u.faction and u.faction.is_player):
			continue
		var sp := camera.unproject_position(u.global_position)
		if rect.has_point(sp):
			found.append(u)
	# Buildings only select via single click (not box), so skip here.
	SelectionManager.end_drag(found, additive)


func _pick_selectable(pos: Vector2) -> Node:
	var u := _pick_unit(pos)
	if u != null:
		return u
	# Fall back to buildings.
	var best_dist := 80.0
	var best: Building = null
	for b in world.get_buildings():
		if not (b.faction and b.faction.is_player):
			continue
		var sp := camera.unproject_position(b.global_position)
		var d := sp.distance_to(pos)
		if d < best_dist:
			best_dist = d
			best = b
	return best


func _pick_unit(pos: Vector2) -> Unit:
	var closest: Unit = null
	var best_dist := 64.0  # pixels
	for u in world.get_units():
		if not (u.faction and u.faction.is_player):
			continue
		var sp := camera.unproject_position(u.global_position)
		var d := sp.distance_to(pos)
		if d < best_dist:
			best_dist = d
			closest = u
	return closest


func _issue_move() -> void:
	if SelectionManager.selected.is_empty():
		return
	var ground := camera.ground_point_at_screen(get_viewport().get_mouse_position())
	var count: int = SelectionManager.selected.size()
	var cols: int = int(ceil(sqrt(count)))
	for i in count:
		var row: int = i / cols
		var col: int = i % cols
		var sep := Vector3(float(col - cols / 2), 0, float(row - cols / 2)) * 1.5
		(SelectionManager.selected[i] as Unit).move_to(ground + sep)
	_spawn_move_marker(ground)


func _spawn_move_marker(pos: Vector3) -> void:
	if command_marker_scene and world:
		var m := command_marker_scene.instantiate() as CommandMarker
		world.add_child(m)
		m.play_at(pos)


func _handle_key(event: InputEventKey) -> void:
	# Control groups: Ctrl+1..9 assign, 1..9 select.
	var key := event.keycode
	if key >= KEY_1 and key <= KEY_9:
		var gi: int = key - KEY_1
		if event.ctrl_pressed:
			ControlGroupManager.assign(gi, SelectionManager.selected)
		else:
			ControlGroupManager.select_group(gi)
		return
	match key:
		KEY_B:
			_queue_production_from_selected_building()
		KEY_Y:
			_set_rally_from_selected_building()
		KEY_H:
			_focus_camera_on_selection()


func _get_selected_building() -> Building:
	for b in world.get_buildings():
		if b.selected and b.faction and b.faction.is_player:
			return b
	return null


func _queue_production_from_selected_building() -> void:
	var b := _get_selected_building()
	if b:
		b.queue_unit()


func _set_rally_from_selected_building() -> void:
	var b := _get_selected_building()
	if not b:
		return
	var ground := camera.ground_point_at_screen(get_viewport().get_mouse_position())
	b.set_rally_point(ground)
	_spawn_move_marker(ground)


func _focus_camera_on_selection() -> void:
	if SelectionManager.selected.is_empty():
		return
	var sum := Vector3.ZERO
	var n := 0
	for u in SelectionManager.selected:
		if is_instance_valid(u):
			sum += u.global_position
			n += 1
	if n == 0:
		return
	var center := sum / float(n)
	camera.focus_on(center)
