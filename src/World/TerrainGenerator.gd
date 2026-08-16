extends RefCounted
## TerrainGenerator
##
## Builds a MapData procedurally: layered noise heightfield with mountains,
## plateaus, a winding river, a road crossing it via a bridge, a couple of
## cities and strategic zones. Pure data generation — no scene tree.

class_name TerrainGenerator

var _noise: FastNoiseLite


func _init(seed: int = 1337) -> void:
	_noise = FastNoiseLite.new()
	_noise.seed = seed
	_noise.frequency = 0.012
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH


func generate(map_size: int = 96, cell: float = 2.0) -> MapData:
	var md := MapData.new()
	md.size = map_size
	md.cell = cell
	md.origin = Vector3(-float(map_size) * cell * 0.5, 0.0, -float(map_size) * cell * 0.5)
	md.heights.resize(map_size * map_size)
	md.heights.fill(0.0)

	# Heightfield: base hills + a mountain ridge + plateau band.
	for gz in map_size:
		for gx in map_size:
			var n := _noise.get_noise_2d(float(gx), float(gz))
			# n in [-1,1] -> [0, ~24]
			var h := (n * 0.5 + 0.5) * 22.0
			# Mountain ridge along x ~ 30% of the map.
			var ridge := absf(float(gx) - float(map_size) * 0.3)
			if ridge < 6.0:
				h = maxf(h, 26.0 - ridge * 2.5)
			# Plateau band along z ~ 70%.
			var plat := absf(float(gz) - float(map_size) * 0.7)
			if plat < 10.0:
				h = maxf(h, 9.0)
			md.set_height_at_grid(gx, gz, clampf(h, 0.0, 32.0))

	# A winding river crossing the map north-south near x ~ 50%.
	var river := PackedVector2Array()
	var half := float(map_size) * cell * 0.5
	for gz in range(0, map_size, 4):
		var wx := half + sin(float(gz) * 0.08) * 6.0
		var wz := md.origin.z + gz * cell
		river.append(Vector2(wx, wz))
	# Thicken into a polygon (offset both sides).
	var poly := PackedVector2Array()
	for i in river.size():
		poly.append(river[i] + Vector2(2.2, 0))
	for i in river.size() - 1:
		var j := river.size() - 1 - i
		poly.append(river[j] - Vector2(2.2, 0))
	md.add_water(poly)

	# A road running east-west at z ~ 0 (the equator), with a bridge where it
	# meets the river.
	var road := PackedVector2Array()
	road.append(Vector2(-half, 0))
	road.append(Vector2(half, 0))
	md.add_road(road)
	md.add_bridge(Vector2(half, 0), 4.0)

	# Two cities.
	md.add_city("Northport", Vector3(half * 0.4, 0, -half * 0.5))
	md.add_city("Southfield", Vector3(-half * 0.5, 0, half * 0.4))

	# Strategic zones.
	md.add_zone("Crossing", Rect2(half - 10, -8, 20, 16))
	md.add_zone("Ridge", Rect2(md.origin.x, -half, float(map_size) * cell, half))

	return md
