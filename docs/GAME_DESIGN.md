# Game Design — ArenaBattle

> Milestone 0 document. Captures vision and the **current prototype scope only**.
> Long-term features are listed as future direction, not commitments.

## 1. Vision

A third-person 3D platform/action **battle arena** where **two teams of four players**
(8 total) compete in the same arena. Fast, readable, skill-based combat with distinct
character roles, movement options (run, jump, dodge), and arena hazards.

## 2. Design Pillars

1. **Readable combat** — players can see and react to threats; camera and silhouettes stay clear.
2. **Movement matters** — platforming, positioning and dodging are core skills.
3. **Team play** — 4v4 roles encourage coordination, not just deathmatch.
4. **Fair competition** — the server, not the client, decides all important outcomes.
5. **Incremental & testable** — every feature ships behind a milestone with acceptance criteria.

## 3. Core Gameplay Loop (target)

Spawn → position/move through arena → engage enemies (melee/ranged) → score on eliminations
or objectives → respawn → repeat until a team meets the victory condition → match end → rematch.

## 4. Scope Management

**Do not build everything at once.** The prototype foundation comes first; content, roles,
abilities, art and networking are layered on only after each prior milestone is verified.

### Current prototype scope (Milestone 1)
- One small 3D arena (floor, walls/boundaries, lighting, camera).
- One controllable **placeholder** third-person character.
- Walk, run, jump, gravity, and collision with the arena.
- Simple instruction label (optional).

### Explicitly out of scope for the prototype
Multiple characters, abilities, real combat balance, HUD/menus, audio, VFX, multiple arenas,
multiplayer, matchmaking, and polished art.

## 5. Arena Design (Milestone 1 placeholder)

- **Shape:** flat rectangular floor with four perimeter walls (a bounded "box").
- **Scale:** roughly 30m × 30m playable area (tunable constant, no magic numbers in code).
- **Lighting:** one `DirectionalLight3D` (sun) + `WorldEnvironment` ambient; optional shadows on.
- **Boundaries:** solid collision walls so the player cannot leave or fall out.
- **Later:** platforms, elevation, hazards, cover, team spawn zones.

## 6. Character Design (Milestone 1 placeholder)

- A primitive-mesh capsule/box body (no rigged model yet).
- `CharacterBody3D` with a `CollisionShape3D`.
- Third-person camera on a spring/arm that follows and orbits the character.
- Movement is **camera-relative** (W = away from camera).
- **Later:** rigged Blender character, role classes, abilities, animations, health/death.

## 7. Combat (Milestone 2, future)

One basic attack against a dummy target with health, through a single clearly-defined combat
interface (`apply_damage`). Range and hit detection validated. No combos or character-specific
abilities until the loop is stable.

## 8. Progression of Content (future)

Second character → one ability per character → character select + HUD → audio/VFX/improved art
→ roster & arena expansion. Only after the local gameplay loop is stable.

## 9. Open Design Questions

See [`DECISIONS.md`](DECISIONS.md). Key undecided items: visual style/art direction, melee vs
ranged focus, objective mode vs team-deathmatch, and the definitive victory condition.
