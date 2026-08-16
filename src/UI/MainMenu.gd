extends Control
## MainMenu
##
## Prototype entry screen. Offers "New Game", an options placeholder and "Quit".
## "New Game" swaps to the Main scene. This is the project's main scene so the
## project boots straight into a menu rather than a blank world.

class_name MainMenu


func _on_new_game_pressed() -> void:
	get_tree().change_scene_to_file("res://src/UI/Main.tscn")


func _on_quit_pressed() -> void:
	get_tree().quit()


func _on_options_pressed() -> void:
	# Placeholder; options are a later phase.
	pass
