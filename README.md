# ArenaBattle — 3D 4v4 Battle Arena

A third-person 3D platform/action battle arena where **two teams of four players** compete
in the same arena. Built incrementally, milestone by milestone, with a small testable
foundation first.

> **Status (2026-10-16):** M1 movement and M2 melee combat are implemented. Approved M3
> local team deathmatch is implemented and headless-verified; manual HUD/feel acceptance
> checks were accepted by the owner on 2026-10-16. M4 two-client PoC is implemented and automatically verified; manual multiplayer acceptance is pending. See
> [`docs/DEVELOPMENT_ROADMAP.md`](docs/DEVELOPMENT_ROADMAP.md).

---

## Tech Stack

| Concern          | Choice                                   |
|------------------|------------------------------------------|
| Game engine      | Godot 4.x (stable)                        |
| Gameplay language| GDScript (typed where it aids clarity)    |
| 3D authoring     | Blender                                   |
| Asset interchange| glTF 2.0 / GLB                            |
| Version control  | Git                                       |
| Target platform  | Windows PC (first)                        |
| Networking model | Server-authoritative (competitive play)   |

---

## Prerequisites

Before the game can be run or tested, the following must be installed on the machine:

- **Godot 4.x stable** — *required* to open, run and export the project.
- **Git** — version control.
- **Blender** — *required later* (Milestone 6+) for character/arena authoring; not needed
  for the placeholder-mesh prototype.

> Environment check (Windows 25H2, updated 2026-10-15): **Git 2.51.0 installed**; **Godot
> 4.7.2.stable installed & verified**; **Blender NOT installed** (only needed from Milestone 6);
> C: free ~21 GB. Godot editor: `…\Qoder_Personal\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe`
> (use the sibling `..._console.exe` for CLI/headless commands). See
> [`docs/DECISIONS.md`](docs/DECISIONS.md) and [`docs/DEVELOPMENT_ROADMAP.md`](docs/DEVELOPMENT_ROADMAP.md).

This agent-driven project does **not** auto-install software. Install Godot (and Blender when
needed) manually, then confirm the version.

---

## Repository Layout

```text
ArenaBattle/
├── FOUNDATION_INSTRUCTIONS.md   # Working agreement / master instructions (do not overwrite)
├── README.md                    # This file
├── .gitignore
├── docs/                        # Architecture, design, roadmap, agent rules, decisions
│   ├── GAME_DESIGN.md
│   ├── TECHNICAL_ARCHITECTURE.md
│   ├── MULTIPLAYER_DESIGN.md
│   ├── DEVELOPMENT_ROADMAP.md
│   ├── AGENT_RULES.md
│   └── DECISIONS.md
├── icon.svg
├── project.godot                # Godot 4.7 project: main scene, input map, Forward+, gravity
├── scenes/
│   ├── main/Main.tscn           # MatchManager + Arena + Player + two opponents + HUD
│   ├── arena/Arena.tscn         # floor, 4 walls, sun, environment, spawn markers
│   ├── characters/Player.tscn   # CharacterBody3D + capsule + third-person camera rig
│   ├── targets/DummyTarget.tscn # static melee opponent with Health + Combatant
│   └── ui/HUD.tscn              # controls, score, countdown, match result
├── scripts/
│   ├── player/                  # player_controller.gd, camera_rig.gd
│   ├── combat/                  # health.gd, melee_attacker.gd, combatant.gd
│   ├── targets/                 # dummy_target.gd feedback
│   ├── match/                   # match_manager.gd
│   └── ui/                      # hud.gd display
├── tests/
│   └── integration/             # movement, combat, match smoke suites
├── assets/                      # created when first needed (M6+)
└── resources/                   # created when first needed
```

> Folders are created **when first needed**, not pre-made empty (per the foundation rules).
> `assets/` and `resources/` are intentionally absent until a milestone needs them.

---

## How to Run

1. Open the Godot Project Manager → **Import** → select `project.godot` in this folder
   (Godot 4.7.x recommended).
2. Press **F5** (or the Play button) to run the main scene `scenes/main/Main.tscn`.
3. Expected: one controllable capsule and two static opponents in a bounded, lit 30×30
   arena, with third-person mouse look, controls, scores and a 3:00 countdown.
4. Attack opponents to score for TEAM A. Opponents automatically attack when you enter
   their melee range and forward arc; player deaths score for TEAM B. Dead combatants
   respawn at their team markers after 3 seconds with full health.
5. First team to 5 kills wins; otherwise the higher score at time expiry wins (equal scores
   draw). Attacks, scoring and respawns stop after match end. Stop and press F5 again to
   start a fresh scene; restarting existing combatants through `start_match()` is unsupported.

### Automated headless test (no display needed)

From the `ArenaBattle/` folder, using the Godot **console** binary:

```powershell
$godotBinary = "<path>\Godot_v4.7.2-stable_win64_console.exe"
& $godotBinary --headless --path . --import
& $godotBinary --headless --path . --script res://tests/integration/movement_smoke_test.gd
& $godotBinary --headless --path . --script res://tests/integration/combat_smoke_test.gd
& $godotBinary --headless --path . --script res://tests/integration/match_smoke_test.gd
```

Each suite prints `ALL_TESTS_PASS=true` and exits `0` on success (`1` on failure).
Movement covers floor collision, movement and jumping; combat covers health, melee range,
arc and cooldown; match covers scoring, death, respawn and match endings.

Verified on 2026-10-16 with Godot 4.7.2.stable: movement (3 checks), combat (9 checks) and
match (44 checks) each passed twice with `ALL_TESTS_PASS=true`, exit 0. Native import and a
120-frame main-scene smoke run also exited 0 with no errors. Each match run deliberately
emits one null-source warning for safe-degradation coverage. See
[`tests/M3_QA_REPORT.md`](tests/M3_QA_REPORT.md) for evidence and remaining manual gates.

### Manual acceptance still required

Run F5 to verify readable score/countdown updates (AC-M3-11), visible correct match results
(AC-M3-12), and camera/movement/attack feel. Automated label assertions do not verify visual
layout or play feel. Exercise both victory and draw presentation using temporary Inspector
values if needed; restore the defaults afterward.

### Controls

| Action        | Default binding        |
|---------------|------------------------|
| Move          | `W` `A` `S` `D`        |
| Run / sprint  | hold `Shift`           |
| Jump          | `Space`                |
| Camera look   | Mouse move             |
| Attack (M2)   | Left Mouse Button      |
| Release / recapture cursor | `Esc`    |

Bindings are defined as **Godot Input Map actions** (see
[`docs/TECHNICAL_ARCHITECTURE.md`](docs/TECHNICAL_ARCHITECTURE.md)); physical keys are
remappable and never hard-coded in scripts.

---

## Documentation Index

- [`docs/GAME_DESIGN.md`](docs/GAME_DESIGN.md) — vision, scope, core loop, arena & character design.
- [`docs/TECHNICAL_ARCHITECTURE.md`](docs/TECHNICAL_ARCHITECTURE.md) — scene/node structure, script responsibilities, interfaces, input map.
- [`docs/MULTIPLAYER_DESIGN.md`](docs/MULTIPLAYER_DESIGN.md) — server-authoritative networking model and security rules.
- [`docs/DEVELOPMENT_ROADMAP.md`](docs/DEVELOPMENT_ROADMAP.md) — milestones M0–M8 with acceptance criteria.
- [`docs/AGENT_RULES.md`](docs/AGENT_RULES.md) — agent roles, file ownership, collaboration and safety rules.
- [`docs/DECISIONS.md`](docs/DECISIONS.md) — architecture decision log (ADRs) and open questions.

---

## Definition of Done (summary)

A task is complete only when the behaviour is implemented **and tested**, changed files and
decisions are documented, the project runs (or blockers are reported), and acceptance
criteria are checked. Unverified features are never reported as passing. See
[`docs/AGENT_RULES.md`](docs/AGENT_RULES.md).

### M3 follow-up: player hit feedback and health bar

Left-click shows a brief cyan attack arc (also on misses); taking damage flashes the
player red with a light view tint. Bottom-left HP text and a health bar track damage,
death (zero HP) and restored health on respawn. These are placeholder visuals before M4;
polished animation/effects remain M6/M7. F5 visual acceptance is still required.

### M4 two-client multiplayer proof of concept

Owner accepted M3 and its player feedback/health HUD on 2026-10-16. A separate
`scenes/multiplayer/MultiplayerArena.tscn` adds a local server and two clients. Run
`.\tools\start_multiplayer.ps1` from PowerShell in this folder to open both game windows.
Close both windows to stop the local server. F5/Main.tscn continues to run the local game.

The server controls movement, hits, HP, respawn, scoring and match results. This is a
loopback proof of concept; manual two-client acceptance remains pending. See
`docs/M4_MULTIPLAYER_PLAN.md` for setup, tests and latency/packet-loss limitations.
