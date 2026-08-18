extends SceneTree

var scene: Node
var camera: Camera3D
var shot_dir := "res://capture"

func _initialize() -> void:
    scene = load("res://src/UI/Main.tscn").instantiate()
    root.add_child(scene)
    camera = scene.get_node_or_null("Camera3D") as Camera3D
    if camera == null:
        quit(2)
        return
    camera.current = true
    call_deferred("_capture")

func _capture() -> void:
    await process_frame
    await process_frame
    await create_timer(2.0).timeout
    # Freeze the deterministic showcase so units do not leave the camera framing.
    paused = true
    var viewport := get_root().get_viewport()
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(shot_dir))

    var hud := scene.get_node_or_null("HUD") as Control
    var minimap := scene.get_node_or_null("Minimap") as Control
    var world := scene.get_node_or_null("World") as Node3D
    var features := world.get_node_or_null("Features") as Node3D if world else null

    # Unit showcase: remove the CBD buildings from the camera temporarily so the
    # player/enemy formations are visible instead of being occluded by towers.
    if hud:
        hud.visible = false
    if minimap:
        minimap.visible = false
    if features:
        features.visible = false
    camera.projection = Camera3D.PROJECTION_PERSPECTIVE
    camera.fov = 58.0
    camera.global_position = Vector3(0.0, 24.0, 30.0)
    camera.look_at(Vector3(0.0, 0.6, 0.0), Vector3.UP)
    await process_frame
    await create_timer(0.8).timeout
    viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(shot_dir + "/main_battle.png"))

    # Unit close-up: use an orthographic frame around the complete mixed player line.
    camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    camera.size = 18.0
    camera.global_position = Vector3(0.0, 26.0, 24.0)
    camera.look_at(Vector3(0.0, 2.0, 0.0), Vector3.UP)
    await process_frame
    await create_timer(0.8).timeout
    viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(shot_dir + "/unit_closeup.png"))

    # Restore the world features and perspective projection for strategic views.
    if features:
        features.visible = true
    if hud:
        hud.visible = true
    if minimap:
        minimap.visible = true
    camera.projection = Camera3D.PROJECTION_PERSPECTIVE
    camera.fov = 52.0
    camera.global_position = Vector3(170.0, 145.0, 170.0)
    camera.look_at(Vector3(0.0, 0.0, 0.0), Vector3.UP)
    await process_frame
    await create_timer(1.0).timeout
    viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(shot_dir + "/main_overview.png"))

    # REAL3D showcase: focus on the Cairo War city position projected from the
    # attached 16384x16384 Unified World Map into the current 256m playfield.
    if hud:
        hud.visible = false
    if minimap:
        minimap.visible = false
    camera.fov = 44.0
    _set_zone_guides_visible(world, false)
    # Cairo War projection from Meta's 16384 map: (4000, 1800) -> (-524, -799).
    # Use a lower, closer aerial composition matching the supplied reference city.
    var cbd_center := Vector3(-524.0, 0.0, -799.0)
    camera.global_position = cbd_center + Vector3(158.0, 118.0, 158.0)
    camera.look_at(cbd_center + Vector3(28.0, 18.0, 28.0), Vector3.UP)
    await process_frame
    await create_timer(1.0).timeout
    viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(shot_dir + "/modern_city_overview.png"))
    quit(0)

func _set_zone_guides_visible(node: Node, enabled: bool) -> void:
    if node == null:
        return
    if node is StrategicZone or "ObjectiveBorder" in node.name or "StrategicZone" in node.name:
        node.visible = enabled
    for child in node.get_children():
        _set_zone_guides_visible(child, enabled)
