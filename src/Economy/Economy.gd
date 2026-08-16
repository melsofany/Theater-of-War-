extends Node
## Economy (autoload)
##
## Per-faction resource stores with capacities and per-second income from owned
## infrastructure (cities + buildings). Buildings spend resources to produce
## units; production is blocked (and refunded-free) when a faction can't afford
## a unit's cost. Designed as pure, testable logic: `can_afford`, `spend`,
## `credit`, `tick`.

enum R {
	MANPOWER,
	FUEL,
	MATERIALS,
}

const R_NAME := {
	R.MANPOWER: "Manpower",
	R.FUEL: "Fuel",
	R.MATERIALS: "Materials",
}

# faction_id -> {R -> amount}
var _amounts: Dictionary = {}
# faction_id -> {R -> capacity}
var _capacities: Dictionary = {}
# faction_id -> {R -> income per second}
var _income: Dictionary = {}

var world: World = null


func register_faction(faction_id: String, starting: Dictionary = {}, caps: Dictionary = {}) -> void:
	if not _amounts.has(faction_id):
		_amounts[faction_id] = {R.MANPOWER: 0.0, R.FUEL: 0.0, R.MATERIALS: 0.0}
		_capacities[faction_id] = {R.MANPOWER: 500.0, R.FUEL: 500.0, R.MATERIALS: 500.0}
		_income[faction_id] = {R.MANPOWER: 0.0, R.FUEL: 0.0, R.MATERIALS: 0.0}
	for k in starting:
		(_amounts[faction_id] as Dictionary)[k] = starting[k]
	for k in caps:
		(_capacities[faction_id] as Dictionary)[k] = caps[k]


func amount(faction_id: String, r: int) -> float:
	if not _amounts.has(faction_id):
		return 0.0
	return (_amounts[faction_id] as Dictionary).get(r, 0.0)


func capacity(faction_id: String, r: int) -> float:
	if not _capacities.has(faction_id):
		return 0.0
	return (_capacities[faction_id] as Dictionary).get(r, 0.0)


func income(faction_id: String, r: int) -> float:
	if not _income.has(faction_id):
		return 0.0
	return (_income[faction_id] as Dictionary).get(r, 0.0)


func can_afford(faction_id: String, cost: Dictionary) -> bool:
	if not _amounts.has(faction_id):
		return false
	for k in cost:
		if amount(faction_id, k) < cost[k]:
			return false
	return true


func spend(faction_id: String, cost: Dictionary) -> bool:
	if not can_afford(faction_id, cost):
		return false
	for k in cost:
		(_amounts[faction_id] as Dictionary)[k] = amount(faction_id, k) - cost[k]
	return true


func credit(faction_id: String, r: int, amt: float) -> void:
	if not _amounts.has(faction_id):
		return
	var cap: float = capacity(faction_id, r)
	var cur: float = amount(faction_id, r)
	(_amounts[faction_id] as Dictionary)[r] = clampf(cur + amt, 0.0, cap)


## Recompute per-second income from owned infrastructure. Called on tick and on
## ownership changes.
func recompute_income(faction_id: String) -> void:
	if not _income.has(faction_id):
		return
	var inc: Dictionary = _income[faction_id]
	for r in [R.MANPOWER, R.FUEL, R.MATERIALS]:
		inc[r] = 0.0
	if world == null:
		return
	# Each owned city yields manpower + materials.
	for c in world.get_cities():
		if c.owner_faction != null and c.owner_faction.name == faction_id:
			inc[R.MANPOWER] += c.income_manpower
			inc[R.MATERIALS] += c.income_materials
	# Each owned building adds a little fuel income + storage capacity.
	for b in world.get_buildings():
		if b.faction != null and b.faction.name == faction_id:
			inc[R.FUEL] += 0.5
	_apply_capacity_from_infrastructure(faction_id)


func _apply_capacity_from_infrastructure(faction_id: String) -> void:
	var base: Dictionary = {R.MANPOWER: 500.0, R.FUEL: 500.0, R.MATERIALS: 500.0}
	if world:
		for b in world.get_buildings():
			if b.faction != null and b.faction.name == faction_id:
				base[R.MATERIALS] += 200.0
				base[R.FUEL] += 100.0
	var caps: Dictionary = _capacities[faction_id]
	for r in base:
		caps[r] = base[r]


func _process(delta: float) -> void:
	for faction_id in _income:
		var inc: Dictionary = _income[faction_id]
		for r in [R.MANPOWER, R.FUEL, R.MATERIALS]:
			credit(faction_id, r, inc.get(r, 0.0) * delta)


func clear() -> void:
	_amounts.clear()
	_capacities.clear()
	_income.clear()
	world = null
