extends Node3D
## HiggsFieldOverlay
##
## Renders a glowing 3D quantum energy field grid across the terrain map with
## animated energy waves and pulsating field nodes, evoking a Higgs field
## visual aesthetic.

class_name HiggsFieldOverlay

@export var map_data: MapData
@export var grid_step: int = 2
@export var y_offset: float = 0.35
@export var base_color: Color = Color(0.0, 0.85, 1.0, 0.55)
@export var emission_color: Color = Color(0.1, 0.9, 1.0, 1.0)
@export var wave_speed: float = 1.8

var _time: float = 0.0
var _grid_mesh_instance: MeshInstance3D = null
var _grid_mat: StandardMaterial3D = null
var _nodes_container: Node3D = null
var _node_instances: Array[MeshInstance3D] = []
var _node_base_y: Array[float] = []


func _ready() -> void:
	if map_data:
		build_overlay(map_data)


func set_map_data(md: MapData) -> void:
	map_data = md
	if is_inside_tree() or map_data != null:
		build_overlay(map_data)


func build_overlay(md: MapData) -> void:
	map_data = md
	for c in get_children():
		c.queue_free()
	_node_instances.clear()
	_node_base_y.clear()

	if map_data == null or map_data.size <= 0:
		return

	_grid_mat = StandardMaterial3D.new()
	_grid_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_grid_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_grid_mat.albedo_color = base_color
	_grid_mat.use_particle_trails = false
	_grid_mat.no_depth_test = false
	_grid_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	_build_grid_mesh()
	_build_field_nodes()


func _build_grid_mesh() -> void:
	if map_data == null:
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_LINES)

	var s := map_data.size
	var step := maxi(1, grid_step)

	# Grid lines along X axis
	for gz in range(0, s, step):
		for gx in range(0, s - step, step):
			var w1 := map_data.grid_to_world(gx, gz)
			var w2 := map_data.grid_to_world(gx + step, gz)
			w1.y += y_offset
			w2.y += y_offset
			st.add_vertex(w1)
			st.add_vertex(w2)

	# Grid lines along Z axis
	for gx in range(0, s, step):
		for gz in range(0, s - step, step):
			var w1 := map_data.grid_to_world(gx, gz)
			var w2 := map_data.grid_to_world(gx, gz + step)
			w1.y += y_offset
			w2.y += y_offset
			st.add_vertex(w1)
			st.add_vertex(w2)

	_grid_mesh_instance = MeshInstance3D.new()
	_grid_mesh_instance.name = "GridLines"
	_grid_mesh_instance.mesh = st.commit()
	_grid_mesh_instance.material_override = _grid_mat
	_grid_mesh_instance.cast_shadow = 0
	add_child(_grid_mesh_instance)


func _build_field_nodes() -> void:
	if map_data == null:
		return
	_nodes_container = Node3D.new()
	_nodes_container.name = "QuantumNodes"
	add_child(_nodes_container)

	var node_sphere := SphereMesh.new()
	node_sphere.radius = 0.18
	node_sphere.height = 0.36

	var node_mat := StandardMaterial3D.new()
	node_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	node_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	node_mat.albedo_color = Color(0.2, 0.95, 1.0, 0.85)

	var s := map_data.size
	var step := maxi(1, grid_step * 3) # Node density

	for gz in range(step, s - step, step):
		for gx in range(step, s - step, step):
			var w := map_data.grid_to_world(gx, gz)
			w.y += y_offset + 0.1
			var mi := MeshInstance3D.new()
			mi.mesh = node_sphere
			mi.material_override = node_mat
			mi.position = w
			mi.cast_shadow = 0
			_nodes_container.add_child(mi)
			_node_instances.append(mi)
			_node_base_y.append(w.y)


func _process(delta: float) -> void:
	_time += delta
	var pulse := (sin(_time * wave_speed) + 1.0) * 0.5
	if _grid_mat:
		var c := base_color
		c.a = lerpf(0.35, 0.75, pulse)
		_grid_mat.albedo_color = c

	# Animate field nodes float & pulse
	for i in range(_node_instances.size()):
		var mi := _node_instances[i]
		if is_instance_valid(mi):
			var offset_phase := i * 0.4
			var hover := sin(_time * 2.5 + offset_phase) * 0.12
			mi.position.y = _node_base_y[i] + hover
