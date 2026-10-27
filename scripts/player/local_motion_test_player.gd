extends "res://scripts/player/player_controller.gd"
## Shared movement for local play, the motion course and authoritative match simulation.
const STAIR_MOTOR := preload("res://scripts/player/stair_motor.gd")
const TRAVERSAL := preload("res://scripts/player/traversal_motor.gd")
const STAIR_POSE := preload("res://scripts/player/stair_presentation.gd")
@export_range(0.0, 0.5, 0.01) var max_step_height := 0.4
@export var stair_stepping_enabled := true
@export var traversal_enabled := true
var network_presentation_only := false
var replicated_grounded := false
var network_interact := false
var network_drop := false
var step_revision := 0
var network_step_height := 0.0
var traversal_motor := TRAVERSAL.new()
var stair_motor := STAIR_MOTOR.new()
var stair_presentation: Node

func _ready() -> void:
	super._ready()
	traversal_motor.bind(self)
	for binding in [["traversal_interact", KEY_E], ["traversal_drop", KEY_C]]:
		if not InputMap.has_action(binding[0]):
			InputMap.add_action(binding[0])
			var key := InputEventKey.new()
			key.physical_keycode = binding[1]
			InputMap.action_add_event(binding[0], key)
	floor_snap_length = 0.12
	floor_constant_speed = true
	stair_presentation = Node.new()
	stair_presentation.set_script(STAIR_POSE)
	stair_presentation.name = "StairPresentation"
	add_child(stair_presentation)
	get_node("Health").died.connect(reset_traversal)
	get_node("Health").reset_performed.connect(reset_traversal)
	var manager := get_tree().get_first_node_in_group("match_manager")
	if manager != null:
		manager.match_ended.connect(func(_winner: int): reset_traversal())

func _simulate_movement(delta: float, direction: Vector3, running: bool, jump_pressed: bool) -> void:
	if is_stunned():
		_apply_gravity(delta)
		velocity.x = 0; velocity.z = 0
		move_and_slide()
		return
	var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if traversal_enabled and traversal_motor.simulate(delta, direction, jump_pressed, network_interact or (not external_control and captured and Input.is_action_just_pressed("traversal_interact")), network_drop or (not external_control and captured and Input.is_action_just_pressed("traversal_drop"))):
		return
	var motion := get_node_or_null("MotionTestControls")
	if motion != null and motion.simulate_dodge(delta):
		return
	_apply_gravity(delta)
	_apply_horizontal_movement(direction, _movement_target_speed(direction, running), delta)
	var jumping := jump_pressed and stair_motor.is_supported(self)
	if jumping:
		stair_motor.support_left = 0.0
		velocity.y = jump_velocity
	move_with_stairs(delta, not jumping)
	if traversal_motor.pose_name() == "wall_jump":
		return
	if camera_lock_behind:
		_face_aim_direction(delta)
	else:
		_face_movement_direction(delta)

## Optional melee-contact interface, invoked only after hit range/arc validation.
func receive_melee_hit(amount: float, source: Node) -> void:
	if not is_finite(amount) or amount <= 0.0:
		return
	var motion := get_node_or_null("MotionTestControls")
	if motion != null and motion.try_parry_melee(source):
		return
	super.apply_damage(amount, source)

func get_traversal_mode() -> String:
	return traversal_motor.mode_name()

func allows_motion_actions() -> bool:
	return not is_stunned() and traversal_motor.pose_name() == "normal" and traversal_motor.wall_push_left <= 0.0

func reset_traversal() -> void:
	traversal_motor.reset()
	stair_motor.support_left = 0.0
	stair_presentation.reset()

func is_motion_grounded() -> bool:
	return (replicated_grounded if network_presentation_only else stair_motor.is_supported(self)) and get_traversal_mode() == "normal"

func move_with_stairs(delta: float, allow_steps: bool = true) -> void:
	var height := stair_motor.move(self, delta, max_step_height, stair_stepping_enabled and allow_steps)
	if absf(height) > 0.005 and is_instance_valid(stair_presentation):
		step_revision += 1
		network_step_height = height
		stair_presentation.on_step(height)
