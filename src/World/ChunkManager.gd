class_name ChunkManager
## ChunkManager — Phase 10b (large world / streaming)
##
## Determines which terrain chunks should be loaded given a focus position and a
## view radius. Chunks are `chunk_size` world units, indexed by integer cell
## coords (xz). A chunk is "active" if it lies within the view radius around the
## focus; chunks leaving the set are unloaded, chunks entering are loaded.
##
## This is the pure math/booking layer; actual streaming rendering is wired in a
## later pass. Kept data-only so it is trivially unit-testable.

var chunk_size: float
var view_radius: float
# When true, the desired set is a square (Chebyshev) ring of `ring_radius`
# chunks around the focus instead of a Euclidean disc. Used for the mega-map
# "9 chunks around camera" streaming profile, which a distance disc cannot
# express exactly for an arbitrary focus position.
var use_square_ring: bool = false
var ring_radius: int = 1
# Currently active chunk keys (Vector2i) -> true.
var _active: Dictionary = {}


func _init(p_chunk_size: float = 64.0, p_view_radius: float = 160.0) -> void:
	chunk_size = maxf(p_chunk_size, 1.0)
	view_radius = maxf(p_view_radius, chunk_size)


func clear() -> void:
	_active.clear()


static func chunk_key_of(pos: Vector3, chunk_size: float) -> Vector2i:
	return Vector2i(int(floor(pos.x / chunk_size)), int(floor(pos.z / chunk_size)))


## The set of chunk keys that should be active around `focus`.
func desired_chunks(focus: Vector3) -> Array:
	var out: Array = []
	var ck := chunk_key_of(focus, chunk_size)
	if use_square_ring:
		var r: int = ring_radius
		for dx in range(-r, r + 1):
			for dz in range(-r, r + 1):
				out.append(Vector2i(ck.x + dx, ck.y + dz))
		return out
	var r := int(ceil(view_radius / chunk_size))
	var r2: float = view_radius * view_radius
	# Test chunk centers within the radius.
	for dx in range(-r, r + 1):
		for dz in range(-r, r + 1):
			var k := Vector2i(ck.x + dx, ck.y + dz)
			var center := Vector3((k.x + 0.5) * chunk_size, 0.0, (k.y + 0.5) * chunk_size)
			if center.distance_squared_to(focus) <= r2:
				out.append(k)
	return out


## Update the active set around `focus`. Returns a dictionary with "loaded" and
## "unloaded" arrays of chunk keys.
func update(focus: Vector3) -> Dictionary:
	var desired: Array = desired_chunks(focus)
	var desired_set: Dictionary = {}
	for k in desired:
		desired_set[k] = true
	var loaded: Array = []
	for k in desired:
		if not _active.has(k):
			_active[k] = true
			loaded.append(k)
	var unloaded: Array = []
	for k in _active.keys():
		if not desired_set.has(k):
			unloaded.append(k)
			_active.erase(k)
	return {"loaded": loaded, "unloaded": unloaded, "active": _active.keys()}


func active_count() -> int:
	return _active.size()


func is_active(key: Vector2i) -> bool:
	return _active.has(key)


## Configure the streaming window so exactly a 3x3 block of chunks (9 chunks)
## loads around the camera/focus — the mega-map streaming profile from the
## design artifact. Uses a square (Chebyshev) ring so the count is exactly 9
## regardless of where the focus sits inside its chunk. Returns self for chaining.
static func configure_for_9_chunks(p_chunk_size: float = 256.0) -> ChunkManager:
	var cm := ChunkManager.new(p_chunk_size, p_chunk_size * 1.5)
	cm.use_square_ring = true
	cm.ring_radius = 1
	return cm


## Convenience: the desired chunk set around `focus` when configured for 9 chunks.
func chunks_around(focus: Vector3) -> Array:
	var ck := chunk_key_of(focus, chunk_size)
	var out: Array = []
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			out.append(Vector2i(ck.x + dx, ck.y + dz))
	return out
