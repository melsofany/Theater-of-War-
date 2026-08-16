# Phase 10c — Integration Foundation

This branch integrates the first executable Phase 10c slice on top of `phase-10b-modding-perf-balance`.

## Implemented

- `World` owns a `SpatialGrid`, registers units as they enter and leave the units container, and exposes radius queries for combat and AI.
- `Unit` updates the spatial index when it moves and uses a radius query instead of scanning every world unit when acquiring a target.
- `Networking` keeps the existing ENet host/join state machine and adds an authoritative, unreliable snapshot stream for stable unit fields: transform, health, supply, fuel, alive state, target position, and movement state.
- `Main` attaches the active world to `Networking` when the gameplay scene starts.
- `ModLoader` continues to support JSON unit definitions and now accepts ZIP packages containing `manifest.json` or `mod.json`; a manifest may contain a `units` array or a single unit definition. Package assets are reserved for later consumers.

## Deliberate limits

This is a foundation pass, not a complete deterministic multiplayer implementation. Dynamic spawn/despawn replication, client prediction, lockstep simulation, conflict resolution, terrain chunk mesh streaming, map/building manifests, and audio asset production remain later work.

## Verification

The repository was checked with Godot 4.3 headless tooling. The GUT suite reports 118 passing tests, and `tools/validate_project.gd` reports that all shipped scenes load and instantiate successfully.
