extends Node
## SelectionManager (autoload)
##
## Owns the current set of selected units and exposes box-select + single click
## selection. Units register themselves as selectable; this manager keeps
## references and notifies listeners. UI draws the drag rectangle.
##
## No class_name: registered as an autoload singleton named `SelectionManager`.

signal selection_changed(units: Array)

# Untyped on purpose: the manager duck-types anything with `set_selected(bool)`.
# Real game entries are Unit/Building; tests use lightweight fakes.
var selected: Array = []
var drag_active: bool = false
var drag_start: Vector2 = Vector2.ZERO
var drag_current: Vector2 = Vector2.ZERO


func select_single(unit) -> void:
	clear(true)
	if unit != null:
		add(unit)


func add(unit) -> void:
	if unit == null or unit in selected:
		return
	selected.append(unit)
	unit.set_selected(true)
	_emit()


func remove(unit) -> void:
	if unit == null or not unit in selected:
		return
	selected.erase(unit)
	unit.set_selected(false)
	_emit()


func clear(quiet: bool = false) -> void:
	for u in selected:
		if is_instance_valid(u):
			u.set_selected(false)
	selected.clear()
	if not quiet:
		_emit()


func begin_drag(pos: Vector2) -> void:
	drag_active = true
	drag_start = pos
	drag_current = pos


func update_drag(pos: Vector2) -> void:
	if drag_active:
		drag_current = pos


func end_drag(units: Array, additive: bool = false) -> void:
	drag_active = false
	if not additive:
		clear(true)
	for u in units:
		add(u)


func get_drag_rect() -> Rect2:
	var r := Rect2()
	r.position = Vector2(min(drag_start.x, drag_current.x), min(drag_start.y, drag_current.y))
	r.size = Vector2(abs(drag_current.x - drag_start.x), abs(drag_current.y - drag_start.y))
	return r

func _emit() -> void:
	selection_changed.emit(selected.duplicate())
