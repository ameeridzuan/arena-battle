extends SceneTree
const MAIN := preload("res://scenes/main/Main.tscn")
const PLAYER := preload("res://scenes/characters/Player.tscn")
const MOTION := preload("res://scripts/player/local_motion_test_player.gd")
const GRENADE := preload("res://scripts/combat/stun_grenade.gd")
const STATE := preload("res://scripts/multiplayer/network_motion_state.gd")
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ",label)

func _initialize() -> void: run.call_deferred()

func frames(count: int) -> void:
	for i in range(count): await physics_frame
	await process_frame

func make_grenade(parent: Node, source: CharacterBody3D, point: Vector3) -> Node3D:
	var grenade := Node3D.new(); grenade.set_script(GRENADE); grenade.source = source
	parent.add_child(grenade); grenade.global_position = point; grenade.set_physics_process(false)
	return grenade

func run() -> void:
	var main := MAIN.instantiate(); root.add_child(main)
	var body: CharacterBody3D = main.get_node("Player")
	var enemy: Node3D = main.get_node("Opponent1")
	var ally: Node3D = main.get_node("Opponent2")
	for node in [enemy,ally]:
		node.get_node("AttackHitbox").auto_attack = false
		node.get_node("AttackHitbox").set_physics_process(false)
	main.get_node("MatchManager").set_physics_process(false)
	await frames(12)
	body.set_physics_process(false)
	var skills = body.get_node("CharacterSkills"); skills.set_physics_process(false)
	var stun = body.get_node("StunStatus"); stun.set_physics_process(false)
	var enemy_stun = enemy.get_node("StunStatus"); enemy_stun.set_physics_process(false)
	var driver = body.get_node("CharacterAnimation")
	var attack = body.get_node("AttackHitbox")
	body.position = Vector3(0,1.01,0); body.velocity = Vector3.ZERO
	body.get_node("Mesh").rotation.y = 0
	enemy.position = Vector3(0,1,2); enemy.rotation = Vector3.ZERO
	ally.position = Vector3(.8,1,2); ally.get_node("Combatant").team_id = 0
	await frames(3)
	check(skills.request_skill(),"Arclight grenade activation accepted")
	check(is_equal_approx(skills.cooldowns[0],18.0),"Grenade starts eighteen-second cooldown")
	check(not skills.request_skill(),"Grenade spam rejected")
	var grenades := get_nodes_in_group("skill_grenades")
	check(grenades.size()==1,"Activation spawns one small grenade")
	var grenade = grenades[0]; grenade.set_physics_process(false)
	grenade.global_position = Vector3(0,1,1.8)
	grenade.detonate()
	check(enemy_stun.is_stunned(),"Grenade blast stuns enemy")
	check(is_equal_approx(enemy_stun.remaining,4.0),"Stun duration is four seconds")
	check(not ally.get_node("StunStatus").is_stunned(),"Grenade ignores teammates")
	check(not body.is_stunned(),"Grenade ignores thrower")
	check(enemy.get_health()==100,"Stun grenade deals no unrequested damage")
	check(not enemy.get_node("AttackHitbox").request_attack(),"Stunned enemy cannot attack")
	enemy_stun._physics_process(3.99)
	check(enemy_stun.is_stunned(),"Stun persists until four seconds")
	enemy_stun._physics_process(.01)
	check(not enemy_stun.is_stunned(),"Stun ends at four seconds")
	grenade.free()
	# Cover and out-of-range protection use actual physics geometry.
	var wall := StaticBody3D.new(); var collision := CollisionShape3D.new(); var shape := BoxShape3D.new()
	shape.size = Vector3(2,2,.15); collision.shape = shape; wall.add_child(collision)
	main.add_child(wall); wall.position = Vector3(0,1,1)
	await frames(3)
	grenade = make_grenade(main,body,Vector3(0,1,.2)); grenade.detonate()
	check(not enemy_stun.is_stunned(),"Blast cannot stun through a wall")
	grenade.free(); wall.free()
	grenade = make_grenade(main,body,Vector3(0,1,-4)); grenade.detonate()
	check(not enemy_stun.is_stunned(),"Blast respects three-metre radius")
	grenade.free()
	# A stunned player still falls/collides but cannot move, jump or activate actions.
	body.set_physics_process(true)
	body.get_node("MotionTestControls")._suppress_melee()
	check(stun.apply_stun(enemy,4),"Enemy can stun player")
	check(not attack.is_physics_processing(),"Stun interrupts suppressed cast/melee state")
	var before := body.position
	body._simulate_movement(1.0/60,Vector3.RIGHT,true,true)
	check(absf(body.position.x-before.x)<.001 and body.velocity.y<=0,"Stun blocks movement and jumping")
	check(not skills.request_skill(),"Stun blocks character skill")
	check(not body.get_node("MotionTestControls").request_dodge(),"Stun blocks dodge")
	check(not attack.request_attack(),"Stun blocks weapon contact attack")
	stun.clear()
	body.get_node("MotionTestControls")._physics_process(0)
	check(attack.is_physics_processing(),"Melee restores after a stun interrupts casting")
	# Switching does not erase the grenade timer, and Warden gets a separate timer.
	driver.cancel_action(); attack.cancel_attack()
	body.get_node("Mesh").set_character(1); driver._physics_process(0)
	check(skills.cooldowns[0]>17.9,"Character switch preserves grenade cooldown")
	check(skills.request_skill(),"Warden summons flame scythe")
	check(skills.is_scythe_active() and is_equal_approx(skills.scythe_left,20),"Scythe lasts twenty seconds")
	check(is_equal_approx(skills.cooldowns[1],40),"Scythe starts forty-second cooldown")
	check(not skills.request_skill(),"Scythe cannot be reactivated while cooling down")
	check(driver._anim.has_animation("Skills/Scythe_Reap") and driver._anim.has_animation("Skills/Scythe_Return") and driver._anim.has_animation("Skills/Scythe_Cleave"),"Three new scythe slash clips are installed")
	check(not driver._anim.get_animation("Skills/Scythe_Reap").resource_path.begins_with("res://assets/models"),"Scythe animation is an instance-local resource")
	# Actual swept blade contact must grant both the hit and the refreshable burn.
	enemy.position = Vector3(0,1,1.4); ally.position = Vector3(9,1,9)
	body.position = Vector3(0,1.01,0); body.velocity = Vector3.ZERO
	body.move_and_slide()
	body.set_physics_process(true)
	await frames(3)
	attack._cooldown_remaining = 0; driver.cancel_action()
	check(attack.request_attack() and attack.current_clip=="Skills/Scythe_Reap","First attack uses scythe reap")
	var damaged := false
	for sample in range(60):
		await frames(1)
		if "--debug-skills" in OS.get_cmdline_user_args() and sample % 8 == 0:
			print("SCYTHE_DEBUG ",sample," action=",driver.get_action_clip()," phase=",attack._elapsed," segment=",attack.get_weapon_segment()," target=",enemy.global_position)
		if enemy.get_health()<100:
			damaged = true; break
	check(damaged,"Scythe sweep makes real blade contact")
	check(enemy.get_node("BurnStatus").is_burning(),"Confirmed scythe hit applies burn")
	attack.cancel_attack(); driver.cancel_action()
	var burn = enemy.get_node("BurnStatus"); burn.set_physics_process(false)
	var hp: float = enemy.get_health(); burn._physics_process(3.0)
	check(is_equal_approx(enemy.get_health(),hp-9.0),"Scythe burn deals three ticks of three damage")
	attack._cooldown_remaining=0
	enemy.get_node("Health").reset()
	check(attack.request_attack() and attack.current_clip=="Skills/Scythe_Return","Second attack uses reverse hook slash")
	for sample in range(65):
		await frames(1)
		if enemy.get_health()<100: break
	check(enemy.get_health()<100 and enemy.get_node("BurnStatus").is_burning(),"Reverse scythe hook makes contact and burns")
	attack.cancel_attack(); driver.cancel_action()
	enemy.get_node("Health").reset()
	body.position.y = 1.55; body.velocity=Vector3.UP*2
	body.move_and_slide(); attack._cooldown_remaining=0
	check(attack.request_attack() and attack.current_clip=="Skills/Scythe_Cleave","Airborne attack selects new scythe cleave")
	for sample in range(85):
		await frames(1)
		if enemy.get_health()<100: break
	check(enemy.get_health()<100 and enemy.get_node("BurnStatus").is_burning(),"Aerial scythe cleave makes contact and burns")
	attack.cancel_attack(); driver.cancel_action()
	# Serialized skills/stun state updates a real replica without granting authority.
	var replica: CharacterBody3D = PLAYER.instantiate(); replica.set_script(MOTION)
	replica.external_control = true; replica.network_presentation_only = true
	replica.get_node("Combatant").free(); replica.get_node("Health").network_replica = true
	main.add_child(replica); replica.set_physics_process(false)
	replica.get_node("AttackHitbox").set_physics_process(false)
	STATE.apply(replica,bytes_to_var(var_to_bytes(STATE.capture(body))))
	check(replica.get_node("CharacterSkills").is_scythe_active(),"Scythe visual state reaches replica")
	check(not replica.get_node("CharacterSkills").request_skill(),"Replica cannot grant a skill")
	check(not replica.get_node("StunStatus").apply_stun(enemy,4),"Replica cannot grant a stun")
	grenade = make_grenade(main,body,enemy.position); grenade.presentation_only=true; grenade.detonate()
	check(not grenade.exploded and not enemy_stun.is_stunned(),"Presentation grenade cannot grant an explosion or stun")
	grenade.free()
	skills._physics_process(19.99)
	check(skills.is_scythe_active(),"Scythe persists to twenty seconds")
	skills._physics_process(.01)
	check(not skills.is_scythe_active(),"Scythe disappears at twenty seconds")
	check(skills.cooldowns[1]>19.9 and not skills.request_skill(),"Cooldown continues after temporary weapon expires")
	skills._physics_process(20)
	check(skills.request_skill(),"Scythe becomes usable after forty seconds")
	body.get_node("Health").apply_damage(100,enemy)
	check(not skills.is_scythe_active(),"Death removes temporary weapon")
	check(skills.cooldowns[1]>39.9,"Death cannot reset character cooldown")
	body.get_node("Health").reset()
	check(not body.is_stunned(),"Respawn clears stun")
	main.get_node("MatchManager")._end_match(-1)
	check(not skills.request_skill(),"Match end rejects skills")
	main.free()
	print("CHARACTER_SKILL_CHECKS=",checks," FAILURES=",failures," ALL_TESTS_PASS=",failures==0)
	quit(0 if failures==0 else 1)
