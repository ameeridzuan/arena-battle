# Development Roadmap — ArenaBattle

> Milestone 0 document. Complete and verify each milestone before starting the next.
> Current position: **Milestone 2 done (headless-verified). Milestone 3 next — design phase (Q5 match objective must be decided first).**

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

### M3 — Local Gameplay Loop
- Player health & death; simple respawn; basic score + match-end condition; separate
  movement/combat/match components.

**Acceptance:** a short local test match starts, plays and ends predictably.

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

1. **Manual F5 playtest (user):** walk to the dummy, attack with Left Mouse, confirm the red
   hit-flash + console `[DummyTarget] health:` prints and that the cooldown feels right (AC-10).
2. **Q5 decided — team-deathmatch** (ADR-0009). M3 design is unblocked.
3. **Architect** drafts the M3 spec (player health/death, respawn, TDM score, match-end) reusing the
   `Health` component; keeps movement/combat/match as separate components.
4. Optional QA follow-up: extend `combat_smoke_test.gd` to exercise the arc at a non-zero
   `CameraPivot` yaw (arc must rotate with the camera).
