extends GutTest

## Test HiggsFieldOverlay and Higgs Field visual integration

func _make_test_map_data() -> MapData:
	var md := MapData.new()
	md.size = 16
	md.cell = 2.0
	md.origin = Vector3(-16, 0, -16)
	md.heights.resize(16 * 16)
	md.heights.fill(0.0)
	return md


func test_higgs_field_overlay_instantiation() -> void:
	var overlay := HiggsFieldOverlay.new()
	assert_not_null(overlay, "HiggsFieldOverlay should instantiate")
	overlay.queue_free()


func test_higgs_field_overlay_builds_mesh_and_nodes() -> void:
	var map_data := _make_test_map_data()
	var overlay := HiggsFieldOverlay.new()
	add_child_autofree(overlay)
	overlay.build_overlay(map_data)

	var grid_lines := overlay.get_node_or_null("GridLines") as MeshInstance3D
	assert_not_null(grid_lines, "GridLines MeshInstance3D should exist")

	var nodes_container := overlay.get_node_or_null("QuantumNodes")
	assert_not_null(nodes_container, "QuantumNodes container should exist")
	assert_gt(nodes_container.get_child_count(), 0, "Should contain quantum node instances")


func test_higgs_field_overlay_process_animates() -> void:
	var map_data := _make_test_map_data()
	var overlay := HiggsFieldOverlay.new()
	add_child_autofree(overlay)
	overlay.build_overlay(map_data)

	overlay._process(0.1)
	overlay._process(0.1)
	assert_true(overlay.is_inside_tree(), "Overlay remains active in tree during animation")


func test_terrain_creates_higgs_field_overlay() -> void:
	var terrain := Terrain.new()
	var map_data := _make_test_map_data()
	terrain.map_data = map_data
	add_child_autofree(terrain)

	var overlay := terrain.get_node_or_null("HiggsFieldOverlay") as HiggsFieldOverlay
	assert_not_null(overlay, "Terrain should automatically create HiggsFieldOverlay child")
