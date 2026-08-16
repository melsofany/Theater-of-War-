extends GutTest
## Tests for the ControlGroupManager autoload.

var _cgm


func before_each():
	_cgm = ControlGroupManager


func after_each():
	# Wipe any assigned groups between tests.
	for i in ControlGroupManager.GROUP_COUNT:
		_cgm.assign(i, [])


class FakeUnit:
	var global_position: Vector3 = Vector3.ZERO
	func set_selected(v): pass


func test_group_count_is_nine():
	assert_eq(ControlGroupManager.GROUP_COUNT, 9)


func test_assign_and_recall():
	var u0 = FakeUnit.new()
	var u1 = FakeUnit.new()
	_cgm.assign(0, [u0, u1])
	var g = _cgm.get_group(0)
	assert_eq(g.size(), 2)
	assert_true(u0 in g)
	assert_true(u1 in g)


func test_assign_overwrites_previous():
	var u0 = FakeUnit.new()
	var u1 = FakeUnit.new()
	_cgm.assign(1, [u0, u0, u0])
	assert_eq(_cgm.get_group(1).size(), 3)
	_cgm.assign(1, [u1])
	assert_eq(_cgm.get_group(1).size(), 1)
	assert_true(u1 in _cgm.get_group(1))


func test_invalid_index_returns_empty():
	assert_eq(_cgm.get_group(-1), [])
	assert_eq(_cgm.get_group(99), [])
