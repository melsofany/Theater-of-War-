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

## Phase 4 — Command Hierarchy

- Army → Corps → Division → Brigade → Battalion → Company → Platoon.
- Order a brigade instead of moving each unit manually; orders propagate down.

## Phase 5 — Economy

- Resources, production, infrastructure.

## Phase 6 — Logistics

- Supply → Transportation → Fuel → Ammunition → Readiness.

## Phase 7 — Intelligence

- Reconnaissance → Fog of War → Intelligence Reports → Enemy Estimates.

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
