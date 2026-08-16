extends Camera3D
## RTSCamera
##
## Classic RTS camera: edge/keyboard panning, zoom on wheel, pitch locked.
## Stays above the ground plane and clamps to the world bounds.

class_name RTSCamera

@export var pan_speed: float = 40.0
@export var edge_pan: bool = true
@export var edge_margin: float = 20.0
@export var zoom_min: float = 15.0
@export var zoom_max: float = 80.0
@export var zoom_step: float = 4.0
@export var bounds: Rect2 = Rect2(-95, -95, 190, 190)

var _velocity: Vector3 = Vector3.ZERO


func _ready() -> void:
	current = true


func _process(delta: float) -> void:
	var move := Vector2.ZERO
	if Input.is_action_pressed("move_north"):
		move.y -= 1.0
	if Input.is_action_pressed("move_south"):
		move.y += 1.0
	if Input.is_action_pressed("move_east"):
		move.x += 1.0
	if Input.is_action_pressed("move_west"):
		move.x -= 1.0

	if edge_pan and get_viewport().get_mouse_position() != Vector2.ZERO:
		var vp := get_viewport().get_visible_rect().size
		var m := get_viewport().get_mouse_position()
		if m.y < edge_margin:
			move.y -= 1.0
		elif m.y > vp.y - edge_margin:
			move.y += 1.0
		if m.x < edge_margin:
			move.x -= 1.0
		elif m.x > vp.x - edge_margin:
			move.x += 1.0

	var fwd := -global_transform.basis.z
	fwd.y = 0
	fwd = fwd.normalized()
	var right := global_transform.basis.x
	right.y = 0
	right = right.normalized()
	var vel := (fwd * -move.y + right * move.x) * pan_speed
	_velocity = _velocity.lerp(vel, 0.2)

	var np := global_position + _velocity * delta
	np.x = clamp(np.x, bounds.position.x, bounds.position.x + bounds.size.x)
	np.z = clamp(np.z, bounds.position.y, bounds.position.y + bounds.size.y)
	global_position = np


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
		_zoom(-zoom_step)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
		_zoom(zoom_step)


func _zoom(amount: float) -> void:
	var pos := global_position
	var dist := pos.distance_to(Vector3(pos.x, 0, pos.z))
	dist = clamp(dist + amount, zoom_min, zoom_max)
	pos.y = dist
	global_position = pos


func ground_point_at_screen(screen_pos: Vector2) -> Vector3:
	var from := project_ray_origin(screen_pos)
	var dir := project_ray_normal(screen_pos)
	# Intersect with the y = 0 plane.
	if abs(dir.y) < 0.0001:
		return Vector3.ZERO
	var t := -from.y / dir.y
	return from + dir * t


func focus_on(world_pos: Vector3) -> void:
	# Move the camera so it looks down at world_pos, keeping its current height.
	var np := global_position
	np.x = world_pos.x
	np.z = world_pos.z - (global_position.y / 0.643)  # offset from pitch (~40deg)
	np.x = clamp(np.x, bounds.position.x, bounds.position.x + bounds.size.x)
	np.z = clamp(np.z, bounds.position.y, bounds.position.y + bounds.size.y)
	global_position = np
	_velocity = Vector3.ZERO
