class_name UrbanWarfareSystem
extends RefCounted
## UrbanWarfareSystem — Mega World Map (Phase 10c+)
##
## When a modern city is split between armies (is_split()), this enables urban
## guerrilla mechanics:
##   - small squads can hide inside a district's buildings (registered in the
##     world SpatialGrid), granting ambush capability,
##   - buildings provide cover: a unit attacking a defender in a building suffers
##     a defence bonus of x1.8 (applied through the Balance multipliers),
##   - street-to-street fighting: line of sight between two street positions is
##     blocked when a glass tower stands between them.
##
## Pure logic (no rendering); uses the world's SpatialGrid and the city's tower
## transforms for the queries so it is unit-testable.

const BUILDING_COVER_BONUS: float = 1.8
const HIDE_CELL_RADIUS: float = 16.0

var world: Node = null


func _init(p_world: Node = null) -> void:
	world = p_world


## Is guerrilla warfare active in this city? Only when two factions hold districts.
func is_guerrilla_active(city: ModernCity) -> bool:
	return city != null and city.is_split()


## A squad attempts to hide inside the district's building cluster. Returns true
## when the squad (at `pos`) is within the cover radius of a building/district
## tower footprint, meaning it cannot be seen except at very close range.
func can_hide(city: ModernCity, pos: Vector3) -> bool:
	if not is_guerrilla_active(city):
		return false
	var district := city.district_at(pos.x, pos.z)
	if district == null:
		return false
	# Hiding is granted by proximity to the district's tower cluster: a tower is a
	# building. We approximate via the district footprint centre distance.
	var local := district.to_local(pos)
	return district.footprint.has_point(Vector2(local.x, local.z))


## Ambush: a hidden squad reveals and strikes a passing enemy. `ambusher` is
## considered hidden if can_hide() holds; the ambush succeeds (bonus damage) when
## the target is within HIDE_CELL_RADIUS of the ambusher's position.
func try_ambush(city: ModernCity, ambusher_pos: Vector3, target_pos: Vector3) -> float:
	if not can_hide(city, ambusher_pos):
		return 1.0
	if ambusher_pos.distance_to(target_pos) > HIDE_CELL_RADIUS:
		return 1.0
	# Ambush bonus stacks with the building cover bonus.
	return BUILDING_COVER_BONUS * 1.5


## Cover bonus for a defender occupying a building/district. Applied as a damage
## reduction on incoming fire (the attacker's damage is divided by this).
func cover_bonus_for(city: ModernCity, pos: Vector3) -> float:
	if city == null:
		return 1.0
	var district := city.district_at(pos.x, pos.z)
	if district == null:
		return 1.0
	if not is_guerrilla_active(city):
		return 1.0
	return BUILDING_COVER_BONUS


## Street-to-street line of sight: blocked when a glass tower's (vertical) box
## intersects the segment between `from` and `to` in the xz-plane. Towers are
## approximated as 12 m square footprints (matching ModernCityGenerator's box scale).
func has_line_of_sight(city: ModernCity, from: Vector3, to: Vector3) -> bool:
	if city == null:
		return true
	var mmi := city.get_towers()
	if mmi == null or mmi.multimesh == null:
		return true
	var mm: MultiMesh = mmi.multimesh
	var half: float = 6.0  # half of a 12 m tower footprint
	for i in mm.instance_count:
		var t: Transform3D = mm.get_instance_transform(i)
		var cx: float = t.origin.x
		var cz: float = t.origin.z
		if _segment_intersects_box(from, to, Vector2(cx, cz), half):
			return false
	return true


## Scaled cover/defence value routed through the Balance autoload so mods can tune
## urban combat centrally. Returns the final defence multiplier for a defender.
func scaled_urban_defence(city: ModernCity, pos: Vector3) -> float:
	var raw: float = cover_bonus_for(city, pos)
	if Balance:
		return raw * Balance.armor_multiplier
	return raw


func _segment_intersects_box(from: Vector3, to: Vector3, centre: Vector2, half: float) -> bool:
	# Liang-Barsky clipping of the segment against the AABB [cx-h, cx+h] x [cy-h, cy+h].
	var p := Vector2(from.x, from.z)
	var q := Vector2(to.x, to.z)
	var d := q - p
	var t0: float = 0.0
	var t1: float = 1.0
	var mins := centre - Vector2(half, half)
	var maxs := centre + Vector2(half, half)
	for axis in range(2):
		var p_v: float = p[axis]
		var d_v: float = d[axis]
		var lo: float = mins[axis]
		var hi: float = maxs[axis]
		if absf(d_v) < 1e-6:
			if p_v < lo or p_v > hi:
				return false
			continue
		var f: float = (lo - p_v) / d_v
		var g: float = (hi - p_v) / d_v
		if f > g:
			var tmp := f
			f = g
			g = tmp
		t0 = maxf(t0, f)
		t1 = minf(t1, g)
		if t0 > t1:
			return false
	return t0 <= t1 and t1 > 0.0 and t0 < 1.0
