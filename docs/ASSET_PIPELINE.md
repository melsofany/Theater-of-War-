# Asset Pipeline — OpenHands ↔ Manus

This document is the **contract** for AI-generated assets (audio, graphics,
images) for the *Theater of War* RTS (Godot 4.3, GDScript). An external
generator (Manus) reads this file, produces the requested assets, and commits
them to the repo on the `assets` branch. OpenHands then wires them into the
game code.

**There is no live agent-to-agent API.** The shared Git repository is the
integration layer.

---

## Roles

| Role | Who | Responsibility |
| --- | --- | --- |
| Consumer | OpenHands (this agent) | Writes code, requests assets here, wires assets in. |
| Producer | Manus (external AI) | Reads requests in `ASSET_REQUESTS.md`, produces files, commits them. |

## How Manus gets access (user does this manually)

1. The repo owner creates a **fine-grained personal access token** (GitHub →
   Settings → Developer settings → Personal access tokens → Fine-grained) scoped
   to **only this repository** with **Contents: Read and write**. Do NOT reuse
   any existing system-managed token.
2. Give that token (and this repo URL) to Manus only. Treat it as a secret.
3. Manus works on a dedicated branch: `assets`.

## Asset placement contract (Manus must follow exactly)

```
assets/
├── audio/
│   ├── sfx/        # *.ogg   — sound effects, mono, 44.1kHz
│   └── music/      # *.ogg   — music loops, stereo, 44.1kHz
├── icons/
│   └── units/      # *.png   — 64x64, transparent background, unit-type icons
├── ui/
│   └── *.png       # menu/HUD textures (see requests for sizes)
└── models/
    └── *.glb        # optional 3D unit models (Godot 4 GLTF2)
```

### Naming (consumed by code by exact name)

`AudioManager.play_sfx("<name>")` loads `res://assets/audio/sfx/<name>.ogg`.
`AudioManager.play_music("<name>")` loads `res://assets/audio/music/<name>.ogg`.

So a file named `tank_fire.ogg` in `assets/audio/sfx/` is played by
`AudioManager.play_sfx("tank_fire")`. **No spaces, no uppercase.**

### Format rules

- Audio: **Ogg Vorbis (.ogg)**. SFX mono, music stereo, 44.1kHz, ≤1MB each.
- Icons: **PNG**, transparent background, RGBA8.
- Models: **GLB** (Godot 4 binary glTF), origin at feet, +Y up, scale in meters.
- Do **not** commit `.import` files (auto-generated) or any `.godot/` cache.

## How OpenHands wires assets in (so Manus knows the loop)

1. OpenHands adds/updates a request in `ASSET_REQUESTS.md` (below) and pushes.
2. Manus produces the files, commits to `assets` branch, pushes.
3. OpenHands pulls, runs `godot --headless --import`, then wires:
   - SFX: call `AudioManager.play_sfx("<name>")` at the event point.
   - Music: `AudioManager.play_music("<name>")` from MainMenu/World.
   - Icons: load `res://assets/icons/units/<key>.png` into HUD/unit card.
   - Models: replace the capsule mesh in `Unit.tscn` with the GLB instance.
4. OpenHands runs tests + validate + boot to confirm nothing breaks.

## Current consumers in code (for Manus reference)

- `src/UI/AudioManager.gd` — SFX/music by name.
- `src/Units/Unit.tscn` — currently uses `CapsuleMesh` (placeholder); a `models/<unit_key>.glb` would replace it.
- `src/UI/Main.tscn`, `src/UI/HUD.tscn` — menu/HUD backgrounds.
- Faction colors: `src/Core/Faction.gd` `@export var color`.

## License

All committed assets must be the repo owner's property or a CC0/CC-BY license
the owner is authorized to commit. Manus must not commit copyrighted material.
