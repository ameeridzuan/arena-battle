extends CharacterBody3D
## Milestone 1 — third-person player controller.
##
## Responsibilities (kept intentionally small):
##   - camera-relative movement (walk / run)
##   - gravity and jumping
##   - facing the movement direction
## Milestone 3 adds ONLY the combat-interface contract (group "damageable" +
## apply_damage()/get_health() delegates to the child Health node) so enemy hitboxes can
## damage the player.  Respawn/team logic lives in the Combatant child; attack logic lives
## in AttackHitbox. M4 supplies validated external controls through the same movement helpers.
##
## Tunables are exported so they can be adjusted in the Inspector without editing code
## (no unexplained magic numbers — see docs/TECHNICAL_ARCHITECTURE.md).

## M4: server supplies validated controls; replicas never simulate movement.
@export var external_control: bool = false

## M6 camera toggle (key V) — two third-person schemes. The melee swing always travels along the
## mesh front (+Z), so the attack follows whichever way the character faces.
##   • false (default, option A — free-look): the camera is free mouse-look and the character faces
##     its MOVEMENT direction, so the attack follows movement.
##   • true (option B — over-the-shoulder aim): the camera sits locked behind the character and the
##     MOUSE steers; the character turns to face the camera-forward (the aim), W/S move forward/back
##     and A/D slide sideways (strafe) WITHOUT turning, so the attack follows the mouse-aim. This is
##     the view a future ranged attack will aim down.
## Single-player only: the toggle key is read in _physics_process(), which networked replicas skip
## via the external_control early-return (their facing stays server-authoritative movement-facing).
@export var camera_lock_behind: bool = false
## How fast the character turns to face the aim in option B (per-second lerp rate); higher = snappier.
@export var lock_turn_speed: float = 12.0

@export_group("Movement")
@export var walk_speed: float = 1.2        # m/s
@export var run_speed: float = 3.8        # m/s while "run" is held
## Authored tactical step speed for side/back movement while aiming and holding run.
@export var aim_step_run_speed: float = 1.8
@export_range(0.0, 20.0) var aim_direction_hysteresis_degrees: float = 8.0
const MOVE_DIRECTION := preload("res://scripts/player/movement_direction.gd")
var _aim_speed_sector: int = 0
var _aim_speed_has_direction: bool = false
@export var acceleration: float = 12.0     # m/s^2 toward target speed
@export var deceleration: float = 16.0     # m/s^2 when no input (ground friction)
@export var jump_velocity: float = 8.0     # m/s upward impulse on jump
@export var turn_speed: float = 14.0       # how fast the body visually turns
@export var gravity_scale: float = 1.0     # multiplier on the project default gravity

@onready var _mesh: Node3D = $Mesh
@onready var _camera_pivot: Node3D = $CameraPivot
@onready var _health: Health = get_node_or_null("Health") as Health


func _ready() -> void:
	# Combat interface (TECHNICAL_ARCHITECTURE.md §6.1 / §7): an attackable body MUST be in
	# the "damageable" group.  The player's own AttackHitbox mask (4) still excludes the
	# player's layer (2), so this cannot cause a self-hit.
	add_to_group("damageable")


func _physics_process(delta: float) -> void:
	if external_control:
		return
	if Input.is_action_just_pressed("toggle_camera_lock"):
		camera_lock_behind = not camera_lock_behind
	_simulate_movement(delta, _camera_relative_input(), Input.is_action_pressed("run"),
		Input.is_action_just_pressed("jump"))


## Called only by the authoritative session, with bounded input (never client positions).
func simulate_network_input(delta: float, movement: Vector2, yaw: float,
		running: bool, jump_pressed: bool) -> void:
	_camera_pivot.rotation.y = yaw
	var direction := Vector3(movement.x, 0.0, movement.y).rotated(Vector3.UP, yaw)
	_simulate_movement(delta, direction, running, jump_pressed)


func _simulate_movement(delta: float, direction: Vector3, running: bool, jump_pressed: bool) -> void:
	if is_stunned():
		_apply_gravity(delta)
		velocity.x = 0; velocity.z = 0
		move_and_slide()
		return
	_apply_gravity(delta)
	_apply_horizontal_movement(direction, _movement_target_speed(direction, running), delta)
	if jump_pressed and is_on_floor():
		velocity.y = jump_velocity
	move_and_slide()
	if camera_lock_behind:
		_face_aim_direction(delta)
	else:
		_face_movement_direction(delta)

func is_stunned() -> bool:
	var status := get_node_or_null("StunStatus")
	return status != null and status.is_stunned()


func _movement_target_speed(direction: Vector3, running: bool) -> float:
	var speed := run_speed if running else walk_speed
	if not camera_lock_behind or direction.length_squared() <= 0.0001:
		_aim_speed_sector = 0
		_aim_speed_has_direction = false
		return speed
	# Match animation sectors while remaining independent of lagging visual yaw.
	var local := direction.rotated(Vector3.UP, -(_camera_pivot.rotation.y + PI))
	_aim_speed_sector = MOVE_DIRECTION.select(local, _aim_speed_sector,
		aim_direction_hysteresis_degrees, not _aim_speed_has_direction)
	_aim_speed_has_direction = true
	if running and _aim_speed_sector != 0:
		speed = minf(speed, aim_step_run_speed)
	return speed


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _project_gravity() * gravity_scale * delta


func _project_gravity() -> float:
	# Single source of truth: Project Settings > physics > 3d > default_gravity.
	return float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))


## Returns a world-space direction on the XZ plane from WASD input, relative to camera yaw.
func _camera_relative_input() -> Vector3:
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if input.length_squared() < 0.0001:
		return Vector3.ZERO

	var basis := _camera_pivot.global_transform.basis
	# Camera looks along -Z; project the axis onto the ground plane.
	var forward := Vector3(-basis.z.x, 0.0, -basis.z.z)
	var right := Vector3(basis.x.x, 0.0, basis.x.z)
	if forward.length_squared() < 0.0001:
		return Vector3.ZERO
	forward = forward.normalized()
	right = right.normalized()

	# get_vector: +x = move_right, +y = move_back (so forward = -y).
	return right * input.x + forward * (-input.y)


func _apply_horizontal_movement(move_dir: Vector3, speed: float, delta: float) -> void:
	var target := Vector3.ZERO
	if move_dir.length_squared() > 0.0001:
		target = move_dir.normalized() * speed

	var rate := (acceleration if target.length_squared() > 0.0 else deceleration) * delta
	velocity.x = move_toward(velocity.x, target.x, rate)
	velocity.z = move_toward(velocity.z, target.z, rate)


func _handle_jump() -> void:
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity


## Rotates only the visual mesh toward travel direction; the body/collision stays axis-aligned
## so the camera rig (a child) is not affected by body spin.
func _face_movement_direction(delta: float) -> void:
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	if flat.length_squared() > 0.01:
		var target_yaw := atan2(flat.x, flat.z)
		_mesh.rotation.y = lerp_angle(
			_mesh.rotation.y, target_yaw, clampf(turn_speed * delta, 0.0, 1.0)
		)


## Option B (over-the-shoulder aim): turn the mesh's front (+Z) to face the camera-forward, so the
## camera stays locked behind the character and the melee/ranged attack travels where you aim. The
## camera pivot is the mouse-driven master (camera_rig); the character follows it. Lerped so
## toggling in and fast mouse turns stay smooth instead of snapping. Because the mesh faces the
## aim — not the velocity — A/D strafe slides sideways without spinning the character (no orbit).
func _face_aim_direction(delta: float) -> void:
	var target_yaw := _camera_pivot.rotation.y + PI
	_mesh.rotation.y = lerp_angle(
		_mesh.rotation.y, target_yaw, clampf(lock_turn_speed * delta, 0.0, 1.0)
	)


# --- Combat interface (M3) — pure delegation to the Health component ------------------

## Routes damage to the Health child.  [param source] is the attacking body node (the node a
## future server identifies as the attacker) — see §6.1 / §6.9.
func apply_damage(amount: float, source: Node) -> void:
	if _health:
		_health.apply_damage(amount, source)


## Returns current health from the Health child (0.0 when the component is absent).
func get_health() -> float:
	return _health.get_health() if _health else 0.0
