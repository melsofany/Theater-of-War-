# Architecture — Theater of War

## Overview

Theater of War is a top-down, theater-level real-time strategy game built on
**Godot 4.3**. The architecture is modular by design: each major game system
lives in its own package, communicates through thin interfaces / signals, and
can be developed, tested and swapped independently.

The guiding principle is **separation of simulation from presentation**. Game
state and rules live in engine-agnostic-style modules (Core, World, Units,
Combat, AI, Economy, Logistics, Intelligence); presentation and interaction live
in UI. Networking (Phase 10+) will sit between simulation and the wire.

## Module map

```
src/
├── Core/          Game session root, selection, factions, clocks
├── World/         Battlefield: terrain, unit container, lookup helpers
├── Units/         Unit + Building entities (movable and static)
├── Combat/        Health / damage / armor / range (Phase 3)
├── AI/            Strategic / Operational / Tactical AI (Phase 8)
├── Economy/       Resources, production, infrastructure (Phase 5)
├── Logistics/     Supply, transport, fuel, ammo, readiness (Phase 6)
├── Intelligence/  Recon, fog of war, intel reports (Phase 7), espionage (Phase 9)
├── UI/            Camera, player controller, HUD, menus
└── Networking/    Multiplayer sync (Phase 10+)

tools/             Headless utilities (project validation, generation)
tests/             GUT unit + scene tests
addons/gut/        Godot Unit Test framework (MIT)
docs/              Design and decision documents
.github/workflows/ CI
```

## Layering (dependency direction)

```
UI ─────────────────────────────────────────────┐
   │                                            │
   v                                            │
Core (GameManager, SelectionManager, Faction)   │
   │                                            │
   v                                            │
World ──> Units ──> Combat                      │
   │           │                                │
   │           v                                │
   │        AI / Economy / Logistics / Intelligence
   │                                            │
   └────────────────────────────────────────────┘
                  Networking (wraps Core/World for sync)
```

- **Core** depends on nothing in `src/` except shared types.
- **World** depends on Core and Units.
- **Units** depend on Core only (faction, selection interface).
- **Combat / AI / Economy / Logistics / Intelligence** depend on Units/World;
  they are consumers, not owned by Units.
- **UI** depends on everything it drives (camera, controller, HUD).
- **Networking** is a transport layer over Core/World; it does not contain game
  rules.

## Autoloads (singletons)

| Name | Purpose |
| --- | --- |
| `GameManager` | Owns the active session: world reference, pause, game speed, elapsed clock. Thin in Phase 0. |
| `SelectionManager` | Owns the current selection set and drag-select rectangle; emits `selection_changed`. |

Autoloads are intentionally few. Systems that need cross-scene access go through
`GameManager.world`, not a forest of singletons.

## Scenes

- `src/UI/MainMenu.tscn` — **main scene**, the project entry screen.
- `src/UI/Main.tscn` — in-game composition: World + RTSCamera +
  PlayerController + HUD.
- `src/World/World.tscn` — ground + units container.
- `src/Units/Unit.tscn` — movable unit (capsule + nav agent + selection ring).
- `src/Units/Building.tscn` — static selectable structure.
- `src/UI/HUD.tscn` — overlay: instructions, selected count, drag rectangle.

## Input

Custom actions defined in `project.godot`:

| Action | Default | Use |
| --- | --- | --- |
| `move_north/south/east/west` | W/A/S/D | camera pan |
| `select` | left mouse | selection / box-select |
| `command` | right mouse | move-to order |

Edge-of-screen panning and mouse-wheel zoom are handled directly by
`RTSCamera`.

## Testing strategy

- **GUT** (Godot Unit Test) for engine-adjacent logic: faction relations,
  selection bookkeeping, camera math, scene load smoke tests.
- Pure data classes (`Faction`, selection helpers) are tested without a scene
  where possible.
- `tools/validate_project.gd` performs a headless load+instantiate of every
  shipped scene, used by CI as a build/integrity gate.
- Later phases add integration tests for combat resolution, supply flow and AI
  decisioning.

## Phasing

Each phase adds a module without disturbing the layers above. Stubs already
exist for `CombatSystem`, `AISystem`, `EconomySystem`, `LogisticsSystem`,
`IntelligenceSystem`, `Networking` so the import graph and folder structure are
stable from day one. See `docs/ROADMAP.md`.
