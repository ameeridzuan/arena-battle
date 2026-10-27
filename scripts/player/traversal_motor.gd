extends RefCounted
const MOTION_PROFILE := preload("res://scripts/player/parkour_motion_profile.gd")
## Local traversal state machine. Every grab, climb segment and jump uses world collision.
enum Mode { NORMAL, HANG, CLIMB, WALL_SLIDE }
var mode := Mode.NORMAL
var ledge_point := Vector3.ZERO
var wall_normal := Vector3.ZERO
var wall_contact_point := Vector3.ZERO
var last_jump_normal := Vector3.ZERO
var climb_progress := 0.0
var climb_from_hang := true
var climb_start_feet: Array[Vector3] = []
var wall_push_left := 0.0
var regrab_delay := 0.0
var _climb_start := Vector3.ZERO
var _climb_end := Vector3.ZERO
var _climb_duration := 0.85
var shimmy_speed := 0.0
var shimmy_clock := 0.0
var shimmy_direction := 0.0
var hand_anchors: Array[Vector3] = []
var _reach_hand := -1
var _reach_start := Vector3.ZERO
var _reach_end := Vector3.ZERO
var _reach_elapsed := 0.0
var wall_jump_elapsed := 0.6
var jump_wall_normal := Vector3.ZERO
var jump_origin := Vector3.ZERO
var contact_revision := 0
var jump_foot_anchor := Vector3.ZERO
var jump_leg := 0
var hang_elapsed := 0.0
var catch_speed := 0.0
const SHIMMY_SPEED := 0.65
const HAND_REACH_TIME := 0.36
const WALL_JUMP_POSE_DURATION := 0.55
var _ledge_body: Node3D
var _ledge_transform := Transform3D.IDENTITY
var _body: CharacterBody3D
var _melee_locked := false
var _melee_was_enabled := false
var notice := "E: grab/climb | Space: wall jump / climb | C: drop"

func bind(body: CharacterBody3D) -> void:
	_body = body

func mode_name() -> String:
	return ["normal", "hang", "climb", "wall_slide"][mode]

func pose_name() -> String:
	if mode == Mode.NORMAL and wall_jump_elapsed < WALL_JUMP_POSE_DURATION:
		return "wall_jump"
	return mode_name()

func reset() -> void:
	_restore_melee()
	mode = Mode.NORMAL
	wall_push_left = 0.0
	regrab_delay = 0.25
	last_jump_normal = Vector3.ZERO
	climb_progress = 0.0
	climb_start_feet.clear()
	_ledge_body = null
	shimmy_speed = 0.0
	shimmy_direction = 0.0
	shimmy_clock = 0.0
	hand_anchors.clear()
	_reach_hand = -1
	wall_jump_elapsed = WALL_JUMP_POSE_DURATION

func _ray(start: Vector3, finish: Vector3) -> Dictionary:
	return _body.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(start, finish, 1, [_body.get_rid()]))

func _clear(from: Vector3, to: Vector3) -> bool:
	var transform := _body.global_transform
	transform.origin = from
	return not _body.test_move(transform, to - from, null, _body.safe_margin, false)

func _cancel_actions() -> void:
	var motion := _body.get_node_or_null("MotionTestControls")
	if motion != null:
		motion.cancel_motion()
	_body.get_node("CharacterAnimation").cancel_action()
	_body.stair_presentation.reset()
	var melee: Node = _body.get_node("AttackHitbox")
	if not _melee_locked:
		_melee_was_enabled = melee.is_physics_processing()
		_melee_locked = true
	melee.set_physics_process(false)

func _restore_melee() -> void:
	if _melee_locked and is_instance_valid(_body):
		var manager := _body.get_tree().get_first_node_in_group("match_manager")
		var active_match: bool = manager == null or manager.get_phase() != 2
		if _melee_was_enabled and _body.get_health() > 0.0 and active_match:
			_body.get_node("AttackHitbox").set_physics_process(true)
		_melee_locked = false

func simulate(delta: float, direction: Vector3, jump: bool, interact: bool, drop: bool) -> bool:
	if mode == Mode.NORMAL and wall_push_left <= 0.0 and wall_jump_elapsed >= WALL_JUMP_POSE_DURATION:
		_restore_melee()
	wall_jump_elapsed = minf(WALL_JUMP_POSE_DURATION, wall_jump_elapsed + delta)
	if pose_name() == "wall_jump":
		var mesh: Node3D = _body.get_node("Mesh")
		var facing_in := atan2(-jump_wall_normal.x, -jump_wall_normal.z)
		var facing_out := atan2(jump_wall_normal.x, jump_wall_normal.z)
		mesh.rotation.y = lerp_angle(facing_in, facing_out, MOTION_PROFILE.wall_turn(wall_jump_elapsed / WALL_JUMP_POSE_DURATION))
	regrab_delay = maxf(0.0, regrab_delay - delta)
	wall_push_left = maxf(0.0, wall_push_left - delta)
	if _body.get_health() <= 0.0:
		reset()
		return false
	if mode in [Mode.HANG, Mode.CLIMB] and (not is_instance_valid(_ledge_body) or not _ledge_body.global_transform.is_equal_approx(_ledge_transform)):
		reset()
		notice = "Ledge moved or disappeared"
		return false
	if drop and mode in [Mode.HANG, Mode.CLIMB]:
		mode = Mode.NORMAL
		regrab_delay = 0.45
		_body.velocity = wall_normal * 1.5 + Vector3.DOWN
		_restore_melee()
		notice = "Dropped ledge"
		return false
	if mode == Mode.HANG:
		hang_elapsed += delta
		_body.velocity = Vector3.ZERO
		if jump or interact:
			_start_climb()
		else:
			_shimmy(delta, direction)
		return true
	if mode == Mode.CLIMB:
		if climb_progress < 0.24:
			var before := _body.global_position
			_shimmy(delta, direction)
			_climb_start += _body.global_position - before
		climb_progress = minf(1.0, climb_progress + delta / _climb_duration)
		# Clear the lip with the capsule; the pose supplies the chest-over-edge weight transfer.
		var rise_weight := smoothstep(0.02, 0.76, climb_progress)
		var travel_weight := smoothstep(0.74, 1.0, climb_progress)
		var desired := _climb_start.lerp(_climb_end, travel_weight)
		desired.y = lerpf(_climb_start.y, _climb_end.y, rise_weight)
		if _body.move_and_collide(desired - _body.global_position) != null:
			mode = Mode.NORMAL
			regrab_delay = 0.4
			notice = "Climb interrupted by obstruction"
		elif climb_progress >= 1.0:
			mode = Mode.NORMAL
			_body.velocity = Vector3.DOWN * 0.1
			_body.move_and_slide()
			_body.apply_floor_snap()
			notice = "Climb complete"
		return true
	if _body.is_on_floor():
		mode = Mode.NORMAL
		last_jump_normal = Vector3.ZERO
		wall_jump_elapsed = WALL_JUMP_POSE_DURATION
		if interact and request_ledge(direction, false):
			return true
		return false
	if wall_push_left > 0.0:
		_body._apply_gravity(delta)
		_body.move_and_slide()
		return true
	if regrab_delay <= 0.0 and (interact or (_body.velocity.y <= 1.0 and direction.length_squared() > 0.01)):
		if request_ledge(direction, not interact):
			return true
	var wall := _find_wall(direction)
	if not wall.is_empty():
		wall_normal = wall.normal
		wall_contact_point = wall.position
		if jump and (last_jump_normal == Vector3.ZERO or last_jump_normal.dot(wall_normal) < 0.5):
			_cancel_actions()
			last_jump_normal = wall_normal
			jump_wall_normal = wall_normal
			jump_origin = _body.global_position
			var jump_tangent := Vector3.UP.cross(wall_normal).normalized()
			jump_leg = 0 if direction.dot(jump_tangent) <= 0.0 else 1
			jump_foot_anchor = wall.position + wall_normal * 0.012 + jump_tangent * (-0.15 if jump_leg == 0 else 0.15) - Vector3.UP * (0.36 if jump_leg == 0 else 0.48)
			wall_jump_elapsed = 0.0
			_body.get_node("Mesh").rotation.y = atan2(-wall_normal.x, -wall_normal.z)
			_body.velocity = wall_normal * 5.2 + Vector3.UP * 7.5
			wall_push_left = 0.18
			regrab_delay = 0.25
			mode = Mode.NORMAL
			_body.move_and_slide()
			notice = "Wall jump"
			return true
		if direction.dot(-wall_normal) > 0.2 and _body.velocity.y < 0.0:
			if mode != Mode.WALL_SLIDE:
				_cancel_actions()
			mode = Mode.WALL_SLIDE
			var mesh: Node3D = _body.get_node("Mesh")
			mesh.rotation.y = lerp_angle(mesh.rotation.y, atan2(-wall_normal.x, -wall_normal.z), 1.0 - exp(-15.0 * delta))
			_body._apply_gravity(delta)
			_body.velocity.y = maxf(_body.velocity.y, -2.0)
			_body.velocity.x = -wall_normal.x * 0.3
			_body.velocity.z = -wall_normal.z * 0.3
			_body.move_and_slide()
			notice = "Wall slide — Space to jump away"
			return true
	mode = Mode.NORMAL
	return false

func _find_wall(direction: Vector3) -> Dictionary:
	var directions := [direction, Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]
	for toward in directions:
		if toward.length_squared() < 0.01:
			continue
		var hit := _ray(_body.global_position, _body.global_position + toward.normalized() * 0.68)
		if not hit.is_empty() and absf(hit.normal.y) < 0.15 and hit.collider is StaticBody3D:
			return hit
	return {}

func request_ledge(direction: Vector3, automatic: bool = false) -> bool:
	if regrab_delay > 0.0 or mode in [Mode.HANG, Mode.CLIMB]:
		return false
	if direction.length_squared() < 0.01:
		direction = _body.get_node("Mesh").global_basis.z
	direction.y = 0.0
	direction = direction.normalized()
	var feet := _body.global_position.y - 1.0
	var wall: Dictionary = {}
	for height in [1.45, 0.45]:
		var start := Vector3(_body.global_position.x, feet + height, _body.global_position.z)
		wall = _ray(start, start + direction * 0.9)
		if not wall.is_empty() and absf(wall.normal.y) < 0.15 and wall.collider is StaticBody3D:
			break
		wall = {}
	if wall.is_empty() or direction.dot(-wall.normal) < 0.5:
		return false
	var inward: Vector3 = wall.position - wall.normal * 0.2
	var top := _ray(Vector3(inward.x, feet + 2.15, inward.z), Vector3(inward.x, feet + 0.4, inward.z))
	if top.is_empty() or top.collider != wall.collider or top.normal.dot(Vector3.UP) < cos(_body.floor_max_angle):
		return false
	var top_point: Vector3 = top.position
	var stand: Vector3 = top_point - wall.normal * 0.55 + Vector3.UP * 1.025
	var support := _ray(stand, stand - Vector3.UP * 1.15)
	if support.is_empty() or absf(support.position.y - top_point.y) > 0.03 or support.normal.dot(Vector3.UP) < cos(_body.floor_max_angle):
		return false
	var raised := Vector3(_body.global_position.x, stand.y, _body.global_position.z)
	if not _clear(_body.global_position, raised) or not _clear(raised, stand):
		return false
	var hang: Vector3 = wall.position + wall.normal * 0.56
	hang.y = top_point.y - 0.60
	if automatic and not _clear(_body.global_position, hang):
		return false
	_ledge_body = top.collider
	_ledge_transform = _ledge_body.global_transform
	wall_normal = wall.normal
	ledge_point = Vector3(wall.position.x, top_point.y, wall.position.z)
	_climb_end = stand
	wall_jump_elapsed = WALL_JUMP_POSE_DURATION
	_initialize_hands()
	var grip_tangent := Vector3.UP.cross(wall_normal).normalized()
	if _sample_lip(ledge_point - grip_tangent * 0.40).is_empty() or _sample_lip(ledge_point + grip_tangent * 0.40).is_empty():
		notice = "Need support for both hands at this ledge position"
		return false
	catch_speed = _body.velocity.length()
	hang_elapsed = 0.0
	_cancel_actions()
	_body.velocity = Vector3.ZERO
	_body.get_node("Mesh").rotation.y = atan2(-wall_normal.x, -wall_normal.z)
	if not automatic and top_point.y - feet < 1.25:
		return _start_climb()
	if not _clear(_body.global_position, hang):
		return false
	var previous_y := _body.global_position.y
	_body.global_position = hang
	_body.stair_presentation.on_step(hang.y - previous_y)
	mode = Mode.HANG
	notice = "Hanging — A/D sideways, E/Space climb, C drop"
	return true

func _start_climb() -> bool:
	var destination := ledge_point - wall_normal * 0.48 + Vector3.UP * 1.025 if mode == Mode.HANG else _climb_end
	var support := _ray(destination, destination - Vector3.UP * 1.15)
	if support.is_empty() or absf(support.position.y - ledge_point.y) > 0.03 or support.normal.dot(Vector3.UP) < cos(_body.floor_max_angle):
		notice = "No standing support above this ledge position"
		return false
	var raised := Vector3(_body.global_position.x, destination.y, _body.global_position.z)
	if not _clear(_body.global_position, raised) or not _clear(raised, destination):
		notice = "Climb blocked — need clear headroom"
		return false
	climb_from_hang = mode == Mode.HANG
	_climb_end = destination
	climb_start_feet.clear()
	var skeleton: Skeleton3D = _body.stair_presentation._skeleton
	for side in ["L", "R"]:
		var foot := skeleton.find_bone("foot." + side) if is_instance_valid(skeleton) else -1
		climb_start_feet.append(skeleton.to_global(skeleton.get_bone_global_pose(foot).origin) if foot >= 0 else _body.global_position - Vector3.UP * 0.87)
	_climb_start = _body.global_position
	_climb_duration = 2.15 if climb_from_hang else clampf(0.72 + (_climb_end.y - _climb_start.y) * 0.30, 0.85, 1.30)
	climb_progress = 0.0
	shimmy_speed = 0.0
	_reach_hand = -1
	mode = Mode.CLIMB
	notice = "Climbing"
	return true

func _initialize_hands() -> void:
	contact_revision += 1
	var tangent := Vector3.UP.cross(wall_normal).normalized()
	hand_anchors = [ledge_point - tangent * 0.29 + wall_normal * 0.16 + Vector3.UP * 0.10, ledge_point + tangent * 0.29 + wall_normal * 0.16 + Vector3.UP * 0.10]
	shimmy_speed = 0.0
	shimmy_direction = 0.0
	_reach_hand = -1

func _sample_lip(point: Vector3) -> Dictionary:
	var wall_start := point + wall_normal * 0.75 - Vector3.UP * 0.25
	var face := _ray(wall_start, wall_start - wall_normal * 1.05)
	if face.is_empty() or face.collider != _ledge_body or face.normal.dot(wall_normal) < 0.98:
		return {}
	var inset: Vector3 = face.position - wall_normal * 0.12
	var top := _ray(Vector3(inset.x, ledge_point.y + 0.12, inset.z), Vector3(inset.x, ledge_point.y - 0.12, inset.z))
	if top.is_empty() or top.collider != _ledge_body or absf(top.position.y - ledge_point.y) > 0.06 or top.normal.dot(Vector3.UP) < cos(_body.floor_max_angle):
		return {}
	return {"position": Vector3(face.position.x, top.position.y, face.position.z)}

func _shimmy(delta: float, direction: Vector3) -> void:
	var tangent := Vector3.UP.cross(wall_normal).normalized()
	var input := clampf(direction.dot(tangent), -1.0, 1.0)
	if absf(input) < 0.15:
		input = 0.0
	shimmy_speed = move_toward(shimmy_speed, input * SHIMMY_SPEED, delta * 3.5)
	var travel := tangent * shimmy_speed * delta
	if travel.length_squared() > 0.000001:
		var candidate := ledge_point + travel
		var left := _sample_lip(candidate - tangent * 0.40)
		var right := _sample_lip(candidate + tangent * 0.40)
		var center := _sample_lip(candidate)
		if left.is_empty() or right.is_empty() or center.is_empty() or not _clear(_body.global_position, _body.global_position + travel):
			shimmy_speed = 0.0
			notice = "Ledge edge / obstruction — movement stopped"
		else:
			var next_point: Vector3 = center.position
			var offset := next_point - ledge_point
			_body.global_position += offset
			ledge_point = next_point
			_climb_end += offset
			shimmy_clock += absf(shimmy_speed) * delta
			shimmy_direction = signf(shimmy_speed)
			notice = "Shimmy — E/Space climb here, C drop"
	_update_hands(delta, tangent)

func _update_hands(delta: float, tangent: Vector3) -> void:
	if hand_anchors.size() != 2:
		_initialize_hands()
	if _reach_hand < 0:
		var worst_error := 0.06
		for hand in 2:
			var side := -1.0 if hand == 0 else 1.0
			var extra := shimmy_direction * 0.11 if absf(shimmy_speed) > 0.05 else 0.0
			var desired := ledge_point + tangent * (side * 0.29 + extra) + wall_normal * 0.16 + Vector3.UP * 0.10
			if _sample_lip(desired).is_empty():
				desired -= tangent * extra
				if _sample_lip(desired).is_empty():
					continue
			var error := hand_anchors[hand].distance_to(desired)
			if error > worst_error:
				worst_error = error
				_reach_hand = hand
				_reach_end = desired
		if _reach_hand >= 0:
			_reach_start = hand_anchors[_reach_hand]
			_reach_elapsed = 0.0
	if _reach_hand >= 0:
		_reach_elapsed = minf(HAND_REACH_TIME, _reach_elapsed + delta)
		var phase := _reach_elapsed / HAND_REACH_TIME
		hand_anchors[_reach_hand] = _reach_start.lerp(_reach_end, smoothstep(0.0, 1.0, phase)) + Vector3.UP * sin(phase * PI) * 0.07
		if phase >= 1.0:
			_reach_hand = -1
