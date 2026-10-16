extends SceneTree
## M6 facing-mode toggle smoke test (single-player).
##
## Proves the option C <-> option B toggle added to player_controller.gd:
##   * default is option C (face_aim_always == false);
##   * option C snaps the visual mesh to the aim forward at each swing (_on_attack_started);
##   * the "toggle_face_aim" action (key V) flips face_aim_always;
##   * option B makes the mesh track the camera-aim (camera yaw + PI) every physics frame.
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

	_check("default_mode_is_C", player.face_aim_always == false)

	# Option C: a swing snaps the mesh front (+Z) to the aim forward exactly.
	player._on_attack_started(Vector3(1.0, 0.0, 0.0))
	_check("C_attack_snap_faces_aim", is_equal_approx(mesh.rotation.y, atan2(1.0, 0.0)))

	# Toggle key -> option B.
	await _press_toggle()
	_check("toggle_key_enables_B", player.face_aim_always == true)

	# Option B: the mesh tracks camera-aim every frame, regardless of movement.
	cam.rotation.y = 1.1
	await _frames(2)
	_check("B_faces_camera_aim", is_equal_approx(_wrap(mesh.rotation.y), _wrap(cam.rotation.y + PI)))

	# A different camera yaw must be tracked too.
	cam.rotation.y = -2.0
	await _frames(2)
	_check("B_tracks_camera_yaw_change", is_equal_approx(_wrap(mesh.rotation.y), _wrap(cam.rotation.y + PI)))

	# Toggle key -> back to option C.
	await _press_toggle()
	_check("toggle_key_restores_C", player.face_aim_always == false)

	main.queue_free()
	await _frames(2)
	var passed := not _results.has(false)
	print("ALL_TESTS_PASS=", passed)
	quit(0 if passed else 1)
