extends Control
## HUD
##
## On-screen overlay: instructions, selected-unit count, pause indicator and the
## drag-selection rectangle drawn from SelectionManager state.

class_name HUD

@onready var label: Label = $VBox/Label
@onready var count_label: Label = $VBox/CountLabel


func _ready() -> void:
	SelectionManager.selection_changed.connect(_on_selection_changed)
	_update_count(0)


func _on_selection_changed(units: Array) -> void:
	_update_count(units.size())


func _update_count(n: int) -> void:
	count_label.text = "Selected units: %d" % n


func _draw() -> void:
	if SelectionManager.drag_active:
		var r := SelectionManager.get_drag_rect()
		draw_rect(r, Color(0.4, 0.7, 1.0, 0.15), true)
		draw_rect(r, Color(0.5, 0.8, 1.0, 0.9), false, 1.5)


func _process(_delta: float) -> void:
	queue_redraw()
