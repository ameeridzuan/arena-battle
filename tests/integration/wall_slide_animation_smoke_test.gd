extends "res://tests/integration/traversal_animation_smoke_test.gd"
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
	for character in 2:
		body.get_node("Mesh").set_character(character)
		await frames(4)
		await fixture(6.0)
		observe()
		body.position = Vector3(0, 3, 2.55)
		body.velocity = Vector3.DOWN * 5.0
		body.move_and_slide()
		await tick(16, Vector3.FORWARD)
		check(motor.pose_name() == "wall_slide", "wall slide active")
		for key in sampled_targets:
			var error: float = sampled_markers[key].distance_to(sampled_targets[key].anchor)
			print("SLIDE rig=", character, " key=", key, " error=", error, " actual=", sampled_markers[key], " desired=", sampled_targets[key].anchor)
			check(error < 0.04, "sliding contact reaches wall")
		check(slide_penetration < 0.001, "torso clears wall")
	world.free()
	print("CHECKS=", checks, " ALL_TESTS_PASS=", failures == 0)
	quit(0 if failures == 0 else 1)
