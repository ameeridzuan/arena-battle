extends SceneTree
const ARENA := preload("res://scenes/multiplayer/MultiplayerArena.tscn")
var session: Node
var checks := 0
var failures := 0
var report := ""
var seen := {"grenade":false,"scythe":false,"stun":false,"cooldowns":false}

func _initialize() -> void: run.call_deferred()

func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ",label)

func wait_until(predicate: Callable,seconds: float = 60.0) -> bool:
	var deadline := Time.get_ticks_msec()+int(seconds*1000)
	while Time.get_ticks_msec()<deadline:
		if predicate.call(): return true
		await process_frame
	return predicate.call()

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): report = arg.trim_prefix("--report=")
	session = ARENA.instantiate(); session.capture_local_controls = false
	root.add_child(session)
	if session.server_mode: await server_test()
	else: await client_test()
	var passed := failures==0 and checks>0
	if not report.is_empty():
		var file := FileAccess.open(report,FileAccess.WRITE)
		file.store_string(JSON.stringify({"passed":passed,"checks":checks,"seen":seen}))
	print("SKILL_NETWORK_CHECKS=",checks," FAILURES=",failures," ALL_TESTS_PASS=",passed)
	quit(0 if passed else 1)

func server_test() -> void:
	check(await wait_until(func():return session.players.size()==2 and session.manager.phase==1),"Both clients finish loading")
	if failures>0:return
	var arc: CharacterBody3D
	var warden: CharacterBody3D
	for record in session.players.values():
		if record.team==0: arc=record.body
		else: warden=record.body
	arc.position=Vector3(0,1.01,0); warden.position=Vector3(0,1.01,6)
	arc.velocity=Vector3.ZERO; warden.velocity=Vector3.ZERO
	arc.get_node("Mesh").rotation.y=0
	session.status_text="TEST:skills"; session._broadcast_snapshot()
	check(await wait_until(func():return arc.get_node("CharacterSkills").cooldowns[0]>0 and warden.get_node("CharacterSkills").is_scythe_active(),20),"Remote G requests activate each character's own skill")
	for record in session.players.values():
		print("SKILL_SERVER_DIAGNOSTIC team=",record.team," seq=",record.seq," rejected=",session.rejected_inputs," allowed=",record.body.get_node("CharacterSkills")._can_activate()," timers=",record.body.get_node("CharacterSkills").capture_state()," phase=",session.manager.phase," status=",session.status_text)
	check(await wait_until(func():return warden.is_stunned(),20),"Traveling grenade stuns opponent on authority")
	if warden.is_stunned():
		check(warden.get_node("StunStatus").remaining<=4 and warden.get_node("StunStatus").remaining>3,"Authority starts four-second stun")
		check(not warden.get_node("CharacterSkills").request_skill(),"Stun rejects action spam")
	check(arc.get_health()==100 and warden.get_health()==100,"Grenade does not cause damage or friendly self-stun")
	check(not arc.is_stunned(),"Thrower remains mobile")
	session.status_text="TEST:stunned"; session._broadcast_snapshot()
	check(await wait_until(func():return not warden.is_stunned(),20),"Authority expires stun")
	check(warden.get_node("CharacterSkills").is_scythe_active(),"Stun does not incorrectly erase twenty-second weapon")
	session.status_text="TEST:done"; session._broadcast_snapshot()
	await create_timer(2).timeout

func client_test() -> void:
	check(await wait_until(func():return session.connected and session.players.size()==2 and session.manager.phase==1),"Client receives live match")
	if failures>0:return
	var local: CharacterBody3D=session.players[session.multiplayer.get_unique_id()].body
	var requests:=0
	var next_request:=0
	var deadline:=Time.get_ticks_msec()+65000
	while Time.get_ticks_msec()<deadline and session.status_text!="TEST:done":
		if session.status_text=="TEST:skills" and requests==0 and Time.get_ticks_msec()>=next_request:
			session.send_controls(Vector2.ZERO,0,false,false,false,session.SKILL)
			requests+=1; next_request=Time.get_ticks_msec()+100
			if requests==3: print("SKILL_SEND_DIAGNOSTIC sequence=",session._sequence," queued=",session._delayed_inputs.size()," physics=",session.is_physics_processing()," peer=",session._peer.get_peer(1).get_state()," connected=",session.connected)
		for record in session.players.values():
			var body:CharacterBody3D=record.body
			var skills=body.get_node("CharacterSkills")
			if int(body.get_node("Mesh").character)==0 and skills.cooldowns[0]>0:seen.cooldowns=true
			if skills.is_scythe_active():seen.scythe=true
			if body.is_stunned():seen.stun=true
		if not session._grenades.is_empty():seen.grenade=true
		await process_frame
	check(session.status_text=="TEST:done","Authority completes skill sequence")
	print("SKILL_CLIENT_DIAGNOSTIC requests=",requests," status=",session.status_text," queued=",session._delayed_inputs.size()," sequence=",session._sequence)
	for feature in seen:check(seen[feature],"Replicated "+feature)
	check(not local.get_node("CharacterSkills").request_skill(),"Client replica cannot activate authoritative skill")
	var health:Health=local.get_node("Health")
	var hp:=health.get_health();health.apply_damage(50,local)
	check(is_equal_approx(hp,health.get_health()),"Client cannot grant damage")
