extends "res://tests/integration/traversal_smoke_test.gd"
## Sample the actual post-animation modifier output, not the restored input pose.
var sampled: Dictionary = {}
var slide_penetration := 0.0
var sampled_lengths: Array[float] = []
var planted_frames := 0
var animation_observer: Callable
var observed_modifier: SkeletonModifier3D
var sampled_markers: Dictionary = {}
var sampled_targets: Dictionary = {}
var support_frames := 0
var loaded_plant_frames := 0
var support_before_plant := true
var worst_loaded_contact_error := 0.0
var worst_palm_tread_gap := 0.0
var support_saw_extended_arms := false
var press_min_angles := Vector2(180.0, 180.0)
var press_max_angles := Vector2.ZERO
var support_saw_shoulders_above := false
var _support_last_frame := -1
var _loaded_sole_positions: Dictionary = {}
var worst_loaded_sole_travel := 0.0
var worst_loaded_sole_phase := 0.0
var loaded_sole_pairs := 0
var sampled_motion_frames: Dictionary = {}
var left_support_frames := 0
var left_push_frames := 0
var right_extended_frames := 0
var minimum_right_push_angle := 180.0
var maximum_right_forward := -INF
var maximum_left_hold_drift := 0.0
var left_push_rise := 0.0
var left_push_forward := 0.0
var left_extension_gain := 0.0
var right_plant_after_halfway := false
var right_plant_gap := INF
var right_plant_inboard := false
var right_plant_tilt := 0.0
var right_plant_limit := 0.0
var _left_push_started := false
var _right_has_planted := false
var _left_unloaded_before_right := false
var _left_stance_origin := Vector3.ZERO
var _left_initial_hips := Vector3.ZERO
var _left_initial_tilt := 0.0
var _left_initial_knee := 0.0
var _previous_knee_planes: Dictionary = {}
var _previous_hinges: Dictionary = {}
var knee_plane_pairs := 0
var hinge_pairs := 0
var worst_knee_plane_turn := 0.0
var worst_hinge_turn := 0.0
var maximum_medial_knee_offset := 0.0
var worst_knee_plane_phase := 0.0
var worst_knee_plane_side := ""
var worst_hinge_phase := 0.0
var worst_hinge_side := ""
var worst_medial_phase := 0.0
var worst_medial_side := ""

func observe() -> void:
	if is_instance_valid(observed_modifier) and animation_observer.is_valid() and observed_modifier.modification_processed.is_connected(animation_observer):
		observed_modifier.modification_processed.disconnect(animation_observer)
	var skeleton: Skeleton3D = body.stair_presentation._skeleton
	var modifier: SkeletonModifier3D = body.stair_presentation._traversal_modifier
	observed_modifier = modifier
	animation_observer = func():
		sampled.clear()
		sampled_markers.clear()
		sampled_targets = modifier.contact_targets.duplicate(true)
		for key in modifier.contact_markers:
			var marker: Dictionary = modifier.contact_markers[key]
			sampled_markers[key] = skeleton.global_transform * skeleton.get_bone_global_pose(marker.bone) * marker.local
		sampled_lengths.clear()
		sampled_motion_frames.clear()
		for name in ["hips", "shin.L", "shin.R"]:
			var index := skeleton.find_bone(name)
			sampled_motion_frames[name] = (skeleton.global_basis * skeleton.get_bone_global_pose(index).basis * skeleton.get_bone_global_rest(index).basis.inverse()).orthonormalized()
		for name in ["hips", "upper_arm.L", "forearm.L", "hand.L", "upper_arm.R", "forearm.R", "hand.R", "thigh.L", "shin.L", "foot.L", "thigh.R", "shin.R", "foot.R"]:
			var index := skeleton.find_bone(name)
			sampled[name] = skeleton.to_global(skeleton.get_bone_global_pose(index).origin)
		for chain in [["upper_arm.L", "forearm.L", "hand.L"], ["upper_arm.R", "forearm.R", "hand.R"], ["thigh.L", "shin.L", "foot.L"], ["thigh.R", "shin.R", "foot.R"]]:
			sampled_lengths.append(sampled[chain[0]].distance_to(sampled[chain[1]]))
			sampled_lengths.append(sampled[chain[1]].distance_to(sampled[chain[2]]))
		if body.get_traversal_mode() == "wall_slide":
			slide_penetration = modifier.geometry.penetration(modifier.torso, body.traversal_motor.wall_contact_point + Vector3.UP * 10.0, body.traversal_motor.wall_normal)
		_record_support()
	modifier.modification_processed.connect(animation_observer)

func _arm_extension(side: String) -> float:
	var upper: Vector3 = sampled["forearm." + side] - sampled["upper_arm." + side]
	var lower: Vector3 = sampled["hand." + side] - sampled["forearm." + side]
	return upper.normalized().dot(lower.normalized())

func _record_support() -> void:
	if body.get_traversal_mode() != "climb" or not body.traversal_motor.climb_from_hang:
		return
	var frame := Engine.get_physics_frames()
	if frame == _support_last_frame:
		return
	_support_last_frame = frame
	var motor: RefCounted = body.traversal_motor
	var palms_loaded := true
	for side in ["L", "R"]:
		var key: String = "palm." + side
		palms_loaded = palms_loaded and sampled_targets.has(key) and float(sampled_targets.get(key, {}).get("weight", 0.0)) >= 0.95
	if palms_loaded:
		support_frames += 1
		var left_extension := _arm_extension("L")
		var right_extension := _arm_extension("R")
		support_saw_extended_arms = support_saw_extended_arms or maxf(left_extension, right_extension) >= cos(deg_to_rad(30.0))
		var left_angle := rad_to_deg(acos(clampf(-left_extension, -1.0, 1.0)))
		var right_angle := rad_to_deg(acos(clampf(-right_extension, -1.0, 1.0)))
		press_min_angles.x = minf(press_min_angles.x, left_angle)
		press_min_angles.y = minf(press_min_angles.y, right_angle)
		press_max_angles.x = maxf(press_max_angles.x, left_angle)
		press_max_angles.y = maxf(press_max_angles.y, right_angle)
		var shoulders: Vector3 = (sampled["upper_arm.L"] + sampled["upper_arm.R"]) * 0.5
		var palms: Vector3 = (sampled_markers["palm.L"] + sampled_markers["palm.R"]) * 0.5
		support_saw_shoulders_above = support_saw_shoulders_above or shoulders.y > palms.y + 0.15
		for side in ["L", "R"]:
			var point: Vector3 = sampled_markers["palm." + side]
			worst_palm_tread_gap = maxf(worst_palm_tread_gap, absf(point.y - motor.ledge_point.y))
	var current_soles: Dictionary = {}
	for key in sampled_targets:
		var target: Dictionary = sampled_targets[key]
		if float(target.get("weight", 0.0)) < 0.95 or not sampled_markers.has(key):
			continue
		var measured_error: float = sampled_markers[key].distance_to(target.anchor)
		if measured_error > worst_loaded_contact_error:
			worst_loaded_contact_error = measured_error
			if measured_error > 0.035:
				print("CONTACT_ERROR phase=", motor.climb_progress, " key=", key, " error=", measured_error)
		if String(key).begins_with("sole."):
			var point: Vector3 = sampled_markers[key]
			if _loaded_sole_positions.has(key):
				var previous: Dictionary = _loaded_sole_positions[key]
				if int(previous.frame) == frame - 1:
					loaded_sole_pairs += 1
					var delta: Vector3 = point - previous.point
					var travel := Vector2(delta.x, delta.z).length()
					if travel > worst_loaded_sole_travel:
						worst_loaded_sole_travel = travel
						worst_loaded_sole_phase = motor.climb_progress
			current_soles[key] = {"point": point, "frame": frame}
			if absf(point.y - motor.ledge_point.y) <= 0.03 and (point - motor.ledge_point).dot(motor.wall_normal) < -0.015:
				loaded_plant_frames += 1
				support_before_plant = support_before_plant and support_frames > 0
	_loaded_sole_positions = current_soles
	_record_left_push(motor)
	_record_knee_planes(frame)

func _leg_angle(side: String) -> float:
	var upper: Vector3 = sampled["shin." + side] - sampled["thigh." + side]
	var lower: Vector3 = sampled["foot." + side] - sampled["shin." + side]
	return rad_to_deg(acos(clampf(-upper.normalized().dot(lower.normalized()), -1.0, 1.0)))

func _record_left_push(motor: RefCounted) -> void:
	var shoulders: Vector3 = (sampled["upper_arm.L"] + sampled["upper_arm.R"]) * 0.5
	var hips: Vector3 = sampled["hips"]
	var torso_tilt := rad_to_deg(acos(clampf((shoulders - hips).normalized().dot(Vector3.UP), -1.0, 1.0)))
	var left_loaded := float(sampled_targets.get("sole.L", {}).get("weight", 0.0)) >= 0.95
	var right_loaded := float(sampled_targets.get("sole.R", {}).get("weight", 0.0)) >= 0.95
	if left_loaded and not _left_push_started:
		var left_point: Vector3 = sampled_markers["sole.L"]
		if absf(left_point.y - motor.ledge_point.y) <= 0.03 and (left_point - motor.ledge_point).dot(motor.wall_normal) < -0.015:
			_left_push_started = true
			_left_stance_origin = left_point
			_left_initial_hips = hips
			_left_initial_tilt = torso_tilt
			_left_initial_knee = _leg_angle("L")
	if right_loaded and not _right_has_planted:
		_right_has_planted = true
		right_plant_tilt = torso_tilt
		right_plant_limit = _left_initial_tilt * 0.5 + 5.0
		right_plant_after_halfway = _left_push_started and torso_tilt <= right_plant_limit
		var right_point: Vector3 = sampled_markers["sole.R"]
		right_plant_gap = absf(right_point.y - motor.ledge_point.y)
		right_plant_inboard = (right_point - motor.ledge_point).dot(motor.wall_normal) < -0.015
	if not _left_push_started:
		return
	if left_loaded:
		left_support_frames += 1
		var drift: Vector3 = sampled_markers["sole.L"] - _left_stance_origin
		maximum_left_hold_drift = maxf(maximum_left_hold_drift, Vector2(drift.x, drift.z).length())
	elif not _right_has_planted:
		_left_unloaded_before_right = true
	if not _right_has_planted:
		left_push_rise = maxf(left_push_rise, hips.y - _left_initial_hips.y)
		left_push_forward = maxf(left_push_forward, (hips - _left_initial_hips).dot(-motor.wall_normal))
		left_extension_gain = maxf(left_extension_gain, _leg_angle("L") - _left_initial_knee)
		if left_loaded and torso_tilt > _left_initial_tilt * 0.5:
			left_push_frames += 1
			var right_angle := _leg_angle("R")
			minimum_right_push_angle = minf(minimum_right_push_angle, right_angle)
			if right_angle >= 145.0:
				right_extended_frames += 1
			maximum_right_forward = maxf(maximum_right_forward, (sampled["foot.R"] - hips).dot(-motor.wall_normal))

func _record_knee_planes(frame: int) -> void:
	var pelvis: Basis = sampled_motion_frames["hips"]
	for side in ["L", "R"]:
		var thigh: Vector3 = sampled["thigh." + side]
		var knee: Vector3 = sampled["shin." + side]
		var ankle: Vector3 = sampled["foot." + side]
		var axis := (ankle - thigh).normalized()
		var bend := knee - thigh - axis * (knee - thigh).dot(axis)
		var local_bend := pelvis.inverse() * bend
		var outward := 1.0 if side == "L" else -1.0
		var medial := -outward * local_bend.x
		if medial > maximum_medial_knee_offset:
			maximum_medial_knee_offset = medial
			worst_medial_phase = body.traversal_motor.climb_progress
			worst_medial_side = side
		if bend.length() >= 0.02:
			var plane := (pelvis.inverse() * axis.cross(bend)).normalized()
			if _previous_knee_planes.has(side):
				var previous: Dictionary = _previous_knee_planes[side]
				if int(previous.frame) == frame - 1:
					knee_plane_pairs += 1
					var turn := rad_to_deg(acos(clampf(plane.dot(previous.plane), -1.0, 1.0)))
					if turn > worst_knee_plane_turn:
						worst_knee_plane_turn = turn
						worst_knee_plane_phase = body.traversal_motor.climb_progress
						worst_knee_plane_side = side
			_previous_knee_planes[side] = {"frame": frame, "plane": plane}
		else:
			_previous_knee_planes.erase(side)
		var shin_frame: Basis = sampled_motion_frames["shin." + side]
		var hinge := (pelvis.inverse() * shin_frame.x).normalized()
		if _previous_hinges.has(side):
			var previous: Dictionary = _previous_hinges[side]
			if int(previous.frame) == frame - 1:
				hinge_pairs += 1
				var turn := rad_to_deg(acos(clampf(hinge.dot(previous.hinge), -1.0, 1.0)))
				if turn > worst_hinge_turn:
					worst_hinge_turn = turn
					worst_hinge_phase = body.traversal_motor.climb_progress
					worst_hinge_side = side
		_previous_hinges[side] = {"frame": frame, "hinge": hinge}

func _reset_support_metrics() -> void:
	support_frames = 0
	loaded_plant_frames = 0
	support_before_plant = true
	worst_loaded_contact_error = 0.0
	worst_palm_tread_gap = 0.0
	support_saw_extended_arms = false
	press_min_angles = Vector2(180.0, 180.0)
	press_max_angles = Vector2.ZERO
	support_saw_shoulders_above = false
	_support_last_frame = -1
	_loaded_sole_positions.clear()
	worst_loaded_sole_travel = 0.0
	worst_loaded_sole_phase = 0.0
	loaded_sole_pairs = 0
	left_support_frames = 0
	left_push_frames = 0
	right_extended_frames = 0
	minimum_right_push_angle = 180.0
	maximum_right_forward = -INF
	maximum_left_hold_drift = 0.0
	left_push_rise = 0.0
	left_push_forward = 0.0
	left_extension_gain = 0.0
	right_plant_after_halfway = false
	right_plant_gap = INF
	right_plant_inboard = false
	right_plant_tilt = 0.0
	right_plant_limit = 0.0
	_left_push_started = false
	_right_has_planted = false
	_left_unloaded_before_right = false
	_previous_knee_planes.clear()
	_previous_hinges.clear()
	knee_plane_pairs = 0
	hinge_pairs = 0
	worst_knee_plane_turn = 0.0
	worst_hinge_turn = 0.0
	maximum_medial_knee_offset = 0.0
	worst_knee_plane_phase = 0.0
	worst_knee_plane_side = ""
	worst_hinge_phase = 0.0
	worst_hinge_side = ""
	worst_medial_phase = 0.0
	worst_medial_side = ""

func run() -> void:
	world = Node3D.new()
	root.add_child(world)
	body = PLAYER.instantiate()
	body.set_script(LOCAL)
	body.get_node("Combatant").free()
	if body.has_node("BurnStatus"):
		body.get_node("BurnStatus").free()
	world.add_child(body)
	body.set_physics_process(false)
	var motor: RefCounted = body.traversal_motor
	for character in [0, 1]:
		body.get_node("Mesh").set_character(character)
		await frames(4)
		await fixture(1.8)
		observe()
		check(motor.request_ledge(Vector3.FORWARD), "rig %d grabs" % character)
		await tick(20)
		check(not sampled.is_empty(), "rig %d samples actual modifier output" % character)
		var left: Vector3 = sampled["hand.L"]
		var right: Vector3 = sampled["hand.R"]
		check(left.x < right.x - 0.25, "rig %d hands remain on correct anatomical sides" % character)
		var contact_error: float = maxf(sampled_markers["finger.L"].distance_to(sampled_targets["finger.L"].anchor), sampled_markers["finger.R"].distance_to(sampled_targets["finger.R"].anchor))
		print("HANG_CONTACT ", character, " ", contact_error)
		check(contact_error < 0.035, "rig %d hanging hands reach the ledge" % character)
		var foot_height: float = (sampled_markers["forefoot.L"].y + sampled_markers["forefoot.R"].y) * 0.5
		var stagger: float = absf(sampled_markers["forefoot.L"].y - sampled_markers["forefoot.R"].y)
		print("CAT_POSTURE rig=", character, " hip_foot_gap=", absf(sampled["hips"].y-foot_height), " stagger=", stagger, " extension=", minf(_arm_extension("L"),_arm_extension("R")))
		check(absf(sampled["hips"].y-foot_height) <= 0.15 and stagger >= 0.25 and stagger <= 0.35, "approved asymmetric brace keeps high left and low right wall feet")
		check(minf(_arm_extension("L"),_arm_extension("R")) >= cos(deg_to_rad(30.0)), "cat hang uses extended arms")
		var lengths := sampled_lengths.duplicate()
		var weapons_hidden: bool = not body.stair_presentation._weapons.is_empty()
		for weapon in body.stair_presentation._weapons:
			weapons_hidden = weapons_hidden and not weapon.visible
		check(weapons_hidden, "rig %d frees both hands by stowing sword" % character)
		_reset_support_metrics()
		motor.simulate(1.0 / 60.0, Vector3.ZERO, true, false, false)
		for sample in [12, 15, 13, 10]:
			await tick(sample)
			var length_error := 0.0
			for i in lengths.size():
				length_error = maxf(length_error, absf(sampled_lengths[i] - lengths[i]))
			check(length_error < 0.01, "rig %d IK preserves limb segment lengths" % character)
		await tick(55)
		for remaining in 120:
			if body.get_traversal_mode() == "normal":
				break
			await tick(1)
		print("PARKOUR_SUPPORT rig=",character," palm_frames=",support_frames," sole_frames=",loaded_plant_frames," contact_error=",worst_loaded_contact_error," tread_gap=",worst_palm_tread_gap)
		print("PRESS_EXTENSION rig=", character, " left_min_degrees=", press_min_angles.x, " left_max_degrees=", press_max_angles.x, " right_min_degrees=", press_min_angles.y, " right_max_degrees=", press_max_angles.y)
		check(support_frames >= 6 and support_saw_extended_arms and support_saw_shoulders_above, "climb presses through an extended support arm above loaded palms")
		check(worst_palm_tread_gap <= 0.03, "loaded palms rest on actual tread")
		check(loaded_plant_frames >= 3 and support_before_plant, "reachable top sole plant follows palm support")
		check(worst_loaded_contact_error <= 0.04, "actual loaded contact markers reach their anchors")
		print("LOADED_SOLE_TRAVEL rig=", character, " distance=", worst_loaded_sole_travel, " phase=", worst_loaded_sole_phase, " consecutive_pairs=", loaded_sole_pairs)
		check(loaded_sole_pairs >= 3 and worst_loaded_sole_travel <= 0.01, "loaded top soles stay planted between physics frames")
		print("LEFT_PUSH rig=", character, " stance_frames=", left_support_frames, " drift=", maximum_left_hold_drift, " push_frames=", left_push_frames, " right_extended=", right_extended_frames, " right_min_angle=", minimum_right_push_angle, " right_forward=", maximum_right_forward, " pelvis_rise=", left_push_rise, " pelvis_forward=", left_push_forward, " left_extension_gain=", left_extension_gain)
		check(left_support_frames >= 6 and maximum_left_hold_drift <= 0.04 and not _left_unloaded_before_right, "left sole stays fixed through the supported push")
		check(left_push_frames >= 3 and right_extended_frames >= int(ceil(float(left_push_frames) * 0.8)) and minimum_right_push_angle >= 135.0, "right leg remains nearly straight during the left push")
		check(left_push_frames >= 3 and maximum_right_forward <= 0.05, "unloaded right leg trails behind the advancing body")
		check(left_push_rise >= 0.12 and left_push_forward >= 0.10 and left_extension_gain >= 20.0, "left-leg extension drives the pelvis forward and upward")
		print("RIGHT_PLANT rig=", character, " tilt=", right_plant_tilt, " halfway_limit=", right_plant_limit, " tread_gap=", right_plant_gap)
		check(_right_has_planted and right_plant_after_halfway and right_plant_gap <= 0.03 and right_plant_inboard, "right sole plants after the torso is halfway upright")
		print("KNEE_PLANES rig=", character, " plane_pairs=", knee_plane_pairs, " worst_plane_turn=", worst_knee_plane_turn, " plane_phase=", worst_knee_plane_phase, " plane_side=", worst_knee_plane_side, " hinge_pairs=", hinge_pairs, " worst_hinge_turn=", worst_hinge_turn, " hinge_phase=", worst_hinge_phase, " hinge_side=", worst_hinge_side, " medial_offset=", maximum_medial_knee_offset, " medial_phase=", worst_medial_phase, " medial_side=", worst_medial_side)
		check(knee_plane_pairs >= 6 and worst_knee_plane_turn <= 45.0 and maximum_medial_knee_offset <= 0.05, "knees retain continuous anatomical bend planes without inward flips")
		check(hinge_pairs >= 6 and worst_hinge_turn <= 45.0, "shin hinge axes stay continuous through near-straight poses")
		check(body.get_traversal_mode() == "normal" and body.is_on_floor(), "rig %d completes climb" % character)
		await tick(35)
		var restored := true
		for i in body.stair_presentation._weapons.size():
			restored = restored and body.stair_presentation._weapons[i].visible == body.stair_presentation._weapon_visibility[i]
		check(restored, "rig %d restores weapon visibility after traversal" % character)
	for character in [0, 1]:
		body.get_node("Mesh").set_character(character)
		await frames(4)
		await fixture(0.6)
		observe()
		check(motor.request_ledge(Vector3.FORWARD), "rig %d low mantle begins from standing foot anchors" % character)
		for count in [6, 6, 12, 12]:
			await tick(count)
			var minimum_ankle: float = minf(sampled["foot.L"].y, sampled["foot.R"].y)
			print("LOW_MANTLE_ANKLE ", character, " phase=", motor.climb_progress, " y=", minimum_ankle)
			check(minimum_ankle >= 0.08, "rig %d low mantle keeps ankles above the floor" % character)
			var clear_tread := true
			for foot in ["foot.L", "foot.R"]:
				if sampled[foot].z < 2.0:
					clear_tread = clear_tread and sampled[foot].y >= 0.68
			check(clear_tread, "rig %d lifts feet before crossing the ledge face" % character)
	await fixture(1.8)
	body.position = Vector3(2.8, 1.01, 2.7)
	body.velocity = Vector3.ZERO
	body.move_and_slide()
	check(not motor.request_ledge(Vector3.FORWARD), "near-end initial grab rejects unsupported outer hand")
	body.position = Vector3(2.4, 1.01, 2.7)
	body.velocity = Vector3.ZERO
	body.move_and_slide()
	check(motor.request_ledge(Vector3.FORWARD), "safe near-end position supports both hands")
	await tick(50, Vector3.LEFT)
	check(body.position.x < 2.1, "safe near-end grab can shimmy inward")
	await fixture(1.8)
	check(motor.request_ledge(Vector3.FORWARD), "shimmy fixture grabs")
	var initial := body.position
	var anchors_preserved := true
	var grip_error := 0.0
	for i in 100:
		var previous: Array = motor.hand_anchors.duplicate()
		await tick(1, Vector3.RIGHT)
		for hand in 2:
			if previous[hand].distance_to(motor.hand_anchors[hand]) < 0.0001:
				grip_error = maxf(grip_error, sampled_markers["finger.L" if hand == 0 else "finger.R"].distance_to(sampled_targets["finger.L" if hand == 0 else "finger.R"].anchor))
		if previous[0].distance_to(motor.hand_anchors[0]) > 0.0001 and previous[1].distance_to(motor.hand_anchors[1]) > 0.0001:
			anchors_preserved = false
	check(body.position.x > initial.x + 0.8 and body.get_traversal_mode() == "hang", "sideways input moves along ledge")
	check(anchors_preserved, "shimmy moves one hand while the other remains planted")
	print("SHIMMY_GRIP_ERROR=", grip_error)
	check(grip_error < 0.04, "planted shimmy hand stays on its actual ledge anchor")
	await tick(300, Vector3.RIGHT)
	check(body.position.x < 2.61 and body.position.x > 2.3 and body.get_traversal_mode() == "hang", "shimmy stops safely before unsupported ledge end")
	await tick(100, Vector3.LEFT)
	check(body.position.x < 1.8, "shimmy can reverse direction")
	motor.simulate(1.0 / 60.0, Vector3.ZERO, true, false, false)
	await tick(95)
	for remaining in 150:
		if body.get_traversal_mode() == "normal":
			break
		await tick(1)
	check(body.get_traversal_mode() == "normal" and body.is_on_floor() and body.position.x > 0.5, "climb uses the new shimmy position")
	await fixture(1.8)
	check(motor.request_ledge(Vector3.FORWARD), "shimmy obstruction fixture grabs")
	box(Vector3(0.3, 2.0, 0.8), Vector3(0.9, 1.0, 2.55))
	await tick(150, Vector3.RIGHT)
	check(body.position.x < 0.3 and body.get_traversal_mode() == "hang", "shimmy capsule stops at blocking geometry")
	await fixture(1.8)
	check(motor.request_ledge(Vector3.FORWARD), "early climb steering fixture grabs")
	motor.simulate(1.0 / 60.0, Vector3.ZERO, true, false, false)
	await tick(12, Vector3.RIGHT)
	check(body.position.x > 0.04 and body.get_traversal_mode() == "climb", "early climb permits lateral adjustment before weight transfer")
	await fixture(6.0)
	body.position = Vector3(0, 3, 2.55)
	body.velocity = Vector3.DOWN
	body.move_and_slide()
	var previous_jump_facing: Vector3 = body.get_node("Mesh").global_basis.z.normalized()
	motor.simulate(1.0 / 60.0, Vector3.FORWARD, true, false, false)
	check(motor.pose_name() == "wall_jump", "wall jump has a distinct takeoff pose")
	var worst_jump_turn := 0.0
	var jump_ticks := ceili(float(motor.WALL_JUMP_POSE_DURATION) * float(Engine.physics_ticks_per_second))
	for jump_tick in jump_ticks:
		await tick(1)
		var current_facing: Vector3 = body.get_node("Mesh").global_basis.z.normalized()
		worst_jump_turn = maxf(worst_jump_turn, rad_to_deg(acos(clampf(previous_jump_facing.dot(current_facing), -1.0, 1.0))))
		previous_jump_facing = current_facing
		if jump_tick == 11:
			check(motor.pose_name() == "wall_jump", "wall jump pose survives the movement push phase")
	var facing: Vector3 = body.get_node("Mesh").global_basis.z
	check(facing.dot(motor.jump_wall_normal) > 0.5, "wall-jump facing turns smoothly away from wall")
	print("WALL_JUMP_TURN max_degrees_per_tick=", worst_jump_turn, " ticks=", jump_ticks)
	check(worst_jump_turn <= 15.0, "wall-jump facing changes continuously through the authored turn")
	await tick(2)
	check(motor.pose_name() == "normal", "wall-jump pose releases into regular airborne animation")
	body.reset_traversal()
	check(body.stair_presentation._traversal_modifier.influence == 0.0, "reset clears lingering traversal pose")
	for character in [0, 1]:
		body.get_node("Mesh").set_character(character)
		await frames(4)
		observe()
		for orientation in 4:
			await fixture(1.8)
			geometry[1].rotation.y = PI / 2.0 if orientation % 2 else 0.0
			await frames(2)
			var outward: Vector3 = [Vector3.BACK, Vector3.RIGHT, Vector3.FORWARD, Vector3.LEFT][orientation]
			body.position = outward * 2.7 + Vector3.UP * 1.01
			body.velocity = Vector3.ZERO
			body.move_and_slide()
			await frames(3)
			check(motor.request_ledge(-outward), "rig %d grabs wall orientation %d" % [character, orientation])
			await tick(20)
			var left_axis: Vector3 = body.get_node("Mesh").global_basis.x
			check((sampled["hand.L"] - sampled["hips"]).dot(left_axis) > 0.1 and (sampled["hand.R"] - sampled["hips"]).dot(left_axis) < -0.1, "rig %d anatomy is correct on wall %d" % [character, orientation])
		await fixture(6.0)
		body.position = Vector3(0, 3, 2.55)
		body.velocity = Vector3.DOWN * 5.0
		body.move_and_slide()
		motor.simulate(1.0 / 60.0, Vector3.FORWARD, false, false, false)
		await tick(16, Vector3.FORWARD)
		check(motor.pose_name() == "wall_slide", "rig %d holds controlled wall slide" % character)
		var slide_error := 0.0
		for key in sampled_targets:
			slide_error = maxf(slide_error, sampled_markers[key].distance_to(sampled_targets[key].anchor))
		print("SLIDE_CONTACT rig=", character, " error=", slide_error, " penetration=", slide_penetration)
		check(sampled_targets.size() == 4 and slide_error < 0.04, "rig %d sliding palms and boots reach wall" % character)
		check(slide_penetration < 0.001, "rig %d sliding torso remains outside wall" % character)
		var knees_forward := true
		for side in ["L", "R"]:
			var thigh: Vector3 = sampled["thigh." + side]
			var axis: Vector3 = (sampled["foot." + side] - thigh).normalized()
			var bend: Vector3 = sampled["shin." + side] - thigh
			bend -= axis * bend.dot(axis)
			knees_forward = knees_forward and bend.dot(-motor.wall_normal) > 0.0 and sampled["foot." + side].y < sampled["hips"].y - 0.25
		check(knees_forward, "rig %d wall slide bends knees forward with feet below pelvis" % character)
		motor.simulate(1.0 / 60.0, Vector3.FORWARD, true, false, false)
		check(motor.pose_name() == "wall_jump" and body.velocity.dot(motor.jump_wall_normal) > 4.0, "rig %d wall slide transitions to outward jump" % character)
		await fixture(6.0)
		body.position = Vector3(0, 3, 2.55)
		body.velocity = Vector3.DOWN
		body.move_and_slide()
		motor.simulate(1.0 / 60.0, Vector3.FORWARD, true, false, false)
		for time_slice in [2, 4, 8, 12]:
			await tick(time_slice)
			var left_axis: Vector3 = body.get_node("Mesh").global_basis.x
			check((sampled["hand.L"] - sampled["hips"]).dot(left_axis) > 0.05 and (sampled["hand.R"] - sampled["hips"]).dot(left_axis) < -0.05, "rig %d wall-jump turn preserves left/right limbs" % character)
	world.free()
	print("CHECKS=", checks, " ALL_TESTS_PASS=", failures == 0)
	quit(0 if failures == 0 else 1)
