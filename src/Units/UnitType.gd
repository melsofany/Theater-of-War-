extends Resource
## UnitType
##
## Data-driven definition of a unit's combat and movement stats. One resource
## instance per unit kind (infantry, tank, artillery, …); units read their
## numbers from it so adding a new type is a data change, not code. Designed to
## be unit-testable in isolation.

class_name UnitType

enum Domain { GROUND, AIR }
enum Category {
	INFANTRY,
	VEHICLE,
	TANK,
	ARTILLERY,
	AIR_DEFENSE,
	AIRCRAFT,
	HELICOPTER,
}

@export var display_name: String = "Unit"
@export var category: Category = Category.INFANTRY
@export var domain: Domain = Domain.GROUND
@export var max_health: float = 100.0
## Flat damage reduction per hit (min 1 damage always applies).
@export var armor: float = 0.0
@export var damage: float = 10.0
@export var range: float = 20.0
@export var sight_range: float = 35.0
@export var attack_cooldown: float = 1.0
@export var max_speed: float = 8.0
@export var turn_speed: float = 6.0
@export var radius: float = 0.6
## Cruise altitude for AIR-domain units (ignored by ground units).
@export var cruise_altitude: float = 12.0
@export var can_attack_ground: bool = true
@export var can_attack_air: bool = false
## For artillery: shells arc over obstacles and ignore line-of-sight.
@export var indirect: bool = false


func is_air() -> bool:
	return domain == Domain.AIR


func can_attack(target_type: UnitType) -> bool:
	if target_type == null:
		return false
	if target_type.is_air():
		return can_attack_air
	return can_attack_ground
