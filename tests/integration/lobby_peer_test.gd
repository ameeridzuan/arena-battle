extends SceneTree
## Independent ENet processes exercise the same lobby requests used by the screen.
const SCENE := preload("res://scenes/multiplayer/MultiplayerArena.tscn")
var session: Node
var role := 0
var count := 2
var report := ""
var checks: Array[bool] = []
var seen_stage := ""
var leave_test := false

func _init() -> void:
	_run.call_deferred()

func check(label: String, passed: bool) -> void:
	checks.append(passed)
	print("CHECK ", label, "=", passed)

func wait_for(predicate: Callable, seconds: float = 120.0) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000)
	while not predicate.call() and Time.get_ticks_msec() < deadline:
		await process_frame
	return predicate.call()

func stage(value: String) -> void:
	session.status_text = "TEST:" + value
	session._broadcast_snapshot()

func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--leave-test":
			leave_test = true
		elif arg.begins_with("--role="):
			role = arg.get_slice("=", 1).to_int()
		elif arg.begins_with("--count="):
			count = arg.get_slice("=", 1).to_int()
		elif arg.begins_with("--report="):
			report = arg.trim_prefix("--report=")
	session = SCENE.instantiate()
	session.lobby_enabled = true
	session.capture_local_controls = false
	if role == 1:
		session.host_token = "lobby-test-owner"
	root.add_child(session)
	if role == 0:
		await server_test()
	else:
		await client_test()
	var passed := not checks.is_empty() and not checks.has(false)
	var file := FileAccess.open(report, FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed": passed, "checks": checks.size(), "role": role, "players": count}))
	file.close()
	quit(0 if passed else 1)

func server_test() -> void:
	check("all players connected and loaded", await wait_for(func():
		if session.players.size() != count or session.lobby_host_id == 0:
			return false
		for record in session.players.values():
			if not record.ready:
				return false
		return true))
	if session.players.size() != count:
		return
	check("does not auto start", session.manager.phase == 0)
	check("capacity four", session.required_players == 4)
	for record in session.players.values():
		check("skills disabled while waiting", not record.body.get_node("CharacterSkills").request_skill())
	check("unready host cannot start", not session._accept_lobby_start(session.lobby_host_id))
	check("unknown player cannot select", not session._accept_lobby_selection(-1, 0, 0, true))
	var owner: Dictionary = session.players[session.lobby_host_id]
	check("invalid team rejected", not session._accept_lobby_selection(session.lobby_host_id, 8, 0, false))
	check("invalid character rejected", not session._accept_lobby_selection(session.lobby_host_id, owner.team, 8, false))
	if count >= 3:
		var counts := [0, 0]
		for record in session.players.values():
			counts[record.team] += 1
		var full: int = 0 if counts[0] == 2 else 1
		for id in session.players:
			if session.players[id].team != full:
				check("third teammate rejected", not session._accept_lobby_selection(id, full, 0, false))
				break
	stage("choose")
	check("character choices reach server", await wait_for(func():
		for record in session.players.values():
			if int(record.body.get_node("Mesh").character) != 1 - record.team:
				return false
		return true))
	# Exercise team change and reassigned respawn slots without exceeding two per side.
	if count == 3:
		var counts := [0, 0]
		for record in session.players.values():
			counts[record.team] += 1
		var full: int = 0 if counts[0] == 2 else 1
		for id in session.players:
			var record: Dictionary = session.players[id]
			if record.team == full:
				check("team change accepted", session._accept_lobby_selection(id, 1 - full, 1 - full, false))
				check("respawn team updated", record.body.get_node("Combatant").team_id == 1 - full)
				break
	stage("ready")
	check("ready requests arrive", await wait_for(func(): return session._lobby_block_reason().is_empty()))
	if leave_test:
		stage("leave")
		check("leaver removed from lobby", await wait_for(func(): return session.players.size() == count - 1, 20.0))
		count -= 1
		check("leave invalidates readiness", not session._lobby_block_reason().is_empty())
		for record in session.players.values():
			check("remaining player readiness reset", not record.lobby_ready)
		stage("ready_again")
		check("remaining players can ready again", await wait_for(func(): return session._lobby_block_reason().is_empty()))
	stage("gueststart")
	await create_timer(0.8).timeout
	check("guest cannot start", session.manager.phase == 0)
	stage("hoststart")
	check("host starts without four required", await wait_for(func(): return session.manager.phase == 1, 15.0))
	check("full roster starts", session.players.size() == count)
	var slots := {}
	for id in session.players:
		var record: Dictionary = session.players[id]
		var key := "%d:%d" % [record.team, record.slot]
		check("distinct team spawn " + key, not slots.has(key))
		slots[key] = true
		check("selection locked in match", not session._accept_lobby_selection(id, 1 - record.team, 0, false))
	stage("skills")
	check("all lobby players can activate selected skill", await wait_for(func():
		for record in session.players.values():
			var selected: int = record.body.get_node("Mesh").character
			if record.body.get_node("CharacterSkills").cooldowns[selected] <= 0:
				return false
		return true, 20.0))
	for record in session.players.values():
		record.done_seq = record.seq
	stage("done")
	check("all clients acknowledge completion", await wait_for(func():
		for record in session.players.values():
			if record.seq <= record.done_seq:
				return false
		return true, 30.0))
	await create_timer(0.5).timeout

func client_test() -> void:
	check("client receives lobby", await wait_for(func(): return session.connected and session.lobby_roster.size() == count and session.players.size() == count))
	if session.players.size() != count:
		return
	var id: int = session._local_peer_id
	check("host identity", (session.lobby_host_id == id) == (role == 1))
	check("lobby screen shown", session._lobby_screen.panel.visible)
	check("cursor free in lobby", Input.mouse_mode == Input.MOUSE_MODE_VISIBLE)
	check("lobby camera input disabled", not session.players[id].body.get_node("CameraPivot").local_input_enabled)
	var deadline := Time.get_ticks_msec() + 120000
	while Time.get_ticks_msec() < deadline:
		await process_frame
		var current: String = session.status_text
		if current == "TEST:done":
			break
		if current == seen_stage:
			continue
		seen_stage = current
		var local: Dictionary = {}
		for record in session.lobby_roster:
			if record.id == id:
				local = record
		if local.is_empty():
			continue
		match current:
			"TEST:choose":
				session.select_lobby(local.team, 1 - local.team, false)
			"TEST:leave":
				if leave_test and role == 4:
					session._peer.close()
					check("client leaves waiting lobby", true)
					return
			"TEST:ready", "TEST:ready_again":
				await create_timer(0.2).timeout
				session.select_lobby(local.team, local.character, true)
			"TEST:gueststart":
				if role != 1:
					session.start_lobby_match()
			"TEST:skills":
				session.send_controls(Vector2.ZERO, 0.0, false, false, false, session.SKILL)
			"TEST:hoststart":
				if role == 1:
					session.start_lobby_match()
	check("running state replicated", session.manager.phase == 1)
	check("lobby hidden when playing", not session._lobby_screen.panel.visible)
	if not session.players.has(id):
		check("local replica retained", false)
		return
	check("camera enabled in match", session.players[id].body.get_node("CameraPivot").local_input_enabled)
	check("own health bound", session.hud._health == session.players[id].body.get_node("Health"))

	# Keep clients alive until the server has received every completion acknowledgement.
	var finish_deadline := Time.get_ticks_msec() + 35000
	while session.connected and Time.get_ticks_msec() < finish_deadline:
		session.send_controls(Vector2.ZERO, 0.0, false, false, false)
		await physics_frame
