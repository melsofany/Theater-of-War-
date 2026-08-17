# Roadmap — Theater of War

A phased delivery plan. Each phase is independently shippable and builds on the
previous. Phase 0 establishes the foundation; phases 1–10+ add the depth that
defines the game.

## Phase 0 — Project Foundation (complete)

- Engine decision and documentation.
- Modular architecture (Core / World / Units / Combat / AI / Economy / Logistics
  / Intelligence / UI / Networking / Tools / Tests).
- Minimal bootable prototype: map, RTS camera, unit selection, movement, group
  move, building, enemy dummy, basic UI.
- Main menu entry screen, HUD overlay.
- Test framework (GUT) + CI.
- `.gitignore`, no secrets.

**Exit criteria:** builds, launches, tests pass, ready for Phase 1. ✅

## Phase 1 — Small RTS Prototype (complete)

- Polished map with grid overlay and clamped bounds.
- RTS camera tuning: smooth lerp panning, edge pan, clamped zoom, focus-on.
- Unit selection refinement: single click + box drag + additive (Shift).
- Movement and group movement with formation spread + command markers.
- Unit grouping: control groups Ctrl+1..9 assign / 1..9 recall.
- Building: HQ with production queue (B), rally point (Y), spawn-on-finish.
- Enemy dummy behavior: simple patrol loop between waypoints.
- Basic UI polish: minimap, selection/building status panel, expanded HUD help.
- Tests added for control groups + building production.

**Exit criteria:** small, stable RTS loop; ready for Phase 2. ✅

## Phase 2 — World & Map (complete)

- Procedural heightfield terrain (layered simplex noise) rendered as an
  `ArrayMesh` with trimesh collision.
- Feature layers: mountains (impassable ridge), plateaus (high passable
  ground), winding river (impassable water), roads (faster movement),
  bridges (water crossing points).
- Cities: named markers placed on the terrain, height-following.
- Strategic zones: rectangular objectives rendered as translucent overlays.
- Terrain-aware units: follow ground height, slow on costly ground, stop at
  impassable terrain; camera picks terrain points for orders.
- `MapData` (pure data) + `TerrainGenerator` (procedural) keep world logic
  testable without a scene tree.

**Exit criteria:** data-driven world with passability + move cost; ready for Phase 3. ✅

## Phase 3 — Units & Combat (complete)

- Data-driven `UnitType` resource (health, armor, damage, range, sight, speed,
  domain GROUND/AIR, category, attack flags, indirect fire).
- `UnitFactory` autoload: seven unit kinds — infantry, vehicle, tank, artillery,
  air defense, aircraft, helicopter — each with tuned stats.
- Health / Damage / Armor / Range / Movement model: `take_damage` (min 1 after
  armor), `die` (emits `died`, deselects, hides), `heal`; auto-target
  acquisition within sight range; cooldown-gated fire; stop-to-shoot.
- Air domain: aircraft/helicopters fly at cruise altitude, ignore terrain
  passability; air defense and air units can attack air; ground-only units
  cannot hit air.
- Artillery: long-range indirect fire.
- Health bars above units (colour-coded, shown when damaged/selected).
- Buildings produce typed units (`produced_unit_key`).
- Tests: +13 (unit types, combat damage/armor/death/heal/range) ->
  43 passing / 105 asserts.

**Exit criteria:** full combat model with all seven unit categories; ready for Phase 4. ✅

## Phase 4 — Command Hierarchy (complete)

- `CommandNode` (RefCounted): echelon enum (Army → Corps → Division → Brigade →
  Battalion → Company → Platoon), parent/children, leaf platoons hold Unit
  instances. `order_move` / `order_attack` / `order_stop` propagate to every
  unit below, distributed across a grid formation so a brigade moves spread out.
- `CommandTree` autoload: builds the player's hierarchy at game start (Army →
  Corps → Division → Brigade → Platoons of ≤4 units), tracks the active command
  node, `promote`/`drill` to move up/down echelons, `select_node_of(unit)`.
- PlayerController keys: **V** select the command node of the current selection;
  **[** / **]** promote / drill the active echelon. Right-click issues a move
  order to the whole active node (formation) when a selected unit belongs to it.
- HUD shows the active command path (e.g. "1st Army → I Corps → … → 2nd Platoon")
  and unit count.
- Tests: +6 (tree shape, unit collection, order propagation + formation spread,
  find_containing, promote/drill, path string) → 49 passing / 123 asserts.

**Exit criteria:** give an order to a brigade instead of moving each unit manually; ready for Phase 5. ✅

## Phase 5 — Economy (complete)

- `Economy` autoload: per-faction resource stores (Manpower, Fuel, Materials)
  with capacities, per-second income from owned infrastructure, `can_afford` /
  `spend` / `credit` / `recompute_income`.
- `UnitFactory.cost_of(key)`: production cost per unit type (manpower/fuel/
  materials) — production is blocked when a faction can't afford it.
- City ownership & capture: `City.owner_faction`, `capture(faction)`; cities
  grant manpower + materials income; `World.get_cities()`. A unit moving within
  3 m of a city captures it for its faction; income is recomputed on capture.
- Buildings add fuel income and materials/fuel storage capacity.
- PlayerController: registers factions with starting resources, assigns the
  nearest city to the player (rest to enemy), checks affordability before
  queuing production and spends on success.
- HUD: `ResourceLabel` shows live Manpower/Fuel/Materials + income rates.
- Tests: +8 (affordability, spend deduction/block, capacity clamp, income
  accumulation, production costs) → 57 passing / 135 asserts.

**Exit criteria:** resources + production costs + city-based income; ready for Phase 6. ✅

## Phase 6 — Logistics (complete)

- `Logistics` autoload: per-unit supply/fuel state and readiness. Buildings are
  supply sources; units within `supply_radius` of a friendly building are
  resupplied over time, cut-off units slowly attrition. `is_in_supply(unit)`.
- `UnitType`: `max_supply`, `max_fuel`, `fuel_per_move`, `ammo_per_shot`.
- `Unit`: `supply`/`fuel`/`readiness` state; `_apply_type` initialises them;
  `compute_readiness()` = 0.2 + 0.4·supply_norm + 0.4·fuel_norm scaled by health.
  Movement burns fuel (grounded when fuel ≤ 0; air units stop). Firing consumes
  ammo and is blocked when out of supply; damage scales by readiness. Move speed
  scales by readiness.
- HUD: `LogisticsLabel` shows selected unit's supply/fuel/readiness + supply
  status (in supply / cut off).
- Tests: +9 (readiness full/low, fire consumes ammo + scales damage, fire
  blocked without ammo, resupply near building, attrition when cut off, in/out
  of supply) → 65 passing / 145 asserts.

**Exit criteria:** supply → transportation (range) → fuel → ammunition → readiness; ready for Phase 7. ✅

## Phase 7 — Intelligence (complete)

- `Intelligence` autoload: per-faction fog of war. Enemy unit states: VISIBLE
  (a friendly unit within `sight_range` or a friendly building within
  `building_vision_radius`), REMEMBERED (last-known position held for
  `remember_seconds` sim-time then decayed), UNKNOWN.
- `UnitType.sight_range` (recon range, already in presets 18–55).
- API: `is_visible(faction, enemy)`, `visible_enemies_of(faction)`,
  `last_known_position(faction, enemy)`, `enemy_estimate(faction)` (category →
  count from sightings), `report(faction)` (human-readable summary). Sim-time
  clock for deterministic decay.
- Integration: target acquisition is sight-gated (units only fight what they
  see); `PlayerController._apply_fog_of_war()` hides enemy visuals the player
  cannot see (unit stays active). HUD `IntelLabel` shows contacts/estimates.
- Tests: +7 (out-of-sight invisible, in-sight visible, tick records visible +
  remembered, last-known decays, enemy estimate by category, friendlies not
  counted, report non-empty) → 72 passing / 156 asserts.

**Exit criteria:** reconnaissance → fog of war → intelligence reports → enemy estimates; ready for Phase 8. ✅

## Phase 8 — AI (complete)

Three cooperating layers, mirroring military doctrine. The AI consumes the same
fog-of-war intelligence as the player — it never reads information it could not
have.

- **`AIStrategy`** (pure, testable decision logic): given a situation snapshot
  (own_force, enemy_force from intelligence estimates, avg_readiness, own
  buildings, known enemy positions) returns a decision with a `Posture`
  (OFFENSIVE / DEFENSIVE / REGROUP) and an objective:
  - OFFENSIVE when force ratio >= 1.3 and readiness >= 0.5 -> nearest known
    enemy position.
  - DEFENSIVE when ratio <= 0.7 or readiness <= 0.3 -> centroid of own
    buildings.
  - REGROUP otherwise -> rally point.
  Thresholds are data, not magic numbers.
- **`AIController`** autoload (three layers):
  - Strategic: throttled think_interval; builds the snapshot from
    `Intelligence` (enemy estimates + visible/last-known positions), Economy and
    Logistics readiness; asks `AIStrategy.decide`.
  - Operational: issues `move_to` orders toward the strategic objective (with
    formation jitter); skips units already in contact.
  - Tactical: each tick, badly damaged units (health < 25%) retreat away from
    the nearest visible enemy. Units otherwise auto-engage visible enemies
    (sight-gated combat, Phase 3/7).
- `World.get_factions()` added (derives factions from units/buildings).
- Tests: +9 (offensive/defensive/regroup posture selection, objective = nearest
  enemy, objective = building centroid, force-ratio computation, controller
  snapshot+decision, tactical retreat, offensive move order) -> 82 passing /
  171 asserts.

**Exit criteria:** Strategic -> Operational -> Tactical AI deciding on available
information; ready for Phase 9.

## Phase 9 — Espionage (complete)

Builds on Phase 7 Intelligence. Agencies, agents, counter-intelligence,
surveillance, deception and information confidence.

- **`Espionage`** autoload:
  - **Agents**: `deploy_agent(owner, target, pos)` places an agent; while active
    it surveils — `Intelligence.reveal_from_agent` reveals real enemy units
    within `agent_vision_radius` as medium-confidence contacts, bypassing normal
    sight range.
  - **Counter-intelligence**: per-faction `counter_intel` rating (0..1). Each
    tick an enemy agent has a detection chance = `target.counter_intel *
    detection_factor`; detected agents are neutralized (removed).
  - **Deception**: `plant_deception(owner, victim, fake_pos, fake_type)` inserts
    a false contact into the victim's intelligence memory (flagged internally),
    misleading its enemy estimates and thus its AI. Looks credible (0.8
    confidence).
  - **Counter-intel sweep**: each tick a faction may `Intelligence.purge_deception`
    (reveal planted false intel) with chance based on its counter-intel.
  - **Information confidence**: contacts carry confidence (own sightings 1.0,
    agent reports 0.6, deceptions 0.8). The AI acts on the same picture the
    player sees, so deception can mislead it and counter-intel can reveal it.
- `Intelligence` extended: `add_contact`, `reveal_from_agent`, `purge_deception`,
  `has_deception`, confidence + deception flags on memory entries.
- PlayerController sets counter-intel ratings for both factions.
- Tests: +7 (agent reveals beyond sight, counter-intel neutralizes agent, low
  CI keeps agent, deception plants false contact, deception flagged+purgeable,
  confidence differs by source, counter-intel tick purges deception) -> 89
  passing / 187 asserts.

**Exit criteria:** agencies, agents, counter-intelligence, surveillance,
deception, information confidence; ready for Phase 10.

## Phase 10 — Naval, Air, Campaigns, Balance (subset complete)

A bounded subset of the broad Phase 10 scope. The remaining items (large world,
multiplayer, performance pass, modding, art/audio) are tracked as future work.

- **Naval domain**: `UnitType.Domain.NAVAL` added; `is_naval()`. `Destroyer`
  preset (high HP, naval-only). Naval units use `_naval_step` — they move on
  water and stop at the shoreline (`World.is_water_at`); land is impassable for
  them. `World.is_water_at` helper added.
- **Air power**: aircraft/helicopters (Phase 3) already ignore terrain at cruise
  altitude and can attack air; the air domain is complete for this scope.
- **Campaign objectives** (`Campaign` autoload): `CAPTURE_CITIES`,
  `ELIMINATE_ENEMY`, `HOLD_POSITION` (accumulates hold time, resets when units
  leave). Win when all of a faction's objectives complete; lose when the enemy
  wins. PlayerController sets a default campaign (capture all cities +
  eliminate enemy). HUD shows objective progress / WON / LOST.
- **Balance**: stats are data in `UnitFactory` presets (costs, HP, armor, damage,
  range, sight, speed); tuning is a data edit, not code.
- Tests: +10 (destroyer domain, naval moves on water, naval stops at shore,
  is_water_at, capture cities done/not-done, eliminate enemy, hold accumulates,
  hold resets, multi-objective all-required) -> 99 passing / 202 asserts.

## Phase 10b — Modding, Performance, Balance, Streaming, Multiplayer, Audio (foundation complete)

Foundation layers for the remaining Phase 10 areas; each is bounded and tested.

- **Modding** (`ModLoader` autoload): data-driven unit definitions loaded from
  `res://mods/*.json` (and `user://mods/` at runtime) into `UnitFactory`.
  `UnitFactory.register_from_dict` builds a `UnitType` from a JSON dictionary.
  A `mods/sample_units.json` ships two example types (heavy_tank, frigate).
  Adding/rebalancing units is now a data edit, not code.
- **Performance** (`SpatialGrid`): uniform-grid spatial index over unit
  positions; `query_radius`, `insert`, `remove`, `update` touch only overlapping
  cells — avoids O(n²) full-list scans for proximity/nearest queries.
- **Balance** (`Balance` autoload): tunable multipliers (damage, armor, income,
  cost, supply/fuel consumption) + difficulty presets (easy/normal/hard). Combat
  damage/armor read these at application; balance is a data edit.
- **Large world / streaming** (`ChunkManager`): pure chunk-load math — given a
  focus position and view radius, computes the active chunk set and returns
  loaded/unloaded diffs. Streaming rendering wired in a later pass.
- **Multiplayer** (`Networking` autoload): host/join foundation via ENet + a
  session state machine (OFFLINE/HOSTING/CONNECTING/ONLINE). Full state
  replication (unit sync, deterministic sim) is a later pass.
- **Audio** (`AudioManager` autoload): play SFX/music by name from
  `res://assets/audio/`; no-op when assets are missing so the game runs without
  them. Asset pipeline deferred to the art pass.

## Phase 10c — Asset pipeline + asset wiring (complete)

External generation integrated via a shared-Git asset contract (no live
agent-to-agent API; the repo is the integration layer).

- **Asset pipeline** (`docs/ASSET_PIPELINE.md`, `ASSET_REQUESTS.md`): roles,
  access setup, exact placement/naming/format contract, the produce→wire loop,
  and license terms. An external generator (Manus) reads requests, produces
  files, and commits them to the `assets` branch; OpenHands pulls and wires.
- **Generated assets** (committed on `assets` branch, merged here): menu music,
  6 combat SFX, 26 unit-type icons, menu background.
- **Wiring**: `AudioManager` lazily initializes its player pool and is robust to
  early calls. `MainMenu` plays menu music on entry and stops it on game start.
  `Unit` plays the per-category fire SFX on attack and the explosion SFX on
  death. `UnitType.key` is set at registration and drives the HUD selection
  icon (`HUD.SelectionIcon` loads `res://assets/icons/units/<key>.png`).
- **Validation**: `validate_project.gd` remains clean; the audio autoload is
  resolved via tree path so scene-attached scripts compile in headless checks.
- **Spatial/Networking/Mod integration** (merged from the parallel 10c
  foundation track): `ModLoader` resolves mod unit keys; `Networking` gains the
  session state machine + host/join helpers; `World` exposes spatial query
  helpers; `Unit` wires into the networking/integration paths.
- **Tests**: 124 passing / 295 asserts (verified on the consolidated branch),
  including asset existence + load, key-wiring (`tests/test_phase10c_assets.gd`),
  and the Phase 10b suite (modloader, register_from_dict incl. naval/air
  defaults, spatial grid, balance, chunk math, networking states).

### Future work

- Streaming terrain rendering wired to ChunkManager; campaigns across theaters.
- Multiplayer state replication (unit sync, lockstep/deterministic sim).
- Performance: instanced rendering, LOD, SpatialGrid wired into AI/intel hot paths.
- Modding: data-driven maps/buildings, mod loading from ZIP, mod manifest.
- Balance pass: combat math tuning, economy curves, playtesting.
- Art & audio: models, animations, SFX, music assets.

## Status legend

- [x] done  [ ] not started  [~] in progress

| Phase | Status |
| --- | --- |
| 0 — Foundation | [x] |
| 1 — Small RTS Prototype | [x] |
| 2 — World & Map | [x] |
| 3 — Units & Combat | [x] |
| 4 — Command Hierarchy | [x] |
| 5 — Economy | [x] |
| 6 — Logistics | [x] |
| 7 — Intelligence | [x] |
| 8 — AI | [x] |
| 9 — Espionage | [x] |
| 10 — Naval/Air/Campaign/Balance (subset) | [x] |
| 10b — Modding/Perf/Balance/Streaming/Multiplayer/Audio (foundation) | [x] |
| 10c — Spatial/Networking/Mod integration + asset pipeline/wiring | [x] |
| 10c+ — Streaming terrain rendering, netcode replication, full art/audio pass | [ ] |
