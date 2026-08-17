extends CharacterBody3D
## Unit
##
## Base class for every controllable entity on the battlefield. Handles
## selection highlighting, terrain-aware movement, health/damage and a simple
## auto-acquire combat loop. Stats come from a `UnitType` resource so adding a
## new unit kind is a data change. Command hierarchy (Phase 4) and real AI
## (Phase 8) build on this.

class_name Unit

signal died(unit: Unit)
signal health_changed(unit: Unit, hp: float)

@export var faction: Faction = null
## Stats + behaviour flags. If null at runtime a default infantry type is used.
@export var unit_type: UnitType = null
## When non-empty and the unit is AI-controlled (not a player unit), it cycles
## through these waypoints as a simple patrol. Phase 8 replaces this with real AI.
@export var patrol_points: Array[Vector3] = []
## Optional world reference for terrain height/move-cost sampling. If null the
## unit moves on a flat y=0 plane (Phase 0/1 behaviour).
var world: World = null

var selected: bool = false
var target_position: Vector3 = Vector3.ZERO
var moving: bool = false
var _patrol_index: int = 0
var _patrol_wait: float = 0.0

# --- Combat state -----------------------------------------------------------
var health: float = 100.0
var max_health: float = 100.0
var armor: float = 0.0
var max_speed: float = 8.0
var turn_speed: float = 6.0
var radius: float = 0.5
var alive: bool = true
var target: Unit = null
var _cooldown: float = 0.0
# --- Logistics state (Phase 6) ----------------------------------------------
var supply: float = 20.0
var max_supply: float = 20.0
var fuel: float = 100.0
var max_fuel: float = 100.0
var fuel_per_move: float = 0.05
var ammo_per_shot: float = 1.0
## 0..1 effectiveness multiplier from supply/fuel/health; affects damage + speed.
var readiness: float = 1.0
## Sight range for reconnaissance / fog of war (metres).
var sight_range: float = 25.0

@onready var body_mesh: MeshInstance3D = $Body
@onready var selection_ring: MeshInstance3D = $SelectionRing
@onready var agent: NavigationAgent3D = $NavigationAgent
@onready var health_bar: MeshInstance3D = $HealthBar
@onready var visual_model: Node3D = $VisualModel


func _ready() -> void:
	if unit_type == null and UnitFactory:
		unit_type = UnitFactory.get_type("infantry")
	_update_visuals()
	_rebuild_visual_model()
	target_position = global_position
	_update_visuals()
	if agent:
		agent.radius = radius
	if not patrol_points.is_empty():
		_advance_patrol()


func _apply_type() -> void:
	if unit_type == null:
		return
	max_health = unit_type.max_health
	health = max_health
	armor = unit_type.armor
	max_speed = unit_type.max_speed
	turn_speed = unit_type.turn_speed
	radius = unit_type.radius
	max_supply = unit_type.max_supply
	supply = max_supply
	max_fuel = unit_type.max_fuel
	fuel = max_fuel
	fuel_per_move = unit_type.fuel_per_move
	ammo_per_shot = unit_type.ammo_per_shot
	sight_range = unit_type.sight_range
	if agent:
		agent.radius = radius
	_update_visuals()
	_rebuild_visual_model()


## Effectiveness from supply, fuel and health. Air units are grounded (0 move)
## without fuel; ground units move at reduced speed when low on fuel.
func compute_readiness() -> float:
	var s_norm: float = supply / maxf(max_supply, 1.0)
	var f_norm: float = fuel / maxf(max_fuel, 1.0)
	var h_norm: float = health / maxf(max_health, 1.0)
	var r: float = 0.2 + 0.4 * s_norm + 0.4 * f_norm
	r *= clampf(h_norm, 0.0, 1.0)
	readiness = clampf(r, 0.0, 1.0)
	return readiness


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
	if visual_model and faction:
		for node in visual_model.get_children():
			if node is MeshInstance3D:
				var visual_mat := (node as MeshInstance3D).get_surface_override_material(0) as StandardMaterial3D
				if visual_mat:
					visual_mat.albedo_color = faction.color.lerp(Color(0.06, 0.08, 0.1), 0.28)
	_update_health_bar()


func _rebuild_visual_model() -> void:
	if visual_model == null or unit_type == null:
		return
	for node in visual_model.get_children():
		node.queue_free()
	# RTS readability: keep units visibly larger than the terrain grid.
	visual_model.scale = Vector3.ONE * 1.65
	# Prefer the supplied top-down Meta AI art when available. The procedural
	# meshes below remain as a safe fallback for unsupported unit categories.
	if _add_meta_asset_sprite():
		body_mesh.visible = false
		_update_visuals()
		return
	body_mesh.visible = unit_type.category == UnitType.Category.INFANTRY or unit_type.category == UnitType.Category.SNIPER
	body_mesh.scale = Vector3.ONE
	body_mesh.position = Vector3(0, 0.6, 0)
	match unit_type.category:
		UnitType.Category.INFANTRY:
			_add_visual(_box(Vector3(0.48, 0.62, 0.34)), Vector3(0, 0.70, 0), Vector3.ZERO, "ArmoredVest")
			_add_visual(_box(Vector3(0.16, 0.54, 0.18)), Vector3(-0.13, 0.28, 0), Vector3.ZERO, "LeftLeg")
			_add_visual(_box(Vector3(0.16, 0.54, 0.18)), Vector3(0.13, 0.28, 0), Vector3.ZERO, "RightLeg")
			_add_visual(_sphere(0.25), Vector3(0, 1.18, 0), Vector3.ZERO, "Head")
			_add_visual(_cylinder(0.28, 0.10), Vector3(0, 1.38, 0), Vector3.ZERO, "Helmet")
			_add_visual(_box(Vector3(0.28, 0.48, 0.18)), Vector3(0, 0.72, -0.22), Vector3.ZERO, "Pack")
			_add_visual(_box(Vector3(0.10, 0.10, 0.78)), Vector3(0.12, 0.86, 0.30), Vector3.ZERO, "Rifle")
		UnitType.Category.SNIPER:
			body_mesh.scale = Vector3(0.9, 0.55, 1.2)
			body_mesh.position = Vector3(0, 0.34, 0)
			_add_visual(_box(Vector3(0.58, 0.22, 1.05)), Vector3(0, 0.30, 0), Vector3.ZERO, "GhillieBody")
			_add_visual(_sphere(0.22), Vector3(0, 0.58, -0.30), Vector3.ZERO, "SniperHead")
			_add_visual(_box(Vector3(0.15, 0.13, 1.35)), Vector3(0, 0.47, 0.48), Vector3.ZERO, "ScopedRifle")
			_add_visual(_cylinder(0.06, 0.24), Vector3(0, 0.55, 0.25), Vector3(PI / 2.0, 0, 0), "Scope")
			_add_visual(_box(Vector3(0.05, 0.20, 0.30)), Vector3(-0.10, 0.20, 0.48), Vector3(0, 0, 0.22), "BipodLeft")
			_add_visual(_box(Vector3(0.05, 0.20, 0.30)), Vector3(0.10, 0.20, 0.48), Vector3(0, 0, -0.22), "BipodRight")
		UnitType.Category.VEHICLE:
			_add_visual(_box(Vector3(1.45, 0.46, 1.9)), Vector3(0, 0.45, 0), Vector3.ZERO, "VehicleHull")
			_add_visual(_box(Vector3(0.90, 0.38, 0.62)), Vector3(0, 0.82, -0.18), Vector3.ZERO, "Cabin")
			_add_visual(_box(Vector3(0.72, 0.20, 0.05)), Vector3(0, 0.84, 0.14), Vector3.ZERO, "Windshield")
			_add_wheels()
		UnitType.Category.TANK:
			_add_visual(_box(Vector3(1.8, 0.52, 2.2)), Vector3(0, 0.44, 0), Vector3.ZERO, "TankHull")
			_add_visual(_box(Vector3(2.0, 0.22, 2.0)), Vector3(0, 0.68, 0), Vector3.ZERO, "TrackDeck")
			_add_visual(_cylinder(0.52, 0.28), Vector3(0, 0.91, -0.10), Vector3.ZERO, "Turret")
			_add_visual(_box(Vector3(0.18, 0.18, 1.45)), Vector3(0, 0.94, 0.72), Vector3.ZERO, "TankBarrel")
			_add_visual(_cylinder(0.035, 0.80), Vector3(0.33, 1.18, -0.34), Vector3.ZERO, "Antenna")
			_add_wheels()
		UnitType.Category.ARTILLERY:
			_add_visual(_box(Vector3(1.25, 0.38, 1.65)), Vector3(0, 0.4, 0), Vector3.ONE, "ArtilleryHull")
			_add_visual(_box(Vector3(0.16, 0.16, 1.25)), Vector3(0, 0.78, 0.55), Vector3(PI / 10.0, 0, 0), "Howitzer")
		UnitType.Category.AIR_DEFENSE:
			_add_visual(_box(Vector3(1.2, 0.4, 1.4)), Vector3(0, 0.4, 0), Vector3.ONE, "AAHull")
			_add_visual(_cylinder(0.09, 1.0), Vector3(-0.22, 0.76, 0), Vector3(0, 0, PI / 2.0), "AAGunLeft")
			_add_visual(_cylinder(0.09, 1.0), Vector3(0.22, 0.76, 0), Vector3(0, 0, PI / 2.0), "AAGunRight")
		UnitType.Category.AIRCRAFT:
			_add_visual(_box(Vector3(0.28, 0.22, 1.9)), Vector3(0, 0.55, 0), Vector3.ONE, "AircraftBody")
			_add_visual(_box(Vector3(1.5, 0.08, 0.42)), Vector3(0, 0.55, 0.1), Vector3.ONE, "AircraftWings")
		UnitType.Category.HELICOPTER:
			_add_visual(_box(Vector3(0.55, 0.45, 1.15)), Vector3(0, 0.7, 0), Vector3.ONE, "HelicopterBody")
			_add_visual(_box(Vector3(2.0, 0.04, 0.08)), Vector3(0, 1.15, 0), Vector3.ONE, "Rotor")
	_update_visuals()


func _meta_asset_path() -> String:
	if unit_type == null:
		return ""
	match unit_type.key:
		"humvee": return "res://assets/meta_units/humvee_vehicle.png"
		"apc": return "res://assets/meta_units/vehicle_apc_topdown.png"
		"cannon_fixed": return "res://assets/meta_units/cannon_fixed.png"
		"cannon_mobile": return "res://assets/meta_units/cannon_mobile.png"
		"howitzer_m777": return "res://assets/meta_units/howitzer_m777.png"
		"mortar_team": return "res://assets/meta_units/mortar_team.png"
		"missile_launcher_fixed": return "res://assets/meta_units/missile_launcher_fixed.png"
		"missile_launcher_mobile": return "res://assets/meta_units/missile_launcher_mobile.png"
		"mlrs_rocket_launcher": return "res://assets/meta_units/mlrs_rocket_launcher.png"
		"bomber": return "res://assets/meta_units/bomber_aircraft.png"
		"transport_aircraft": return "res://assets/meta_units/transport_aircraft.png"
		"fighter": return "res://assets/meta_units/fighter_aircraft.png"
	match unit_type.category:
		UnitType.Category.INFANTRY:
			return "res://assets/meta_units/infantry_topdown.png"
		UnitType.Category.SNIPER:
			return "res://assets/sprites/units/sniper.png"
		UnitType.Category.VEHICLE:
			return "res://assets/meta_units/vehicle_apc_topdown.png"
		UnitType.Category.TANK:
			return "res://assets/meta_units/tank_final.png"
		UnitType.Category.ARTILLERY:
			return "res://assets/meta_units/artillery_topdown.png"
		UnitType.Category.AIR_DEFENSE:
			return "res://assets/meta_units/airdefense_topdown.png"
		UnitType.Category.AIRCRAFT:
			return "res://assets/meta_units/aircraft_fighter_topdown.png"
		UnitType.Category.HELICOPTER:
			return "res://assets/meta_units/helicopter_topdown.png"
	return ""


func _add_meta_asset_sprite() -> bool:
	var asset_path := _meta_asset_path()
	if asset_path.is_empty():
		return false
	var image := Image.load_from_file(ProjectSettings.globalize_path(asset_path))
	if image == null or image.is_empty():
		return false
	var texture := ImageTexture.create_from_image(image)
	if texture == null:
		return false
	var sprite := Sprite3D.new()
	sprite.name = "MetaAssetSprite"
	sprite.texture = texture
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.shaded = true
	sprite.no_depth_test = false
	sprite.pixel_size = 0.00105
	sprite.position = Vector3(0, 1.15, 0)
	if unit_type.category == UnitType.Category.SNIPER:
		sprite.pixel_size = 0.0032
		sprite.position.y = 0.72
	visual_model.add_child(sprite)
	return true


func _box(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh


func _sphere(radius_value: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius_value
	mesh.height = radius_value * 2.0
	return mesh


func _cylinder(radius_value: float, height_value: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius_value
	mesh.bottom_radius = radius_value
	mesh.height = height_value
	return mesh


func _add_visual(mesh: Mesh, position: Vector3, rotation: Vector3, node_name: String) -> void:
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.position = position
	node.rotation = rotation
	var mat := StandardMaterial3D.new()
	var base_color := faction.color if faction else Color(0.2, 0.4, 0.9)
	var dark_part := node_name.contains("Rifle") or node_name.contains("Scope") or node_name.contains("Bipod") or node_name.contains("Wheel") or node_name.contains("Track") or node_name.contains("Windshield") or node_name.contains("Barrel") or node_name.contains("Antenna")
	if dark_part:
		base_color = Color(0.025, 0.035, 0.045)
	elif node_name.contains("Helmet") or node_name.contains("Pack") or node_name.contains("Ghillie"):
		base_color = base_color.lerp(Color(0.08, 0.12, 0.07), 0.48)
	mat.albedo_color = base_color
	mat.roughness = 0.72
	mat.metallic = 0.08 if dark_part else 0.0
	node.material_override = mat
	visual_model.add_child(node)


func _add_wheels() -> void:
	for side in [-1.0, 1.0]:
		for z in [-0.58, 0.58]:
			_add_visual(_cylinder(0.18, 0.14), Vector3(side * 0.7, 0.28, z), Vector3(0, 0, PI / 2.0), "Wheel")


func _update_health_bar() -> void:
	if not health_bar:
		return
	var pct := clampf(health / maxf(max_health, 1.0), 0.0, 1.0)
	health_bar.scale.x = maxf(pct, 0.001)
	var mat := health_bar.get_surface_override_material(0) as StandardMaterial3D
	if mat:
		mat.albedo_color = Color(1, 0.2, 0.2).lerp(Color(0.2, 0.9, 0.2), pct)
	health_bar.visible = selected or health < max_health


func move_to(pos: Vector3) -> void:
	target_position = pos
	moving = true
	if agent:
		agent.set_target_position(pos)


func _physics_process(delta: float) -> void:
	if not alive:
		return
	var old_pos := global_position
	_cooldown = maxf(_cooldown - delta, 0.0)
	# Air units hover at cruise altitude and don't use the navmesh/terrain.
	if unit_type and unit_type.is_air():
		_air_step(delta)
		_combat_step(delta)
		_sync_spatial(old_pos)
		return
	if unit_type and unit_type.is_naval():
		_naval_step(delta)
		_combat_step(delta)
		_sync_spatial(old_pos)
		return
	if agent and agent.is_navigation_finished():
		moving = false
		_on_arrived()
	_combat_step(delta)
	if not agent:
		_sync_spatial(old_pos)
		return
	var next := agent.get_next_path_position()
	var dir := (next - global_position)
	dir.y = 0
	var dist := dir.length()
	if dist < 0.05:
		return
	dir = dir.normalized()
	# Stop to shoot if we have a target in range.
	if target and is_instance_valid(target) and _in_range(target):
		return
	# No fuel -> cannot move (grounded). Air units handled in _air_step.
	if fuel <= 0.0:
		moving = false
		return
	var speed := max_speed * compute_readiness()
	if world:
		var cost := world.move_cost_at(global_position.x, global_position.z)
		if is_inf(cost):
			return
		speed = speed / maxf(cost, 0.0001)
	var step: float = minf(speed * delta, dist)
	global_position += dir * step
	# Burn fuel proportional to distance moved.
	fuel = maxf(fuel - fuel_per_move * step, 0.0)
	global_position.y = world.ground_height_at(global_position.x, global_position.z) if world else 0.0
	if dir.length_squared() > 0.001:
		var look := global_position + dir
		look.y = global_position.y
		var target_basis := Transform3D().looking_at(look - global_position, Vector3.UP).basis
		basis = basis.slerp(target_basis, clamp(turn_speed * delta, 0.0, 1.0))
	_sync_spatial(old_pos)


func _sync_spatial(old_pos: Vector3) -> void:
	if world:
		world.update_unit_spatial(self, old_pos)


func _air_step(delta: float) -> void:
	# Fly straight toward the target position at cruise altitude.
	var to: Vector3 = target_position - global_position
	to.y = 0
	var dist: float = to.length()
	if dist > 0.1 and fuel > 0.0:
		var dir: Vector3 = to.normalized()
		var step: float = minf(max_speed * compute_readiness() * delta, dist)
		global_position += dir * step
		fuel = maxf(fuel - fuel_per_move * step, 0.0)
	global_position.y = unit_type.cruise_altitude
	if to.length_squared() > 0.001:
		var look := global_position + to.normalized()
		look.y = global_position.y
		var target_basis := Transform3D().looking_at(look - global_position, Vector3.UP).basis
		basis = basis.slerp(target_basis, clamp(turn_speed * delta, 0.0, 1.0))
	moving = dist > 0.5


# Naval units move on water only (land is impassable for them). Simple steering
# toward the target position, constrained to water tiles.
func _naval_step(delta: float) -> void:
	var to: Vector3 = target_position - global_position
	to.y = 0
	var dist: float = to.length()
	if dist > 0.1 and fuel > 0.0:
		var dir: Vector3 = to.normalized()
		var speed: float = max_speed * compute_readiness()
		var step: float = minf(speed * delta, dist)
		var candidate: Vector3 = global_position + dir * step
		# Only advance into water; stop at the shoreline.
		if world and not world.is_water_at(candidate.x, candidate.z):
			moving = false
		else:
			global_position = candidate
			fuel = maxf(fuel - fuel_per_move * step, 0.0)
	# Naval units sit at water level (y = 0).
	global_position.y = 0.0
	if to.length_squared() > 0.001:
		var look := global_position + to.normalized()
		look.y = global_position.y
		var target_basis := Transform3D().looking_at(look - global_position, Vector3.UP).basis
		basis = basis.slerp(target_basis, clamp(turn_speed * delta, 0.0, 1.0))
	moving = moving and dist > 0.5


# --- Combat -----------------------------------------------------------------

func _combat_step(delta: float) -> void:
	if not unit_type:
		return
	# Drop a dead/invalid target.
	if target and not is_instance_valid(target):
		target = null
	if target and not target.alive:
		target = null
	# Acquire a target if we have none.
	if target == null:
		_acquire_target()
	if target and _in_range(target):
		moving = false
		if _cooldown <= 0.0:
			_fire(target)
			_cooldown = unit_type.attack_cooldown


func _acquire_target() -> void:
	if world == null or unit_type == null:
		return
	var best: Unit = null
	var best_d := unit_type.sight_range
	var candidates: Array = world.query_units_radius(global_position, unit_type.sight_range)
	for u in candidates:
		if not u is Unit or u.faction == null or faction == null:
			continue
		if not faction.is_enemy_of(u.faction) or not u.alive:
			continue
		if not unit_type.can_attack(u.unit_type):
			continue
		var d := global_position.distance_to(u.global_position)
		if d < best_d:
			best_d = d
			best = u
	target = best


func _in_range(other: Unit) -> bool:
	if other == null:
		return false
	return global_position.distance_to(other.global_position) <= unit_type.range


func _fire(other: Unit) -> void:
	if supply < ammo_per_shot:
		# Out of ammo: cannot fire this tick.
		return
	supply = maxf(supply - ammo_per_shot, 0.0)
	_play_fire_sfx()
	var raw: float = unit_type.damage * compute_readiness()
	var dmg: float = Balance.scaled_damage(raw) if Balance else raw
	other.take_damage(dmg)


func _play_fire_sfx() -> void:
	var am := get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_sfx"):
		am.play_sfx(_fire_sfx_name())


func _fire_sfx_name() -> String:
	match unit_type.category:
		UnitType.Category.INFANTRY:
			return "infantry_fire"
		UnitType.Category.TANK:
			return "tank_fire"
		UnitType.Category.ARTILLERY:
			return "artillery_fire"
		UnitType.Category.AIR_DEFENSE:
			return "aa_fire"
		UnitType.Category.AIRCRAFT, UnitType.Category.HELICOPTER:
			return "aircraft_fire"
	return "infantry_fire"


func take_damage(amount: float) -> void:
	if not alive:
		return
	var eff_armor: float = armor * (Balance.armor_multiplier if Balance else 1.0)
	var dmg := maxf(1.0, amount - eff_armor)
	health -= dmg
	health_changed.emit(self, health)
	_update_health_bar()
	if health <= 0.0:
		die()


func die() -> void:
	if not alive:
		return
	alive = false
	health = 0.0
	var am := get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_sfx"):
		am.play_sfx("explosion")
	died.emit(self)
	_update_health_bar()
	# Detach from selection and hide; the world/manager can free later.
	if selected:
		SelectionManager.remove(self)
	hide()
	set_physics_process(false)


func heal(amount: float) -> void:
	if not alive:
		return
	health = minf(health + amount, max_health)
	health_changed.emit(self, health)
	_update_health_bar()


func _on_arrived() -> void:
	if patrol_points.is_empty():
		return
	if _patrol_wait < 0.8:
		_patrol_wait += get_physics_process_delta_time()
		return
	_patrol_wait = 0.0
	_patrol_index = (_patrol_index + 1) % patrol_points.size()
	_advance_patrol()


func _advance_patrol() -> void:
	if patrol_points.is_empty():
		return
	move_to(patrol_points[_patrol_index])
