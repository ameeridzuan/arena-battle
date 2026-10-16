# Technical Architecture — ArenaBattle

> Milestone 0 design; updated at Milestone 2 (combat) and Milestone 3 (local gameplay loop).
> Describes the intended Godot 4 structure and interfaces.

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
│   ├── combat/      # health.gd, melee_attacker.gd, combatant.gd (Milestone 3)
│   ├── targets/     # dummy_target.gd (Milestone 2)
│   ├── abilities/   # (later)
│   ├── multiplayer/ # (Milestone 4+) network manager, replication
│   ├── match/       # match_manager.gd (Milestone 3)
│   └── ui/          # hud.gd (Milestone 3)
├── resources/       # characters/ weapons/ abilities/ — data-driven .tres
└── tests/           # unit/ integration/
```

Folders created at M1: `scenes/main`, `scenes/arena`, `scenes/characters`, `scenes/ui`,
`scripts/player`.
Folders created at M2: `scenes/targets`, `scripts/combat`, `scripts/targets`.
Folders created at M3: `scripts/match`, `scripts/ui`.

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

### 3.5 Milestone 3 — Player.tscn (updated)

```text
Player (CharacterBody3D)             # collision_layer=2, collision_mask=5
├── CollisionShape3D                 # CapsuleShape3D radius=0.5, height=2.0
├── Mesh (MeshInstance3D)            # CapsuleMesh radius=0.5, height=2.0
├── CameraPivot (Node3D)             # camera_rig.gd
│   └── CameraTilt (Node3D)
│       └── Camera3D
├── AttackHitbox (Area3D)            # melee_attacker.gd — collision_layer=0, collision_mask=4
│   └── CollisionShape3D             # SphereShape3D radius=2.0
├── Health (Node)                    # health.gd — max_health=100.0           ← NEW (M3)
└── Combatant (Node)                 # combatant.gd — team_id=0, respawn_delay=3.0  ← NEW (M3)
```

### 3.6 Milestone 3 — DummyTarget.tscn (updated → opponent)

```text
DummyTarget (StaticBody3D)           # dummy_target.gd — collision_layer=4, collision_mask=0
├── CollisionShape3D                 # BoxShape3D size=(1.0, 2.0, 1.0)
├── Mesh (MeshInstance3D)            # BoxMesh size=(1.0, 2.0, 1.0) + StandardMaterial3D
├── Health (Node)                    # health.gd — max_health=100.0
├── Combatant (Node)                 # combatant.gd — team_id=1, respawn_delay=3.0  ← NEW (M3)
└── AttackHitbox (Area3D)            # melee_attacker.gd — auto_attack=true          ← NEW (M3)
    │                                #   collision_layer=0, collision_mask=2 (detects Player)
    │                                #   aim_reference_path=^"..", attack_damage=20,
    │                                #   attack_cooldown=1.5, attack_range=2.0, attack_arc_deg=90
    └── CollisionShape3D             # SphereShape3D radius=2.0
```

### 3.7 Milestone 3 — Arena.tscn (updated spawn points)

```text
└── SpawnPoints (Node3D)
    ├── SpawnA  (Marker3D)           # (-6, 1.0, -6)  groups=["spawn_team_0"]
    ├── SpawnB  (Marker3D)           # ( 6, 1.0,  6)  groups=["spawn_team_1"]
    └── SpawnB2 (Marker3D)           # ( 8, 1.0,  4)  groups=["spawn_team_1"]  ← NEW (M3)
```

### 3.8 Milestone 3 — Main.tscn (updated)

```text
Main (Node3D)
├── MatchManager (Node)              # match_manager.gd                        ← NEW (M3)
│                                    #   score_limit=5, time_limit=180.0, auto_start=true
├── Arena (instance)
├── Player (instance)                # position = SpawnA (-6, 1, -6)
├── Opponent1 (instance DummyTarget) # position = SpawnB (6, 1, 6), rotated to face centre
├── Opponent2 (instance DummyTarget) # position = SpawnB2 (8, 1, 4), rotated to face centre
│                                    #   Combatant.spawn_index=1
└── HUD (instance)
```

### 3.9 Milestone 3 — HUD.tscn (updated)

```text
HUD (CanvasLayer)                    # hud.gd                                  ← NEW script (M3)
├── ControlsLabel (Label)            # existing — text updated for M3
├── ScoreLabel (Label)               # "TEAM A: 0  |  TEAM B: 0"              ← NEW (M3)
├── TimerLabel (Label)               # "3:00"                                  ← NEW (M3)
└── ResultLabel (Label)              # hidden; shown on match_ended            ← NEW (M3)
```

## 4. Script Responsibilities

### 4.1 Milestone 1 (unchanged)

| Script | Node | Responsibility |
|--------|------|----------------|
| `player_controller.gd` | `Player (CharacterBody3D)` | Camera-relative movement, gravity, jump, `move_and_slide()`, face mesh toward travel. **No combat logic.** |
| `camera_rig.gd` | `CameraPivot` | Mouse-look yaw/pitch, Esc toggles cursor capture. |
| `hud.gd` (if used) | `HUD` | Static controls label. |

### 4.2 Milestone 2 (unchanged)

| Script | Node | Responsibility |
|--------|------|----------------|
| `health.gd` | `Health (Node)` child | Reusable health component. Stores current HP, clamps 0…max, emits `health_changed` / `died`. Exposes `apply_damage(amount, source)` and `get_health()`. |
| `melee_attacker.gd` | `AttackHitbox (Area3D)` child of Player | Reads `attack` input in `_physics_process`, manages cooldown timer, queries `get_overlapping_bodies()`, applies arc filter using CameraPivot forward, calls `apply_damage` on valid targets. Owns all attack tunables. |
| `dummy_target.gd` | `DummyTarget (StaticBody3D)` root | Registers in `"damageable"` group, delegates `apply_damage`/`get_health` to Health child, emits print feedback on hit/death, flashes mesh color. |

### 4.3 Milestone 3 (new)

| Script | Node | Responsibility |
|--------|------|----------------|
| `match_manager.gd` | `MatchManager (Node)` in Main.tscn | Owns match state: phase (WAITING/RUNNING/ENDED), per-team scores, countdown timer. Exposes `start_match()`, `register_kill(scorer, victim)`, signals. Pure/deterministic logic — no rendering, no input, no scene-tree shortcuts. Joins group `"match_manager"`. |
| `combatant.gd` | `Combatant (Node)` child of Player / DummyTarget | Team identity (`team_id`), death→kill-attribution→MatchManager notification, respawn scheduling (disable/enable cycle), spawn-point lookup by group. Does NOT own movement or attack logic. |
| `hud.gd` | `HUD (CanvasLayer)` root | Connects to MatchManager signals; updates ScoreLabel, TimerLabel, ResultLabel. Pure display — no game logic. |

### 4.4 Milestone 3 — minimal additions to existing scripts

| Script | Addition | Rationale |
|--------|----------|-----------|
| `health.gd` | `var last_damage_source: Node = null` (set in `apply_damage`); `func reset() -> void` | Kill attribution needs the source after `died` fires; respawn needs health restoration. Backward-compatible — no signal signature changes. |
| `melee_attacker.gd` | `@export var auto_attack: bool = false`; modified `_physics_process` branch | Lets dummy opponents attack on cooldown without reading player input. Default `false` = existing M2 behaviour preserved. |
| `player_controller.gd` | `func _ready()` → `add_to_group("damageable")`; `func apply_damage(amount, source)` → delegates to `$Health`; `func get_health() -> float` → delegates to `$Health` | Satisfies the combat-interface contract (§6.1) so enemy hitboxes can damage the player. **No movement logic changed.** |

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

**No new input actions required for M3.**

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

### 6.5 Health component — M3 additions (backward-compatible)

Two additions to `scripts/combat/health.gd`. **No signal signatures change.** The M2 combat
smoke test continues to pass without modification.

```gdscript
## --- M3 ADDITION: store the source of the most recent damage for kill attribution ---
var last_damage_source: Node = null

func apply_damage(amount: float, source: Node) -> void:   # signature unchanged
    if _current <= 0.0:
        return
    last_damage_source = source                           # ← NEW: store before clamping
    _current = maxf(_current - amount, 0.0)
    health_changed.emit(_current, max_health)
    if _current == 0.0:
        died.emit()

## --- M3 ADDITION: reset for respawn ---
func reset() -> void:
    _current = max_health
    last_damage_source = null
    health_changed.emit(_current, max_health)
```

**Why `reset()` and not `revive()` or `heal()`:**
- `reset()` is state-machine language: "return to initial state." It matches the existing
  `_ready()` initialisation and is unambiguous.
- `heal(amount)` implies partial restoration (future ability system); `revive()` implies a
  lifecycle concept that belongs to `combatant.gd`, not to the pure Health component.
- Backward-compatible: no existing caller breaks; the M2 test never calls `reset()`.

### 6.6 Melee attacker — M3 addition (backward-compatible)

One new export and a conditional branch in `_physics_process`:

```gdscript
@export var auto_attack: bool = false   # ← NEW: when true, attacks on cooldown without input

func _physics_process(delta: float) -> void:
    _cooldown_remaining -= delta
    if _cooldown_remaining <= 0.0:
        if auto_attack or Input.is_action_just_pressed("attack"):
            _cooldown_remaining = attack_cooldown
            _perform_attack()
```

Default `false` preserves M2 behaviour exactly. The M2 combat smoke test never sets
`auto_attack`, so it remains `false` and all 6 cases pass unchanged.

### 6.7 MatchManager (`scripts/match/match_manager.gd`)

```gdscript
extends Node
## Milestone 3 — match state machine.  Node in Main.tscn (NOT an autoload).
## Joins group "match_manager" so combatants can discover it without hardcoded paths.
## Pure/deterministic: no rendering, no input, no scene-tree shortcuts.
## Designed to lift server-side in M4 with zero logic changes.

enum Phase { WAITING, RUNNING, ENDED }
enum Team { TEAM_A = 0, TEAM_B = 1 }

signal match_started
signal score_changed(team_a_score: int, team_b_score: int)
signal player_died                                       # convenience for HUD/camera
signal match_ended(winner: int)                          # Team value, or -1 for draw

@export var score_limit: int = 5                         # kills to win
@export var time_limit: float = 180.0                    # seconds
@export var auto_start: bool = true                      # start on _ready (deferred)

var phase: Phase = Phase.WAITING
var score_a: int = 0
var score_b: int = 0
var time_remaining: float = 0.0

func _ready() -> void:
    add_to_group("match_manager")
    if auto_start:
        start_match.call_deferred()                      # after all siblings' _ready

func _physics_process(delta: float) -> void:
    if phase != Phase.RUNNING:
        return
    time_remaining = maxf(time_remaining - delta, 0.0)
    if time_remaining <= 0.0:
        _end_match()

func start_match() -> void:
    phase = Phase.RUNNING
    score_a = 0
    score_b = 0
    time_remaining = time_limit
    match_started.emit()

func register_kill(scorer_team: int, victim_team: int) -> void:
    if phase != Phase.RUNNING:
        return
    if scorer_team == victim_team:
        return                                           # TDM awards opposing-team kills only
    if victim_team != Team.TEAM_A and victim_team != Team.TEAM_B:
        return                                           # unknown victim — no score
    if scorer_team == Team.TEAM_A:
        score_a += 1
    elif scorer_team == Team.TEAM_B:
        score_b += 1
    else:
        return                                           # unknown team — no score
    score_changed.emit(score_a, score_b)
    if victim_team == Team.TEAM_A:
        player_died.emit()
    if score_a >= score_limit or score_b >= score_limit:
        _end_match()

func _end_match() -> void:
    if phase == Phase.ENDED:
        return                                           # idempotent
    phase = Phase.ENDED
    var winner: int
    if score_a > score_b:
        winner = Team.TEAM_A
    elif score_b > score_a:
        winner = Team.TEAM_B
    else:
        winner = -1                                      # draw
    match_ended.emit(winner)

## --- Read-only queries (for HUD / tests) ---
func get_phase() -> Phase:
    return phase
func get_time_remaining() -> float:
    return time_remaining
func get_score(team: int) -> int:
    return score_a if team == Team.TEAM_A else score_b
```

**Design notes:**
- `_physics_process` (fixed 60 Hz tick) for the timer → deterministic, matches server tick model.
- `start_match.call_deferred()` ensures all combatants' `_ready()` has fired before the match
  begins (Godot calls `_ready` bottom-up, siblings in tree order; deferred runs after all).
- Combatant calls `register_kill` once per death; the method itself does not deduplicate
  separate requests. It rejects same-team and invalid-team kills. `_end_match` is idempotent
  (guarded by phase check). Server-side request validation/deduplication belongs to M4.
- Draw: `winner = -1`. No overtime in M3.
- M3 starts fresh matches by reloading the main scene (stop and F5 in the editor).
  `start_match()` initializes manager state only; it does not reset Combatant end-state latches.
- No client-only shortcuts (no `get_tree().reload_current_scene()`, no direct node manipulation).

### 6.8 Combatant component (`scripts/combat/combatant.gd`)

```gdscript
extends Node
## Milestone 3 — team identity + death/respawn glue for any combatant body.
## Attach as a child Node alongside Health. Does NOT own movement or attack logic.
## Discovers MatchManager via group "match_manager".

signal combatant_died(team_id: int)
signal combatant_respawned(team_id: int)

@export var team_id: int = 0                             # 0 = TEAM_A (player), 1 = TEAM_B
@export var respawn_delay: float = 3.0                   # seconds
@export var spawn_index: int = 0                         # which spawn marker to use

var _is_dead: bool = false
var _match_over: bool = false
var _health: Health
var _parent_body: Node3D
var _mesh: MeshInstance3D
var _collision: CollisionShape3D
var _attack_hitbox: Area3D
var _match_manager: Node
var _spawn_point: Node3D

func _ready() -> void:
    _parent_body = get_parent() as Node3D
    _health = _parent_body.get_node_or_null("Health") as Health
    _mesh = _parent_body.get_node_or_null("Mesh") as MeshInstance3D
    _collision = _parent_body.get_node_or_null("CollisionShape3D") as CollisionShape3D
    _attack_hitbox = _parent_body.get_node_or_null("AttackHitbox") as Area3D
    _match_manager = get_tree().get_first_node_in_group("match_manager")
    _resolve_spawn_point()
    if _health:
        _health.died.connect(_on_died)
    if _match_manager:
        _match_manager.match_ended.connect(_on_match_ended)

func get_team_id() -> int:
    return team_id

func is_dead() -> bool:
    return _is_dead

## --- Death → kill attribution → respawn scheduling ---
func _on_died() -> void:
    if _is_dead:
        return
    _is_dead = true
    combatant_died.emit(team_id)
    _attribute_kill()
    _disable_combatant()
    if not _match_over:
        get_tree().create_timer(respawn_delay).timeout.connect(_respawn)

func _attribute_kill() -> void:
    if _match_manager == null:
        return
    var source: Node = _health.last_damage_source if _health else null
    var scorer_team := _resolve_team(source)
    if scorer_team >= 0:
        _match_manager.register_kill(scorer_team, team_id)

func _resolve_team(source: Node) -> int:
    ## Maps an attacker node → its team_id.  Returns -1 if unresolvable (safe degradation).
    if source == null or not is_instance_valid(source):
        return -1
    var combatant := source.get_node_or_null("Combatant")
    if combatant and combatant.has_method("get_team_id"):
        return combatant.get_team_id()
    return -1

## --- Disable / enable cycle ---
func _disable_combatant() -> void:
    if _collision:
        _collision.disabled = true
    if _mesh:
        _mesh.visible = false
    _parent_body.set_physics_process(false)
    if _attack_hitbox:
        _attack_hitbox.set_physics_process(false)

func _respawn() -> void:
    if _match_over:
        return
    _is_dead = false
    if _spawn_point:
        _parent_body.global_position = _spawn_point.global_position
    if _collision:
        _collision.disabled = false
    if _mesh:
        _mesh.visible = true
    if _health:
        _health.reset()
    _parent_body.set_physics_process(true)
    if _attack_hitbox:
        _attack_hitbox.set_physics_process(true)
    combatant_respawned.emit(team_id)

func _on_match_ended(_winner: int) -> void:
    _match_over = true
    if _attack_hitbox:
        _attack_hitbox.set_physics_process(false)

## --- Spawn point resolution (by group) ---
func _resolve_spawn_point() -> void:
    var group_name := "spawn_team_%d" % team_id
    var spawns := get_tree().get_nodes_in_group(group_name)
    if spawns.size() > 0:
        _spawn_point = spawns[spawn_index % spawns.size()] as Node3D
```

**Design notes:**
- Spawn lookup by **group** (not NodePath) → robust against scene-tree restructuring; works in
  tests that re-parent nodes.
- `spawn_index` selects among multiple markers in the same group → supports N combatants per team.
- `_resolve_team(source)` degrades safely: null source → -1 → no kill registered (prevents crash
  on environmental/future damage with no attacker).
- Respawn uses `SceneTree.create_timer()` → fires regardless of the parent's process mode.
- `_match_over` flag prevents respawn after the match ends.
- Player-specific: `set_physics_process(false)` on the Player root stops movement input processing.
  Camera rig (a child) is unaffected — the player can still look around while dead.

### 6.9 Kill-attribution flow (end-to-end)

```text
1. Attacker's melee_attacker._perform_attack()
   → body.apply_damage(attack_damage, _owner_body)
     where _owner_body = get_parent() = the attacker's root body (Player or DummyTarget)

2. Target root's apply_damage(amount, source)
   → _health.apply_damage(amount, source)

3. Health.apply_damage:
   → last_damage_source = source        [M3 addition]
   → _current -= amount; clamp 0
   → health_changed.emit(...)
   → if _current == 0: died.emit()

4. Combatant._on_died()  [connected to Health.died]
   → reads _health.last_damage_source   (= attacker's root body node)
   → _resolve_team(source):
       source.get_node_or_null("Combatant").get_team_id()
       → returns attacker's team_id (0 or 1)
       → if source is null / has no Combatant → returns -1 (no score awarded)
   → _match_manager.register_kill(scorer_team, self.team_id)

5. MatchManager.register_kill(scorer_team, victim_team):
   → increments scorer's score
   → score_changed.emit(score_a, score_b)
   → if victim_team == TEAM_A: player_died.emit()
   → if score >= score_limit: _end_match()
```

**Safe degradation:** if `source` is `null` (environmental damage, future hazards) or the source
node has no `Combatant` child, `_resolve_team` returns `-1` and `register_kill` is NOT called.
The death still processes (disable + respawn) but no team scores. A warning is printed.

### 6.10 Respawn flow

```text
Death:
  Combatant._on_died()
    → _is_dead = true
    → combatant_died.emit(team_id)
    → _attribute_kill()  [kill attribution flow above]
    → _disable_combatant():
        CollisionShape3D.disabled = true
        Mesh.visible = false
        parent_body.set_physics_process(false)      [stops movement / auto-attack]
        AttackHitbox.set_physics_process(false)      [stops input/auto attacks]
    → SceneTree timer (respawn_delay seconds) → _respawn()

Respawn:
  Combatant._respawn()
    → if _match_over: return (no respawn after match end)
    → _is_dead = false
    → parent_body.global_position = _spawn_point.global_position
    → CollisionShape3D.disabled = false
    → Mesh.visible = true
    → Health.reset()  [_current = max_health, last_damage_source = null, health_changed emitted]
    → parent_body.set_physics_process(true)
    → AttackHitbox.set_physics_process(true)
    → combatant_respawned.emit(team_id)
```

**"Dead" state definition:**
- **Player:** input disabled (physics_process off → no movement/jump; AttackHitbox off → no
  attacks), mesh hidden, collision off. Camera remains active (player observes arena).
- **Dummy opponents:** auto-attack stops (AttackHitbox physics_process off), mesh hidden,
  collision off. **Disabled in place, NOT removed.** Justification: simpler lifecycle, symmetric
  disable/enable, stable node tree for M4 server entity mapping, no re-instantiation overhead.

## 7. Collision Layer / Mask Plan (Milestone 2 + M3 additions)

Godot 4 uses a 32-bit integer for `collision_layer` and `collision_mask`. The editor shows them as
numbered checkboxes (1-based). Bitmask value = 2^(layer_number − 1).

| Editor layer # | Bitmask value | Name (set in Project Settings) | Assigned to |
|:-:|:-:|---|---|
| 1 | 1 | `World` | Floor, Walls (StaticBody3D) |
| 2 | 2 | `Player` | Player (CharacterBody3D) |
| 3 | 4 | `DamageableTarget` | DummyTarget and future targets |
| 4 | 8 | *(reserved — projectiles/hazards, M3+)* | — |

### Node collision settings (M3 updated)

| Node | `collision_layer` | `collision_mask` | Rationale |
|------|:-:|:-:|---|
| Floor / Walls | 1 | 1 (default) | Static world; mask irrelevant for StaticBody3D |
| Player (CharacterBody3D) | 2 | 5 (= 1 + 4) | Collides with world (1) and targets (4); NOT detected by own hitbox |
| DummyTarget (StaticBody3D) | 4 | 0 | On target layer; does not detect anything |
| Player → AttackHitbox (Area3D) | 0 | 4 | Detects only layer 3 (DamageableTarget); never sees Player (layer 2) |
| DummyTarget → AttackHitbox (Area3D) | 0 | 2 | **M3 NEW:** Detects only layer 2 (Player); never sees other dummies (layer 4) |

**Key invariants (M3):**
- Player's AttackHitbox mask (4) excludes Player's layer (2) → no self-hit.
- Dummy's AttackHitbox mask (2) excludes Dummy's layer (4) → dummies never hit each other.
- Both hitboxes use the `is_in_group("damageable")` code filter as a semantic safety net.
- Player is NOW in group `"damageable"` (M3 addition) so dummy hitboxes can damage it.

### Project Settings addition (unchanged from M2)

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
- **No new project settings required for M3.** (MatchManager is a scene node, not an autoload.)

## 9. Verification Approach

Godot **4.7.2.stable** is installed and headless verification is available:
1. `godot --headless --path . --import` (asset/import validation).
2. `godot --headless --path . --script res://tests/integration/<test>.gd` (integration tests).
3. Manual F5 playtest for visual/feel checks.

M2 test: `tests/integration/combat_smoke_test.gd` — verifies damage, range, cooldown, death.
M3 test: `tests/integration/match_smoke_test.gd` — verifies match lifecycle, scoring, respawn, end.

**M2 regression:** `combat_smoke_test.gd` must still pass after M3 changes. The additions to
`health.gd` and `melee_attacker.gd` are backward-compatible (no signal/API changes, defaults
preserve M2 behaviour). Regression fixtures must isolate the original combat contract from
M3 opponent auto-attacks, death/respawn and scene-node changes. The player's own AttackHitbox
mask (4) still excludes the player's layer (2).

No feature will be reported as "passing" until it has actually been run.

**Verified checkpoint (2026-10-16):** Godot 4.7.2.stable native import and 120-frame
main-scene headless smoke exited 0 without errors. Movement (3 checks), combat (9 checks)
and match (44 checks) each passed twice with `ALL_TESTS_PASS=true` and exit 0. Match coverage
includes lifecycle/respawn, both score-limit winners, all timed outcomes, post-match gates,
invalid/friendly kills, HUD text/state, null-source degradation and actual runtime inward
opponent facing. One expected null-source warning is emitted by each match suite.
See [`../tests/M3_QA_REPORT.md`](../tests/M3_QA_REPORT.md). Visual HUD layout/results
(AC-M3-11/12) and play feel remain manual acceptance gates.

## 10. Server-Authoritative Readiness (M4 prep)

M2 design choices that keep the door open for server-authoritative multiplayer:

| Concern | M2 decision | M4 path |
|---------|-------------|---------|
| Damage logic separation | `health.gd` is a pure state machine with no scene-tree coupling | Server runs the same Health node; client sends "I attacked" → server validates range/cooldown then calls `apply_damage` |
| Deterministic cooldown | `_cooldown_remaining` decremented by `delta` in `_physics_process` | Server ticks at fixed rate; client prediction mirrors locally |
| Config-driven tunables | All values are `@export` on the node | Values can come from a replicated Resource or server config |
| Source identification | `apply_damage(amount, source)` passes the attacker node | In M4, `source` becomes a peer_id / player_id reference |
| Group-based filtering | `"damageable"` group | Server maintains authoritative target registry |

### M3 additions to server-readiness

| Concern | M3 decision | M4 path |
|---------|-------------|---------|
| Match rules separation | `match_manager.gd` is pure logic (no rendering, no input, no scene-tree shortcuts) | Runs identically on dedicated server; clients receive replicated phase/score/timer |
| MatchManager as scene node (not autoload) | Scoped lifecycle; no global state leakage | Server scene has authoritative instance; client scene has shadow instance that only displays replicated state |
| Kill attribution via `last_damage_source` | Source node → Combatant child → team_id | In M4, source maps to `peer_id`; server validates the kill before awarding score |
| Respawn in `combatant.gd` | Disable/enable cycle + SceneTree timer + spawn-point group lookup | Server owns respawn timing; broadcasts "respawn at position" to clients; clients replay visually |
| Timer via `_physics_process` | Fixed-timestep countdown (deterministic) | Server tick is the single clock; clients interpolate display |
| Team id on Combatant component | Exported int, not hardcoded | Server assigns teams at match start; replicated to clients |
| Draw handling | Explicit `winner = -1` | Server broadcasts draw; clients display |
| No client-only shortcuts | MatchManager never calls `reload_current_scene()`, never reads Input, never accesses rendering | Lift-and-shift to server process |

**What moves to the server in M4:**
- `match_manager.gd` (authoritative instance on server; shadow on client)
- `health.gd` (server applies damage; client receives health_changed)
- `combatant.gd` death/respawn scheduling (server decides timing + position)
- Kill attribution validation (server verifies source identity before scoring)

**What stays client-side in M4:**
- `player_controller.gd` (local prediction; server validates position)
- `camera_rig.gd` (purely visual)
- `hud.gd` (display only; driven by replicated signals)
- `melee_attacker.gd` input reading (client sends "I attacked" intent; server re-validates)

## 11. Risks & Dependencies

- **Godot 4.7.2 confirmed** — renderer Forward+, API verified for Area3D/StaticBody3D.
- **Headless testing available** — integration tests run via `--script`.
- Placeholder meshes keep the art pipeline off the critical path.
- Melee arc check uses XZ-plane projection only (no vertical angle) — acceptable for ground combat.
- `get_overlapping_bodies()` is updated once per physics frame *before* the step; the attack
  reads it in `_physics_process`, so the data is at most 1 frame stale (irrelevant at 60 Hz).
- **M3 risk — auto_attack on static dummies:** dummies swing every `attack_cooldown` regardless
  of whether anything is in range. `_perform_attack()` iterates an empty overlap list harmlessly.
  Negligible perf cost with 2 opponents.
- **M3 risk — M2 test regression:** mitigated by backward-compatible additions only (defaults
  preserve M2 behaviour). QA must re-run `combat_smoke_test.gd` as part of M3 verification.
- **M3 dependency — spawn-point groups:** Arena.tscn markers must join the correct groups before
  combatant.gd can resolve spawn positions. If a group is empty, `_spawn_point` is null and
  respawn occurs in place (safe fallback, logged as warning).

## M3 follow-up — player presentation and health HUD (2026-10-16)

`Player/PlayerFeedback` owns the temporary swipe mesh and player hurt material. It listens
to `AttackHitbox.attack_started(forward)` and `Health.health_changed(current, maximum)`.
The attacker emits the presentation signal once per accepted swing, including misses;
hit rules and cooldowns remain in the attack component. Feedback never writes health.
The swipe radius/arc come from attack configuration; durations/colors are exported.

HUD binds the local player's Health through exported `player_health_path`, initially
`../Player/Health`. It initializes from current HP, then displays health changes, zero HP
on death and restored HP on respawn. It also fades a non-interactive red view tint on
damage. The bar and numeric label anchor to the lower-left viewport corner. In M4, bind
the owning peer's replicated Health; do not choose the first arbitrary combatant.
M6/M7 can replace placeholder presentation while preserving these event hooks.

## M4 — local server/client session

`MultiplayerArena.tscn` owns Arena and Players. Its `network_session.gd` creates the
server MatchManager or client ReplicaMatchState and HUD. It owns ENet/RPC lifecycle,
registration, sender-bound input validation, authoritative control dispatch and snapshots.
PlayerController external control reuses the local movement calculation; CameraPivot's
input is enabled only on the owning client's replica. AttackHitbox external control
reuses existing cooldown/range/arc checks; Health.network_replica prevents local damage
and reset calls. Client Combatant nodes are removed before ready so replicas cannot run
death attribution or respawn timers. Server Combatants retain the accepted lifecycle.
HUD.bind_health supports late-spawned local player binding. The local M3 defaults remain
unchanged. Full interfaces, channel choices, acceptance and limitations: M4_MULTIPLAYER_PLAN.md.
