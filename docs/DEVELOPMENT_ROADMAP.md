# Development Roadmap — ArenaBattle

> Milestone 0 document. Complete and verify each milestone before starting the next.
> Current position (2026-10-16): **M2 headless-verified; approved M3 implemented and headless-verified. Manual HUD/feel acceptance remains pending.**

## Environment Gate (resolved)

| Tool   | Status (2026-10-15)         | Needed for |
|--------|-----------------------------|-----------|
| Git    | ✅ Installed (2.51.0)        | version control |
| Godot 4.x | ✅ Installed & verified (**4.7.2.stable**) | open/run/export project |
| Blender | ❌ Not installed            | art pipeline — required from M6 |
| Disk (C:) | ~21.3 GB free             | sufficient for Godot (~0.2 GB) + Blender (~1 GB) |

**Action required from user:** Blender still needed only at Milestone 6.

---

## Milestones

### M0 — Environment & Plan ✅ (this document set)
- [x] Inspect workspace before changing anything.
- [x] Check Godot, Git, Blender availability and versions.
- [x] Confirm new (not existing) repository — workspace is not yet a git repo.
- [x] Write architecture and roadmap docs.
- [x] Identify unresolved design choices + temporary assumptions.
- [x] **Review & approval by user** (gate for M1).

**Acceptance:** environment, plan, assumptions and next steps documented. *(Met.)*

### M1 — Playable 3D Movement ✅ (implemented & headless-verified)
- [x] Create/configure the Godot project (`project.godot`, folder skeleton).
- [x] Main scene + simple arena (floor, walls, light, environment, camera).
- [x] `CharacterBody3D` player controller.
- [x] Camera-relative movement, gravity, jumping.
- [x] Collision + arena boundaries.
- [x] Third-person follow camera (yaw pivot + pitch tilt, mouse look, Esc toggle).
- [x] Input actions defined in Project Settings.
- [x] Instruction label (HUD).
- [x] README run/test instructions.

**Acceptance:** project launches with no script errors; player moves/turns/jumps/lands; cannot
fall through floor; camera usable; controls documented.

**Verification (2026-10-15, Godot 4.7.2 headless):** `--import` exit 0; smoke run exit 0;
`tests/integration/movement_smoke_test.gd` → floor_collision=true, movement=true (4.55 m),
jump=true, **ALL_TESTS_PASS=true**, exit 0. *Manual F5 playtest (visual/camera feel) still to be
confirmed by the user in the editor.*

---

### M2 — Basic Combat ✅ (implemented & headless-verified)

> **Spec:** See `TECHNICAL_ARCHITECTURE.md` §3.2–3.4, §4.2, §6, §7 and `DECISIONS.md` ADR-0007 / ADR-0008.
> **Decision-complete:** implemented exactly to spec; one QA finding (DEF-3) resolved via ADR-0008.

#### Scope
- [x] `Health` component node (`scripts/combat/health.gd`) — reusable, signals, clamp at 0.
- [x] Melee attacker on Area3D hitbox (`scripts/combat/melee_attacker.gd`) — input, cooldown, arc + range filter.
- [x] Dummy target scene (`scenes/targets/DummyTarget.tscn` + `scripts/targets/dummy_target.gd`).
- [x] Player.tscn updated: AttackHitbox child node, collision layer/mask set.
- [x] Main.tscn updated: DummyTarget instance at (0, 1, −4).
- [x] `project.godot` updated: `[layer_names]` section for physics layers 1–3.
- [x] Collision layer plan applied (see TECHNICAL_ARCHITECTURE.md §7).
- [x] HUD label text updated to mention Attack: Left Mouse.
- [x] `player_controller.gd` unchanged — NO combat logic added.
- [x] Integration test: `tests/integration/combat_smoke_test.gd`.

#### Out of scope (explicitly excluded)
- Combos, chains, or multi-hit sequences.
- Character-specific abilities or ultimates.
- Ranged / projectile attacks.
- Player health, death, or respawn (M3).
- Multiplayer / networking (M4).
- Animation (no AnimationPlayer at M2; visual feedback is color flash + print only).
- Audio.

#### Acceptance criteria (all must pass headless + visual playtest)

| # | Criterion | How verified |
|---|-----------|-------------|
| AC-1 | Attack damages dummy when target is within `attack_range` (2 m) AND within `attack_arc_deg` (120°) of camera forward | `combat_smoke_test.gd` test case 1 |
| AC-2 | Attack does **NOT** damage dummy when target is beyond `attack_range` | test case 2 |
| AC-3 | Attack does **NOT** damage dummy when target is within range but outside the arc (behind player) | test case 3 |
| AC-4 | Cooldown prevents a second hit within `attack_cooldown` (0.6 s) | test case 4 |
| AC-5 | Health clamps at 0.0 (never negative) after lethal damage | test case 5 |
| AC-6 | `died` signal emitted exactly once when health reaches 0 | test case 5 |
| AC-7 | All damage flows through `apply_damage(amount, source)` — no direct HP manipulation | code review (single interface) |
| AC-8 | Player's own hitbox never detects the player (layer exclusion) | test case 6 |
| AC-9 | Console prints `[DummyTarget] health: X / Y` on each hit (headless feedback) | test output assertion |
| AC-10 | Dummy mesh flashes red on hit during visual playtest | manual F5 check |
| AC-11 | Project runs with zero script errors (`--import` + `--headless` exit 0) | CI / manual run |

#### QA test cases (for `tests/integration/combat_smoke_test.gd`)

1. **Hit within range & arc** — position dummy 1.5 m in front (−Z), fire attack, assert health = 75.
2. **Miss — out of range** — position dummy 3.0 m in front, fire attack, assert health unchanged (100).
3. **Miss — outside arc** — position dummy 1.5 m behind (+Z), fire attack, assert health unchanged.
4. **Cooldown gate** — fire attack twice in rapid succession (same frame / next frame), assert only one hit lands (health = 75, not 50).
5. **Lethal damage + died signal** — apply 4 × 25 damage (with cooldown waits), assert health = 0, `died` fired once, fifth hit does nothing.
6. **Self-hit exclusion** — verify `get_overlapping_bodies()` on AttackHitbox never contains the Player node.

#### Files to create / modify

| Action | Path | Owner |
|--------|------|-------|
| CREATE | `scripts/combat/health.gd` | Gameplay Dev |
| CREATE | `scripts/combat/melee_attacker.gd` | Gameplay Dev |
| CREATE | `scripts/targets/dummy_target.gd` | Gameplay Dev |
| CREATE | `scenes/targets/DummyTarget.tscn` | Gameplay Dev |
| MODIFY | `scenes/characters/Player.tscn` (add AttackHitbox + collision layers) | Gameplay Dev |
| MODIFY | `scenes/main/Main.tscn` (add DummyTarget instance) | Gameplay Dev |
| MODIFY | `project.godot` (add `[layer_names]`) | Gameplay Dev |
| MODIFY | `scenes/ui/HUD.tscn` (update label text) | Gameplay Dev |
| CREATE | `tests/integration/combat_smoke_test.gd` | QA Engineer |

#### Server-authoritative readiness notes (M4 prep)
- `health.gd` is a pure state machine (no scene-tree position dependency) → can run on server.
- `melee_attacker.gd` range/arc/cooldown checks are deterministic math → server replicates validation.
- `apply_damage(amount, source)` carries attacker identity → maps to `peer_id` in M4.
- All tunables are `@export` → can be driven by replicated Resources or server config.
- No client-side-only shortcuts (e.g. direct HP set) exist.

#### Verification (2026-10-15, Godot 4.7.2 headless)
- `--import` → exit 0 (no parse errors/warnings).
- `tests/integration/combat_smoke_test.gd` → all 6 spec cases **true** (`hit_in_range_and_arc`,
  `miss_out_of_range`, `miss_outside_arc`, `cooldown_gate`, `lethal_and_died`, `self_hit_exclusion`)
  plus harness-integrity checks; **ALL_TESTS_PASS=true**, exit 0, deterministic across two runs.
- `tests/integration/movement_smoke_test.gd` (M1 regression) → **ALL_TESTS_PASS=true**, exit 0.
- DEF-3 fix verified: DIAG `centre_distance_2.2m_took_damage=false` (range now centre-to-centre).
- AC status: AC-1…AC-9 and AC-11 verified headless; **AC-10 (red hit-flash) still needs the manual
  F5 playtest** — the only M2 criterion not automatable without a display.

---

### M3 — Local Gameplay Loop (approved; headless-verified, manual acceptance pending)

> **Spec:** See `TECHNICAL_ARCHITECTURE.md` §3.5–3.9, §4.3–4.4, §6.5–6.10, §7 (M3 rows), §10 (M3
> table) and `DECISIONS.md` ADR-0010.
> **Objective (FOUNDATION §4 M3):** a short LOCAL test match that starts, plays and ends
> predictably — player health & death, simple respawn, basic score + match-end condition, and
> movement/combat/match kept as SEPARATE components. Match objective = team-deathmatch (ADR-0009).
> **NO networking** (M4), no art, no audio.

#### Scope checklist

- [x] `MatchManager` node (`scripts/match/match_manager.gd`) — phase/score/timer/signals.
- [x] `Combatant` component (`scripts/combat/combatant.gd`) — team id, death→kill attribution,
      respawn scheduling, spawn-point group lookup.
- [x] `health.gd` additions — `last_damage_source` var + `reset()` method (backward-compatible).
- [x] `melee_attacker.gd` addition — `auto_attack` export (default false = M2 behaviour).
- [x] `player_controller.gd` minimal additions — `_ready()` group join, `apply_damage()`,
      `get_health()` delegates. **No movement logic changed.**
- [x] `Player.tscn` updated — add Health + Combatant child nodes.
- [x] `DummyTarget.tscn` updated — add Combatant + AttackHitbox (auto_attack=true, mask=2).
- [x] `Arena.tscn` updated — spawn markers join groups (`spawn_team_0`, `spawn_team_1`);
      add SpawnB2 marker; adjust Y to 1.0.
- [x] `Main.tscn` updated — add MatchManager node; replace single DummyTarget with 2 Opponent
      instances at team-B spawn positions, oriented toward arena centre.
- [x] `HUD.tscn` updated — add ScoreLabel, TimerLabel, ResultLabel; attach `hud.gd`.
- [x] `scripts/ui/hud.gd` — connects to MatchManager signals, updates labels. Pure display.
- [x] Integration test: `tests/integration/match_smoke_test.gd` — 44 checks, twice, exit 0.
- [x] M2 regression: `combat_smoke_test.gd` — 9 checks, twice, ALL_TESTS_PASS=true, exit 0.
- [x] M1 regression: `movement_smoke_test.gd` — 3 checks, twice, ALL_TESTS_PASS=true, exit 0.

#### Out of scope (explicitly excluded from M3)

- **Networking / multiplayer** (M4).
- **Enemy movement AI** (pathfinding, chase, patrol, navmesh) — opponents are STATIC.
- **Art / animation / audio / VFX** — placeholder meshes and print/label feedback only.
- **Character selection / lobby / menus.**
- **Multiple arenas.**
- **Abilities / ultimates / ranged attacks.**
- **Overtime / tiebreaker** on draw (draw = draw, match ends).
- **Persistent stats / progression.**
- **Dynamic opponent count** (fixed at 2 instances in Main.tscn; tunable by editing the scene).

#### Verification checkpoint — 2026-10-16

Godot 4.7.2.stable native import passed (exit 0), followed by two successful runs each of
movement (3 checks), combat (9 checks) and match (44 checks). Every suite reported
`ALL_TESTS_PASS=true` and exit 0. A 120-frame main-scene headless smoke run also exited 0.
There were no errors; each match suite deliberately emits one null-source attribution
warning for the safe-degradation case. Detailed evidence: [`../tests/M3_QA_REPORT.md`](../tests/M3_QA_REPORT.md).

The resumed work added match lifecycle/respawn/scoring/HUD-state coverage, aligned stale M2
combat fixtures with the M3 scene, and rejected friendly or invalid-team kill registrations.
The runtime opponent-facing regression passes with the existing authored scene transforms.

AC-M3-1–10 and AC-M3-15–17 have automated evidence. Code review verified component separation
and exported gameplay tunables (AC-M3-13/14). HUD text/state assertions supplement testing,
but visual score/countdown presentation (AC-M3-11), result presentation (AC-M3-12) and play
feel still require manual F5 acceptance. **Full M3 remains open until those checks pass.**

#### Acceptance criteria

| # | Criterion | How verified |
|---|-----------|-------------|
| AC-M3-1 | Match starts automatically on scene load; phase transitions WAITING→RUNNING; `match_started` signal emitted | `match_smoke_test.gd` case 1 |
| AC-M3-2 | Killing an opponent increments TEAM_A score by 1; `score_changed` emitted with correct values | case 2 |
| AC-M3-3 | Opponent's auto_attack damages the player when player is within range/arc | case 3 |
| AC-M3-4 | Player death increments TEAM_B score by 1; `player_died` signal emitted | case 3 |
| AC-M3-5 | Dead player is disabled (input off, mesh hidden, collision off) during respawn delay | case 4 |
| AC-M3-6 | Player respawns after `respawn_delay` (3 s) at TEAM_A spawn point with health restored to max | case 4 |
| AC-M3-7 | Dead opponent is disabled during respawn delay, then respawns at TEAM_B spawn with health restored | case 5 |
| AC-M3-8 | Match ends when a team reaches `score_limit` (5); `match_ended(winner)` emitted with correct team | case 6 |
| AC-M3-9 | Match ends when `time_limit` (180 s) expires; higher score wins; equal scores → draw (winner = −1) | case 7 |
| AC-M3-10 | After match ends, no more kills are registered and no respawns occur | case 8 |
| AC-M3-11 | HUD displays score (both teams) and countdown timer; updates on `score_changed` | manual F5 |
| AC-M3-12 | HUD displays match result ("TEAM A WINS" / "TEAM B WINS" / "DRAW") on `match_ended` | manual F5 |
| AC-M3-13 | Movement, combat and match logic are in SEPARATE scripts (no cross-contamination) | code review |
| AC-M3-14 | All tunables are `@export` with documented defaults — no magic numbers | code review |
| AC-M3-15 | `combat_smoke_test.gd` (M2) still passes: ALL_TESTS_PASS=true, exit 0 | headless regression |
| AC-M3-16 | `movement_smoke_test.gd` (M1) still passes: ALL_TESTS_PASS=true, exit 0 | headless regression |
| AC-M3-17 | Project runs with zero script errors (`--import` + headless exit 0) | CI / manual |

#### QA test cases (for `tests/integration/match_smoke_test.gd`)

1. **match_starts** — instantiate Main.tscn; await deferred start; assert phase == RUNNING,
   time_remaining > 0, `match_started` signal received.
2. **kill_opponent_scores** — call `opponent.apply_damage(999, player)` directly (bypasses
   melee timing); assert TEAM_A score == 1, `score_changed(1, 0)` emitted.
3. **opponent_damages_player** — teleport player into opponent's range/arc; wait for
   auto_attack cooldown; assert player health < max; if lethal, assert TEAM_B score == 1
   and `player_died` emitted.
4. **player_respawn** — kill player (direct apply_damage); assert disabled state (collision
   off, mesh hidden, physics_process off); wait respawn_delay + margin; assert player at
   SpawnA position, health == max, collision on, mesh visible, physics_process on.
5. **opponent_respawn** — kill opponent; assert disabled; wait respawn_delay + margin; assert
   opponent at team-B spawn, health == max, re-enabled.
6. **score_limit_ends_match** — set score_limit=2 (test override); register 2 kills for TEAM_A;
   assert phase == ENDED, `match_ended(0)` emitted (TEAM_A wins).
7. **time_expiry_ends_match** — set time_limit=1.0 (test override); wait > 1 s; assert phase ==
   ENDED; test both unequal scores (winner = higher) and equal scores (winner = −1, draw).
8. **post_match_no_scoring** — after match_ended, call register_kill; assert score unchanged;
   kill a combatant; assert no respawn occurs.

**Supplementary (non-scored):**
- **null_source_degradation** — call `apply_damage(999, null)` on a combatant; assert death
  processes (disable + respawn) but NO score is awarded (safe degradation).
- **M2 regression gate** — run `combat_smoke_test.gd` in the same session; assert ALL_TESTS_PASS.

#### File manifest — CREATE / MODIFY

| Action | Path | Responsibility | Owner |
|--------|------|----------------|-------|
| CREATE | `scripts/match/match_manager.gd` | Match state machine: phase, scores, timer, signals, register_kill, start/end | Gameplay Dev |
| CREATE | `scripts/combat/combatant.gd` | Team identity, death→kill attribution, respawn disable/enable, spawn lookup | Gameplay Dev |
| CREATE | `scripts/ui/hud.gd` | HUD label updates driven by MatchManager signals (score, timer, result) | Gameplay Dev |
| CREATE | `tests/integration/match_smoke_test.gd` | M3 integration test (8 scored cases + supplementary) | QA Engineer |
| MODIFY | `scripts/combat/health.gd` | Add `last_damage_source` var + `reset()` method (backward-compatible) | Gameplay Dev |
| MODIFY | `scripts/combat/melee_attacker.gd` | Add `@export auto_attack: bool = false` + conditional branch | Gameplay Dev |
| MODIFY | `scripts/player/player_controller.gd` | Add `_ready()` (group join), `apply_damage()`, `get_health()` delegates | Gameplay Dev |
| MODIFY | `scenes/characters/Player.tscn` | Add Health (Node) + Combatant (Node) children | Gameplay Dev |
| MODIFY | `scenes/targets/DummyTarget.tscn` | Add Combatant (Node) + AttackHitbox (Area3D + CollisionShape3D) children | Gameplay Dev |
| MODIFY | `scenes/arena/Arena.tscn` | Spawn markers → groups; add SpawnB2; adjust Y to 1.0 | Gameplay Dev |
| MODIFY | `scenes/main/Main.tscn` | Add MatchManager node; replace DummyTarget with 2 Opponent instances; reposition Player to SpawnA | Gameplay Dev |
| MODIFY | `scenes/ui/HUD.tscn` | Add ScoreLabel, TimerLabel, ResultLabel; attach hud.gd; update ControlsLabel text | Gameplay Dev |

**NOT modified:** `project.godot` (no new input actions, layers, or autoloads),
`scripts/targets/dummy_target.gd` (Combatant child handles team/death/respawn; existing feedback
code untouched), `scripts/player/camera_rig.gd`.

#### Approved exported tunables & defaults

| Tunable | Location | Default | Notes |
|---------|----------|---------|-------|
| `score_limit` | MatchManager | **5** | Kills needed to win |
| `time_limit` | MatchManager | **180.0 s** | Match duration |
| `auto_start` | MatchManager | **true** | Start match on scene load |
| `respawn_delay` | Combatant | **3.0 s** | Time dead before respawn |
| `team_id` (player) | Combatant on Player | **0** (TEAM_A) | |
| `team_id` (opponents) | Combatant on DummyTarget | **1** (TEAM_B) | |
| `spawn_index` | Combatant | **0** | Selects among group spawn markers |
| `auto_attack` | melee_attacker on DummyTarget | **true** | Opponents swing on cooldown |
| `attack_damage` (opponent) | melee_attacker on DummyTarget | **20.0** | 5 hits to kill player (100 HP) |
| `attack_cooldown` (opponent) | melee_attacker on DummyTarget | **1.5 s** | Slower than player (0.6 s) |
| `attack_range` (opponent) | melee_attacker on DummyTarget | **2.0 m** | Same as player |
| `attack_arc_deg` (opponent) | melee_attacker on DummyTarget | **90°** | Narrower than player (120°) |
| `max_health` (player) | Health on Player | **100.0** | Same as dummy |
| Opponent count | Main.tscn instances | **2** | Add/remove instances to change |
| Opponent placement | Main.tscn transforms | SpawnB (6,1,6), SpawnB2 (8,1,4) | Face arena centre |

#### Server-authoritative readiness notes (M4 prep)

| M3 component | What moves to server in M4 | What stays client-side |
|--------------|---------------------------|----------------------|
| `match_manager.gd` | Authoritative instance on server (phase, scores, timer, register_kill, match-end) | Shadow instance on client (display only; receives replicated state) |
| `combatant.gd` | Death validation, respawn timing + position, team assignment | Visual disable/enable (mesh, collision) as client-side presentation |
| `health.gd` | Server applies damage, emits health_changed → replicated | Client receives health_changed for display |
| `melee_attacker.gd` | Server re-validates range/arc/cooldown on "I attacked" intent | Client sends intent; local prediction optional |
| `player_controller.gd` | Server validates position (anti-cheat) | Local movement prediction |
| `hud.gd` | — | Purely client-side display |
| `camera_rig.gd` | — | Purely client-side |

**Determinism guarantees for M4 lift:**
- MatchManager timer uses `_physics_process` (fixed tick) → server clock is authoritative.
- Kill attribution is synchronous within the `died` signal handler → no race conditions.
- Respawn uses SceneTree timer (real-time seconds) → in M4, server owns the timer and broadcasts
  the respawn event; clients replay visually.
- No `get_tree().reload_current_scene()`, no `Input` reads, no rendering calls in match/combat logic.
- All tunables are `@export` → server can override from config/Resource without code changes.

---

### M4 — Multiplayer PoC (2 clients)
- Research current Godot multiplayer APIs; host/client responsibilities; sync spawning +
  minimal state; server validates damage/health/respawn/score/victory; handle disconnects &
  invalid requests; test latency; document limitations.

**Acceptance:** two clients join one match with consistent, server-validated gameplay.

### M5 — 4v4 Match Foundation
- 8-player limit; two teams of four; team spawn points; match start/timer/score/end; test with
  8 clients (or documented mix). Matchmaking/public deployment out of scope.

**Acceptance:** match rules work; the server determines the result.

### M6 — Art & Character Pipeline
- Base character; rig/animate in Blender or use licensed assets; export GLB/glTF; import to
  Godot; verify scale/skeleton/materials/animations; establish naming & import conventions.

**Acceptance:** one character model imports correctly and plays basic animations.

### M7 — Expand Content
- Second character; one ability per character; character select + HUD; sound/effects/improved
  arena art; incremental roster & arena growth.

### M8 — Online Readiness (separate phase)
- Dedicated server; lobby/matchmaking; auth; monitoring & crash reporting; rate limits & abuse
  handling; network perf testing; security review & deployment process.

---

## Immediate Next Steps

1. **Manual F5 playtest:** verify score/countdown readability and updates (AC-M3-11), all
   result labels (AC-M3-12), and camera/movement/melee feel, including M2 hit feedback.
2. Retain the verified checkpoint locally; remote push remains a separate owner decision.
   Do not mark full M3 complete until manual acceptance passes.
3. Start fresh matches by stopping and running the main scene again (F5). Manager-only
   `start_match()` re-entry does not reset Combatant end-state latches and is unsupported.
4. Plan M4 only after the local loop is accepted; no networking is included in this checkpoint.
