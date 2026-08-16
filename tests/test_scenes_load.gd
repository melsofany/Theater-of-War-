extends GutTest
## TestScenesLoad
##
## Smoke test: every shipped scene must load and instantiate without errors so
## the dependency graph stays intact across phases.

var scenes := [
	"res://src/UI/MainMenu.tscn",
	"res://src/UI/Main.tscn",
	"res://src/World/World.tscn",
	"res://src/Units/Unit.tscn",
	"res://src/Units/Building.tscn",
	"res://src/UI/HUD.tscn",
]


func test_all_scenes_load_and_instantiate() -> void:
	for path in scenes:
		var packed := load(path) as PackedScene
		assert_not_null(packed, "Scene failed to load: %s" % path)
		if packed == null:
			continue
		var inst := packed.instantiate()
		assert_not_null(inst, "Scene failed to instantiate: %s" % path)
		if inst:
			add_child(inst)
			inst.queue_free()
