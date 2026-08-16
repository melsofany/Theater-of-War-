extends Node3D
## Main
##
## Composes the in-game scene: world, RTS camera, player controller and HUD.
## Loaded by MainMenu when the player starts a new game. Wires cross-node
## references (world -> camera) so terrain-aware picking/movement works.

class_name Main


func _ready() -> void:
	var tree := get_tree()
	tree.paused = false
	var w := get_node_or_null("World") as World
	var cam := get_node_or_null("Camera3D") as RTSCamera
	if w and cam:
		cam.world = w
