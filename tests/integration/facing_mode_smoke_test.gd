extends SceneTree
## M6 camera/facing smoke test (single-player) — two third-person schemes.
##
## The melee swing always travels along the Mesh front (+Z), so the attack follows the character's
## facing. The "toggle_camera_lock" action (key V) switches scheme:
##   * option A (default, camera_lock_behind == false): free mouse-look; the character faces its
##     MOVEMENT direction, the attack follows movement, and the controller does not drive the camera;
##   * option B (camera_lock_behind == true): over-the-shoulder aim; the MOUSE steers, the character
##     turns to face the camera-forward (mesh yaw == camera yaw + PI) so the camera stays locked
##     behind it, the attack follows the aim, and A/D strafe SLIDES sideways without spinning the
##     character (no orbit).
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


## True when two yaw angles agree within tol radians (the locked camera lerps, so allow slack).
func _angle_close(a: float, b: float, tol: float = 0.02) -> bool:
	return absf(_wrap(a - b)) < tol


## Presses the toggle action and lets player_controller._physics_process observe the edge.
func _press_toggle() -> void:
	Input.action_press("toggle_camera_lock")
	await _frames(3)
	Input.action_release("toggle_camera_lock")
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

	_check("default_mode_is_A_free_camera", player.camera_lock_behind == false)

	# The swing direction is the Mesh front (+Z), independent of the camera (true in both modes).
	var captured: Array = [Vector3.ZERO]
	hitbox.attack_started.connect(func(f: Vector3): captured[0] = f)
	mesh.rotation.y = 0.7
	await _frames(1)
	hitbox._perform_attack()
	_check("attack_follows_mesh_facing",
			captured[0].distance_to(Vector3(sin(0.7), 0.0, cos(0.7))) < 0.001)

	# Option A: the controller does NOT drive the camera, so its yaw stays put (free mouse-look).
	var cam_before: float = cam.rotation.y
	await _frames(3)
	_check("A_camera_not_locked", _angle_close(cam.rotation.y, cam_before))

	# Toggle key -> option B (over-the-shoulder aim: the mouse steers, the character faces the aim).
	await _press_toggle()
	_check("toggle_key_enables_camera_lock", player.camera_lock_behind == true)

	# In B the character turns to face the camera-forward (mesh yaw == camera yaw + PI), so the
	# camera stays locked behind it. The camera pivot is the master; the mesh follows.
	cam.rotation.y = 1.1
	await _frames(40)
	_check("B_mesh_faces_camera_aim", _angle_close(mesh.rotation.y, cam.rotation.y + PI))

	# The swing therefore follows the aim (mesh front == camera-forward).
	captured[0] = Vector3.ZERO
	hitbox._perform_attack()
	_check("B_attack_follows_aim", captured[0].distance_to(
			Vector3(sin(cam.rotation.y + PI), 0.0, cos(cam.rotation.y + PI))) < 0.01)

	# KEY regression: strafing must SLIDE, not orbit. Aim down -Z (cam yaw 0), then hold move_right
	# (+X strafe): the character must translate sideways while its facing stays at -Z (no spin to +X).
	cam.rotation.y = 0.0
	await _frames(40)
	var x_before: float = player.position.x
	Input.action_press("move_right")
	await _frames(20)
	Input.action_release("move_right")
	await _frames(2)
	_check("B_strafe_slides_without_turning",
			player.position.x > x_before + 0.2 and _angle_close(mesh.rotation.y, PI, 0.25))

	# Toggle key -> back to option A.
	await _press_toggle()
	_check("toggle_key_restores_A", player.camera_lock_behind == false)

	main.queue_free()
	await _frames(2)
	var passed := not _results.has(false)
	print("ALL_TESTS_PASS=", passed)
	quit(0 if passed else 1)
