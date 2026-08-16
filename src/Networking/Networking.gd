extends Node
## Networking (autoload) — Phase 10b (multiplayer foundation)
##
## Host/join foundation using Godot's high-level multiplayer (ENet). This phase
## provides connection setup and a session state machine; full state replication
## (unit sync, deterministic simulation, lockstep) is a later pass.
##
## States: OFFLINE -> HOSTING (as server) or CONNECTING -> ONLINE -> OFFLINE.

enum State { OFFLINE, HOSTING, CONNECTING, ONLINE }

var state: int = State.OFFLINE
var peer: ENetMultiplayerPeer = null
signal state_changed(new_state: int)


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


func _set_state(s: int) -> void:
	state = s
	state_changed.emit(s)


func _process(_delta: float) -> void:
	# Promote a connecting client to ONLINE once the connection is established.
	if state == State.CONNECTING and peer != null:
		if peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
			_set_state(State.ONLINE)

