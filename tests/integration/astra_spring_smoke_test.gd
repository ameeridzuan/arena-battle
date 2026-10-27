extends SceneTree
const MAIN := preload("res://scenes/main/Main.tscn")
var checks := 0
var failures := 0
var samples := 0
var hair_angle := 0.0
var cloth_angle := 0.0
var skeleton: Skeleton3D
var finite_poses := true
var yixuan := "--yixuan" in OS.get_cmdline_user_args()
var prefix := "Yixuan" if yixuan else "Astra"
var local_rotations: Dictionary = {}

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	print("CHECK ", label, " = ", ok)
	if not ok:
		failures += 1

func frames(count: int) -> void:
	for i in count:
		await physics_frame
	await process_frame

func observe() -> void:
	samples += 1
	for bone in skeleton.get_bone_count():
		var pose := skeleton.get_bone_pose(bone)
		local_rotations[bone] = pose.basis.get_rotation_quaternion()
		finite_poses = finite_poses and pose.is_finite()
		var name := String(skeleton.get_bone_name(bone))
		var angle := pose.basis.get_rotation_quaternion().angle_to(skeleton.get_bone_rest(bone).basis.get_rotation_quaternion())
		if name.begins_with(prefix + "Hair_"):
			hair_angle = maxf(hair_angle, angle)
		elif name.begins_with(prefix + "Skirt_") or name.begins_with(prefix + "Sleeve_"):
			cloth_angle = maxf(cloth_angle, angle)

func run() -> void:
	var main := MAIN.instantiate()
	root.add_child(main)
	main.get_node("MatchManager").set_physics_process(false)
	for name in ["Opponent1", "Opponent2"]:
		main.get_node(name + "/AttackHitbox").set_physics_process(false)
	await frames(8)
	var body: CharacterBody3D = main.get_node("Player")
	if yixuan:
		body.get_node("MotionTestControls").switch_character()
	body.get_node("MotionTestControls").switch_skin()
	await frames(8)
	var mesh: Node = body.get_node("Mesh")
	var motion: Node = mesh._model.get_node(prefix + "SpringMotion")
	var sim: SpringBoneSimulator3D = motion.simulator
	skeleton = motion.skeleton
	check(skeleton.get_bone_count() == (207 if yixuan else 222), "hair/clothing bones retained beside gameplay bones")
	check(motion.chain_count > 20, "native spring chains configured")
	check(sim.get_child_count() == 4, "head torso and thigh collision shapes")
	check(sim.get_index() == skeleton.get_child_count() - 2 and motion.limiter.get_index() == skeleton.get_child_count() - 1, "springs and limits run after terrain and traversal modifiers")
	var covered := {}
	var only_secondary := true
	for chain in sim.setting_count:
		for joint in sim.get_joint_count(chain):
			var bone := sim.get_joint_bone(chain, joint)
			# An extended end is virtual and may have no bone.
			if bone >= 0:
				only_secondary = only_secondary and motion._is_secondary(bone)
				covered[bone] = true
	check(only_secondary, "spring solver never owns gameplay bones")
	check(covered.size() == (181 if yixuan else 202), "all restored secondary bones belong to chains")
	var has_hair_weights := false
	var has_cloth_weights := false
	var surface: MeshInstance3D = mesh._model.find_child("YixuanBody" if yixuan else "AstraYaoBody", true, false)
	for part in surface.mesh.get_surface_count():
		var arrays := surface.mesh.surface_get_arrays(part)
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		for i in bones.size():
			if weights[i] <= 0.0:
				continue
			var slot := bones[i]
			var bone := surface.skin.get_bind_bone(slot)
			if bone < 0:
				bone = skeleton.find_bone(surface.skin.get_bind_name(slot))
			var label := String(skeleton.get_bone_name(bone))
			has_hair_weights = has_hair_weights or label.begins_with(prefix + "Hair_")
			has_cloth_weights = has_cloth_weights or label.begins_with(prefix + "Skirt_") or label.begins_with(prefix + "Sleeve_")
	check(has_hair_weights and has_cloth_weights, "rendered mesh has real spring-bone weights")
	motion.limiter.modification_processed.connect(observe)
	var origin := body.position
	body.set_physics_process(false)
	for i in 90:
		body.position = origin + Vector3(sin(float(i) * 0.10) * 0.24, 0, 0)
		await physics_frame
	body.position = origin
	if yixuan:
		# Settling is measured with fixed primary bones, not a breathing/turning idle pose.
		var driver: Node = body.get_node("CharacterAnimation")
		driver.set_manual_preview(true)
		driver._anim.play("Idle")
		driver._anim.seek(0.2, true)
		driver._anim.pause()
		motion.graceful_pose.active = false
	await frames(90)
	check(samples > 30, "native simulation advances over time")
	check(hair_angle > 0.01 and cloth_angle > 0.01, "hair and cloth visibly respond to motion")
	check(finite_poses, "spring poses remain finite under motion and settling")
	check(hair_angle <= deg_to_rad(32.1) and cloth_angle <= deg_to_rad(40.1), "hair and cloth swings stay within silhouette limits")
	if yixuan:
		check(motion.wind_strength == 0.0, "Yixuan has no artificial wind flutter")
		var damped := true
		for chain in sim.setting_count:
			damped = damped and sim.get_drag(chain) >= 0.85 and sim.get_radius(chain) <= 0.0041
		check(damped, "dense Yixuan chains use high damping and small collision radii")
		check(hair_angle <= deg_to_rad(4.6) and cloth_angle <= deg_to_rad(4.6), "Yixuan bends stay far below previous 32/40 degree swings")
		var settled := local_rotations.duplicate()
		await frames(30)
		var residual := 0.0
		for bone in motion.limiter.bounded_bones:
			var a: Quaternion = settled[bone]
			residual = maxf(residual, a.angle_to(local_rotations[bone]))
		check(residual < deg_to_rad(1.0), "hair and cloth settle without persistent shaking")
		var bone: int = motion.limiter.bounded_bones[0]
		var filtered: Quaternion = motion.limiter._filtered[bone]
		skeleton.set_bone_pose_rotation(bone, Quaternion(Vector3.RIGHT, 1.0))
		motion.limiter._process_modification_with_delta(0.0)
		check(skeleton.get_bone_pose_rotation(bone).is_equal_approx(filtered), "zero-time pose refresh does not advance spring smoothing")
		print("YIXUAN_SETTLED_DRIFT_DEGREES=", rad_to_deg(residual))
	var before_reset: int = motion.reset_count
	body.position += Vector3(8, 0, 0)
	await frames(3)
	check(motion.reset_count > before_reset, "teleport resets inertia")
	var sun: DirectionalLight3D = main.get_node("Arena/DirectionalLight3D")
	var environment: Environment = main.get_node("Arena/WorldEnvironment").environment
	check(sun.light_color.r > sun.light_color.g and sun.light_color.g > sun.light_color.b and sun.rotation_degrees.x < 0, "warm sunlight shines down onto character")
	check(environment.ambient_light_energy < 0.5, "ambient fill preserves warm sun contrast")
	mesh.set_cosmetic_skin(0)
	await frames(3)
	check(mesh._model.find_child(prefix + "SpringMotion", true, false) == null, "switching skin cleans up simulation")
	print(prefix.to_upper(), "_SPRING_CHECKS=", checks, " FAILURES=", failures, " SAMPLES=", samples, " HAIR_ANGLE=", hair_angle, " CLOTH_ANGLE=", cloth_angle)
	main.free()
	quit(0 if failures == 0 else 1)
