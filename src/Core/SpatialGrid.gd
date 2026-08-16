class_name SpatialGrid
## SpatialGrid — Phase 10b (performance)
##
## Uniform-grid spatial index over unit positions to avoid O(n²) / repeated
## full-list scans for "units within radius" and "nearest enemy" queries. Cells
## are `cell_size` world units; a query touches only the cells overlapping the
## query radius. Position keys are integer cell coords (xz, y ignored).

var cell_size: float
var _cells: Dictionary = {}  # Vector2i(cell_x, cell_z) -> Array[Unit]


func _init(p_cell_size: float = 16.0) -> void:
	cell_size = maxf(p_cell_size, 1.0)


func clear() -> void:
	_cells.clear()


static func _key(pos: Vector3, cell_size: float) -> Vector2i:
	return Vector2i(int(floor(pos.x / cell_size)), int(floor(pos.z / cell_size)))


func insert(unit: Unit) -> void:
	if unit == null:
		return
	var k := _key(unit.global_position, cell_size)
	if not _cells.has(k):
		_cells[k] = []
	_cells[k].append(unit)


func remove(unit: Unit) -> void:
	if unit == null:
		return
	var k := _key(unit.global_position, cell_size)
	var arr: Array = _cells.get(k, [])
	var idx := arr.find(unit)
	if idx >= 0:
		arr.remove_at(idx)
		if arr.is_empty():
			_cells.erase(k)


## Move a unit whose position changed: remove from old cell, insert into new.
func update(unit: Unit, old_pos: Vector3) -> void:
	if unit == null:
		return
	var old_k := _key(old_pos, cell_size)
	var new_k := _key(unit.global_position, cell_size)
	if old_k == new_k:
		return
	var arr: Array = _cells.get(old_k, [])
	var idx := arr.find(unit)
	if idx >= 0:
		arr.remove_at(idx)
		if arr.is_empty():
			_cells.erase(old_k)
	insert(unit)


## All units within `radius` of `pos`.
func query_radius(pos: Vector3, radius: float) -> Array:
	var out: Array = []
	var r := int(ceil(radius / cell_size))
	var ck := _key(pos, cell_size)
	var r2: float = radius * radius
	for dx in range(-r, r + 1):
		for dz in range(-r, r + 1):
			var k := Vector2i(ck.x + dx, ck.y + dz)
			var arr: Array = _cells.get(k, [])
			for u in arr:
				var d2: float = u.global_position.distance_squared_to(pos)
				if d2 <= r2:
					out.append(u)
	return out


func count() -> int:
	var n: int = 0
	for k in _cells:
		n += _cells[k].size()
	return n
