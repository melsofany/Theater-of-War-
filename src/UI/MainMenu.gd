extends Control
## MainMenu
##
## Prototype entry screen. Offers "New Game", an options placeholder and "Quit".
## "New Game" swaps to the Main scene. This is the project's main scene so the
## project boots straight into a menu rather than a blank world.

class_name MainMenu


func _ready() -> void:
	var am := get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_music"):
		am.play_music("menu_theme")


func _on_new_game_pressed() -> void:
	var am := get_node_or_null("/root/AudioManager")
	if am and am.has_method("stop_music"):
		am.stop_music()
	get_tree().change_scene_to_file("res://src/UI/Main.tscn")


func _on_quit_pressed() -> void:
	get_tree().quit()


func _on_options_pressed() -> void:
	# Placeholder; options are a later phase.
	pass
