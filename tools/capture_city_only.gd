extends SceneTree

var city: Node3D
var camera: Camera3D

func _initialize() -> void:
	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.45, 0.68, 0.88)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.70, 0.78, 0.88)
	environment.ambient_light_energy = 0.75
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.glow_enabled = true
	environment.glow_intensity = 0.08
	environment.ssao_enabled = true
	environment.ssao_intensity = 0.35
	environment_node.environment = environment
	root.add_child(environment_node)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, -32.0, 0.0)
	sun.light_energy = 2.1
	sun.shadow_enabled = true
	root.add_child(sun)

	city = load("res://src/World/PhotorealCityGenerator.gd").new()
	city.name = "ReferenceCityOnly"
	city.city_extent = Vector2(360.0, 360.0)
	root.add_child(city)
	city.build_city("Cairo War", 0, false)

	camera = Camera3D.new()
	camera.current = true
	camera.fov = 52.0
	camera.global_position = Vector3(174.0, 136.0, 188.0)
	root.add_child(camera)
	camera.look_at(Vector3(0.0, 20.0, 0.0), Vector3.UP)
	call_deferred("_capture")

func _capture() -> void:
	await process_frame
	await process_frame
	await create_timer(0.8).timeout
	var viewport := get_root().get_viewport()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://capture"))
	viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://capture/modern_city_kaykit.png"))
	quit(0)
