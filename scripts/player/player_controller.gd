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

## M6 facing toggle (option B). When false (default, option C) the mesh faces the movement
## direction and snaps to the aim only at the moment of a swing. When true the mesh always
## faces the camera-aim direction. Single-player only: the toggle key is read in
## _physics_process(), which networked replicas skip via the external_control early-return.
@export var face_aim_always: bool = false

@export_group("Movement")
@export var walk_speed: float = 6.0        # m/s
@export var run_speed: float = 10.0        # m/s while "run" is held
@export var acceleration: float = 12.0     # m/s^2 toward target speed
@export var deceleration: float = 16.0     # m/s^2 when no input (ground friction)
@export var jump_velocity: float = 8.0     # m/s upward impulse on jump
@export var turn_speed: float = 14.0       # how fast the body visually turns
@export var gravity_scale: float = 1.0     # multiplier on the project default gravity

@onready var _mesh: Node3D = $Mesh
@onready var _camera_pivot: Node3D = $CameraPivot
@onready var _health: Health = get_node_or_null("Health") as Health
@onready var _attack: Node = get_node_or_null("AttackHitbox")


func _ready() -> void:
	# Combat interface (TECHNICAL_ARCHITECTURE.md §6.1 / §7): an attackable body MUST be in
	# the "damageable" group.  The player's own AttackHitbox mask (4) still excludes the
	# player's layer (2), so this cannot cause a self-hit.
	add_to_group("damageable")
	# M6 (attack-facing): snap the visual mesh to the aim direction at the moment of a swing so
	# the attack always comes out of the character's front. Presentation only — combat still
	# resolves along the camera-aim forward the hitbox emits; movement-facing resumes afterwards.
	if _attack != null and _attack.has_signal("attack_started"):
		_attack.attack_started.connect(_on_attack_started)


func _physics_process(delta: float) -> void:
	if external_control:
		return
	if Input.is_action_just_pressed("toggle_face_aim"):
		face_aim_always = not face_aim_always
	_simulate_movement(delta, _camera_relative_input(), Input.is_action_pressed("run"),
		Input.is_action_just_pressed("jump"))


## Called only by the authoritative session, with bounded input (never client positions).
func simulate_network_input(delta: float, movement: Vector2, yaw: float,
		running: bool, jump_pressed: bool) -> void:
	_camera_pivot.rotation.y = yaw
	var direction := Vector3(movement.x, 0.0, movement.y).rotated(Vector3.UP, yaw)
	_simulate_movement(delta, direction, running, jump_pressed)


func _simulate_movement(delta: float, direction: Vector3, running: bool, jump_pressed: bool) -> void:
	_apply_gravity(delta)
	_apply_horizontal_movement(direction, run_speed if running else walk_speed, delta)
	if jump_pressed and is_on_floor():
		velocity.y = jump_velocity
	move_and_slide()
	_update_facing(delta)


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


## Chooses the visual-facing rule: option B (always face the camera-aim) or option C (face the
## movement direction; _on_attack_started snaps to aim at each swing).
func _update_facing(delta: float) -> void:
	if face_aim_always:
		_face_aim_direction()
	else:
		_face_movement_direction(delta)


## Option B: the mesh's local +Z (its front) tracks the camera-forward. The camera pivot's yaw
## maps to the same world direction _on_attack_started snaps to (atan2 of the aim forward), so
## facing and attack direction are always identical while this mode is on.
func _face_aim_direction() -> void:
	_mesh.rotation.y = _camera_pivot.rotation.y + PI


## M6 (attack-facing): turn the visual mesh to the swing's aim direction instantly, so the
## model faces where it attacks. [param forward] is the XZ aim direction emitted by the
## AttackHitbox (camera-forward); the mesh's local +Z is its front, matching _face_movement_direction.
func _on_attack_started(forward: Vector3) -> void:
	if _mesh != null and forward.length_squared() > 0.0001:
		_mesh.rotation.y = atan2(forward.x, forward.z)


# --- Combat interface (M3) — pure delegation to the Health component ------------------

## Routes damage to the Health child.  [param source] is the attacking body node (the node a
## future server identifies as the attacker) — see §6.1 / §6.9.
func apply_damage(amount: float, source: Node) -> void:
	if _health:
		_health.apply_damage(amount, source)


## Returns current health from the Health child (0.0 when the component is absent).
func get_health() -> float:
	return _health.get_health() if _health else 0.0
