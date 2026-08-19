extends Control
## Minimap
##
## Draws the projected Unified World Map and live RTS entities. The attached
## Meta map is 16384x16384 in source coordinates; the runtime MapData projects
## those coordinates into its playable bounds, which are used for rendering.

class_name Minimap

@export var world: World
@export var camera: Camera3D
@export var bg_color: Color = Color(0.035, 0.05, 0.065, 0.95)
@export var border_color: Color = Color(0.55, 0.65, 0.72, 0.95)
@export var terrain_color: Color = Color(0.28, 0.22, 0.14, 1.0)
@export var zone_color: Color = Color(0.78, 0.61, 0.22, 0.22)
@export var road_color: Color = Color(0.78, 0.70, 0.50, 0.9)
@export var city_color: Color = Color(0.98, 0.82, 0.28, 1.0)
@export var player_color: Color = Color(0.3, 0.6, 1.0)
@export var enemy_color: Color = Color(1.0, 0.3, 0.3)
@export var camera_color: Color = Color(1.0, 1.0, 1.0, 0.8)
@export var world_bounds: Rect2 = Rect2(-128, -128, 256, 256)
@export var map_size: float = 16384.0
@export var dot_radius: float = 2.5

var _bounds_synced := false


func _ready() -> void:
	_sync_world_bounds()
	queue_redraw()


func _sync_world_bounds() -> void:
	if world == null or world.map_data == null:
		return
	var md: MapData = world.map_data
	world_bounds = Rect2(md.origin.x, md.origin.z, float(md.size) * md.cell, float(md.size) * md.cell)
	_bounds_synced = true


func _to_minimap(wp: Vector2) -> Vector2:
	var safe_size := Vector2(maxf(world_bounds.size.x, 1.0), maxf(world_bounds.size.y, 1.0))
	return Vector2(
		(wp.x - world_bounds.position.x) / safe_size.x * size.x,
		(wp.y - world_bounds.position.y) / safe_size.y * size.y
	)


func _map_line(line: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for point in line:
		out.append(_to_minimap(point))
	return out


func _draw() -> void:
	if not _bounds_synced:
		_sync_world_bounds()
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, bg_color, true)
	draw_rect(r, border_color, false, 1.5)
	if world == null or world.map_data == null:
		return
	var md: MapData = world.map_data

	# Strategic zones and roads from the attached Unified World Map.
	for zone in md.zones:
		var zr: Rect2 = zone["rect"]
		var a := _to_minimap(zr.position)
		var b := _to_minimap(zr.position + zr.size)
		draw_rect(Rect2(a, b - a), zone_color, true)
		draw_rect(Rect2(a, b - a), Color(zone_color.r, zone_color.g, zone_color.b, 0.7), false, 1.0)
	for line in md.roads:
		var mapped := _map_line(line as PackedVector2Array)
		if mapped.size() >= 2:
			draw_polyline(mapped, road_color, 1.2, true)

	# City markers make the Theater Map useful even before units spawn.
	for city in world.get_cities():
		if is_instance_valid(city):
			var cp := _to_minimap(Vector2(city.global_position.x, city.global_position.z))
			draw_circle(cp, 3.5, city_color)
			draw_circle(cp, 5.0, Color(city_color.r, city_color.g, city_color.b, 0.35), false, 1.0)

	# Live unit markers.
	for u in world.get_units():
		if not is_instance_valid(u) or u.faction == null:
			continue
		var mp := _to_minimap(Vector2(u.global_position.x, u.global_position.z))
		var c := enemy_color if not u.faction.is_player else player_color
		draw_circle(mp, dot_radius, c)

	# Camera indicator.
	if camera:
		var cy := camera.global_position
		var corners := PackedVector2Array()
		for off in [Vector2(-15, -10), Vector2(15, -10), Vector2(15, 10), Vector2(-15, 10)]:
			corners.append(_to_minimap(Vector2(cy.x + off.x, cy.z + off.y)))
		if corners.size() >= 2:
			draw_polyline(corners + PackedVector2Array([corners[0]]), camera_color, 1.0, true)


func _process(_delta: float) -> void:
	if world != null and world.map_data != null and not _bounds_synced:
		_sync_world_bounds()
	queue_redraw()
