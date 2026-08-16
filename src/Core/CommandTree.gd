extends Node
## CommandTree (autoload)
##
## Builds and owns the player faction's command hierarchy at game start and
## tracks the currently "active" command node — the echelon the player is
## commanding. The UI issues orders to the active node so a single order can
## move an entire brigade instead of each unit individually.

signal active_node_changed(node: CommandNode)

var root_node: CommandNode = null
var active_node: CommandNode = null


func build_for(units: Array, faction_name: String = "1st") -> CommandNode:
	root_node = CommandNode.new(CommandNode.Echelon.ARMY, "%s Army" % faction_name)
	# One corps + one division + one brigade for Phase 4; later phases can split.
	var corps := CommandNode.new(CommandNode.Echelon.CORPS, "I Corps")
	var division := CommandNode.new(CommandNode.Echelon.DIVISION, "1st Division")
	var brigade := CommandNode.new(CommandNode.Echelon.BRIGADE, "1st Brigade")
	root_node.add_child(corps)
	corps.add_child(division)
	division.add_child(brigade)
	# Group units into platoons of up to 4.
	var platoon_size := 4
	var platoon_count := maxi(1, int(ceil(float(units.size()) / float(platoon_size))))
	for p in platoon_count:
		var platoon := CommandNode.new(CommandNode.Echelon.PLATOON, "%d Platoon" % (p + 1))
		brigade.add_child(platoon)
		var from := p * platoon_size
		var to := mini(from + platoon_size, units.size())
		for i in range(from, to):
			platoon.add_unit(units[i])
	active_node = root_node
	active_node_changed.emit(active_node)
	return root_node


func set_active(node: CommandNode) -> void:
	if node == null:
		return
	active_node = node
	active_node_changed.emit(node)


func promote() -> CommandNode:
	if active_node and active_node.parent:
		set_active(active_node.parent)
	return active_node


func drill() -> CommandNode:
	if active_node and not active_node.children.is_empty():
		set_active(active_node.children[0])
	return active_node


func select_node_of(unit: Unit) -> CommandNode:
	if root_node == null or unit == null:
		return null
	var node := root_node.find_containing(unit)
	if node != null:
		set_active(node)
	return node


func clear() -> void:
	root_node = null
	active_node = null
	active_node_changed.emit(null)
