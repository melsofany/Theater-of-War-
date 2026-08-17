extends Node3D
## Terrain
##
## Renders a MapData heightfield as an ArrayMesh and gives it a collision body
## so units/physics rest on the ground. Also draws feature overlays (water tint
## and roads) as separate coloured meshes. Built at runtime from MapData so the
## world can be regenerated/seeded without editor baking.

class_name Terrain

@export var map_data: MapData

## Streaming (10c+): when true, ground is built as per-chunk meshes loaded/
## unloaded around `stream_focus` via a ChunkManager, instead of one giant
## mesh. Water/roads stay as whole-scene overlays (cheap, flat). Default false
## preserves the original single-mesh build.
@export var streaming: bool = false
@export var chunk_size: float = 64.0
@export var stream_view_radius: float = 160.0
## World position to stream around. Set each frame (e.g. to the camera or the
## player's average unit position); defaults to the map centre.
var stream_focus: Vector3 = Vector3.ZERO
var _chunk_manager: ChunkManager = null
var _chunk_meshes: Dictionary = {}  # Vector2i -> MeshInstance3D
var _ground_mat: StandardMaterial3D = null

var _mesh_instance: MeshInstance3D
var _body: StaticBody3D
var _water_mesh: MeshInstance3D
var _road_mesh: MeshInstance3D


func _ready() -> void:
	if not map_data:
		map_data = TerrainGenerator.new().generate()
	# Default focus to the map centre so a fresh scene streams around the middle.
	stream_focus = map_data.grid_to_world(map_data.size / 2, map_data.size / 2)
	_build_terrain()


func set_map_data(md: MapData) -> void:
	map_data = md
	if is_inside_tree():
		_build_terrain()


func _build_terrain() -> void:
	for c in get_children():
		c.queue_free()
	_chunk_meshes.clear()
	_chunk_manager = null
	_ground_mat = StandardMaterial3D.new()
	_ground_mat.vertex_color_use_as_albedo = true
	_ground_mat.roughness = 0.95
	_ground_mat.metalness = 0.0
	if streaming:
		_build_streaming_ground()
	else:
		_build_ground()
	_build_water()
	_build_roads()


func _build_streaming_ground() -> void:
	_chunk_manager = ChunkManager.new(chunk_size, stream_view_radius)
	# Build the initial active set around the default focus.
	_stream_update()


## Build the ground mesh for a single chunk (the grid cells whose world xz fall
## in `[key.x, key.x+1)*chunk_size` etc.) and register its MeshInstance3D.
func _build_chunk_mesh(key: Vector2i) -> MeshInstance3D:
	var md := map_data
	var cell := md.cell
	# World-space bounds for this chunk.
	var x0 := float(key.x) * chunk_size
	var z0 := float(key.y) * chunk_size
	# Map world -> grid indices inclusive.
	var g0 := md.world_to_grid(x0, z0)
	var g1 := md.world_to_grid(x0 + chunk_size, z0 + chunk_size)
	# Clamp to map; if entirely out of bounds, nothing to draw.
	var gx_min := clampi(g0.x, 0, md.size - 1)
	var gz_min := clampi(g0.y, 0, md.size - 1)
	var gx_max := clampi(g1.x, 0, md.size - 1)
	var gz_max := clampi(g1.y, 0, md.size - 1)
	if gx_max <= gx_min or gz_max <= gz_min:
		return null
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var local_origin := Vector3(x0, 0.0, z0)
	for gz in range(gz_min, gz_max + 1):
		for gx in range(gx_min, gx_max + 1):
			st.set_uv(Vector2(float(gx) / float(md.size), float(gz) / float(md.size)))
			var h := md.height_at_grid(gx, gz)
			st.set_color(_elevation_color(h, md))
			# Vertices stored in chunk-local space so the chunk can be placed at
			# (x0, 0, z0) and share one material instance.
			var w := md.grid_to_world(gx, gz)
			st.add_vertex(w - local_origin)
	# Two triangles per cell, indexed within this chunk's local vertex grid.
	var w := gx_max - gx_min + 1
	for gz in range(gz_max - gz_min):
		for gx in range(gx_max - gx_min):
			var a: int = gz * w + gx
			var b: int = gz * w + gx + 1
			var c: int = (gz + 1) * w + gx
			var d: int = (gz + 1) * w + gx + 1
			st.add_index(a)
			st.add_index(c)
			st.add_index(b)
			st.add_index(b)
			st.add_index(c)
			st.add_index(d)
	st.index()
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.cast_shadow = 1
	mi.material_override = _ground_mat
	mi.position = local_origin
	return mi


## Load/unload chunk meshes to match the ChunkManager's desired set around the
## current `stream_focus`. Public so tests/external code can drive a step.
func _stream_update() -> Dictionary:
	if _chunk_manager == null:
		return {"loaded": [], "unloaded": [], "active": []}
	var diff: Dictionary = _chunk_manager.update(stream_focus)
	for key in diff.get("loaded", []):
		if not _chunk_meshes.has(key):
			var mi := _build_chunk_mesh(key)
			if mi != null:
				add_child(mi)
				_chunk_meshes[key] = mi
	for key in diff.get("unloaded", []):
		var mi = _chunk_meshes.get(key)
		if mi != null:
			mi.queue_free()
			_chunk_meshes.erase(key)
	return {"loaded": diff.get("loaded", []), "unloaded": diff.get("unloaded", []),
			"active": _chunk_meshes.keys()}


func active_chunk_count() -> int:
	return _chunk_meshes.size()


func is_chunk_loaded(key: Vector2i) -> bool:
	return _chunk_meshes.has(key)


func _process(_delta: float) -> void:
	if streaming and _chunk_manager != null:
		_stream_update()


func _build_ground() -> void:
	var md := map_data
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for gz in md.size:
		for gx in md.size:
			st.set_uv(Vector2(float(gx) / float(md.size), float(gz) / float(md.size)))
			var h := md.height_at_grid(gx, gz)
			# Coloured by elevation: low=green, plateau=tan, mountain=grey, peak=white.
			var c := _elevation_color(h, md)
			st.set_color(c)
			st.add_vertex(md.grid_to_world(gx, gz))
	# Two triangles per cell, indices wound for +Y normals.
	var s := md.size
	for gz in s - 1:
		for gx in s - 1:
			var a: int = gz * s + gx
			var b: int = gz * s + gx + 1
			var c: int = (gz + 1) * s + gx
			var d: int = (gz + 1) * s + gx + 1
			st.add_index(a)
			st.add_index(c)
			st.add_index(b)
			st.add_index(b)
			st.add_index(c)
			st.add_index(d)
	st.index()
	st.generate_normals()

	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.mesh = st.commit()
	_mesh_instance.cast_shadow = 1  # GeometryInstance3D.ShadowCastingSetting.ON
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = false
	mat.albedo_color = Color.WHITE
	mat.albedo_texture = _load_texture("res://assets/textures/terrain/grass.png")
	mat.normal_enabled = true
	mat.normal_texture = _load_texture("res://assets/textures/terrain/grass_normal.png")
	mat.roughness_texture = _load_texture("res://assets/textures/terrain/grass_roughness.png")

	mat.roughness = 0.88
	mat.metallic = 0.0
	mat.uv1_scale = Vector3(7.0, 7.0, 7.0)
	_mesh_instance.material_override = mat
	add_child(_mesh_instance)

	# Collision via trimesh.
	_body = StaticBody3D.new()
	_body.collision_layer = 4
	_body.collision_mask = 1
	var col := ConcavePolygonShape3D.new()
	col.set_faces(_mesh_instance.mesh.get_faces())
	var cs := CollisionShape3D.new()
	cs.shape = col
	_body.add_child(cs)
	add_child(_body)


func _build_water() -> void:
	var md := map_data
	if md.waters.is_empty():
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for loop in md.waters:
		var poly := loop as PackedVector2Array
		if poly.size() < 3:
			continue
		var indices := Geometry2D.triangulate_polygon(poly)
		for i in indices:
			var p := poly[i]
			st.add_vertex(Vector3(p.x, 0.05, p.y))
	st.index()
	st.generate_normals()
	_water_mesh = MeshInstance3D.new()
	_water_mesh.mesh = st.commit()
	_water_mesh.cast_shadow = 0
	var wmat := StandardMaterial3D.new()
	wmat.albedo_texture = _load_texture("res://assets/textures/terrain/water.png")
	wmat.normal_enabled = true
	wmat.normal_texture = _load_texture("res://assets/textures/terrain/water_normal.png")
	wmat.roughness_texture = _load_texture("res://assets/textures/terrain/water_roughness.png")

	wmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wmat.albedo_color = Color(0.28, 0.55, 0.82, 0.82)
	wmat.roughness = 0.18
	wmat.metallic = 0.12
	wmat.uv1_scale = Vector3(4.0, 4.0, 4.0)
	_water_mesh.material_override = wmat
	add_child(_water_mesh)


func _build_roads() -> void:
	var md := map_data
	if md.roads.is_empty():
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	const W := 1.2
	for line in md.roads:
		var pts := line as PackedVector2Array
		for i in pts.size() - 1:
			var a := pts[i]
			var b := pts[i + 1]
			var d := (b - a).normalized()
			var n := Vector2(-d.y, d.x) * W
			var ah := md.height_at(a.x, a.y) + 0.1
			var bh := md.height_at(b.x, b.y) + 0.1
			var v0 := Vector3(a.x + n.x, ah, a.y + n.y)
			var v1 := Vector3(a.x - n.x, ah, a.y - n.y)
			var v2 := Vector3(b.x + n.x, bh, b.y + n.y)
			var v3 := Vector3(b.x - n.x, bh, b.y - n.y)
			st.add_vertex(v0)
			st.add_vertex(v1)
			st.add_vertex(v2)
			st.add_vertex(v2)
			st.add_vertex(v1)
			st.add_vertex(v3)
	st.index()
	st.generate_normals()
	_road_mesh = MeshInstance3D.new()
	_road_mesh.mesh = st.commit()
	_road_mesh.cast_shadow = 0
	var rmat := StandardMaterial3D.new()
	rmat.albedo_texture = _load_texture("res://assets/textures/terrain/road.png")
	rmat.normal_enabled = true
	rmat.normal_texture = _load_texture("res://assets/textures/terrain/road_normal.png")
	rmat.roughness_texture = _load_texture("res://assets/textures/terrain/road_roughness.png")
	rmat.albedo_color = Color(0.72, 0.70, 0.66)
	rmat.roughness = 0.92
	rmat.uv1_scale = Vector3(5.0, 5.0, 5.0)
	_road_mesh.material_override = rmat
	add_child(_road_mesh)


func _load_texture(path: String) -> Texture2D:
	var image := Image.load_from_file(ProjectSettings.globalize_path(path))
	if image == null or image.is_empty():
		return null
	return ImageTexture.create_from_image(image)


func _elevation_color(h: float, md: MapData) -> Color:
	if h >= md.mountain_height:
		var t := clampf((h - md.mountain_height) / 6.0, 0.0, 1.0)
		return Color(0.28, 0.31, 0.32).lerp(Color(0.62, 0.65, 0.64), t)
	if h >= md.plateau_height:
		return Color(0.48, 0.42, 0.28)
	return Color(0.16, 0.28, 0.12).lerp(Color(0.38, 0.44, 0.18), clampf(h / 8.0, 0.0, 1.0))
