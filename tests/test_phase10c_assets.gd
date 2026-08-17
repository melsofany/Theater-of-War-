extends GutTest
## Phase 10c — asset wiring tests. Verifies generated assets exist and load in
## Godot, and that UnitType.key is set on registration (drives the HUD icon).

const ICON_KEYS := [
	"infantry", "vehicle", "tank", "artillery", "air_defense",
	"aircraft", "helicopter", "destroyer", "frigate", "heavy_tank",
]

func test_unit_type_key_set_on_register():
	var t: UnitType = UnitFactory.get_type("tank")
	assert_eq(t.key, "tank")
	var inf: UnitType = UnitFactory.get_type("infantry")
	assert_eq(inf.key, "infantry")


func test_register_from_dict_sets_key():
	UnitFactory.register_from_dict("wired_test_unit", {"max_health": 90})
	var t: UnitType = UnitFactory.get_type("wired_test_unit")
	assert_eq(t.key, "wired_test_unit")


func test_fire_sfx_name_by_category():
	var u: Unit = load("res://src/Units/Unit.tscn").instantiate()
	u.unit_type = UnitFactory.get_type("tank")
	add_child(u)
	assert_eq(u._fire_sfx_name(), "tank_fire")
	u.unit_type = UnitFactory.get_type("artillery")
	assert_eq(u._fire_sfx_name(), "artillery_fire")
	u.unit_type = UnitFactory.get_type("air_defense")
	assert_eq(u._fire_sfx_name(), "aa_fire")
	u.unit_type = UnitFactory.get_type("aircraft")
	assert_eq(u._fire_sfx_name(), "aircraft_fire")


func test_combat_sfx_assets_exist_and_load():
	for name in ["infantry_fire", "tank_fire", "artillery_fire", "aa_fire", "aircraft_fire", "explosion"]:
		var path := "res://assets/audio/sfx/%s.ogg" % name
		assert_true(ResourceLoader.exists(path), "missing SFX: %s" % path)
		var s := load(path)
		assert_not_null(s, "failed to load SFX: %s" % path)


func test_menu_music_asset_exists_and_loads():
	var path := "res://assets/audio/music/menu_theme.ogg"
	assert_true(ResourceLoader.exists(path))
	assert_not_null(load(path))


func test_menu_background_asset_exists_and_loads():
	var path := "res://assets/ui/menu_bg.png"
	assert_true(ResourceLoader.exists(path))
	assert_not_null(load(path))


func test_unit_icon_assets_exist_and_load():
	for key in ICON_KEYS:
		var path := "res://assets/icons/units/%s.png" % key
		assert_true(ResourceLoader.exists(path), "missing icon: %s" % path)
		var tex := load(path)
		assert_not_null(tex, "failed to load icon: %s" % path)
