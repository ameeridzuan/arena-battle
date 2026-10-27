extends Node3D
## M5 eight-player team match; loopback by default, LAN by explicit address. All RPCs live at /root/MultiplayerArena, authority=1.
## Clients send bounded controls; only the server simulates gameplay and writes outcomes.

signal snapshot_received
signal lobby_updated
const LOBBY_SCREEN := preload("res://scripts/multiplayer/waiting_lobby.gd")
const PLAYER := preload("res://scenes/characters/Player.tscn")
const HUD := preload("res://scenes/ui/HUD.tscn")
const MATCH := preload("res://scripts/match/match_manager.gd")
const REPLICA_MATCH := preload("res://scripts/multiplayer/replica_match_state.gd")
const MOTION_PLAYER := preload("res://scripts/player/local_motion_test_player.gd")
const MOTION_CONTROLS := preload("res://scripts/characters/motion_test_controls.gd")
const WEAPON := preload("res://scripts/combat/local_weapon_attacker.gd")
const MOTION_STATE := preload("res://scripts/multiplayer/network_motion_state.gd")
const BOLT := preload("res://scripts/characters/test_energy_bolt.gd")
const IMPACT := preload("res://scripts/combat/weapon_impact.gd")
const GRENADE := preload("res://scripts/combat/stun_grenade.gd")
const INTERACT := 1
const DROP := 2
const DODGE := 4
const PARRY := 8
const CAST := 16
const SWITCH := 32
const SKILL := 64
const SERVER_ID := 1
const LOOPBACK := "127.0.0.1"
const MAX_PLAYERS := 8
const TEAM_SIZE := 4
## Team identity colours (used for the overhead marker; the authored model materials are kept).
const TEAM_COLORS := [Color(0.2, 0.55, 1.0), Color(1.0, 0.55, 0.15)]
const MAX_SEQUENCE_ADVANCE := 1024

@export var port: int = 24560
@export var bind_address: String = LOOPBACK
@export var server_address: String = LOOPBACK
## Two-player mode remains available for quick regression/playtests.
@export var required_players: int = 8
## Opt-in preserves the existing direct 2/8-player regression sessions.
@export var lobby_enabled: bool = false
var host_token: String = ""
var _server_host_token: String = ""
var lobby_host_id: int = 0
var lobby_roster: Array = []
var lobby_notice: String = ""
var lobby_start_reason: String = "Waiting for players to connect."
var _lobby_screen: CanvasLayer
var _lobby_revision: int = 0
var _last_lobby_revision: int = -1
var _lobby_request_times: Dictionary = {}
@export var snapshot_hz: float = 20.0
@export var input_timeout_ms: int = 250
@export var input_rate_limit: float = 90.0
@export var input_burst_limit: float = 120.0
## Diagnostic control delay; applied only on clients. No server outcome changes.
@export var simulated_input_delay_ms: int = 0
@export var connection_timeout_ms: int = 60000

var server_mode: bool = false
var connected: bool = false
var status_text: String = "Connecting to local server..."
var players: Dictionary = {}
var manager: Node
var hud: CanvasLayer
var winner: int = -1
var rejected_inputs: int = 0
var rate_limited_inputs: int = 0
var rtt_ms: int = 0
var _peer: ENetMultiplayerPeer
var _status_label: Label
var _sequence: int = 0
var _snapshot_tick: int = 0
var _last_snapshot_tick: int = -1
var _snapshot_elapsed: float = 0.0
var _ping_elapsed: float = 0.0
var _connection_started: int = 0
var _local_peer_id: int = 0
var _delayed_inputs: Array[Dictionary] = []
## Tests drive the same send_controls API without keyboard state.
var capture_local_controls: bool = true
var _bolts: Dictionary = {}
var _grenades: Dictionary = {}
var _impacts: Array = []
var _impact_sequence := 0
var _last_impact := 0
var _local_aim := false
var _local_ready_sent := false

func _ready() -> void:
	for binding in [["traversal_interact", KEY_E], ["traversal_drop", KEY_C], ["motion_dodge", KEY_Q], ["motion_parry", KEY_F], ["motion_cast", KEY_R], ["motion_switch_character", KEY_TAB], ["character_skill", KEY_G]]:
		if not InputMap.has_action(binding[0]):
			InputMap.add_action(binding[0])
			var key := InputEventKey.new()
			key.physical_keycode = binding[1]
			InputMap.action_add_event(binding[0], key)
	for arg in OS.get_cmdline_user_args():
		if arg == "--lobby":
			lobby_enabled = true
		elif arg.begins_with("--lobby-token="):
			_server_host_token = arg.trim_prefix("--lobby-token=")
		elif arg == "--server":
			server_mode = true
		elif arg.begins_with("--port="):
			port = arg.get_slice("=", 1).to_int()
		elif arg.begins_with("--bind="):
			bind_address = arg.trim_prefix("--bind=")
		elif arg.begins_with("--connect="):
			server_address = arg.trim_prefix("--connect=")
		elif arg.begins_with("--players="):
			required_players = arg.trim_prefix("--players=").to_int()
		elif arg.begins_with("--input-delay-ms="):
			simulated_input_delay_ms = clampi(arg.get_slice("=", 1).to_int(), 0, 1000)
	if required_players not in [2, 4, 8] or port < 1024 or port > 65535:
		push_error("Use --players=2, --players=4 or --players=8 and a port from 1024 to 65535.")
		get_tree().quit(1)
		return
	if lobby_enabled:
		required_players = 4
	manager = Node.new()
	manager.set_script(MATCH if server_mode else REPLICA_MATCH)
	manager.name = "MatchManager"
	if server_mode:
		manager.auto_start = false
	add_child(manager)
	if server_mode:
		manager.match_ended.connect(_on_match_ended)
	else:
		hud = HUD.instantiate()
		hud.player_health_path = NodePath("")
		add_child(hud)
		hud.get_node("ControlsLabel").text = "Team Parkour Arena | WASD move | Shift run | Space jump / wall jump\nE grab / climb | A/D shimmy | C drop | Click melee / jump attack\nG character skill | V aim | R cast + burn | Q dash / dodge | F parry | Tab character | Esc cursor"
	if lobby_enabled and not server_mode:
		_lobby_screen = CanvasLayer.new()
		_lobby_screen.set_script(LOBBY_SCREEN)
		add_child(_lobby_screen)
	var layer := CanvasLayer.new()
	add_child(layer)
	_status_label = Label.new()
	_status_label.position = Vector2(16, 112)
	layer.add_child(_status_label)
	_peer = ENetMultiplayerPeer.new()
	var error: Error
	if server_mode:
		_peer.set_bind_ip(bind_address)
		# Clients communicate only with the authority. No peer-to-peer relay is needed.
		multiplayer.server_relay = false
		error = _peer.create_server(port, required_players, 3)
	else:
		error = _peer.create_client(server_address, port, 3)
	if error != OK:
		status_text = "Could not open network session (error %d)." % error
		return
	multiplayer.peer_connected.connect(func(id: int): print("NETWORK_PEER_CONNECTED=", id))
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	multiplayer.multiplayer_peer = _peer
	_connection_started = Time.get_ticks_msec()
	if server_mode:
		status_text = _waiting_status()
		print("M4_SERVER_READY port=", port, " players=", required_players, " bind=", bind_address)

func _physics_process(delta: float) -> void:
	if _peer == null or _peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		if not server_mode and Time.get_ticks_msec() - _connection_started > connection_timeout_ms and status_text.begins_with("Connecting"):
			_on_connection_failed()
		return
	if server_mode:
		_server_step(delta)
		_snapshot_elapsed += delta
		if _snapshot_elapsed >= 1.0 / snapshot_hz:
			_snapshot_elapsed = 0.0
			_broadcast_snapshot()
	elif connected:
		# ENet can begin disconnecting before SceneMultiplayer emits its disconnect signal.
		if _peer.get_peer(SERVER_ID).get_state() != ENetPacketPeer.STATE_CONNECTED:
			_delayed_inputs.clear()
			return
		if capture_local_controls and (not lobby_enabled or manager.phase == 1):
			var local: Dictionary = players.get(multiplayer.get_unique_id(), {})
			if not local.is_empty():
				var body: Node3D = local.body
				if Input.is_action_just_pressed("toggle_camera_lock"):
					_local_aim = not _local_aim
					body.camera_lock_behind = _local_aim
				var buttons := 0
				var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
				if captured:
					for binding in [["traversal_interact", INTERACT], ["traversal_drop", DROP], ["motion_dodge", DODGE], ["motion_parry", PARRY], ["motion_cast", CAST], ["motion_switch_character", SWITCH], ["character_skill", SKILL]]:
						if Input.is_action_just_pressed(binding[0]):
							buttons |= int(binding[1])
				send_controls(Input.get_vector("move_left", "move_right", "move_forward", "move_back"),
					body.get_node("CameraPivot").rotation.y, Input.is_action_pressed("run"),
					captured and Input.is_action_just_pressed("jump"), captured and Input.is_action_just_pressed("attack"), buttons, _local_aim, body.get_node("CameraPivot/CameraTilt").rotation.x)
		while not _delayed_inputs.is_empty() and _delayed_inputs[0].due <= Time.get_ticks_msec():
			var command: Dictionary = _delayed_inputs.pop_front()
			_submit_input.rpc_id(SERVER_ID, command.seq, command.move, command.yaw, command.run, command.jump, command.attack, command.buttons, command.aim, command.pitch)
		for record in players.values():
			var motor: RefCounted = record.body.traversal_motor
			if motor.mode == motor.Mode.CLIMB:
				motor.climb_progress = minf(1.0, motor.climb_progress + delta / maxf(motor._climb_duration, 0.1))
			if motor.mode == motor.Mode.HANG:
				motor.hang_elapsed += delta
			motor.wall_jump_elapsed = minf(motor.WALL_JUMP_POSE_DURATION, motor.wall_jump_elapsed + delta)
			record.body.get_node("AttackHitbox").present_network_trail()
		_ping_elapsed += delta
		if _ping_elapsed >= 1.0:
			_ping_elapsed = 0.0
			_ping.rpc_id(SERVER_ID, Time.get_ticks_msec())

func _process(_delta: float) -> void:
	if _status_label:
		var team_text := ""
		if players.has(_local_peer_id):
			team_text = "You: TEAM %s | " % ("A" if players[_local_peer_id].team == 0 else "B")
		_status_label.text = team_text + status_text + (" | RTT: %d ms | control delay: %d ms" % [rtt_ms, simulated_input_delay_ms] if connected and not server_mode else "")
		if players.has(_local_peer_id):
			_status_label.text += "\n" + players[_local_peer_id].body.get_node("CharacterSkills").describe()

func _on_connected() -> void:
	print("NETWORK_CONNECTED")
	connected = true
	_local_peer_id = multiplayer.get_unique_id()
	_peer.get_peer(SERVER_ID).set_timeout(16, 10000, 60000)
	status_text = "Connected; waiting for the roster..."
	_register_player.rpc_id(SERVER_ID, host_token)

@rpc("any_peer", "call_remote", "reliable", 1)
func _register_player(claim: String = "") -> void:
	if not server_mode:
		return
	var id := multiplayer.get_remote_sender_id()
	if id <= SERVER_ID or players.has(id):
		return
	_peer.get_peer(id).set_timeout(16, 10000, 60000)
	if players.size() >= required_players or players.size() >= MAX_PLAYERS or manager.phase != 0:
		_peer.disconnect_peer(id)
		return
	var counts := [0, 0]
	for record in players.values():
		counts[record.team] += 1
	var team: int = 0 if counts[0] <= counts[1] else 1
	var slot := 0
	var occupied: Array[int] = []
	for record in players.values():
		if record.team == team:
			occupied.append(record.slot)
	while slot in occupied:
		slot += 1
	if slot >= TEAM_SIZE:
		_peer.disconnect_peer(id)
		return
	if lobby_enabled and lobby_host_id == 0 and (_server_host_token.is_empty() or claim == _server_host_token):
		lobby_host_id = id
	var body := _spawn_player(id, team, slot)
	players[id] = {"body": body, "team": team, "slot": slot, "seq": -1,
		"move": Vector2.ZERO, "yaw": body.get_node("CameraPivot").rotation.y, "run": false, "jump": false, "attack": false,
		"last_input": Time.get_ticks_msec(), "bucket_time": Time.get_ticks_msec(), "tokens": input_burst_limit,
		"ready": false, "lobby_ready": false, "swings": 0, "buttons": 0, "aim": false, "pitch": 0.0}
	if lobby_enabled:
		_invalidate_lobby_ready()
		_publish_lobby()
	status_text = _waiting_status()
	_broadcast_snapshot()

@rpc("any_peer", "call_remote", "reliable", 1)
func _client_ready() -> void:
	if not server_mode or manager.phase != 0:
		return
	var id := multiplayer.get_remote_sender_id()
	if not players.has(id):
		return
	players[id].ready = true
	if not lobby_enabled:
		_peer.get_peer(id).set_timeout(8, 5000, 15000)
	if lobby_enabled:
		_publish_lobby()
		return
	var all_ready := players.size() == required_players
	for record in players.values():
		all_ready = all_ready and bool(record.get("ready", false))
	if all_ready:
		manager.start_match()
		status_text = "%dv%d match running" % [required_players / 2, required_players / 2]
	else:
		status_text = _waiting_status()
	_broadcast_snapshot()

func _waiting_status() -> String:
	if lobby_enabled:
		return "Lobby: %d/4 connected | waiting for host to start" % players.size()
	if players.size() == required_players:
		return "Loading characters - waiting for both clients to be ready..."
	return "Waiting for players: %d/%d | %s:%d" % [players.size(), required_players, bind_address, port]

func _spawn_player(id: int, team: int, slot: int = 0) -> CharacterBody3D:
	var body: CharacterBody3D = PLAYER.instantiate()
	body.set_script(MOTION_PLAYER)
	body.network_presentation_only = not server_mode
	body.name = str(id)
	body.external_control = true
	body.get_node("CharacterSkills").network_authority = server_mode
	body.collision_mask = 3
	var attack: Node = body.get_node("AttackHitbox")
	attack.set_script(WEAPON)
	attack.network_authority = server_mode
	if server_mode:
		var motion := Node.new()
		motion.name = "MotionTestControls"
		motion.set_script(MOTION_CONTROLS)
		motion.network_driven = true
		motion.network_authority = true
		body.add_child(motion)
	attack.external_control = true
	attack.friendly_fire = false
	attack.collision_mask = 2
	var camera: Node3D = body.get_node("CameraPivot")
	camera.local_input_enabled = not server_mode and id == _local_peer_id and (not lobby_enabled or manager.phase == 1)
	body.get_node("CameraPivot/CameraTilt/Camera3D").current = not server_mode and id == _local_peer_id
	# Both viewers use the authority's character identity, so rig poses and blade lengths match.
	# Team defaults are Arclight/Warden; accepted Tab switches replicate in snapshots.
	var mesh: Node = body.get_node("Mesh")
	mesh.character = team
	_add_team_marker(mesh, team)
	if server_mode:
		body.get_node("Combatant").team_id = team
		body.get_node("Combatant").spawn_index = slot
	else:
		body.get_node("Combatant").free()
		body.get_node("Health").network_replica = true
	var spawns := get_tree().get_nodes_in_group("spawn_team_%d" % team)
	var spawn: Node3D = spawns[slot]
	body.position = spawn.global_position
	camera.rotation.y = atan2(body.position.x, body.position.z)
	$Players.add_child(body, true)
	if server_mode:
		body.get_node("MotionTestControls").set_physics_process(false)
		attack.impact_presented.connect(_record_impact)
	if not server_mode:
		body.set_physics_process(false)
		attack.set_physics_process(false)
		body.get_node("CollisionShape3D").disabled = true
		if id == _local_peer_id:
			hud.bind_health(body.get_node("Health"))
	return body

## Small unshaded overhead orb in the team colour. Parented under `Mesh` so it follows the body,
## rotates harmlessly (a sphere), is hidden with the model on death, and picks up the damage
## flash like the rest of the skinned meshes.
func _add_team_marker(mesh: Node, team: int) -> void:
	var marker := MeshInstance3D.new()
	marker.name = "TeamMarker"
	var sphere := SphereMesh.new()
	sphere.radius = 0.12
	sphere.height = 0.24
	marker.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = TEAM_COLORS[team] if team >= 0 and team < TEAM_COLORS.size() else Color.WHITE
	marker.material_override = mat
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	marker.position = Vector3(0.0, 1.15, 0.0)
	mesh.add_child(marker)

func send_controls(movement: Vector2, yaw: float, running: bool, jump: bool, attack: bool, buttons: int = 0, aim: bool = false, pitch: float = 0.0) -> void:
	if server_mode or not connected:
		return
	_sequence += 1
	# Bound diagnostics queues even when a caller submits controls faster than physics.
	if _delayed_inputs.size() >= 120:
		return
	_delayed_inputs.append({"due": Time.get_ticks_msec() + simulated_input_delay_ms,
		"seq": _sequence, "move": movement, "yaw": yaw, "run": running, "jump": jump, "attack": attack, "buttons": buttons, "aim": aim, "pitch": pitch})
	# Critical one-shot skill edges also travel reliably. Both paths share a token.
	if buttons & SKILL and not buttons & (SWITCH | DODGE | PARRY | CAST):
		_request_character_skill.rpc_id(SERVER_ID,_sequence)

@rpc("any_peer", "call_remote", "reliable", 1)
func _request_character_skill(sequence: int) -> void:
	if server_mode:
		_try_character_skill(multiplayer.get_remote_sender_id(),sequence)

func _try_character_skill(id: int, sequence: int) -> bool:
	if not server_mode or not players.has(id) or sequence < 0 or sequence > 2147483647: return false
	var record: Dictionary = players[id]
	if sequence <= int(record.get("skill_sequence_used",-1)) or sequence > int(record.seq)+MAX_SEQUENCE_ADVANCE: return false
	record.skill_sequence_used = sequence
	var now := Time.get_ticks_msec()
	if now-int(record.get("skill_request_time",-1000)) < 100: return false
	record.skill_request_time = now
	if manager.phase != 1 or record.body.get_node("Combatant").is_dead(): return false
	return record.body.get_node("CharacterSkills").request_skill()

@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func _submit_input(sequence: int, movement: Vector2, yaw: float, running: bool, jump: bool, attack: bool, buttons: int = 0, aim: bool = false, pitch: float = 0.0) -> void:
	if server_mode:
		_accept_input(multiplayer.get_remote_sender_id(), sequence, movement, yaw, running, jump, attack, buttons, aim, pitch)

func _accept_input(id: int, sequence: int, movement: Vector2, yaw: float, running: bool, jump: bool, attack: bool, buttons: int = 0, aim: bool = false, pitch: float = 0.0) -> bool:
	if not players.has(id):
		rejected_inputs += 1
		return false
	var record: Dictionary = players[id]
	var now := Time.get_ticks_msec()
	record.tokens = minf(input_burst_limit, record.tokens + (now - record.bucket_time) * input_rate_limit / 1000.0)
	record.bucket_time = now
	if record.tokens < 1.0:
		rate_limited_inputs += 1
		return false
	record.tokens -= 1.0
	if (sequence < 0 or sequence > 2147483647 or sequence <= record.seq
		or sequence > record.seq + MAX_SEQUENCE_ADVANCE or not movement.is_finite()
		or movement.length_squared() > 1.001 or not is_finite(yaw) or buttons < 0 or buttons > 127
		or not is_finite(pitch) or absf(pitch) > 1.5):
		rejected_inputs += 1
		return false
	record.seq = sequence
	if manager.phase != 1 or record.body.get_node("Combatant").is_dead():
		return false
	record.move = movement.limit_length(1.0)
	record.yaw = wrapf(yaw, -PI, PI)
	record.run = running
	# Preserve button edges across multiple input packets before the next server tick.
	record.jump = record.jump or jump
	record.attack = record.attack or attack
	record.buttons = int(record.get("buttons", 0)) | buttons
	if buttons & SKILL: record.pending_skill_sequence = sequence
	record.aim = aim
	record.pitch = pitch
	record.last_input = now
	return true

func _server_step(delta: float) -> void:
	if manager.phase != 1:
		return
	for record in players.values():
		if manager.phase != 1:
			break
		var body: CharacterBody3D = record.body
		if body.get_node("Combatant").is_dead():
			record.move = Vector2.ZERO
			record.jump = false
			record.attack = false
			record.buttons = 0
			continue
		if Time.get_ticks_msec() - record.last_input > input_timeout_ms:
			record.move = Vector2.ZERO
			record.run = false
			record.jump = false
			record.attack = false
			record.buttons = 0
		var buttons: int = int(record.get("buttons", 0)) if Time.get_ticks_msec() - record.last_input <= input_timeout_ms else 0
		var motion: Node = body.get_node("MotionTestControls")
		body.camera_lock_behind = bool(record.get("aim", false))
		body.get_node("CameraPivot").rotation.y = record.yaw
		body.get_node("CameraPivot/CameraTilt").rotation.x = float(record.get("pitch", 0.0))
		motion._physics_process(delta)
		var direction := Vector3(record.move.x, 0, record.move.y).rotated(Vector3.UP, record.yaw)
		if buttons & SWITCH:
			motion.switch_character()
		elif buttons & DODGE:
			motion.request_dodge(direction)
		elif buttons & PARRY:
			motion.request_parry()
		elif buttons & CAST:
			motion.request_cast()
		elif buttons & SKILL:
			_try_character_skill(int(String(body.name)),int(record.get("pending_skill_sequence",record.seq)))
		body.network_interact = bool(buttons & INTERACT)
		body.network_drop = bool(buttons & DROP)
		body.simulate_network_input(delta, record.move, record.yaw, record.run, record.jump)
		body.network_interact = false
		body.network_drop = false
		record.buttons = 0
		if record.attack and manager.phase == 1 and body.get_node("AttackHitbox").request_attack():
			record.swings += 1
		record.jump = false
		record.attack = false
		record.buttons = 0

func _broadcast_snapshot() -> void:
	_snapshot_tick += 1
	var states: Array = []
	for id in players:
		var record: Dictionary = players[id]
		var body: CharacterBody3D = record.body
		var health: Health = body.get_node("Health")
		# Positional wire records avoid repeated dictionary keys in every player snapshot.
		states.append([id, record.team, record.slot, body.position, body.velocity,
			body.get_node("Mesh").rotation.y, body.get_node("CameraPivot").rotation.y,
			health.get_health(), health.max_health, body.get_node("Combatant").is_dead(), record.swings, MOTION_STATE.capture(body)])
	# Compress the complete pose/effect payload together to stay below the ENet MTU.
	var packed := var_to_bytes([states, _capture_effects()]).compress(FileAccess.COMPRESSION_DEFLATE)
	# Use the registered, live roster rather than broadcast to peers being torn down.
	for id in players:
		if multiplayer.get_peers().has(id) and _peer.get_peer(id).get_state() == ENetPacketPeer.STATE_CONNECTED:
			_receive_snapshot.rpc_id(id, _snapshot_tick, packed, manager.phase, manager.score_a, manager.score_b,
				manager.time_remaining, winner, status_text)

@rpc("authority", "call_remote", "unreliable_ordered", 0)
func _receive_snapshot(tick: int, states: Variant, phase: int, a: int, b: int, remaining: float, result: int, message: String, effects: Array = []) -> void:
	if server_mode or tick <= _last_snapshot_tick:
		return
	if states is PackedByteArray:
		var decoded: Variant = bytes_to_var(states.decompress_dynamic(65536, FileAccess.COMPRESSION_DEFLATE))
		if not decoded is Array or decoded.size() != 2 or not decoded[0] is Array or not decoded[1] is Array:
			return
		effects = decoded[1]
		states = decoded[0]
	if not states is Array:
		return
	_last_snapshot_tick = tick
	var present: Array[int] = []
	for wire in states:
		var state := {"id": wire[0], "team": wire[1], "slot": wire[2], "position": wire[3],
			"velocity": wire[4], "mesh_yaw": wire[5], "yaw": wire[6], "hp": wire[7],
			"max_hp": wire[8], "dead": wire[9], "swings": wire[10]}
		var id: int = state.id
		present.append(id)
		if not players.has(id):
			players[id] = {"body": _spawn_player(id, state.team, state.slot), "team": state.team, "slot": state.slot, "swings": state.swings}
		var record: Dictionary = players[id]
		var body: CharacterBody3D = record.body
		if record.team != state.team or record.slot != state.slot:
			record.team = state.team
			record.slot = state.slot
			_set_team_marker(body, state.team)
		body.position = state.position
		body.velocity = state.velocity
		body.get_node("Mesh").rotation.y = state.mesh_yaw
		var motion_state: Dictionary = wire[11] if wire.size() > 11 else {}
		body.get_node("Health").apply_network_state(state.hp, state.max_hp, StringName(motion_state.get("damage_kind", "hit")))
		if not motion_state.is_empty():
			MOTION_STATE.apply(body, motion_state)
		body.get_node("Mesh").visible = not state.dead
		if not state.dead and state.swings > record.swings:
			# A: the swing travels along the server-authoritative Mesh front (+Z), so drive the
			# remote swipe from mesh_yaw (not the camera yaw) to match the real attack direction.
			var forward := Vector3.BACK.rotated(Vector3.UP, state.mesh_yaw)
			body.get_node("AttackHitbox").attack_started.emit(forward)
			if motion_state.is_empty():
				body.get_node("CharacterAnimation")._on_attack_started(forward)
		record.swings = state.swings
	for id in players.keys():
		if not present.has(id):
			_remove_player(id)
	_apply_effects(effects)
	var previous_phase: int = manager.phase
	manager.apply_state(phase, a, b, remaining, result)
	if lobby_enabled and players.has(_local_peer_id):
		players[_local_peer_id].body.get_node("CameraPivot").local_input_enabled = phase != 0
		if phase == 1 and previous_phase != 1:
			_peer.get_peer(SERVER_ID).set_timeout(8, 5000, 15000)
		if phase == 2 and previous_phase != 2:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		if phase == 1 and previous_phase != 1 and capture_local_controls:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	winner = result
	status_text = message
	if connected and not _local_ready_sent and (players.has(_local_peer_id) if lobby_enabled else players.size() == required_players):
		_local_ready_sent = true
		if not lobby_enabled:
			_peer.get_peer(SERVER_ID).set_timeout(8, 5000, 15000)
		_client_ready.rpc_id(SERVER_ID)
	snapshot_received.emit()

func _remove_player(id: int) -> void:
	if not players.has(id):
		return
	if not server_mode and id == _local_peer_id:
		hud.bind_health(null)
	players[id].body.queue_free()
	players.erase(id)

func _on_peer_disconnected(id: int) -> void:
	print("NETWORK_PEER_DISCONNECTED=", id)
	if not server_mode:
		return
	_remove_player(id)
	if lobby_enabled and manager.phase == 0:
		if id == lobby_host_id:
			lobby_host_id = 0
		_invalidate_lobby_ready()
		_publish_lobby()
	if manager.phase == 1:
		manager._end_match(-1)
		status_text = "Player disconnected - session ended. Restart server and clients."
	elif manager.phase == 0:
		status_text = _waiting_status()
	_broadcast_snapshot()

func _on_match_ended(result: int) -> void:
	winner = result
	for record in players.values():
		record.move = Vector2.ZERO
		record.jump = false
		record.attack = false
		record.buttons = 0
		record.body.velocity = Vector3.ZERO
	status_text = "Match ended - restart server and clients for a fresh match."

func _on_connection_failed() -> void:
	connected = false
	status_text = "Connection failed or session full. Check server/address, then restart this client."
	if _peer:
		_peer.close()

func _on_server_disconnected() -> void:
	connected = false
	status_text = "Server disconnected - session stopped. Restart server and clients."
	_delayed_inputs.clear()
	for id in players.keys():
		_remove_player(id)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

@rpc("any_peer", "call_remote", "unreliable", 2)
func _ping(sent_at: int) -> void:
	var id := multiplayer.get_remote_sender_id()
	if server_mode and players.has(id):
		_pong.rpc_id(id, sent_at)

@rpc("authority", "call_remote", "unreliable", 2)
func _pong(sent_at: int) -> void:
	if not server_mode:
		rtt_ms = maxi(0, Time.get_ticks_msec() - sent_at)

func _exit_tree() -> void:
	if _peer:
		_peer.close()

func _record_impact(point: Vector3, normal: Vector3, airborne: bool) -> void:
	_impact_sequence += 1
	_impacts.append([_impact_sequence, point, normal, airborne])
	if _impacts.size() > 16:
		_impacts.pop_front()

func _capture_effects() -> Array:
	var bolts: Array = []
	for bolt in get_tree().get_nodes_in_group("motion_test_bolts"):
		if is_ancestor_of(bolt) and not bolt.is_queued_for_deletion():
			bolts.append([bolt.get_instance_id(), bolt.global_position, bolt.direction])
	var grenades: Array = []
	for grenade in get_tree().get_nodes_in_group("skill_grenades"):
		if is_ancestor_of(grenade) and not grenade.presentation_only and not grenade.is_queued_for_deletion():
			grenades.append([grenade.get_instance_id(),grenade.global_position,grenade.exploded,grenade.burst_left])
	return [bolts, _impacts, grenades]

func _apply_effects(effects: Array) -> void:
	if effects.size() < 2:
		return
	var present: Array = []
	for shot in effects[0]:
		var id: int = shot[0]
		present.append(id)
		if not _bolts.has(id):
			var bolt := Node3D.new()
			bolt.set_script(BOLT)
			add_child(bolt)
			bolt.set_physics_process(false)
			_bolts[id] = bolt
		_bolts[id].global_position = shot[1]
	for id in _bolts.keys():
		if not present.has(id):
			if is_instance_valid(_bolts[id]):
				_bolts[id].queue_free()
			_bolts.erase(id)
	for hit in effects[1]:
		if int(hit[0]) <= _last_impact:
			continue
		_last_impact = int(hit[0])
		var effect := Node3D.new()
		effect.set_script(IMPACT)
		effect.normal = hit[2]
		effect.air_attack = hit[3]
		add_child(effect)
		effect.global_position = hit[1]
	var active: Array = []
	if effects.size() > 2:
		for state in effects[2]:
			var id: int = state[0]
			active.append(id)
			if not _grenades.has(id):
				var grenade := Node3D.new(); grenade.set_script(GRENADE)
				grenade.presentation_only = true
				add_child(grenade)
				_grenades[id] = grenade
			_grenades[id].present_state(state[1],state[2],state[3])
	for id in _grenades.keys():
		if not active.has(id):
			if is_instance_valid(_grenades[id]): _grenades[id].queue_free()
			_grenades.erase(id)


# Lobby requests always derive ownership from the RPC sender, never a supplied player ID.
func select_lobby(team: int, character: int, ready: bool) -> void:
	if connected and lobby_enabled:
		_lobby_select.rpc_id(SERVER_ID, team, character, ready)

func start_lobby_match() -> void:
	if connected and lobby_enabled:
		_lobby_start.rpc_id(SERVER_ID)

@rpc("any_peer", "call_remote", "reliable", 1)
func _lobby_select(team: int, character: int, ready: bool) -> void:
	if server_mode and _allow_lobby_request(multiplayer.get_remote_sender_id()):
		_accept_lobby_selection(multiplayer.get_remote_sender_id(), team, character, ready)

func _allow_lobby_request(id: int) -> bool:
	var now := Time.get_ticks_msec()
	if now - int(_lobby_request_times.get(id, -1000)) < 100:
		return false
	_lobby_request_times[id] = now
	return true

func _accept_lobby_selection(id: int, team: int, character: int, ready: bool) -> bool:
	if not server_mode or not lobby_enabled or manager.phase != 0 or not players.has(id):
		return false
	if team not in [0, 1] or character not in [0, 1]:
		return false
	var record: Dictionary = players[id]
	if record.team != team:
		var count := 0
		for other in players.values():
			if other.team == team:
				count += 1
		if count >= 2:
			_lobby_feedback.rpc_id(id, "That team already has two players.")
			return false
	var mesh: Node = record.body.get_node("Mesh")
	var changed: bool = record.team != team or int(mesh.character) != character
	if changed:
		record.team = team
		if int(mesh.character) != character:
			mesh.set_character(character)
			record.body.get_node("CharacterAnimation")._physics_process(0.0)
			record.body.stair_presentation._bind_model()
		_assign_lobby_spawns()
		_invalidate_lobby_ready()
	record.lobby_ready = ready and bool(record.ready) and not changed
	_publish_lobby()
	_broadcast_snapshot()
	return true

func _assign_lobby_spawns() -> void:
	var slots := [0, 0]
	for record in players.values():
		var team: int = record.team
		record.slot = slots[team]
		slots[team] += 1
		var body: Node3D = record.body
		var combatant: Node = body.get_node("Combatant")
		combatant.team_id = team
		combatant.spawn_index = record.slot
		combatant._resolve_spawn_point()
		var spawns := get_tree().get_nodes_in_group("spawn_team_%d" % team)
		body.global_position = spawns[record.slot].global_position
		body.velocity = Vector3.ZERO
		_set_team_marker(body, team)

func _set_team_marker(body: Node3D, team: int) -> void:
	var marker: MeshInstance3D = body.get_node("Mesh/TeamMarker")
	marker.material_override.albedo_color = TEAM_COLORS[team]

func _invalidate_lobby_ready() -> void:
	for record in players.values():
		record.lobby_ready = false

func _lobby_block_reason() -> String:
	if players.size() < 2:
		return "Waiting for another player. You can start with 2, 3 or 4 players."
	var counts := [0, 0]
	for record in players.values():
		counts[record.team] += 1
	if counts[0] == 0 or counts[1] == 0:
		return "Choose at least one player on each team."
	if counts[0] > 2 or counts[1] > 2 or players.size() > 4:
		return "Each team can have at most two players."
	for record in players.values():
		if not record.ready:
			return "Waiting for characters to finish loading."
		if not record.lobby_ready:
			return "Waiting for every player to mark Ready."
	if lobby_host_id == 0:
		return "Host left. Return to menu and host a new lobby."
	return ""

@rpc("any_peer", "call_remote", "reliable", 1)
func _lobby_start() -> void:
	if server_mode and _allow_lobby_request(multiplayer.get_remote_sender_id()):
		_accept_lobby_start(multiplayer.get_remote_sender_id())

func _accept_lobby_start(id: int) -> bool:
	if not server_mode or not lobby_enabled or manager.phase != 0 or id != lobby_host_id:
		return false
	if not _lobby_block_reason().is_empty():
		return false
	for peer_id in players:
		_peer.get_peer(peer_id).set_timeout(8, 5000, 15000)
	manager.start_match()
	var counts := [0, 0]
	for record in players.values():
		counts[record.team] += 1
	status_text = "%dv%d match running" % [counts[0], counts[1]]
	_publish_lobby()
	_broadcast_snapshot()
	return true

func _publish_lobby() -> void:
	_lobby_revision += 1
	lobby_roster = []
	for id in players:
		var record: Dictionary = players[id]
		lobby_roster.append({"id": id, "team": record.team,
			"character": int(record.body.get_node("Mesh").character),
			"loaded": bool(record.ready), "ready": bool(record.lobby_ready)})
	lobby_start_reason = _lobby_block_reason()
	for id in players:
		if multiplayer.get_peers().has(id):
			_receive_lobby.rpc_id(id, _lobby_revision, lobby_roster, lobby_host_id, lobby_start_reason)

@rpc("authority", "call_remote", "reliable", 1)
func _receive_lobby(revision: int, roster: Array, host_id: int, reason: String) -> void:
	if server_mode or revision <= _last_lobby_revision:
		return
	_last_lobby_revision = revision
	lobby_roster = roster
	lobby_host_id = host_id
	lobby_start_reason = reason
	lobby_notice = ""
	lobby_updated.emit()

@rpc("authority", "call_remote", "reliable", 1)
func _lobby_feedback(message: String) -> void:
	lobby_notice = message
	lobby_updated.emit()
