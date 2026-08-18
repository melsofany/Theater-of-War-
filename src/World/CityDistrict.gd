class_name CityDistrict
extends Node3D
## CityDistrict — Mega World Map (Phase 10c+)
##
## A controllable slice of a modern city. A modern city is split into 4-6 districts
## (North/South/Downtown/Industrial/Port/...). Each district tracks the faction that
## currently holds it, so a single city can be divided between armies: one side
## holds the north district while the enemy holds the south — enabling the urban
## guerrilla / street-to-street fighting model (UrbanWarfareSystem).
##
## A district carries its building/glass-tower data and civilian spawn points, and
## reports capture transitions (so Economy income and Intelligence can react). It
## is a Node3D so towers / spawn markers can live in its local space.

signal captured(new_faction: Faction, old_faction: Faction)

@export var district_name: String = "District"
## Faction currently holding this district (null = contested/unoccupied).
var control_faction: Faction = null
@export var building_count: int = 0
## Number of glass towers (rendered via a shared MultiMesh by the city generator).
var glass_tower_count: int = 0
## World-space civilian spawn points within this district.
var civilian_spawn_points: PackedVector3Array = PackedVector3Array()
## Local-space footprint AABB (xz) of the district, used for capture/proximity.
var footprint: Rect2 = Rect2()

var combat_intensity: float = 0.0
## Civilian population currently resident (drives Economy income).
var civilian_population: float = 0.0


## Capture threshold: a faction must hold `capture_progress >= 1.0` to flip the
## district. Advances when friendly units outnumber enemies inside the footprint.
var capture_progress: float = 0.0
var capturing_faction: Faction = null


func _process(delta: float) -> void:
	# Combat intensity decays toward 0 when no fighting is reported; civilians
	# flee while it stays above the flee threshold (see CivilianNPC).
	combat_intensity = maxf(0.0, combat_intensity - 0.2 * delta)


func set_population(p: float) -> void:
	civilian_population = maxf(0.0, p)


func add_combat_intensity(amount: float) -> void:
	combat_intensity = clampf(combat_intensity + amount, 0.0, 10.0)


## Resolve a capture: when an attacker reaches full progress, flip control.
func resolve_capture(attacker: Faction) -> void:
	if attacker == null:
		return
	if control_faction != null and control_faction.name == attacker.name:
		capture_progress = 1.0
		return
	capture_progress = 1.0
	var old := control_faction
	control_faction = attacker
	capture_progress = 0.0
	captured.emit(attacker, old)


## True when fighting in or near this district is intense enough to spook civilians.
func is_under_heavy_combat(threshold: float = 3.0) -> bool:
	return combat_intensity >= threshold


## A point (world xz) lies inside the district footprint?
func contains_point(wx: float, wz: float) -> bool:
	var local := to_local(Vector3(wx, 0.0, wz))
	return footprint.has_point(Vector2(local.x, local.z))
