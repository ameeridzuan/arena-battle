# Development Roadmap — ArenaBattle

> Milestone 0 document. Complete and verify each milestone before starting the next.
> Current position: **Milestone 0 done; Milestone 1 implemented & headless-verified (Godot 4.7.2). Next: M2 combat.**

## Environment Gate (blocking M1 run/test)

| Tool   | Status (2026-10-14)         | Needed for |
|--------|-----------------------------|-----------|
| Git    | ✅ Installed (2.51.0)        | version control |
| Godot 4.x | ✅ Installed & verified (**4.7.2.stable**) | open/run/export project |
| Blender | ❌ Not installed            | art pipeline — required from M6 |
| Disk (C:) | ~21.3 GB free             | sufficient for Godot (~0.2 GB) + Blender (~1 GB) |

**Action required from user:** ~~install Godot 4.x stable~~ ✅ Done — Godot 4.7.2.stable verified.
Blender is still needed only at Milestone 6. The agent will not install software without approval.

---

## Milestones

### M0 — Environment & Plan ✅ (this document set)
- [x] Inspect workspace before changing anything.
- [x] Check Godot, Git, Blender availability and versions.
- [x] Confirm new (not existing) repository — workspace is not yet a git repo.
- [x] Write architecture and roadmap docs.
- [x] Identify unresolved design choices + temporary assumptions.
- [ ] **Review & approval by user** (gate for M1).

**Acceptance:** environment, plan, assumptions and next steps documented. *(Met, pending review.)*

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

### M2 — Basic Combat
- Dummy target with health; one basic attack; validated range/hit detection; damage via a
  single `apply_damage` interface; health feedback. No combos/abilities.

**Acceptance:** attack reliably damages within intended range only.

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

## Immediate Next Steps (after approval)

1. User installs **Godot 4.x stable**; report exact version.
2. On approval: `git init` + first commit of the foundation (docs, README, .gitignore).
3. Implement **Milestone 1** exactly as scoped above; verify via manual F5 run + acceptance checklist.
