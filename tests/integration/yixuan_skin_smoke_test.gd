extends SceneTree
const MAIN := preload("res://scenes/main/Main.tscn")
const STATE := preload("res://scripts/multiplayer/network_motion_state.gd")
var checks := 0
var failures := 0

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
	var weapon: Node = body.get_node("AttackHitbox")
	var shape: Shape3D = body.get_node("CollisionShape3D").shape
	var speed := [body.walk_speed, body.run_speed, body.acceleration, body.jump_velocity]
	controls.switch_skin()
	await frames(3)
	var astra_player: AnimationPlayer = driver._anim
	var astra_clips := {}
	for clip in ["Idle", "Walk", "Run", "Jump", "Walk_Backward", "Walk_Left", "Walk_Right", "Attack_Slash", "Attack_Backhand", "Attack_Overhead", "Attack_Thrust", "Actions/CastEnergy", "Actions/Dash_Forward", "Actions/Parry_Attempt"]:
		astra_clips[clip] = astra_player.get_animation(clip).duplicate(true)
	controls.switch_character()
	await frames(3)
	check(mesh.character == 1 and mesh.cosmetic_skin == 0, "Warden initially keeps default skin")
	var segment: Array = weapon.get_weapon_segment()
	var blade_length: float = segment[0].distance_to(segment[1])
	controls.switch_skin()
	await frames(5)
	check(mesh.character == 1 and mesh.cosmetic_skin == 2, "Yixuan belongs to Warden")
	check(mesh.get_display_name() == "Yixuan (Ashen Warden)", "Yixuan display name")
	check(mesh._model.find_child("YixuanBody", true, false) != null, "supplied body loaded")
	var motion: Node = mesh._model.get_node("YixuanSpringMotion")
	check(motion.skeleton.get_bone_count() == 207 and motion.chain_count > 10, "weighted hair and clothing springs configured")
	check(motion.graceful_pose.get_script() == preload("res://scripts/player/astra_graceful_pose.gd"), "same graceful pose script as Astra")
	var skeleton: Skeleton3D = motion.skeleton
	for clip: String in astra_clips:
		check(driver._anim.has_animation(clip), "Yixuan clip: " + clip)
		var animation: Animation = driver._anim.get_animation(clip)
		var source: Animation = astra_clips[clip]
		var identical := animation.length == source.length
		for track in source.get_track_count():
			if source.track_get_type(track) != Animation.TYPE_ROTATION_3D:
				continue
			var bone_name := String(source.track_get_path(track).get_subname(0))
			var target := animation.find_track(NodePath("AshenWardenRig/Skeleton3D:" + bone_name), Animation.TYPE_ROTATION_3D)
			if target < 0 or source.track_get_key_count(track) != animation.track_get_key_count(target):
				identical = false
				continue
			for key in source.track_get_key_count(track):
				var a: Quaternion = source.track_get_key_value(track, key)
				var b: Quaternion = animation.track_get_key_value(target, key)
				identical = identical and a.is_equal_approx(b) and source.track_get_key_time(track, key) == animation.track_get_key_time(target, key)
		check(identical, "Astra animation rotations and timing match: " + clip)
		for track in animation.get_track_count():
			var path := animation.track_get_path(track)
			check(String(path).begins_with("AshenWardenRig/Skeleton3D:"), "animation bound to Warden skeleton")
	var yixuan_segment: Array = weapon.get_weapon_segment()
	check(absf(yixuan_segment[0].distance_to(yixuan_segment[1]) - blade_length) < 0.00002, "Warden longsword length retained")
	check(body.get_node("CollisionShape3D").shape == shape and shape.radius == 0.5 and shape.height == 2.0, "same body hitbox")
	check(speed == [body.walk_speed, body.run_speed, body.acceleration, body.jump_velocity], "movement speed unchanged")
	var state: Dictionary = bytes_to_var(var_to_bytes(STATE.capture(body)))
	check(state.character == 1 and state.skin == 2, "snapshot identifies Yixuan independently")
	controls.switch_skin()
	await frames(3)
	check(mesh.cosmetic_skin == 0 and mesh.get_display_name() == "Ashen Warden", "toggle back to Warden")
	STATE.apply(body, state)
	await frames(3)
	check(mesh.cosmetic_skin == 2 and mesh._model.find_child("YixuanBody", true, false) != null, "snapshot restores Yixuan")
	controls.switch_character()
	await frames(3)
	check(mesh.character == 0 and mesh.cosmetic_skin == 1, "Arclight remembers Astra")
	controls.switch_character()
	await frames(3)
	check(mesh.character == 1 and mesh.cosmetic_skin == 2, "Warden remembers Yixuan")
	mesh.set_appearance(0, 2)
	check(mesh.character == 1 and mesh.cosmetic_skin == 2, "wrong character-skin pair rejected")
	var enemy: Node3D = main.get_node("Opponent1")
	enemy.position = body.position + Vector3.BACK * 1.1
	enemy.rotation = Vector3.ZERO
	body.get_node("Mesh").rotation.y = 0.0
	check(weapon.request_attack(), "Yixuan accepts melee attack")
	await frames(45)
	check(enemy.get_node("Health").get_health() == 75.0, "Yixuan longsword deals 25 damage once")
	main.free()
	await process_frame
	print("YIXUAN_SKIN_CHECKS=", checks, " FAILURES=", failures)
	quit(0 if failures == 0 else 1)
