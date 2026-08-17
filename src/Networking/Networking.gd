## Networking (autoload) — Phase 10c
##
## ENet session setup plus lightweight authoritative unit-state replication.
## The host sends snapshots of the deterministic unit fields; clients apply them
## to matching nodes. Full lockstep simulation and dynamic spawn replication are
## intentionally left for a later multiplayer pass.

extends Node

enum State { OFFLINE, HOSTING, CONNECTING, ONLINE }

var state: int = State.OFFLINE
var peer: ENetMultiplayerPeer = null
var replicated_world: World = null
@export var sync_interval: float = 0.10
var _sync_elapsed: float = 0.0
signal state_changed(new_state: int)
signal snapshot_applied(unit_count: int)
## Emitted on a client when a snapshot entry has no matching local unit, so the
## client can request/construct the spawn. `entry` is the raw snapshot dict.
signal spawn_requested(entry: Dictionary)


func host(port: int = 12000, max_clients: int = 4) -> bool:
	_stop()
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_server(port, max_clients)
	if err != OK:
		push_warning("Networking.host: create_server failed: %d" % err)
		peer = null
		_set_state(State.OFFLINE)
		return false
	multiplayer.multiplayer_peer = peer
	_set_state(State.HOSTING)
	return true


func join(address: String, port: int = 12000) -> bool:
	_stop()
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port)
	if err != OK:
		push_warning("Networking.join: create_client failed: %d" % err)
		peer = null
		_set_state(State.OFFLINE)
		return false
	multiplayer.multiplayer_peer = peer
	_set_state(State.CONNECTING)
	return true


func disconnect_peer() -> void:
	_stop()
	_set_state(State.OFFLINE)


func attach_world(world: World) -> void:
	replicated_world = world
	_sync_elapsed = 0.0


func detach_world(world: World = null) -> void:
	if world == null or replicated_world == world:
		replicated_world = null


func is_online() -> bool:
	return state == State.ONLINE or state == State.HOSTING or state == State.CONNECTING


func is_server() -> bool:
	return state == State.HOSTING


func _stop() -> void:
	if peer != null:
		peer.close()
		peer = null
	if multiplayer and multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer = null
	_sync_elapsed = 0.0


func _set_state(s: int) -> void:
	state = s
	state_changed.emit(s)


func _process(delta: float) -> void:
	if state == State.CONNECTING and peer != null:
		if peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
			_set_state(State.ONLINE)
	if not is_server() or replicated_world == null:
		return
	_sync_elapsed += delta
	if _sync_elapsed < maxf(sync_interval, 0.02):
		return
	_sync_elapsed = 0.0
	_send_snapshot.rpc(_build_snapshot())


func _build_snapshot() -> Array:
	var snapshot: Array = []
	for unit in replicated_world.get_units():
		if unit == null:
			continue
		snapshot.append({
			"name": str(unit.name),
			"position": unit.global_position,
			"rotation": unit.global_rotation,
			"health": unit.health,
			"supply": unit.supply,
			"fuel": unit.fuel,
			"alive": unit.alive,
			"target_position": unit.target_position,
			"moving": unit.moving,
		})
	return snapshot


@rpc("authority", "call_remote", "unreliable")
func _send_snapshot(snapshot: Array) -> void:
	# The RPC is invoked by the host and delivered to clients. On the host,
	# call_remote prevents this method from applying the snapshot locally.
	if is_server() or replicated_world == null:
		return
	var applied: int = _apply_snapshot(snapshot)
	snapshot_applied.emit(applied)


## Apply a host snapshot to the local world. Pure/testable (no RPC dependency):
## updates matching units, and emits `spawn_requested` for entries with no
## matching local unit so clients can mirror dynamic spawns. Returns the number
## of units updated.
func _apply_snapshot(snapshot: Array) -> int:
	var applied: int = 0
	for state_data in snapshot:
		if not state_data is Dictionary:
			continue
		var unit := _find_unit(str(state_data.get("name", "")))
		if unit == null:
			spawn_requested.emit(state_data)
			continue
		unit.global_position = state_data.get("position", unit.global_position)
		unit.global_rotation = state_data.get("rotation", unit.global_rotation)
		unit.health = float(state_data.get("health", unit.health))
		unit.supply = float(state_data.get("supply", unit.supply))
		unit.fuel = float(state_data.get("fuel", unit.fuel))
		unit.alive = bool(state_data.get("alive", unit.alive))
		unit.target_position = state_data.get("target_position", unit.target_position)
		unit.moving = bool(state_data.get("moving", unit.moving))
		unit.call_deferred("_update_health_bar")
		applied += 1
	return applied


## Build a snapshot of the host's deterministic unit fields. Exposed for tests.
func build_snapshot() -> Array:
	return _build_snapshot()


func _find_unit(unit_name: String) -> Unit:
	if unit_name.is_empty() or replicated_world == null or replicated_world.units_root == null:
		return null
	return replicated_world.units_root.get_node_or_null(NodePath(unit_name)) as Unit
