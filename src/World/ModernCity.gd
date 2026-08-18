class_name ModernCity
extends Node3D
## ModernCity — Mega World Map (Phase 10c+)
##
## A modern glass city on the mega world map: 1500 x 1500 m, 4-6 districts, glass
## facades with reflections, wide streets and shop decals. Owned by ModernCity at
## runtime but kept as a scene-graph node so towers (MultiMesh), streets and
## civilian spawn markers can live in it.
##
## A city can be split between armies: each district holds its own control_faction,
## so the north half can be one army and the south half the enemy. The aggregate
## owner (for Economy income) is the faction holding the majority of districts.

const CITY_EXTENT: float = 1500.0

@export var city_name: String = "City"
var districts: Array[CityDistrict] = []
## Glass-tower multimesh shared across the city (performance: one draw call).
var _towers: MultiMeshInstance3D = null


func _ready() -> void:
	for c in get_children():
		if c is CityDistrict:
			districts.append(c)


func add_district(d: CityDistrict) -> void:
	add_child(d)
	districts.append(d)


func get_district(name: String) -> CityDistrict:
	for d in districts:
		if d.district_name == name:
			return d
	return null


## Faction holding the majority of districts (the city's aggregate owner). Null if
## no single faction holds a majority (the city is contested / split).
func majority_owner() -> Faction:
	var tally: Dictionary = {}
	for d in districts:
		if d.control_faction == null:
			continue
		tally[d.control_faction.name] = tally.get(d.control_faction.name, 0) + 1
	var best: Faction = null
	var best_n: int = 0
	for d in districts:
		if d.control_faction == null:
			continue
		var n: int = tally[d.control_faction.name]
		if n > best_n:
			best_n = n
			best = d.control_faction
	# Majority means strictly more than half the districts.
	if best_n > districts.size() / 2:
		return best
	return null


## True if two different factions hold districts of this city (it is "split").
func is_split() -> bool:
	var seen: Dictionary = {}
	for d in districts:
		if d.control_faction == null:
			continue
		seen[d.control_faction.name] = true
	return seen.size() >= 2


## Total resident civilians across all districts.
func total_civilian_population() -> float:
	var p: float = 0.0
	for d in districts:
		p += d.civilian_population
	return p


## A district whose footprint contains the world point, or null.
func district_at(wx: float, wz: float) -> CityDistrict:
	for d in districts:
		if d.contains_point(wx, wz):
			return d
	return null


func attach_towers(mmi: MultiMeshInstance3D) -> void:
	_towers = mmi
	if _towers and not _towers.is_inside_tree():
		add_child(_towers)


func get_towers() -> MultiMeshInstance3D:
	return _towers


## Build the full visual dressing (street details + contested barricades) for
## every district. Opt-in: the pure-data path used by tests does not call this, so
## GUT stays green; the live game scene calls this once the city is placed.
func build_visuals() -> void:
	for d in districts:
		var street := StreetDetails.new()
		add_child(street)
		street.build_for_district(d.footprint, d.district_name)
	_update_contested_barricades()


## Spawn/remove barricades (sandbags, concrete barriers, checkpoints) depending
## on whether the city is currently split between factions. Called by
## `build_visuals` and re-callable as the tactical picture changes.
func _update_contested_barricades() -> void:
	# Remove any stale barricade layer first.
	for c in get_children():
		if c is Node3D and c.name == "Barricades":
			c.queue_free()
	if not is_split():
		return
	var layer := Node3D.new()
	layer.name = "Barricades"
	add_child(layer)
	for d in districts:
		if d.control_faction == null:
			continue
		_place_district_barricades(layer, d)


## Sandbag + concrete barrier line + checkpoint at the boundary between two
## districts held by different factions (urban-warfare flavour for split cities).
func _place_district_barricades(layer: Node3D, d: CityDistrict) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(d.district_name)
	var sand := _barrier_mesh(true)
	var concrete := _barrier_mesh(false)
	var mmi_sand := _single_mesh_multimesh(sand, 8)
	var mmi_conc := _single_mesh_multimesh(concrete, 4)
	var x0: float = d.footprint.position.x
	var z0: float = d.footprint.position.y
	var w: float = d.footprint.size.x
	for k in 8:
		var x: float = x0 + rng.randf() * w
		var z: float = z0 + (0.0 if k % 2 == 0 else d.footprint.size.y)
		mmi_sand.multimesh.set_instance_transform(k, Transform3D(Basis(), Vector3(x, 0.4, z)))
	for k in 4:
		var x: float = x0 + rng.randf() * w
		var z: float = z0 + (0.0 if k % 2 == 0 else d.footprint.size.y)
		mmi_conc.multimesh.set_instance_transform(k, Transform3D(Basis().scaled(Vector3(1.5, 1.2, 0.8)), Vector3(x, 0.6, z)))
	layer.add_child(mmi_sand)
	layer.add_child(mmi_conc)


func _barrier_mesh(sandbag: bool) -> Mesh:
	var mesh := ArrayMesh.new()
	var st := SurfaceTool.new()
	if sandbag:
		_append_box(st, Vector3(1.5, 0.8, 0.6), Vector3(0, 0.4, 0))
	else:
		_append_box(st, Vector3(2.0, 1.2, 0.6), Vector3(0, 0.6, 0))
	st.index()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.45, 0.30) if sandbag else Color(0.62, 0.62, 0.60)
	mat.roughness = 0.9
	st.set_material(mat)
	st.commit(mesh)
	return mesh


func _single_mesh_multimesh(mesh: Mesh, count: int) -> MultiMeshInstance3D:
	var mmi := MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.mesh = mesh
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.instance_count = count
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return mmi


func _append_box(st: SurfaceTool, size: Vector3, origin: Vector3) -> void:
	var hx: float = size.x * 0.5
	var hy: float = size.y * 0.5
	var hz: float = size.z * 0.5
	var c := origin
	var p := [
		c + Vector3(-hx, -hy, -hz), c + Vector3(hx, -hy, -hz),
		c + Vector3(hx, -hy, hz), c + Vector3(-hx, -hy, hz),
		c + Vector3(-hx, hy, -hz), c + Vector3(hx, hy, -hz),
		c + Vector3(hx, hy, hz), c + Vector3(-hx, hy, hz),
	]
	var faces := [
		[7, 6, 5, 4], Vector3(0, 1, 0),
		[4, 5, 1, 0], Vector3(0, 0, -1),
		[2, 6, 7, 3], Vector3(0, 0, 1),
		[3, 7, 4, 0], Vector3(-1, 0, 0),
		[1, 5, 6, 2], Vector3(1, 0, 0),
	]
	var uv_quad := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
	for i in range(0, faces.size(), 2):
		var idx: Array = faces[i]
		var n: Vector3 = faces[i + 1]
		st.set_normal(n)
		st.set_uv(uv_quad[0])
		st.add_vertex(p[idx[0]])
		st.set_normal(n)
		st.set_uv(uv_quad[1])
		st.add_vertex(p[idx[1]])
		st.set_normal(n)
		st.set_uv(uv_quad[2])
		st.add_vertex(p[idx[2]])
		st.set_normal(n)
		st.set_uv(uv_quad[0])
		st.add_vertex(p[idx[0]])
		st.set_normal(n)
		st.set_uv(uv_quad[2])
		st.add_vertex(p[idx[2]])
		st.set_normal(n)
		st.set_uv(uv_quad[3])
		st.add_vertex(p[idx[3]])
