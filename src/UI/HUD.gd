extends Control
## HUD
##
## On-screen overlay: instructions, selected-unit count, building production
## status and the drag-selection rectangle drawn from SelectionManager state.

class_name HUD

@export var world: World

@onready var label: Label = $VBox/Label
@onready var count_label: Label = $VBox/CountLabel
@onready var building_label: Label = $VBox/BuildingLabel


func _ready() -> void:
	SelectionManager.selection_changed.connect(_on_selection_changed)
	_update_count(0)


func _on_selection_changed(units: Array) -> void:
	_update_count(units.size())


func _update_count(n: int) -> void:
	count_label.text = "Selected units: %d" % n


func _process(_delta: float) -> void:
	# Show production status of any selected player building.
	var b: Building = null
	if world:
		for bb in world.get_buildings():
			if bb.selected and bb.faction and bb.faction.is_player:
				b = bb
				break
	if b:
		building_label.text = "%s — queue: %d  (B: build, Y: rally)" % [b.display_name, b.production_queue.size()]
	else:
		building_label.text = ""
	queue_redraw()


func _draw() -> void:
	if SelectionManager.drag_active:
		var r := SelectionManager.get_drag_rect()
		draw_rect(r, Color(0.4, 0.7, 1.0, 0.15), true)
		draw_rect(r, Color(0.5, 0.8, 1.0, 0.9), false, 1.5)
