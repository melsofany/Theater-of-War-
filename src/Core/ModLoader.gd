extends Node
## ModLoader (autoload) — Phase 10b
##
## Data-driven unit definitions. Scans `res://mods/` (and `user://mods/` at
## runtime) for `*.json` files describing unit types, and registers them into
## `UnitFactory`. This makes adding/rebalancing units a data edit, not a code
## change — the foundation of modding.
##
## JSON schema (one object per file, or an array of objects):
## {
##   "key": "modded_tank",
##   "display_name": "Heavy Tank",
##   "category": "TANK",
##   "domain": "GROUND",            // optional: GROUND | AIR | NAVAL
##   "max_health": 400,
##   "armor": 15,
##   "damage": 40,
##   "range": 28,
##   "sight_range": 32,
##   "max_speed": 8,
##   "radius": 1.0,
##   "turn_speed": 3.0,
##   "max_supply": 100,
##   "max_fuel": 100,
##   "indirect": false,
##   "can_attack_ground": true,
##   "can_attack_air": false
## }

var loaded_count: int = 0
var loaded_keys: Array = []


func _ready() -> void:
	load_all()


func load_all() -> int:
	loaded_count = 0
	loaded_keys.clear()
	var dirs := ["res://mods/", "user://mods/"]
	for d in dirs:
		_load_dir(d)
	return loaded_count


func _load_dir(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if not dir.current_is_dir() and name.ends_with(".json"):
			_load_file(path + name)
		name = dir.get_next()
	dir.list_dir_end()


func _load_file(path: String) -> void:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return
	var text := f.get_as_text()
	f.close()
	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		push_warning("ModLoader: failed to parse %s: %s" % [path, json.get_error_message()])
		return
	var data = json.data
	if data is Dictionary:
		_register_one(data)
	elif data is Array:
		for entry in data:
			if entry is Dictionary:
				_register_one(entry)


func _register_one(d: Dictionary) -> void:
	var key: String = d.get("key", "")
	if key.is_empty():
		return
	UnitFactory.register_from_dict(key, d)
	loaded_count += 1
	loaded_keys.append(key)
