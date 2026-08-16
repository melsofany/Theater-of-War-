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

## Phase 8 — AI

- Strategic AI → Operational AI → Tactical AI.
- Decisions based on available information.

## Phase 9 — Espionage

- Intelligence agencies, agents, counter-intelligence, surveillance,
  deception, information confidence.

## Phase 10 and beyond

- Air power, naval power, campaigns.
- Large world.
- Multiplayer.
- Performance optimization.
- Modding.
- Balance.
- Art and audio.

## Status legend

- [x] done  [ ] not started  [~] in progress

| Phase | Status |
| --- | --- |
| 0 — Foundation | [x] |
| 1 — Small RTS Prototype | [ ] |
| 2 — World & Map | [ ] |
| 3 — Units & Combat | [ ] |
| 4 — Command Hierarchy | [ ] |
| 5 — Economy | [ ] |
| 6 — Logistics | [ ] |
| 7 — Intelligence | [ ] |
| 8 — AI | [ ] |
| 9 — Espionage | [ ] |
| 10+ — Air/Naval/Multiplayer/etc. | [ ] |
