extends SceneTree
## Focused regressions: real snapshot presentation handler, isolated melee resources,
## and damage validation. Snapshot inputs are fixtures, not a transport/network test.
const SESSION := preload("res://scenes/multiplayer/MultiplayerArena.tscn")
const MELEE := preload("res://scripts/combat/melee_attacker.gd")
const HEALTH := preload("res://scripts/combat/health.gd")
var results: Array[bool] = []

func _init() -> void:
	_run.call_deferred()

func _check(label: String, passed: bool) -> void:
	print("CHECK ", label, " = ", passed)
	results.append(passed)

func _melee_fixture(shared: SphereShape3D, radius: float) -> Node3D:
	var body := Node3D.new()
	var pivot := Node3D.new()
	pivot.name = "CameraPivot"
	body.add_child(pivot)
	var attack := Area3D.new()
	attack.set_script(MELEE)
	attack.name = "AttackHitbox"
	attack.attack_range = radius
	attack.external_control = true
	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	collision.shape = shared
	attack.add_child(collision)
	body.add_child(attack)
	root.add_child(body)
	return body

func _run() -> void:
	var shared := SphereShape3D.new()
	shared.radius = 0.5
	var first := _melee_fixture(shared, 1.5)
	var second := _melee_fixture(shared, 3.0)
	var first_shape: SphereShape3D = first.get_node("AttackHitbox/CollisionShape3D").shape
	var second_shape: SphereShape3D = second.get_node("AttackHitbox/CollisionShape3D").shape
	_check("melee_shapes_are_instance_owned", first_shape != second_shape and first_shape != shared and second_shape != shared)
	_check("melee_ranges_do_not_mutate_siblings_or_template", first_shape.radius == 1.5 and second_shape.radius == 3.0 and shared.radius == 0.5)
	second_shape.radius = 4.0
	_check("later_range_change_is_isolated", first_shape.radius == 1.5 and shared.radius == 0.5)
	first.free()
	second.free()
	var health := Node.new()
	health.set_script(HEALTH)
	root.add_child(health)
	var source := Node.new()
	var invalid_source := Node.new()
	root.add_child(source)
	root.add_child(invalid_source)
	var signals := [0, 0]
	health.health_changed.connect(func(_current: float, _max: float): signals[0] += 1)
	health.died.connect(func(): signals[1] += 1)
	health.apply_damage(25.0, source)
	_check("valid_damage_updates_state_and_source", health.get_health() == 75.0 and health.last_damage_source == source and signals == [1, 0])
	for amount in [-10.0, 0.0, NAN, INF, -INF]:
		health.apply_damage(amount, invalid_source)
	_check("invalid_damage_preserves_health", health.get_health() == 75.0)
	_check("invalid_damage_preserves_kill_attribution", health.last_damage_source == source)
	_check("invalid_damage_emits_no_signals", signals == [1, 0])
	health.apply_damage(100.0, source)
	health.apply_damage(100.0, invalid_source)
	_check("valid_lethal_damage_emits_death_once", health.get_health() == 0.0 and signals == [2, 1] and health.last_damage_source == source)
	health.network_replica = true
	health.apply_network_state(50.0, 100.0)
	var signal_count: int = signals[0]
	for pair in [[NAN, 100.0], [INF, 100.0], [-INF, 100.0], [50.0, NAN], [50.0, INF], [50.0, -INF], [50.0, 0.0], [50.0, -100.0]]:
		health.apply_network_state(pair[0], pair[1])
	_check("invalid_replica_health_preserves_state", health.get_health() == 50.0 and health.max_health == 100.0)
	_check("invalid_replica_health_emits_no_signals", signals[0] == signal_count and signals[1] == 1)
	health.apply_network_state(200.0, 150.0)
	_check("valid_replica_health_clamps_to_maximum", health.get_health() == 150.0 and health.max_health == 150.0)
	health.free()
	source.free()
	invalid_source.free()
	var session: Node = SESSION.instantiate()
	session.capture_local_controls = false
	root.add_child(session)
	# Stop the unused client connection; exercise the same snapshot method synchronously.
	session.set_physics_process(false)
	session._peer.close()
	session._local_peer_id = 42
	var wire: Array = [42, 0, 0, Vector3(-6, 1, -6), Vector3.ZERO, 0.75, -0.5, 100.0, 100.0, false, 0]
	session._receive_snapshot(1, [wire], 1, 0, 0, 180.0, -1, "fixture")
	var body: Variant = session.players[42].body
	var animation: Variant = body.get_node("CharacterAnimation")
	var attack: Variant = body.get_node("AttackHitbox")
	var feedback: Variant = body.get_node("PlayerFeedback")
	var swings := [0]
	var direction := [Vector3.ZERO]
	attack.attack_started.connect(func(forward: Vector3):
		swings[0] += 1
		direction[0] = forward)
	_check("replica_has_authored_animation_player", animation._anim != null)
	wire[10] = 1
	session._receive_snapshot(2, [wire], 1, 0, 0, 179.0, -1, "fixture")
	_check("snapshot_swing_emits_presentation_signal", swings[0] == 1)
	_check("snapshot_swing_drives_authored_attack", animation._attack_playing and animation._anim != null and animation.get_action_clip() == "Attack_Slash")
	_check("snapshot_swing_drives_swipe", feedback.get_node("AttackSwipe").visible)
	_check("snapshot_swing_uses_mesh_facing", direction[0].dot(Vector3.BACK.rotated(Vector3.UP, 0.75)) > 0.999)
	session._receive_snapshot(3, [wire], 1, 0, 0, 178.0, -1, "fixture")
	_check("unchanged_swing_counter_does_not_replay", swings[0] == 1 and animation._attack_index == 1)
	wire[10] = 2
	session._receive_snapshot(2, [wire], 1, 0, 0, 179.0, -1, "stale")
	_check("stale_snapshot_does_not_replay_attack", swings[0] == 1)
	session._receive_snapshot(4, [wire], 1, 0, 0, 177.0, -1, "fixture")
	_check("next_authoritative_swing_advances_clip", swings[0] == 2 and animation._anim != null and animation.get_action_clip() == "Attack_Backhand")
	wire[9] = true
	wire[7] = 0.0
	wire[10] = 3
	session._receive_snapshot(5, [wire], 1, 0, 0, 176.0, -1, "fixture")
	_check("dead_snapshot_does_not_emit_swing", swings[0] == 2 and not body.get_node("Mesh").visible)
	session.free()
	var passed := not results.has(false)
	print("ALL_TESTS_PASS=", passed, " checks=", results.size())
	quit(0 if passed else 1)
