extends Node3D
## PlayerController
##
## Bridges mouse input to selection + movement orders. Handles single-click
## select, box-drag multi-select, right-click move-to-ground commands,
## control-group assignment/selection (Ctrl+1..9 / 1..9) and the command
## hierarchy (V/[/]: select / promote / drill the active command node so an
## order can move a whole brigade instead of each unit).

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
	_setup_economy()
	_build_command_tree()


func _setup_economy() -> void:
	Economy.clear()
	Economy.world = world
	Logistics.clear()
	Logistics.world = world
	Intelligence.clear()
	Intelligence.world = world
	# Starting resources for each faction.
	Economy.register_faction(_player_faction.name,
		{Economy.R.MANPOWER: 200.0, Economy.R.FUEL: 150.0, Economy.R.MATERIALS: 300.0})
	Economy.register_faction(_enemy_faction.name,
		{Economy.R.MANPOWER: 200.0, Economy.R.FUEL: 150.0, Economy.R.MATERIALS: 300.0})
	# The player owns the city nearest their HQ (if any).
	if world:
		var best: City = null
		var best_d := 1e9
		for c in world.get_cities():
			c.capture(_enemy_faction)
			var d: float = c.global_position.distance_squared_to(Vector3(-8, 0, 0))
			if d < best_d:
				best_d = d
				best = c
		if best:
			best.capture(_player_faction)
	Economy.recompute_income(_player_faction.name)
	Economy.recompute_income(_enemy_faction.name)


func _build_command_tree() -> void:
	if not world:
		return
	var player_units: Array = []
	for u in world.get_units():
		if u.faction and u.faction.is_player:
			player_units.append(u)
	CommandTree.build_for(player_units)


func _process(_delta: float) -> void:
	_check_city_capture()
	_apply_fog_of_war()


func _check_city_capture() -> void:
	if not world:
		return
	var changed := false
	for c in world.get_cities():
		for u in world.get_units():
			if not u.alive:
				continue
			if u.faction == null:
				continue
			if c.owner_faction == u.faction:
				continue
			if u.global_position.distance_to(c.global_position) < 3.0:
				c.capture(u.faction)
				changed = true
	if changed:
		Economy.recompute_income(_player_faction.name)
		Economy.recompute_income(_enemy_faction.name)


func _seed_battlefield() -> void:
	if building_scene and world:
		var b := building_scene.instantiate() as Building
		world.units_root.add_child(b)
		b.faction = _player_faction
		b.global_position = Vector3(-8, world.ground_height_at(-8, 0), 0)
		b.unit_scene = unit_scene
		b.produced_unit_key = "infantry"

	if unit_scene and world:
		# A mixed player force: two infantry + a tank.
		var keys := ["infantry", "infantry", "tank"]
		for i in keys.size():
			var u := unit_scene.instantiate() as Unit
			world.units_root.add_child(u)
			u.faction = _player_faction
			u.world = world
			if UnitFactory:
				u.unit_type = UnitFactory.get_type(keys[i])
			var x := -4.0 + i * 2.0
			u.global_position = Vector3(x, world.ground_height_at(x, 6.0), 6.0)
			u.set_selected(false)

	if unit_scene and world:
		# Enemy force: an infantry squad + an air-defense unit (to threaten air).
		var ekeys := ["infantry", "infantry", "air_defense"]
		for i in ekeys.size():
			var e := unit_scene.instantiate() as Unit
			world.units_root.add_child(e)
			e.faction = _enemy_faction
			e.world = world
			if UnitFactory:
				e.unit_type = UnitFactory.get_type(ekeys[i])
			var x := 14.0 + i * 2.0
			e.global_position = Vector3(x, world.ground_height_at(x, -6.0), -6.0)
			e.set_selected(false)
			e.patrol_points = [
				Vector3(x, 0, -6),
				Vector3(x, 0, 8),
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
	var ground := camera.ground_point_at_screen(get_viewport().get_mouse_position())
	# If a command node is active and at least one selected unit belongs to it,
	# issue the order to the whole node (formation spread).
	var use_command := false
	if CommandTree.active_node != null and not SelectionManager.selected.is_empty():
		var active_units: Array = CommandTree.active_node.collect_units()
		for s in SelectionManager.selected:
			if s in active_units:
				use_command = true
				break
	if use_command:
		CommandTree.active_node.order_move(ground)
		_spawn_move_marker(ground)
		return
	if SelectionManager.selected.is_empty():
		return
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
		KEY_V:
			_select_command_of_selection()
		KEY_BRACKETLEFT:
			CommandTree.promote()
			_select_active_command_units()
		KEY_BRACKETRIGHT:
			CommandTree.drill()
			_select_active_command_units()


func _get_selected_building() -> Building:
	for b in world.get_buildings():
		if b.selected and b.faction and b.faction.is_player:
			return b
	return null


func _queue_production_from_selected_building() -> void:
	var b := _get_selected_building()
	if not b:
		return
	var cost: Dictionary = UnitFactory.cost_of(b.produced_unit_key)
	if not Economy.can_afford(_player_faction.name, cost):
		return
	if b.queue_unit():
		Economy.spend(_player_faction.name, cost)


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


# --- Command hierarchy ------------------------------------------------------

func _select_command_of_selection() -> void:
	if SelectionManager.selected.is_empty():
		return
	var first = SelectionManager.selected[0]
	if first is Unit:
		CommandTree.select_node_of(first)
	_select_active_command_units()


func _select_active_command_units() -> void:
	if CommandTree.active_node == null:
		return
	var units: Array = CommandTree.active_node.collect_units()
	# Filter to valid player units only.
	var valid: Array = []
	for u in units:
		if is_instance_valid(u) and u is Unit and u.faction and u.faction.is_player:
			valid.append(u)
	SelectionManager.clear(true)
	for u in valid:
		SelectionManager.add(u)


func _apply_fog_of_war() -> void:
	if not world or not Intelligence or not Intelligence.world:
		return
	# Hide enemy units the player cannot see (fog of war). Friendly units and
	# buildings are always visible.
	for u in world.get_units():
		if u.faction == null:
			continue
		if u.faction.name == _player_faction.name:
			continue  # own units always visible
		var seen: bool = Intelligence.is_visible(_player_faction, u)
		# Keep the unit active (it still moves/fights) but hide its visuals.
		if u.body_mesh:
			u.body_mesh.visible = seen
		if u.selection_ring:
			u.selection_ring.visible = seen and u.selected
		if u.health_bar:
			u.health_bar.visible = seen and (u.selected or u.health < u.max_health)
