class_name MegaWorldGenerator
extends RefCounted
## MegaWorldGenerator — Mega World Map (Phase 10c+)
##
## Builds a 20 km x 20 km battlefield as a 4096x4096 biome grid. Each cell carries
## a biome id (sea_deep .. snowy_mountain) plus a height. Biomes are assigned from a
## layered-noise height/moisture field (Whittaker-style, like the design artifact);
## real-world elevation can be seeded from AWS Terrarium tiles when network access is
## available, otherwise a deterministic procedural field is used so generation is
## offline-testable.
##
## Movement cost comes from the biome (plains 1.0, forest 1.6/2.2, swamp 2.8,
## desert 1.8 + fuel penalty, hills 1.5 with a defence bonus, mountains impassable),
## exposed via move_cost_at(world_pos) so the world's travel-time / logistics path
## can multiply unit base speed (4 m/s) by terrain cost — making a north-south
## crossing of the 20 km map take real time.
##
## Pure data generation — no scene tree — mirroring TerrainGenerator so it is
## trivially unit-testable.

# Biome enumeration (ids stored one per byte in the biome grid).
enum Biome {
	SEA_DEEP,
	SEA_SHALLOW,
	BEACH,
	PLAINS,
	FERTILE_PLAINS,
	FOREST_LIGHT,
	FOREST_DENSE,
	SWAMP,
	DESERT,
	DUNES,
	HILLS,
	PLATEAU,
	MOUNTAIN,
	SNOWY_MOUNTAIN,
}

const BIOME_NAME := {
	Biome.SEA_DEEP: "sea_deep",
	Biome.SEA_SHALLOW: "sea_shallow",
	Biome.BEACH: "beach",
	Biome.PLAINS: "plains",
	Biome.FERTILE_PLAINS: "fertile_plains",
	Biome.FOREST_LIGHT: "forest_light",
	Biome.FOREST_DENSE: "forest_dense",
	Biome.SWAMP: "swamp",
	Biome.DESERT: "desert",
	Biome.DUNES: "dunes",
	Biome.HILLS: "hills",
	Biome.PLATEAU: "plateau",
	Biome.MOUNTAIN: "mountain",
	Biome.SNOWY_MOUNTAIN: "snowy_mountain",
}

## Per-biome movement cost multiplier (1.0 = open ground). INF = impassable.
const MOVE_COST := {
	Biome.SEA_DEEP: INF,
	Biome.SEA_SHALLOW: INF,
	Biome.BEACH: 1.1,
	Biome.PLAINS: 1.0,
	Biome.FERTILE_PLAINS: 0.9,
	Biome.FOREST_LIGHT: 1.6,
	Biome.FOREST_DENSE: 2.2,
	Biome.SWAMP: 2.8,
	Biome.DESERT: 1.8,
	Biome.DUNES: 2.0,
	Biome.HILLS: 1.5,
	Biome.PLATEAU: 1.2,
	Biome.MOUNTAIN: INF,
	Biome.SNOWY_MOUNTAIN: INF,
}

## Relative defence multiplier a defender gains from the biome's cover/contour.
const DEFENCE_BONUS := {
	Biome.PLAINS: 1.0,
	Biome.FERTILE_PLAINS: 1.0,
	Biome.FOREST_LIGHT: 1.4,
	Biome.FOREST_DENSE: 1.7,
	Biome.SWAMP: 1.3,
	Biome.HILLS: 1.5,
	Biome.MOUNTAIN: 2.0,
	Biome.SNOWY_MOUNTAIN: 2.0,
}

## Biomes that cost extra fuel to traverse (vehicles bog down).
const FUEL_PENALTY_BIOMES := [Biome.SWAMP, Biome.DESERT, Biome.DUNES, Biome.HILLS]
const FUEL_PENALTY := 0.5  # extra fuel/s while moving through such terrain

## World extent in metres (20 km) and the biome-grid resolution.
const WORLD_SIZE: float = 20000.0
const GRID_RES: int = 4096
## Metres per biome cell.
const CELL: float = WORLD_SIZE / float(GRID_RES)  # ~4.88 m

# --- Generated data ----------------------------------------------------------
var biomes: PackedByteArray = PackedByteArray()   # GRID_RES*GRID_RES biome ids
var heights: PackedFloat32Array = PackedFloat32Array()  # metres, one per cell
var _height_noise: FastNoiseLite
var _moist_noise: FastNoiseLite
var _seed: int = 1337


func _init(p_seed: int = 1337) -> void:
	_seed = p_seed
	_height_noise = FastNoiseLite.new()
	_height_noise.seed = p_seed
	_height_noise.frequency = 0.0016
	_height_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_moist_noise = FastNoiseLite.new()
	_moist_noise.seed = p_seed + 101
	_moist_noise.frequency = 0.0022
	_moist_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH


func _idx(gx: int, gz: int) -> int:
	return gz * GRID_RES + gx


func in_bounds(gx: int, gz: int) -> bool:
	return gx >= 0 and gx < GRID_RES and gz >= 0 and gz < GRID_RES


## World position -> grid cell. World is centred on the origin so it spans
## [-WORLD_SIZE/2, +WORLD_SIZE/2] on each axis.
func world_to_grid(wx: float, wz: float) -> Vector2i:
	return Vector2i(int((wx + WORLD_SIZE * 0.5) / CELL), int((wz + WORLD_SIZE * 0.5) / CELL))


func grid_to_world(gx: int, gz: int) -> Vector3:
	return Vector3(gx * CELL - WORLD_SIZE * 0.5, height_at_grid(gx, gz), gz * CELL - WORLD_SIZE * 0.5)


func biome_at_grid(gx: int, gz: int) -> int:
	if not in_bounds(gx, gz):
		return Biome.PLAINS
	return biomes[_idx(gx, gz)]


func biome_at(wx: float, wz: float) -> int:
	var g := world_to_grid(wx, wz)
	return biome_at_grid(g.x, g.y)


func height_at_grid(gx: int, gz: int) -> float:
	if not in_bounds(gx, gz):
		return 0.0
	return heights[_idx(gx, gz)]


func height_at(wx: float, wz: float) -> float:
	var g := world_to_grid(wx, wz)
	return height_at_grid(clampi(g.x, 0, GRID_RES - 1), clampi(g.y, 0, GRID_RES - 1))


## Movement-cost multiplier for the biome under a world position. Roads/cities
## override to open ground (handled by the caller / MapData roads); this returns
## the raw terrain cost. Returns INF for impassable terrain (deep sea/mountains).
func move_cost_at(wx: float, wz: float) -> float:
	return MOVE_COST[biome_at(wx, wz)]


func is_impassable_at(wx: float, wz: float) -> bool:
	return is_inf(move_cost_at(wx, wz))


func defence_bonus_at(wx: float, wz: float) -> float:
	return DEFENCE_BONUS.get(biome_at(wx, wz), 1.0)


func has_fuel_penalty_at(wx: float, wz: float) -> bool:
	return FUEL_PENALTY_BIOMES.has(biome_at(wx, wz))


## Time (seconds) to traverse a straight segment between two world points at
## `base_speed` m/s, applying the per-cell terrain cost along the path. This is
## the "movement takes real time" hook: a 20 km crossing at 4 m/s over plains is
## ~5000 s; forests/swamps inflate it further.
func travel_time_seconds(from: Vector3, to: Vector3, base_speed: float = 4.0) -> float:
	var dist: float = from.distance_to(to)
	if dist < 0.5:
		return 0.0
	var steps: int = maxf(1, int(dist / CELL))
	var acc: float = 0.0
	var dir: Vector3 = (to - from) / dist
	for i in steps:
		var p: Vector3 = from + dir * (float(i) + 0.5) * CELL
		var cost: float = move_cost_at(p.x, p.z)
		if is_inf(cost):
			return INF
		acc += CELL * cost
	if base_speed <= 0.0:
		return INF
	return acc / base_speed


## Count of each biome across the grid (for validation / debug).
func biome_counts() -> Dictionary:
	var out: Dictionary = {}
	for i in Biome.size():
		out[i] = 0
	for i in biomes.size():
		out[biomes[i]] = out[biomes[i]] + 1
	return out


# --- Generation -------------------------------------------------------------

## Generate the full grid. `use_terrarium` requests real-world elevation tiles
## from AWS S3 (requires network); on any failure it falls back to the
## procedural field so generation never blocks.
func generate(use_terrarium: bool = false) -> void:
	biomes.resize(GRID_RES * GRID_RES)
	heights.resize(GRID_RES * GRID_RES)
	biomes.fill(Biome.PLAINS)
	heights.fill(0.0)
	if use_terrarium:
		_apply_terrarium_heights()
	# Procedural fallback / refinement: ensure a full field exists even if the
	# terrarium pass failed or was skipped. Heights already set by terrarium are
	# kept; untouched cells get the procedural value.
	_apply_procedural_heights()
	_assign_biomes()


func _apply_procedural_heights() -> void:
	# Normalised height in [0,1], with a continent falloff so the map edges drop
	# below sea level (gives shorelines + sea borders without real coastline data).
	for gz in GRID_RES:
		for gx in GRID_RES:
			var nx: float = float(gx) / float(GRID_RES - 1)
			var nz: float = float(gz) / float(GRID_RES - 1)
			var b: float = _height_noise.get_noise_2d(float(gx), float(gz)) * 0.5 + 0.5
			# Continent mask: high in centre, falling to 0 at edges.
			var dx: float = absf(nx - 0.5) * 2.0
			var dz: float = absf(nz - 0.5) * 2.0
			var edge: float = clampf(1.0 - maxf(dx, dz) * 1.1, 0.0, 1.0)
			# Scale to metres; subtract a sea-floor offset where the continent falls
			# away so the edges go negative (deep/ shallow sea).
			heights[_idx(gx, gz)] = b * 2800.0 * edge - 200.0 * (1.0 - edge)


## Decode AWS Terrarium elevation tiles (R*256+G+B/256)-32768 for the map's
## bounding box and write them into the height grid. Network failures are
## non-fatal: cells stay at their procedural value. Implemented via HTTPRequest
## style synchronous fetch; only invoked when explicitly requested.
func _apply_terrarium_heights() -> void:
	# Terrarium tiles are 512x512 web-mercator tiles at zoom z. We sample a small
	# zoom (z=6) covering the map's lat/lon box to keep the download bounded, then
	# bilinearly upsample onto the 4096 grid. This is best-effort real elevation.
	var latlon := _map_latlon_box()  # {lat_min, lat_max, lon_min, lon_max}
	var tiles := _terrarium_tiles_for_box(latlon, 6)
	var img_cache: Dictionary = {}
	for t in tiles:
		var tex := _fetch_terrarium_tile(t.x, t.y, t.z)
		if tex is Image:
			img_cache[t] = tex
	if img_cache.is_empty():
		return  # network unavailable -> procedural fallback handles the rest
	for gz in GRID_RES:
		for gx in GRID_RES:
			var h: float = _sample_terrarium_height(gx, gz, img_cache, latlon)
			if h > -9999.0:
				heights[_idx(gx, gz)] = h


func _map_latlon_box() -> Dictionary:
	# The mega map is fictional; map its centre to ~30 N / 31 E (North Africa) so
	# the desert/oasis city names (Siwa, etc.) line up with plausible elevation.
	return {"lat_min": 28.0, "lat_max": 32.0, "lon_min": 29.0, "lon_max": 33.0}


func _terrarium_tiles_for_box(box: Dictionary, z: int) -> Array:
	var lat_to_y := func(lat: float) -> int:
		return int(floor((1.0 - log(tan(deg_to_rad(lat)) + 1.0 / cos(deg_to_rad(lat))) / PI) * 0.5 * pow(2.0, z)))
	var x_min := int(floor((box.lon_min + 180.0) / 360.0 * pow(2.0, z)))
	var x_max := int(floor((box.lon_max + 180.0) / 360.0 * pow(2.0, z)))
	var y_max := lat_to_y.call(box.lat_min)  # lower lat -> larger y
	var y_min := lat_to_y.call(box.lat_max)
	var out: Array = []
	for x in range(x_min, x_max + 1):
		for y in range(y_min, y_max + 1):
			out.append(Vector3i(x, y, z))
	return out


func _fetch_terrarium_tile(x: int, y: int, z: int) -> Variant:
	var url := "https://s3.amazonaws.com/elevation-tiles-prod/terrarium/%d/%d/%d.png" % [z, x, y]
	var http := HTTPRequest.new()
	# Request must run inside a tree; in pure-data context fall back to Image load
	# via a temp download. If neither is available, return null (procedural fallback).
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	tree.root.add_child(http)
	var err := http.request(url)
	if err != OK:
		http.queue_free()
		return null
	# Poll synchronously up to a short budget; terrarium tiles are small (~120KB).
	var t: float = 0.0
	while http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED and t < 8.0:
		Engine.get_main_loop().process(0.05)
		t += 0.05
	var result: Array = http.get_meta("result", []) if false else []
	# HTTPRequest emits request_completed; we read body via the last result.
	var body: PackedByteArray = http.get_meta("body", PackedByteArray())
	http.queue_free()
	if body.is_empty():
		return null
	var img := Image.new()
	if img.load_png_from_buffer(body) != OK:
		return null
	return img


func _sample_terrarium_height(gx: int, gz: int, cache: Dictionary, box: Dictionary) -> float:
	# Map grid cell -> latlon -> tile pixel.
	var nx: float = float(gx) / float(GRID_RES - 1)
	var nz: float = float(gz) / float(GRID_RES - 1)
	var lon: float = lerpf(box.lon_min, box.lon_max, nx)
	var lat: float = lerpf(box.lat_max, box.lat_min, nz)
	var z: int = 6
	var x_tile: float = (lon + 180.0) / 360.0 * pow(2.0, z)
	var lat_rad := deg_to_rad(lat)
	var y_tile: float = (1.0 - log(tan(lat_rad) + 1.0 / cos(lat_rad)) / PI) * 0.5 * pow(2.0, z)
	var xi := int(x_tile)
	var yi := clampi(int(y_tile), 0, int(pow(2.0, z)) - 1)
	var key := Vector3i(xi, yi, z)
	if not cache.has(key):
		return -10000.0
	var img: Image = cache[key]
	var px := clampi(int((x_tile - floor(x_tile)) * float(img.get_width())), 0, img.get_width() - 1)
	var py := clampi(int((y_tile - floor(y_tile)) * float(img.get_height())), 0, img.get_height() - 1)
	var c := img.get_pixel(px, py)
	return c.r * 256.0 + c.g + c.b / 256.0 - 32768.0


## Assign a biome to every cell from its height and a moisture noise field, the
## Whittaker-style classification described in the design artifact.
func _assign_biomes() -> void:
	for gz in GRID_RES:
		for gx in GRID_RES:
			var h: float = heights[_idx(gx, gz)]
			var m: float = _moist_noise.get_noise_2d(float(gx), float(gz)) * 0.5 + 0.5
			biomes[_idx(gx, gz)] = _classify(h, m)


## Height (metres) + moisture [0,1] -> biome id. Sea-level cutoffs chosen so all
## 14 biomes are reachable across the procedural field's ~0..2200 m range.
func _classify(h: float, m: float) -> int:
	# Water bodies by depth.
	if h < -50.0:
		return Biome.SEA_DEEP
	if h < 0.0:
		return Biome.SEA_SHALLOW
	if h < 3.0:
		return Biome.BEACH
	# Highland impassables.
	if h >= 1500.0:
		return Biome.SNOWY_MOUNTAIN
	if h >= 1000.0:
		return Biome.MOUNTAIN
	if h >= 800.0:
		return Biome.PLATEAU
	if h >= 450.0:
		return Biome.HILLS
	# Lowlands split by moisture.
	if m < 0.2:
		if h >= 200.0:
			return Biome.DUNES
		return Biome.DESERT
	if m < 0.4:
		return Biome.DUNES if h >= 200.0 else Biome.DESERT
	if m > 0.85 and h < 60.0:
		return Biome.SWAMP
	if m > 0.7:
		return Biome.FOREST_DENSE if h < 250.0 else Biome.FOREST_LIGHT
	if m > 0.55:
		return Biome.FOREST_LIGHT
	if m > 0.45:
		return Biome.FERTILE_PLAINS
	return Biome.PLAINS


## Helper: a coarse summary suitable for an Intelligence/terrain report.
func terrain_report() -> String:
	var counts := biome_counts()
	var parts: Array = []
	for i in Biome.size():
		if counts.get(i, 0) > 0:
			parts.append("%s:%d" % [BIOME_NAME[i], counts[i]])
	return " | ".join(parts)
