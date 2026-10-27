extends SceneTree
const MAIN := preload("res://scenes/main/Main.tscn")
var checks := 0
var failures := 0
var skeleton: Skeleton3D
var captured: Array[Transform3D] = []
var max_sword_error := 0.0
var max_cast_error := 0.0
var max_foot_error := 0.0
var yixuan := "--yixuan" in OS.get_cmdline_user_args()
var prefix := "Yixuan" if yixuan else "Astra"

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", label)

func frames(count: int) -> void:
	for i in count:
		await physics_frame
	await process_frame

func capture() -> void:
	captured.clear()
	for bone in skeleton.get_bone_count():
		captured.append(skeleton.get_bone_global_pose(bone))

func sample(player: AnimationPlayer, style: SkeletonModifier3D, clip: String, time: float, enabled: bool) -> Array[Transform3D]:
	style.active = enabled
	skeleton.reset_bone_poses()
	player.play(clip)
	player.seek(time, true)
	player.pause()
	skeleton.advance(0.0)
	await process_frame
	var result: Array[Transform3D] = []
	result.assign(captured)
	return result

func error(a: Transform3D, b: Transform3D) -> float:
	return maxf(a.origin.distance_to(b.origin), maxf(a.basis.x.distance_to(b.basis.x), maxf(a.basis.y.distance_to(b.basis.y), a.basis.z.distance_to(b.basis.z))))

func run() -> void:
	var main := MAIN.instantiate()
	root.add_child(main)
	main.get_node("MatchManager").set_physics_process(false)
	for name in ["Opponent1", "Opponent2"]:
		main.get_node(name + "/AttackHitbox").set_physics_process(false)
	await frames(10)
	var body: CharacterBody3D = main.get_node("Player")
	var mesh: Node = body.get_node("Mesh")
	var controls: Node = body.get_node("MotionTestControls")
	var driver: Node = body.get_node("CharacterAnimation")
	var attack: Node = body.get_node("AttackHitbox")
	var original_shape: Shape3D = body.get_node("CollisionShape3D").shape
	var movement := [body.walk_speed, body.run_speed, body.aim_step_run_speed, body.acceleration, body.deceleration, body.jump_velocity]
	var combat := [attack.attack_range, attack.weapon_radius, attack.attack_damage, attack.ground_duration_s, attack.air_duration_s, attack.contact_start_phase, attack.contact_end_phase]
	if yixuan:
		controls.switch_character()
	controls.switch_skin()
	await frames(8)
	body.set_physics_process(false)
	body.stair_presentation.set_physics_process(false)
	controls.set_physics_process(false)
	attack.set_physics_process(false)
	driver.set_physics_process(false)
	driver.set_manual_preview(true)
	var motion: Node = mesh._model.get_node(prefix + "SpringMotion")
	var style: SkeletonModifier3D = motion.graceful_pose
	skeleton = motion.skeleton
	motion.simulator.active = false
	motion.limiter.modification_processed.connect(capture)
	check(style.get_index() < motion.simulator.get_index(), "grace precedes secondary spring motion")
	check(body.is_motion_grounded(), "fixture is grounded")
	var right := skeleton.find_bone("hand.R")
	var left := skeleton.find_bone("hand.L")
	var left_foot := skeleton.find_bone("foot.L")
	var right_foot := skeleton.find_bone("foot.R")
	var expressive := skeleton.find_bone("forearm.L")
	var player: AnimationPlayer = driver._anim
	for clip in ["Idle", "Walk", "Run", "Walk_Backward", "Walk_Left", "Walk_Right", "Jump", "Attack_Slash", "Attack_Backhand", "Attack_Overhead", "Attack_Thrust", "Actions/CastEnergy", "Actions/Dash_Forward", "Actions/Dodge_Left", "Actions/Parry_Attempt"]:
		var animation := player.get_animation(clip)
		var duration := animation.length
		var nominal: Variant = animation.get_meta("nominal_speed_m_s", -1.0)
		var changed := false
		for index in 12:
			var time := duration * (float(index) + 0.25) / 12.0
			var before := await sample(player, style, clip, time, false)
			var after := await sample(player, style, clip, time, true)
			if before.size() != skeleton.get_bone_count() or after.size() != skeleton.get_bone_count():
				check(false, "pose capture: " + clip)
				continue
			var sword_error := error(before[right], after[right])
			max_sword_error = maxf(max_sword_error, sword_error)
			check(sword_error < 0.00002, "sword trajectory preserved: " + clip)
			# Compare actual grip/tip positions as well as the complete hand transform.
			for endpoint in ([Vector3(0, 0.07, -0.12), Vector3(0, 0.07, -1.08)] if yixuan else [Vector3(0, 0.07, -0.111), Vector3(0, 0.07, -0.851422)]):
				check((before[right] * endpoint).distance_to(after[right] * endpoint) < 0.00002, "blade contact unchanged: " + clip)
			if clip in ["Idle", "Walk", "Run", "Walk_Backward", "Walk_Left", "Walk_Right"]:
				var foot_error := maxf(error(before[left_foot], after[left_foot]), error(before[right_foot], after[right_foot]))
				max_foot_error = maxf(max_foot_error, foot_error)
				check(foot_error < 0.00002, "gait foot placement preserved: " + clip)
			if clip == "Actions/CastEnergy":
				var cast_error := error(before[left], after[left])
				max_cast_error = maxf(max_cast_error, cast_error)
				check(cast_error < 0.00002, "cast origin preserved")
			changed = changed or error(before[expressive], after[expressive]) > 0.005
		check(changed, "visible graceful pose difference: " + clip)
		check(animation.length == duration and animation.get_meta("nominal_speed_m_s", -1.0) == nominal, "animation duration and gait speed unchanged: " + clip)
	check(body.get_node("CollisionShape3D").shape == original_shape and original_shape.radius == 0.5 and original_shape.height == 2.0, "body hitbox unchanged")
	check(movement == [body.walk_speed, body.run_speed, body.aim_step_run_speed, body.acceleration, body.deceleration, body.jump_velocity], "all movement speed parameters unchanged")
	check(combat == [attack.attack_range, attack.weapon_radius, attack.attack_damage, attack.ground_duration_s, attack.air_duration_s, attack.contact_start_phase, attack.contact_end_phase], "range damage timing and attack shape unchanged")
	style.active = true
	player.stop()
	body.traversal_motor.mode = 1
	var count: int = style.applied_count
	skeleton.advance(0.0)
	await process_frame
	check(style.applied_count == count, "parkour contact poses bypass styling")
	body.traversal_motor.mode = 0
	body.traversal_motor.wall_jump_elapsed = 0.0
	skeleton.advance(0.0)
	await process_frame
	check(style.applied_count == count, "wall-jump recovery bypasses styling")
	body.traversal_motor.reset()
	mesh.set_cosmetic_skin(0)
	await frames(3)
	check(mesh._model.find_child(prefix + "GracefulPose", true, false) == null, "default character has no skin-specific style")
	main.free()
	await process_frame
	print(prefix.to_upper(), "_GRACEFUL_CHECKS=", checks, " FAILURES=", failures, " SWORD_ERROR=", max_sword_error, " CAST_ERROR=", max_cast_error, " FOOT_ERROR=", max_foot_error)
	quit(0 if failures == 0 else 1)
