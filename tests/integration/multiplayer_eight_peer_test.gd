extends SceneTree
## Eight real ENet clients. Positioning and shortened rules below are explicit server fixtures.
const SCENE := preload("res://scenes/multiplayer/MultiplayerArena.tscn")
var session: Node
var role := ""
var report_path := ""
var control_dir := ""
var results: Array[bool] = []

func _init() -> void:
	_run.call_deferred()

func _check(label: String, passed: bool) -> void:
	print("CHECK ", label, " = ", passed)
	results.append(passed)

func _wait_until(predicate: Callable, seconds: float = 30.0) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000)
	while not predicate.call() and Time.get_ticks_msec() < deadline:
		await process_frame
	return predicate.call()

func _seconds(seconds: float) -> void:
	await create_timer(seconds).timeout

func _marker(name: String) -> void:
	var file := FileAccess.open(control_dir.path_join(name), FileAccess.WRITE)
	file.store_string("ready")

func _stage(name: String, attacker: int = 0) -> void:
	session.status_text = "TEST:%s:%d" % [name, attacker]
	session._broadcast_snapshot()

func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="):
			role = arg.trim_prefix("--role=")
		elif arg.begins_with("--report="):
			report_path = arg.trim_prefix("--report=")
		elif arg.begins_with("--control-dir="):
			control_dir = arg.trim_prefix("--control-dir=")
	session = SCENE.instantiate()
	session.capture_local_controls = false
	root.add_child(session)
	if role == "server":
		await _server_test()
	elif role == "extra":
		_check("ninth_peer_rejected", await _wait_until(func(): return session.status_text.begins_with("Connection failed") or session.status_text.begins_with("Server disconnected"), 12.0))
		_check("ninth_peer_has_no_roster", session.players.is_empty())
	else:
		await _client_test()
	var passed := not results.is_empty() and not results.has(false)
	var file := FileAccess.open(report_path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"role": role, "passed": passed, "checks": results.size()}))
	file.close()
	quit(0 if passed else 1)

func _server_test() -> void:
	_marker("server-ready")
	_check("seven_clients_register", await _wait_until(func(): return session.players.size() == 7, 60.0))
	await _seconds(0.5)
	_check("seven_players_do_not_start_match", session.players.size() == 7 and session.manager.phase == 0)
	_marker("seven-ready")
	_check("eighth_player_starts_match", await _wait_until(func(): return session.players.size() == 8 and session.manager.phase == 1))
	if session.players.size() != 8:
		return
	var teams := [0, 0]
	var spawn_positions: Array[Vector3] = []
	var slots := {}
	var attacker_id := 0
	var friend_id := 0
	var enemy_id := 0
	for id in session.players:
		var record: Dictionary = session.players[id]
		teams[record.team] += 1
		spawn_positions.append(record.body.position)
		slots["%d:%d" % [record.team, record.slot]] = true
		if record.team == 0 and record.slot == 0:
			attacker_id = id
		elif record.team == 0 and record.slot == 1:
			friend_id = id
		elif record.team == 1 and record.slot == 2:
			enemy_id = id
	_check("balanced_four_per_team", teams == [4, 4])
	_check("eight_distinct_team_slots", slots.size() == 8)
	var separated := true
	for i in spawn_positions.size():
		for j in range(i + 1, spawn_positions.size()):
			if spawn_positions[i].distance_to(spawn_positions[j]) < 1.0:
				separated = false
	_check("eight_separated_spawn_positions", separated)
	_marker("eight-ready")
	_check("extra_client_finished_probe", await _wait_until(func(): return FileAccess.file_exists(control_dir.path_join("extra.json")), 25.0))
	_check("rejected_join_keeps_running_roster", session.players.size() == 8 and session.manager.phase == 1)
	var attacker: Variant = session.players[attacker_id].body
	var friend: Variant = session.players[friend_id].body
	var enemy: Variant = session.players[enemy_id].body
	var enemy_spawn: Vector3 = enemy.position
	# Fixture places combatants precisely; actual attacks travel through client RPCs.
	for id in session.players:
		var body: Variant = session.players[id].body
		body.position = Vector3(8 + session.players[id].team * 4, 1, -12 + session.players[id].slot * 3)
		body.velocity = Vector3.ZERO
	attacker.position = Vector3(0, 1, 0)
	friend.position = Vector3(0, 1, -1.5)
	# A (attack-follows-facing): orient the attacker toward world -Z (its Mesh front) where the
	# friend/enemy fixtures sit, so its remote swings land. It never moves, so this yaw persists.
	attacker.get_node("Mesh").rotation.y = PI
	_stage("friendly", attacker_id)
	await _seconds(1.0)
	_check("friendly_remote_swings_execute", session.players[attacker_id].swings > 0)
	_check("friendly_melee_does_not_damage_or_score", friend.get_health() == 100 and session.manager.score_a == 0 and session.manager.score_b == 0)
	_stage("idle")
	await _seconds(0.4)
	friend.position = Vector3(-12, 1, 12)
	# Let physics remove the teammate from the target position before teleporting the enemy.
	await _seconds(0.15)
	enemy.position = Vector3(0, 1, -1.5)
	enemy.get_node("Combatant").respawn_delay = 1.2
	session.manager.score_limit = 2
	_stage("enemy", attacker_id)
	await _seconds(1.0)
	_check("enemy_remote_melee_damages", await _wait_until(func(): return enemy.get_health() < 100.0))
	_check("enemy_kill_scores_for_attacker_team", await _wait_until(func(): return session.manager.score_a == 1))
	_check("enemy_death_authoritative", enemy.get_node("Combatant").is_dead())
	_stage("respawn")
	_check("enemy_respawns", await _wait_until(func(): return not enemy.get_node("Combatant").is_dead()))
	var actual_spawn: Vector3 = enemy.position
	_check("respawn_returns_to_assigned_slot", Vector2(actual_spawn.x, actual_spawn.z).distance_to(Vector2(enemy_spawn.x, enemy_spawn.z)) < 0.1 and enemy.get_health() == 100)
	enemy.position = Vector3(0, 1, -1.5)
	enemy.velocity = Vector3.ZERO
	_stage("finish", attacker_id)
	_check("server_ends_at_score_limit", await _wait_until(func(): return session.manager.phase == 2))
	_check("team_result_correct", session.winner == 0 and session.manager.score_a == 2 and session.manager.score_b == 0)
	_stage("ended", attacker_id)
	await _seconds(1.0)
	_check("ended_match_scores_stay_fixed", session.manager.score_a == 2 and enemy.get_node("Combatant").is_dead())
	_stage("done")
	await _seconds(1.5)

func _client_test() -> void:
	_check("client_receives_eight_player_roster", await _wait_until(func(): return session.players.size() == 8, 100.0))
	if session.players.size() != 8:
		return
	var id: int = session.multiplayer.get_unique_id()
	var local: Dictionary = session.players[id]
	_check("own_hud_health_binding", session.hud._health == local.body.get_node("Health"))
	var teams := [0, 0]
	for record in session.players.values():
		teams[record.team] += 1
	_check("client_observes_balanced_teams", teams == [4, 4])
	var saw_result := false
	var saw_full_result := false
	var deadline := Time.get_ticks_msec() + 70000
	while session.connected and Time.get_ticks_msec() < deadline:
		await physics_frame
		var stage: String = session.status_text.get_slice(":", 1)
		var attacker: int = session.status_text.get_slice(":", 2).to_int()
		if stage == "done":
			break
		session.send_controls(Vector2.ZERO, 0.0, false, false, id == attacker and stage in ["friendly", "enemy", "finish", "ended"])
		if stage == "ended":
			saw_full_result = saw_full_result or session.players.size() == 8
			saw_result = session.manager.phase == 2 and session.manager.score_a == 2 and session.winner == 0 and session.hud.get_node("ResultLabel").text == "TEAM A WINS"
	_check("client_receives_authoritative_team_result", saw_result)
	_check("client_retains_eight_players_through_result", saw_full_result)
	_check("client_receives_snapshots", session._last_snapshot_tick > 20)
