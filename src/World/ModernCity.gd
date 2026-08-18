class_name ModernCity
extends Node3D
## ModernCity — Mega World Map (Phase 10c+)
##
## A modern glass city on the mega world map: 1500 x 1500 m, 4-6 districts, glass
## facades with reflections, wide streets and shop decals. Owned by ModernCity at
## runtime but kept as a scene-graph node so towers (MultiMesh), streets and
## civilian spawn markers can live in it.
##
## A city can be split between armies: each district holds its own control_faction,
## so the north half can be one army and the south half the enemy. The aggregate
## owner (for Economy income) is the faction holding the majority of districts.

const CITY_EXTENT: float = 1500.0

@export var city_name: String = "City"
var districts: Array[CityDistrict] = []
## Glass-tower multimesh shared across the city (performance: one draw call).
var _towers: MultiMeshInstance3D = null


func _ready() -> void:
	for c in get_children():
		if c is CityDistrict:
			districts.append(c)


func add_district(d: CityDistrict) -> void:
	add_child(d)
	districts.append(d)


func get_district(name: String) -> CityDistrict:
	for d in districts:
		if d.district_name == name:
			return d
	return null


## Faction holding the majority of districts (the city's aggregate owner). Null if
## no single faction holds a majority (the city is contested / split).
func majority_owner() -> Faction:
	var tally: Dictionary = {}
	for d in districts:
		if d.control_faction == null:
			continue
		tally[d.control_faction.name] = tally.get(d.control_faction.name, 0) + 1
	var best: Faction = null
	var best_n: int = 0
	for d in districts:
		if d.control_faction == null:
			continue
		var n: int = tally[d.control_faction.name]
		if n > best_n:
			best_n = n
			best = d.control_faction
	# Majority means strictly more than half the districts.
	if best_n > districts.size() / 2:
		return best
	return null


## True if two different factions hold districts of this city (it is "split").
func is_split() -> bool:
	var seen: Dictionary = {}
	for d in districts:
		if d.control_faction == null:
			continue
		seen[d.control_faction.name] = true
	return seen.size() >= 2


## Total resident civilians across all districts.
func total_civilian_population() -> float:
	var p: float = 0.0
	for d in districts:
		p += d.civilian_population
	return p


## A district whose footprint contains the world point, or null.
func district_at(wx: float, wz: float) -> CityDistrict:
	for d in districts:
		if d.contains_point(wx, wz):
			return d
	return null


func attach_towers(mmi: MultiMeshInstance3D) -> void:
	_towers = mmi
	if _towers and not _towers.is_inside_tree():
		add_child(_towers)


func get_towers() -> MultiMeshInstance3D:
	return _towers
