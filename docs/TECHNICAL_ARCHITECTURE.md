# Technical Architecture — ArenaBattle

> Milestone 0 design. Describes the intended Godot 4 structure and interfaces.
> Nothing here is implemented yet; gameplay code begins only after plan approval.

## 1. Guiding Principles

1. **Separation of concerns:** movement, combat, abilities, networking and match rules live in
   distinct, small scripts.
2. **Reusable scenes & resources** over copy-pasted scripts per character.
3. **Interfaces before parallel work:** define contracts, then implement.
4. **Configurable rules:** tunable values live in exported vars / `Resource`s, not magic numbers.
5. **Typed GDScript** where it improves clarity and catches errors.
6. **Godot conventions** for naming and scene structure.
7. **No speculative abstraction** — solve the current problem only.
8. **Tested or it isn't done.**

## 2. Target Folder Structure

```text
ArenaBattle/
├── project.godot
├── README.md
├── .gitignore
├── docs/
├── assets/          # characters/ weapons/ animations/ environments/ materials/ textures/ audio/ vfx/
├── scenes/
│   ├── main/        # Main.tscn — bootstrap / entry scene
│   ├── arena/       # Arena.tscn — floor, walls, lights, environment, spawns
│   ├── characters/  # Player.tscn — CharacterBody3D + camera rig + mesh
│   ├── targets/     # DummyTarget.tscn (Milestone 2)
│   └── ui/          # HUD / labels / menus
├── scripts/
│   ├── core/        # game bootstrap, shared constants/config, service locators
│   ├── player/      # player_controller.gd, camera_rig.gd
│   ├── combat/      # damage interface, hitboxes (Milestone 2)
│   ├── abilities/   # (later)
│   ├── multiplayer/ # (Milestone 4+) network manager, replication
│   ├── match/       # (Milestone 3+) match/round/score logic
│   └── ui/          # HUD scripts
├── resources/       # characters/ weapons/ abilities/ — data-driven .tres
└── tests/           # unit/ integration/
```

Folders are created **when first needed** (foundation rule). At Milestone 1 the created
directories will be: `scenes/main`, `scenes/arena`, `scenes/characters`, `scenes/ui`,
`scripts/core`, `scripts/player`, `scripts/ui`.

## 3. Milestone 1 Scene Graph (proposed)

```text
Main (Node3D)                        # scenes/main/Main.tscn — set as the project main scene
└── Arena (instance of Arena.tscn)
│   ├── Floor (StaticBody3D)         # CollisionShape3D (BoxShape3D) + MeshInstance3D
│   ├── Walls (StaticBody3D x4)      # perimeter boundaries
│   ├── DirectionalLight3D           # "sun"
│   ├── WorldEnvironment             # ambient light / sky
│   └── SpawnPoints (Node3D)         # Marker3D placeholders for future team spawns
└── Player (instance of Player.tscn)
    └── (CharacterBody3D)
        ├── CollisionShape3D         # CapsuleShape3D
        ├── MeshInstance3D           # placeholder capsule/box mesh
        └── CameraPivot (Node3D)     # yaw/pitch pivot
            └── SpringArm3D
                └── Camera3D         # current = true
└── HUD (CanvasLayer)                # scenes/ui/HUD.tscn — controls label
    └── ControlsLabel (Label)
```

## 4. Script Responsibilities (Milestone 1)

| Script | Node | Responsibility |
|--------|------|----------------|
| `player_controller.gd` | `Player (CharacterBody3D)` | Read input actions, compute camera-relative movement, apply gravity, handle jump, call `move_and_slide()`, rotate body toward movement. Exposes tunable `@export` speed/run/jump/gravity values. |
| `camera_rig.gd` | `CameraPivot` | Capture mouse look (yaw on pivot, pitch clamped on camera/spring arm), keep camera following player. |
| `hud.gd` | `HUD` | Show the static controls/instruction label. |
| `game_config.gd` (optional) | autoload | Central tunable constants if we prefer not to hardcode in each scene. |

> Combat, abilities, match and multiplayer scripts are intentionally **not** created at M1.

## 5. Input Map (proposed actions)

Defined in Project Settings → Input Map, referenced by action name in code (never raw keys):

| Action name     | Default binding | Notes |
|-----------------|-----------------|-------|
| `move_forward`  | `W`             | camera-relative |
| `move_back`     | `S`             | |
| `move_left`     | `A`             | |
| `move_right`    | `D`             | |
| `run`           | `Shift`         | held modifier |
| `jump`          | `Space`         | |
| `attack`        | Left Mouse      | used at Milestone 2 |

Mouse look uses captured mouse mode (`Input.MOUSE_MODE_CAPTURED`) with an `Esc` toggle to
release the cursor — implemented in `camera_rig.gd`.

## 6. Key Interfaces (contracts to honour later)

```gdscript
# Damage contract (introduced at Milestone 2, defined now to avoid rework)
# Any node that can take damage implements:
func apply_damage(amount: float, source: Node) -> void: ...
func get_health() -> float: ...
```

Movement controller will expose a small, stable surface (`velocity`, `is_on_floor()`) so
combat/abilities/network layers can build on it without reaching into internals.

## 7. Godot Project Settings (Milestone 1)

- `application/run/main_scene` → `res://scenes/main/Main.tscn`
- `input/*` → the actions in §5.
- `rendering` → defaults; forward+ or mobile renderer chosen when Godot version is confirmed.
- Physics: default gravity; the controller reads/uses a configurable gravity value.

## 8. Verification Approach

Because **Godot is not installed** on this machine, scripts/scenes **cannot be executed or
auto-verified** by the agent yet. Verification options, in order of preference:
1. Manual run by the user in the Godot editor (F5) against the Milestone 1 acceptance checklist.
2. Later, an approved **restricted local Godot bridge/MCP** to run `--headless --check-only`
   script validation and capture logs (see `FOUNDATION_INSTRUCTIONS.md` §10.4). Not added now.

No feature will be reported as "passing" until it has actually been run.

## 9. Risks & Dependencies

- **Godot version unconfirmed** — exact 4.x stable must be pinned before implementation
  (renderer choice, API differences between 4.0–4.3+).
- **No runtime verification** available to the agent until Godot is installed / a bridge is approved.
- Placeholder meshes keep the art pipeline off the critical path.
