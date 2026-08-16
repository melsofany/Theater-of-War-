extends Node
## Campaign (autoload) — Phase 10
##
## Strategic objectives and win/lose conditions. A campaign is a list of
## objectives; when all objectives for a faction are complete, that faction wins.
## Objective types (foundation):
##   - CAPTURE_CITIES: own a given set of cities (owner_faction matches).
##   - ELIMINATE_ENEMY: reduce the enemy faction's alive units below a threshold.
##   - HOLD_POSITION: keep at least N friendly units within a radius of a point
##     for a cumulative duration.
##
## The campaign is checked each tick against the live world state. This gives the
## game a clear goal and drives the AI's strategic posture indirectly (the AI can
## be wired to pursue objectives in later tuning).

enum ObjectiveType { CAPTURE_CITIES, ELIMINATE_ENEMY, HOLD_POSITION }

var world: World = null
# faction_id -> Array[Dictionary] objective specs.
var _objectives: Dictionary = {}
# faction_id -> bool won.
var _won: Dictionary = {}


func clear() -> void:
	_objectives.clear()
	_won.clear()
	world = null


func add_objective(faction: Faction, spec: Dictionary) -> void:
	if faction == null:
		return
	if not _objectives.has(faction.name):
		_objectives[faction.name] = []
	_objectives[faction.name].append(spec.duplicate(true))


func objectives_for(faction: Faction) -> Array:
	if faction == null:
		return []
	return _objectives.get(faction.name, [])


func is_won(faction: Faction) -> bool:
	if faction == null:
		return false
	return _won.get(faction.name, false)


func _process(delta: float) -> void:
	tick(delta)


func tick(delta: float) -> void:
	if not world:
		return
	for fid in _objectives.keys():
		if _won.get(fid, false):
			continue
		var all_done: bool = true
		for spec in _objectives[fid]:
			if not _objective_done(fid, spec, delta):
				all_done = false
		if all_done and not _objectives[fid].is_empty():
			_won[fid] = true


func _objective_done(fid: String, spec: Dictionary, delta: float) -> bool:
	match spec.get("type"):
		ObjectiveType.CAPTURE_CITIES:
			return _cities_captured(fid, spec.get("cities", []))
		ObjectiveType.ELIMINATE_ENEMY:
			return _enemy_eliminated(fid, spec.get("threshold", 0))
		ObjectiveType.HOLD_POSITION:
			return _hold_done(fid, spec, delta)
	return false


func _cities_captured(fid: String, cities: Array) -> bool:
	if cities.is_empty():
		return false
	for c in cities:
		if c is City and (c.owner_faction == null or c.owner_faction.name != fid):
			return false
	return true


func _enemy_eliminated(fid: String, threshold: int) -> bool:
	var count: int = 0
	for u in world.get_units():
		if u.faction != null and u.faction.name != fid and u.alive:
			count += 1
	return count <= threshold


func _hold_done(fid: String, spec: Dictionary, delta: float) -> bool:
	var pos: Vector3 = spec.get("pos", Vector3.ZERO)
	var radius: float = spec.get("radius", 10.0)
	var required: int = spec.get("count", 1)
	var hold_time: float = spec.get("hold_seconds", 5.0)
	var present: int = 0
	for u in world.get_units():
		if u.faction != null and u.faction.name == fid and u.alive:
			if u.global_position.distance_to(pos) <= radius:
				present += 1
	var key: String = "progress"
	if present >= required:
		spec[key] = spec.get(key, 0.0) + delta
	else:
		spec[key] = maxf(spec.get(key, 0.0) - delta, 0.0)
	return spec.get(key, 0.0) >= hold_time


## Convenience: a default capture-the-capital campaign for a faction.
func setup_default(faction: Faction, enemy: Faction, cities: Array) -> void:
	clear()
	add_objective(faction, {"type": ObjectiveType.CAPTURE_CITIES, "cities": cities})
	add_objective(faction, {"type": ObjectiveType.ELIMINATE_ENEMY, "threshold": 0})
	if enemy != null:
		add_objective(enemy, {"type": ObjectiveType.ELIMINATE_ENEMY, "threshold": 0})
