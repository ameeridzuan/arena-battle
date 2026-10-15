# Decisions Log (ADR) — ArenaBattle

> Milestone 0 document. Records architecture decisions and reasons. Append new entries; do not
> rewrite history. Format: Context → Decision → Rationale → Status.

## Adopted Defaults (from `FOUNDATION_INSTRUCTIONS.md` §11)

| Area | Decision | Status |
|------|----------|--------|
| Camera | Third-person (spring-arm follow + mouse look) | Adopted |
| Visual style | Undecided — use simple placeholder shapes for the prototype | Provisional |
| Target platform | Windows PC first | Adopted |
| Engine | Godot 4.x stable | Adopted |
| Language | GDScript (typed where useful) | Adopted |
| Initial player count | One local player, then two networked | Adopted |
| Long-term match size | 4v4 (8 players) | Adopted |
| First map | One small bounded arena | Adopted |
| Initial roster | One placeholder character; add a second only after core combat works | Adopted |
| Networking | Server-authoritative for competitive play | Adopted |
| Public matchmaking | Out of scope for the foundation | Adopted |

---

## ADR-0001 — Project memory scope separated as `arena-battle`
- **Context:** This is a brand-new personal project, distinct from existing work scopes
  (`cbpfos`, `LOS-FOS`, `personal-mcp`) already stored in the personal-memory MCP.
- **Decision:** Store all durable facts/config/decisions for this game under a new MCP system
  scope `arena-battle`, so it never mixes with unrelated project memories.
- **Rationale:** User explicitly asked to differentiate this new project in MCP memory; prevents
  cross-project contamination of recalled context.
- **Status:** Adopted (2026-10-14). Two seed memories recorded: project intro + environment/tooling.

## ADR-0002 — Documentation-first foundation; no gameplay code before approval
- **Context:** Foundation instructions require presenting the plan and stopping before Milestone 1
  implementation is approved.
- **Decision:** At Milestone 0 create only `README.md`, `.gitignore` and `docs/*`. Do **not**
  create `project.godot`, scenes, scripts, run `git init`, install software, or add MCP servers
  until the user approves.
- **Rationale:** Respects the review gate and file-safety rules; avoids premature untested code.
- **Status:** Adopted.

## ADR-0003 — Folders created only when first needed
- **Context:** Instruction: "Do not create empty folders merely to make the tree look complete."
- **Decision:** Only `docs/` exists now. `scenes/`, `scripts/`, `assets/`, `resources/`, `tests/`
  and their subfolders are created at the milestone that first populates them (M1 creates the
  scene/script folders it uses). Git does not track empty directories anyway.
- **Rationale:** Follows the rule; keeps the tree honest and avoids `.gitkeep` clutter.
- **Status:** Adopted.

## ADR-0004 — Placeholder primitive meshes for the prototype
- **Context:** No Blender installed; art is not on the critical path for movement validation.
- **Decision:** Use Godot primitive meshes (capsule/box) for the M1 character and arena.
- **Rationale:** Lets movement/collision/camera be built and tested immediately; defers the art
  pipeline to M6.
- **Status:** Adopted.

## ADR-0005 — Damage interface defined early, implemented at M2
- **Context:** Combat, health and (later) server validation all need one consistent contract.
- **Decision:** Fix `apply_damage(amount, source)` / `get_health()` now; implement at Milestone 2.
- **Rationale:** Prevents rework and keeps authoritative rules separable for future networking.
- **Status:** Adopted (2026-10-15). Implemented via `health.gd` component — see ADR-0007.

---

## ADR-0006 — Milestone 1 camera rig: yaw pivot + pitch tilt (no SpringArm3D yet)
- **Context:** A third-person camera needs mouse yaw + pitch and must not feed rotation back into
  camera-relative movement.
- **Decision:** `CameraPivot` (Node3D) holds **yaw only**; a child `CameraTilt` holds **pitch**; the
  `Camera3D` sits at a fixed offset (0, 1.2, 4.0) behind/above the player. The player body does not
  rotate — only the visual `Mesh` turns to face travel — so the pivot's yaw stays clean for movement
  math. SpringArm3D camera-collision is deferred (open arena; no clipping yet).
- **Rationale:** Deterministic, avoids Euler-order/SpringArm-direction ambiguity, keeps movement and
  look independent. Headless test confirms floor/movement/jump all pass.
- **Status:** Adopted (2026-10-15). Revisit SpringArm collision when arena geometry gets complex.

---

## ADR-0007 — Milestone 2: Health component + Area3D hitbox + arc filter (melee)
- **Context:** M2 requires one basic attack, a damageable target, and a single combat interface.
  The attack type was undecided (Q4: melee vs ranged). The hit detection mechanism needed to avoid
  self-hits, be testable headless, and stay server-authoritative-ready for M4.
- **Decision:**
  1. **Melee-first** — resolve Q4 as melee. The player swings in a short-range arc in front.
  2. **Reusable `Health` component** (`scripts/combat/health.gd`, `class_name Health`) — a plain
     `Node` added as a child of any damageable scene. Stores HP, clamps at 0, emits
     `health_changed(current, max)` and `died`. No dependencies on the parent's type.
  3. **Group + physics-layer dual filter** — damageable roots join group `"damageable"` AND sit on
     physics layer 3 (bitmask 4). The attack hitbox Area3D uses `collision_mask = 4` (detects only
     layer 3) and additionally checks `is_in_group("damageable")` in code. The player's own body
     (layer 2) is never detected.
  4. **Sphere Area3D + code arc filter** — an `AttackHitbox (Area3D)` with a `SphereShape3D` of
     radius = `attack_range` (default 2.0 m) is always monitoring. On attack, the script queries
     `get_overlapping_bodies()` and rejects bodies outside `attack_arc_deg / 2` of the CameraPivot's
     forward direction (XZ-plane projection). This avoids needing to rotate the hitbox or parent it
     to the camera.
  5. **Cooldown via delta accumulation** — `_cooldown_remaining` decremented in `_physics_process`.
     No Timer node needed; deterministic and trivially testable.
  6. **Damage source = the Player node** — `apply_damage(amount, get_parent())` passes the
     CharacterBody3D, not the Area3D. In M4, the server identifies the attacker by this reference.
- **Rationale:**
  - Melee is simpler to validate (no projectile lifetime/travel), satisfies the FOUNDATION spec
    ("basic attack"), and keeps scope minimal.
  - Health-as-child-node is reusable across all damageable entities (players, dummies, destructibles)
    without inheritance or mixins.
  - Sphere + code arc avoids fragile hitbox rotation/parenting while remaining physically correct.
  - Layer separation guarantees the player never self-hits; group check is a semantic safety net.
  - Delta-accumulation cooldown is frame-rate independent and works in headless tests with
    `Input.action_press("attack")`.
  - All tunables are `@export` — configurable in Inspector or by Resource override for M4.
- **Status:** Adopted (2026-10-15). Supersedes Q4 temporary assumption.

---

## ADR-0008 — Melee range enforced centre-to-centre (QA finding DEF-3)
- **Context:** QA (`combat_smoke_test.gd`) found that attack range was enforced only by the
  hit-sphere radius, so effective reach = `attack_range + the target's own half-extent`. A dummy
  whose centre was 2.2 m away (beyond the documented 2.0 m `attack_range`) still took damage. That
  makes reach depend on target size and undermines the deterministic server-side re-validation
  planned for M4.
- **Decision:** Add an explicit centre-to-centre gate in `melee_attacker._perform_attack()`:
  `if to_body.length() > attack_range: continue`, reusing the existing XZ offset vector. The sphere
  `Area3D` stays as the broad-phase overlap query; the code gate makes `attack_range` mean metres
  from the attacker's origin to the target's origin, independent of target size.
- **Rationale:** Matches the documented "attack_range in metres" semantics, keeps reach consistent
  across differently-sized targets, and makes the hit rule trivially reproducible on a server.
- **Status:** Adopted (2026-10-15). Verified: DIAG `centre_distance_2.2m_took_damage=false`; all 6
  combat test cases and the M1 movement regression still pass (exit 0).

---

## ADR-0009 — Match objective: team-deathmatch (Q5 resolved)
- **Context:** M3 (local gameplay loop) needs a concrete win condition before design can start.
  Q5 left the objective open (team-deathmatch vs objective-based).
- **Decision:** Adopt **team-deathmatch (TDM)** as the match objective. A kill against an opposing
  team scores one point for the attacker's team; the match ends on a score limit OR a time limit,
  whichever comes first, and the higher-scoring team wins (draw handled explicitly).
- **Rationale:** TDM reuses the M2 combat/`Health` path directly (a death is just `died` → award a
  point), is the simplest objective to make server-authoritative in M4/M5, and needs no extra map
  geometry or capture logic. Objective modes can layer on later without discarding the scoring core.
- **Status:** Adopted (2026-10-15). Drives the M3 spec (score, match-end, respawn). Resolves Q5.

---

## Open Questions / Temporary Assumptions

| # | Item | Temporary assumption | Revisit by |
|---|------|----------------------|-----------|
| Q1 | Exact Godot 4.x version | **Resolved: 4.7.2.stable.official.ed1daf0bf** | Done (M1) |
| Q2 | Renderer (Forward+ vs Mobile) | **Resolved: Forward+** (`renderer/rendering_method="forward_plus"`) | Done (M1) |
| Q3 | Arena size | ~30m × 30m box | M1 tuning |
| Q4 | Melee vs ranged combat focus | **Resolved: Melee-first** (ADR-0007) | Done (M2) |
| Q5 | Match objective (TDM vs objective) | **Resolved: Team-deathmatch** (ADR-0009) | Done (M2) |
| Q6 | Art direction / visual style | Placeholder shapes | M6 |
| Q7 | `FOUNDATION_INSTRUCTIONS.md` location | Left at project root (doc text refers to `docs/`); not moved without approval | On approval |
| Q8 | Git init timing | Deferred until user approves | On approval |

> Q1–Q5 are resolved. Q6 (art direction) is due before M6; Q7/Q8 are standing notes.
