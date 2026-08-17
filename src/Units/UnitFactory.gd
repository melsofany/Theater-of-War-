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
	_register("sniper", _make("Sniper", UnitType.Category.SNIPER, 55, 0, 32, 65, 58, 6.0, 0.45, 5.0))
	_register("vehicle", _make("Vehicle", UnitType.Category.VEHICLE, 120, 3, 12, 22, 32, 12.0, 0.6, 4.0))
	_register("tank", _make("Tank", UnitType.Category.TANK, 300, 12, 35, 24, 30, 9.0, 1.0, 3.5))
	_register("artillery", _make("Artillery", UnitType.Category.ARTILLERY, 90, 2, 60, 55, 28, 4.0, 2.0, 2.0, {"indirect": true}))
	_register("air_defense", _make("Air Defense", UnitType.Category.AIR_DEFENSE, 100, 4, 14, 40, 34, 6.0, 0.7, 2.0, {"can_ground": false, "can_air": true}))
	_register("aircraft", _make("Aircraft", UnitType.Category.AIRCRAFT, 70, 0, 25, 30, 45, 22.0, 1.0, 5.0, {"domain": UnitType.Domain.AIR, "alt": 14.0, "can_air": true}))
	_register("helicopter", _make("Helicopter", UnitType.Category.HELICOPTER, 90, 0, 18, 26, 40, 16.0, 1.2, 4.0, {"domain": UnitType.Domain.AIR, "alt": 10.0, "can_air": true}))
	_register("destroyer", _make("Destroyer", UnitType.Category.VEHICLE, 400, 8, 30, 32, 38, 10.0, 0.8, 4.0, {"domain": UnitType.Domain.NAVAL}))


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
	t.key = key
	_types[key] = t


## Public registration (used by the ModLoader to add data-driven unit types).
func register(key: String, t: UnitType) -> void:
	_register(key, t)


## Build and register a UnitType from a plain dictionary (JSON-friendly).
## Used by mods. Keys mirror the UnitType @export fields.
func register_from_dict(key: String, d: Dictionary) -> UnitType:
	var t := UnitType.new()
	t.display_name = d.get("display_name", key)
	t.category = _category_from_name(d.get("category", "INFANTRY"))
	t.max_health = float(d.get("max_health", 80))
	t.armor = float(d.get("armor", 0))
	t.damage = float(d.get("damage", 8))
	t.range = float(d.get("range", 18))
	t.sight_range = float(d.get("sight_range", 30))
	t.max_speed = float(d.get("max_speed", 7))
	t.radius = float(d.get("radius", 0.6))
	t.turn_speed = float(d.get("turn_speed", 4))
	t.max_supply = float(d.get("max_supply", 100))
	t.max_fuel = float(d.get("max_fuel", 100))
	if d.has("indirect"):
		t.indirect = bool(d["indirect"])
	if d.has("can_attack_ground"):
		t.can_attack_ground = bool(d["can_attack_ground"])
	if d.has("can_attack_air"):
		t.can_attack_air = bool(d["can_attack_air"])
	if d.has("domain"):
		t.domain = _domain_from_name(d["domain"])
	if d.has("cruise_altitude"):
		t.cruise_altitude = float(d["cruise_altitude"])
	if t.domain == UnitType.Domain.AIR and not d.has("can_attack_air"):
		t.can_attack_air = true
	_register(key, t)
	return t


static func _category_from_name(n: String) -> UnitType.Category:
	match n.to_upper():
		"INFANTRY": return UnitType.Category.INFANTRY
		"SNIPER": return UnitType.Category.SNIPER
		"VEHICLE": return UnitType.Category.VEHICLE
		"TANK": return UnitType.Category.TANK
		"ARTILLERY": return UnitType.Category.ARTILLERY
		"AIR_DEFENSE": return UnitType.Category.AIR_DEFENSE
		"AIRCRAFT": return UnitType.Category.AIRCRAFT
		"HELICOPTER": return UnitType.Category.HELICOPTER
	return UnitType.Category.INFANTRY


static func _domain_from_name(n: String) -> UnitType.Domain:
	match n.to_upper():
		"AIR": return UnitType.Domain.AIR
		"NAVAL": return UnitType.Domain.NAVAL
	return UnitType.Domain.GROUND


func get_type(key: String) -> UnitType:
	return _types.get(key, _types["infantry"])


func cost_of(key: String) -> Dictionary:
	# Resource costs (Economy.R keys) to produce one unit of this type.
	match key:
		"infantry":
			return {Economy.R.MANPOWER: 50, Economy.R.MATERIALS: 20}
		"sniper":
			return {Economy.R.MANPOWER: 70, Economy.R.MATERIALS: 35}
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
		"destroyer":
			return {Economy.R.MANPOWER: 40, Economy.R.FUEL: 60, Economy.R.MATERIALS: 120}
	return {Economy.R.MANPOWER: 50, Economy.R.MATERIALS: 20}


func all_keys() -> Array:
	return _types.keys()
