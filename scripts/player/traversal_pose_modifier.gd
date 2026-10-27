extends SkeletonModifier3D
## Contact-driven hang, pull, palm support, stepping and airborne recovery.
const GEOMETRY := preload("res://scripts/player/traversal_geometry.gd")
const PROFILE := preload("res://scripts/player/parkour_motion_profile.gd")
const SOLVER := preload("res://scripts/player/terrain_foot_modifier.gd")
var body: CharacterBody3D
var solver := SOLVER.new()
var geometry := GEOMETRY.new()
var torso: Array = []
var clearance_correction := 0.0
var clearance_source := ""
var arms: Array = []
var legs: Array = []
var _last_state := "hang"
var _last_normal := Vector3.FORWARD
var _last_ledge := Vector3.ZERO
var _last_progress := 0.0
var _hands: Array[Vector3] = []
var contact_markers: Dictionary = {}
var contact_targets: Dictionary = {}
var phase_name := ""
var _foot_anchors: Array[Vector3] = []
var _foot_reach := -1
var _foot_reach_from := Vector3.ZERO
var _foot_reach_to := Vector3.ZERO
var _foot_reach_time := 0.0
var _contact_revision := -1
var _rebrace_started := false
var _rebrace_from := Vector3.ZERO
var _contact_lip := Vector3(INF, INF, INF)

func configure(target: CharacterBody3D, skeleton: Skeleton3D) -> void:
	body = target
	geometry.build(skeleton)
	for name in ["hips", "spine", "chest", "neck", "head"]:
		torso.append(skeleton.find_bone(name))
	for side in ["L", "R"]:
		arms.append([skeleton.find_bone("upper_arm." + side), skeleton.find_bone("forearm." + side), skeleton.find_bone("hand." + side)])
		legs.append([skeleton.find_bone("thigh." + side), skeleton.find_bone("shin." + side), skeleton.find_bone("foot." + side)])

	_calibrate_contacts(skeleton)

func _legacy_modification() -> void:
	if not is_instance_valid(body) or influence <= 0.001:
		return
	var motor: RefCounted = body.traversal_motor
	var state: String = motor.pose_name()
	if state != "normal":
		_last_state = state
		_last_normal = motor.jump_wall_normal if state == "wall_jump" else motor.wall_normal
		_last_ledge = motor.ledge_point
		_last_progress = motor.wall_jump_elapsed / motor.WALL_JUMP_POSE_DURATION if state == "wall_jump" else motor.climb_progress
		_hands.assign(motor.hand_anchors)
	else:
		state = _last_state
	var skeleton := get_skeleton()
	var normal := _last_normal
	# Facing -normal makes world-left = -UP.cross(normal), matching the +X=L rigs.
	var tangent := Vector3.UP.cross(normal).normalized()
	if state == "wall_slide":
		_wall_slide(skeleton, normal, tangent)
		return
	if state == "wall_jump":
		_wall_jump(skeleton, normal, tangent)
		return
	var pull := 0.0
	var transfer_clearance := 0.0
	if state == "climb":
		# Anticipate armor clearance with a continuous arc instead of reactive hip pops.
		transfer_clearance = 0.25 * smoothstep(0.12, 0.28, _last_progress) * (1.0 - smoothstep(0.65, 0.90, _last_progress))
		pull = smoothstep(0.0, 0.30, _last_progress) * (1.0 - smoothstep(0.70, 1.0, _last_progress))
		var crouch := 0.30 * pull + 0.35 * smoothstep(0.30, 0.55, _last_progress) * (1.0 - smoothstep(0.70, 1.0, _last_progress))
		var transfer_offset := normal * (transfer_clearance - 0.16 * pull) - Vector3.UP * crouch
		_pose_body(skeleton, transfer_offset, tangent, deg_to_rad(-15.0) * pull, deg_to_rad(-20.0) * pull)
	elif state == "hang":
		var sway: float = sin(motor.shimmy_clock * 13.0) * minf(absf(motor.shimmy_speed) / 0.65, 1.0)
		_pose_body(skeleton, tangent * sway * 0.025, tangent, deg_to_rad(-4.0), 0.0)
	else:
		_pose_body(skeleton, Vector3.ZERO, tangent, deg_to_rad(-8.0), deg_to_rad(5.0))
	clearance_correction = geometry.penetration(torso, _last_ledge, normal) if state in ["hang", "climb"] else 0.0
	if clearance_correction > 0.0:
		_shift_hips(skeleton, normal * clearance_correction)
	var contacts: Array = []
	for index in 2:
		var side := -1.0 if index == 0 else 1.0
		var hand: Vector3
		var foot: Vector3
		var leg_lift := 0.0
		var leg_advance := 0.0
		var arm_weight := 1.0
		var leg_weight := 1.0
		if state == "wall_slide":
			hand = body.global_position - normal * 0.47 + tangent * side * 0.28 + Vector3.UP * (0.32 if index == 0 else 0.20)
			foot = body.global_position - normal * 0.28 + tangent * side * 0.16 - Vector3.UP * (0.57 if index == 0 else 0.72)
		else:
			hand = _hands[index] if _hands.size() == 2 else _last_ledge + normal * 0.16 + tangent * side * 0.29 + Vector3.UP * 0.10
			foot = _last_ledge + normal * 0.29 + tangent * side * 0.15 - Vector3.UP * (1.28 if index == 0 else 1.34)
			if state == "climb":
				if not motor.climb_from_hang and motor.climb_start_feet.size() == 2:
					foot = motor.climb_start_feet[index]
				var start_foot := foot
				leg_lift = smoothstep(0.12 if index == 0 else 0.48, 0.34 if index == 0 else 0.70, _last_progress)
				leg_advance = smoothstep(0.32 if index == 0 else 0.68, 0.52 if index == 0 else 0.86, _last_progress)
				# Plant near the lip within leg reach, then step deeper as hips cross.
				var plant_depth := lerpf(0.08, 0.35, smoothstep(0.72, 0.92, _last_progress)) if index == 0 else lerpf(0.10, 0.24, smoothstep(0.80, 0.96, _last_progress))
				var planted := _last_ledge - normal * plant_depth + tangent * side * 0.17 + Vector3.UP * 0.14
				foot = start_foot.lerp(planted, leg_advance)
				foot.y = lerpf(start_foot.y, _last_ledge.y + 0.28, leg_lift) - 0.14 * smoothstep(0.46 if index == 0 else 0.80, 0.56 if index == 0 else 0.90, _last_progress)
				# Release the leading hand only after knee support; retain the other through transfer.
				arm_weight = 1.0 - smoothstep(0.56 if index == 0 else 0.72, 0.72 if index == 0 else 0.88, _last_progress)
				leg_weight = 1.0 - smoothstep(0.86, 1.0, _last_progress)
		var elbow_pole := normal * 0.35 + tangent * side * 0.45 - Vector3.UP * 0.25
		var knee_pole := normal * (0.7 - leg_lift * 0.7 - leg_advance * 0.2) + Vector3.UP * leg_lift * 0.8
		var foot_pitch := deg_to_rad(25.0) * (1.0 - leg_lift) if state == "hang" or motor.climb_from_hang else 0.0
		contacts.append({"hand": hand, "foot": foot, "arm_weight": arm_weight, "leg_weight": leg_weight, "elbow_pole": elbow_pole, "knee_pole": knee_pole, "foot_pitch": foot_pitch})
		_adjust(skeleton, arms[index], hand, arm_weight, elbow_pole)
		_orient_contact(skeleton, arms[index][2], tangent, PI / 2.0, arm_weight)
		_adjust(skeleton, legs[index], foot, leg_weight, knee_pole)
		_orient_contact(skeleton, legs[index][2], tangent, foot_pitch, 1.0)

	if state in ["hang", "climb"]:
		var protected_bones := torso.duplicate()
		for chain in arms:
			protected_bones.append(chain[0])
			protected_bones.append(chain[1])
		for chain in legs:
			protected_bones.append(chain[0])
		# A safe capsule does not guarantee safe skinned armor. Preserve the grips while
		# projecting the torso outward until the solved arm envelopes clear the edge.
		for iteration in 6:
			var depth := geometry.penetration(protected_bones, _last_ledge, normal)
			if depth < 0.001:
				break
			_shift_hips(skeleton, normal * depth)
			clearance_correction += depth
			for index in 2:
				var contact: Dictionary = contacts[index]
				_adjust(skeleton, arms[index], contact.hand, contact.arm_weight, contact.elbow_pole)
				_orient_contact(skeleton, arms[index][2], tangent, PI / 2.0, contact.arm_weight)
				_adjust(skeleton, legs[index], contact.foot, contact.leg_weight, contact.knee_pole)
				_orient_contact(skeleton, legs[index][2], tangent, contact.foot_pitch, 1.0)

func _wall_slide(skeleton: Skeleton3D, normal: Vector3, tangent: Vector3) -> void:
	# Sliding contacts move down the wall with the body; they are braces, not ledge grips.
	phase_name = "wall_slide_brace"
	var motor: RefCounted = body.traversal_motor
	var wall_point: Vector3 = motor.wall_contact_point
	wall_point.y = body.global_position.y
	var left := -tangent
	_pose_body(skeleton, Vector3.ZERO, tangent, deg_to_rad(-6.0), 0.0)
	var plans: Array = []
	for index in 2:
		var side := 1.0 if index == 0 else -1.0
		var suffix := ".L" if index == 0 else ".R"
		var hand_anchor := wall_point + normal * 0.035 + left * side * 0.29 + Vector3.UP * (0.30 if index == 0 else 0.18)
		var foot_anchor := wall_point + normal * 0.012 + left * side * 0.15 - Vector3.UP * (0.36 if index == 0 else 0.48)
		var hand_frame := _contact_frame(skeleton, arms[index][2], tangent, PI)
		var foot_frame := _contact_frame(skeleton, legs[index][2], tangent, deg_to_rad(75.0))
		var elbow := normal * 0.25 + left * side * 0.45 - Vector3.UP * 0.15
		var knee := -normal * 0.95 + left * side * 0.22
		plans.append({"hand": hand_anchor, "foot": foot_anchor, "hand_frame": hand_frame, "foot_frame": foot_frame, "elbow": elbow, "knee": knee, "suffix": suffix})
	# Re-solve contacts after any armor correction, keeping the torso outside the wall.
	clearance_correction = 0.0
	var protected := torso.duplicate()
	for chain in arms:
		protected.append_array([chain[0], chain[1]])
	for chain in legs:
		protected.append(chain[0])
	for iteration in 7:
		for index in 2:
			var plan: Dictionary = plans[index]
			_solve_contact(skeleton, arms[index], contact_markers["palm" + plan.suffix].local, plan.hand, plan.hand_frame, 1.0, plan.elbow)
			_solve_contact(skeleton, legs[index], contact_markers["forefoot" + plan.suffix].local, plan.foot, plan.foot_frame, 1.0, plan.knee)
		var depth := geometry.penetration(protected, wall_point + Vector3.UP * 10.0, normal)
		if depth < 0.001 or iteration == 6:
			break
		_shift_hips(skeleton, normal * depth)
		clearance_correction += depth
	for plan in plans:
		contact_targets["palm" + plan.suffix] = {"anchor": plan.hand, "weight": 1.0, "mode": "slide"}
		contact_targets["forefoot" + plan.suffix] = {"anchor": plan.foot, "weight": 1.0, "mode": "slide"}

func _wall_jump(skeleton: Skeleton3D, normal: Vector3, tangent: Vector3) -> void:
	var phase := _last_progress
	var compress := 1.0 - smoothstep(0.0, 0.20, phase)
	var extend := smoothstep(0.06, 0.40, phase)
	var weight := 1.0 - smoothstep(0.60, 1.0, phase)
	var motor: RefCounted = body.traversal_motor
	var release := smoothstep(0.04, 0.16, phase)
	phase_name = "wall_load" if phase < 0.12 else ("wall_extend" if phase < 0.40 else "wall_flight")
	var anatomical_left: Vector3 = body.get_node("Mesh").global_basis.x
	var facing: Vector3 = body.get_node("Mesh").global_basis.z
	var lift := (0.07 * smoothstep(0.02, 0.20, phase) - 0.02 * compress) * (1.0 - smoothstep(0.55, 1.0, phase))
	_pose_body(skeleton, Vector3.UP * lift, -anatomical_left, deg_to_rad(-6.0) * compress, 0.0)
	var hips := skeleton.get_bone_global_pose(torso[0])
	var flow := sin(phase * PI) * weight
	var twist := Basis(Vector3.UP, deg_to_rad(8.0) * flow) * Basis(facing, deg_to_rad(4.0) * flow * (-1.0 if motor.jump_leg == 0 else 1.0))
	hips.basis = skeleton.global_basis.inverse() * twist * skeleton.global_basis * hips.basis
	skeleton.set_bone_global_pose(torso[0], hips)
	for index in 2:
		var side := 1.0 if index == 0 else -1.0
		var driving: bool = index == motor.jump_leg
		var arm_flow := sin(PI * smoothstep(0.25, 0.88, phase))
		var hand_height := lerpf(0.28, 0.08 if driving else 0.38, extend) + (0.06 if driving else -0.04) * arm_flow
		var hand := body.global_position + anatomical_left * side * lerpf(0.25, 0.40, extend) - normal * lerpf(0.32, -0.05, extend) + Vector3.UP * hand_height
		var foot_height := lerpf(0.48 if driving else 0.68, 0.78 if driving else 0.60, extend)
		var foot := body.global_position + anatomical_left * side * 0.15 - normal * lerpf(0.30, -0.12, extend) - Vector3.UP * foot_height
		_adjust(skeleton, arms[index], hand, weight, -facing * 0.3 + anatomical_left * side * 0.5)
		_adjust(skeleton, legs[index], foot, weight, facing * 0.8 + Vector3.UP * 0.05 + anatomical_left * side * 0.18)
		_orient_contact(skeleton, legs[index][2], -anatomical_left, deg_to_rad(-10.0) * (1.0 - extend), weight)
		if driving and release < 0.999:
			var key := "forefoot.L" if index == 0 else "forefoot.R"
			var frame := _contact_frame(skeleton, legs[index][2], tangent, deg_to_rad(75.0))
			_solve_contact(skeleton, legs[index], contact_markers[key].local, motor.jump_foot_anchor, frame, 1.0 - release, facing + Vector3.UP)
			contact_targets[key] = {"anchor": motor.jump_foot_anchor, "weight": 1.0 - release, "mode": "wall"}

func _pose_body(skeleton: Skeleton3D, offset: Vector3, axis: Vector3, hips_pitch: float, chest_pitch: float) -> void:
	var local_axis := (skeleton.global_basis.inverse() * axis).normalized()
	var hips_index := skeleton.find_bone("hips")
	if hips_index >= 0:
		var hips := skeleton.get_bone_global_pose(hips_index)
		hips.origin += skeleton.global_basis.inverse() * offset
		hips.basis = Basis(local_axis, hips_pitch) * hips.basis
		skeleton.set_bone_global_pose(hips_index, hips)
	var chest_index := skeleton.find_bone("chest")
	if chest_index >= 0:
		var chest := skeleton.get_bone_global_pose(chest_index)
		chest.basis = Basis(local_axis, chest_pitch) * chest.basis
		skeleton.set_bone_global_pose(chest_index, chest)

func _adjust(skeleton: Skeleton3D, chain: Array, target_world: Vector3, blend: float, pole_world: Vector3) -> void:
	if chain.has(-1) or blend <= 0.001:
		return
	var top := skeleton.get_bone_global_pose(chain[0])
	var middle := skeleton.get_bone_global_pose(chain[1])
	var end := skeleton.get_bone_global_pose(chain[2])
	var target := end.origin.lerp(skeleton.to_local(target_world), blend)
	if String(skeleton.get_bone_name(chain[2])).begins_with("foot.") and _last_state == "climb":
		var world_target := skeleton.to_global(target)
		var limit := -INF
		if not body.traversal_motor.climb_from_hang:
			limit = body.traversal_motor._climb_start.y - 0.87
		if (world_target - _last_ledge).dot(_last_normal) < 0.24 and _last_progress > 0.3:
			limit = maxf(limit, _last_ledge.y + 0.14)
		world_target.y = maxf(world_target.y, limit)
		target = skeleton.to_local(world_target)
	var pole := skeleton.global_basis.inverse() * pole_world
	solver._solve(skeleton, chain, top, middle, end, target, Vector3.UP, pole, false, deg_to_rad(150.0) if String(skeleton.get_bone_name(chain[2])).begins_with("foot.") else PI, String(skeleton.get_bone_name(chain[2])).begins_with("foot."))

func _exit_tree() -> void:
	solver.free()

func _shift_hips(skeleton: Skeleton3D, world_offset: Vector3) -> void:
	var index := skeleton.find_bone("hips")
	var hips := skeleton.get_bone_global_pose(index)
	hips.origin += skeleton.global_basis.inverse() * world_offset
	skeleton.set_bone_global_pose(index, hips)

func _orient_contact(skeleton: Skeleton3D, bone: int, axis: Vector3, pitch: float, weight: float) -> void:
	if bone < 0 or weight <= 0.001:
		return
	var pose := skeleton.get_bone_global_pose(bone)
	var rest_world := skeleton.global_basis * skeleton.get_bone_global_rest(bone).basis
	var desired := skeleton.global_basis.inverse() * Basis(axis, pitch) * rest_world
	pose.basis = pose.basis.orthonormalized().slerp(desired.orthonormalized(), weight)
	skeleton.set_bone_global_pose(bone, pose)

func _calibrate_contacts(skeleton: Skeleton3D) -> void:
	for side in ["L", "R"]:
		var hand := skeleton.find_bone("hand." + side)
		var foot := skeleton.find_bone("foot." + side)
		var hand_box: AABB = geometry.bounds[hand]
		var foot_box: AABB = geometry.bounds[foot]
		var wrist := skeleton.get_bone_global_rest(hand).origin
		var finger := Vector3(wrist.x, hand_box.position.y + 0.012, -0.02)
		var palm := Vector3(wrist.x, wrist.y - 0.09, hand_box.position.z + 0.008)
		var ankle := skeleton.get_bone_global_rest(foot).origin
		# The wall contact must protect the outer boot, not an interior ankle proxy.
		var forefoot := Vector3(ankle.x, foot_box.position.y, foot_box.end.z)
		var sole := Vector3(ankle.x, foot_box.position.y, 0.07)
		for entry in [["finger", hand, finger], ["palm", hand, palm], ["forefoot", foot, forefoot], ["sole", foot, sole]]:
			contact_markers[entry[0] + "." + side] = {"bone": entry[1], "local": skeleton.get_bone_global_rest(entry[1]).affine_inverse() * entry[2]}

func contact_point(side: int, mode: String) -> Vector3:
	var key := mode + (".L" if side == 0 else ".R")
	var marker: Dictionary = contact_markers[key]
	var skeleton := get_skeleton()
	return skeleton.global_transform * skeleton.get_bone_global_pose(marker.bone) * marker.local

func _process_modification() -> void:
	if not is_instance_valid(body) or influence <= 0.001:
		return
	var motor: RefCounted = body.traversal_motor
	var state: String = motor.pose_name()
	contact_targets.clear()
	if state == "normal" and _last_state == "climb" and motor.climb_from_hang:
		if motor.climb_progress >= 1.0:
			_last_progress = 1.0
		_parkour_contacts("climb")
	elif state == "hang" or (state == "climb" and motor.climb_from_hang):
		_last_state = state
		_last_normal = motor.wall_normal
		_last_ledge = motor.ledge_point
		_last_progress = motor.climb_progress
		_hands.assign(motor.hand_anchors)
		_parkour_contacts(state)
	else:
		phase_name = "low_mantle" if state == "climb" else state
		_legacy_modification()

func _parkour_contacts(state: String) -> void:
	var skeleton := get_skeleton()
	var motor: RefCounted = body.traversal_motor
	var normal := _last_normal
	var tangent := Vector3.UP.cross(normal).normalized()
	var p := _last_progress if state == "climb" else 0.0
	var hip_position: Vector2 = PROFILE.hip_at(p) if state == "climb" else PROFILE.HANG_HIP
	if state == "climb":
		# Anticipate forearm clearance before releasing palms at the faster tempo.
		hip_position.x += 0.012 * smoothstep(0.64, 0.70, p) * (1.0 - smoothstep(0.72, 0.82, p))
	var shimmy_weight := minf(absf(motor.shimmy_speed) / 0.4, 1.0) if state == "hang" else 0.0
	hip_position += Vector2(-0.04, 0.03) * shimmy_weight
	var hand_center: Vector3 = (motor.hand_anchors[0] + motor.hand_anchors[1]) * 0.5
	var lateral_balance := tangent * (hand_center - _last_ledge).dot(tangent) * (1.0 - smoothstep(0.12, 0.32, p))
	var yaw: float = PROFILE.yaw_at(p) if state == "climb" else 0.0
	var roll: float = PROFILE.roll_at(p) if state == "climb" else 0.0
	var turn := Basis(Vector3.UP, yaw)
	var anatomical_left := turn * -tangent
	var forward := turn * -normal
	var hips_world := _last_ledge + normal * hip_position.x + Vector3.UP * hip_position.y + lateral_balance
	if state == "climb":
		hips_world += anatomical_left * PROFILE.left_bias_at(p)
	_pose_body(skeleton, Vector3.ZERO, tangent, PROFILE.pitch_at(p) if state == "climb" else deg_to_rad(-8.0), 0.0)
	var hips := skeleton.get_bone_global_pose(torso[0])
	var pelvis_turn := Basis(Vector3.UP, yaw) * Basis(-normal, roll)
	hips.basis = skeleton.global_basis.inverse() * pelvis_turn * skeleton.global_basis * hips.basis
	hips.origin = skeleton.to_local(hips_world)
	skeleton.set_bone_global_pose(torso[0], hips)
	# Keep the shoulders facing the grips while the pelvis opens for the left leg.
	var chest := skeleton.get_bone_global_pose(torso[2])
	var counter_turn := Basis(Vector3.UP, -yaw * 0.65) * Basis(-normal, -roll * 0.50)
	chest.basis = skeleton.global_basis.inverse() * counter_turn * skeleton.global_basis * chest.basis
	skeleton.set_bone_global_pose(torso[2], chest)
	phase_name = "cat_hang" if state == "hang" else ("load" if p < 0.13 else ("wall_drive" if p < 0.32 else ("turnover" if p < 0.48 else ("palm_support" if p < 0.56 else ("left_foot_under" if p < 0.72 else ("left_leg_push" if p < 0.86 else "right_leg_follow"))))))
	_update_foot_contacts(motor, normal, tangent, state)
	var planned: Array = []
	for index in 2:
		var side := -1.0 if index == 0 else 1.0
		var suffix := ".L" if index == 0 else ".R"
		var grip_anchor: Vector3 = motor.hand_anchors[index] - normal * 0.145 - Vector3.UP * 0.055
		var palm_anchor: Vector3 = grip_anchor - normal * 0.04 - Vector3.UP * 0.02
		var palm_blend: float = PROFILE.palm_weight(p) if state == "climb" else 0.0
		var hand_weight: float = PROFILE.hand_weight(p, index) if state == "climb" else 1.0
		var hand_mode := "palm" if palm_blend >= 0.999 else "finger"
		var hand_anchor := grip_anchor.lerp(palm_anchor, palm_blend)
		var hand_marker: Vector3 = contact_markers["finger" + suffix].local.lerp(contact_markers["palm" + suffix].local, palm_blend)
		var foot_anchor := _foot_anchors[index]
		var foot_mode := "forefoot"
		var foot_pitch := deg_to_rad(75.0)
		var foot_weight := 1.0
		var advance := 0.0
		# Knee flexion is in a stable anatomical plane, independent of pelvis forward pitch.
		var knee_pole := forward * 0.95 + anatomical_left * (0.65 if index == 0 else -0.20)
		if state == "climb":
			var release: float = PROFILE.foot_release(p, index)
			advance = PROFILE.foot_advance(p, index)
			var initial_frame := _contact_frame(skeleton, legs[index][2], tangent, deg_to_rad(75.0))
			var wall_ankle: Vector3 = _foot_anchors[index] - initial_frame * contact_markers["forefoot" + suffix].local
			var ankle: Vector3
			if index == 0:
				var free := hips_world - Vector3.UP * 0.54 + normal * 0.08 + anatomical_left * 0.24
				var folded := hips_world - Vector3.UP * 0.20 + normal * 0.26 + anatomical_left * 0.27
				ankle = wall_ankle.lerp(free.lerp(folded, PROFILE.foot_lift(p, index)), release)
			else:
				var free := hips_world - Vector3.UP * 0.70 + normal * 0.08 - anatomical_left * 0.17
				var thigh := skeleton.to_global(skeleton.get_bone_global_pose(legs[index][0]).origin)
				var straight := thigh + (-Vector3.UP * 0.55 + normal * 0.83).normalized() * _leg_reach(skeleton, legs[index]) * 0.992
				ankle = wall_ankle.lerp(free, release).lerp(straight, smoothstep(0.43, 0.62, p))
			foot_pitch = lerpf(deg_to_rad(75.0), deg_to_rad(-20.0 if index == 0 else -35.0), release) * (1.0 - advance)
			var swing_frame := _contact_frame(skeleton, legs[index][2], tangent, foot_pitch)
			var swing_marker: Vector3 = contact_markers["forefoot" + suffix].local.lerp(contact_markers["sole" + suffix].local, advance)
			var sole := _last_ledge - normal * 0.55 + tangent * side * 0.14 + Vector3.UP * 0.012
			foot_anchor = (ankle + swing_frame * swing_marker).lerp(sole, advance)
			foot_anchor.y += sin(advance * PI) * (0.10 if index == 0 else 0.07)
			foot_mode = "sole" if advance >= 0.999 else "forefoot"
			foot_weight = 1.0 if release < 0.001 or advance >= 0.999 else 0.0
		var foot_marker: Vector3 = contact_markers["forefoot" + suffix].local.lerp(contact_markers["sole" + suffix].local, advance)
		var elbow_pole := (normal * 0.25 + tangent * side * 0.4 - Vector3.UP * 0.2).lerp(normal * 0.8 + tangent * side * 0.1 + Vector3.UP * 0.35, palm_blend)
		var hand_frame := _contact_frame(skeleton, arms[index][2], tangent, PI / 2.0)
		var hand_solve_weight := hand_weight
		var hand_contact_weight := hand_weight
		if state == "climb":
			var release := 1.0 - hand_weight
			var free_hand := skeleton.get_bone_global_pose(arms[index][2])
			var free_frame := skeleton.global_basis * free_hand.basis
			var free_point := skeleton.to_global(free_hand.origin) + free_frame * hand_marker
			hand_anchor = hand_anchor.lerp(free_point, release) + Vector3.UP * sin(PI * release) * 0.05 * smoothstep(0.10, 0.40, release)
			hand_frame = hand_frame.orthonormalized().slerp(free_frame.orthonormalized(), smoothstep(0.25, 1.0, release))
			hand_solve_weight = 1.0
			# Once released the hand follows a free recovery arc, not a loaded grip.
			hand_contact_weight = 1.0 if release <= 0.001 else 0.0
		var foot_frame := _contact_frame(skeleton, legs[index][2], tangent, foot_pitch)
		planned.append({"hand_anchor": hand_anchor, "hand_marker": hand_marker, "hand_frame": hand_frame, "hand_weight": hand_solve_weight, "elbow_pole": elbow_pole, "foot_anchor": foot_anchor, "foot_marker": foot_marker, "foot_frame": foot_frame, "knee_pole": knee_pole})
		_solve_contact(skeleton, arms[index], hand_marker, hand_anchor, hand_frame, hand_solve_weight, elbow_pole)
		_solve_contact(skeleton, legs[index], foot_marker, foot_anchor, foot_frame, 1.0, knee_pole)
		contact_targets[hand_mode + suffix] = {"anchor": hand_anchor, "weight": hand_contact_weight if palm_blend <= 0.001 or palm_blend >= 0.999 else 0.0, "mode": "grip" if hand_mode == "finger" else "support"}
		contact_targets[foot_mode + suffix] = {"anchor": foot_anchor, "weight": foot_weight if _foot_reach != index else 0.0, "mode": "wall" if foot_mode == "forefoot" else "roof"}
	# Maintain conservative body/armor protection in addition to capsule sweeps.
	clearance_correction = 0.0
	var protected := torso.duplicate()
	for chain in arms:
		protected.append_array([chain[0], chain[1]])
	for chain in legs:
		protected.append(chain[0])
	clearance_source = ""
	var worst_source := 0.0
	for bone in protected:
		var source_depth := geometry.penetration([bone], _last_ledge, normal)
		if source_depth > worst_source:
			worst_source = source_depth
			clearance_source = skeleton.get_bone_name(bone)
	for iteration in 6:
		var depth := geometry.penetration(protected, _last_ledge, normal)
		if depth < 0.001:
			break
		_shift_hips(skeleton, normal * depth)
		clearance_correction += depth
		for index in 2:
			var contact: Dictionary = planned[index]
			_solve_contact(skeleton, arms[index], contact.hand_marker, contact.hand_anchor, contact.hand_frame, contact.hand_weight, contact.elbow_pole)
			_solve_contact(skeleton, legs[index], contact.foot_marker, contact.foot_anchor, contact.foot_frame, 1.0, contact.knee_pole)

func _leg_reach(skeleton: Skeleton3D, chain: Array) -> float:
	return skeleton.get_bone_global_rest(chain[0]).origin.distance_to(skeleton.get_bone_global_rest(chain[1]).origin) + skeleton.get_bone_global_rest(chain[1]).origin.distance_to(skeleton.get_bone_global_rest(chain[2]).origin)

func _contact_frame(skeleton: Skeleton3D, bone: int, tangent: Vector3, pitch: float) -> Basis:
	return Basis(tangent, pitch) * skeleton.global_basis * skeleton.get_bone_global_rest(bone).basis

func _solve_contact(skeleton: Skeleton3D, chain: Array, marker_local: Vector3, anchor: Vector3, frame: Basis, weight: float, pole: Vector3) -> void:
	if weight <= 0.001:
		return
	var target := anchor - frame * marker_local
	var top := skeleton.get_bone_global_pose(chain[0])
	var middle := skeleton.get_bone_global_pose(chain[1])
	var end := skeleton.get_bone_global_pose(chain[2])
	solver._solve(skeleton, chain, top, middle, end, end.origin.lerp(skeleton.to_local(target), weight), Vector3.UP, skeleton.global_basis.inverse() * pole, false, deg_to_rad(150.0) if String(skeleton.get_bone_name(chain[2])).begins_with("foot.") else PI, String(skeleton.get_bone_name(chain[2])).begins_with("foot."))
	var result := skeleton.get_bone_global_pose(chain[2])
	result.basis = result.basis.orthonormalized().slerp((skeleton.global_basis.inverse() * frame).orthonormalized(), weight)
	skeleton.set_bone_global_pose(chain[2], result)

func _update_foot_contacts(motor: RefCounted, normal: Vector3, tangent: Vector3, state: String) -> void:
	if _foot_anchors.size() != 2 or _contact_revision != motor.contact_revision:
		_contact_revision = motor.contact_revision
		_rebrace_started = false
		_foot_anchors.clear()
		for index in 2:
			_foot_anchors.append(_last_ledge + normal * 0.012 + tangent * (-0.15 if index == 0 else 0.15) + Vector3.UP * PROFILE.HANG_FOOT_HEIGHTS[index])
		_foot_reach = -1
	_contact_lip = _last_ledge
	if state != "hang":
		if _foot_reach >= 0:
			if not _rebrace_started:
				_rebrace_from = _foot_anchors[_foot_reach]
				_rebrace_started = true
			var brace := smoothstep(0.0, 0.10, motor.climb_progress)
			_foot_anchors[_foot_reach] = _rebrace_from.lerp(_foot_reach_to, brace)
			if brace >= 1.0:
				_foot_reach = -1
		return
	if _foot_reach < 0:
		var largest := 0.13
		for index in 2:
			var desired: Vector3 = _last_ledge + normal * 0.012 + tangent * (-0.15 if index == 0 else 0.15) + Vector3.UP * PROFILE.HANG_FOOT_HEIGHTS[index]
			if _foot_anchors[index].distance_to(desired) > largest:
				largest = _foot_anchors[index].distance_to(desired)
				_foot_reach = index
				_foot_reach_from = _foot_anchors[index]
				_foot_reach_to = desired
				_foot_reach_time = motor.hang_elapsed
	if _foot_reach >= 0:
		# Motor time is authoritative; repeated render evaluations cannot advance a step.
		var step_phase := clampf((motor.hang_elapsed - _foot_reach_time) / 0.28, 0.0, 1.0)
		_foot_anchors[_foot_reach] = _foot_reach_from.lerp(_foot_reach_to, smoothstep(0.0, 1.0, step_phase)) + normal * sin(step_phase * PI) * 0.07
		if step_phase >= 1.0:
			_foot_reach = -1
