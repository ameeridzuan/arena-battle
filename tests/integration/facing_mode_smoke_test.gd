extends SceneTree
## M6 facing-mode smoke test (single-player), updated for option A.
##
## Option A (default): the character faces its MOVEMENT direction and the melee swing travels
## along the Mesh front (+Z) — i.e. the attack always follows where the character faces. The
## "toggle_face_aim" action (key V) flips to option B, where the Mesh tracks the camera-aim
## (camera yaw + PI); because the attack follows the Mesh, B makes the attack follow the aim.
## Proven here:
##   * default is option A (face_aim_always == false);
##   * the swing direction equals the Mesh front, independent of the camera (attack_started forward);
##   * the toggle key flips face_aim_always and B tracks the camera-aim every physics frame;
##   * in B the swing direction equals the aim (Mesh front == camera-forward).
##
## Run: Godot_v4.7.2-stable_win64_console.exe --headless --path . ^
##        --script res://tests/integration/facing_mode_smoke_test.gd
## Exit 0 = all checks passed, 1 = at least one failed.

const MAIN := preload("res://scenes/main/Main.tscn")

var _results: Array[bool] = []


func _init() -> void:
	_run()


func _check(label: String, passed: bool) -> void:
	print("CHECK ", label, " = ", passed)
	_results.append(passed)


func _frames(count: int) -> void:
	for _i in count:
		await physics_frame


func _wrap(angle: float) -> float:
	return wrapf(angle, -PI, PI)


## Presses the toggle action and lets player_controller._physics_process observe the edge.
func _press_toggle() -> void:
	Input.action_press("toggle_face_aim")
	await _frames(3)
	Input.action_release("toggle_face_aim")
	await _frames(2)


func _run() -> void:
	var main: Node = MAIN.instantiate()
	root.add_child(main)
	await _frames(6)

	# Script members are not visible through a typed CharacterBody3D handle; use a dynamic one.
	var player: Variant = main.get_node("Player")
	var cam: Node3D = main.get_node("Player/CameraPivot")
	var mesh: Node3D = main.get_node("Player/Mesh")
	var hitbox: Variant = main.get_node("Player/AttackHitbox")

	_check("default_mode_is_A_movement", player.face_aim_always == false)

	# Option A core: the swing direction is the Mesh front (+Z), independent of the camera.
	var captured: Array = [Vector3.ZERO]
	hitbox.attack_started.connect(func(f: Vector3): captured[0] = f)
	mesh.rotation.y = 0.7
	await _frames(1)
	hitbox._perform_attack()
	_check("A_attack_follows_mesh_facing",
			captured[0].distance_to(Vector3(sin(0.7), 0.0, cos(0.7))) < 0.001)

	# Toggle key -> option B (face the camera-aim).
	await _press_toggle()
	_check("toggle_key_enables_B", player.face_aim_always == true)

	# Option B: the mesh tracks camera-aim every frame, regardless of movement.
	cam.rotation.y = 1.1
	await _frames(2)
	_check("B_faces_camera_aim", is_equal_approx(_wrap(mesh.rotation.y), _wrap(cam.rotation.y + PI)))

	# Because the swing follows the Mesh, in B the attack direction equals the aim.
	captured[0] = Vector3.ZERO
	hitbox._perform_attack()
	_check("B_attack_follows_aim", captured[0].distance_to(
			Vector3(sin(cam.rotation.y + PI), 0.0, cos(cam.rotation.y + PI))) < 0.001)

	# A different camera yaw must be tracked too.
	cam.rotation.y = -2.0
	await _frames(2)
	_check("B_tracks_camera_yaw_change", is_equal_approx(_wrap(mesh.rotation.y), _wrap(cam.rotation.y + PI)))

	# Toggle key -> back to option A.
	await _press_toggle()
	_check("toggle_key_restores_A", player.face_aim_always == false)

	main.queue_free()
	await _frames(2)
	var passed := not _results.has(false)
	print("ALL_TESTS_PASS=", passed)
	quit(0 if passed else 1)
