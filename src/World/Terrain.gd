extends Node3D
## Terrain
##
## Renders a MapData heightfield as an ArrayMesh and gives it a collision body
## so units/physics rest on the ground. Also draws feature overlays (water tint
## and roads) as separate coloured meshes. Built at runtime from MapData so the
## world can be regenerated/seeded without editor baking.

class_name Terrain

@export var map_data: MapData

var _mesh_instance: MeshInstance3D
var _body: StaticBody3D
var _water_mesh: MeshInstance3D
var _road_mesh: MeshInstance3D


func _ready() -> void:
	if not map_data:
		map_data = TerrainGenerator.new().generate()
	_build_terrain()


func set_map_data(md: MapData) -> void:
	map_data = md
	if is_inside_tree():
		_build_terrain()


func _build_terrain() -> void:
	for c in get_children():
		c.queue_free()
	_build_ground()
	_build_water()
	_build_roads()


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
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.95
	mat.metalness = 0.0
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
	wmat.albedo_color = Color(0.15, 0.35, 0.7, 0.75)
	wmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wmat.roughness = 0.2
	wmat.metalness = 0.1
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
	rmat.albedo_color = Color(0.5, 0.45, 0.4)
	rmat.roughness = 0.9
	_road_mesh.material_override = rmat
	add_child(_road_mesh)


func _elevation_color(h: float, md: MapData) -> Color:
	if h >= md.mountain_height:
		var t := clampf((h - md.mountain_height) / 6.0, 0.0, 1.0)
		return Color(0.7, 0.7, 0.72).lerp(Color(1, 1, 1), t)
	if h >= md.plateau_height:
		return Color(0.6, 0.55, 0.4)
	return Color(0.25, 0.45, 0.2).lerp(Color(0.4, 0.5, 0.25), clampf(h / 8.0, 0.0, 1.0))
