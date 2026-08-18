class_name StreetDetails
extends Node3D
## StreetDetails — Mega World Map city visuals (Phase 10c+)
##
## Spawns the street-level dressing that makes a district read as a real city
## instead of bare ground under floating boxes:
##   - Asphalt ground (PlaneMesh, dark rough PBR-ish material)
##   - White crosswalk decals at district edges (Decal node)
##   - Trees every ~15 m along street lines (low-poly multimesh, Quaternius-style
##     trunk+foliage built procedurally so no download is required)
##   - Parked cars (simple boxes with a PBR-ish car material)
##   - Shop signs (PlaneMesh with a procedural signage shader: MART, BAKERY...)
##
## All assets are procedural / CC0-friendly; the project runs fully offline.

const TREE_SPACING: float = 15.0
const TREE_HEIGHT: float = 6.0

var _asphalt_mat: StandardMaterial3D = null
var _car_mat: StandardMaterial3D = null
var _sign_shader: Shader = null
var _tree_mesh: Mesh = null


func _ready_materials() -> void:
	if _asphalt_mat == null:
		_asphalt_mat = StandardMaterial3D.new()
		_asphalt_mat.albedo_color = Color(0.07, 0.07, 0.08, 1.0)
		_asphalt_mat.roughness = 0.95
		_asphalt_mat.metallic = 0.0
	if _car_mat == null:
		_car_mat = StandardMaterial3D.new()
		_car_mat.albedo_color = Color(0.35, 0.12, 0.12, 1.0)
		_car_mat.roughness = 0.35
		_car_mat.metallic = 0.6
	if _sign_shader == null:
		_sign_shader = _load_shader("res://assets/shaders/shop_sign.gdshader", _default_sign_code())
	if _tree_mesh == null:
		_tree_mesh = _build_tree_mesh()


## Build all street dressing for a district footprint (local xz origin, size w x h).
func build_for_district(footprint: Rect2, district_name: String) -> void:
	_ready_materials()
	_add_asphalt(footprint)
	_add_crosswalks(footprint)
	_add_trees(footprint)
	_add_parked_cars(footprint)
	_add_shop_signs(footprint, district_name)


func _add_asphalt(footprint: Rect2) -> void:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(footprint.size.x, footprint.size.y)
	mi.mesh = pm
	mi.material_override = _asphalt_mat
	mi.position = Vector3(footprint.position.x + footprint.size.x * 0.5, 0.02, footprint.position.y + footprint.size.y * 0.5)
	add_child(mi)


func _add_crosswalks(footprint: Rect2) -> void:
	# Decals at the four district edges marking crosswalks.
	var edges := [
		{p = Vector3(footprint.position.x, 0.05, footprint.position.y + footprint.size.y * 0.5), r = Vector3(0, 90, 0)},
		{p = Vector3(footprint.position.x + footprint.size.x, 0.05, footprint.position.y + footprint.size.y * 0.5), r = Vector3(0, 90, 0)},
		{p = Vector3(footprint.position.x + footprint.size.x * 0.5, 0.05, footprint.position.y), r = Vector3(0, 0, 0)},
		{p = Vector3(footprint.position.x + footprint.size.x * 0.5, 0.05, footprint.position.y + footprint.size.y), r = Vector3(0, 0, 0)},
	]
	var wmat := StandardMaterial3D.new()
	wmat.albedo_color = Color(0.9, 0.9, 0.9, 1.0)
	wmat.roughness = 0.9
	for e in edges:
		var decal := Decal.new()
		decal.size = Vector3(12.0, 4.0, 3.0)
		decal.position = e.p
		decal.rotation_degrees = Vector3(-90, 0, 0)
		# A simple stripe look via albedo texture is ideal; fall back to a pale decal.
		decal.texture_albedo = _stripe_texture()
		decal.modulate = Color(1, 1, 1, 0.8)
		add_child(decal)


func _add_trees(footprint: Rect2) -> void:
	# Tree lines along the two long avenues.
	var mmi := MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.mesh = _tree_mesh
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var pts := _tree_line_points(footprint)
	mm.instance_count = pts.size()
	for i in pts.size():
		var t := Transform3D(Basis().scaled(Vector3(1.0, 1.0, 1.0)), pts[i])
		mm.set_instance_transform(i, t)
	mm.instance_count = pts.size()
	mmi.multimesh = mm
	add_child(mmi)


func _tree_line_points(footprint: Rect2) -> Array:
	var out: Array = []
	var x0: float = footprint.position.x
	var z0: float = footprint.position.y
	var w: float = footprint.size.x
	var h: float = footprint.size.y
	# Two rows along z, offset from the district centre.
	for zfrac in [0.25, 0.75]:
		var z: float = z0 + h * zfrac
		var x: float = x0 + TREE_SPACING * 0.5
		while x < x0 + w:
			out.append(Vector3(x, 0.0, z))
			x += TREE_SPACING
	return out


func _add_parked_cars(footprint: Rect2) -> void:
	var mmi := MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	var box := BoxMesh.new()
	box.size = Vector3(4.5, 1.6, 2.0)
	mm.mesh = box
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var pts := _car_points(footprint)
	mm.instance_count = pts.size()
	for i in pts.size():
		var t := Transform3D(Basis(Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1)).scaled(Vector3(1,1,1)), pts[i])
		mm.set_instance_transform(i, t)
	mm.instance_count = pts.size()
	mmi.multimesh = mm
	mmi.material_override = _car_mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(mmi)


func _car_points(footprint: Rect2) -> Array:
	var out: Array = []
	var x0: float = footprint.position.x
	var z0: float = footprint.position.y
	var w: float = footprint.size.x
	var h: float = footprint.size.y
	# Curb-side parking along one edge.
	var z: float = z0 + h * 0.12
	var x: float = x0 + 6.0
	while x < x0 + w - 6.0:
		out.append(Vector3(x, 0.8, z))
		x += 6.5
	return out


func _add_shop_signs(footprint: Rect2, district_name: String) -> void:
	# A few shop signs at street level on the main avenue.
	var signs := ["MART 24", "BAKERY", "PHARMACY", "CAFÉ", "HOTEL"]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(district_name)
	var count: int = mini(signs.size(), 3)
	var placed: int = 0
	var idx: int = 0
	var z: float = footprint.position.y + footprint.size.y * 0.5
	while placed < count and idx < signs.size() * 2:
		var s: String = signs[idx % signs.size()]
		var mi := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(4.0, 1.2)
		mi.mesh = pm
		var x: float = footprint.position.x + 8.0 + float(placed) * 22.0
		mi.position = Vector3(x, 4.0, z)
		var mat := ShaderMaterial.new()
		mat.shader = _sign_shader
		mat.set_shader_parameter("text_idx", float(placed))
		mi.material_override = mat
		add_child(mi)
		placed += 1
		idx += 1


func _build_tree_mesh() -> Mesh:
	# A simple low-poly tree: a brown trunk cylinder + a green foliage cone.
	var st := SurfaceTool.new()
	var mesh := ArrayMesh.new()
	# Trunk (cylinder approximation via 6 sides).
	_append_cylinder(st, 0.25, 0.25, TREE_HEIGHT * 0.3, Vector3(0, TREE_HEIGHT * 0.15, 0), Color(0.35, 0.22, 0.12))
	st.index()
	var trunk_mat := StandardMaterial3D.new()
	trunk_mat.albedo_color = Color(0.35, 0.22, 0.12, 1.0)
	trunk_mat.roughness = 0.9
	st.set_material(trunk_mat)
	st.commit(mesh)
	# Foliage (cone).
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_append_cone(st, 2.5, TREE_HEIGHT * 0.7, Vector3(0, TREE_HEIGHT * 0.65, 0))
	st.index()
	var leaf_mat := StandardMaterial3D.new()
	leaf_mat.albedo_color = Color(0.16, 0.36, 0.18, 1.0)
	leaf_mat.roughness = 0.85
	st.set_material(leaf_mat)
	st.commit(mesh)
	return mesh


func _append_cylinder(st: SurfaceTool, r_top: float, r_bot: float, h: float, centre: Vector3, _c: Color) -> void:
	var sides: int = 6
	var y0: float = centre.y - h * 0.5
	var y1: float = centre.y + h * 0.5
	for i in sides:
		var a0: float = TAU * float(i) / float(sides)
		var a1: float = TAU * float(float(i) + 1.0) / float(sides)
		var v0 := Vector3(cos(a0) * r_bot, y0, sin(a0) * r_bot) + Vector3(centre.x, 0, centre.z)
		var v1 := Vector3(cos(a1) * r_bot, y0, sin(a1) * r_bot) + Vector3(centre.x, 0, centre.z)
		var v2 := Vector3(cos(a1) * r_top, y1, sin(a1) * r_top) + Vector3(centre.x, 0, centre.z)
		var v3 := Vector3(cos(a0) * r_top, y1, sin(a0) * r_top) + Vector3(centre.x, 0, centre.z)
		var n := (v0 + v1 + v2 + v3) * 0.25 - Vector3(centre.x, centre.y, centre.z)
		st.set_normal(n.normalized())
		st.add_vertex(v0)
		st.add_vertex(v1)
		st.add_vertex(v2)
		st.set_normal(n.normalized())
		st.add_vertex(v0)
		st.add_vertex(v2)
		st.add_vertex(v3)


func _append_cone(st: SurfaceTool, r: float, h: float, centre: Vector3) -> void:
	var sides: int = 7
	var apex := centre + Vector3(0, h * 0.5, 0)
	var base_y: float = centre.y - h * 0.5
	for i in sides:
		var a0: float = TAU * float(i) / float(sides)
		var a1: float = TAU * float(float(i) + 1.0) / float(sides)
		var v0 := Vector3(cos(a0) * r, base_y, sin(a0) * r) + Vector3(centre.x, 0, centre.z)
		var v1 := Vector3(cos(a1) * r, base_y, sin(a1) * r) + Vector3(centre.x, 0, centre.z)
		var n := (v0 + v1) * 0.5 - Vector3(centre.x, 0, centre.z)
		st.set_normal(n.normalized())
		st.add_vertex(v0)
		st.add_vertex(v1)
		st.add_vertex(apex)


func _stripe_texture() -> Texture2D:
	# A small procedural crosswalk stripe image (no external asset).
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in range(0, 16, 4):
		for x in 16:
			img.set_pixel(x, y, Color(0.95, 0.95, 0.95, 1.0))
			img.set_pixel(x, y + 1, Color(0.95, 0.95, 0.95, 1.0))
	var tex := ImageTexture.create_from_image(img)
	return tex


func _load_shader(path: String, fallback_code: String) -> Shader:
	if ResourceLoader.exists(path):
		var s: Resource = load(path)
		if s is Shader:
			return s
	var s := Shader.new()
	s.code = fallback_code
	return s


func _default_sign_code() -> String:
	return """shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled;
uniform float text_idx = 0.0;
void fragment(){
	ALBEDO = vec3(0.85, 0.75, 0.25);
	EMISSION = vec3(0.9, 0.7, 0.2) * 0.6;
	ROUGHNESS = 0.4;
}
"""
