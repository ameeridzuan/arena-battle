extends SceneTree
## Authored studies; forward dash adapts the accepted human Run capture. No armor simulation.
## Rebuilds separate rig libraries; original GLBs and gameplay transforms stay intact.
const PROFILES := preload("res://scripts/player/motion_profiles.gd")
const DIRECTIONS := {"Dash_Forward": Vector3.BACK, "Dodge_Backward": Vector3.FORWARD,
	"Dodge_Left": Vector3.LEFT, "Dodge_Right": Vector3.RIGHT}
const MODEL_NAMES := ["arclight", "ashen_warden"]

func _initialize() -> void:
	call_deferred("build")

func curve(time: float, times: Array, values: Array) -> float:
	for i in range(1, times.size()):
		if time <= float(times[i]):
			return lerpf(float(values[i-1]), float(values[i]), smoothstep(float(times[i-1]), float(times[i]), time))
	return float(values[-1])

func set_global(skeleton: Skeleton3D, bone: int, pose: Transform3D) -> void:
	var parent := skeleton.get_bone_parent(bone)
	var local := skeleton.get_bone_global_pose(parent).affine_inverse() * pose if parent >= 0 else pose
	skeleton.set_bone_pose_position(bone, local.origin)
	skeleton.set_bone_pose_rotation(bone, local.basis.get_rotation_quaternion().normalized())
	skeleton.set_bone_pose_scale(bone, local.basis.get_scale())

func rotate_global(skeleton: Skeleton3D, name: String, degrees: Vector3) -> void:
	var bone := skeleton.find_bone(name)
	var pose := skeleton.get_bone_global_pose(bone)
	pose.basis = Basis(Quaternion.from_euler(degrees * PI / 180.0)) * pose.basis
	set_global(skeleton, bone, pose)

func aim_bone(skeleton: Skeleton3D, bone: int, child: int, target: Vector3) -> void:
	var pose := skeleton.get_bone_global_pose(bone)
	var current := (pose.basis * skeleton.get_bone_pose_position(child)).normalized()
	var desired := (target - pose.origin).normalized()
	pose.basis = Basis(Quaternion(current, desired)) * pose.basis
	set_global(skeleton, bone, pose)

func solve_limb(skeleton: Skeleton3D, upper_name: String, middle_name: String,
		end_name: String, target: Vector3, bend_hint: Vector3) -> void:
	var upper := skeleton.find_bone(upper_name)
	var middle := skeleton.find_bone(middle_name)
	var end := skeleton.find_bone(end_name)
	var origin := skeleton.get_bone_global_pose(upper).origin
	var length_a := skeleton.get_bone_pose_position(middle).length()
	var length_b := skeleton.get_bone_pose_position(end).length()
	var direction := (target - origin).normalized()
	var distance := clampf(origin.distance_to(target), absf(length_a - length_b) + 0.001, (length_a + length_b) * 0.985)
	var along := (length_a * length_a - length_b * length_b + distance * distance) / (2.0 * distance)
	var height := sqrt(maxf(0.0, length_a * length_a - along * along))
	var perpendicular := (bend_hint - direction * bend_hint.dot(direction)).normalized()
	if perpendicular.length_squared() < 0.01:
		perpendicular = direction.cross(Vector3.RIGHT).normalized()
	var elbow := origin + direction * along + perpendicular * height
	aim_bone(skeleton, upper, middle, elbow)
	aim_bone(skeleton, middle, end, origin + direction * distance)

func sample_pose(skeleton: Skeleton3D, baseline: Array[Transform3D],
		neutral_global: Array[Transform3D], name: String, time: float, length: float, warden: bool) -> Array[Transform3D]:
	for bone in skeleton.get_bone_count():
		skeleton.set_bone_pose_position(bone, baseline[bone].origin)
		skeleton.set_bone_pose_rotation(bone, baseline[bone].basis.get_rotation_quaternion())
		skeleton.set_bone_pose_scale(bone, baseline[bone].basis.get_scale())
	var phase := time / length
	# Exact endpoints return the source Idle pose without an IK approximation.
	if (time > 0.00001 or name == "Parry_Success") and time < length - 0.00001:
		if name == "CastEnergy":
			var strength := curve(time, [0.0, 0.12, 0.22, 0.46, 0.68, 0.86], [0.0, 0.85, 1.0, 1.0, 0.6, 0.0])
			var release := curve(time, [0.0, 0.18, 0.34, 0.46, 0.64, 0.86], [0.0, 0.0, 1.0, 0.95, 0.15, 0.0])
			rotate_global(skeleton, "spine", Vector3(4.0 * release, -5.0 * (1.0 - release), 0.0) * strength)
			rotate_global(skeleton, "chest", Vector3(2.0 * release, 6.0 * release, 0.0) * strength)
			var shoulder := skeleton.get_bone_global_pose(skeleton.find_bone("upper_arm.L")).origin
			var reach := skeleton.get_bone_pose_position(skeleton.find_bone("forearm.L")).length() + skeleton.get_bone_pose_position(skeleton.find_bone("hand.L")).length()
			var side := signf(shoulder.x)
			var target := shoulder + Vector3(-side * reach * 0.15, reach * lerpf(-0.35, 0.02, release), reach * lerpf(0.25, 0.91, release))
			var neutral := neutral_global[skeleton.find_bone("hand.L")].origin
			target = neutral.lerp(target, strength)
			solve_limb(skeleton, "upper_arm.L", "forearm.L", "hand.L", target, Vector3(side * 0.7, -1.0, -0.2 if warden else 0.0))
			# The right hand retains its authored weapon grip; left hand casts.
			rotate_global(skeleton, "head", Vector3(-4.0 * release, -2.0 * release, 0.0) * strength)
		elif name.begins_with("Parry_"):
			var success := name == "Parry_Success"
			var strength := curve(phase, [0.0, 0.10, 0.45, 0.68, 1.0], [0.95, 1.0, 0.8, 0.45, 0.0]) if success else curve(time, [0.0, 0.04, 0.22, 0.34, length], [0.0, 1.0, 1.0, 0.5, 0.0])
			var recoil := curve(phase, [0.0, 0.18, 0.50, 1.0], [0.0, 1.0, 0.3, 0.0]) if success else 0.0
			rotate_global(skeleton, "spine", Vector3(-3.0 * strength - 8.0 * recoil, 0, 0))
			rotate_global(skeleton, "chest", Vector3(-2.0 * recoil, -8.0 * strength, 0))
			rotate_global(skeleton, "head", Vector3(4.0 * recoil, 4.0 * strength, 0))
			for suffix in [".L", ".R"]:
				var shoulder := skeleton.get_bone_global_pose(skeleton.find_bone("upper_arm" + suffix)).origin
				var side := signf(shoulder.x)
				var reach := skeleton.get_bone_pose_position(skeleton.find_bone("forearm" + suffix)).length() + skeleton.get_bone_pose_position(skeleton.find_bone("hand" + suffix)).length()
				var target := shoulder + Vector3(-side * reach * 0.35, -0.08 if suffix == ".L" else -0.15, reach * (0.60 if suffix == ".L" else 0.42) - recoil * 0.04)
				target = neutral_global[skeleton.find_bone("hand" + suffix)].origin.lerp(target, strength)
				solve_limb(skeleton, "upper_arm" + suffix, "forearm" + suffix, "hand" + suffix, target, Vector3(side, -0.3, -0.5))
		else:
			var direction: Vector3 = DIRECTIONS[name]
			var crouch := curve(phase, [0.0, 0.08, 0.24, 0.62, 0.84, 1.0], [0.0, 0.6, 0.75, 0.55, 0.4, 0.0])
			var lean := curve(phase, [0.0, 0.08, 0.24, 0.62, 0.88, 1.0], [0.0, 0.55, 1.0, 0.75, -0.1, 0.0])
			var stride := curve(phase, [0.0, 0.08, 0.28, 0.64, 0.88, 1.0], [0.0, 0.35, 1.0, 0.85, 0.25, 0.0])
			var lift := curve(phase, [0.0, 0.08, 0.28, 0.64, 0.84, 1.0], [0.0, 0.4, 1.0, 0.65, 0.0, 0.0])
			var hips := skeleton.find_bone("hips")
			var hip_pose := skeleton.get_bone_global_pose(hips)
			hip_pose.origin.y -= 0.08 * crouch
			set_global(skeleton, hips, hip_pose)
			var angles := Vector3(direction.z * 22.0, 0.0, -direction.x * 28.0) * lean
			rotate_global(skeleton, "hips", angles * 0.4)
			rotate_global(skeleton, "spine", angles * 0.5)
			rotate_global(skeleton, "chest", angles * 0.1)
			rotate_global(skeleton, "neck", -angles * 0.35)
			for suffix in [".L", ".R"]:
				var foot := skeleton.find_bone("foot" + suffix)
				var target := neutral_global[foot].origin
				var leading: bool = signf(target.x) == signf(direction.x) if absf(direction.x) > 0.5 else suffix == (".L" if direction.z > 0.0 else ".R")
				target += direction * (0.28 if leading else -0.16) * stride
				target.y += 0.09 * lift if leading else 0.02 * lift
				solve_limb(skeleton, "thigh" + suffix, "shin" + suffix, "foot" + suffix, target, Vector3.BACK)
				var ankle := skeleton.get_bone_global_pose(foot)
				ankle.basis = neutral_global[foot].basis
				set_global(skeleton, foot, ankle)
				var shoulder := skeleton.get_bone_global_pose(skeleton.find_bone("upper_arm" + suffix)).origin
				var side := signf(shoulder.x)
				var hand_target := shoulder + Vector3(side * 0.12, -0.28, 0.18) - direction * 0.06 * lean
				var hand := skeleton.find_bone("hand" + suffix)
				hand_target = neutral_global[hand].origin.lerp(hand_target, crouch * (0.8 if warden else 1.0))
				solve_limb(skeleton, "upper_arm" + suffix, "forearm" + suffix, "hand" + suffix, hand_target, Vector3(side, -1.0, 0.0))
	var result: Array[Transform3D] = []
	for bone in skeleton.get_bone_count():
		result.append(skeleton.get_bone_pose(bone))
	return result

func sample_dash(player: AnimationPlayer, skeleton: Skeleton3D,
		baseline: Array[Transform3D], time: float, length: float) -> Array[Transform3D]:
	# Reuse the accepted human run rather than stretching the old crouched dodge pose.
	for bone in skeleton.get_bone_count():
		skeleton.set_bone_pose_position(bone, baseline[bone].origin)
		skeleton.set_bone_pose_rotation(bone, baseline[bone].basis.get_rotation_quaternion())
		skeleton.set_bone_pose_scale(bone, baseline[bone].basis.get_scale())
	var phase := time / length
	var source := player.get_animation("DashSource/Run")
	player.play("DashSource/Run", 0.0)
	player.seek(source.length * phase * 0.90, true)
	player.pause()
	var weight := curve(phase, [0.0, 0.07, 0.70, 1.0], [0.0, 1.0, 1.0, 0.0])
	rotate_global(skeleton, "spine", Vector3(15.0, 0, 0) * weight)
	rotate_global(skeleton, "chest", Vector3(6.0, 0, 0) * weight)
	rotate_global(skeleton, "head", Vector3(-10.0, 0, 0) * weight)
	var result: Array[Transform3D] = []
	for bone in skeleton.get_bone_count():
		result.append(baseline[bone].interpolate_with(skeleton.get_bone_pose(bone), weight))
	return result

func build() -> void:
	DirAccess.make_dir_recursive_absolute("res://assets/animations/actions")
	var manifest := {"source": "Authored cast/dodge/parry; dash adapts accepted CMU Run capture with authored lean", "status": "blockout; visual approval pending", "rigs": {}}
	for model_name in MODEL_NAMES:
		var model: Node = load("res://assets/models/" + model_name + ".glb").instantiate()
		root.add_child(model)
		var player: AnimationPlayer = model.find_children("*", "AnimationPlayer", true, false)[0]
		var skeleton: Skeleton3D = model.find_children("*", "Skeleton3D", true, false)[0]
		player.play("Idle")
		player.seek(0.0, true)
		player.pause()
		var baseline: Array[Transform3D] = []
		var neutral_global: Array[Transform3D] = []
		for bone in skeleton.get_bone_count():
			baseline.append(skeleton.get_bone_pose(bone))
			neutral_global.append(skeleton.get_bone_global_pose(bone))
		var path := player.get_node(player.root_node).get_path_to(skeleton)
		player.add_animation_library("DashSource", load("res://assets/animations/locomotion/" + model_name + ".tres"))
		var library := AnimationLibrary.new()
		manifest.rigs[model_name] = {}
		for name in ["CastEnergy"] + DIRECTIONS.keys() + ["Parry_Attempt", "Parry_Success"]:
			var cast: bool = name == "CastEnergy"
			var parry: bool = name.begins_with("Parry_")
			var clip := Animation.new()
			clip.length = 0.86
			if parry:
				clip.length = PROFILES.PARRY_SUCCESS_DURATION if name == "Parry_Success" else PROFILES.PARRY_DURATION
			elif not cast:
				clip.length = float(PROFILES.evasion(name).duration)
			clip.loop_mode = Animation.LOOP_NONE
			clip.set_meta("presentation_only", true)
			clip.set_meta("source", "authored_blockout")
			var markers: Dictionary = {"anticipation": 0.18, "release": 0.34, "recovery": 0.56, "complete": clip.length} if cast else {"preload": 0.1152, "push": 0.2448, "brake": 0.5616, "complete": clip.length}
			if parry:
				markers = {"active_start": PROFILES.PARRY_START, "active_end": PROFILES.PARRY_END, "complete": clip.length} if name == "Parry_Attempt" else {"deflect": 0.04, "recover": 0.16, "complete": clip.length}
			elif not cast:
				markers = {"push": clip.length * 0.08, "travel": clip.length * 0.24, "brake": clip.length * 0.82, "complete": clip.length}
			if name == "Dash_Forward":
				clip.set_meta("source", "CMU Run with authored dash lean")
				clip.set_meta("source_capture", player.get_animation("DashSource/Run").get_meta("source_capture"))
			clip.set_meta("phase_markers", markers)
			if cast:
				clip.set_meta("release_time_s", 0.34)
				clip.set_meta("release_bone", "hand.L")
			elif not parry:
				clip.set_meta("direction_local", DIRECTIONS[name])
			var times: Array[float] = []
			for frame in range(int(ceil(clip.length * 30.0)) + 1):
				times.append(minf(float(frame) / 30.0, clip.length))
			for marker in markers.values():
				if not times.has(float(marker)): times.append(float(marker))
			times.sort()
			var samples: Array = []
			for time in times:
				if name == "Dash_Forward":
					samples.append(sample_dash(player, skeleton, baseline, time, clip.length))
				else:
					samples.append(sample_pose(skeleton, baseline, neutral_global, name, time, clip.length, model_name == "ashen_warden"))
			for bone in skeleton.get_bone_count():
				var bone_path := NodePath(str(path) + ":" + skeleton.get_bone_name(bone))
				for type in [Animation.TYPE_ROTATION_3D, Animation.TYPE_POSITION_3D, Animation.TYPE_SCALE_3D]:
					var track := clip.add_track(type)
					clip.track_set_path(track, bone_path)
					for k in times.size():
						var pose: Transform3D = samples[k][bone]
						match type:
							Animation.TYPE_ROTATION_3D: clip.rotation_track_insert_key(track, times[k], pose.basis.get_rotation_quaternion().normalized())
							Animation.TYPE_POSITION_3D: clip.position_track_insert_key(track, times[k], pose.origin)
							Animation.TYPE_SCALE_3D: clip.scale_track_insert_key(track, times[k], pose.basis.get_scale())
			library.add_animation(name, clip)
			manifest.rigs[model_name][name] = {"duration": clip.length, "layer": "upper_body" if cast or parry else "full_body", "movement": "free_locomotion" if cast or parry else "external_authority_required", "source": clip.get_meta("source"), "markers_visual_only": markers, "release_bone": "hand.L" if cast else "", "loop": false}
		var error := ResourceSaver.save(library, "res://assets/animations/actions/" + model_name + ".tres")
		if error != OK:
			printerr("Cannot save action library: ", error)
			quit(1)
			return
		model.free()
	FileAccess.open("res://assets/animations/actions/manifest.json", FileAccess.WRITE).store_string(JSON.stringify(manifest, "\t"))
	print("CAST_DODGE_BUILT rigs=2 clips_per_rig=7")
	quit()
