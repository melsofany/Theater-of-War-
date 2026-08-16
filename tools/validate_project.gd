extends SceneTree
## validate_project
##
## Headless utility run via `godot --headless --script tools/validate_project.gd`.
## Loads the MainMenu and Main scenes to confirm the project parses and the
## dependency graph is intact, then exits with a status code. Used by CI and the
## local build step.

const MainMenuPath := "res://src/UI/MainMenu.tscn"
const MainPath := "res://src/UI/Main.tscn"


func _init() -> void:
	var errors := []
	for path in [MainMenuPath, MainPath]:
		var packed := load(path) as PackedScene
		if packed == null:
			errors.append("Failed to load scene: %s" % path)
			continue
		var inst := packed.instantiate()
		if inst == null:
			errors.append("Failed to instantiate scene: %s" % path)
			continue
		root.add_child(inst)
		# Run one idle frame so _ready fires.
		await process_frame
		inst.queue_free()
		await process_frame

	if errors.is_empty():
		print("VALIDATE: OK — all scenes loaded and instantiated.")
		quit(0)
	else:
		for e in errors:
			push_error(e)
		quit(1)
