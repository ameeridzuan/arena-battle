# ArenaBattle — 3D 4v4 Battle Arena

A third-person 3D platform/action battle arena where **two teams of four players** compete
in the same arena. Built incrementally, milestone by milestone, with a small testable
foundation first.

> **Status:** Milestone 0 (Foundation & Plan) — documentation and project structure only.
> Gameplay implementation (Milestone 1) has **not** started and is pending plan approval.

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

> Environment check on 2026-10-14 (Windows 25H2): **Git 2.51.0 installed**; **Godot NOT
> installed**; **Blender NOT installed**; C: free space ~21.3 GB. See
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
├── project.godot                # Created at Milestone 1 (pending approval)
├── assets/                      # Created when first needed
├── scenes/                      # Created when first needed
├── scripts/                     # Created when first needed
├── resources/                   # Created when first needed
└── tests/                       # Created when first needed
```

> Folders are created **when first needed**, not pre-made empty (per the foundation rules).
> The engine/project files and `scenes/`, `scripts/`, `assets/`, `resources/`, `tests/`
> directories are introduced with Milestone 1 once the plan is approved.

---

## How to Run (available from Milestone 1)

1. Install **Godot 4.x stable** and note the exact version.
2. Open the Godot Project Manager → **Import** → select `project.godot` in this folder.
3. Press **F5** (or the Play button) to run the main scene.
4. Expected: a placeholder third-person character you can move, turn and jump inside a
   bounded, lit arena.

### Controls (proposed for Milestone 1)

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
