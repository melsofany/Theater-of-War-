# Technical Decisions — Theater of War

A log of the engineering decisions behind the foundation and the reasoning for
each. Future phases should append here rather than rewrite history.

## 1. Engine: Godot 4.3

See `docs/ENGINE_DECISION.md`. Open source, MIT-licensed, strong RTS-relevant
tooling (NavigationServer, TileMap/Terrain, high-level multiplayer), fast
iteration in GDScript with C# available for hot paths.

## 2. Primary language: GDScript

- Fast iteration in the foundation phase.
- Tight editor integration.
- C# / GDExtension reserved for profiled hot paths later (e.g. large-pathfinding
  or mass simulation). No premature optimization.

## 3. Module layout: one package per game system

`src/{Core, World, Units, Combat, AI, Economy, Logistics, Intelligence, UI,
Networking}`. Each system is a folder with its scripts and scenes. Stubs exist
for systems not yet implemented, so the import graph and CI coverage are stable
from Phase 0.

## 4. Simulation / presentation separation

Game state and rules live in Core/World/Units/Combat/etc. Presentation
(camera, HUD, menus) lives in UI and only reads/writes simulation state through
defined entry points. This makes headless testing and (later) headless
multiplayer servers natural.

## 5. Minimal autoloads

Only `GameManager` and `SelectionManager` are autoloads. Cross-system access
goes through `GameManager.world`, avoiding a tangle of singletons. Systems that
need a session reference receive it explicitly.

## 6. Signals for decoupling

Selection changes, game start/pause/speed changes are broadcast via signals.
Consumers connect rather than poll. This keeps modules independent and testable.

## 7. Navigation via NavigationServer3D

Units use `NavigationAgent3D` for pathfinding. This avoids hand-rolling a
pathfinder and gives us steering, avoidance knobs and region baking for free —
critical when terrain (Phase 2) complicates the navigable surface.

## 8. Testing: GUT + headless scene validation

- `addons/gut/` provides the unit-test framework.
- `tests/` holds unit tests for engine-adjacent logic.
- `tools/validate_project.gd` headlessly loads+instantiates every scene as a
  build/integrity gate.
- CI runs both. See `.github/workflows/ci.yml`.

## 9. CI: GitHub Actions with pinned Godot binary

CI installs the same Godot 4.3 stable binary the project targets, imports
resources headless, runs GUT, then validates scenes. No GPU required. The
engine version is pinned so local and CI environments match.

## 10. Version control hygiene

- `.gitignore` excludes `.godot/`, `*.import`, export configs, build artifacts,
  IDE folders and **secrets** (`.env`, keys, credentials).
- No secrets, tokens or credentials are committed. The repo is safe to make
  public.
- Third-party code (GUT) is vendored under `addons/` with its MIT license
  retained, rather than fetched at build time, so the build is reproducible.

## 11. Phasing discipline

Each phase is independently shippable. Later-phase systems are stubbed, not
omitted, so the architecture is exercised from day one. We do not implement
ahead of the roadmap (no advanced AI, multiplayer, combat, espionage, economy,
massive terrain or thousands of units in Phase 0).

## 12. Rendering: Forward+ at default quality

Godot's Forward+ renderer is the default. MSAA 2x is enabled for crispness.
Renderer choice is revisitable; for a top-down RTS with moderate scene
complexity, Forward+ is a safe default. Rendering layers are named
(`Default`, `Units`, `Terrain`) to keep selection/click picking organized.
