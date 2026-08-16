extends GutTest
## TestFaction
##
## Verifies faction ownership / enemy relationships used by selection and
## (later) combat filtering.

var FactionClass := preload("res://src/Core/Faction.gd")


func test_make_sets_fields() -> void:
	var f := FactionClass.make("blue", "Blue Force", Color.BLUE, ["red"], true)
	assert_eq(f.name, "blue")
	assert_eq(f.display_name, "Blue Force")
	assert_true(f.is_player)
	assert_eq(f.enemies.size(), 1)


func test_is_enemy_of_true_for_declared_enemy() -> void:
	var blue := FactionClass.make("blue", "Blue", Color.BLUE, ["red"], true)
	var red := FactionClass.make("red", "Red", Color.RED, ["blue"], false)
	assert_true(blue.is_enemy_of(red))
	assert_true(red.is_enemy_of(blue))


func test_is_enemy_of_false_for_same_side() -> void:
	var a := FactionClass.make("blue", "Blue", Color.BLUE, ["red"], true)
	var b := FactionClass.make("blue", "Blue 2", Color.BLUE, ["red"], true)
	assert_false(a.is_enemy_of(b))


func test_is_enemy_of_null_is_false() -> void:
	var f := FactionClass.make("blue", "Blue", Color.BLUE, ["red"], true)
	assert_false(f.is_enemy_of(null))
