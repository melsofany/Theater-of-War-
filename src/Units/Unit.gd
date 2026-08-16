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


func _ready() -> void:
	if unit_type == null and UnitFactory:
		unit_type = UnitFactory.get_type("infantry")
	_apply_type()
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
	_update_health_bar()


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
	_cooldown = maxf(_cooldown - delta, 0.0)
	# Air units hover at cruise altitude and don't use the navmesh/terrain.
	if unit_type and unit_type.is_air():
		_air_step(delta)
		_combat_step(delta)
		return
	if unit_type and unit_type.is_naval():
		_naval_step(delta)
		_combat_step(delta)
		return
	if agent and agent.is_navigation_finished():
		moving = false
		_on_arrived()
	_combat_step(delta)
	if not agent:
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
	for u in world.get_enemy_units_of(faction):
		if not u.alive:
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
	var dmg: float = unit_type.damage * compute_readiness()
	other.take_damage(dmg)


func take_damage(amount: float) -> void:
	if not alive:
		return
	var dmg := maxf(1.0, amount - armor)
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
