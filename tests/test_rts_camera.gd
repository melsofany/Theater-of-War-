extends GutTest
## TestRTSCamera
##
## Verifies the ground-plane intersection math the player controller relies on
## for issuing move orders.

const CameraScript := preload("res://src/UI/RTSCamera.gd")


func test_ground_point_at_screen_returns_y_zero() -> void:
	var cam := Camera3D.new()
	add_child(cam)
	cam.set_script(CameraScript)
	# Angled RTS-style view (not straight down, to avoid a parallel up vector).
	cam.global_position = Vector3(0, 35, 20)
	cam.global_transform = cam.global_transform.looking_at(Vector3.ZERO, Vector3.UP)
	cam.fov = 70
	# The ground plane is y = 0; the intersection should lie on it.
	var p: Vector3 = cam.call("ground_point_at_screen", Vector2(640, 360))
	assert_lt(abs(p.y), 0.001)
	cam.queue_free()


func test_zoom_clamps_within_bounds() -> void:
	var cam := Camera3D.new()
	add_child(cam)
	cam.set_script(CameraScript)
	cam.zoom_min = 15.0
	cam.zoom_max = 80.0
	cam.global_position = Vector3(0, 35, 0)
	cam.call("_zoom", -1000.0)
	assert_almost_eq(cam.global_position.y, 15.0, 0.01)
	cam.call("_zoom", 1000.0)
	assert_almost_eq(cam.global_position.y, 80.0, 0.01)
	cam.queue_free()
