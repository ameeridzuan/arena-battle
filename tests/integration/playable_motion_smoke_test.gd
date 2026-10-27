extends SceneTree
## Main-only interactive motion harness; real physics, collision and cast release signals.
const MAIN := preload("res://scenes/main/Main.tscn")
const PLAYER := preload("res://scenes/characters/Player.tscn")
const MULTIPLAYER := preload("res://scenes/multiplayer/MultiplayerArena.tscn")
const TRIAL_ORIGIN := Vector3(-6, 1, -6)
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", label)

func _initialize() -> void:
	call_deferred("run")

func frames(count: int) -> void:
	for frame in count:
		await physics_frame
	await process_frame

func prepare_trial(body: CharacterBody3D, controls: Node) -> void:
	controls.cancel_motion()
	controls._cast_cooldown = 0.0
	controls._dodge_cooldown = 0.0
	body.get_node("CharacterAnimation").reset_presentation()
	body.camera_lock_behind = false
	body.global_position = TRIAL_ORIGIN
	body.velocity = Vector3.ZERO
	body.get_node("Mesh").rotation.y = 0.0
	await frames(8)

func run() -> void:
	var bare := PLAYER.instantiate()
	check(not bare.has_node("MotionTestControls"), "bare Player has no local harness")
	bare.free()
	var multiplayer := MULTIPLAYER.instantiate()
	check(multiplayer.find_children("MotionTestControls", "", true, false).is_empty(), "multiplayer scene has no local harness")
	multiplayer.free()
	var main := MAIN.instantiate()
	root.add_child(main)
	var body: CharacterBody3D = main.get_node("Player")
	var controls: Node = body.get_node_or_null("MotionTestControls")
	check(controls != null, "Main installs interactive motion controls")
	if controls == null:
		main.free()
		quit(1)
		return
	for name in ["Opponent1", "Opponent2"]:
		var attack: Node = main.get_node(name + "/AttackHitbox")
		attack.auto_attack = false
		attack.set_physics_process(false)
	var manager: Node = main.get_node("MatchManager")
	manager.set_physics_process(false)
	await frames(12)
	var driver: Node = body.get_node("CharacterAnimation")
	var mesh: Node3D = body.get_node("Mesh")
	var releases: Array = []
	var dodges: Array = []
	controls.cast_released.connect(func(origin: Vector3, direction: Vector3): releases.append([origin, direction]))
	controls.dodge_started.connect(func(direction: Vector3, clip: String): dodges.append([direction, clip]))
	check(body.is_on_floor(), "interactive fixture rests on collision floor")
	check(not controls.request_cast(), "cast rejected outside aim mode")
	body.camera_lock_behind = true
	Input.action_press("move_right")
	Input.action_press("run")
	await frames(12)
	var skeleton: Skeleton3D = body.find_children("*", "Skeleton3D", true, false)[0]
	var thigh := skeleton.find_bone("thigh.L")
	var leg_before := skeleton.get_bone_global_pose(thigh)
	var cast_start := body.global_position
	check(controls.request_cast(), "aim mode accepts local cast")
	check(not controls.request_cast(), "held/repeated cast cannot bypass cooldown")
	await frames(10)
	check(driver.get_action_clip() == "Actions/CastEnergy", "local cast drives layered presentation")
	check(driver.get_locomotion_clip() != "Idle" and not skeleton.get_bone_global_pose(thigh).is_equal_approx(leg_before), "legs continue animating during moving cast")
	await frames(14)
	check(releases.size() == 1 and controls._cast_cooldown > 0.0 and not controls.request_cast(), "released cast remains rate limited")
	var released_token: int = controls._cast_token
	controls._release_cast.call_deferred(released_token)
	controls._release_cast.call_deferred(released_token)
	await frames(1)
	check(releases.size() == 1, "duplicate queued release token cannot emit another bolt")
	await frames(50)
	Input.action_release("move_right")
	Input.action_release("run")
	check(releases.size() == 1, "one accepted cast emits exactly one release")
	if releases.size() == 1:
		var origin: Vector3 = releases[0][0]
		var direction: Vector3 = releases[0][1]
		check(origin.is_finite() and direction.is_finite() and is_equal_approx(direction.length(), 1.0), "cast origin and direction are finite and normalized")
	check(body.global_position.distance_to(cast_start) > 0.3, "cast permits real movement")
	check(body.get_health() == 100 and main.get_node("Opponent1/Health").get_health() == 100 and main.get_node("Opponent2/Health").get_health() == 100, "cast that misses targets causes no damage")
	# Four real cardinal moves use the mesh-local animation while travelling in world space.
	for trial in [[Vector3.BACK, "Dash_Forward"], [Vector3.FORWARD, "Dodge_Backward"], [Vector3.LEFT, "Dodge_Left"], [Vector3.RIGHT, "Dodge_Right"]]:
		await prepare_trial(body, controls)
		var start := body.global_position
		var before := dodges.size()
		check(controls.request_dodge(trial[0]), trial[1] + " accepted")
		check(dodges.size() == before + 1 and String(dodges[-1][1]).ends_with(trial[1]), trial[1] + " selects semantic clip")
		check(not controls.request_dodge(trial[0]), "repeated dodge cannot restart active travel")
		await frames(1)
		check((body.global_position - start).dot(trial[0]) > 0.015, trial[1] + " moves on the first physics frame")
		await frames(29)
		var travel := body.global_position - start
		travel.y = 0.0
		var minimum := 2.9 if trial[1] == "Dash_Forward" else 2.1
		var maximum := 3.9 if trial[1] == "Dash_Forward" else 2.9
		check(travel.dot(trial[0]) > minimum and travel.length() < maximum, trial[1] + " delivers responsive bounded travel")
		check((travel - trial[0] * travel.dot(trial[0])).length() < 0.15, trial[1] + " preserves requested travel direction")
		check(body.global_position.is_finite() and body.is_on_floor() and body.get_health() == 100, trial[1] + " keeps gravity and health intact")
		check(controls._dodge_cooldown > 0.0 and not controls.request_dodge(trial[0]), trial[1] + " cooldown outlasts active travel")
	await prepare_trial(body, controls)
	check(controls.request_dodge(), "stationary dodge accepts default backstep")
	check(String(dodges[-1][1]).ends_with("Dodge_Backward"), "no-direction dodge chooses backstep")
	body.apply_damage(5.0, main)
	check(body.get_health() == 95, "dodge grants no damage immunity")
	body.get_node("Health").reset()
	await frames(55)
	# A new solid wall must stop physical travel before the visual dodge finishes.
	await prepare_trial(body, controls)
	var wall := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.3, 4.0, 4.0)
	collision.shape = shape
	wall.add_child(collision)
	main.add_child(wall)
	wall.global_position = body.global_position + Vector3(1.5, 0.0, 0.0)
	await frames(3)
	var wall_start := body.global_position
	check(controls.request_dodge(Vector3.RIGHT), "wall-bound dodge starts")
	await frames(55)
	check(body.global_position.x > wall_start.x + 0.1 and body.global_position.x < wall_start.x + 1.3, "dodge stops at wall without tunnelling")
	wall.free()
	await prepare_trial(body, controls)
	body.camera_lock_behind = true
	var release_count := releases.size()
	check(controls.request_cast(), "cancel fixture starts cast")
	body.camera_lock_behind = false
	await frames(35)
	check(releases.size() == release_count, "leaving aim cancels unreleased cast")
	await prepare_trial(body, controls)
	body.camera_lock_behind = true
	check(controls.request_cast(), "focus fixture starts cast")
	controls.notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
	await frames(35)
	check(releases.size() == release_count, "focus loss cancels pending release")
	controls.notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_IN)
	await prepare_trial(body, controls)
	body.camera_lock_behind = true
	check(controls.request_cast(), "swap fixture starts cast")
	var previous_character: int = mesh.character
	controls.switch_character()
	await frames(35)
	check(mesh.character != previous_character and is_instance_valid(driver._anim), "character switch rebuilds usable animation binding")
	check(releases.size() == release_count, "character switch cancels old pending release")
	var feedback: Node = body.get_node("PlayerFeedback")
	var skins_valid: bool = not feedback._skin_meshes.is_empty()
	var saved_skin_materials: Array[Material] = []
	for skin in feedback._skin_meshes:
		skins_valid = skins_valid and is_instance_valid(skin)
		if is_instance_valid(skin):
			skins_valid = skins_valid and mesh._model.is_ancestor_of(skin)
			saved_skin_materials.append(skin.material_override)
	check(skins_valid, "feedback references only live meshes on the switched character")
	var saved_anchor_material: Material = mesh.material_override
	body.apply_damage(5.0, main)
	await frames(1)
	check(feedback._override_applied, "switched character receives nonlethal hurt flash")
	body.apply_damage(5.0, main)
	await frames(20)
	var restored: bool = not feedback._override_applied and mesh.material_override == saved_anchor_material
	for index in saved_skin_materials.size():
		restored = restored and is_instance_valid(feedback._skin_meshes[index]) and feedback._skin_meshes[index].material_override == saved_skin_materials[index]
	check(restored and body.get_health() == 90, "repeated hurt flashes restore switched model materials without stuck red")
	body.get_node("Health").reset()
	await prepare_trial(body, controls)
	body.camera_lock_behind = true
	body.external_control = true
	check(not controls.request_cast() and not controls.request_dodge(), "external bodies reject local harness requests")
	body.external_control = false
	body.set_physics_process(false)
	check(not controls.request_cast() and not controls.request_dodge(), "disabled bodies reject local harness requests")
	body.set_physics_process(true)
	var phase: int = manager.phase
	manager.phase = 2
	check(not controls.request_cast() and not controls.request_dodge(), "ended match rejects local harness requests")
	manager.phase = phase
	check(controls.request_cast(), "death fixture starts cast")
	body.apply_damage(100.0, main)
	await frames(35)
	check(releases.size() == release_count and not controls.request_cast() and not controls.request_dodge(), "death cancels pending release and rejects new motion")
	main.free()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	print("PLAYABLE_MOTION_CHECKS=", checks, " FAILURES=", failures, " ALL_TESTS_PASS=", failures == 0)
	quit(0 if failures == 0 else 1)
