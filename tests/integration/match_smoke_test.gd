extends SceneTree
## M3 integration gate. Run with --headless --path <ArenaBattle> --script res://tests/integration/match_smoke_test.gd
## Each case instantiates the authored scene anew. M1/M2 are separate regression commands.
const MAIN := preload("res://scenes/main/Main.tscn")
var _results: Array[bool] = []

func _init() -> void:
	_run()

func _check(label: String, passed: bool) -> void:
	print("CHECK ", label, " = ", passed)
	_results.append(passed)

func _frames(count: int) -> void:
	for i in count:
		await physics_frame

func _seconds(seconds: float) -> void:
	await create_timer(seconds).timeout
	await _frames(2)

func _setup(duration: float = 180.0, limit: int = 5) -> Dictionary:
	var main: Node = MAIN.instantiate()
	var manager: Variant = main.get_node("MatchManager")
	manager.time_limit = duration
	manager.score_limit = limit
	var events := {"started": 0, "scores": [], "deaths": 0, "winners": [], "respawns": []}
	manager.match_started.connect(func(): events.started += 1)
	manager.score_changed.connect(func(a: int, b: int): events.scores.append(Vector2i(a, b)))
	manager.player_died.connect(func(): events.deaths += 1)
	manager.match_ended.connect(func(winner: int): events.winners.append(winner))
	var player: Variant = main.get_node("Player")
	var first: Variant = main.get_node("Opponent1")
	var second: Variant = main.get_node("Opponent2")
	for body in [player, first, second]:
		body.get_node("Combatant").combatant_respawned.connect(func(team: int): events.respawns.append(team))
	_check("initial_waiting", manager.phase == 0 and manager.time_remaining == 0.0)
	root.add_child(main)
	await _frames(12)
	return {"main": main, "manager": manager, "player": player,
		"first": first, "second": second, "events": events}

func _cleanup(ctx: Dictionary) -> void:
	ctx.main.queue_free()
	await _frames(3)

func _disabled(body: Variant) -> bool:
	return body.get_node("Combatant").is_dead() \
		and body.get_node("CollisionShape3D").disabled \
		and not body.get_node("Mesh").visible \
		and not body.is_physics_processing() \
		and not body.get_node("AttackHitbox").is_physics_processing()

func _enabled(body: Variant) -> bool:
	return not body.get_node("Combatant").is_dead() \
		and not body.get_node("CollisionShape3D").disabled \
		and body.get_node("Mesh").visible \
		and body.is_physics_processing() \
		and body.get_node("AttackHitbox").is_physics_processing() \
		and is_equal_approx(body.get_health(), body.get_node("Health").max_health)

func _faces_center(body: Node3D) -> bool:
	var forward := -body.global_basis.z
	forward.y = 0.0
	var to_center := Vector3(-body.global_position.x, 0.0, -body.global_position.z)
	var alignment := forward.normalized().dot(to_center.normalized())
	print("DIAG authored_facing body=", body.name, " position=", body.global_position,
		" basis=", body.global_basis, " forward=", forward, " to_center=", to_center, " dot=", alignment)
	return alignment > 0.999

func _run() -> void:
	await _case_start()
	await _case_kill()
	await _case_auto_attack()
	await _case_player_respawn()
	await _case_opponent_respawn()
	await _case_score_limit()
	await _case_time_expiry()
	await _case_post_match()
	await _case_null_source()
	await _case_rejected_kills()
	var passed := not _results.has(false)
	print("ALL_TESTS_PASS=", passed)
	quit(0 if passed else 1)

func _case_start() -> void:
	var c := await _setup()
	_check("match_starts", c.manager.phase == 1 and c.manager.time_remaining > 0.0 and c.events.started == 1)
	_check("authored_defaults", c.manager.time_limit == 180.0 and c.manager.score_limit == 5
		and c.player.get_node("Combatant").respawn_delay == 3.0
		and c.first.get_node("AttackHitbox").auto_attack
		and c.first.get_node("AttackHitbox").attack_cooldown == 1.5)
	_check("hud_initial_state", c.main.get_node("HUD/ScoreLabel").text == "TEAM A: 0  |  TEAM B: 0"
		and c.main.get_node("HUD/TimerLabel").text == "3:00"
		and not c.main.get_node("HUD/ResultLabel").visible)
	_check("authored_opponents_face_center", _faces_center(c.first) and _faces_center(c.second))
	await _cleanup(c)

func _case_kill() -> void:
	var c := await _setup()
	c.first.apply_damage(999.0, c.player)
	await _frames(2)
	_check("kill_opponent_scores", c.manager.score_a == 1 and c.manager.score_b == 0
		and c.events.scores == [Vector2i(1, 0)] and c.events.deaths == 0)
	_check("hud_score_update", c.main.get_node("HUD/ScoreLabel").text == "TEAM A: 1  |  TEAM B: 0")
	await _cleanup(c)

func _case_auto_attack() -> void:
	var c := await _setup()
	# The authored opponent facing controls the arc. Keep clear of its physical box.
	var forward: Vector3 = -c.first.global_basis.z
	c.player.global_position = c.first.global_position + forward.normalized() * 1.5
	c.player.velocity = Vector3.ZERO
	await _seconds(1.7)
	_check("opponent_damages_player", c.player.get_health() < 100.0 and c.player.get_health() > 0.0)
	await _seconds(6.1)
	_check("opponent_kills_player", c.player.get_node("Combatant").is_dead()
		and c.manager.score_a == 0 and c.manager.score_b == 1
		and c.events.deaths == 1 and c.events.scores == [Vector2i(0, 1)])
	_check("auto_attack_death_disabled", _disabled(c.player))
	await _cleanup(c)

func _case_player_respawn() -> void:
	var c := await _setup()
	c.player.global_position = Vector3(0, 1, 0)
	c.player.apply_damage(999.0, c.first)
	await _frames(2)
	_check("player_disabled", _disabled(c.player))
	await _seconds(0.2)
	_check("player_stays_dead_before_delay", _disabled(c.player) and c.events.respawns.is_empty())
	await _seconds(3.0)
	var spawn: Node3D = get_first_node_in_group("spawn_team_0")
	var offset: Vector3 = c.player.global_position - spawn.global_position
	_check("player_respawn", _enabled(c.player) and Vector2(offset.x, offset.z).length() < 0.05
		and absf(offset.y) < 0.15 and c.events.respawns == [0]
		and c.player.get_node("Health").last_damage_source == null)
	await _cleanup(c)

func _case_opponent_respawn() -> void:
	var c := await _setup()
	# Exercise both spawn indices, including the second team-B marker.
	for opponent in [c.first, c.second]:
		opponent.global_position = Vector3(0, 1, 0)
		opponent.apply_damage(999.0, c.player)
	await _frames(2)
	_check("opponents_disabled", _disabled(c.first) and _disabled(c.second))
	await _seconds(3.2)
	var spawns := get_nodes_in_group("spawn_team_1")
	_check("opponent_respawn", _enabled(c.first) and _enabled(c.second)
		and c.first.global_position.distance_to(spawns[0].global_position) < 0.01
		and c.second.global_position.distance_to(spawns[1].global_position) < 0.01
		and c.events.respawns == [1, 1])
	await _cleanup(c)

func _case_score_limit() -> void:
	for team in [0, 1]:
		var c := await _setup(180.0, 2)
		c.manager.register_kill(team, 1 - team)
		_check("below_score_limit_%d" % team, c.manager.phase == 1)
		c.manager.register_kill(team, 1 - team)
		_check("score_limit_ends_match_%d" % team, c.manager.phase == 2
			and c.manager.get_score(team) == 2 and c.events.winners == [team])
		_check("hud_score_winner_%d" % team, c.main.get_node("HUD/ResultLabel").visible
			and c.main.get_node("HUD/ResultLabel").text == ("TEAM A WINS" if team == 0 else "TEAM B WINS"))
		await _cleanup(c)

func _case_time_expiry() -> void:
	for winner in [-1, 0, 1]:
		var c := await _setup(1.0)
		if winner >= 0:
			c.manager.register_kill(winner, 1 - winner)
		await _seconds(1.1)
		_check("time_expiry_ends_match_%d" % winner, c.manager.phase == 2
			and c.manager.time_remaining == 0.0 and c.events.winners == [winner])
		var expected: String = "DRAW" if winner == -1 else ("TEAM A WINS" if winner == 0 else "TEAM B WINS")
		_check("hud_time_winner_%d" % winner, c.main.get_node("HUD/ResultLabel").visible
			and c.main.get_node("HUD/ResultLabel").text == expected
			and c.main.get_node("HUD/TimerLabel").text == "0:00")
		await _cleanup(c)

func _case_post_match() -> void:
	var c := await _setup(180.0, 2)
	for body in [c.first, c.second, c.player]:
		body.get_node("Combatant").respawn_delay = 0.25
	# Cover a pending respawn timer, the winning kill and a death after match end.
	c.first.apply_damage(999.0, c.player)
	c.second.apply_damage(999.0, c.player)
	var scores: Array = c.events.scores.duplicate()
	c.manager.register_kill(1, 0)
	c.manager.register_kill(0, 1)
	c.player.apply_damage(999.0, c.first)
	await _seconds(0.5)
	_check("post_match_no_scoring", c.manager.score_a == 2 and c.manager.score_b == 0
		and c.events.scores == scores and c.events.winners == [0])
	_check("post_match_no_respawns", _disabled(c.first) and _disabled(c.second)
		and _disabled(c.player) and c.events.respawns.is_empty())
	await _cleanup(c)

func _case_null_source() -> void:
	var c := await _setup()
	c.first.get_node("Combatant").respawn_delay = 0.2
	c.first.apply_damage(999.0, null)
	await _frames(2)
	_check("null_source_death_no_score", _disabled(c.first) and c.manager.score_a == 0
		and c.manager.score_b == 0 and c.events.scores.is_empty() and c.events.deaths == 0)
	await _seconds(0.35)
	_check("null_source_respawn", _enabled(c.first) and c.events.respawns == [1])
	await _cleanup(c)

func _case_rejected_kills() -> void:
	var c := await _setup(180.0, 1)
	for pair in [Vector2i(0, 0), Vector2i(1, 1), Vector2i(-1, 0),
		Vector2i(2, 0), Vector2i(0, -1), Vector2i(1, 2)]:
		c.manager.register_kill(pair.x, pair.y)
	_check("reject_same_or_unknown_team", c.manager.score_a == 0 and c.manager.score_b == 0
		and c.manager.phase == 1 and c.events.scores.is_empty()
		and c.events.deaths == 0 and c.events.winners.is_empty())
	await _cleanup(c)
