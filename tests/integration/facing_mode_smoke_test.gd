extends SceneTree
## M6 camera/facing smoke test (single-player).
##
## The character ALWAYS faces its MOVEMENT direction and the melee swing travels along the Mesh
## front (+Z), so the attack follows the character in BOTH modes. The "toggle_camera_lock" action
## (key V) only changes the CAMERA:
##   * default (option A) is free mouse-look (camera_lock_behind == false);
##   * the swing direction equals the Mesh front, independent of the camera (attack_started forward);
##   * the toggle key flips camera_lock_behind;
##   * option B hard-locks the camera yaw behind the character (camera yaw == mesh yaw + PI).
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

	# Toggle key -> option B (hard-lock the camera behind the character).
	await _press_toggle()
	_check("toggle_key_enables_camera_lock", player.camera_lock_behind == true)

	# The camera yaw swings to sit behind the character's facing (mesh yaw + PI).
	mesh.rotation.y = 0.7
	await _frames(40)
	_check("B_camera_locks_behind_character", _angle_close(cam.rotation.y, mesh.rotation.y + PI))

	# A different character facing must be tracked too.
	mesh.rotation.y = -2.0
	await _frames(40)
	_check("B_camera_tracks_character_facing", _angle_close(cam.rotation.y, mesh.rotation.y + PI))

	# Toggle key -> back to option A.
	await _press_toggle()
	_check("toggle_key_restores_A", player.camera_lock_behind == false)

	main.queue_free()
	await _frames(2)
	var passed := not _results.has(false)
	print("ALL_TESTS_PASS=", passed)
	quit(0 if passed else 1)
