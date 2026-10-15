extends SceneTree
## Headless integration smoke test for Milestone 1 (Agent C — QA).
##
## Verifies the acceptance criteria that CAN be checked without a human/display:
##   1. The player spawns and rests on the floor (does not fall through).
##   2. Camera-relative movement displaces the player when "move_forward" is held.
##   3. Jumping leaves the floor.
##
## Run from the project root with the Godot console binary:
##   godot --headless --path . --script res://tests/integration/movement_smoke_test.gd
## Exit code 0 = all checks passed, 1 = at least one failed.

const MAIN_SCENE := "res://scenes/main/Main.tscn"


func _init() -> void:
	_run()


func _run() -> void:
	var main: Node = load(MAIN_SCENE).instantiate()
	root.add_child(main)
	var player: CharacterBody3D = main.get_node("Player")

	var results: Array[bool] = []

	# --- 1. Floor / gravity -------------------------------------------------
	# Use local position here: the node's global transform is not valid until the
	# first physics frame after being added to the tree.
	print("spawn_position=", player.position)
	for i in range(90):
		await physics_frame
	var on_floor := player.is_on_floor()
	var y := player.global_position.y
	var floor_ok := on_floor and y > 0.5 and y < 1.5
	print("rest_position=", player.global_position, " on_floor=", on_floor)
	print("CHECK floor_collision = ", floor_ok)
	results.append(floor_ok)

	# --- 2. Movement --------------------------------------------------------
	var start := player.global_position
	Input.action_press("move_forward")
	for i in range(60):
		await physics_frame
	Input.action_release("move_forward")
	var moved := player.global_position.distance_to(start)
	var move_ok := moved > 0.5
	print("moved_distance=", moved)
	print("CHECK movement = ", move_ok)
	results.append(move_ok)

	# --- 3. Jump ------------------------------------------------------------
	# Let the player settle first.
	for i in range(30):
		await physics_frame
	Input.action_press("jump")
	await physics_frame
	Input.action_release("jump")
	var left_floor := false
	for i in range(40):
		await physics_frame
		if not player.is_on_floor():
			left_floor = true
	print("CHECK jump = ", left_floor)
	results.append(left_floor)

	# --- Summary ------------------------------------------------------------
	var all_pass := true
	for r in results:
		if not r:
			all_pass = false
	print("ALL_TESTS_PASS=", all_pass)
	quit(0 if all_pass else 1)
