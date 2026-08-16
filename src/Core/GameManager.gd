extends Node
## GameManager (autoload)
##
## Top-level coordinator for an active game session. Owns the world, the player
## faction and the turn/clock. Kept deliberately thin in Phase 0; later phases
## will hang economy, logistics and intelligence state off of here.
##
## No class_name: this script is registered as an autoload singleton named
## `GameManager`, so the global identifier resolves to the running instance.

signal game_started
signal game_paused(paused: bool)
signal game_speed_changed(speed: float)

@export var initial_speed: float = 1.0

var world: Node = null
var player_faction: String = "blue"
var paused: bool = false
var game_speed: float = 1.0
var elapsed: float = 0.0


func _ready() -> void:
	game_speed = initial_speed


func start_game(p_world: Node) -> void:
	world = p_world
	elapsed = 0.0
	paused = false
	game_started.emit()


func set_paused(value: bool) -> void:
	paused = value
	game_paused.emit(paused)


func set_speed(value: float) -> void:
	game_speed = clamp(value, 0.0, 8.0)
	game_speed_changed.emit(game_speed)


func _process(delta: float) -> void:
	if not is_instance_valid(world) or paused:
		return
	elapsed += delta * game_speed


func get_units() -> Array:
	if not is_instance_valid(world):
		return []
	if world.has_method("get_units"):
		return world.get_units()
	return []
