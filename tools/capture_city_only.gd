extends SceneTree

var city: Node3D
var camera: Camera3D

func _initialize() -> void:
	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.34, 0.62, 0.96)
	sky_material.sky_horizon_color = Color(0.82, 0.92, 1.00)
	sky_material.ground_bottom_color = Color(0.48, 0.54, 0.58)
	sky_material.ground_horizon_color = Color(0.78, 0.84, 0.90)
	sky_material.sun_angle_max = 18.0
	sky_material.sun_curve = 0.08
	var sky := Sky.new()
	sky.sky_material = sky_material
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.70, 0.78, 0.88)
	environment.ambient_light_energy = 1.05
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.glow_enabled = true
	environment.glow_intensity = 0.10
	environment.ssao_enabled = true
	environment.ssao_intensity = 0.48
	environment.ssr_enabled = true
	environment.ssr_max_steps = 64
	environment.ssr_fade_in = 0.15
	environment.ssr_fade_out = 2.0
	environment.sdfgi_enabled = true
	environment_node.environment = environment
	root.add_child(environment_node)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, -32.0, 0.0)
	sun.light_energy = 2.55
	sun.shadow_enabled = true
	root.add_child(sun)

	city = load("res://src/World/PhotorealCityGenerator.gd").new()
	city.name = "ReferenceCityOnly"
	city.city_extent = Vector2(360.0, 360.0)
	city.showcase_density = true
	root.add_child(city)
	city.build_city("Cairo War", 0, false)

	camera = Camera3D.new()
	camera.current = true
	camera.fov = 44.0
	root.add_child(camera)
	camera.position = Vector3(158.0, 118.0, 158.0)
	camera.look_at_from_position(camera.position, Vector3(28.0, 18.0, 28.0), Vector3.UP)
	call_deferred("_capture")

func _capture() -> void:
	await process_frame
	await process_frame
	await create_timer(0.8).timeout
	var viewport := get_root().get_viewport()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://capture"))
	viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://capture/modern_city_kaykit.png"))
	quit(0)
