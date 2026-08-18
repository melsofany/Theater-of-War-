extends Node3D
## Main
##
## Composes the in-game scene: world, RTS camera, player controller and HUD.
## Wires the camera and minimap to the runtime world and keeps streamed terrain
## centred on the active camera.

class_name Main

var _world: World
var _camera: RTSCamera


func _ready() -> void:
	var tree := get_tree()
	tree.paused = false
	_world = get_node_or_null("World") as World
	_camera = get_node_or_null("Camera3D") as RTSCamera
	var minimap := get_node_or_null("Minimap") as Minimap
	if _world and _camera:
		_camera.world = _world
		_sync_camera_bounds()
		if Networking:
			Networking.attach_world(_world)
	if _world and minimap:
		minimap.world = _world
		minimap.call_deferred("_sync_world_bounds")


func _process(_delta: float) -> void:
	if _world == null or _camera == null or _world.terrain == null:
		return
	# Stream only the terrain near the current RTS view while preserving the
	# complete MapData for movement, minimap and long-distance strategy.
	_world.terrain.stream_focus = _camera.global_position
	_world.terrain._stream_update()


func _sync_camera_bounds() -> void:
	if _world == null or _world.map_data == null or _camera == null:
		return
	var md := _world.map_data
	var width := float(md.size) * md.cell
	var margin := 96.0
	_camera.bounds = Rect2(
		md.origin.x + margin,
		md.origin.z + margin,
		maxf(1.0, width - margin * 2.0),
		maxf(1.0, width - margin * 2.0)
	)
