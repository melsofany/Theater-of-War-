# Theater of War — مسرح الحرب

A theater-level real-time strategy game about commanding military formations at
scale. You issue orders to a chain of command (Army → Corps → Division →
Brigade → Battalion → Company → Platoon) and let it carry them down to the
units — operational depth, logistics and intelligence matter more than click
speed.

Built on **Godot 4.3**. Phases 0 through 10c are implemented, plus the first
10c+ batch: SpatialGrid wired into the intelligence hot path, netcode state
replication made testable with dynamic-spawn detection, and opt-in streaming
terrain rendering wired to ChunkManager. The project builds, boots, and
passes its full test suite (134/134, 324 asserts). See
[`docs/ROADMAP.md`](docs/ROADMAP.md) for the per-phase status.

---

## Status

Implemented to date (Phases 0–10c), each layer independently shippable and
tested:

- **Phase 0–1 — Foundation + small RTS prototype**: Godot 4.3 / GDScript,
  modular architecture (`Core`, `World`, `Units`, `Combat`, `AI`, `Economy`,
  `Logistics`, `Intelligence`, `UI`, `Networking`, `Tools`, `Tests`). Playable
  small-RTS loop: map, RTS camera, selection (click + box-drag + additive),
  group movement with command markers, control groups, HQ with production queue
  + rally point, enemy dummy on patrol, minimap, HUD + main menu. GUT tests +
  headless scene validation in CI.
- **Phase 2 — World & Map**: procedural heightfield terrain, features
  (mountains/plateaus/rivers/roads/bridges), named cities, strategic zones,
  terrain-aware movement with passability + move cost.
- **Phase 3 — Units & Combat**: data-driven `UnitType`, seven unit kinds
  (infantry, vehicle, tank, artillery, air-defense, aircraft, helicopter),
  health/armor/damage/range model, air & naval domains, indirect artillery
  fire, health bars.
- **Phase 4 — Command Hierarchy**: Army → Corps → … → Platoon chain; order one
  node and it propagates to every unit below in formation.
- **Phase 5 — Economy**: per-faction resources (Manpower/Fuel/Materials) +
  capacities, income from owned cities/buildings, production costs, city
  capture.
- **Phase 6 — Logistics**: supply/fuel/readiness, buildings as supply sources,
  cut-off attrition, fuel-burning movement, ammo-gated fire, readiness-scaled
  damage/speed.
- **Phase 7 — Intelligence**: fog-of-war intelligence picture the AI shares with
  the player (never omniscient).
- **Phase 8 — AI**: opponent that acts on the same intelligence picture.
- **Phase 9 — Espionage**: agents, counter-intel, deception (planted false
  contacts), information confidence.
- **Phase 10 — Naval/Air/Campaign/Balance**: naval domain + destroyer, campaign
  objectives (capture cities / eliminate enemy / hold position), win/lose.
- **Phase 10b — Modding/Perf/Balance/Streaming/Multiplayer/Audio foundations**:
  `ModLoader` (JSON unit mods), `SpatialGrid`, `Balance` tunables + difficulty
  presets, `ChunkManager` chunk math, `Networking` host/join state machine,
  `AudioManager`.
- **Phase 10c — Spatial/networking/mod integration + asset pipeline/wiring**:
  ModLoader/Networking/World integration, plus an external asset contract that
  produced and wired menu music, combat SFX, 26 unit icons, and a menu
  background.

## Project layout

```
src/        Game modules (Core, World, Units, Combat, AI, Economy,
            Logistics, Intelligence, UI, Networking)
tools/      Headless utilities (project validation)
tests/      GUT unit + scene tests
addons/gut/ Godot Unit Test framework (MIT)
docs/       Design + decision documents
.github/    CI workflow
```

## Requirements

- **Godot 4.3 stable** (standard build). Download from
  <https://godotengine.org/download> or the
  [godot-builds releases](https://github.com/godotengine/godot-builds/releases).
- For CI / headless: the Linux x86_64 binary is sufficient.

## Run the project

Open in the editor:

```bash
godot --path .
```

Launch the game directly (skips the editor):

```bash
godot --path .   # opens MainMenu as the main scene
```

The project boots into the **Main Menu**. Choose **New Game** to enter the
prototype battlefield.

### Controls

| Input | Action |
| --- | --- |
| Left mouse | Select unit/building / begin box-drag |
| Left mouse + Shift | Add to / toggle selection |
| Right mouse | Move selected units |
| W / A / S / D | Pan camera |
| Mouse at screen edge | Pan camera |
| Mouse wheel | Zoom |
| Ctrl + 1..9 | Assign control group |
| 1..9 | Recall control group |
| B | Queue unit from selected HQ |
| Y | Set HQ rally point at cursor |
| H | Focus camera on current selection |

## Tests

```bash
# Run the GUT test suite headless
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit

# Validate every scene loads + instantiates headless
godot --headless --script tools/validate_project.gd
```

## CI

GitHub Actions (`.github/workflows/ci.yml`) installs Godot 4.3, imports the
project headless, runs GUT, and validates scenes on every push / pull request.

## Documentation

- [Game Design](docs/GAME_DESIGN.md)
- [Architecture](docs/ARCHITECTURE.md)
- [Roadmap](docs/ROADMAP.md)
- [Engine Decision](docs/ENGINE_DECISION.md)
- [AI Design](docs/AI_DESIGN.md)
- [Technical Decisions](docs/TECHNICAL_DECISIONS.md)

## License

Project source is proprietary to the author unless stated otherwise. The bundled
`addons/gut/` testing framework retains its own MIT license (see
`addons/gut/LICENSE.md`).
