extends SceneTree
## Real ENet process test. The Python runner starts a server and two independent clients.
const SCENE := preload("res://scenes/multiplayer/MultiplayerArena.tscn")
var session: Node
var results: Array[bool] = []
var report_path: String
var role: String = ""
var scenario: String = "gameplay"
var seen: Dictionary = {}
var _last_stage: String = ""
var _stage_started: int = 0
var _movement_start: Vector3
var _has_start: bool = false

func _init() -> void:
	_run.call_deferred()

func _check(label: String, passed: bool) -> void:
	print("CHECK ", label, " = ", passed)
	results.append(passed)

func _wait_until(predicate: Callable, seconds: float = 8.0) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while not predicate.call() and Time.get_ticks_msec() < deadline:
		await process_frame
	return predicate.call()

func _seconds(seconds: float) -> void:
	await create_timer(seconds).timeout

func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):
			report_path = arg.trim_prefix("--report=")
		elif arg.begins_with("--role="):
			role = arg.trim_prefix("--role=")
		elif arg.begins_with("--scenario="):
			scenario = arg.trim_prefix("--scenario=")
	session = SCENE.instantiate()
	session.capture_local_controls = false
	root.add_child(session)
	if scenario == "unavailable":
		session.connection_timeout_ms = 800
		_check("unavailable_server_reports_failure", await _wait_until(func(): return session.status_text.begins_with("Connection failed"), 3.0))
		_check("failed_connection_has_no_players", not session.connected and session.players.is_empty())
	elif role == "server":
		await _server_test()
	else:
		await _client_test()
	var passed := not results.is_empty() and not results.has(false)
	print("ALL_TESTS_PASS=", passed)
	if not report_path.is_empty():
		var file := FileAccess.open(report_path, FileAccess.WRITE)
		file.store_string(JSON.stringify({"passed": passed, "checks": results.size(), "role": role,
			"scenario": scenario, "rtt_ms": session.rtt_ms, "seen": seen}))
	quit(0 if passed else 1)

func _stage(name: String) -> void:
	session.status_text = "TEST:" + name
	session._broadcast_snapshot()
	print("STAGE ", name)

func _position_players(first: Node3D, second: Node3D, target: Vector3) -> void:
	first.position = Vector3(0, 1, 0)
	second.position = target
	first.velocity = Vector3.ZERO
	second.velocity = Vector3.ZERO
	for record in session.players.values():
		record.move = Vector2.ZERO
		record.attack = false
		record.body.get_node("AttackHitbox")._cooldown_remaining = 0.0

func _server_test() -> void:
	_check("two_clients_registered", await _wait_until(func(): return session.players.size() == 2 and session.manager.phase == 1))
	if session.players.size() != 2:
		return
	var records: Array = session.players.values()
	records.sort_custom(func(a, b): return a.team < b.team)
	var first: Variant = records[0].body
	var second: Variant = records[1].body
	_check("distinct_server_assigned_teams", records[0].team == 0 and records[1].team == 1)
	if scenario == "disconnect":
		_stage("disconnect")
		_check("disconnect_removes_player", await _wait_until(func(): return session.players.size() == 1))
		_check("disconnect_ends_running_match", session.manager.phase == 2 and session.winner == -1)
		await _seconds(0.8)
		return
	if scenario == "timeout":
		session.manager.time_remaining = 0.5
		_stage("timeout")
		_check("server_time_limit_ends_draw", await _wait_until(func(): return session.manager.phase == 2))
		_check("timeout_score_and_winner", session.winner == -1 and session.manager.score_a == 0 and session.manager.score_b == 0)
		_stage("timeout_result")
		await _seconds(0.8)
		_stage("done")
		await _seconds(0.5)
		return
	# Short respawn and score target are test fixture overrides only.
	second.get_node("Combatant").respawn_delay = 0.5
	session.manager.score_limit = 2
	_stage("motion")
	var initial: Vector3 = first.position
	await _seconds(0.8)
	var distance: float = first.position.distance_to(initial)
	_check("server_simulates_bounded_movement", distance > 0.5 and distance < first.run_speed * 1.0)
	_stage("stale")
	# Input timeout is followed by the controller's normal deceleration to rest.
	await _seconds(0.8)
	var stopped: Vector3 = first.position
	await _seconds(0.3)
	_check("stale_input_stops_movement", first.position.distance_to(stopped) < 0.02)
	_stage("invalid")
	# Lower the configurable budget so ENet's burst coalescing cannot hide the limit.
	session.input_rate_limit = 10.0
	session.input_burst_limit = 5.0
	for record in session.players.values():
		record.tokens = 5.0
	await _seconds(0.5)
	_check("remote_invalid_requests_rejected", session.rejected_inputs >= 3)
	_check("remote_flood_rate_limited", session.rate_limited_inputs > 0)
	_check("invalid_input_does_not_change_outcomes", first.get_health() == 100.0 and second.get_health() == 100.0 and session.manager.score_a == 0 and session.manager.score_b == 0)
	session.input_rate_limit = 90.0
	session.input_burst_limit = 120.0
	# Refill bucket and allow queued valid sequence numbers to settle after flood.
	_stage("idle")
	await _seconds(1.5)
	_position_players(first, second, Vector3(0, 1, -4))
	_stage("far")
	await _seconds(0.9)
	_check("remote_attack_misses_out_of_range", second.get_health() == 100.0)
	_position_players(first, second, Vector3(0, 1, 1.5))
	_stage("behind")
	await _seconds(0.9)
	_check("remote_attack_misses_outside_arc", second.get_health() == 100.0)
	_position_players(first, second, Vector3(0, 1, -1.5))
	_stage("hit")
	_check("remote_attack_hits", await _wait_until(func(): return second.get_health() < 100.0))
	await _seconds(0.15)
	_check("server_cooldown_rejects_repeated_attacks", second.get_health() == 75.0)
	_check("server_self_hit_excluded", first.get_health() == 100.0)
	_stage("lethal")
	_check("server_kill_scores_once", await _wait_until(func(): return session.manager.score_a == 1))
	_check("server_death_disables_player", second.get_node("Combatant").is_dead() and not second.get_node("Mesh").visible)
	_stage("respawn")
	_check("server_respawns_player", await _wait_until(func(): return not second.get_node("Combatant").is_dead()))
	_check("server_restores_health_and_spawn", second.get_health() == 100.0 and second.position.distance_to(Vector3(6, 1, 6)) < 0.05)
	# Both peers submit attacks simultaneously; the server applies the existing tick order.
	_position_players(first, second, Vector3(0, 1, -1.5))
	_stage("simultaneous")
	_check("both_peers_can_damage", await _wait_until(func(): return first.get_health() < 100.0 and second.get_health() < 100.0))
	_stage("idle")
	await _seconds(0.2)
	first.get_node("Health").reset()
	second.get_node("Health").reset()
	_position_players(first, second, Vector3(0, 1, -1.5))
	_stage("finish")
	_check("server_determines_match_result", await _wait_until(func(): return session.manager.phase == 2))
	_check("score_limit_winner", session.manager.score_a == 2 and session.manager.score_b == 0 and session.winner == 0)
	_stage("ended")
	var end_position: Vector3 = first.position
	var end_hp: float = first.get_health()
	await _seconds(0.8)
	_check("post_match_requests_cannot_mutate_game", first.position == end_position and first.get_health() == end_hp and session.manager.score_a == 2 and second.get_node("Combatant").is_dead())
	_stage("done")
	await _seconds(0.8)

func _client_test() -> void:
	_check("client_connects_and_receives_two_players", await _wait_until(func(): return session.connected and session.players.size() == 2))
	if session.players.size() != 2:
		return
	var id: int = session.multiplayer.get_unique_id()
	var local: Dictionary = session.players[id]
	_check("local_health_bound_to_owning_peer", session.hud._health == local.body.get_node("Health"))
	_check("replica_does_not_simulate", not local.body.is_physics_processing() and not local.body.has_node("Combatant") and local.body.get_node("Health").network_replica)
	# A client cannot mutate its HP through the local damage API.
	local.body.apply_damage(999.0, local.body)
	_check("replica_cannot_apply_damage", local.body.get_health() == 100.0)
	var deadline := Time.get_ticks_msec() + 30000
	while Time.get_ticks_msec() < deadline and not session.status_text.ends_with("done"):
		await physics_frame
		if not session.connected:
			break
		var stage: String = session.status_text.trim_prefix("TEST:")
		if stage != _last_stage:
			_last_stage = stage
			_stage_started = Time.get_ticks_msec()
			if stage == "invalid" and local.team == 0:
				# All probes use real client -> server RPCs, with no claimed player ID.
				session._submit_input.rpc_id(1, session._sequence, Vector2(100, 0), 0.0, false, false, false)
				session._submit_input.rpc_id(1, session._sequence + 1, Vector2.ZERO, NAN, false, false, false)
				session._submit_input.rpc_id(1, -1, Vector2.ZERO, 0.0, false, false, false)
		# Spread a flood over frames so ENet's unreliable-ordering does not coalesce
		# the probe into only one packet. This exercises the server's token bucket.
		if stage == "invalid" and local.team == 0:
			for i in 20:
				session._submit_input.rpc_id(1, -1, Vector2.ZERO, 0.0, false, false, false)
		if stage == "disconnect" and local.team == 1:
			session._peer.get_peer(1).peer_disconnect()
			await _seconds(0.2)
			_check("client_can_disconnect", true)
			return
		var move := Vector2.ZERO
		var attack := false
		var yaw := 0.0
		if stage == "motion" and local.team == 0:
			move = Vector2(1, 0)
		if local.team == 0 and stage in ["far", "behind", "hit", "lethal", "simultaneous", "finish", "ended"]:
			attack = true
		if stage == "simultaneous" and local.team == 1:
			attack = true
			yaw = PI
		if stage not in ["stale", "invalid"]:
			session.send_controls(move, yaw, false, false, attack)
		if stage == "motion":
			if not _has_start:
				_movement_start = local.body.position
				_has_start = true
			if local.body.position.distance_to(_movement_start) > 0.3:
				seen.movement = true
		if local.body.get_health() < 100.0:
			seen.hurt = true
		if local.body.get_health() == 0.0:
			seen.death = true
		if seen.has("death") and local.body.get_health() == 100.0:
			seen.respawn = true
		if stage == "ended":
			seen.result = session.manager.phase == 2 and session.hud.get_node("ResultLabel").text == "TEAM A WINS"
		if stage == "timeout_result":
			seen.draw = session.manager.phase == 2 and session.hud.get_node("ResultLabel").text == "DRAW"
		if not session.connected:
			break
	if scenario == "timeout":
		_check("client_receives_timer_result", seen.get("draw", false))
	elif scenario == "disconnect":
		_check("remaining_client_observes_disconnect_end", session.manager.phase == 2 and session.winner == -1)
		_check("remaining_client_observes_server_loss", not session.connected and session.players.is_empty() and session.status_text.begins_with("Server disconnected"))
	else:
		_check("client_observes_server_result", seen.get("result", false))
		if local.team == 0:
			_check("client_observes_authoritative_movement", seen.get("movement", false))
		else:
			_check("client_observes_damage_death_respawn", seen.get("hurt", false) and seen.get("death", false) and seen.get("respawn", false))
		_check("hud_matches_authoritative_hp", session.hud.get_node("HealthBar").value == local.body.get_health())
		_check("client_received_many_snapshots", session._last_snapshot_tick > 20)
