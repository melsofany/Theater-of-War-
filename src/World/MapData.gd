extends Resource
## MapData
##
## Pure-data model for a battlefield's terrain features. Holds the height field
## and feature layers (cities, rivers, roads, bridges, strategic zones) plus
## query helpers used by movement, rendering and (later) AI. Keeping this
## data-only makes it trivially unit-testable without a scene tree.
##
## Phase 2 scope: heightfield + water/impassable/move-cost + cities + zones.

class_name MapData

# --- Height field -----------------------------------------------------------
# Grid is size x size cells, world_to_grid = (x - origin.x)/cell, etc.
var size: int = 128
var cell: float = 2.0
var origin: Vector3 = Vector3(-128.0, 0.0, -128.0)
# Row-major height array (size*size). Heights in metres.
var heights: PackedFloat32Array = PackedFloat32Array()

# --- Feature layers ---------------------------------------------------------
# Water polygons (river/lake) as arrays of Vector3 (world-space, y ignored).
var waters: Array = []  # Array of PackedVector2Array (xz loops)
# Road segments as world-space point lists.
var roads: Array = []  # Array of PackedVector2Array (xz polylines)
# Bridges: position + radius (world xz) where water becomes passable.
var bridges: Array = []  # Array of {position: Vector2, radius: float}
# Mountains: height threshold above which ground is impassable. The terrain
# pass is intentionally flatter than the original 32-unit range, so this
# threshold stays below the procedural ridge peak.
var mountain_height: float = 12.0
# Plateaus: gentle high ground (visual only; passable).
var plateau_height: float = 8.0

# --- Points of interest -----------------------------------------------------
var cities: Array = []  # Array of {name: String, position: Vector3}
var zones: Array = []  # Array of {name, rect: Rect2(world xz)}


func _init() -> void:
	heights.resize(size * size)
	heights.fill(0.0)


func idx(gx: int, gz: int) -> int:
	return gz * size + gx


func in_bounds(gx: int, gz: int) -> bool:
	return gx >= 0 and gx < size and gz >= 0 and gz < size


func world_to_grid(wx: float, wz: float) -> Vector2i:
	return Vector2i(int((wx - origin.x) / cell), int((wz - origin.z) / cell))


func grid_to_world(gx: int, gz: int) -> Vector3:
	return Vector3(origin.x + gx * cell, height_at_grid(gx, gz), origin.z + gz * cell)


func height_at_grid(gx: int, gz: int) -> float:
	if not in_bounds(gx, gz):
		return 0.0
	return heights[idx(gx, gz)]


func set_height_at_grid(gx: int, gz: int, h: float) -> void:
	if in_bounds(gx, gz):
		heights[idx(gx, gz)] = h


func height_at(wx: float, wz: float) -> float:
	# Bilinear sample of the height field.
	var g := world_to_grid(wx, wz)
	if not in_bounds(g.x, g.y):
		return 0.0
	var gx := clampi(g.x, 0, size - 2)
	var gz := clampi(g.y, 0, size - 2)
	var fx := (wx - (origin.x + gx * cell)) / cell
	var fz := (wz - (origin.z + gz * cell)) / cell
	fx = clampf(fx, 0.0, 1.0)
	fz = clampf(fz, 0.0, 1.0)
	var h00 := height_at_grid(gx, gz)
	var h10 := height_at_grid(gx + 1, gz)
	var h01 := height_at_grid(gx, gz + 1)
	var h11 := height_at_grid(gx + 1, gz + 1)
	return lerpf(lerpf(h00, h10, fx), lerpf(h01, h11, fx), fz)


func is_water(wx: float, wz: float) -> bool:
	for loop in waters:
		var poly := loop as PackedVector2Array
		if poly.size() < 3:
			continue
		if _point_in_polygon(Vector2(wx, wz), poly):
			return true
	return false


func is_bridge(wx: float, wz: float) -> bool:
	for b in bridges:
		var bp: Vector2 = b["position"]
		var br: float = b["radius"]
		if bp.distance_to(Vector2(wx, wz)) <= br:
			return true
	return false


func is_impassable(wx: float, wz: float) -> bool:
	# Mountains (steep/high) and water (unless a bridge).
	if height_at(wx, wz) >= mountain_height:
		return true
	if is_water(wx, wz) and not is_bridge(wx, wz):
		return true
	return false


func move_cost(wx: float, wz: float) -> float:
	# 1.0 = normal; roads cheaper; water/mountains impassable handled separately.
	if is_impassable(wx, wz):
		return INF
	var cost := 1.0
	if _on_road(wx, wz):
		cost = 0.5
	return cost


func _on_road(wx: float, wz: float) -> bool:
	var p := Vector2(wx, wz)
	const ROAD_HALF := 1.5
	for line in roads:
		var pts := line as PackedVector2Array
		for i in pts.size() - 1:
			if Geometry2D.is_point_in_circle(p, pts[i], ROAD_HALF):
				return true
			if _dist_to_segment(p, pts[i], pts[i + 1]) <= ROAD_HALF:
				return true
	return false


func _dist_to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var l2 := ab.length_squared()
	if l2 < 0.0001:
		return p.distance_to(a)
	var t := clampf((p - a).dot(ab) / l2, 0.0, 1.0)
	return p.distance_to(a + ab * t)


func _point_in_polygon(p: Vector2, poly: PackedVector2Array) -> bool:
	return Geometry2D.is_point_in_polygon(p, poly)


func add_city(city_name: String, pos: Vector3) -> void:
	cities.append({"name": city_name, "position": pos})


func add_zone(zone_name: String, rect: Rect2) -> void:
	zones.append({"name": zone_name, "rect": rect})


func add_bridge(pos: Vector2, radius: float) -> void:
	bridges.append({"position": pos, "radius": radius})


func add_water(loop: PackedVector2Array) -> void:
	waters.append(loop)


func add_road(line: PackedVector2Array) -> void:
	roads.append(line)
