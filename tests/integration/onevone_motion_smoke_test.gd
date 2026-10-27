extends SceneTree
const SESSION := preload("res://scenes/multiplayer/MultiplayerArena.tscn")
const STATE := preload("res://scripts/multiplayer/network_motion_state.gd")
const PLAYER := preload("res://scenes/characters/Player.tscn")
const MOTION := preload("res://scripts/player/local_motion_test_player.gd")
var session: Node
var checks := 0
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print("CHECK ", label, " = ", ok)
func frames(count: int) -> void:
	for i in count:
		await physics_frame
	await process_frame
func tick(count: int) -> void:
	for i in count:
		await physics_frame
		for record in session.players.values():
			record.last_input = Time.get_ticks_msec()
		session._server_step(1.0 / 60.0)
	await process_frame
func run() -> void:
	session = SESSION.instantiate()
	session.server_mode = true
	session.port = 24835
	session.required_players = 2
	root.add_child(session)
	session.set_physics_process(false)
	for id in [42, 43]:
		var team: int = id - 42
		var body: CharacterBody3D = session._spawn_player(id, team)
		session.players[id] = {"body": body, "team": team, "slot": 0, "seq": -1, "move": Vector2.ZERO, "yaw": 0.0, "run": false, "jump": false, "attack": false, "buttons": 0, "aim": false, "pitch": 0.0, "last_input": Time.get_ticks_msec(), "bucket_time": Time.get_ticks_msec(), "tokens": 120.0, "swings": 0}
	session.manager.start_match()
	await tick(8)
	var first: CharacterBody3D = session.players[42].body
	var second: CharacterBody3D = session.players[43].body
	var motion: Node = first.get_node("MotionTestControls")
	var weapon: Node = first.get_node("AttackHitbox")
	first.position = Vector3(0, 5.5, 13.5)
	check(not first.traversal_motor._clear(first.position, Vector3(0, 5.5, 15.5)), "elevated routes cannot jump through the arena boundary")
	first.position = Vector3(-6, 1.01, -6)
	check(first.has_method("move_with_stairs") and first.traversal_enabled, "match uses adaptive stair and parkour controller")
	check(weapon.network_authority and motion.network_authority and not motion.is_physics_processing(), "server owns action requests and clocks")
	check(first.get_node("Mesh").character == 0 and second.get_node("Mesh").character == 1, "character identities are consistent by team")
	first.position = Vector3(0, 1.01, 0)
	second.position = Vector3(0, 1.01, 1.1)
	first.get_node("Mesh").rotation.y = 0.0
	first.move_and_slide()
	second.move_and_slide()
	await tick(6)
	check(weapon.request_attack(), "server accepts blade-contact attack")
	check(second.get_health() == 100.0, "attack windup grants no immediate damage")
	await tick(50)
	check(second.get_health() == 75.0, "server blade contact applies 25 damage exactly once")
	second.position = Vector3(6, 1.01, 6)
	await tick(6)

	check(not session._accept_input(42, 0, Vector2.ZERO, 0, false, false, false, 128), "undefined action bits are rejected")
	check(not session._accept_input(42, 0, Vector2.ZERO, 0, false, false, false, 0, true, NAN), "nonfinite camera pitch rejected")
	check(session._accept_input(42, 0, Vector2.ZERO, 0, false, false, false, session.DODGE), "bounded remote dodge request accepted")
	session._server_step(1.0 / 60.0)
	check(motion._dodge_active and first.get_node("CharacterAnimation").get_action_clip().begins_with("Actions/Dodge_"), "server starts directional dodge")
	var start := first.position
	await tick(24)
	check(first.position.distance_to(start) > 0.3, "server moves dodge body through collision")
	check(not motion.request_dodge(), "dodge spam cannot bypass active action or cooldown")
	await tick(45)
	check(session._accept_input(42, 1, Vector2.ZERO, 0, false, false, false, session.PARRY), "bounded remote parry request accepted")
	session._server_step(1.0 / 60.0)
	check(motion._parry_elapsed >= 0, "server starts parry window")
	motion._parry_elapsed = 0.14
	first.get_node("Mesh").rotation.y = 0.0
	second.position = first.position + Vector3.BACK * 1.5
	var health: float = first.get_health()
	first.receive_melee_hit(25, second)
	check(first.get_health() == health and motion._parry_confirmed, "validated frontal melee is deflected by server parry")
	await tick(55)
	first.get_node("Mesh").rotation.y = PI
	second.position = first.position + Vector3.FORWARD * 4.0
	second.get_node("Health").reset()
	check(session._accept_input(42, 2, Vector2.ZERO, 0, false, false, false, session.CAST, true), "bounded remote cast request accepted")
	session._server_step(1.0 / 60.0)
	check(motion._cast_elapsed >= 0, "server starts cast and cooldown")
	check(not motion.request_cast(), "cast spam rejected by authoritative cooldown")
	await tick(24)
	var shots: Array = session._capture_effects()[0]
	check(not shots.is_empty(), "server creates traveling spell for replication")
	await tick(24)
	check(second.get_health() == 80.0 and second.get_node("BurnStatus").is_burning(), "authoritative spell impact starts burn")
	await tick(185)
	check(second.get_health() == 71.0, "server burn delivers three timed damage ticks")
	motion.cancel_motion()
	first.reset_traversal()
	first.position = Vector3(-7.3, 1.01, 0)
	first.velocity = Vector3.ZERO
	first.move_and_slide()
	await frames(3)
	first.traversal_motor.regrab_delay = 0.0
	check(first.traversal_motor.request_ledge(Vector3.LEFT), "new terrace supports ledge grab from central court")
	await tick(12)
	var replica: CharacterBody3D = PLAYER.instantiate()
	replica.set_script(MOTION)
	replica.external_control = true
	replica.network_presentation_only = true
	replica.get_node("Combatant").free()
	replica.get_node("Health").network_replica = true
	session.add_child(replica)
	replica.set_physics_process(false)
	replica.get_node("AttackHitbox").set_physics_process(false)
	replica.get_node("CollisionShape3D").disabled = true
	await frames(4)
	var state: Dictionary = bytes_to_var(var_to_bytes(STATE.capture(first)))
	STATE.apply(replica, state)
	check(replica.get_traversal_mode() == "hang" and replica.traversal_motor.hand_anchors == first.traversal_motor.hand_anchors, "serialized snapshot preserves hanging state and grip anchors")
	var before: float = replica.get_health()
	replica.apply_damage(99, first)
	check(replica.get_health() == before, "replica cannot grant damage")
	check(first.traversal_motor._start_climb() and is_equal_approx(first.traversal_motor._climb_duration, 2.15), "match uses faster approved climb")
	await tick(145)
	check(first.get_traversal_mode() == "normal" and first.is_on_floor() and first.position.y > 2.7, "match climb finishes standing on terrace")
	first.reset_traversal()
	first.position = Vector3(10, 1.01, 9)
	first.velocity = Vector3.ZERO
	first.move_and_slide()
	session.players[42].move = Vector2(0, -1)
	await tick(340)
	check(first.position.y > 2.7 and first.is_on_floor(), "varied-height stairs reach upper terrace")
	session.players[42].move = Vector2.ZERO
	first.reset_traversal()
	first.position = Vector3(0.6, 3, 9)
	first.velocity = Vector3.DOWN
	first.move_and_slide()
	first.traversal_motor.simulate(1.0 / 60.0, Vector3.RIGHT, false, false, false)
	check(first.get_traversal_mode() == "wall_slide", "new jump lane supports controlled wall slide")
	STATE.apply(replica, bytes_to_var(var_to_bytes(STATE.capture(first))))
	check(replica.get_traversal_mode() == "wall_slide" and replica.traversal_motor.wall_contact_point == first.traversal_motor.wall_contact_point, "wall slide contact plane reaches replica")
	first.traversal_motor.simulate(1.0 / 60.0, Vector3.RIGHT, true, false, false)
	check(first.velocity.x < -4.0 and first.velocity.y > 6.0, "new jump lane permits upward outward wall jump")
	STATE.apply(replica, bytes_to_var(var_to_bytes(STATE.capture(first))))
	check(replica.traversal_motor.pose_name() == "wall_jump", "wall jump pose reaches replica")
	first.reset_traversal()
	motion.cancel_motion()
	first.position = Vector3(0, 1.01, 0)
	first.velocity = Vector3.ZERO
	first.move_and_slide()
	await tick(5)
	check(session._accept_input(42, 3, Vector2.ZERO, 0, false, false, false, session.SKIN), "remote skin request accepted")
	session._server_step(1.0 / 60.0)
	check(first.get_node("Mesh").character == 0 and first.get_node("Mesh").cosmetic_skin == 1, "authority equips Astra without changing character")
	STATE.apply(replica, bytes_to_var(var_to_bytes(STATE.capture(first))))
	check(replica.get_node("Mesh").cosmetic_skin == 1 and replica.get_node("Mesh").get_display_name() == "Astra Yao (Arclight)", "serialized Astra appearance reaches replica")
	check(session._accept_input(43, 0, Vector2.ZERO, 0, false, false, false, session.SKIN), "remote Warden skin request accepted")
	session._server_step(1.0 / 60.0)
	check(second.get_node("Mesh").character == 1 and second.get_node("Mesh").cosmetic_skin == 2, "authority equips Yixuan on Warden")
	STATE.apply(replica, bytes_to_var(var_to_bytes(STATE.capture(second))))
	check(replica.get_node("Mesh").get_display_name() == "Yixuan (Ashen Warden)" and replica.get_node("Mesh")._model.has_node("YixuanSpringMotion"), "Yixuan animation and skin reach replica")
	first.get_node("Health").apply_damage(100, second)
	check(first.get_traversal_mode() == "normal" and not motion._dodge_active and motion._cast_elapsed < 0, "death cancels traversal and action state")
	session.manager._end_match(-1)
	check(not motion.request_cast() and not motion.request_dodge(), "match end rejects new abilities")
	session.free()
	print("CHECKS=", checks, " ALL_TESTS_PASS=", failures == 0)
	quit(0 if failures == 0 else 1)
