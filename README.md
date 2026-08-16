# Theater of War — مسرح الحرب

A theater-level real-time strategy game about commanding military formations at
scale. You issue orders to a chain of command (Army → Corps → Division →
Brigade → Battalion → Company → Platoon) and let it carry them down to the
units — operational depth, logistics and intelligence matter more than click
speed.

Built on **Godot 4.3**. This repository is at **Phase 0 — Project Foundation**.

---

## Status

Phases 0–1 deliver a stable, tested, bootable small-RTS foundation:

- Engine chosen and documented (Godot 4.3, GDScript).
- Modular architecture: `Core`, `World`, `Units`, `Combat`, `AI`, `Economy`,
  `Logistics`, `Intelligence`, `UI`, `Networking`, `Tools`, `Tests`.
- Playable small-RTS prototype: map, RTS camera, selection (click + box-drag +
  additive), group movement with command markers, control groups, a building
  (HQ) with a production queue + rally point, an enemy dummy on patrol, a
  minimap, HUD + main menu.
- Test framework (GUT) and headless scene validation, running in CI.

See [`docs/ROADMAP.md`](docs/ROADMAP.md) for the full plan.

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
