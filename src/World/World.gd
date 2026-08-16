extends Node3D
## World
##
## Root of the playable battlefield. Owns the terrain ground, the unit container
## and exposes lookup helpers used by the rest of the game. Phase 0 is a flat
## plane with a grid overlay; Phase 2 replaces this with real terrain.

class_name World

@export var ground_size: float = 200.0
@export var cell_size: float = 2.0

@onready var ground: StaticBody3D = $Ground
@onready var units_root: Node3D = $Units


func _ready() -> void:
	GameManager.start_game(self)


func get_units() -> Array:
	var out: Array = []
	if units_root:
		for c in units_root.get_children():
			if c is Unit:
				out.append(c)
	return out


func get_buildings() -> Array:
	var out: Array = []
	if units_root:
		for c in units_root.get_children():
			if c is Building:
				out.append(c)
	return out


func get_enemy_units_of(faction: Faction) -> Array:
	var out: Array = []
	for u in get_units():
		if u.faction != null and u.faction.is_enemy_of(faction):
			out.append(u)
	return out


func spawn_unit(scene: PackedScene, at: Vector3) -> Unit:
	var u := scene.instantiate() as Unit
	units_root.add_child(u)
	u.global_position = at
	return u
