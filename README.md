# ArenaBattle — 3D 4v4 Battle Arena

A third-person 3D platform/action battle arena where **two teams of four players** compete
in the same arena. Built incrementally, milestone by milestone, with a small testable
foundation first.

> **Status:** Milestone 1 (Playable 3D Movement) **implemented and headless-verified** with
> Godot 4.7.2. One arena + one third-person character (walk/run/jump/gravity/collision) is
> working. Combat (M2) and multiplayer (M4+) are not started. See
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
│   ├── main/Main.tscn           # entry scene: instances Arena + Player + HUD
│   ├── arena/Arena.tscn         # floor, 4 walls, sun, environment, spawn markers
│   ├── characters/Player.tscn   # CharacterBody3D + capsule + third-person camera rig
│   └── ui/HUD.tscn              # controls label
├── scripts/
│   └── player/                  # player_controller.gd, camera_rig.gd
├── tests/
│   └── integration/movement_smoke_test.gd   # headless floor/movement/jump test
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
3. Expected: a capsule placeholder character you can move, turn and jump inside a bounded,
   lit 30×30 arena, with a third-person mouse-look camera and a controls label.

### Automated headless test (no display needed)

From the `ArenaBattle/` folder, using the Godot **console** binary:

```powershell
& "<path>\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script res://tests/integration/movement_smoke_test.gd
```

It verifies floor collision, movement and jump, prints `ALL_TESTS_PASS=true` and exits `0`
on success (or `1` on failure). Last run: **PASS** (exit 0).

### Controls

| Action        | Default binding        |
|---------------|------------------------|
| Move          | `W` `A` `S` `D`        |
| Run / sprint  | hold `Shift`           |
| Jump          | `Space`                |
| Camera look   | Mouse move             |
| Attack (M2)   | Left Mouse Button      |

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
