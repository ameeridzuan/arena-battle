extends CharacterBody3D
## Milestone 1 — third-person player controller.
##
## Responsibilities (kept intentionally small):
##   - camera-relative movement (walk / run)
##   - gravity and jumping
##   - facing the movement direction
## Combat, health, respawn and networking are deliberately NOT here (later milestones).
##
## Tunables are exported so they can be adjusted in the Inspector without editing code
## (no unexplained magic numbers — see docs/TECHNICAL_ARCHITECTURE.md).

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


func _physics_process(delta: float) -> void:
	_apply_gravity(delta)

	var move_dir := _camera_relative_input()
	var speed := run_speed if Input.is_action_pressed("run") else walk_speed
	_apply_horizontal_movement(move_dir, speed, delta)
	_handle_jump()

	move_and_slide()
	_face_movement_direction(delta)


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
