extends SceneTree
const PLAYER := preload("res://scenes/characters/Player.tscn")
const LOCAL := preload("res://scripts/player/local_motion_test_player.gd")
var world: Node3D
var body: CharacterBody3D
var geometry: Array[Node] = []
var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	print("CHECK ", label, " = ", ok)
	if not ok:
		failures += 1

func box(size: Vector3, at: Vector3) -> StaticBody3D:
	var solid := StaticBody3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	solid.add_child(collision)
	solid.position = at
	world.add_child(solid)
	geometry.append(solid)
	return solid

func frames(count: int) -> void:
	for i in count:
		await physics_frame
	await process_frame

func fixture(height: float, depth: float = 4.0) -> void:
	for solid in geometry:
		if is_instance_valid(solid):
			solid.free()
	geometry.clear()
	box(Vector3(40, 1, 40), Vector3(0, -0.5, 0))
	box(Vector3(6, height, depth), Vector3(0, height / 2.0, 2.0 - depth / 2.0))
	body.reset_traversal()
	body.traversal_motor.regrab_delay = 0.0
	body.position = Vector3(0, 1.01, 2.7)
	body.velocity = Vector3.ZERO
	await frames(5)
	body._simulate_movement(1.0 / 60.0, Vector3.ZERO, false, false)

func tick(count: int, direction: Vector3 = Vector3.ZERO) -> void:
	for i in count:
		await physics_frame
		body._simulate_movement(1.0 / 60.0, direction, false, false)
	await process_frame

func run() -> void:
	world = Node3D.new()
	root.add_child(world)
	body = PLAYER.instantiate()
	body.set_script(LOCAL)
	body.get_node("Combatant").free()
	if body.has_node("BurnStatus"):
		body.get_node("BurnStatus").free()
	world.add_child(body)
	body.set_physics_process(false)
	var motor: RefCounted = body.traversal_motor
	await fixture(0.6)
	check(motor.request_ledge(Vector3.FORWARD), "E accepts reachable low mantle")
	check(body.get_traversal_mode() == "climb", "low ledge goes directly into mantle")
	check(not body.allows_motion_actions(), "climbing blocks dodge/cast/parry")
	await tick(90)
	print("MANTLE_END ", body.position, " ", body.get_traversal_mode())
	check(body.get_traversal_mode() == "normal" and body.position.z < 1.5 and body.position.y > 1.5 and body.is_on_floor(), "mantle finishes standing on ledge")
	await fixture(1.8)
	check(motor.request_ledge(Vector3.FORWARD), "reachable high ledge can be grabbed")
	check(body.get_traversal_mode() == "hang" and body.velocity.is_zero_approx(), "ledge hang holds still without gravity")
	await tick(20)
	check(body.get_node("CharacterAnimation").get_locomotion_clip() == "Idle", "hang replaces airborne gait with traversal pose")
	check(motor.simulate(1.0 / 60.0, Vector3.ZERO, true, false, false), "Space accepts climb from hang")
	await tick(int(ceil(motor._climb_duration * 60.0)) + 15)
	check(body.get_traversal_mode() == "normal" and body.position.y > 2.7 and body.is_on_floor(), "high ledge climb reaches walkable landing")
	await fixture(1.8)
	check(motor.request_ledge(Vector3.FORWARD), "drop fixture grabs")
	motor.simulate(1.0 / 60.0, Vector3.ZERO, false, false, true)
	check(body.get_traversal_mode() == "normal" and body.velocity.y < 0.0 and not motor.request_ledge(Vector3.FORWARD), "C drops and prevents instant regrab")
	await fixture(2.4)
	check(not motor.request_ledge(Vector3.FORWARD), "out-of-reach ledge rejected from ground")
	body.position.y = 2.0
	body.velocity = Vector3.DOWN
	await frames(2)
	check(motor.request_ledge(Vector3.FORWARD, true) and body.get_traversal_mode() == "hang", "airborne approach grabs higher ledge")
	await fixture(0.6)
	box(Vector3(6, 0.3, 4), Vector3(0, 2.2, 0))
	await frames(2)
	check(not motor.request_ledge(Vector3.FORWARD), "climb rejects blocked standing clearance")
	await fixture(1.8, 0.4)
	check(not motor.request_ledge(Vector3.FORWARD), "thin ledge without landing support rejected")
	await fixture(1.8)
	check(motor.request_ledge(Vector3.FORWARD), "disappearing ledge fixture grabs")
	geometry[1].free()
	await tick(1)
	check(body.get_traversal_mode() == "normal", "removed ledge safely releases hang")
	await fixture(6.0)
	body.position = Vector3(0, 3, 2.55)
	body.velocity = Vector3.DOWN * 7
	body.move_and_slide()
	await frames(2)
	check(motor.simulate(1.0 / 60.0, Vector3.FORWARD, false, false, false), "airborne input into wall starts slide")
	check(body.get_traversal_mode() == "wall_slide" and body.velocity.y >= -2.01, "wall slide limits downward speed")
	check(motor.simulate(1.0 / 60.0, Vector3.FORWARD, true, false, false), "Space accepts wall jump")
	check(body.velocity.z > 4.0 and body.velocity.y > 6.0, "wall jump pushes up and away from wall")
	var start := body.position
	await tick(8, Vector3.FORWARD)
	check(body.position.z > start.z + 0.4, "wall jump retains outward impulse against held input")
	body.position = Vector3(0, 3, 2.55)
	body.velocity = Vector3.DOWN
	motor.wall_push_left = 0.0
	await frames(2)
	motor.simulate(1.0 / 60.0, Vector3.FORWARD, true, false, false)
	check(body.velocity.y <= 0.0, "same wall cannot be farmed for repeated jumps")
	box(Vector3(6, 6, 0.5), Vector3(0, 3, 5))
	body.position = Vector3(0, 3, 4.2)
	body.velocity = Vector3.DOWN
	motor.wall_push_left = 0.0
	await frames(2)
	motor.simulate(1.0 / 60.0, Vector3.BACK, true, false, false)
	check(body.velocity.z < -4.0 and body.velocity.y > 6.0, "opposite wall permits alternating wall jumps")
	await fixture(1.8)
	for character in [0, 1]:
		body.get_node("Mesh").set_character(character)
		await frames(4)
		motor.regrab_delay = 0.0
		check(motor.request_ledge(Vector3.FORWARD), "character %d grabs ledge" % character)
		await tick(3)
		var skeleton: Skeleton3D = body.find_children("*", "Skeleton3D", true, false).back()
		var modifier: Node = skeleton.get_node("TraversalPose")
		modifier._process_modification()
		var finite := true
		for bone in skeleton.get_bone_count():
			finite = finite and skeleton.get_bone_global_pose(bone).origin.is_finite()
		check(finite, "character %d traversal pose remains finite" % character)
		body.reset_traversal()
		body.position = Vector3(0, 1.01, 2.7)
		body.velocity = Vector3.ZERO
		await frames(3)
	await fixture(0.6)
	check(motor.request_ledge(Vector3.FORWARD), "interrupted climb starts with clear path")
	box(Vector3(2, 0.3, 1), Vector3(0, 2.0, 1.2))
	await tick(90)
	check(body.get_traversal_mode() == "normal" and body.position.z > 1.7, "new obstruction interrupts climb without passing through it")
	await fixture(1.8)
	check(motor.request_ledge(Vector3.FORWARD), "death fixture grabs")
	body.get_node("Health").apply_damage(100.0, null)
	check(body.get_traversal_mode() == "normal", "death resets traversal while body simulation is disabled")
	await tick(1)
	check(body.get_traversal_mode() == "normal", "death clears hanging state")
	body.get_node("Health").reset()
	await fixture(6.0)
	body.position = Vector3(0, 3, 2.55)
	body.velocity = Vector3.DOWN * 4
	body.move_and_slide()
	check(not motor.simulate(1.0 / 60.0, Vector3.ZERO, false, false, false) and body.get_traversal_mode() == "normal", "wall contact without inward input does not stick")
	world.free()
	print("CHECKS=", checks, " ALL_TESTS_PASS=", failures == 0)
	quit(0 if failures == 0 else 1)
