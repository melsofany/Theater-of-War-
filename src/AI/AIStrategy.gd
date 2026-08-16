class_name AIStrategy
extends RefCounted
## Pure decision logic for the three-layer AI.
##
## Given a situation snapshot it produces an `AIDecision` (posture + objective).
## This class has no Godot scene dependencies beyond Vector3/Fraction, so it is
## fully unit-testable in isolation. The AI is deliberately bounded: it decides
## only on the information in the snapshot (which is built from fog-of-war
## intelligence, not omniscience).

enum Posture { OFFENSIVE, DEFENSIVE, REGROUP }

## Thresholds (data, not hardcoded magic numbers inside logic).
@export var offensive_ratio: float = 1.3
@export var defensive_ratio: float = 0.7
@export var offensive_readiness: float = 0.5
@export var defensive_readiness: float = 0.3
## A unit below this health fraction is ordered to retreat (tactical).
@export var retreat_health_fraction: float = 0.25


## `snapshot` keys:
##   own_force: float, enemy_force: float, avg_readiness: float,
##   own_buildings: Array[Vector3], enemy_known_positions: Array[Vector3],
##   home_pos: Vector3
func decide(snapshot: Dictionary) -> Dictionary:
	var own: float = snapshot.get("own_force", 0.0)
	var enemy: float = snapshot.get("enemy_force", 0.0)
	var readiness: float = snapshot.get("avg_readiness", 1.0)
	var ratio: float = own / maxf(enemy, 1.0)

	var posture: int = Posture.REGROUP
	var objective: Vector3 = snapshot.get("home_pos", Vector3.ZERO)

	var enemy_positions: Array = snapshot.get("enemy_known_positions", [])
	var own_buildings: Array = snapshot.get("own_buildings", [])

	if ratio >= offensive_ratio and readiness >= offensive_readiness and not enemy_positions.is_empty():
		posture = Posture.OFFENSIVE
		objective = _nearest(enemy_positions, snapshot.get("rally_pos", objective))
	elif ratio <= defensive_ratio or readiness <= defensive_readiness:
		posture = Posture.DEFENSIVE
		# Defend the centroid of own buildings (or home).
		if not own_buildings.is_empty():
			objective = _centroid(own_buildings)
		else:
			objective = snapshot.get("home_pos", Vector3.ZERO)
	else:
		posture = Posture.REGROUP
		objective = snapshot.get("rally_pos", snapshot.get("home_pos", Vector3.ZERO))

	return {
		"posture": posture,
		"objective": objective,
		"force_ratio": ratio,
		"retreat_health_fraction": retreat_health_fraction,
	}


func _nearest(points: Array, from: Vector3) -> Vector3:
	var best: Vector3 = from
	var best_d: float = INF
	for p in points:
		if p is Vector3:
			var d: float = from.distance_to(p)
			if d < best_d:
				best_d = d
				best = p
	return best


func _centroid(points: Array) -> Vector3:
	var sum := Vector3.ZERO
	var n: int = 0
	for p in points:
		if p is Vector3:
			sum += p
			n += 1
	if n == 0:
		return Vector3.ZERO
	return sum / float(n)
