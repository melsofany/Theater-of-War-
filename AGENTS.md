# Theater of War — Agent Memory

RTS game built in **Godot 4.3 (GDScript)**. The per-phase history lives on
its own branch (`phase-0-foundation` … `phase-10c-assets-wiring`); the
consolidated line of development is the `integration/consolidated` branch,
which merges both parallel Phase 10c tracks (foundation + assets-wiring) into
one tree. No pull requests are opened; branches are pushed directly.

## Architecture

- Engine: Godot 4.3, GDScript. Modules under `src/`: Core, World, Units, Combat,
  AI, Economy, Logistics, Intelligence, UI, Networking, (Tools).
- Autoloads (project.godot): GameManager, SelectionManager,
  ControlGroupManager, Economy, UnitFactory, ModLoader, Balance, AudioManager,
  CommandTree, Logistics, Intelligence, AIController, Espionage, Networking,
  Campaign.
- Tests: GUT, `tests/*.gd`, run via
  `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`.
  Latest: 134 passing / 324 asserts (0 failing, 0 pending/risky) — verified on
  the consolidated branch after the Phase 10c merge + the first 10c+ batch
  (SpatialGrid wired into intelligence hot path; netcode state replication
  made testable with dynamic-spawn detection; streaming terrain rendering
  wired to ChunkManager; deterministic balance regression guard).
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

Phases 0–10c complete (the two parallel 10c tracks are merged on
`integration/consolidated`, now also `Main`). 10c+ in progress: SpatialGrid
wired into the intelligence hot path (DONE), netcode state replication made
testable + dynamic-spawn detection (DONE), streaming terrain rendering wired
to ChunkManager (DONE), deterministic balance regression guard (DONE). Next:
full art/audio pass (external asset generation), campaigns, true lockstep
multiplayer sim, instanced rendering/LOD, balance playtesting.
- Art/audio hand-off prompt for an external asset agent (Manus) is at
  `docs/MANUS_ASSETS_PROMPT.md` — every path it lists is already referenced by
  the game's runtime loaders (icons, sprites, terrain textures, UI, SFX,
  music). Deferred to the end per the user's instruction.
