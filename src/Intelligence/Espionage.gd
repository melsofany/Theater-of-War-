extends Node
## Espionage (autoload) — Phase 9
##
## Manages intelligence agencies, agents, counter-intelligence, surveillance and
## deception. Builds on the Phase 7 Intelligence system:
##
## - **Agents**: a faction deploys an agent into enemy territory. While active
##   the agent performs surveillance — it reveals real enemy units within its
##   vision radius to the owner (medium-confidence contacts that bypass normal
##   sight range).
## - **Counter-intelligence**: each faction has a `counter_intel` rating (0..1).
##   Each tick, every enemy agent has a chance to be detected and neutralized
##   proportional to the target faction's counter-intel. Detected agents are
##   removed.
## - **Deception**: a faction can plant false intelligence (a fake contact) into
##   a victim's memory, misleading its enemy estimates (and thus its AI). The
##   false contact is marked internally; counter-intelligence sweeps can purge
##   it (`Intelligence.purge_deception`).
## - **Information confidence**: contacts carry a confidence (own sightings 1.0,
##   agent reports 0.6, deceptions 0.8 to look credible). The AI acts on the
##   same picture the player sees, so deception can mislead it and
##   counter-intel can reveal it.

@export var agent_vision_radius: float = 40.0
@export var agent_report_confidence: float = 0.6
## Per-tick detection probability = target.counter_intel * this factor.
@export var detection_factor: float = 0.2
## Chance per tick that a faction's counter-intel reveals planted deception.
@export var deception_reveal_factor: float = 0.3

# faction_id -> counter_intel rating (0..1).
var _counter_intel: Dictionary = {}
# Array[Dictionary]: {owner, target, pos, id, active}
var _agents: Array = []
var _next_id: int = 1


func set_counter_intel(faction: Faction, rating: float) -> void:
	if faction == null:
		return
	_counter_intel[faction.name] = clampf(rating, 0.0, 1.0)


func counter_intel(faction: Faction) -> float:
	if faction == null:
		return 0.0
	return _counter_intel.get(faction.name, 0.0)


## Deploy an agent for `owner` watching `target` near `pos`. Returns the agent id.
func deploy_agent(owner: Faction, target: Faction, pos: Vector3) -> int:
	if owner == null or target == null:
		return -1
	var id: int = _next_id
	_next_id += 1
	_agents.append({
		"id": id,
		"owner": owner,
		"target": target,
		"pos": pos,
		"active": true,
	})
	return id


func active_agents(owner: Faction) -> Array:
	var out: Array = []
	for a in _agents:
		if a["active"] and a["owner"].name == owner.name:
			out.append(a)
	return out


func agent_count(owner: Faction) -> int:
	return active_agents(owner).size()


## Plant a false contact (deception) into `victim`'s intelligence memory.
## Returns true on success.
func plant_deception(owner: Faction, victim: Faction, fake_pos: Vector3,
		fake_type: UnitType) -> bool:
	if owner == null or victim == null or fake_type == null:
		return false
	# Deception looks credible (high confidence) but is flagged for counter-intel.
	var key: int = _next_id
	_next_id += 1
	Intelligence.add_contact(victim, key, fake_pos, fake_type, 0.8, true)
	return true


func _process(delta: float) -> void:
	tick(delta)


func tick(delta: float) -> void:
	# 1. Active agents surveil for their owners.
	for a in _agents:
		if not a["active"]:
			continue
		if Intelligence and Intelligence.world:
			Intelligence.reveal_from_agent(a["owner"], a["pos"],
					agent_vision_radius, agent_report_confidence)
	# 2. Counter-intelligence: detect & neutralize enemy agents.
	var still: Array = []
	for a in _agents:
		if not a["active"]:
			continue
		var target_ci: float = counter_intel(a["target"])
		var p: float = target_ci * detection_factor * delta * 10.0
		if randf() < p:
			a["active"] = false  # neutralized
		if a["active"]:
			still.append(a)
	_agents = still
	# 3. Counter-intel deception sweep: each faction may reveal planted deceptions.
	if Intelligence and Intelligence.world:
		for fid in _counter_intel:
			var ci: float = _counter_intel[fid]
			if randf() < ci * deception_reveal_factor * delta * 10.0:
				var f := Faction.new()
				f.name = fid
				Intelligence.purge_deception(f)


func clear() -> void:
	_counter_intel.clear()
	_agents.clear()
