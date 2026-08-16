# AI Design — Theater of War

> Status: design direction only. Implementation begins in **Phase 8**. This
> document records the intended structure so the foundation can leave room for
> it.

## Design goal

The AI should feel like an opposing commander operating under the same
constraints as the player: limited information, finite logistics, and a chain of
command. It is **not** a cheating omniscient script. It makes decisions on the
basis of what it knows, and what it knows is shaped by the same intelligence and
fog-of-war systems the player sees.

## Three-layer model

The AI is structured as three cooperating layers, mirroring military doctrine:

### 1. Strategic AI

- Sets theater-wide objectives and priorities (which sectors matter, when to
  attack/defend/withdraw, resource allocation across fronts).
- Operates on long time horizons and aggregate information (intelligence
  estimates, economy state, logistics readiness).
- Decides force composition goals and where to commit reserves.

### 2. Operational AI

- Translates strategic objectives into concrete operations: assemble a force at
  a staging area, open a corridor, secure a river crossing.
- Manages movement of formations between sectors, timing and synchronization.
- Consumes logistics capacity and reports constraints back up.

### 3. Tactical AI

- Commands individual formations in contact: engage, suppress, maneuver, retreat
  within the local tactical picture.
- Resolves fire and movement at the unit/formation level using the Combat system
  (Phase 3).
- Operates on the freshest local information and reacts in real time.

## Information model

The AI consumes the **same** intelligence picture as the player:

- **Fog of war** limits what it can see (Phase 7).
- **Information confidence** weights estimates; the AI may act on stale or
  low-confidence data and be wrong, just like a human.
- **Deception** (Phase 9) can mislead the AI; counter-intelligence can reveal
  player deception.

This is the single most important principle: **the AI's decisions are bounded by
information, not by difficulty knobs alone.**

## Command hierarchy integration

The AI issues orders **through the same command hierarchy** (Phase 4) as the
player — Army → Corps → Division → Brigade → Battalion → Company → Platoon. It
does not teleport units or bypass the chain. This keeps AI and player behavior
symmetric and lets the same simulation rules apply to both.

## Difficulty

Difficulty is expressed as a combination of:

- Information quality (better/worse reconnaissance and confidence).
- Planning horizon and reaction speed.
- Resource and force starting conditions.
- Risk tolerance in decision-making.

Not as stat bonuses or omniscience. Where tuning constants are needed, they are
exposed as data, not hardcoded.

## Phase 0 / Phase 1 status

No AI behavior exists yet. The enemy unit on the map is a static dummy. The
`AISystem` module is a stub reserving the namespace and folder. Phase 8 begins
real implementation on top of the combat, hierarchy, logistics and intelligence
systems delivered in Phases 3–7.
