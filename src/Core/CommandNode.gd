extends RefCounted
## CommandNode
##
## A node in the military command hierarchy: Army → Corps → Division → Brigade →
## Battalion → Company → Platoon. Interior nodes hold child CommandNodes; the
## platoon (leaf) holds the actual Unit instances. Orders given to any node
## propagate down to every unit under it, distributed across a formation so a
## brigade moves as a spread group rather than a single stack.
##
## Pure logic — no scene tree — so it is unit-testable in isolation.

class_name CommandNode

enum Echelon {
	ARMY,
	CORPS,
	DIVISION,
	BRIGADE,
	BATTALION,
	COMPANY,
	PLATOON,
}

const ECHELON_NAME := {
	Echelon.ARMY: "Army",
	Echelon.CORPS: "Corps",
	Echelon.DIVISION: "Division",
	Echelon.BRIGADE: "Brigade",
	Echelon.BATTALION: "Battalion",
	Echelon.COMPANY: "Company",
	Echelon.PLATOON: "Platoon",
}

var echelon: Echelon = Echelon.PLATOON
var unit_name: String = ""
var parent: CommandNode = null
var children: Array[CommandNode] = []
var units: Array[Unit] = []
## Horizontal spacing (metres) between sub-elements when an order propagates.
var formation_spacing: float = 3.0


func _init(e: Echelon = Echelon.PLATOON, n: String = "") -> void:
	echelon = e
	unit_name = n if n != "" else ECHELON_NAME[e]


func is_leaf() -> bool:
	return children.is_empty()


func add_child(node: CommandNode) -> void:
	node.parent = self
	children.append(node)


func add_unit(u: Unit) -> void:
	if u != null and not units.has(u):
		units.append(u)


func collect_units() -> Array:
	var out: Array = []
	if not is_leaf():
		for c in children:
			out.append_array(c.collect_units())
	out.append_array(units)
	return out


func unit_count() -> int:
	return collect_units().size()


func order_move(center: Vector3) -> void:
	var all: Array = collect_units()
	if all.is_empty():
		return
	var positions := _formation_offsets(all.size(), center)
	for i in all.size():
		var u: Unit = all[i]
		if u and is_instance_valid(u):
			u.move_to(positions[i])


func order_attack(target: Unit) -> void:
	for u in collect_units():
		if u and is_instance_valid(u):
			u.target = target


func order_stop() -> void:
	for u in collect_units():
		if u and is_instance_valid(u):
			u.moving = false
			u.target = null


## Distribute `count` units in a grid centred on `center`, each spaced by
## `formation_spacing`. Returns world-space target positions.
func _formation_offsets(count: int, center: Vector3) -> Array:
	var out: Array = []
	if count <= 0:
		return out
	var cols := int(ceil(sqrt(float(count))))
	var rows := int(ceil(float(count) / float(cols)))
	var sp := formation_spacing
	var origin_x := center.x - (cols - 1) * sp * 0.5
	var origin_z := center.z - (rows - 1) * sp * 0.5
	for i in count:
		var col := i % cols
		var row := i / cols
		out.append(Vector3(origin_x + col * sp, center.y, origin_z + row * sp))
	return out


func path_string() -> String:
	var parts: Array = []
	var n: CommandNode = self
	while n != null:
		parts.push_front(n.unit_name)
		n = n.parent
	return " → ".join(parts)


func find_containing(u: Unit) -> CommandNode:
	if u in units:
		return self
	for c in children:
		var found := c.find_containing(u)
		if found != null:
			return found
	return null


func root() -> CommandNode:
	var n: CommandNode = self
	while n.parent != null:
		n = n.parent
	return n
