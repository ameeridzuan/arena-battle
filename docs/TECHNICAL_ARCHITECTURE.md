# Technical Architecture — ArenaBattle

> Milestone 0 design; updated at Milestone 2 (combat). Describes the intended Godot 4 structure
> and interfaces.

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
│   ├── characters/  # Player.tscn — CharacterBody3D + camera rig + mesh + hitbox
│   ├── targets/     # DummyTarget.tscn (Milestone 2)
│   └── ui/          # HUD / labels / menus
├── scripts/
│   ├── core/        # game bootstrap, shared constants/config, service locators
│   ├── player/      # player_controller.gd, camera_rig.gd
│   ├── combat/      # health.gd, melee_attacker.gd (Milestone 2)
│   ├── targets/     # dummy_target.gd (Milestone 2)
│   ├── abilities/   # (later)
│   ├── multiplayer/ # (Milestone 4+) network manager, replication
│   ├── match/       # (Milestone 3+) match/round/score logic
│   └── ui/          # HUD scripts
├── resources/       # characters/ weapons/ abilities/ — data-driven .tres
└── tests/           # unit/ integration/
```

Folders created at M1: `scenes/main`, `scenes/arena`, `scenes/characters`, `scenes/ui`,
`scripts/player`.
Folders created at M2: `scenes/targets`, `scripts/combat`, `scripts/targets`.

## 3. Scene Graphs

### 3.1 Milestone 1 — Main (unchanged structure)

```text
Main (Node3D)                        # scenes/main/Main.tscn — project main scene
├── Arena (instance of Arena.tscn)
│   ├── Floor (StaticBody3D)         # collision_layer=1, collision_mask=1
│   ├── Walls (Node3D)
│   │   ├── WallNorth (StaticBody3D) # collision_layer=1, collision_mask=1
│   │   ├── WallSouth (StaticBody3D)
│   │   ├── WallWest  (StaticBody3D)
│   │   └── WallEast  (StaticBody3D)
│   ├── DirectionalLight3D
│   ├── WorldEnvironment
│   └── SpawnPoints (Node3D)
│       ├── SpawnA (Marker3D)
│       └── SpawnB (Marker3D)
├── Player (instance of Player.tscn) # position (0, 1, 0)
└── HUD (instance of HUD.tscn)
```

### 3.2 Milestone 2 — Player.tscn (updated)

```text
Player (CharacterBody3D)             # collision_layer=2, collision_mask=5
├── CollisionShape3D                 # CapsuleShape3D radius=0.5, height=2.0
├── Mesh (MeshInstance3D)            # CapsuleMesh radius=0.5, height=2.0
├── CameraPivot (Node3D)             # camera_rig.gd — yaw rotation
│   └── CameraTilt (Node3D)
│       └── Camera3D                 # current=true, fov=70, offset (0, 1.2, 4.0)
└── AttackHitbox (Area3D)            # melee_attacker.gd — collision_layer=0, collision_mask=4
    └── CollisionShape3D             # SphereShape3D radius set from attack_range export
```

### 3.3 Milestone 2 — DummyTarget.tscn (new)

```text
DummyTarget (StaticBody3D)           # dummy_target.gd — collision_layer=4, collision_mask=0
├── CollisionShape3D                 # BoxShape3D size=(1.0, 2.0, 1.0)
├── Mesh (MeshInstance3D)            # BoxMesh size=(1.0, 2.0, 1.0) + StandardMaterial3D
└── Health (Node)                    # health.gd — max_health=100.0
```

### 3.4 Milestone 2 — Main.tscn (updated)

```text
Main (Node3D)
├── Arena (instance)
├── Player (instance)                # position (0, 1, 0)
├── DummyTarget (instance)           # position (0, 1, -4) — 4 m in front of default camera
└── HUD (instance)
```

## 4. Script Responsibilities

### 4.1 Milestone 1 (unchanged)

| Script | Node | Responsibility |
|--------|------|----------------|
| `player_controller.gd` | `Player (CharacterBody3D)` | Camera-relative movement, gravity, jump, `move_and_slide()`, face mesh toward travel. **No combat logic.** |
| `camera_rig.gd` | `CameraPivot` | Mouse-look yaw/pitch, Esc toggles cursor capture. |
| `hud.gd` (if used) | `HUD` | Static controls label. |

### 4.2 Milestone 2 (new)

| Script | Node | Responsibility |
|--------|------|----------------|
| `health.gd` | `Health (Node)` child | Reusable health component. Stores current HP, clamps 0…max, emits `health_changed` / `died`. Exposes `apply_damage(amount, source)` and `get_health()`. |
| `melee_attacker.gd` | `AttackHitbox (Area3D)` child of Player | Reads `attack` input in `_physics_process`, manages cooldown timer, queries `get_overlapping_bodies()`, applies arc filter using CameraPivot forward, calls `apply_damage` on valid targets. Owns all attack tunables. |
| `dummy_target.gd` | `DummyTarget (StaticBody3D)` root | Registers in `"damageable"` group, delegates `apply_damage`/`get_health` to Health child, emits print feedback on hit/death, flashes mesh color. |

## 5. Input Map

Defined in Project Settings → Input Map, referenced by action name in code (never raw keys):

| Action name     | Default binding | Notes |
|-----------------|-----------------|-------|
| `move_forward`  | `W`             | camera-relative |
| `move_back`     | `S`             | |
| `move_left`     | `A`             | |
| `move_right`    | `D`             | |
| `run`           | `Shift`         | held modifier |
| `jump`          | `Space`         | |
| `attack`        | Left Mouse      | **used at Milestone 2** — read in `melee_attacker.gd` |

Mouse look uses captured mouse mode (`Input.MOUSE_MODE_CAPTURED`) with an `Esc` toggle to
release the cursor — implemented in `camera_rig.gd`.

## 6. Combat Interface (Milestone 2 — ADR-0005 + ADR-0007)

### 6.1 Damage contract

```gdscript
## Any PhysicsBody3D that can receive damage MUST:
##   1. Be in group "damageable".
##   2. Expose these methods on its root node:
func apply_damage(amount: float, source: Node) -> void
func get_health() -> float
```

The `source` parameter is the node that **owns** the attack (e.g. the Player CharacterBody3D),
NOT the hitbox Area3D. This is the node a future server will identify as the attacker.

### 6.2 Health component (`scripts/combat/health.gd`)

```gdscript
extends Node
class_name Health

signal health_changed(current: float, maximum: float)
signal died

@export var max_health: float = 100.0

var _current: float = 0.0

func _ready() -> void:
    _current = max_health

func apply_damage(amount: float, _source: Node) -> void:
    if _current <= 0.0:
        return                       # already dead — no overkill processing
    _current = maxf(_current - amount, 0.0)
    health_changed.emit(_current, max_health)
    if _current <= 0.0:
        died.emit()

func get_health() -> float:
    return _current
```

Rules:
- Amount is **always positive** (healing is a future separate method, not negative damage).
- Health **clamps at 0**; never goes negative.
- `died` fires **exactly once** (after that, `apply_damage` early-returns).
- No frame-rate dependency; purely event-driven.

### 6.3 Melee attacker (`scripts/combat/melee_attacker.gd`)

```gdscript
extends Area3D
## Attached to the AttackHitbox (Area3D) child of the Player.

@export_group("Melee Attack")
@export var attack_damage: float = 25.0       # HP removed per hit
@export var attack_range: float = 2.0         # metres — radius of the sphere hitbox
@export var attack_cooldown: float = 0.6      # seconds between attacks
@export var attack_arc_deg: float = 120.0     # total cone width in degrees

@export_group("References")
@export var aim_reference_path: NodePath = ^"../CameraPivot"

var _cooldown_remaining: float = 0.0
var _aim_ref: Node3D

func _ready() -> void:
    _aim_ref = get_node(aim_reference_path) as Node3D
    # Sync sphere radius with exported range
    var shape := $CollisionShape3D.shape as SphereShape3D
    if shape:
        shape.radius = attack_range

func _physics_process(delta: float) -> void:
    if _cooldown_remaining > 0.0:
        _cooldown_remaining -= delta
    if Input.is_action_just_pressed("attack") and _cooldown_remaining <= 0.0:
        _perform_attack()

func _perform_attack() -> void:
    _cooldown_remaining = attack_cooldown
    var forward := _get_attack_forward()
    for body in get_overlapping_bodies():
        if not body.is_in_group("damageable"):
            continue
        if _within_arc(body, forward):
            body.apply_damage(attack_damage, get_parent())

func _get_attack_forward() -> Vector3:
    var basis := _aim_ref.global_transform.basis
    var fwd := Vector3(-basis.z.x, 0.0, -basis.z.z)
    return fwd.normalized() if fwd.length_squared() > 0.0001 else Vector3.FORWARD

func _within_arc(body: Node3D, forward: Vector3) -> bool:
    var to_body := body.global_position - global_position
    to_body.y = 0.0
    if to_body.length_squared() < 0.001:
        return true                  # body is at same XZ — always in arc
    to_body = to_body.normalized()
    var angle := rad_to_deg(forward.angle_to(to_body))
    return angle <= attack_arc_deg * 0.5
```

### 6.4 Dummy target (`scripts/targets/dummy_target.gd`)

```gdscript
extends StaticBody3D

@onready var _health: Health = $Health
@onready var _mesh: MeshInstance3D = $Mesh

func _ready() -> void:
    add_to_group("damageable")
    _health.health_changed.connect(_on_health_changed)
    _health.died.connect(_on_died)

## --- Combat interface (single path for all damage) ---
func apply_damage(amount: float, source: Node) -> void:
    _health.apply_damage(amount, source)

func get_health() -> float:
    return _health.get_health()

## --- Feedback ---
func _on_health_changed(current: float, maximum: float) -> void:
    print("[DummyTarget] health: %.1f / %.1f" % [current, maximum])
    _flash_red()

func _on_died() -> void:
    print("[DummyTarget] DIED")

func _flash_red() -> void:
    var mat := _mesh.get_surface_override_material(0) as StandardMaterial3D
    if mat == null:
        mat = StandardMaterial3D.new()
        _mesh.set_surface_override_material(0, mat)
    mat.albedo_color = Color(1.0, 0.2, 0.2, 1.0)
    get_tree().create_timer(0.15).timeout.connect(func() -> void:
        mat.albedo_color = Color(0.8, 0.8, 0.8, 1.0)
    )
```

## 7. Collision Layer / Mask Plan (Milestone 2)

Godot 4 uses a 32-bit integer for `collision_layer` and `collision_mask`. The editor shows them as
numbered checkboxes (1-based). Bitmask value = 2^(layer_number − 1).

| Editor layer # | Bitmask value | Name (set in Project Settings) | Assigned to |
|:-:|:-:|---|---|
| 1 | 1 | `World` | Floor, Walls (StaticBody3D) |
| 2 | 2 | `Player` | Player (CharacterBody3D) |
| 3 | 4 | `DamageableTarget` | DummyTarget and future targets |
| 4 | 8 | *(reserved — projectiles/hazards, M3+)* | — |

### Node collision settings

| Node | `collision_layer` | `collision_mask` | Rationale |
|------|:-:|:-:|---|
| Floor / Walls | 1 | 1 (default) | Static world; mask irrelevant for StaticBody3D |
| Player (CharacterBody3D) | 2 | 5 (= 1 + 4) | Collides with world (1) and targets (4); NOT detected by own hitbox |
| DummyTarget (StaticBody3D) | 4 | 0 | On target layer; does not detect anything |
| AttackHitbox (Area3D) | 0 | 4 | Detects only layer 3 (DamageableTarget); never sees Player (layer 2) |

**Key invariant:** `AttackHitbox.collision_mask` (4) does NOT include `Player.collision_layer` (2),
so `get_overlapping_bodies()` can never return the player. The additional `is_in_group("damageable")`
filter in code provides a second semantic safety net.

### Project Settings addition

```ini
[layer_names]

3d_physics_layer_1="World"
3d_physics_layer_2="Player"
3d_physics_layer_3="DamageableTarget"
```

## 8. Godot Project Settings

- `application/run/main_scene` → `res://scenes/main/Main.tscn`
- `input/*` → the actions in §5 (already configured; `attack` = Left Mouse Button).
- `rendering` → Forward+ renderer (confirmed Godot 4.7.2).
- `physics/3d/default_gravity` → 20.0
- `layer_names/3d_physics_layer_*` → see §7.

## 9. Verification Approach

Godot **4.7.2.stable** is installed and headless verification is available:
1. `godot --headless --path . --import` (asset/import validation).
2. `godot --headless --path . --script res://tests/integration/<test>.gd` (integration tests).
3. Manual F5 playtest for visual/feel checks.

M2 test: `tests/integration/combat_smoke_test.gd` — verifies damage, range, cooldown, death.

No feature will be reported as "passing" until it has actually been run.

## 10. Server-Authoritative Readiness (M4 prep)

M2 design choices that keep the door open for server-authoritative multiplayer:

| Concern | M2 decision | M4 path |
|---------|-------------|---------|
| Damage logic separation | `health.gd` is a pure state machine with no scene-tree coupling | Server runs the same Health node; client sends "I attacked" → server validates range/cooldown then calls `apply_damage` |
| Deterministic cooldown | `_cooldown_remaining` decremented by `delta` in `_physics_process` | Server ticks at fixed rate; client prediction mirrors locally |
| Config-driven tunables | All values are `@export` on the node | Values can come from a replicated Resource or server config |
| Source identification | `apply_damage(amount, source)` passes the attacker node | In M4, `source` becomes a peer_id / player_id reference |
| Group-based filtering | `"damageable"` group | Server maintains authoritative target registry |

No networking code is added at M2; the architecture simply avoids decisions that would block it.

## 11. Risks & Dependencies

- **Godot 4.7.2 confirmed** — renderer Forward+, API verified for Area3D/StaticBody3D.
- **Headless testing available** — integration tests run via `--script`.
- Placeholder meshes keep the art pipeline off the critical path.
- Melee arc check uses XZ-plane projection only (no vertical angle) — acceptable for ground combat.
- `get_overlapping_bodies()` is updated once per physics frame *before* the step; the attack
  reads it in `_physics_process`, so the data is at most 1 frame stale (irrelevant at 60 Hz).
