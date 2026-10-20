extends SceneTree
var checks := 0
var failures := 0
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ", label)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var gallery = load("res://scenes/characters/AnimationReviewGallery.tscn").instantiate()
	root.add_child(gallery)
	await process_frame
	gallery.set_process(false)
	gallery._set_paused(true)
	for body in gallery.bodies:
		var driver = body.get_node("CharacterAnimation")
		for sample in [[0.0,"Idle"],[1.2,"Walk"],[2.2,"Run"],[2.0,"Run"],[1.9,"Run"],[1.8,"Walk"],[0.45,"Walk"],[0.35,"Idle"]]:
			body.velocity = body.get_node("Mesh").global_basis.z * float(sample[0])
			driver._physics_process(0.016)
			check(driver.get_locomotion_clip() == sample[1], str(body.name)+" speed "+str(sample[0]))
		driver._on_attack_started(Vector3.FORWARD)
		check(driver.get_action_clip() == "Attack_Slash", "accepted attack starts")
		driver._physics_process(driver._anim.get_animation("Attack_Slash").length + 0.01)
		check(driver.get_action_clip() == "" and not driver._attack_playing, "finished attack clears action")
		check(not body.is_physics_processing() and not body.has_node("Combatant"), "gallery body isolated")
		var raw = body.get_node("Mesh").get_child(0).duplicate()
		# Compare independently instantiated players of the same character below.
		raw.free()
	var twin = load("res://scenes/characters/Player.tscn").instantiate()
	twin.external_control = true
	twin.get_node("Combatant").free()
	root.add_child(twin)
	twin.set_physics_process(false)
	var first: Animation = gallery.bodies[0].get_node("CharacterAnimation")._anim.get_animation("Idle")
	var second: Animation = twin.get_node("CharacterAnimation")._anim.get_animation("Idle")
	check(first != second, "same-model animation resources are independent")
	first.loop_mode = Animation.LOOP_PINGPONG
	check(second.loop_mode == Animation.LOOP_LINEAR, "loop mutation remains local")
	first.loop_mode = Animation.LOOP_LINEAR
	gallery._set_mode(2)
	gallery._set_paused(true)
	var anim: AnimationPlayer = gallery.bodies[0].get_node("CharacterAnimation")._anim
	anim.advance(0)
	var before := anim.current_animation_position
	gallery._step()
	check(is_equal_approx(anim.current_animation_position - before, 1.0/30.0), "paused frame step advances exactly")
	for body in gallery.bodies:
		check(body.get_node("CharacterAnimation")._anim.current_animation == "Walk", "manual clip on both models")
	check(gallery.paused, "step leaves playback paused")
	gallery.free()
	twin.free()
	print("CHECKS=",checks," FAILURES=",failures," ALL_TESTS_PASS=",failures == 0)
	quit(0 if failures == 0 else 1)
