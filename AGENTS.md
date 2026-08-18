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
  Latest: 158 passing / 409 asserts (4 failing — all missing binary assets:
  combat SFX, menu music, menu background, unit icons; pre-existing, deferred
  to `docs/MANUS_ASSETS_PROMPT.md`). Includes the `tests/test_mega_map.gd`
  suite (26 tests) for the Phase 10c+ mega world map: 14 biomes + terrain
  movement costs, 6 glass cities with district capture-split, civilian flee +
  exodus intel + economy impact, urban guerrilla (cover ×1.8, LOS blocking),
  9-chunk streaming, cut supply routes, OSM road network.
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
to ChunkManager (DONE), deterministic balance regression guard (DONE),
**mega world map (DONE — branch `phase-mega-world`)**: `src/World/MegaWorldGenerator.gd`
(4096² biome grid, 14 biomes, Terrarium elevation decode, terrain movement
costs + `travel_time_seconds`), `src/World/ModernCityGenerator.gd` +
`ModernCity.gd` + `CityDistrict.gd` (6 glass cities incl. "معقل الرماد",
4–6 districts each, MultiMesh glass towers StandardMaterial3D metallic 0.9
roughness 0.1 SSR, 150–400 civilian spawn points, per-district capture so a
city can be split between armies), `src/Units/CivilianNPC.gd` (flee on combat
intensity → exodus intel report + Economy income drop),
`src/Combat/UrbanWarfareSystem.gd` (guerrilla hide/ambush via SpatialGrid,
cover ×1.8, tower LOS blocking, only when a city is split),
`src/World/RoadNetworkGenerator.gd` (OSM/Overpass roads with procedural
fallback; supply trucks depend on them), `Logistics.register_contested_city` /
`is_supply_route_cut` / `supply_travel_time` (base unit speed 4 m/s),
`ChunkManager.configure_for_9_chunks` (Chebyshev square ring → exactly 9).
Terrain3D addon v1.0.0 (Godot 4.3 build) installed at `addons/terrain_3d/`
(minimal: gdextension + linux/windows binaries + editor scripts; NOT enabled
as an editor plugin, and intentionally WITHOUT the 200+ demo EXR assets — the
full Terrain3D release zip overwrites `project.godot` with its demo config, so
extract only `addons/terrain_3d/`). Next: full art/audio pass (external asset
generation), campaigns, true lockstep multiplayer sim, instanced rendering/LOD,
balance playtesting.
- Art/audio hand-off prompt for an external asset agent (Manus) is at
  `docs/MANUS_ASSETS_PROMPT.md` — every path it lists is already referenced by
  the game's runtime loaders (icons, sprites, terrain textures, UI, SFX,
  music). Deferred to the end per the user's instruction.
