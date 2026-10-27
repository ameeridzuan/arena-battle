extends Control
## Portable Demo 1 entry point. Gameplay still lives at /root/MultiplayerArena.
const SESSION := preload("res://scenes/multiplayer/MultiplayerArena.tscn")
var session: Node
var server_pid: int = -1
var address: LineEdit
var message: Label
var menu: VBoxContainer
var back: Button
var reported_running := false
var _host_token := ""

func _ready() -> void:
	_build_menu()
	var args := OS.get_cmdline_user_args()
	if "--server" in args:
		_enter_session.call_deferred("", true)
		return
	for arg in args:
		if arg.begins_with("--connect="):
			_enter_session.call_deferred(arg.trim_prefix("--connect="))
			return
		if arg.begins_with("--demo-host="):
			address.text = arg.trim_prefix("--demo-host=")
			_host()
			return

func _build_menu() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Color("101c30")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	menu = VBoxContainer.new()
	menu.custom_minimum_size.x = 640
	menu.add_theme_constant_override("separation", 18)
	center.add_child(menu)
	var title := Label.new()
	title.text = "DEMO 1  |  ArenaBattle"
	title.add_theme_font_size_override("font_size", 38)
	menu.add_child(title)
	var description := Label.new()
	description.text = "Team Parkour Arena - up to four players on the same LAN\nHost a lobby, choose teams and characters, then play 1v1, 2v1 or 2v2."
	menu.add_child(description)
	address = LineEdit.new()
	address.placeholder_text = "Host IP address (for example 192.168.1.20)"
	address.text = "127.0.0.1"
	menu.add_child(address)
	var host := Button.new()
	host.text = "Host lobby (up to 4 players)"
	host.pressed.connect(_host)
	menu.add_child(host)
	var join := Button.new()
	join.text = "Join host"
	join.pressed.connect(_join)
	menu.add_child(join)
	var ips: Array[String] = []
	for ip in IP.get_local_addresses():
		if ip.contains(".") and not ip.begins_with("127.") and not ip.begins_with("169.254."):
			ips.append(ip)
	message = Label.new()
	message.text = "This PC's IPv4 addresses: " + ", ".join(ips) + "\nUDP port 24560. Allow the game on your private network if prompted."
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	menu.add_child(message)
	var controls := Label.new()
	controls.text = "WASD move | Shift run | Space jump / wall jump | Click melee\nE grab / climb | A/D shimmy | C drop | Q dash / dodge | F parry\nG character skill | V aim | R cast + burn | Tab character | Esc cursor\nExplore the terraces and wall-jump lanes. Close host to stop server."
	menu.add_child(controls)
	var quit_button := Button.new()
	quit_button.text = "Quit"
	quit_button.pressed.connect(func(): get_tree().quit())
	menu.add_child(quit_button)
	var overlay := CanvasLayer.new()
	overlay.layer = 10
	add_child(overlay)
	back = Button.new()
	back.text = "Return to menu"
	back.position = Vector2(1090, 16)
	back.visible = false
	back.pressed.connect(_return_to_menu)
	overlay.add_child(back)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _join() -> void:
	var ip := address.text.strip_edges()
	if not ip.is_valid_ip_address():
		message.text = "Enter the host's IP address, for example 192.168.1.20."
		return
	_enter_session(ip)

func _host() -> void:
	menu.get_parent().visible = false
	var child_args := PackedStringArray(["--headless"])
	var pack := OS.get_executable_path().get_base_dir().path_join("Demo 1.pck")
	if FileAccess.file_exists(pack):
		child_args.append_array(["--main-pack", pack])
	else:
		child_args.append_array(["--path", ProjectSettings.globalize_path("res://"), "res://scenes/multiplayer/Demo1.tscn"])
	_host_token = Crypto.new().generate_random_bytes(24).hex_encode()
	child_args.append_array(["--log-file", ProjectSettings.globalize_path("user://demo1-server.log"), "--", "--server", "--bind=*", "--players=4", "--lobby", "--lobby-token=" + _host_token])
	server_pid = OS.create_process(OS.get_executable_path(), child_args, false)
	if server_pid < 0:
		menu.get_parent().visible = true
		message.text = "Could not start the server. Check that all ZIP files were extracted."
		return
	print("DEMO1_HOST_SERVER_PID=", server_pid)
	await get_tree().create_timer(0.75).timeout
	if not OS.is_process_running(server_pid):
		server_pid = -1
		menu.get_parent().visible = true
		message.text = "Server could not open UDP 24560. Close any previous host and try again."
		return
	_enter_session("127.0.0.1")

func _enter_session(ip: String, dedicated: bool = false) -> void:
	visible = false
	session = SESSION.instantiate()
	session.required_players = 4
	session.lobby_enabled = true
	if not dedicated:
		session.host_token = _host_token
	if not dedicated:
		session.server_address = ip
	get_tree().root.add_child(session)
	back.visible = not dedicated
	if dedicated and session.status_text.begins_with("Could not"):
		get_tree().quit(1)
	reported_running = false

func _process(_delta: float) -> void:
	if is_instance_valid(session) and session.manager != null and session.manager.phase == 1 and not reported_running:
		reported_running = true
		print("DEMO1_MATCH_RUNNING players=", session.players.size())
	if is_instance_valid(session) and not session.server_mode and not session.connected:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _return_to_menu() -> void:
	if is_instance_valid(session):
		get_tree().root.remove_child(session)
		session.free()
	session = null
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	_stop_server()
	back.visible = false
	visible = true
	menu.get_parent().visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _stop_server() -> void:
	if server_pid > 0 and OS.is_process_running(server_pid):
		OS.kill(server_pid)
	server_pid = -1
	_host_token = ""

func _exit_tree() -> void:
	_stop_server()
