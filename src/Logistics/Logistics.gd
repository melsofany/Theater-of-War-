extends Node
## Logistics (autoload)
##
## Per-unit supply state: ammunition, fuel and readiness. Units within the supply
## radius of a friendly building are resupplied over time; cut-off units slowly
## attrition (no auto-refill) and their combat effectiveness degrades via
## `Unit.compute_readiness`. This is the Phase 6 "supply chain" — a building is
## a supply source, distance is the transportation network, fuel/ammunition are
## consumed by movement/firing, and readiness is the derived readiness rating.

## Range (metres) within which a friendly building resupplies units.
@export var supply_radius: float = 25.0
## Resupply rate per second (supply + fuel).
@export var resupply_rate: float = 5.0
## Slow attrition drain per second for cut-off units (represents consumption).
@export var attrition_drain: float = 0.2
## Base unit road speed (m/s) for travel-time estimates over the mega map.
@export var base_road_speed: float = 4.0

var world: World = null
# Contested city centres (Vector3) whose supply routes are cut. A supply truck's
# road segment passing within `contested_radius` of one of these is considered cut.
var _contested: Array = []
@export var contested_radius: float = 850.0  # ~half a 1500 m city


## Mark a city (its centre) as contested so road-bound supply through it is cut.
## Mega Map (Phase 10c+): when a modern city is split, supply trucks that need its
## roads can no longer traverse it safely.
func register_contested_city(centre: Vector3) -> void:
	if not _contested.has(centre):
		_contested.append(centre)


func clear_contested_city(centre: Vector3) -> void:
	_contested.erase(centre)


func is_city_contested(centre: Vector3) -> bool:
	for c in _contested:
		if c.distance_to(centre) < 1.0:
			return true
	return false


## True if a straight supply road segment from `a` to `b` is cut by a contested
## city (its centre within `contested_radius` of the segment).
func is_supply_route_cut(a: Vector3, b: Vector3) -> bool:
	for c in _contested:
		if _dist_point_to_segment(Vector2(c.x, c.z), Vector2(a.x, a.z), Vector2(b.x, b.z)) <= contested_radius:
			return true
	return false


## Travel time (seconds) for a supply truck to move from `a` to `b` along the road
## at base road speed, with terrain cost from `move_cost_fn` (callable pos->float).
## Returns INF if the route is cut by a contested city or hits impassable terrain.
func supply_travel_time(a: Vector3, b: Vector3, move_cost_fn: Callable) -> float:
	if is_supply_route_cut(a, b):
		return INF
	var dist: float = a.distance_to(b)
	if dist < 0.5:
		return 0.0
	var steps: int = maxf(1, int(dist / 8.0))
	var acc: float = 0.0
	var dir: Vector3 = (b - a) / dist
	for i in steps:
		var p: Vector3 = a + dir * (float(i) + 0.5) * 8.0
		var cost: float = move_cost_fn.call(p)
		if is_inf(cost):
			return INF
		acc += 8.0 * cost
	return acc / base_road_speed


func _dist_point_to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var l2 := ab.length_squared()
	if l2 < 0.0001:
		return p.distance_to(a)
	var t := clampf((p - a).dot(ab) / l2, 0.0, 1.0)
	return p.distance_to(a + ab * t)


func _process(delta: float) -> void:
	if not world:
		return
	var buildings: Array = world.get_buildings()
	for u in world.get_units():
		if not u.alive:
			continue
		var in_supply := false
		for b in buildings:
			if b.faction != null and u.faction != null and b.faction.name == u.faction.name:
				if u.global_position.distance_to(b.global_position) <= supply_radius:
					in_supply = true
					break
		if in_supply:
			u.supply = minf(u.supply + resupply_rate * delta, u.max_supply)
			u.fuel = minf(u.fuel + resupply_rate * delta, u.max_fuel)
		else:
			u.supply = maxf(u.supply - attrition_drain * delta, 0.0)
		u.compute_readiness()


## True if the unit is within supply range of a friendly building.
func is_in_supply(u: Unit) -> bool:
	if not world:
		return false
	for b in world.get_buildings():
		if b.faction != null and u.faction != null and b.faction.name == u.faction.name:
			if u.global_position.distance_to(b.global_position) <= supply_radius:
				return true
	return false


func clear() -> void:
	_contested.clear()
	world = null
