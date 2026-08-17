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
    camera.global_position = Vector3(0.0, 10.0, 19.0)
    camera.look_at(Vector3(0.0, 0.8, 6.0), Vector3.UP)
    await process_frame
    await create_timer(1.0).timeout
    viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(shot_dir + "/main_battle.png"))
    camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    camera.size = 12.0
    camera.global_position = Vector3(0.0, 22.0, 6.0)
    camera.look_at(Vector3(0.0, 0.0, 6.0), Vector3.UP)
    await process_frame
    await create_timer(0.8).timeout
    viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(shot_dir + "/unit_closeup.png"))
    # Pull up and point at the center to show the full formation.
    camera.projection = Camera3D.PROJECTION_PERSPECTIVE
    camera.fov = 52.0
    camera.global_position = Vector3(8.0, 48.0, 8.0)
    camera.look_at(Vector3(5.0, 0.0, 0.0), Vector3.UP)
    await process_frame
    await create_timer(1.0).timeout
    viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(shot_dir + "/main_overview.png"))
    # Meta-city showcase: use a true RTS top-down view over Northport.
    var hud := scene.get_node_or_null("HUD") as Control
    var minimap := scene.get_node_or_null("Minimap") as Control
    if hud:
        hud.visible = false
    if minimap:
        minimap.visible = false
    camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    camera.size = 59.0
    camera.global_position = Vector3(25.6, 92.0, -32.0)
    camera.look_at(Vector3(25.6, 0.0, -32.0), Vector3(0.0, 0.0, -1.0))

    await process_frame
    await create_timer(1.0).timeout
    viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(shot_dir + "/modern_city_overview.png"))
    quit(0)
