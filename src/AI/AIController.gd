extends Node
## AIController (autoload)
##
## Drives the non-player faction(s) through the three AI layers each tick:
##   - Strategic: AIStrategy.decide(snapshot) -> posture + objective.
##   - Operational: move formations toward the strategic objective (or retreat).
##   - Tactical: units already auto-engage visible enemies (sight-gated, Phase 3/7);
##     badly damaged units are ordered to retreat from the nearest known enemy.
##
## The snapshot is built from fog-of-war intelligence (Intelligence), economy and
## logistics state — the AI never reads information it could not have. Decisions
## are issued as move orders on Unit, symmetric with player orders.

@export var think_interval: float = 2.0

var world: World = null
var strategy: AIStrategy = AIStrategy.new()
# faction_id -> sim clock for throttled thinking.
var _clocks: Dictionary = {}
# faction_id -> last decision (for introspection / HUD).
var _decisions: Dictionary = {}


func _process(delta: float) -> void:
	if not world:
		return
	if not world.has_method("get_factions"):
		return
	for f in world.get_factions():
		if f == null or f.is_player:
			continue
		_run(f, delta)


func _run(faction: Faction, delta: float) -> void:
	var fid: String = faction.name
	var clock: float = _clocks.get(fid, 0.0) + delta
	_clocks[fid] = clock
	# Always run tactical (cheap, per-unit); throttle strategic/operational.
	_tactical(faction)
	if clock < think_interval:
		return
	_clocks[fid] = 0.0
	var snapshot := _build_snapshot(faction)
	var decision: Dictionary = strategy.decide(snapshot)
	_decisions[fid] = decision
	_operational(faction, decision)


func _build_snapshot(faction: Faction) -> Dictionary:
	var own_force: float = 0.0
	var own_buildings: Array = []
	var rally: Vector3 = Vector3.ZERO
	var readiness_sum: float = 0.0
	var readiness_n: int = 0
	for u in world.get_units():
		if u.faction == null or u.faction.name != faction.name:
			continue
		if not u.alive:
			continue
		own_force += u.health
		readiness_sum += u.readiness
		readiness_n += 1
		rally += u.global_position
	for b in world.get_buildings():
		if b.faction != null and b.faction.name == faction.name:
			own_buildings.append(b.global_position)
			rally += b.global_position

	# Enemy force estimate comes from intelligence (fog-of-war bounded).
	var est: Dictionary = Intelligence.enemy_estimate(faction) if Intelligence and Intelligence.world else {}
	var enemy_force: float = _estimate_strength(est)

	# Known enemy positions: visible + last-known.
	var enemy_positions: Array = []
	if Intelligence and Intelligence.world:
		for e in Intelligence.visible_enemies_of(faction):
			enemy_positions.append(e.global_position)
		# Include last-known positions of remembered contacts.
		for u in world.get_units():
			if u.faction != null and u.faction.name != faction.name and u.alive:
				var lkp = Intelligence.last_known_position(faction, u)
				if lkp is Vector3:
					enemy_positions.append(lkp)

	var avg_readiness: float = readiness_sum / maxf(readiness_n, 1.0)
	var home: Vector3 = rally / maxf(float(own_buildings.size() + readiness_n), 1.0)

	return {
		"own_force": own_force,
		"enemy_force": enemy_force,
		"avg_readiness": avg_readiness,
		"own_buildings": own_buildings,
		"enemy_known_positions": enemy_positions,
		"home_pos": home,
		"rally_pos": home,
	}


## Map an intelligence estimate (category -> count) to a rough strength number.
func _estimate_strength(est: Dictionary) -> float:
	var total: float = 0.0
	for cat in est:
		var count: int = est[cat]
		total += count * _category_weight(cat)
	return total


func _category_weight(cat: int) -> float:
	# Rough relative combat value per category.
	var UnitType = load("res://src/Units/UnitType.gd")
	match cat:
		UnitType.Category.INFANTRY: return 1.0
		UnitType.Category.VEHICLE: return 2.0
		UnitType.Category.TANK: return 4.0
		UnitType.Category.ARTILLERY: return 3.0
		UnitType.Category.AIR_DEFENSE: return 2.0
		UnitType.Category.AIRCRAFT: return 5.0
		UnitType.Category.HELICOPTER: return 4.0
		_: return 1.0


## Operational: move the faction's units toward the strategic objective.
func _operational(faction: Faction, decision: Dictionary) -> void:
	var objective: Vector3 = decision.get("objective", Vector3.ZERO)
	var posture: int = decision.get("posture", AIStrategy.Posture.REGROUP)
	for u in world.get_units():
		if u.faction == null or u.faction.name != faction.name:
			continue
		if not u.alive:
			continue
		# Don't override units already in contact (let tactical/combat handle them).
		if u.target != null and is_instance_valid(u.target):
			continue
		var dest: Vector3 = objective
		if posture == AIStrategy.Posture.OFFENSIVE:
			# Move toward the objective; small per-unit offset for formation.
			dest = objective + Vector3(randf_range(-2.0, 2.0), 0.0, randf_range(-2.0, 2.0))
		u.move_to(dest)


## Tactical: retreat badly damaged units away from the nearest known enemy.
func _tactical(faction: Faction) -> void:
	var retreat_frac: float = strategy.retreat_health_fraction
	for u in world.get_units():
		if u.faction == null or u.faction.name != faction.name:
			continue
		if not u.alive:
			continue
		if u.health > u.max_health * retreat_frac:
			continue
		# Find nearest visible enemy and flee from it.
		var nearest: Vector3 = u.global_position
		var best_d: float = INF
		if Intelligence and Intelligence.world:
			for e in Intelligence.visible_enemies_of(faction):
				var d: float = u.global_position.distance_to(e.global_position)
				if d < best_d:
					best_d = d
					nearest = e.global_position
		if best_d < INF:
			var away: Vector3 = u.global_position + (u.global_position - nearest).normalized() * 10.0
			u.move_to(away)


func decision_for(faction: Faction) -> Dictionary:
	if faction == null:
		return {}
	return _decisions.get(faction.name, {})


func clear() -> void:
	_clocks.clear()
	_decisions.clear()
	world = null
