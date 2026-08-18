class_name CivilianNPC
extends Node3D
## CivilianNPC — Mega World Map (Phase 10c+)
##
## A civilian resident of a city district. Extends the AI behaviour model: it
## observes the combat intensity of its district and, once it exceeds a threshold,
## flees toward a safer district or out of the city. Fleeing civilians:
##   - trigger an Intelligence report ("civilian exodus in <district>"), and
##   - drop the resident population of their home district, which lowers that
##     faction's city income in the Economy system.
##
## Kept as a Node3D (not CharacterBody3D) so it runs headless without a physics
## world; movement is a simple seek toward a flee target, mirroring how Unit seeks.

signal fled_home(district: CityDistrict)
signal exodus_reported(district_name: String, count: int)

@export var flee_threshold: float = 3.0
@export var move_speed: float = 3.0  # civilians move slower than military units

var home_district: CityDistrict = null
var current_district: CityDistrict = null
var flee_target: Vector3 = Vector3.ZERO
var is_fleeing: bool = false
var fled: bool = false
## Set by the world/city so this NPC can find a safe destination.
var world: Node = null

static var _exodus_counts: Dictionary = {}  # district_name -> count fled this wave


func _ready() -> void:
	current_district = home_district


func _process(delta: float) -> void:
	if fled:
		return
	var district := current_district if current_district else home_district
	if district == null:
		return
	if not is_fleeing and district.is_under_heavy_combat(flee_threshold):
		_begin_flee(district)
	if is_fleeing:
		_seek(delta)


func _begin_flee(district: CityDistrict) -> void:
	is_fleeing = true
	flee_target = _choose_flee_target(district)
	# Report the exodus to intelligence and economy.
	_exodus_counts[district.district_name] = _exodus_counts.get(district.district_name, 0) + 1
	exodus_reported.emit(district.district_name, int(_exodus_counts[district.district_name]))
	if Intelligence and Intelligence.has_method("add_contact"):
		var rep := Faction.new()
		rep.name = "civilians"
		# Surface the exodus as a low-confidence contact near the district centre.
		Intelligence.add_contact(rep, get_instance_id(), global_position, null, 0.1, false)
	if district.civilian_population > 0.0:
		district.set_population(maxf(0.0, district.civilian_population - 1.0))
		# Economy income tracks resident population; recompute the owning faction.
		_apply_economy_drop(district)


func _choose_flee_target(district: CityDistrict) -> Vector3:
	# Prefer a sibling district with low combat; else flee outside the city.
	var city := district.get_parent() as ModernCity
	if city:
		var best: CityDistrict = null
		var best_intensity: float = INF
		for d in city.districts:
			if d == district:
				continue
			if d.combat_intensity < best_intensity and d.combat_intensity < flee_threshold * 0.5:
				best_intensity = d.combat_intensity
				best = d
		if best:
			return best.global_position + Vector3(0.0, 0.0, 0.0)
		# Otherwise flee radially out of the city.
		return city.global_position + (district.global_position - city.global_position).normalized() * (ModernCity.CITY_EXTENT * 0.75)
	return district.global_position + Vector3(50.0, 0.0, 0.0)


func _seek(delta: float) -> void:
	var to: Vector3 = flee_target - global_position
	var d: float = to.length()
	if d < 2.0:
		fled = true
		is_fleeing = false
		if home_district:
			fled_home.emit(home_district)
		return
	global_position += to.normalized() * move_speed * delta


## Lower the owning faction's economy income because residents left. We don't have
## a direct "income per civilian" knob, so we model it as a materials penalty.
func _apply_economy_drop(district: CityDistrict) -> void:
	if not Economy:
		return
	var owner: Faction = district.control_faction
	if owner == null:
		return
	# Each fleeing civilian trims a sliver of materials income for the owner.
	if Economy.has_method("credit"):
		Economy.credit(owner.name, Economy.R.MATERIALS, -0.5)
