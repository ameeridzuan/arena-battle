extends SceneTree
const MAIN := preload("res://scenes/main/Main.tscn")
const MOTION_STATE := preload("res://scripts/multiplayer/network_motion_state.gd")
var failures := 0
var checks := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", label)

func _initialize() -> void:
	call_deferred("run")

func settle() -> void:
	for i in 5:
		await physics_frame
	await process_frame

func run() -> void:
	var main := MAIN.instantiate()
	root.add_child(main)
	main.get_node("MatchManager").set_physics_process(false)
	for name in ["Opponent1", "Opponent2"]:
		main.get_node(name + "/AttackHitbox").set_physics_process(false)
	await settle()
	var body: CharacterBody3D = main.get_node("Player")
	var mesh: Node = body.get_node("Mesh")
	var controls: Node = body.get_node("MotionTestControls")
	var driver: Node = body.get_node("CharacterAnimation")
	var attacker: Node = body.get_node("AttackHitbox")
	var default_segment: Array = attacker.get_weapon_segment()
	controls.switch_skin()
	await settle()
	check(mesh.character == 0 and mesh.cosmetic_skin == 1, "Astra keeps Arclight identity")
	check(mesh.get_display_name() == "Astra Yao (Arclight)", "Astra display name")
	check(mesh._model.find_child("AstraYaoBody", true, false) != null, "supplied body is instantiated")
	check(mesh.get_child_count() == 1, "one Model anchor after swapping")
	for clip in ["Idle", "Walk", "Run", "Walk_Left", "Jump", "Attack_Slash", "Actions/CastEnergy", "Actions/Dash_Forward", "Actions/Parry_Attempt"]:
		check(driver._anim.has_animation(clip), "Astra clip: " + clip)
	var segment: Array = attacker.get_weapon_segment()
	check(segment.size() == 2 and default_segment.size() == 2, "Astra retains melee sword")
	if segment.size() == 2 and default_segment.size() == 2:
		check(absf(segment[0].distance_to(segment[1]) - default_segment[0].distance_to(default_segment[1])) < 0.001, "same Arclight blade length")
	var state := MOTION_STATE.capture(body)
	check(state.character == 0 and state.skin == 1, "snapshot carries skin separately")
	controls.switch_skin()
	await settle()
	check(mesh.cosmetic_skin == 0 and mesh.get_display_name() == "Arclight", "toggle back to default")
	MOTION_STATE.apply(body, state)
	await settle()
	check(mesh.cosmetic_skin == 1 and mesh.character == 0, "snapshot restores Astra")
	var enemy: Node3D = main.get_node("Opponent1")
	enemy.position = body.position + Vector3.BACK * 1.1
	enemy.rotation = Vector3.ZERO
	body.get_node("Mesh").rotation.y = 0.0
	check(attacker.request_attack(), "Astra accepts Arclight melee attack")
	for i in 45:
		await physics_frame
	check(enemy.get_node("Health").get_health() == 75.0, "Astra blade contact deals 25 damage once")
	controls.switch_character()
	await settle()
	check(mesh.character == 1 and mesh.get_display_name() == "Ashen Warden", "Warden unaffected")
	controls.switch_character()
	await settle()
	check(mesh.character == 0 and mesh.cosmetic_skin == 1, "Arclight remembers skin")
	mesh.set_appearance(42, 42)
	check(mesh.character == 0 and mesh.cosmetic_skin == 1, "invalid appearance rejected")
	mesh.set_cosmetic_skin(0)
	await settle()
	print("ASTRA_SKIN_CHECKS=", checks, " FAILURES=", failures)
	main.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
