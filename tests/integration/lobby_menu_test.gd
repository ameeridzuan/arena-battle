extends SceneTree
## End-to-end menu hosting: launch its own dedicated child, wait, leave, and host again.
var checks: Array[bool] = []
func _init() -> void:
	run_test.call_deferred()
func check(label: String, passed: bool) -> void:
	print("CHECK ", label, "=", passed)
	checks.append(passed)
func run_test() -> void:
	var menu = load("res://scenes/multiplayer/Demo1.tscn").instantiate()
	root.add_child(menu)
	for attempt in 2:
		await menu._host()
		print("HOST_MENU_STATUS=", menu.message.text, " session=", is_instance_valid(menu.session))
		var deadline := Time.get_ticks_msec() + 90000
		while (not is_instance_valid(menu.session) or menu.session.lobby_roster.size() != 1) and Time.get_ticks_msec() < deadline:
			await process_frame
		if not is_instance_valid(menu.session):
			check("host creates session", false)
			break
		var session: Node = menu.session
		check("host connects to own server", session.connected and session.lobby_roster.size() == 1)
		check("host owner claim accepted", session.lobby_host_id == session._local_peer_id and session.lobby_host_id > 1)
		check("single player stays waiting", session.manager.phase == 0)
		check("waiting screen active", session._lobby_screen.panel.visible)
		check("return button above lobby", menu.back.visible and menu.back.get_parent().layer > session._lobby_screen.layer)
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://.godot/lobby_menu_preview.png")
		var child: int = menu.server_pid
		menu._return_to_menu()
		var stopped_deadline := Time.get_ticks_msec() + 5000
		while OS.is_process_running(child) and Time.get_ticks_msec() < stopped_deadline:
			await process_frame
		check("return stops owned server", not OS.is_process_running(child))
		check("return restores menu", menu.visible and menu.session == null)
	print("ALL_MENU_LOBBY_TESTS_PASS=", not checks.has(false), " checks=", checks.size())
	quit(1 if checks.has(false) else 0)
