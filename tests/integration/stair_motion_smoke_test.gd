extends SceneTree
const PLAYER := preload("res://scenes/characters/Player.tscn")
const LOCAL := preload("res://scripts/player/local_motion_test_player.gd")
var failures := 0
var checks := 0
var world: Node3D
var body: CharacterBody3D
var geometry: Array[Node] = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	print("CHECK ", label, " = ", ok)
	if not ok:
		failures += 1

func box(size: Vector3, at: Vector3) -> void:
	var solid := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	solid.add_child(collision)
	solid.position = at
	world.add_child(solid)
	geometry.append(solid)

func frames(count: int, direction: Vector3 = Vector3.ZERO, running: bool = false) -> void:
	for i in count:
		await physics_frame
		body._simulate_movement(1.0 / 60.0, direction, running, false)
	await process_frame

func fixture(height: float, count: int = 4) -> void:
	for item in geometry:
		item.free()
	geometry.clear()
	box(Vector3(40, 1, 40), Vector3(0, -0.5, 0))
	for i in count:
		box(Vector3(4, (i + 1) * height, 6.0 if i == count - 1 else 1.2), Vector3(0, (i + 1) * height / 2, -i * 1.2 - (2.4 if i == count - 1 else 0.0)))
	body.position = Vector3(0, 1.01, 2)
	body.velocity = Vector3.ZERO
	body.reset_traversal()
	await frames(10)

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
	for height in [0.15, 0.3, 0.4]:
		for running in [false, true]:
			await fixture(height)
			var max_correction := 0.0
			var grounded := 0
			var air_clips := 0
			var peak_foot_offset := 0.0
			var duration := 310 if not running else 132
			for i in duration:
				await frames(1, Vector3.FORWARD, running)
				max_correction = maxf(max_correction, absf(body.stair_presentation.visual_offset))
				if body.get_node("CharacterAnimation").get_locomotion_clip() == "Jump":
					air_clips += 1
				for offset in body.stair_presentation._modifier.offsets:
					peak_foot_offset = maxf(peak_foot_offset, absf(offset))
				if body.is_on_floor():
					grounded += 1
			print("STAIR ", height, " run=", running, " position=", body.position, " smoothing=", max_correction, " grounded=", grounded, "/", duration)
			check(body.position.z < -2.9 and body.position.y > 1.0 + height * 3.5, "ascend %.2f m at run=%s" % [height, running])
			check(grounded > duration * 0.9 and air_clips == 0, "stairs stay grounded without Jump animation")
			check(peak_foot_offset > 0.03 and body.stair_presentation._modifier.solve_count > 0, "terrain samples drive actual leg correction")
			check(max_correction > 0.01, "visible step smoothing applied")
			body.position = Vector3(0, 1.01 + height * 4, -3.6)
			body.velocity = Vector3.ZERO
			await frames(5)
			await frames(duration + 60, Vector3.BACK, running)
			print("DESCENT ", height, " ", running, " ", body.position)
			check(body.position.z > 0.8 and body.position.y < 1.1 and body.is_on_floor(), "descend %.2f m" % height)
	await fixture(0.6, 1)
	await frames(150, Vector3.FORWARD, true)
	print("OVERHEIGHT ", body.position)
	check(body.position.z > 0.7 and body.position.y < 1.1, "overheight ledge does not auto climb")
	await fixture(0.3, 1)
	box(Vector3(4, 0.2, 4), Vector3(0, 2.22, 0))
	await frames(120, Vector3.FORWARD, true)
	check(body.position.z > 0.7 and body.position.y < 1.1, "low ceiling rejects stair ascent")
	await fixture(0.3)
	body.position = Vector3(0, 1.01, 2)
	await frames(5)
	body._simulate_movement(1.0 / 60.0, Vector3.FORWARD, true, true)
	await frames(8, Vector3.FORWARD, true)
	check(body.velocity.y > 0.0 and body.position.y > 1.4, "jump keeps upward impulse near stairs")
	body.get_node("Mesh").set_character(1)
	await frames(4)
	await fixture(0.3)
	await frames(310, Vector3.FORWARD)
	check(body.position.z < -3.0 and body.position.y > 2.0 and body.stair_presentation._modifier.solve_count > 0, "Warden climbs stairs with its own live rig correction")
	world.free()
	print("CHECKS=", checks, " ALL_TESTS_PASS=", failures == 0)
	quit(0 if failures == 0 else 1)
