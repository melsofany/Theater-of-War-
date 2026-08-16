extends Node3D
## Main
##
## Composes the in-game scene: world, RTS camera, player controller and HUD.
## Loaded by MainMenu when the player starts a new game.

class_name Main


func _ready() -> void:
	# Allow ESC to return to the main menu.
	var tree := get_tree()
	tree.paused = false
