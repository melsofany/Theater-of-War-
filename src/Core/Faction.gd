extends Resource
## Faction
##
## Lightweight data holder for a side in the conflict. Phase 0 only needs an id
## and an enemy list; later phases add economy, logistics and intelligence state.
## A Resource (not a Node) so it is refcounted and cheap to pass around.

class_name Faction

@export var name: String = "blue"
@export var display_name: String = "Blue Force"
@export var color: Color = Color(0.2, 0.4, 0.9)
@export var enemies: Array[StringName] = []

var is_player: bool = false


func is_enemy_of(other: Faction) -> bool:
	if other == null:
		return false
	return StringName(other.name) in enemies


static func make(p_name: String, p_display: String, p_color: Color, p_enemies: Array, p_player: bool = false) -> Faction:
	var f := Faction.new()
	f.name = p_name
	f.display_name = p_display
	f.color = p_color
	for e in p_enemies:
		f.enemies.append(StringName(e))
	f.is_player = p_player
	return f
