# Theater of War — Agent Memory

RTS game built in **Godot 4.3 (GDScript)**. Each phase lives on its own branch
(`phase-0-foundation` … `phase-10b-modding-perf-balance`). No pull requests are
opened; branches are pushed directly.

## Architecture

- Engine: Godot 4.3, GDScript. Modules under `src/`: Core, World, Units, Combat,
  AI, Economy, Logistics, Intelligence, UI, Networking, (Tools).
- Autoloads (project.godot): GameManager, SelectionManager,
  ControlGroupManager, Economy, UnitFactory, ModLoader, Balance, AudioManager,
  CommandTree, Logistics, Intelligence, AIController, Espionage, Networking,
  Campaign.
- Tests: GUT, `tests/*.gd`, run via
  `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`.
  Latest: 117 passing / 252 asserts.
- Scene validation: `godot --headless --script tools/validate_project.gd`.
- Godot binary expected at `$HOME/godot/godot` (add to PATH).

## Key conventions

- GDScript: tabs for indentation, static types with `:=`/explicit types,
  `class_name` for non-autoload modules (autoloads use `extends Node` + global
  name).
- Stats are data in `UnitFactory` presets; tuning is a data edit. Mods load via
  `res://mods/*.json` → `UnitFactory.register_from_dict`.
- The AI reads the same fog-of-war Intelligence picture as the player (never
  omniscient); deception (Phase 9) can mislead it and counter-intel can reveal.
- Combat damage/armor go through `Balance` multipliers.

## Encoding note

`docs/ROADMAP.md` uses real UTF-8 em-dashes (`—` U+2014) and arrows (`→`).
The file_editor `view` tool may *display* these as mojibake (`â€"`), but the raw
bytes are correct. Edit this file with Python (`io.open(..., encoding='utf-8')`)
using `\u2014` / `\u2192` literals to avoid str_replace mismatches.

## Phase status

Phases 0–10b complete and pushed. Next (10c+): streaming terrain rendering wired
to ChunkManager, multiplayer state replication, art/audio assets.
