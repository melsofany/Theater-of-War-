extends Node
## Intelligence (autoload)
##
## Fog of war + reconnaissance. For each faction an enemy unit is in one of three
## states:
##   VISIBLE     — a friendly unit or building currently sees it (within sight).
##   REMEMBERED  — was seen recently; a last-known position is held until it
##                 decays past `remember_seconds`.
##   UNKNOWN     — never seen, or memory decayed.
##
## Provides `is_visible`, `visible_enemies_of`, `last_known_position`,
## `enemy_estimate` (rough strength count by category from sightings) and
## `report` (a human-readable intelligence summary).

## How long a last-known contact is remembered after it leaves sight.
@export var remember_seconds: float = 15.0
## Vision radius provided by a friendly building (fixed recon post).
@export var building_vision_radius: float = 30.0

var world: World = null
# Monotonic simulation clock (seconds), advanced by tick(delta). Using a sim
# clock (not wall time) makes memory decay deterministic and testable.
var _sim_time: float = 0.0

# faction_id -> { unit_instance_id -> {"pos": Vector3, "type": UnitType, "time": float} }
var _memory: Dictionary = {}
# faction_id -> Array[enemy Unit] currently visible (refreshed each tick).
var _visible: Dictionary = {}


func _process(delta: float) -> void:
	if not world:
		return
	tick(delta)


func tick(delta: float) -> void:
	if not world:
		return
	_sim_time += delta
	# Collect factions present.
	var factions: Dictionary = {}
	for u in world.get_units():
		if u.faction != null:
			factions[u.faction.name] = u.faction
	for fid in factions:
		_update_faction(fid, delta)


func _update_faction(faction_id: String, delta: float) -> void:
	var vis: Array = []
	for enemy in world.get_units():
		if enemy.faction == null:
			continue
		if enemy.faction.name == faction_id:
			continue
		if not enemy.alive:
			continue
		if is_visible_by_faction(faction_id, enemy):
			vis.append(enemy)
			_remember(faction_id, enemy)
	# Decay memory: remove entries older than remember_seconds, and drop dead.
	var mem: Dictionary = _memory.get(faction_id, {})
	for key in mem.keys():
		var entry: Dictionary = mem[key]
		var age: float = _sim_time - entry.get("time", 0.0)
		if age > remember_seconds:
			mem.erase(key)
	_visible[faction_id] = vis


## Is `enemy` currently visible to any friendly unit/building of `faction_id`?
func is_visible_by_faction(faction_id: String, enemy: Unit) -> bool:
	if not world or enemy == null or not enemy.alive:
		return false
	for u in world.get_units():
		if u.faction == null or u.faction.name != faction_id:
			continue
		if not u.alive:
			continue
		if u.global_position.distance_to(enemy.global_position) <= u.sight_range:
			return true
	for b in world.get_buildings():
		if b.faction == null or b.faction.name != faction_id:
			continue
		if b.global_position.distance_to(enemy.global_position) <= building_vision_radius:
			return true
	return false


## Convenience: is `enemy` visible to the faction of `observer`?
func is_visible(observer_faction: Faction, enemy: Unit) -> bool:
	if observer_faction == null:
		return false
	return is_visible_by_faction(observer_faction.name, enemy)


func visible_enemies_of(faction: Faction) -> Array:
	if faction == null:
		return []
	return _visible.get(faction.name, [])


func last_known_position(faction: Faction, enemy: Unit) -> Variant:
	if faction == null or enemy == null:
		return null
	var mem: Dictionary = _memory.get(faction.name, {})
	var entry: Dictionary = mem.get(enemy.get_instance_id(), {})
	if entry.is_empty():
		return null
	return entry.get("pos", null)


func _remember(faction_id: String, enemy: Unit) -> void:
	if not _memory.has(faction_id):
		_memory[faction_id] = {}
	_memory[faction_id][enemy.get_instance_id()] = {
		"pos": enemy.global_position,
		"type": enemy.unit_type,
		"time": _sim_time,
	}


## Rough enemy strength estimate from sightings: category -> count seen.
func enemy_estimate(faction: Faction) -> Dictionary:
	if faction == null:
		return {}
	var mem: Dictionary = _memory.get(faction.name, {})
	var counts: Dictionary = {}
	for key in mem:
		var entry: Dictionary = mem[key]
		var ut: UnitType = entry.get("type")
		if ut != null:
			counts[ut.category] = counts.get(ut.category, 0) + 1
	return counts


## Human-readable intelligence report.
func report(faction: Faction) -> String:
	if faction == null:
		return ""
	var vis: Array = visible_enemies_of(faction)
	var est: Dictionary = enemy_estimate(faction)
	var parts: Array = []
	for cat in est:
		parts.append("%s: %d" % [UnitType.Category.find_key(cat), est[cat]])
	return "Contacts: %d visible, %d remembered | %s" % [vis.size(), _memory.get(faction.name, {}).size(), ", ".join(parts) if not parts.is_empty() else "none"]


func clear() -> void:
	_memory.clear()
	_visible.clear()
	_sim_time = 0.0
	world = null
