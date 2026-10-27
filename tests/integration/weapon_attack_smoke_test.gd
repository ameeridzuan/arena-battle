extends SceneTree
## Main-local weapon contact: real rig segments, active timing, air budget and hit-only feedback.
const MAIN := preload("res://scenes/main/Main.tscn")
const SHARED_PLAYER := preload("res://scenes/characters/Player.tscn")
const ORIGIN := Vector3(-6.0, 1.0, -6.0)
var checks := 0
var failures := 0
var hits: Array = []

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", label)

func _initialize() -> void:
	call_deferred("run")

func frames(count: int) -> void:
	for frame in count:
		await physics_frame
	await process_frame

func setup(character: int) -> Dictionary:
	var main := MAIN.instantiate()
	root.add_child(main)
	var body: CharacterBody3D = main.get_node("Player")
	var enemy: Node3D = main.get_node("Opponent1")
	var attack: Node = body.get_node("AttackHitbox")
	var driver: Node = body.get_node("CharacterAnimation")
	main.get_node("MatchManager").set_physics_process(false)
	main.get_node("Opponent2").global_position = Vector3(8, 1, 8)
	for name in ["Opponent1", "Opponent2"]:
		main.get_node(name + "/AttackHitbox").auto_attack = false
		main.get_node(name + "/AttackHitbox").set_physics_process(false)
	await frames(12)
	body.get_node("Mesh").set_character(character)
	driver._physics_process(0.0)
	await frames(4)
	attack.weapon_hit.connect(func(target: Node, point: Vector3, normal: Vector3, amount: float):
		hits.append({"target": target, "point": point, "normal": normal, "amount": amount, "airborne": not body.is_on_floor()}))
	return {"main": main, "body": body, "enemy": enemy, "attack": attack, "driver": driver, "character": character}

func prepare(ctx: Dictionary, height: float = 0.0, target_offset: Vector3 = Vector3(0, 0, 1.1)) -> void:
	ctx.body.get_node("MotionTestControls").cancel_motion()
	ctx.attack.cancel_attack()
	ctx.attack._cooldown_remaining = 0.0
	ctx.driver.reset_presentation()
	ctx.body.get_node("Health").reset()
	ctx.enemy.get_node("Health").reset()
	ctx.body.camera_lock_behind = false
	ctx.body.global_position = ORIGIN + Vector3.UP * height
	ctx.body.velocity = Vector3.ZERO
	if int(ctx.body.get_node("Mesh").character) != ctx.character:
		ctx.body.get_node("Mesh").set_character(ctx.character)
		ctx.driver._physics_process(0.0)
	ctx.body.get_node("Mesh").rotation.y = 0.0
	ctx.enemy.global_position = ORIGIN + target_offset
	# Main authors this cube at 45 degrees. Use an axis-aligned hurtbox so a
	# separating wall at .55 m does not cut through an exposed corner of the victim.
	ctx.enemy.rotation = Vector3.ZERO
	for effect in get_nodes_in_group("weapon_hit_effects"):
		effect.free()
	hits.clear()
	await frames(4)

func wait_for_hit(maximum_frames: int = 60) -> void:
	for frame in maximum_frames:
		if not hits.is_empty():
			return
		await frames(1)

func run() -> void:
	var bare := SHARED_PLAYER.instantiate()
	check(not bare.get_node("AttackHitbox").has_method("get_weapon_segment"), "shared/network player keeps its existing melee contract")
	bare.free()
	for character in [0, 1]:
		var ctx := await setup(character)
		await prepare(ctx)
		check(ctx.body.is_on_floor(), "ground fixture rests on the real floor")
		var segment: Array = ctx.attack.get_weapon_segment()
		var expected_length := 0.740422 if character == 0 else 0.96
		check(segment.size() == 2 and segment[0].is_finite() and segment[1].is_finite() and absf(segment[0].distance_to(segment[1]) - expected_length) < 0.04, "weapon segment uses the actual rig-specific blade length")
		check(ctx.attack.request_attack(), "ground weapon attack is accepted")
		check(not ctx.attack.is_jump_attack and ctx.driver.get_action_clip() == ctx.attack.current_clip, "ground attacker owns its selected animation without a second cycle")
		check(not ctx.attack.request_attack(), "active swing cannot restart or bypass cooldown")
		check(ctx.enemy.get_health() == 100.0 and hits.is_empty(), "attack request itself causes no damage or contact event")
		await frames(6)
		check(ctx.enemy.get_health() == 100.0 and hits.is_empty(), "windup remains harmless before the active blade window")
		await wait_for_hit()
		check(ctx.enemy.get_health() == 75.0 and hits.size() == 1, "ground blade contact damages once for 25")
		if not hits.is_empty():
			check(hits[0].target == ctx.enemy and hits[0].point.is_finite() and hits[0].normal.is_finite() and hits[0].amount == 25.0, "confirmed contact reports victim, finite surface and actual damage")
			var local_point: Vector3 = ctx.enemy.to_local(hits[0].point)
			var box_distance: Vector3 = local_point.abs() - Vector3(0.5, 1.0, 0.5)
			check(box_distance.x <= 0.02 and box_distance.y <= 0.02 and box_distance.z <= 0.02 and minf(absf(box_distance.x), minf(absf(box_distance.y), absf(box_distance.z))) < 0.02, "impact lies on the victim's actual collider surface")
		check(not get_nodes_in_group("weapon_hit_effects").is_empty(), "confirmed contact produces a hit effect")
		await frames(50)
		check(ctx.enemy.get_health() == 75.0 and hits.size() == 1 and ctx.body.get_health() == 100.0, "continued overlap cannot double-hit a victim or damage the wielder")
		check(get_nodes_in_group("weapon_hit_effects").is_empty(), "contact effects expire instead of accumulating")
		# Continue the accepted cycle without resetting presentation between swings.
		for expected_clip in ["Attack_Backhand", "Attack_Overhead", "Attack_Thrust"]:
			ctx.enemy.get_node("Health").reset()
			hits.clear()
			check(ctx.attack.request_attack() and ctx.attack.current_clip == expected_clip, "ground cycle selects " + expected_clip)
			await wait_for_hit()
			check(ctx.enemy.get_health() == 75.0 and hits.size() == 1, expected_clip + " confirms real blade contact")
			await frames(50)
		await prepare(ctx)
		Input.action_press("jump")
		for step in 3:
			await physics_frame
		Input.action_release("jump")
		await physics_frame
		check(not ctx.body.is_on_floor() and ctx.body.velocity.y > 0.0 and ctx.attack.request_attack(), "Space jump accepts an airborne attack while rising")
		await frames(6)
		check(ctx.attack.current_clip == "Attack_Overhead" and ctx.driver.get_locomotion_clip() == "Jump", "jump attack layers the overhead cut over airborne legs")
		await wait_for_hit()
		check(ctx.enemy.get_health() == 75.0 and hits.size() == 1 and hits[0].airborne, "a real jump attack reaches a standing enemy before landing")
		await frames(50)
		# A raised target intersects the descending blade while the attacker is
		# still genuinely airborne; ordinary gravity remains in charge of the body.
		await prepare(ctx, 2.2, Vector3(0, 1.0, 1.1))
		var initial_y: float = ctx.body.global_position.y
		var initial_velocity: float = ctx.body.velocity.y
		check(not ctx.body.is_on_floor() and ctx.attack.request_attack(), "airborne body accepts a jump attack")
		check(ctx.attack.is_jump_attack and ctx.attack.current_clip == "Attack_Overhead" and ctx.driver.get_action_clip() == "Attack_Overhead", "jump attack selects the explicit overhead clip")
		await frames(6)
		check(ctx.body.global_position.y < initial_y and ctx.body.velocity.y < initial_velocity, "jump attack preserves falling motion and gravity")
		check(ctx.enemy.get_health() == 100.0, "air attack cannot damage during anticipation")
		await wait_for_hit()
		check(ctx.enemy.get_health() == 75.0 and hits.size() == 1 and hits[0].airborne, "actual airborne weapon contact deals one hit")
		await frames(35)
		check(ctx.enemy.get_health() == 75.0 and hits.size() == 1, "air contact stays single-hit after landing")
		# High above a normal-height opponent, the blade cannot reach either the
		# target or the floor. Horizontal range alone must never create a hit/VFX.
		await prepare(ctx, maxf(6.0, ctx.body._project_gravity() * 3.0))
		check(ctx.attack.request_attack(), "high airborne miss starts its animation")
		var saw_effect := false
		for frame in 120:
			await frames(1)
			saw_effect = saw_effect or not get_nodes_in_group("weapon_hit_effects").is_empty()
			if ctx.attack._elapsed < 0.0 and ctx.attack._cooldown_remaining <= 0.0:
				break
		check(ctx.enemy.get_health() == 100.0 and hits.is_empty() and not saw_effect, "vertical separation produces neither damage nor a fabricated contact effect")
		check(ctx.attack._elapsed < 0.0 and ctx.attack._cooldown_remaining <= 0.0, "air budget fixture waits for action and cooldown completion")
		check(not ctx.body.is_on_floor() and not ctx.attack.request_attack(), "one air attack budget remains spent after action and cooldown end")
		for frame in 150:
			if ctx.body.is_on_floor():
				break
			await frames(1)
		check(ctx.body.is_on_floor() and ctx.attack.request_attack(), "landing restores the next attack opportunity")
		ctx.attack.cancel_attack()
		# A solid wall lies between the player capsule face (.5 m) and the
		# opponent's near face (.6 m). Even an animated hand beyond it is occluded.
		await prepare(ctx)
		var wall := StaticBody3D.new()
		wall.name = "WeaponOcclusionWall"
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(4.0, 5.0, 0.04)
		collision.shape = shape
		wall.add_child(collision)
		wall.position = ORIGIN + Vector3.BACK * 0.55
		ctx.main.add_child(wall)
		await frames(3)
		var wall_ray := PhysicsRayQueryParameters3D.create(ctx.body.global_position, ctx.enemy.global_position, 1, [ctx.body.get_rid()])
		check(ctx.body.get_world_3d().direct_space_state.intersect_ray(wall_ray).get("collider") == wall, "occlusion fixture has a real wall between attacker and victim")
		check(ctx.attack.request_attack(), "occluded swing still plays normally")
		await frames(50)
		check(ctx.enemy.get_health() == 100.0 and hits.is_empty(), "world occlusion prevents damage through a solid wall")
		wall.free()
		await prepare(ctx)
		ctx.enemy.get_node("Combatant").team_id = 0
		check(ctx.attack.request_attack(), "friendly contact still permits swing presentation")
		await frames(60)
		check(ctx.enemy.get_health() == 100.0 and hits.is_empty(), "friendly contact awards no damage or confirmed hit")
		ctx.enemy.get_node("Combatant").team_id = 1
		await prepare(ctx)
		ctx.body.get_node("Health").network_replica = true
		check(not ctx.attack.request_attack(), "replica wielder cannot start local melee authority")
		ctx.body.get_node("Health").network_replica = false
		ctx.enemy.get_node("Health").network_replica = true
		check(ctx.attack.request_attack(), "replica target fixture permits swing presentation")
		await frames(60)
		check(ctx.enemy.get_health() == 100.0 and hits.is_empty(), "local blade cannot mutate replica target health")
		ctx.enemy.get_node("Health").network_replica = false
		await prepare(ctx)
		check(ctx.attack.request_attack(), "focus cancellation fixture starts swing")
		ctx.attack.notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
		await frames(50)
		check(ctx.enemy.get_health() == 100.0 and hits.is_empty() and ctx.driver.get_action_clip().is_empty(), "focus loss cancels pending weapon contact and pose")
		await prepare(ctx)
		check(ctx.attack.request_attack(), "reset cancellation fixture starts swing")
		ctx.body.get_node("Health").reset()
		await frames(50)
		check(ctx.enemy.get_health() == 100.0 and hits.is_empty(), "health reset cannot leave a stale active weapon")
		await prepare(ctx)
		check(ctx.attack.request_attack(), "model cancellation fixture starts swing")
		ctx.body.get_node("Mesh").set_character(1 - character)
		ctx.driver._physics_process(0.0)
		await frames(50)
		check(ctx.enemy.get_health() == 100.0 and hits.is_empty(), "model replacement cancels old-rig weapon contact")
		await prepare(ctx)
		check(ctx.attack.request_attack(), "motion cancellation fixture starts swing")
		check(ctx.body.get_node("MotionTestControls").request_dodge(Vector3.FORWARD), "higher-priority evasion may take over from a melee windup")
		await frames(50)
		check(ctx.enemy.get_health() == 100.0 and hits.is_empty(), "evasion cancels the previous weapon hit window")
		await prepare(ctx)
		check(ctx.attack.request_attack(), "death cancellation fixture starts swing")
		ctx.body.apply_damage(100.0, ctx.enemy)
		await frames(50)
		check(ctx.enemy.get_health() == 100.0 and hits.is_empty() and not ctx.attack.request_attack(), "death clears pending contact and rejects further attacks")
		ctx.body.get_node("Combatant")._respawn()
		check(ctx.attack.request_attack(), "respawn clears the previous life cooldown and permits a fresh attack")
		ctx.main.get_node("MatchManager")._end_match(-1)
		await frames(60)
		check(ctx.enemy.get_health() == 100.0 and hits.is_empty() and ctx.attack.current_clip.is_empty() and not ctx.attack.request_attack(), "match end cancels pending contact and rejects late attacks")
		ctx.main.free()
		await frames(2)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	print("WEAPON_ATTACK_CHECKS=", checks, " FAILURES=", failures, " ALL_TESTS_PASS=", failures == 0)
	quit(0 if failures == 0 else 1)
