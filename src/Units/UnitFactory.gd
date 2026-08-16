extends Node
## UnitFactory (autoload)
##
## Central registry of unit-type definitions. Returns configured `UnitType`
## resources by name so the rest of the game refers to types by string without
## hardcoding stats. Phase 3 covers the seven required categories; later phases
## can extend the dictionary.

var _types: Dictionary = {}


func _ready() -> void:
	_register_defaults()


func _register_defaults() -> void:
	_register("infantry", _make("Infantry", UnitType.Category.INFANTRY, 80, 1, 8, 18, 30, 7.0, 0.6, 4.0))
	_register("vehicle", _make("Vehicle", UnitType.Category.VEHICLE, 120, 3, 12, 22, 32, 12.0, 0.6, 4.0))
	_register("tank", _make("Tank", UnitType.Category.TANK, 300, 12, 35, 24, 30, 9.0, 1.0, 3.5))
	_register("artillery", _make("Artillery", UnitType.Category.ARTILLERY, 90, 2, 60, 55, 28, 4.0, 2.0, 2.0, {"indirect": true}))
	_register("air_defense", _make("Air Defense", UnitType.Category.AIR_DEFENSE, 100, 4, 14, 40, 34, 6.0, 0.7, 2.0, {"can_ground": false, "can_air": true}))
	_register("aircraft", _make("Aircraft", UnitType.Category.AIRCRAFT, 70, 0, 25, 30, 45, 22.0, 1.0, 5.0, {"domain": UnitType.Domain.AIR, "alt": 14.0, "can_air": true}))
	_register("helicopter", _make("Helicopter", UnitType.Category.HELICOPTER, 90, 0, 18, 26, 40, 16.0, 1.2, 4.0, {"domain": UnitType.Domain.AIR, "alt": 10.0, "can_air": true}))


func _make(
		u_name: String, cat: UnitType.Category, hp: float, arm: float, dmg: float,
		rng: float, sight: float, spd: float, rad: float, turn: float,
		opts: Dictionary = {}
) -> UnitType:
	var t := UnitType.new()
	t.display_name = u_name
	t.category = cat
	t.max_health = hp
	t.armor = arm
	t.damage = dmg
	t.range = rng
	t.sight_range = sight
	t.max_speed = spd
	t.radius = rad
	t.turn_speed = turn
	if opts.has("indirect"):
		t.indirect = opts["indirect"]
	if opts.has("can_ground"):
		t.can_attack_ground = opts["can_ground"]
	if opts.has("can_air"):
		t.can_attack_air = opts["can_air"]
	if opts.has("domain"):
		t.domain = opts["domain"]
	if opts.has("alt"):
		t.cruise_altitude = opts["alt"]
	# Air units can attack air by default (dogfight) unless overridden.
	if t.domain == UnitType.Domain.AIR and not opts.has("can_air"):
		t.can_attack_air = true
	return t


func _register(key: String, t: UnitType) -> void:
	_types[key] = t


func get_type(key: String) -> UnitType:
	return _types.get(key, _types["infantry"])


func cost_of(key: String) -> Dictionary:
	# Resource costs (Economy.R keys) to produce one unit of this type.
	match key:
		"infantry":
			return {Economy.R.MANPOWER: 50, Economy.R.MATERIALS: 20}
		"vehicle":
			return {Economy.R.MANPOWER: 30, Economy.R.FUEL: 20, Economy.R.MATERIALS: 50}
		"tank":
			return {Economy.R.MANPOWER: 25, Economy.R.FUEL: 40, Economy.R.MATERIALS: 90}
		"artillery":
			return {Economy.R.MANPOWER: 30, Economy.R.FUEL: 15, Economy.R.MATERIALS: 70}
		"air_defense":
			return {Economy.R.MANPOWER: 30, Economy.R.FUEL: 20, Economy.R.MATERIALS: 60}
		"aircraft":
			return {Economy.R.MANPOWER: 20, Economy.R.FUEL: 60, Economy.R.MATERIALS: 80}
		"helicopter":
			return {Economy.R.MANPOWER: 25, Economy.R.FUEL: 50, Economy.R.MATERIALS: 70}
	return {Economy.R.MANPOWER: 50, Economy.R.MATERIALS: 20}


func all_keys() -> Array:
	return _types.keys()
