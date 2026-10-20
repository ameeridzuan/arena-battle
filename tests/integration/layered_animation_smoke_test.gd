extends SceneTree
## Compare actual mixed bone poses against a locomotion-only reference on BOTH rigs.
const PLAYER := preload("res://scenes/characters/Player.tscn")
const ACTION := preload("res://scripts/player/animation_action.gd")
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

func run() -> void:
	for character in [0, 1]:
		var moving := fixture(character)
		var reference := fixture(character)
		var driver: Node = moving.get_node("CharacterAnimation")
		var baseline: Node = reference.get_node("CharacterAnimation")
		var skeleton: Skeleton3D = moving.find_children("*", "Skeleton3D", true, false)[0]
		var reference_skeleton: Skeleton3D = reference.find_children("*", "Skeleton3D", true, false)[0]
		check(driver._layers.mask_paths.size() >= 12, "rig-specific upper mask exists")
		for path in driver._layers.mask_paths:
			check(not String(path).ends_with(":hips") and not String(path).ends_with(":root"), "mask excludes root/pelvis")
		var original := moving.transform
		for velocity in [Vector3.ZERO, Vector3.BACK * 1.2, Vector3.BACK * 3.8, Vector3.RIGHT * 1.2, Vector3.FORWARD * 1.2]:
			for attack_index in range(4):
				driver.reset_presentation()
				baseline.reset_presentation()
				moving.velocity = velocity
				reference.velocity = velocity
				driver._physics_process(0.23)
				baseline._physics_process(0.23)
				driver._attack_index = attack_index
				driver._on_attack_started(Vector3.BACK)
				check(driver.get_action_clip() == driver.attack_animations[attack_index], "accepted action selects shared clip")
				var upper_changed := false
				var lower_equal := true
				var phase_equal := true
				var duration: float = driver._anim.get_animation(driver.get_action_clip()).length
				for frame in range(int(ceil(duration * 60.0)) + 12):
					driver._physics_process(1.0 / 60.0)
					baseline._physics_process(1.0 / 60.0)
					phase_equal = phase_equal and is_equal_approx(driver.get_locomotion_position(), baseline.get_locomotion_position())
					for bone_name in ["root", "hips", "thigh.L", "thigh.R", "shin.L", "shin.R", "foot.L", "foot.R"]:
						var bone := skeleton.find_bone(bone_name)
						lower_equal = lower_equal and skeleton.get_bone_global_pose(bone).is_equal_approx(reference_skeleton.get_bone_global_pose(bone))
					var arm := skeleton.find_bone("upper_arm.R")
					upper_changed = upper_changed or not skeleton.get_bone_pose(arm).is_equal_approx(reference_skeleton.get_bone_pose(arm))
				check(lower_equal, "legs match locomotion throughout attack and recovery")
				check(upper_changed, "upper body actually contributes attack pose")
				check(phase_equal, "attack never resets or pauses gait phase")
				check(not driver._attack_playing and driver.get_action_clip().is_empty(), "action ends independently of cadence")
				check(moving.velocity == velocity and moving.transform.is_equal_approx(original) and moving.get_node("Health").get_health() == 100, "presentation cannot move body or apply damage")
		# Movement changes during the same action, including air, must update the base.
		driver._on_attack_started(Vector3.BACK)
		for pair in [[Vector3.BACK * 3.8, "Run"], [Vector3.RIGHT * 1.2, "Walk_Right"], [Vector3.ZERO, "Idle"], [Vector3(0, 2, 0), "Jump"]]:
			moving.velocity = pair[0]
			driver._physics_process(0.016)
			check(driver.get_locomotion_clip() == pair[1], "locomotion changes beneath action")
		check(is_equal_approx(driver._layers.action_time, 0.064), "action clock ignores run/strafe/air cadence")
		# Explicit committed actions own the whole pose; lower priorities cannot replace them.
		var committed := ACTION.new()
		committed.clip = &"Attack_Overhead"
		committed.layer = ACTION.Layer.FULL_BODY
		committed.priority = 10
		check(driver._layers.start_action(committed), "explicit full-body override accepted")
		var light := ACTION.new()
		light.clip = &"Attack_Slash"
		check(not driver._layers.start_action(light), "lower priority cannot replace committed action")
		driver._physics_process(0.2)
		check(not driver._layers._overlay.filter_enabled and driver._layers.action_weight > 0, "full-body action owns all tracks")
		driver.reset_presentation()
		check(driver.get_action_clip().is_empty(), "explicit reset cancels full-body action")
		# Replicated death does not emit local died; health_changed must clear the mixer.
		driver._on_attack_started(Vector3.BACK)
		var health: Node = moving.get_node("Health")
		health.network_replica = true
		health.apply_network_state(0.0, 100.0)
		check(driver.get_action_clip().is_empty(), "replicated death immediately clears action")
		driver._on_attack_started(Vector3.BACK)
		check(driver.get_action_clip().is_empty(), "dead body cannot restart action")
		health.apply_network_state(100.0, 100.0)
		moving.velocity = Vector3.ZERO
		driver._physics_process(0.016)
		check(driver.get_locomotion_clip() == "Idle", "respawn begins neutral")
		# Reset while already targeting Idle must discard the previous blended run pose.
		moving.velocity = Vector3.BACK * 3.8
		driver._physics_process(0.2)
		moving.velocity = Vector3.ZERO
		driver._physics_process(0.016)
		driver.reset_presentation()
		baseline.reset_presentation()
		var reset_matches := true
		for bone in skeleton.get_bone_count():
			reset_matches = reset_matches and skeleton.get_bone_pose(bone).is_equal_approx(reference_skeleton.get_bone_pose(bone))
		check(reset_matches, "reset discards outgoing gait even during run-to-idle blend")
		# Gallery must give playback ownership to exactly one mixer at a time.
		driver.set_manual_preview(true)
		check(not driver._layers.tree.active, "manual review disables runtime tree")
		driver._anim.play("Walk")
		driver._anim.seek(0.2, true)
		driver.set_manual_preview(false)
		check(driver._layers.tree.active and not driver._anim.is_playing(), "runtime restoration stops raw player")
		var old_player: AnimationPlayer = driver._anim
		moving.get_node("Mesh").set_character(1 - character)
		driver._physics_process(0.016)
		check(driver._anim != old_player and driver._layers.mask_paths.size() >= 12, "model swap rebinds player and rig mask")
		moving.free()
		reference.free()
	var gallery: Node = load("res://scenes/characters/AnimationReviewGallery.tscn").instantiate()
	root.add_child(gallery)
	gallery.set_process(false)
	gallery._set_mode(gallery.MODES.size() + 1)
	gallery._set_paused(true)
	for slow_speed in [0.25, 0.5, 1.0]:
		gallery.playback_speed = slow_speed
		gallery._apply_playback()
		var gallery_driver: Node = gallery.bodies[0].get_node("CharacterAnimation")
		var before: float = gallery_driver._layers.action_time
		gallery._step()
		check(is_equal_approx(gallery_driver._layers.action_time - before, 1.0 / 30.0), "layered frame step remains one source frame at slow playback")
		check(gallery.paused and is_equal_approx(gallery_driver.playback_multiplier, slow_speed), "step retains pause and selected playback speed")
	gallery.free()
	print("LAYERED_CHECKS=", checks, " FAILURES=", failures, " ALL_TESTS_PASS=", failures == 0)
	quit(0 if failures == 0 else 1)
