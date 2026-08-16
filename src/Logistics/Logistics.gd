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

var world: World = null


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
	world = null
