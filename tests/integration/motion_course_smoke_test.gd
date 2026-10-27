extends SceneTree
const COURSE := preload("res://scenes/characters/MotionTestCourse.tscn")
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: ", label)

func frames(count: int) -> void:
	for i in count:
		await physics_frame
	await process_frame

func run() -> void:
	var course := COURSE.instantiate()
	root.add_child(course)
	var player: CharacterBody3D = course.get_node("Player")
	await frames(20)
	check(player.is_on_floor(), "spawn rests on recovery floor")
	check(get_nodes_in_group("motion_test_ledge").size() == 5, "five measured ledges")
	check(get_nodes_in_group("motion_test_wall").size() == 6, "three paired wall lanes")
	for index in 6:
		course.reset_player(index)
		await frames(8)
		check(player.is_on_floor() and player.position.is_finite(), "zone %d has clear grounded spawn" % index)
	course.reset_player(1)
	await frames(5)
	player._simulate_movement(1.0 / 60.0, Vector3.ZERO, false, true)
	await frames(8)
	check(player.position.y > 1.3, "real jump rises from course floor")
	await frames(70)
	check(player.is_on_floor(), "jump lands on course floor")
	player.position.y = -10
	await frames(8)
	check(player.position.distance_to(course.SPAWNS[1]) < 0.2, "fall recovery returns to selected zone")
	var space := player.get_world_3d().direct_space_state
	for ledge in get_nodes_in_group("motion_test_ledge"):
		var ray := PhysicsRayQueryParameters3D.create(ledge.position + Vector3(0, 8, 0), ledge.position - Vector3(0, 8, 0), 1)
		var hit := space.intersect_ray(ray)
		check(not hit.is_empty() and absf(hit.position.y - float(ledge.get_meta("ledge_height_m"))) < 0.01, "ledge top collision matches labelled height")
	course.reset_player(5)
	player.position = Vector3(20, 1.05, -16)
	await frames(8)
	for i in 90:
		player._simulate_movement(1.0 / 60.0, Vector3.RIGHT, true, false)
		await physics_frame
	check(player.position.x < 20.8, "wall lane blocks player travel")
	player.reset_traversal()
	player.position = Vector3(-23, 1.01, -5.8)
	player.velocity = Vector3.ZERO
	await frames(12)
	player.get_node("Mesh").rotation.y = PI
	check(player.get_node("MotionTestControls").request_dodge(Vector3.FORWARD), "dash can start approaching stairs")
	await frames(45)
	check(player.position.z < -7.5 and player.position.y > 1.4, "real dash traverses stair risers")
	player.reset_traversal()
	player.position = Vector3(0, 1.01, -19.25)
	player.velocity = Vector3.ZERO
	await frames(8)
	player.traversal_motor.regrab_delay = 0.0
	check(player.traversal_motor.request_ledge(Vector3.FORWARD), "live harness enters ledge hang")
	player.camera_lock_behind = true
	var controls: Node = player.get_node("MotionTestControls")
	controls._cast_cooldown = 0.0
	check(not controls.request_cast(), "hanging rejects cosmetic or combat cast requests")
	course.reset_player(0)
	check(player.get_traversal_mode() == "normal" and player.allows_motion_actions(), "zone reset clears traversal and restores controls")
	course.free()
	print("ALL_TESTS_PASS=", failures == 0)
	quit(0 if failures == 0 else 1)
