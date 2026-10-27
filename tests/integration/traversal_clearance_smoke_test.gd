extends "res://tests/integration/traversal_smoke_test.gd"
var plant_support_samples := 0
var worst_plant_support_gap := 0.0
var maximum_clearance_correction := 0.0
var maximum_clearance_phase := 0.0
var maximum_hip_frame_travel := 0.0
var maximum_hip_speed := 0.0
var worst_hip_continuity_excess := 0.0
var worst_hip_continuity_phase := 0.0
var _last_pose_frame := -1
var _last_hip_relative_normal := 0.0
## Checks conservative envelopes of the visible armor at every animation update.
var worst_depth := 0.0
var worst_bone := ""
var worst_phase := 0.0
var lowest_boot := 10.0
var envelope_frames := 0
var clearance_observer: Callable
var foot_frames: Dictionary = {}
var forefoot_errors: Dictionary = {}

func observe_clearance(height: float) -> void:
	var skeleton: Skeleton3D = body.stair_presentation._skeleton
	var modifier: SkeletonModifier3D = body.stair_presentation._traversal_modifier
	clearance_observer = func():
		if body.get_traversal_mode() not in ["hang", "climb"]:
			return
		envelope_frames += 1
		var progress: float = body.traversal_motor.climb_progress
		var plant_loaded := false
		if body.get_traversal_mode() == "climb":
			if body.traversal_motor.climb_from_hang:
				plant_loaded = float(modifier.contact_targets.get("sole.L", {}).get("weight", 0.0)) >= 0.95
			else:
				plant_loaded = progress >= 0.60 and progress <= 0.72
		if plant_loaded:
			var sole_gap := INF
			for point in modifier.geometry.points(skeleton.find_bone("foot.L")):
				if (point - body.traversal_motor.ledge_point).dot(body.traversal_motor.wall_normal) < -0.015:
					sole_gap = minf(sole_gap, absf(point.y - body.traversal_motor.ledge_point.y))
			plant_support_samples += 1
			if sole_gap > worst_plant_support_gap:
				var sole_marker: Dictionary = modifier.contact_markers["sole.L"]
				var sole_point: Vector3 = skeleton.global_transform * skeleton.get_bone_global_pose(sole_marker.bone) * sole_marker.local
				print("PLANT_GAP_MAX height=", height, " phase=", progress, " corner_gap=", sole_gap, " sole_marker=", sole_point - body.traversal_motor.ledge_point, " target=", modifier.contact_targets.get("sole.L", {}))
			worst_plant_support_gap = maxf(worst_plant_support_gap, sole_gap)
		var correction: float = modifier.clearance_correction
		if correction > maximum_clearance_correction:
			maximum_clearance_correction = correction
			maximum_clearance_phase = body.traversal_motor.climb_progress
		var frame := Engine.get_physics_frames()
		var hips := skeleton.to_global(skeleton.get_bone_global_pose(skeleton.find_bone("hips")).origin)
		var relative_normal: float = (hips - body.global_position).dot(body.traversal_motor.wall_normal)
		if frame != _last_pose_frame:
			if _last_pose_frame >= 0:
				var duration := float(frame - _last_pose_frame) / float(Engine.physics_ticks_per_second)
				var travel := absf(relative_normal - _last_hip_relative_normal)
				maximum_hip_frame_travel = maxf(maximum_hip_frame_travel, travel)
				maximum_hip_speed = maxf(maximum_hip_speed, travel / duration)
				# At 60 Hz allow <= 3.94 cm, including 6 mm sampling tolerance.
				# Root motion is removed so rapid traversal does not hide a cosmetic pop.
				var excess := travel - (0.006 + 2.0 * duration)
				if excess > worst_hip_continuity_excess:
					worst_hip_continuity_excess = excess
					worst_hip_continuity_phase = body.traversal_motor.climb_progress
			_last_pose_frame = frame
			_last_hip_relative_normal = relative_normal
		for side in ["L", "R"]:
			var foot := skeleton.find_bone("foot." + side)
			foot_frames[side] = skeleton.global_basis * skeleton.get_bone_global_pose(foot).basis * skeleton.get_bone_global_rest(foot).basis.inverse()
			var forefoot_key: String = "forefoot." + side
			if modifier.contact_targets.has(forefoot_key):
				var forefoot_marker: Dictionary = modifier.contact_markers[forefoot_key]
				var forefoot_point: Vector3 = skeleton.global_transform * skeleton.get_bone_global_pose(foot) * forefoot_marker.local
				forefoot_errors[side] = forefoot_point.distance_to(modifier.contact_targets[forefoot_key].anchor)
		for bone in modifier.geometry.bounds:
			for point in modifier.geometry.points(bone):
				var inside_face: float = -(point - body.traversal_motor.ledge_point).dot(body.traversal_motor.wall_normal)
				var depth: float = minf(height - point.y, inside_face)
				if depth > worst_depth:
					worst_depth = depth
					worst_bone = skeleton.get_bone_name(bone)
					worst_phase = body.traversal_motor.climb_progress
				if String(skeleton.get_bone_name(bone)).begins_with("foot."):
					if point.y < lowest_boot:
						lowest_boot = point.y
	modifier.modification_processed.connect(clearance_observer)

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
	for character in [0, 1]:
		for height in [0.6, 1.2, 1.8]:
			body.get_node("Mesh").set_character(character)
			await frames(4)
			await fixture(height)
			worst_bone = ""
			worst_phase = 0.0
			worst_depth = 0.0
			lowest_boot = 10.0
			envelope_frames = 0
			forefoot_errors.clear()
			plant_support_samples = 0
			worst_plant_support_gap = 0.0
			maximum_clearance_correction = 0.0
			maximum_clearance_phase = 0.0
			maximum_hip_frame_travel = 0.0
			maximum_hip_speed = 0.0
			worst_hip_continuity_excess = 0.0
			worst_hip_continuity_phase = 0.0
			_last_pose_frame = -1
			observe_clearance(height)
			var motor: RefCounted = body.traversal_motor
			check(motor.request_ledge(Vector3.FORWARD), "rig %d grabs %.1fm" % [character, height])
			if body.get_traversal_mode() == "hang":
				await tick(20)
				for side in ["L", "R"]:
					check(float(forefoot_errors.get(side, INF)) <= 0.035, "actual hanging forefoot holds its wall contact")
					var frame: Basis = foot_frames[side]
					var lateral: Vector3 = body.get_node("Mesh").global_basis.x
					check((frame * Vector3.RIGHT).normalized().dot(lateral) > cos(deg_to_rad(10.0)), "hanging boot keeps lateral alignment without ankle roll")
				motor.simulate(1.0 / 60.0, Vector3.ZERO, true, false, false)
			await tick(100)
			for remaining in 120:
				if body.get_traversal_mode() == "normal":
					break
				await tick(1)
			body.stair_presentation._traversal_modifier.modification_processed.disconnect(clearance_observer)
			check(body.get_traversal_mode() == "normal", "sampled climb completes into normal movement")
			print("GEOMETRY rig=",character," height=",height," depth=",worst_depth," bone=",worst_bone," phase=",worst_phase," boot_floor=",lowest_boot," samples=",envelope_frames)
			check(envelope_frames > 30, "full animation sequence was sampled")
			check(worst_depth < 0.001, "visible body does not enter the ledge")
			check(lowest_boot >= -0.01, "boot geometry stays above the floor")
			print("CONTINUITY rig=", character, " height=", height, " max_correction=", maximum_clearance_correction, " correction_phase=", maximum_clearance_phase, " hip_frame_travel=", maximum_hip_frame_travel, " hip_speed=", maximum_hip_speed, " excess=", worst_hip_continuity_excess, " phase=", worst_hip_continuity_phase)
			check(worst_hip_continuity_excess < 0.0001, "visual hips move continuously relative to collision body")
			print("PLANT_SUPPORT rig=", character, " height=", height, " samples=", plant_support_samples, " worst_sole_gap=", worst_plant_support_gap)
			check(plant_support_samples >= 4 and worst_plant_support_gap <= 0.03, "lead boot maintains toe-supported plant through weight transfer")
	world.free()
	print("CHECKS=",checks," ALL_TESTS_PASS=",failures == 0)
	quit(0 if failures == 0 else 1)
