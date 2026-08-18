extends SceneTree

func _init() -> void:
	var paths := [
		"res://assets/cc0/kaykit_city_builder_bits/Assets/glb/building_A.glb",
		"res://assets/cc0/kaykit_city_builder_bits/Assets/glb/car_sedan.glb",
		"res://assets/cc0/kaykit_city_builder_bits/Assets/glb/streetlight.glb",
		"res://assets/cc0/kaykit_city_builder_bits/Assets/glb/bench.glb",
		"res://src/World/StreetDetails.gd",
		"res://src/World/PhotorealCityGenerator.gd"
	]
	var failed := false
	for path in paths:
		if path.ends_with(".glb"):
			var document := GLTFDocument.new()
			var state := GLTFState.new()
			var result := document.append_from_file(path, state)
			if result != OK or document.generate_scene(state) == null:
				push_error("FAILED GLB: " + path)
				failed = true
			else:
				print("OK GLB: " + path)
		else:
			var resource = load(path)
			if resource == null:
				push_error("FAILED SCRIPT: " + path)
				failed = true
			else:
				print("OK SCRIPT: " + path)
	quit(1 if failed else 0)
