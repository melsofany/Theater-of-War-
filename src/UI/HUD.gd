extends Control
## HUD
##
## On-screen overlay: instructions, selected-unit count, building production
## status and the drag-selection rectangle drawn from SelectionManager state.

class_name HUD

@export var world: World

@onready var label: Label = $VBox/Label
@onready var count_label: Label = $VBox/CountLabel
@onready var command_label: Label = $VBox/CommandLabel
@onready var resource_label: Label = $VBox/ResourceLabel
@onready var building_label: Label = $VBox/BuildingLabel


func _ready() -> void:
	SelectionManager.selection_changed.connect(_on_selection_changed)
	if CommandTree:
		CommandTree.active_node_changed.connect(_on_active_node_changed)
	_update_count(0)
	_update_command()


func _on_selection_changed(units: Array) -> void:
	_update_count(units.size())


func _on_active_node_changed(_node: CommandNode) -> void:
	_update_command()


func _update_count(n: int) -> void:
	count_label.text = "Selected units: %d" % n


func _update_command() -> void:
	if CommandTree and CommandTree.active_node:
		var n: CommandNode = CommandTree.active_node
		command_label.text = "Command: %s  (%d units)" % [n.path_string(), n.unit_count()]
	else:
		command_label.text = ""


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
	_update_resources()
	_update_command()
	queue_redraw()


func _update_resources() -> void:
	if not Economy or not Economy._amounts.has("blue"):
		resource_label.text = ""
		return
	var mp: int = int(Economy.amount("blue", Economy.R.MANPOWER))
	var fuel: int = int(Economy.amount("blue", Economy.R.FUEL))
	var mat: int = int(Economy.amount("blue", Economy.R.MATERIALS))
	var mp_i: float = Economy.income("blue", Economy.R.MANPOWER)
	var mat_i: float = Economy.income("blue", Economy.R.MATERIALS)
	resource_label.text = "MP %d (+%.1f/s)  Fuel %d  Mat %d (+%.1f/s)" % [mp, mp_i, fuel, mat, mat_i]


func _draw() -> void:
	if SelectionManager.drag_active:
		var r := SelectionManager.get_drag_rect()
		draw_rect(r, Color(0.4, 0.7, 1.0, 0.15), true)
		draw_rect(r, Color(0.5, 0.8, 1.0, 0.9), false, 1.5)
