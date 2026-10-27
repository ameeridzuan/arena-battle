extends SceneTree
## Actual mixed poses on both rigs; cosmetic fixtures cannot award movement or damage.
const PLAYER := preload("res://scenes/characters/Player.tscn")
const ACTIONS := preload("res://scripts/player/action_library.gd")
const ACTION := preload("res://scripts/player/animation_action.gd")
const EVADES := ["Dash_Forward", "Dodge_Backward", "Dodge_Left", "Dodge_Right"]
const IDS := ["CastEnergy", "Dash_Forward", "Dodge_Backward", "Dodge_Left", "Dodge_Right", "Parry_Attempt", "Parry_Success"]
const LOWER := ["root", "hips", "thigh.L", "thigh.R", "shin.L", "shin.R", "foot.L", "foot.R"]
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", label)

func _initialize() -> void:
	call_deferred("run")

func fixture(character: int) -> CharacterBody3D:
	var body: CharacterBody3D = PLAYER.instantiate()
	body.external_control = true
	body.get_node("Combatant").free()
	body.get_node("Mesh").character = character
	body.get_node("AttackHitbox").external_control = true
	body.get_node("CameraPivot").local_input_enabled = false
	root.add_child(body)
	body.set_physics_process(false)
	body.get_node("CharacterAnimation").set_physics_process(false)
	body.get_node("AttackHitbox").set_physics_process(false)
	return body

func world_bone(skeleton: Skeleton3D, name: String) -> Vector3:
	return skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone(name)).origin

func same_lower(first: Skeleton3D, second: Skeleton3D) -> bool:
	for name in LOWER:
		if not first.get_bone_global_pose(first.find_bone(name)).is_equal_approx(second.get_bone_global_pose(second.find_bone(name))):
			return false
	return true

func finite_pose(skeleton: Skeleton3D) -> bool:
	for bone in skeleton.get_bone_count():
		if not skeleton.get_bone_pose(bone).is_finite():
			return false
	return true

func run() -> void:
	check(ACTIONS.definition("UnknownAction") == null, "unknown action has no presentation definition")
	for character in [0, 1]:
		var moving := fixture(character)
		var reference := fixture(character)
		var driver: Node = moving.get_node("CharacterAnimation")
		var baseline: Node = reference.get_node("CharacterAnimation")
		var player: AnimationPlayer = driver._anim
		var skeleton: Skeleton3D = moving.find_children("*", "Skeleton3D", true, false)[0]
		var reference_skeleton: Skeleton3D = reference.find_children("*", "Skeleton3D", true, false)[0]
		var mesh: Node3D = moving.get_node("Mesh")
		var animation_root := player.get_node(player.root_node)
		var original := moving.transform
		for id in IDS:
			var spec: Resource = ACTIONS.definition(id)
			check(spec != null and player.has_animation(spec.clip), str(character) + " semantic clip installed: " + id)
			if spec == null or not player.has_animation(spec.clip):
				continue
			var clip: Animation = player.get_animation(spec.clip)
			check(clip.loop_mode == Animation.LOOP_NONE and clip.length > 0, id + " is a finite one-shot")
			check(bool(clip.get_meta("presentation_only", false)), id + " explicitly cosmetic")
			check(spec.layer == (ACTION.Layer.UPPER_BODY if id == "CastEnergy" or id.begins_with("Parry_") else ACTION.Layer.FULL_BODY), id + " layer ownership")
			var paths_valid := clip.get_track_count() > 0
			var transforms_only := true
			for track in clip.get_track_count():
				transforms_only = transforms_only and clip.track_get_type(track) in [Animation.TYPE_POSITION_3D, Animation.TYPE_ROTATION_3D, Animation.TYPE_SCALE_3D]
				var path := clip.track_get_path(track)
				var target := animation_root.get_node_or_null(NodePath(path.get_concatenated_names()))
				paths_valid = paths_valid and target is Skeleton3D and path.get_subname_count() == 1
				if target is Skeleton3D and path.get_subname_count() == 1:
					paths_valid = paths_valid and target.find_bone(path.get_subname(0)) >= 0
			check(paths_valid, id + " every track resolves against this rig")
			check(transforms_only, id + " has no method or effect tracks")
			if id == "CastEnergy":
				var release: float = clip.get_meta("release_time_s", -1.0)
				check(release > 0 and release < clip.length and is_equal_approx(release, 0.34), "cast release marker within clip")
			elif id in EVADES:
				var direction: Vector3 = clip.get_meta("direction_local", Vector3.ZERO)
				var expected: Vector3 = {"Dash_Forward": Vector3.BACK, "Dodge_Backward": Vector3.FORWARD, "Dodge_Left": Vector3.LEFT, "Dodge_Right": Vector3.RIGHT}[id]
				check(direction.is_equal_approx(expected), id + " direction metadata uses mesh-local convention")
		# Reuse exactly one cast over all five movement states, with real FK pose comparisons.
		for velocity in [Vector3.ZERO, Vector3.BACK * 1.2, Vector3.BACK * 3.8, Vector3.RIGHT * 1.2, Vector3.FORWARD * 1.2]:
			driver.reset_presentation()
			baseline.reset_presentation()
			moving.velocity = velocity
			reference.velocity = velocity
			driver._physics_process(0.23)
			baseline._physics_process(0.23)
			var spec: Resource = ACTIONS.definition("CastEnergy")
			check(driver.present_action(spec), "cast accepted over velocity " + str(velocity))
			var lower_equal := true
			var phase_equal := true
			var upper_changed := false
			var finite := true
			var duration: float = player.get_animation(spec.clip).length
			for frame in range(int(ceil(duration * 60.0)) + 12):
				driver._physics_process(1.0 / 60.0)
				baseline._physics_process(1.0 / 60.0)
				lower_equal = lower_equal and same_lower(skeleton, reference_skeleton)
				phase_equal = phase_equal and is_equal_approx(driver.get_locomotion_position(), baseline.get_locomotion_position())
				var arm := skeleton.find_bone("upper_arm.L")
				upper_changed = upper_changed or not skeleton.get_bone_pose(arm).is_equal_approx(reference_skeleton.get_bone_pose(arm))
				finite = finite and finite_pose(skeleton)
			check(lower_equal and phase_equal, "cast preserves legs and uninterrupted gait phase")
			check(upper_changed and finite, "cast contributes finite upper-body motion")
			check(driver.get_action_clip().is_empty(), "cast naturally finishes")
			check(moving.transform.is_equal_approx(original) and moving.velocity == velocity and moving.get_health() == 100, "cast has no movement or damage authority")
		# Inspect the actual release silhouette in world space, independent of rig basis.
		driver.reset_presentation()
		moving.velocity = Vector3.ZERO
		driver._physics_process(0.2)
		var cast: Resource = ACTIONS.definition("CastEnergy")
		driver.present_action(cast)
		driver._physics_process(0.12)
		var anticipation := world_bone(skeleton, "hand.L")
		var release_time: float = player.get_animation(cast.clip).get_meta("release_time_s")
		driver._physics_process(release_time - 0.12)
		var release_hand := world_bone(skeleton, "hand.L")
		check((release_hand - anticipation).dot(mesh.global_basis.z.normalized()) > 0.08, "left casting hand extends toward mesh-forward release")
		check(release_hand.y > world_bone(skeleton, "hips").y, "casting palm releases above the waist")
		for id in ["Parry_Attempt", "Parry_Success"]:
			driver.reset_presentation()
			baseline.reset_presentation()
			moving.velocity = Vector3.RIGHT * 1.2
			reference.velocity = moving.velocity
			driver._physics_process(0.23)
			baseline._physics_process(0.23)
			var spec: Resource = ACTIONS.definition(id)
			check(driver.present_action(spec), id + " preview enters upper-body ownership")
			var lower_equal := true
			var upper_changed := false
			var finite := true
			var duration: float = player.get_animation(spec.clip).length
			for frame in range(int(ceil(duration * 60.0)) + 12):
				driver._physics_process(1.0 / 60.0)
				baseline._physics_process(1.0 / 60.0)
				lower_equal = lower_equal and same_lower(skeleton, reference_skeleton) and is_equal_approx(driver.get_locomotion_position(), baseline.get_locomotion_position())
				for bone_name in ["spine", "upper_arm.L", "upper_arm.R", "forearm.L", "forearm.R"]:
					var bone := skeleton.find_bone(bone_name)
					upper_changed = upper_changed or not skeleton.get_bone_pose(bone).is_equal_approx(reference_skeleton.get_bone_pose(bone))
				finite = finite and finite_pose(skeleton)
			check(lower_equal and upper_changed and finite, id + " actual upper pose preserves moving legs")
			check(driver.get_action_clip().is_empty() and moving.transform.is_equal_approx(original) and moving.get_health() == 100, id + " preview ends without awarding effects")
		for id in EVADES:
			driver.reset_presentation()
			baseline.reset_presentation()
			moving.velocity = Vector3.BACK * 1.2
			reference.velocity = moving.velocity
			driver._physics_process(0.23)
			baseline._physics_process(0.23)
			var spec: Resource = ACTIONS.definition(id)
			check(driver.present_action(spec), id + " full-body presentation starts")
			var clip: Animation = player.get_animation(spec.clip)
			var direction: Vector3 = clip.get_meta("direction_local")
			var direction_world := (mesh.global_basis * direction).normalized()
			var lower_changed := false
			var max_lean := -INF
			var finite := true
			var phase_equal := true
			for frame in range(int(ceil(clip.length * 60.0)) + 12):
				driver._physics_process(1.0 / 60.0)
				baseline._physics_process(1.0 / 60.0)
				lower_changed = lower_changed or not same_lower(skeleton, reference_skeleton)
				var lean := world_bone(skeleton, "chest") - world_bone(skeleton, "hips")
				var neutral := world_bone(reference_skeleton, "chest") - world_bone(reference_skeleton, "hips")
				max_lean = maxf(max_lean, (lean - neutral).dot(direction_world))
				finite = finite and finite_pose(skeleton)
				phase_equal = phase_equal and is_equal_approx(driver.get_locomotion_position(), baseline.get_locomotion_position())
			check(lower_changed and finite, id + " visibly owns finite lower-body motion")
			check(max_lean > 0.015, id + " torso leans in semantic travel direction")
			check(phase_equal and same_lower(skeleton, reference_skeleton), id + " resumes uninterrupted underlying gait")
			check(driver.get_action_clip().is_empty(), id + " clears full-body ownership")
			check(moving.transform.is_equal_approx(original) and moving.velocity == reference.velocity and moving.get_health() == 100, id + " cannot grant displacement or damage")
		check(not driver.present_action(ACTIONS.definition("UnknownAction")), "runtime rejects an unknown action definition")
		driver.set_manual_preview(true)
		check(not driver.present_action(ACTIONS.definition("CastEnergy")), "raw preview rejects runtime action ownership")
		driver.set_manual_preview(false)
		moving.get_node("Health").network_replica = true
		driver.present_action(ACTIONS.definition("Dash_Forward"))
		moving.get_node("Health").apply_network_state(0, 100)
		check(driver.get_action_clip().is_empty(), "replicated death clears dodge")
		check(not driver.present_action(ACTIONS.definition("CastEnergy")), "dead character rejects cast")
		moving.free()
		reference.free()
	# Every new review entry uses the same action graph, with fixed-source frame stepping.
	var gallery = load("res://scenes/characters/AnimationReviewGallery.tscn").instantiate()
	root.add_child(gallery)
	gallery.set_process(false)
	gallery.playback_speed = 0.25
	for index in gallery.ACTION_PREVIEWS.size():
		var entry: Dictionary = gallery.ACTION_PREVIEWS[index]
		gallery._set_mode(gallery.MODES.size() + gallery.MOVING_ACTION_MODES.size() + index)
		gallery._set_paused(true)
		var originals: Array[Transform3D] = []
		for body in gallery.bodies:
			originals.append(body.transform)
		gallery._step()
		check(gallery.paused, entry.label + " stepping remains paused")
		for body_index in gallery.bodies.size():
			var body: CharacterBody3D = gallery.bodies[body_index]
			var driver: Node = body.get_node("CharacterAnimation")
			var expected: Resource = ACTIONS.definition(entry.action)
			check(driver.get_action_clip() == String(expected.clip), entry.label + " gallery presents expected action on both rigs")
			check(is_equal_approx(driver._layers.action_time, 1.0 / 30.0), entry.label + " slow-motion step advances one source frame")
			check(driver._layers.tree.active and not driver._anim.is_playing(), entry.label + " graph has sole runtime ownership")
			check(body.transform.is_equal_approx(originals[body_index]) and body.get_health() == 100 and not body.has_node("Combatant"), entry.label + " preview remains isolated")
	gallery._set_mode(1)
	gallery._set_paused(true)
	for body in gallery.bodies:
		var driver: Node = body.get_node("CharacterAnimation")
		check(not driver._layers.tree.active and driver.get_action_clip().is_empty() and driver._anim.current_animation == "Idle", "raw gallery mode clears action and disables mixer")
	gallery._set_mode(0)
	gallery._set_paused(true)
	for body in gallery.bodies:
		var driver: Node = body.get_node("CharacterAnimation")
		check(driver._layers.tree.active and not driver._anim.is_playing() and driver.get_action_clip().is_empty(), "return to automatic mode restores sole graph ownership")
	gallery.free()
	print("CAST_DODGE_CHECKS=", checks, " FAILURES=", failures, " ALL_TESTS_PASS=", failures == 0)
	quit(0 if failures == 0 else 1)
