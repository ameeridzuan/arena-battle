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

## ADR-0010 — Milestone 3: MatchManager (scene node), Combatant component, static opponents, Health reset
- **Context:** M3 requires a local gameplay loop: player health/death, respawn, TDM scoring, and
  match-end. The architecture must keep movement/combat/match separated (FOUNDATION §5.1), be
  testable headless, and lift cleanly to a server-authoritative model in M4. Key open choices:
  MatchManager as autoload vs scene node; how combatants get team identity and death handling;
  whether opponents move; how Health restores on respawn.
- **Decision:**
  1. **MatchManager is a scene node in Main.tscn** (NOT an autoload). Joins group
     `"match_manager"` for discovery. Owns phase (WAITING/RUNNING/ENDED), per-team scores,
     countdown timer. Exposes signals (`match_started`, `score_changed`, `player_died`,
     `match_ended(winner)`) and methods (`start_match()`, `register_kill(scorer, victim)`).
     Timer ticks in `_physics_process` (fixed 60 Hz, deterministic).
  2. **`combatant.gd` — a reusable child-Node component** (like Health) attached to every
     combatant body. Owns: `team_id` (exported int), death→kill-attribution→MatchManager
     notification, respawn scheduling (disable/enable cycle + SceneTree timer), spawn-point
     lookup by group. Does NOT own movement or attack logic.
  3. **Static dummy opponents (no movement AI).** Opponents reuse the existing DummyTarget scene
     with added Combatant + AttackHitbox (auto_attack=true). They damage the player when in
     range/arc but never move. Enemy pathfinding/chase is explicitly out of scope for M3.
  4. **Health additions (backward-compatible):** `var last_damage_source: Node` set in
     `apply_damage` for kill attribution; `func reset() -> void` restores to max_health for
     respawn. No signal signature changes. M2 test fixtures must isolate the original combat
     contract from the added M3 opponents and match lifecycle; regression passing is a QA gate.
  5. **melee_attacker addition:** `@export var auto_attack: bool = false`. When true, attacks on
     cooldown without reading Input. Default false preserves M2 behaviour exactly.
  6. **Player joins group `"damageable"`** and gains `apply_damage()`/`get_health()` delegates on
     `player_controller.gd` (3 lines; no movement logic touched). Dummy AttackHitbox uses
     `collision_mask = 2` (Player layer) → detects player, never other dummies.
  7. **Kill attribution:** `Health.last_damage_source` → source node's `Combatant.get_team_id()`
     → `MatchManager.register_kill(scorer_team, victim_team)`. Null/missing source degrades
     safely (no score, warning printed). Same-team and invalid-team kill requests do not
     award points; local validation preserves the TDM contract (ADR-0009).
  8. **Respawn:** disable in place (collision off, mesh hidden, physics_process off), wait
     `respawn_delay` (SceneTree timer), teleport to team spawn marker (group lookup +
     `spawn_index`), `Health.reset()`, re-enable. NOT removed/re-instantiated.
  9. **Draw handling:** time expires with equal scores → `match_ended(-1)`. No overtime in M3.
  10. **Tunables (defaults):** score_limit=5, time_limit=180 s, respawn_delay=3 s,
      opponent_count=2, dummy attack_damage=20, dummy attack_cooldown=1.5 s,
      dummy attack_arc_deg=90°.
- **Rationale:**
  - *Scene node over autoload:* scoped lifecycle (no global state leakage between tests/matches);
    Inspector-editable exports; in M4 the server scene has the authoritative instance and the
    client scene has a shadow — no runtime `if is_server` branching inside the pure logic.
  - *Combatant component over root-script inheritance:* keeps player_controller.gd (movement) and
    dummy_target.gd (feedback) unchanged in responsibility; team/death/respawn logic is isolated
    and reusable across any combatant body type.
  - *Static opponents:* M3 validates the LOOP (start→play→score→die→respawn→end), not AI.
    Movement AI adds pathfinding/navmesh scope that belongs in M5+ when real opponents exist.
    Static opponents with auto_attack still exercise both directions of the kill flow.
  - *`reset()` naming:* state-machine language ("return to initial state"); avoids confusion with
    `heal(amount)` (partial, future ability) or `revive()` (lifecycle concept owned by combatant).
  - *`last_damage_source` stored in Health:* avoids changing the `died()` signal signature (which
    would break existing connections); combatant reads it synchronously in the died handler.
  - *Disable-in-place over remove/re-instantiate:* symmetric, stable node tree, no signal
    reconnection overhead, maps to persistent server entities in M4.
- **Status:** Adopted. Approved M3 checkpoint resumed on 2026-10-16 at the owner's request;
  existing tunable defaults retained. Automated QA and manual HUD/feel acceptance are tracked
  separately in the roadmap; adoption does not mean full milestone acceptance.

---

## ADR-0011 — M4: separate loopback server, bounded controls and server-owned snapshots

- **Context:** Owner accepted M3 including feedback/HP HUD and authorized the next task
  on 2026-10-16. M4 needs two real clients, server validation and failure handling.
- **Decision:** ENet; one headless local server and two clients. Bind server to loopback,
  retain authority 1, derive player identity from RPC sender. Send bounded controls,
  simulate movement/attacks server-side and replicate outcomes at 20Hz. Keep M3 Main.tscn;
  use a separate MultiplayerArena scene and client display model. Start only after two
  registrations, stop on a running-peer disconnect. Reuse Health/Combatant/MatchManager.
- **Reason:** This gives a single place for gameplay authority without client transform
  trust, while preserving the accepted local scene and avoiding premature M5/M8 scope.
- **Limits:** No prediction/interpolation/lag compensation; transient action edges share
  unreliable control packets. Restart processes for a fresh match. See M4 plan for tests.
- **Status:** Implemented and automatically verified; manual multiplayer acceptance pending.

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
| Q9 | Enemy movement AI | Out of scope M3; static opponents only | M5+ |
| Q10 | Overtime / tiebreaker on draw | None in M3 (draw = draw) | M5 |

> Q1–Q5 are resolved. Q6 (art direction) is due before M6; Q7/Q8 are standing notes.
> Q9/Q10 are M3 deferrals recorded for future milestones.


## 2026-10-19 — Animation foundation

Use per-player animation copies before runtime loop configuration to prevent shared imported-resource mutations. Apply 0.15 s movement blends and separate enter/exit speed thresholds while preserving attack onset. These are interim presentation changes; import-time loop configuration, memory/performance measurements and authoritative action timing remain pending. Review new clips in the isolated AnimationReviewGallery scene before gameplay integration.


## 2026-10-19 — Human gait and natural speeds

Use freely reusable CMU35_01/35_17 human capture adapted to each rig; preserve original model exports and install per-instance runtime locomotion clips. The owner chose natural movement speeds, set to1.2m/s walk and3.8m/s run. Derive playback rate from capture stride travel and preserve normalized phase across Walk/Run. Follow the owner armor reference: no universal armor multiplier or invented equipment masses. Capture-based jump/strafe remain review-only pending state/authority integration.


## 2026-10-20 — Directional movement and reference previews

Use captured backward/side walks rather than reversing the accepted forward clip. Select from actual mesh-local velocity with angular hysteresis, per-clip cadence and gait phase continuity. Local aim fast side/back steps use a configurable1.8m/s target while forwardrun3.8m/s is preserved. Starts/stops, turns and blocks remain gallery-only until state and authority contracts exist. Preserve independent head/torso capture rotations for turns and source root travel for future adapters.

## 2026-10-20 — Layered actions without movement-state clip duplication

Use one runtime AnimationTree as the pose writer; AnimationPlayer supplies clips and runs only in explicitly isolated raw gallery mode. Blend the locomotion base continuously with an action filtered to the actual rig's spine descendants, keeping root/pelvis/legs on locomotion. Share existing melee clips across idle/walk/run/strafe rather than authoring their Cartesian product. Independently advance locomotion and action clocks; gait cadence must never speed up attack playback. Current graph uses two phase-aware locomotion slots and an action slot with TimeSeek sampling, driven once per physics update. Data resources declare clip, upper/full-body ownership, priority, interruption and fades. Full-body overrides are explicit; motion and combat authority remain in existing controllers. Death clears actions and model replacement rebuilds bindings. Future persistent guard/aim, additive reactions and server phase synchronization are separate extensions, not mechanics enabled by this change. Visual acceptance and performance measurements remain pending.

## 2026-10-20 — Reusable casting and directional dodge previews

Author one composite magic cast over the upper-body layer, shared across all movement states, and four directional dodge one-shots using explicit full-body ownership. Use limb-length-aware analytical pose targets and rig-specific libraries while preserving the imported model files. Keep root/horizontal hip travel in place; gameplay remains authoritative for travel, collision and effects. Record visual phase/release markers as metadata only. A common present_action adapter supplies the same priority/death/manual-preview rules as melee. Do not add projectile, dodge movement, invulnerability, aim replication or controls merely because their preview animation exists. Persistent casting stances and gameplay timing synchronization remain separate work. Generated motion is labelled authored blockout, not human capture or measured armor simulation.

## 2026-10-20 — Local playable motion harness

At the owner's request to test the new motion, install a local-only Main player adapter: V/R casts with one cosmetic bolt, Q chooses a cardinal collision-based dodge, and Tab swaps the character. Keep animation as presentation; the test component owns bounded in-place-to-body movement and cosmetic release timing. Use a local player subclass so shared/network movement has no new input branch. Prototype defaults are 1 s cooldowns, 0.72 s dodge duration and 5.5 m/s peak, with no invulnerability or ranged damage. Cancel on death, match end, focus/cursor loss and model change; suppress melee while a test action owns the layer. Rebind hit-feedback meshes on the new model_changed signal to avoid stale freed-node references. Existing portable exports and multiplayer protocols remain unchanged; visual acceptance and authoritative mechanics are separate work.

## 2026-10-21 — Responsive evasion and local parry

Replace forward dodge with a distinct Run-derived forward dash. Start displacement immediately: dash lasts 0.36 s and travels about 3.35 m; side/back dodge lasts 0.42 s and travels about 2.53 m. Share profile timing between pose generation and movement. Add a 0.32 s visible windup to Main-only sparring enemies so contact-time range checks allow physical evasion. F starts a reusable upper-body parry: one frontal melee hit during 0.04–0.22 s is deflected, followed by a confirmed-success pose. Ordinary damage bypasses parry. Keep collision, gravity and environmental vulnerability; no automatic counterattack or multiplayer protocol. Parry reuses locomotion beneath the torso layer instead of adding movement-specific variants. See DASH_PARRY_CHECKPOINT.md for tuning and validation.

## 2026-10-21 — Actual damage feedback and local spell burn

The owner requested hit amounts, ranged damage and a short damage-over-time effect. Health emits actual HP loss with a damage kind for a reusable floating-number presenter on Player and DummyTarget. Keep presentation outside Health and outside model meshes; initial replica snapshots establish a baseline without inventing a hit. The local traveling bolt now validates source, team, authoritative Health and swept world collision before applying 20 impact damage. A separate BurnStatus owns three one-second ticks of 3 damage, preserving caster kill credit. Repeated hits refresh the single burn and its source while preserving the upcoming tick cadence, preventing stacking and tick starvation. Explicit reset, death and match-end signals clear the status. Replica clients never run burn damage timers. Orange numbers and built-in ember particles identify burn; ordinary hits use red numbers. These values are tunable local defaults; multiplayer spell authority/replication and portable exports remain separate work. See RANGED_DAMAGE_CHECKPOINT.md.

## 2026-10-21 — Local adaptive traversal

Use capsule sweeps plus bounded support snapping for local stair stepping, with
terrain-aware leg IK and cosmetic mesh/camera smoothing. Keep ledge and wall
movement in a separate traversal state machine, arbitrate competing actions,
and sweep every climb segment. Reuse the existing local test adapter; leave
network authority/replication for a dedicated integration. See
[adaptive traversal design, sources and QA](ADAPTIVE_TRAVERSAL.md).

## 2026-10-22 — Local jump attacks and weapon contacts

The owner requested airborne melee and contact effects. Main and MotionTestCourse
use a local weapon adapter that explicitly presents existing ground attacks and
Attack_Overhead over Jump. Reuse the upper-body action layer rather than create
idle/run/jump combinations. Add action playback speed independently of gait to
normalize local ground/air swings to 0.65/0.9 seconds. Only the active 30–80% of
the swing can damage. Sample the actual rig blade through hand.R skin bindings,
sweep its capsule between physics samples and apply one 25-damage hit per victim.
Use the actual shape-contact surface for occlusion checks and spark placement;
blade and body rays prevent damage through intervening world geometry.
Gravity continues, one air attack is permitted before landing, and lifecycle or
higher-priority actions cancel pending contact. Keep shared/network melee timing
and original GLBs unchanged. See WEAPON_ATTACK_CHECKPOINT.md for scope and checks.

## 2026-10-22 — Visible traversal contacts and clearance

Use rest-model skin envelopes to constrain cosmetic traversal bones in addition
to physical capsule sweeps. Keep explicit boot frames independent of shin axes,
and retain a crouched hip transfer until the trailing hand can safely release.
Ease clearance above the lip while preserving full protection below it. Validate
actual post-modifier geometry throughout complete climbs, rather than accepting
only bone endpoints and static sheets. See TRAVERSAL_ANIMATION_REVIEW.md for
reference demonstrations, review findings and scoped acceptance.


## 2026-10-23 — 1v1 shared motion authority and parkour arena

The owner requested the approved local motion/combat changes in the portable
1v1 Host/Join match and terrain that exercises climbing and wall jumping.
The network session now uses the shared movement, action and blade-contact
components on its authority. Clients submit bounded controls; snapshots carry
consistent character identity, contact-driven traversal/action pose, burn and
cosmetic effects. Bounded DEFLATE snapshot compression keeps 1v1 pose traffic
below the unreliable-packet MTU. Match start waits for both clients to finish
loading the complete roster; loading grace is separate from input timeout.
A mirrored arena preserves spawns and central duel space while adding terraces,
variable-rise stairs, low vaults and opposing wall-jump lanes.
See ONEVONE_PARKOUR_BUILD.md for exact checks, packaging and limitations.


### 2026-10-27 — Four-player waiting lobby
Demo1 now uses an explicit host-start lobby with server-validated teams (two per side), character selection and separate loading/Ready flags. Start accepts 1v1, 2v1/1v2 or 2v2 with both teams populated. Roster/selection changes clear readiness. A process-lifetime random owner claim distinguishes the host from joining clients; no host migration or mid-match join is introduced. Legacy direct two/eight-player auto-start tests remain supported. See TEAM_LOBBY.md.
