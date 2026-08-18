class_name RoadNetworkGenerator
extends RefCounted
## RoadNetworkGenerator — Mega World Map (Phase 10c+)
##
## Builds the road network that supply trucks depend on. Roads connect the six
## mega cities so a Logistics supply truck can move from one city to another along
## a road, and — per the design artifact — real-world road geometry can be pulled
## from OpenStreetMap via the Overpass API (https://overpass-api.de/api/interpreter)
## using the OSM Buildings style. Network access is optional: when unavailable or
## not requested, a deterministic procedural road mesh (straight segments between
## city centres, snapped to passable terrain) is produced so the supply-path logic
## is offline-testable.
##
## Each road is a PackedVector2Array of world xz waypoints; Logistics.supply_travel_time
## consumes a road as a sequence of segments and is cut by a contested city.

@export var overpass_endpoint: String = "https://overpass-api.de/api/interpreter"

## Procedurally connect every pair of cities whose centres are within `max_gap`
## metres, producing straight two-point road segments. Roads avoid impassable
## terrain (mountains/deep sea) by routing through the nearest passable midpoint.
func generate_procedural(city_centres: Array, mega: MegaWorldGenerator, max_gap: float = 12000.0) -> Array:
	var roads: Array = []
	for i in city_centres.size():
		for j in range(i + 1, city_centres.size()):
			var a: Vector3 = city_centres[i]
			var b: Vector3 = city_centres[j]
			if a.distance_to(b) > max_gap:
				continue
			var pts := PackedVector2Array()
			pts.append(Vector2(a.x, a.z))
			# If the direct segment crosses impassable terrain, bend it via a
			# passable midpoint found by sampling along the perpendicular.
			if _segment_blocked(a, b, mega):
				var mid := _passable_midpoint(a, b, mega)
				pts.append(Vector2(mid.x, mid.z))
			pts.append(Vector2(b.x, b.z))
			roads.append(pts)
	return roads


func _segment_blocked(a: Vector3, b: Vector3, mega: MegaWorldGenerator) -> bool:
	var dist: float = a.distance_to(b)
	var dir: Vector3 = (b - a) / dist
	var steps: int = maxf(1, int(dist / MegaWorldGenerator.CELL))
	for i in steps:
		var p: Vector3 = a + dir * (float(i) + 0.5) * MegaWorldGenerator.CELL
		if mega.is_impassable_at(p.x, p.z):
			return true
	return false


func _passable_midpoint(a: Vector3, b: Vector3, mega: MegaWorldGenerator) -> Vector3:
	var mid: Vector3 = (a + b) * 0.5
	var dir: Vector3 = (b - a).normalized()
	var perp := Vector3(-dir.z, 0.0, dir.x)
	# Scan outward along the perpendicular for the first passable point.
	for offset in [0.0, 250.0, -250.0, 750.0, -750.0, 1500.0, -1500.0]:
		var cand: Vector3 = mid + perp * offset
		if not mega.is_impassable_at(cand.x, cand.z):
			return cand
	return mid


## Best-effort fetch of OSM highways for the map's lat/lon box via Overpass.
## Returns an Array of PackedVector2Array (world xz) on success, or [] on failure
## (so callers fall back to the procedural network). Each way's lat/lon nodes are
## projected into world space via the same lat/lon->world transform used by
## MegaWorldGenerator's terrarium sampling.
func fetch_osm_roads(latlon_box: Dictionary, mega: MegaWorldGenerator) -> Array:
	var query := "[out:json][timeout:25];way[\"highway\"~\"motorway|trunk|primary|secondary\"](%f,%f,%f,%f);out geom;"
	var q := query % [latlon_box.lat_min, latlon_box.lon_min, latlon_box.lat_max, latlon_box.lon_max]
	var http := HTTPRequest.new()
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return []
	tree.root.add_child(http)
	var err := http.request(overpass_endpoint, ["Content-Type: application/x-www-form-urlencoded"], HTTPClient.METHOD_POST, "data=" + q.uri_encode())
	if err != OK:
		http.queue_free()
		return []
	var t: float = 0.0
	while http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED and t < 10.0:
		Engine.get_main_loop().process(0.05)
		t += 0.05
	var body: PackedByteArray = http.get_meta("body", PackedByteArray())
	http.queue_free()
	if body.is_empty():
		return []
	var text := body.get_string_from_utf8()
	return _parse_overpass_geom(text, latlon_box, mega)


func _parse_overpass_geom(text: String, box: Dictionary, mega: MegaWorldGenerator) -> Array:
	# Minimal JSON walk: pull every "geometry":[{lat,lon},...] array. Robust enough
	# for the simple way-geometry output Overpass returns with `out geom;`.
	var roads: Array = []
	var key := "\"geometry\":["
	var idx := 0
	while true:
		var at := text.find(key, idx)
		if at < 0:
			break
		var start := at + key.length()
		var end := text.find("]", start)
		if end < 0:
			break
		var chunk := text.substr(start, end - start)
		var pts := PackedVector2Array()
		var lat := 0.0
		var lon := 0.0
		var have := false
		var i := 0
		while i < chunk.length():
			if chunk.substr(i).begins_with("\"lat\":"):
				var colon := chunk.find(":", i + 5)
				var comma := chunk.find(",", colon)
				if comma < 0:
					comma = chunk.length()
				lat = chunk.substr(colon + 1, comma - colon - 1).to_float()
			elif chunk.substr(i).begins_with("\"lon\":"):
				var colon := chunk.find(":", i + 5)
				var comma := chunk.find(",", colon)
				if comma < 0:
					comma = chunk.length()
				lon = chunk.substr(colon + 1, comma - colon - 1).to_float()
				have = true
			if have:
				pts.append(_latlon_to_world(lat, lon, box, mega))
				have = false
			i += 1
		if pts.size() >= 2:
			roads.append(pts)
		idx = end + 1
	return roads


## Project a lat/lon into the mega map's world space. The map spans
## [-WORLD_SIZE/2, +WORLD_SIZE/2] and maps the latlon_box onto that square.
func _latlon_to_world(lat: float, lon: float, box: Dictionary, _mega: MegaWorldGenerator) -> Vector2:
	var nx: float = inverse_lerp(box.lon_min, box.lon_max, lon)
	var nz: float = inverse_lerp(box.lat_max, box.lat_min, lat)
	var wx: float = lerpf(-MegaWorldGenerator.WORLD_SIZE * 0.5, MegaWorldGenerator.WORLD_SIZE * 0.5, nx)
	var wz: float = lerpf(-MegaWorldGenerator.WORLD_SIZE * 0.5, MegaWorldGenerator.WORLD_SIZE * 0.5, nz)
	return Vector2(wx, wz)
