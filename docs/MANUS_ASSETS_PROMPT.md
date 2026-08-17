# Manus Prompt — Art & Audio Asset Generation for "Theater of War"

> Paste this whole prompt into Manus (or an equivalent autonomous asset agent)
> to generate the complete art + audio asset set for the Theater of War Godot
> 4.3 RTS. Every path below is the **exact** import path the game already loads
> at runtime; missing assets currently fall back to a soft error (logged, not
> fatal), so producing them turns the placeholder/silent state into a fully
> populated game.

---

## 0. Context you must read first

Before generating anything, read these files in the repo to learn the visual
language, unit roster, and audio cues the code already expects:

- `README.md` — game overview, factions, tone (grounded modern military RTS,
  not cartoonish; olive/tan/grey palette; readable silhouettes at strategy
  zoom).
- `docs/ROADMAP.md` — phase status; the only remaining blocker for a "complete"
  release is this asset pass.
- `src/Units/UnitFactory.gd` — the canonical unit roster and stats. Every unit
  key here has a corresponding icon + sprite path the game loads.
- `src/Units/Unit.gd` — `_fire_sfx_name()` and `_update_health_bar()` show the
  exact SFX keys and the HealthBar visual contract.
- `src/Audio/AudioManager.gd` (or equivalent) — the bus/SFX names the game
  plays (`infantry_fire`, `tank_fire`, `artillery_fire`, `aa_fire`,
  `aircraft_fire`, `explosion`, `ui_click`, `ui_hover`, `music_*`).
- `src/UI/MainMenu.tscn` — needs a background image and menu music.
- `assets/` tree — the target directory; subfolders already exist or must be
  created to match the paths in section 2.

**Rule:** do not invent new paths. Every asset you emit must land at a path the
code already references (listed below). If you need a new path, stop and ask.

---

## 1. Visual style guide (non-negotiable)

- **Tone:** grounded modern military, mid-folfidelity. Think
 Command-and-Conquer-Generals-meets-Wargame: readable from a top-down
  strategy camera, believable up close in a cinematic.
- **Palette:** faction-coloured but muted — Red faction (warm desaturated red
  / rust accents on dark grey-green base), Blue faction (steel blue accents on
  the same dark grey-green base). Terrain: lowland green, plateau tan,
  mountain grey, peak white (matches `_elevation_color()` in
  `src/World/Terrain.gd`). Water: translucent blue `Color(0.15,0.35,0.7,0.75)`.
  Roads: warm grey `Color(0.5,0.45,0.4)`.
- **Silhouettes:** each unit class must be identifiable by silhouette alone at
  ~64×64 px. Tanks = wide hull + long barrel; artillery = long thin barrel +
  small chassis; AA = quad barrels on a light chassis; aircraft = swept wings;
  helicopter = rotor + tail boom; destroyer/frigate = long hull + mast; heavy
  tank = bigger tank with double turret.
- **Faction tint:** apply the faction accent colour as a small decal/stripe or
  a rim-light pass, never as a full-body recolour (must stay readable as the
  base vehicle).
- **Icons vs sprites:** unit **icons** (UI roster panel) are top-down stylised
  on a neutral dark rounded-square background; unit **sprites/in-game models**
  are 3/4-view. Do not reuse the icon as the in-game sprite.
- **Naming:** lowercase, underscores, exactly matching the keys below.

---

## 2. Required asset list (exact paths)

### 2.1 Unit icons — PNG, 256×256, transparent background
Path prefix: `assets/icons/units/`

| File | Unit | Notes |
|---|---|---|
| `infantry.png` | Infantry | single soldier, prone-ready, helmet |
| `vehicle.png` | light vehicle / APC | wheeled, MG on top |
| `tank.png` | Tank (MBT) | classic MBT silhouette |
| `artillery.png` | Artillery (SPG) | long thin barrel, elevated |
| `air_defense.png` | Air Defense (SPAAG) | quad barrels |
| `aircraft.png` | Jet aircraft | swept wings, afterburner |
| `helicopter.png` | Attack helicopter | 5-blade rotor, chin gun |
| `destroyer.png` | Destroyer | long hull, single mast, main gun forward |
| `frigate.png` | Frigate | leaner hull, radar mast |
| `heavy_tank.png` | Heavy tank | bigger MBT, double turret |

### 2.2 Unit sprites / in-game art — PNG, 512×512, transparent, 3/4 view
Path prefix: `assets/sprites/units/`
Same filenames as 2.1 (the in-game 3/4 render, not the icon). Provide a
**red** and a **blue** variant of each by tinting the accent pass:
`<name>_red.png` and `<name>_blue.png` (e.g. `tank_red.png`, `tank_blue.png`).
The base `<name>.png` may be the neutral/grey version.

### 2.3 Terrain / map textures — PNG, tileable, 512×512
Path prefix: `assets/textures/terrain/`
`grass.png`, `plateau_dirt.png`, `mountain_rock.png`, `snow.png`,
`water_normal.png` (translucent normal map for the water overlay),
`road_asphalt.png`. Must tile seamlessly (no visible seams when repeated).

### 2.4 UI art — PNG
Path prefix: `assets/ui/`
- `main_menu_bg.png` — 1920×1080, a strategic map / war-room table look.
- `hud_frame.png` — 9-sliceable command bar frame (centre pixel = scale axis).
- `cursor_default.png`, `cursor_move.png`, `cursor_attack.png`,
  `cursor_select.png` — 32×32 cursors.

### 2.5 Audio — OGG Vorbis
Path prefix: `assets/audio/sfx/`
Each SFX: mono or stereo, ~1–2 s, loop-friendly where noted, normalised to
-1 dBFS peak, no clipping.
- `infantry_fire.ogg` — rifle burst, sharp, dry.
- `tank_fire.ogg` — heavy cannon, deep boom, slight tail.
- `artillery_fire.ogg` — distant howitzer, long tail.
- `aa_fire.ogg` — rapid auto-cannon chatter.
- `aircraft_fire.ogg` — autocannon from a jet, doppler.
- `explosion.ogg` — mixed detonation, 1.5 s tail.
- `engine_idle.ogg` — LOOPABLE, low mechanical drone for vehicle idle.
- `ui_click.ogg`, `ui_hover.ogg` — short UI blips (<0.2 s).
- `alert_under_attack.ogg`, `alert_unit_lost.ogg` — 0.8 s voice-style stingers
  (can be a siren/tone if no VO).

### 2.6 Music — OGG Vorbis, looping
Path prefix: `assets/audio/music/`
- `menu_theme.ogg` — 2–3 min, tense orchestral + subtle electronics, loopable.
- `battle_theme_red.ogg`, `battle_theme_blue.ogg` — 3–4 min each, driving,
  loopable, faction-tinted (red = more aggressive brass, blue = more
  cold/electronic).
- `action_stinger.ogg` — 5 s hit when combat spikes.

---

## 3. Technical constraints (Godot 4.3 import)

- PNGs: import as `CompressedTexture2D`, **Filter** on for sprites/icons,
  **Nearest** only if a deliberately pixel-art look is chosen (it is not — use
  Filter). Keep `hdr` off for UI/terrain PNGs.
- OGG: import as `AudioStreamOggVorbis`, set **Loop** true for `engine_idle`,
  all `music/*`, and `*_fire` are one-shot (loop off).
- No external fonts/textures beyond what's listed. No shaders required (the
  game already has its material setup; just supply textures).
- File sizes: keep each sprite ≤ 300 KB, each icon ≤ 80 KB, each OGG ≤ 1.5 MB
  (use ~128 kbps for music, ~96 kbps for SFX). The repo must stay lightweight.
- Place a `.gdignore`-free import: let Godot generate `.import` files on first
  open — do not hand-edit `.import` files.

---

## 4. Definition of done (per asset)

An asset is "done" when:
1. It exists at the exact path in section 2.
2. It opens without error in Godot 4.3 (no missing-loader warnings).
3. It matches the style guide in section 1.
4. The relevant runtime path no longer logs a "failed to load" soft error
   (verify by booting the game headless and checking the log).

When **all** assets in section 2 are done, run:
```
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit
```
The suite must still report **134/134 passing** (assets don't change test
logic, but this confirms no import broke a scene). Then run:
```
godot --headless --path . --script tools/validate_project.gd
```
It must still print `VALIDATE: OK`.

---

## 5. Hand-back

When finished, open a PR titled **"Art & audio asset pass"** with:
- the full `assets/` diff,
- a screenshot sheet (icons grid, sprites grid, terrain tiles, UI),
- confirmation that the headless test suite + validate_project both pass,
- a list of any path you could not satisfy and why.

Do not mark this prompt's work complete until the game boots with zero "failed
to load icon/SFX/music/scene" soft errors in the log.
