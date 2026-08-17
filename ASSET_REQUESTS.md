# Asset Requests

OpenHands lists asset requests here. Manus produces them and commits the files
per `docs/ASSET_PIPELINE.md`, then changes the status from `[ ]` to `[x]`.

Each request is self-contained so Manus needs nothing else.

---

## A-001 — Menu music (first priority)

- [x] produced
- **Path:** `assets/audio/music/menu_theme.ogg`
- **Spec:** 30–90s, stereo, 44.1kHz, looping-friendly, military/strategic mood,
  orchestral-light (strings + brass + soft percussion), no melody dominance so
  it loops unobtrusively. ≤ 2MB.
- **Played by:** `AudioManager.play_music("menu_theme")` in `MainMenu.gd`
  (`src/UI/Main.tscn`).
- **Acceptance:** file exists at the path, loads in Godot 4.3, loops without
  an audible seam.

## A-002 — Combat SFX pack

- [x] produced
- **Paths (one file each):**
  - `assets/audio/sfx/infantry_fire.ogg`
  - `assets/audio/sfx/tank_fire.ogg`
  - `assets/audio/sfx/artillery_fire.ogg`
  - `assets/audio/sfx/aa_fire.ogg`
  - `assets/audio/sfx/aircraft_fire.ogg`
  - `assets/audio/sfx/explosion.ogg`
- **Spec:** mono, 44.1kHz, 0.3–1.2s each, crisp, ≤200KB each.
- **Played by:** `AudioManager.play_sfx(<name>)` in `Unit.gd` at the fire event
  (keyed by unit category) and on death (`explosion`).
- **Acceptance:** each file loads; distinct enough to tell unit types apart.

## A-003 — Unit-type icons

- [x] produced
- **Paths (one file per unit key):**
  infantry, vehicle, tank, artillery, air_defense, aircraft, helicopter,
  destroyer, frigate, heavy_tank → `assets/icons/units/<key>.png`
- **Spec:** 64×64 PNG, transparent background, top-down or 3/4 silhouette,
  readable at small size, single-color faction-neutral outline (white 1px).
- **Used by:** HUD unit cards (`src/UI/HUD.tscn`) and selection panel.
- **Acceptance:** each icon loads at `res://assets/icons/units/<key>.png`.

## A-004 — Main menu background

- [x] produced
- **Path:** `assets/ui/menu_bg.png`
- **Spec:** 1920×1080, wartime landscape / strategic map mood, no text, dark
  enough that white UI text stays readable (overlay tested in `Main.tscn`).
- **Used by:** `MainMenu` background texture.
- **Acceptance:** loads; UI text readable over it.

---

## A-005 — Expanded unit icon pack

- [x] produced
- **Paths:** `assets/icons/units/<key>.png`
- **Unit keys:**
  - `mortar_team` — فريق هاون.
  - `rpg_team` — فريق RPG مضاد للدروع.
  - `heavy_machine_gun_team` — فريق رشاش ثقيل عيار نصف بوصة.
  - `fighter_light` — مقاتلة خفيفة متعددة المهام.
  - `fighter_heavy` — مقاتلة ثقيلة/اعتراضية.
  - `bomber` — قاذفة بعيدة المدى.
  - `transport_aircraft` — طائرة نقل عسكرية.
  - `hummer` — عربة همر/مركبة تكتيكية خفيفة.
  - `apc` — ناقلة جنود مدرعة.
  - `ifv` — مركبة قتال مشاة.
  - `mlrs` — راجمة صواريخ متعددة.
  - `rocket_launcher` — منصة إطلاق صواريخ موجهة.
  - `atgm_launcher` — منصة صواريخ مضادة للدروع.
  - `field_gun` — مدفع ميداني مقطور.
  - `self_propelled_gun` — مدفع ذاتي الحركة.
  - `anti_aircraft_gun` — مدفع مضاد للطائرات.
- **Spec:** 64×64 RGBA PNG, transparent background, faction-neutral white tactical outline, readable at small size, matching the existing A-003 icon style. The quota-limited remainder uses deterministic vector fallback icons with the same contract.
- **Acceptance:** every listed file exists and loads at `res://assets/icons/units/<key>.png`; no source files under `src/` or `tests/` are modified on the assets branch.

---

## Notes for Manus

- Work only on the `assets` branch.
- Do not modify anything under `src/` or `tests/` — OpenHands wires assets in.
- After committing, leave a one-line note at the bottom of this file:
  `Manus: produced A-001, A-002 (commit <sha>) on <date>`.
Manus: produced A-001, A-002, A-003, A-004 (commit 6b3d1b1fa9db4ef76833ada6a9ced32bd16b0e69) on 2026-08-17.
Manus: produced A-005 (commit 305cf5b52b94f27b3e3708371f01c87dd7687c31) on 2026-08-17.

- If a request is ambiguous, leave a question in a commit message, do not guess.

## A-006 — Sniper unit icon
- [x] produced
- **Path:** `assets/icons/units/sniper.png`
- **Spec:** 64×64 RGBA PNG, transparent background, faction-neutral tactical outline, readable prone sniper silhouette with scoped rifle, matching the existing unit icon pack.
- **Acceptance:** file exists and loads at `res://assets/icons/units/sniper.png`.
Manus: produced A-006 (commit 48c37b150c32007623c886fd82a208c45cbcb822) on 2026-08-17.
