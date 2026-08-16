extends Node
## Balance (autoload) — Phase 10b
##
## Central tunable multipliers for combat and economy so balance is a data edit,
## not scattered magic numbers. Systems read these at the point of application.
## Defaults are 1.0 (no change). A mod or difficulty preset can override values.

# Combat multipliers (applied to outgoing damage).
var damage_multiplier: float = 1.0
var armor_multiplier: float = 1.0

# Economy multipliers.
var income_multiplier: float = 1.0
var cost_multiplier: float = 1.0

# Logistics multipliers.
var supply_consumption_multiplier: float = 1.0
var fuel_consumption_multiplier: float = 1.0


func reset() -> void:
	damage_multiplier = 1.0
	armor_multiplier = 1.0
	income_multiplier = 1.0
	cost_multiplier = 1.0
	supply_consumption_multiplier = 1.0
	fuel_consumption_multiplier = 1.0


## Apply a difficulty preset by name.
func apply_preset(name: String) -> void:
	reset()
	match name:
		"easy":
			damage_multiplier = 1.2   # player hits harder
			income_multiplier = 1.3
		"hard":
			damage_multiplier = 0.8   # player hits softer
			income_multiplier = 0.8
			supply_consumption_multiplier = 1.2
		"normal", _:
			pass  # defaults


## Scale a raw damage value by the balance multiplier.
func scaled_damage(raw: float) -> float:
	return raw * damage_multiplier


## Scale a raw income value.
func scaled_income(raw: float) -> float:
	return raw * income_multiplier


## Scale a raw cost value.
func scaled_cost(raw: float) -> float:
	return raw * cost_multiplier
