# Engine Decision — Theater of War

## Decision

**Godot Engine 4.3 (stable)** is the game engine for Theater of War.

Development is done primarily in **GDScript**. Performance-critical systems
(pathfinding bottlenecks, large-scale simulations) may later move to C# or
GDExtension (C++), but only when profiling justifies it.

## Candidates evaluated

| Engine | Verdict |
| --- | --- |
| **Godot 4** | Selected — best fit, see below. |
| Unity (C#) | Rejected — capable, but non-open-source licensing and heavier
runtime conflict with a project that wants long-term, mod-friendly, free
tooling. The Personal edition licensing/reporting obligations are unwelcome for
an open project. |
| Unreal Engine 5 | Rejected — AAA rendering fidelity is unnecessary for a
top-down theater-level RTS at this stage; UE's build weight, C++ complexity and
licensing/royalty model are disproportionate for the foundation phase. |
| Custom engine (Python / pygame) | Rejected — cannot scale to the thousands of
units, large terrain and multiplayer the roadmap requires. Acceptable only for
quick standalone tooling, never for the game runtime. |
| Bevy (Rust, ECS) | Rejected — promising and fast, but the ecosystem is still
maturing; fewer ready-made navigation/terrain/UI building blocks than Godot,
which would slow the early phases. |

## Why Godot 4

1. **Open source, no licensing friction.** MIT-licensed engine, no royalties, no
   seat limits, no reporting thresholds. Matches an open, mod-friendly project.
2. **Strong fit for RTS needs.**
   - `NavigationAgent3D` / `NavigationServer3D` give unit pathfinding out of the
     box — essential for an RTS and costly to build well from scratch.
   - `TileMap`/`Terrain3D`-style tooling maps directly onto the Phase 2 world
     (terrain, rivers, bridges, strategic zones).
   - Node/scene architecture mirrors the planned module decomposition
     (Core/World/Units/Combat/...), keeping the codebase organized.
3. **2D + 3D in one engine.** Theater of War is 3D viewed top-down, but menus,
   minimaps, intel overlays and the HUD are 2D. Godot handles both natively.
4. **GDScript iteration speed.** Rapid prototyping matters in the foundation
   phase; GDScript compiles instantly and integrates tightly with the editor.
   C# remains available for hot paths.
5. **Headless mode + CLI.** `godot --headless` lets us import resources, run
   tests (GUT) and validate scenes in CI without a GPU — critical for the
   GitHub Actions pipeline and for "build successfully / launch successfully"
   acceptance criteria in a headless container.
6. **Built-in high-level multiplayer.** Phase 10+ multiplayer (RPC + ENet) is
   available without bringing in a third-party netcode stack.
7. **Cross-platform.** Linux/Windows/macOS export targets cover development and
   distribution.
8. **Lightweight and fast to boot.** The editor and runtime start quickly,
   keeping the feedback loop tight.

## Trade-offs acknowledged

- **Ecosystem depth vs Unity/Unreal.** Fewer off-the-shelf AAA assets. We accept
  this because the roadmap favors systems-driven simulation over asset density.
- **Multiplayer maturity.** Godot's high-level multiplayer is adequate for our
  scale but less battle-tested than dedicated netcode libraries. We defer the
  real decision to Phase 10; nothing in the foundation commits us irreversibly.
- **Large-world streaming.** Godot 4 has no first-class world-streaming solution
  on the scale of Unreal's World Partition. Phase 2's large maps may need chunk
  streaming built on `ResourceLoader.load_threaded_*`; this is a known, bounded
  problem and does not affect the Phase 0 foundation.

## Versioning

- Engine: **Godot 4.3.stable** (pinned).
- CI downloads the same pinned binary, so local and CI environments match.

## How to run

```bash
godot --path .                # editor
godot --path . --headless     # headless runtime / CI
```
