extends GutTest
## Tests for the command hierarchy: tree shape, unit collection, order
## propagation and formation distribution.

func _make_unit() -> Unit:
	var u: Unit = load("res://src/Units/Unit.tscn").instantiate()
	add_child(u)
	u.unit_type = UnitFactory.get_type("infantry")
	u.max_health = u.unit_type.max_health
	u.health = u.max_health
	u.armor = u.unit_type.armor
	u.max_speed = u.unit_type.max_speed
	u.radius = u.unit_type.radius
	return u


func _brigade_of(root: CommandNode) -> CommandNode:
	return root.children[0].children[0].children[0]


func test_build_tree_shape():
	var units: Array = []
	for i in 6:
		units.append(_make_unit())
	var root := CommandTree.build_for(units)
	assert_eq(root.echelon, CommandNode.Echelon.ARMY)
	assert_eq(root.children.size(), 1)  # one corps
	var brigade: CommandNode = _brigade_of(root)
	assert_eq(brigade.echelon, CommandNode.Echelon.BRIGADE)
	# 6 units / platoon_size 4 -> 2 platoons.
	assert_eq(brigade.children.size(), 2)
	assert_eq(root.unit_count(), 6)
	CommandTree.clear()


func test_collect_units_gathers_all_descendants():
	var units: Array = []
	for i in 5:
		units.append(_make_unit())
	var root := CommandTree.build_for(units)
	var brigade: CommandNode = _brigade_of(root)
	var collected: Array = brigade.collect_units()
	assert_eq(collected.size(), 5)
	CommandTree.clear()


func test_order_move_propagates_to_all_units():
	var units: Array = []
	for i in 4:
		units.append(_make_unit())
	var root := CommandTree.build_for(units)
	var brigade: CommandNode = _brigade_of(root)
	brigade.order_move(Vector3(50, 0, 50))
	var moving := 0
	for u in units:
		if u and is_instance_valid(u) and u.moving:
			moving += 1
	assert_eq(moving, 4)
	var seen: Dictionary = {}
	for u in units:
		seen[u.target_position] = true
	assert_gt(seen.size(), 1)
	CommandTree.clear()


func test_find_containing_returns_platoon():
	var units: Array = []
	for i in 3:
		units.append(_make_unit())
	var root := CommandTree.build_for(units)
	var node: CommandNode = root.find_containing(units[0])
	assert_not_null(node)
	assert_eq(node.echelon, CommandNode.Echelon.PLATOON)
	CommandTree.clear()


func test_promote_and_drill_move_active_node():
	var units: Array = []
	for i in 4:
		units.append(_make_unit())
	var root := CommandTree.build_for(units)
	assert_eq(CommandTree.active_node, root)
	CommandTree.drill()
	assert_eq(CommandTree.active_node.echelon, CommandNode.Echelon.CORPS)
	CommandTree.drill()
	assert_eq(CommandTree.active_node.echelon, CommandNode.Echelon.DIVISION)
	CommandTree.drill()
	assert_eq(CommandTree.active_node.echelon, CommandNode.Echelon.BRIGADE)
	CommandTree.promote()
	assert_eq(CommandTree.active_node.echelon, CommandNode.Echelon.DIVISION)
	CommandTree.clear()


func test_path_string_contains_echelons():
	var units: Array = []
	for i in 2:
		units.append(_make_unit())
	var root := CommandTree.build_for(units)
	var p: String = root.path_string()
	assert_true(p.find("Army") >= 0)
	var brigade: CommandNode = _brigade_of(root)
	var bp: String = brigade.path_string()
	assert_true(bp.find("Brigade") >= 0)
	assert_true(bp.find("Army") >= 0)
	CommandTree.clear()
