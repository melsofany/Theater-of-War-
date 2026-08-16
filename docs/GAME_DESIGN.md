# Game Design — Theater of War

## Vision

Theater of War is a theater-level real-time strategy game about commanding
military formations at scale. The player does not micromanage every soldier;
they issue orders to formations in a chain of command and let that chain carry
the order down to the individual units. The game rewards operational thinking —
mass, logistics, timing, terrain and intelligence — over click speed.

## Core pillars

1. **Command, not micro.** Orders flow down a hierarchy
   (Army → Corps → Division → Brigade → Battalion → Company → Platoon). The
   player commands at the level they choose; sub-units execute autonomously.
2. **Operational depth.** Terrain, supply lines, fuel, ammunition and readiness
   shape what is actually possible, not just what is on paper.
3. **Information asymmetry.** Fog of war and intelligence confidence mean the
   player acts on imperfect estimates of the enemy. Deception and
   reconnaissance matter.
4. **Scale that respects the player.** Thousands of units are simulated, but the
   interface keeps the player at a manageable decision altitude.

## Player experience

- A **top-down RTS camera** with pan/zoom lets the player survey the theater.
- The player **selects** units or formations (single click or box-drag) and
  **issues move orders** (right-click). Later phases add attack, hold, garrison,
  formation and stance orders.
- A **command hierarchy** (Phase 4) lets the player order a brigade and have its
  battalions/companies distribute the movement automatically.
- **Logistics** (Phase 6) and **intelligence** (Phase 7) panels reveal the
  friction behind every order.

## Setting

Fictional contemporary/near-future warfare. Two opposing forces — **Blue** and
**Red** — contest a theater. The setting is intentionally generic in the
foundation so the systems can be themed later without rework.

## Phase 0 scope (this phase)

A **minimal playable loop** that proves the foundation:

- A flat map with a ground plane.
- An RTS camera (pan, zoom, edge-scroll).
- Unit selection: single-click and box-drag, with a selection ring.
- Unit movement via the NavigationServer (right-click move, formation spread).
- A player building (HQ placeholder) and an enemy dummy unit.
- A main menu entry screen and an in-game HUD overlay.

Everything above the foundation — combat, hierarchy, economy, logistics,
intelligence, AI, espionage, air/naval, multiplayer — is explicitly out of scope
for Phase 0 and stubbed only. See `docs/ROADMAP.md`.

## Controls

| Input | Action |
| --- | --- |
| Left mouse | Select unit / begin box-drag |
| Left mouse + Shift | Add to / toggle selection |
| Right mouse | Move selected units to cursor |
| W / A / S / D | Pan camera |
| Mouse at screen edge | Pan camera |
| Mouse wheel | Zoom in / out |

## Non-goals for Phase 0

- No combat, health or damage.
- No real terrain, rivers or bridges.
- No economy, logistics or intelligence.
- No AI behavior beyond the enemy dummy sitting on the map.
- No multiplayer, no save/load.
