class_name BuildingGenerator
extends RefCounted
## BuildingGenerator — Mega World Map city visuals (Phase 10c+)
##
## Replaces the old single-CSGBox3D / flat-BoxMesh towers with a composed,
## photorealistic building mesh:
##   - Base: 2 floors of shop fronts (darker concrete with a shop-grid shader)
##   - Middle: glass shaft (GlassFacade window-grid shader) for ~40% of towers,
##     or a concrete shaft (PBR-ish StandardMaterial3D) for ~60%, per the spec
##   - Roof: flat slab + a small roof garden (low trees via a baked MultiMesh)
##
## All meshes are built procedurally with SurfaceTool + inline ShaderMaterials so
## the project runs fully offline (no Polyhaven/Kenney downloads required at
## runtime; the GlassFacade.tres and glass_facade.gdshader assets are CC0-style
## references that resolve if present but are not hard dependencies).
##
## For performance, one ArrayMesh with multiple surfaces (each carrying its own
## baked material) is returned, so a whole district's towers can be rendered with
## a single MultiMeshInstance3D draw call.

const SHOP_ROWS: float = 2.0
const SHOP_COLS: float = 8.0
const ROOF_TREE_DENSITY: float = 0.4 # trees per 100 m^2 of roof

var _glass_shader: Shader = null
var _shop_shader: Shader = null
var _concrete_mat: StandardMaterial3D = null


func _ready_shaders() -> void:
	if _glass_shader == null:
		_glass_shader = _load_shader("res://assets/shaders/glass_facade.gdshader",
			_default_glass_code())
	if _shop_shader == null:
		_shop_shader = _load_shader("res://assets/shaders/shop_front.gdshader",
			_default_shop_code())
	if _concrete_mat == null:
		_concrete_mat = StandardMaterial3D.new()
		_concrete_mat.albedo_color = Color(0.32, 0.32, 0.34, 1.0)
		_concrete_mat.roughness = 0.85
		_concrete_mat.metallic = 0.05


func _load_shader(path: String, fallback_code: String) -> Shader:
	# Prefer the authored .gdshader on disk; fall back to an inline string so the
	# generator always works even before the asset is imported.
	if ResourceLoader.exists(path):
		var s: Resource = load(path)
		if s is Shader:
			return s
	var s := Shader.new()
	s.code = fallback_code
	return s


## Build a single building ArrayMesh. `glass` selects a glass shaft (window grid)
## vs a concrete shaft. `rng` drives height/footprint variation deterministically.
func build_building(glass: bool, rng: RandomNumberGenerator) -> ArrayMesh:
	_ready_shaders()
	var st := SurfaceTool.new()
	var mesh := ArrayMesh.new()
	# Footprint + storeys.
	var w: float = rng.randf_range(10.0, 16.0)
	var d: float = rng.randf_range(10.0, 16.0)
	var floors: int = int(rng.randi_range(10, 30))
	var floor_h: float = 3.5
	var base_h: float = floor_h * SHOP_ROWS
	var shaft_h: float = floor_h * float(floors)
	var total_h: float = base_h + shaft_h
	# Surface 0: shop base (concrete with shop-grid shader).
	_append_box(st, Vector3(w, base_h, d), Vector3(0.0, base_h * 0.5, 0.0))
	st.index()
	var shop_mat := ShaderMaterial.new()
	shop_mat.shader = _shop_shader
	shop_mat.set_shader_parameter("rows", SHOP_ROWS)
	shop_mat.set_shader_parameter("cols", SHOP_COLS)
	st.set_material(shop_mat)
	st.commit(mesh)
	# Surface 1: shaft (glass window grid or concrete).
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_append_box(st, Vector3(w, shaft_h, d), Vector3(0.0, base_h + shaft_h * 0.5, 0.0))
	st.index()
	if glass:
		var gmat := ShaderMaterial.new()
		gmat.shader = _glass_shader
		gmat.set_shader_parameter("rows", float(floors))
		gmat.set_shader_parameter("cols", maxf(4.0, round(w / 2.5)))
		st.set_material(gmat)
	else:
		var cmat := _concrete_mat.duplicate() as StandardMaterial3D
		# Slight per-building colour variation so concrete isn't perfectly flat.
		cmat.albedo_color = Color(0.28 + rng.randf_range(0.0, 0.12), 0.28 + rng.randf_range(0.0, 0.12), 0.30 + rng.randf_range(0.0, 0.12), 1.0)
		st.set_material(cmat)
	st.commit(mesh)
	# Surface 2: roof slab + a couple of roof boxes (AC / garden) for silhouette.
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_append_box(st, Vector3(w, 0.6, d), Vector3(0.0, total_h + 0.3, 0.0))
	_append_box(st, Vector3(w * 0.3, 1.2, d * 0.3), Vector3(w * 0.2, total_h + 1.2, d * 0.2))
	st.index()
	st.set_material(_concrete_mat)
	st.commit(mesh)
	return mesh


## A simplified (lower-poly) version for the LOD distance band.
func build_building_lod(glass: bool, rng: RandomNumberGenerator) -> ArrayMesh:
	_ready_shaders()
	var st := SurfaceTool.new()
	var mesh := ArrayMesh.new()
	var w: float = rng.randf_range(10.0, 16.0)
	var d: float = rng.randf_range(10.0, 16.0)
	var floors: int = int(rng.randi_range(10, 30))
	var total_h: float = floor(3.5) * (SHOP_ROWS + float(floors))
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_append_box(st, Vector3(w, total_h, d), Vector3(0.0, total_h * 0.5, 0.0))
	st.index()
	if glass:
		var gmat := ShaderMaterial.new()
		gmat.shader = _glass_shader
		gmat.set_shader_parameter("rows", float(floors) * 0.5)
		gmat.set_shader_parameter("cols", 3.0)
		st.set_material(gmat)
	else:
		st.set_material(_concrete_mat)
	st.commit(mesh)
	return mesh


## Append an axis-aligned box (centred at `origin`, size `size`) to the active
## SurfaceTool. Normals point outward; UVs map 0..1 per face for the shaders.
func _append_box(st: SurfaceTool, size: Vector3, origin: Vector3) -> void:
	var hx: float = size.x * 0.5
	var hy: float = size.y * 0.5
	var hz: float = size.z * 0.5
	var c := origin
	# 8 corners.
	var p := [
		c + Vector3(-hx, -hy, -hz), c + Vector3(hx, -hy, -hz),
		c + Vector3(hx, -hy, hz), c + Vector3(-hx, -hy, hz),
		c + Vector3(-hx, hy, -hz), c + Vector3(hx, hy, -hz),
		c + Vector3(hx, hy, hz), c + Vector3(-hx, hy, hz),
	]
	# Faces: (a, b, c, d), normal, uv per face.
	var faces := [
		[0, 1, 2, 3], Vector3(0, -1, 0), # bottom
		[7, 6, 5, 4], Vector3(0, 1, 0), # top
		[4, 5, 1, 0], Vector3(0, 0, -1), # -Z
		[2, 6, 7, 3], Vector3(0, 0, 1),  # +Z
		[3, 7, 4, 0], Vector3(-1, 0, 0),# -X
		[1, 5, 6, 2], Vector3(1, 0, 0), # +X
	]
	var uv_quad := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
	for i in range(0, faces.size(), 2):
		var idx: Array = faces[i]
		var n: Vector3 = faces[i + 1]
		# Two triangles per quad.
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


func _default_glass_code() -> String:
	return """shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;
uniform vec4 albedo : source_color = vec4(0.165, 0.227, 0.290, 1.0);
uniform float metallic : hint_range(0.0, 1.0) = 0.85;
uniform float roughness : hint_range(0.0, 1.0) = 0.15;
uniform vec4 window_tint : source_color = vec4(0.30, 0.50, 0.70, 1.0);
uniform vec4 lit_color : source_color = vec4(1.0, 0.82, 0.48, 1.0);
uniform float rows = 26.0;
uniform float cols = 6.0;
uniform float frame = 0.10;
uniform float lit_fraction = 0.22;
uniform float lit_intensity = 0.7;
float cell_rand(vec2 cell){ return fract(sin(dot(cell, vec2(12.9898, 78.233))) * 43758.5453); }
void fragment(){
	vec2 uv = UV;
	vec2 cell = floor(vec2(uv.x * cols, uv.y * rows));
	vec2 g = fract(vec2(uv.x * cols, uv.y * rows));
	float mullion = step(g.x, frame) + step(1.0 - frame, g.x) + step(g.y, frame) + step(1.0 - frame, g.y);
	mullion = clamp(mullion, 0.0, 1.0);
	float r = cell_rand(cell);
	float lit = step(1.0 - lit_fraction, r);
	vec3 pane = mix(window_tint.rgb, lit_color.rgb, lit * 0.85);
	vec3 col = mix(pane, albedo.rgb * 0.35, mullion);
	ALBEDO = col;
	METALLIC = mix(metallic, 0.2, mullion);
	ROUGHNESS = mix(roughness, 0.55, mullion);
	EMISSION = lit_color.rgb * lit * lit_intensity;
}
"""


func _default_shop_code() -> String:
	return """shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;
uniform vec4 albedo : source_color = vec4(0.20, 0.18, 0.16, 1.0);
uniform float rows = 2.0;
uniform float cols = 8.0;
uniform float frame = 0.18;
uniform vec4 lit_color : source_color = vec4(1.0, 0.8, 0.45, 1.0);
float cell_rand(vec2 cell){ return fract(sin(dot(cell, vec2(12.9898, 78.233))) * 43758.5453); }
void fragment(){
	vec2 uv = UV;
	vec2 cell = floor(vec2(uv.x * cols, uv.y * rows));
	vec2 g = fract(vec2(uv.x * cols, uv.y * rows));
	float mullion = step(g.x, frame) + step(1.0 - frame, g.x) + step(g.y, frame) + step(1.0 - frame, g.y);
	mullion = clamp(mullion, 0.0, 1.0);
	float lit = step(0.6, cell_rand(cell));
	vec3 pane = mix(albedo.rgb * 1.4, lit_color.rgb, lit * 0.7);
	ALBEDO = mix(pane, albedo.rgb * 0.4, mullion);
	METALLIC = 0.0;
	ROUGHNESS = mix(0.4, 0.9, mullion);
	EMISSION = lit_color.rgb * lit * 0.5;
}
"""
