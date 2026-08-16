extends GutTest
## TestSelectionManager
##
## Drives the SelectionManager autoload logic with a minimal stand-in unit so
## the engine-agnostic selection bookkeeping is verified without a full scene.

const SelectionScript := preload("res://src/Core/SelectionManager.gd")

class FakeUnit:
	var selected: bool = false
	func set_selected(v: bool) -> void:
		selected = v


func _make_manager() -> Node:
	var m: Node = SelectionScript.new()
	return m


func test_select_single_clears_previous() -> void:
	var m := _make_manager()
	autofree(m)
	var a := FakeUnit.new()
	var b := FakeUnit.new()
	m.add(a)
	m.add(b)
	assert_eq(m.get("selected").size(), 2)
	m.call("select_single", a)
	var sel: Array = m.get("selected")
	assert_eq(sel.size(), 1)
	assert_true(a.selected)
	assert_false(b.selected)


func test_add_is_idempotent() -> void:
	var m := _make_manager()
	autofree(m)
	var a := FakeUnit.new()
	m.add(a)
	m.add(a)
	var sel: Array = m.get("selected")
	assert_eq(sel.size(), 1)


func test_remove_clears_flag() -> void:
	var m := _make_manager()
	autofree(m)
	var a := FakeUnit.new()
	m.add(a)
	m.remove(a)
	var sel: Array = m.get("selected")
	assert_eq(sel.size(), 0)
	assert_false(a.selected)


func test_clear_resets_all() -> void:
	var m := _make_manager()
	autofree(m)
	var a := FakeUnit.new()
	var b := FakeUnit.new()
	m.add(a)
	m.add(b)
	m.clear()
	var sel: Array = m.get("selected")
	assert_eq(sel.size(), 0)
	assert_false(a.selected)
	assert_false(b.selected)


func test_drag_rect_normalizes() -> void:
	var m := _make_manager()
	autofree(m)
	m.call("begin_drag", Vector2(100, 100))
	m.call("update_drag", Vector2(20, 60))
	var r: Rect2 = m.call("get_drag_rect")
	assert_eq(r.position, Vector2(20, 60))
	assert_eq(r.size, Vector2(80, 40))


func test_end_drag_collects_units() -> void:
	var m := _make_manager()
	autofree(m)
	m.call("begin_drag", Vector2(0, 0))
	m.call("update_drag", Vector2(50, 50))
	var a := FakeUnit.new()
	m.call("end_drag", [a], false)
	var sel: Array = m.get("selected")
	assert_eq(sel.size(), 1)
	assert_true(a.selected)
