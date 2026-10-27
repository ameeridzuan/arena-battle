extends SceneTree
## Local ranged combat: swept impact, periodic burn, attribution and damage presentation.
const MAIN := preload("res://scenes/main/Main.tscn")
const BOLT := preload("res://scripts/characters/test_energy_bolt.gd")
const ORIGIN := Vector3(-6.0, 1.0, -6.0)
var checks := 0
var failures := 0
var main: Node
var body: CharacterBody3D
var enemy: Node3D
var health: Node
var burn: Node
var manager: Node
var damage_events: Array = []

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

func prepare() -> void:
	burn.clear()
	health.network_replica = false
	health.max_health = 100.0
	if enemy.get_node("Combatant").is_dead():
		enemy.get_node("Combatant")._respawn()
	else:
		health.reset()
	burn.set_physics_process(false)
	# Impact enables the component, so disable automatic scheduling at the node-mode
	# level while testing exact intervals through explicit deterministic steps.
	burn.process_mode = Node.PROCESS_MODE_DISABLED
	body.global_position = ORIGIN
	body.velocity = Vector3.ZERO
	enemy.global_position = ORIGIN + Vector3.BACK * 5.0
	for actor in [body, enemy, main.get_node("Opponent2")]:
		actor.get_node("AttackHitbox").auto_attack = false
		actor.get_node("AttackHitbox").set_physics_process(false)
	for label in get_nodes_in_group("floating_damage_numbers"):
		label.free()
	damage_events.clear()
	await frames(4)

func fire(origin: Vector3, direction: Vector3 = Vector3.BACK, owner_body: Node = null) -> Node3D:
	var bolt := Node3D.new()
	bolt.set_script(BOLT)
	bolt.source = body if owner_body == null else owner_body
	bolt.source_rid = bolt.source.get_rid()
	bolt.direction = direction
	bolt.position = origin
	main.add_child(bolt)
	return bolt

func last_number_contains(amount: String) -> bool:
	var numbers := get_nodes_in_group("floating_damage_numbers")
	return not numbers.is_empty() and str(numbers[-1].text).contains(amount)

func run() -> void:
	main = MAIN.instantiate()
	root.add_child(main)
	body = main.get_node("Player")
	enemy = main.get_node("Opponent1")
	health = enemy.get_node("Health")
	burn = enemy.get_node("BurnStatus")
	manager = main.get_node("MatchManager")
	manager.set_physics_process(false)
	main.get_node("Opponent2").global_position = Vector3(8, 1, 8)
	for actor in [body, enemy, main.get_node("Opponent2")]:
		actor.get_node("AttackHitbox").auto_attack = false
		actor.get_node("AttackHitbox").set_physics_process(false)
	await frames(12)
	health.damage_taken.connect(func(amount: float, source: Node, kind: StringName):
		damage_events.append({"amount": amount, "source": source, "kind": kind}))
	check(body.has_node("DamageFeedback") and enemy.has_node("DamageFeedback"), "both actor types install reusable damage feedback")
	body.apply_damage(7.0, enemy)
	check(body.get_health() == 93.0 and last_number_contains("7"), "being hit displays damage on the local player too")
	body.get_node("Health").reset()
	await prepare()
	var bolt := fire(ORIGIN + Vector3.BACK * 0.7)
	await frames(24)
	check(not is_instance_valid(bolt), "swept projectile is consumed on one target contact")
	check(health.get_health() == 80.0, "ranged impact applies 20 damage once")
	check(damage_events.size() == 1 and damage_events[0].amount == 20.0 and damage_events[0].source == body, "impact preserves original caster attribution")
	check(last_number_contains("20"), "impact displays a floating damage amount")
	check(burn.is_burning(), "ranged impact starts burn")
	burn._physics_process(0.99)
	check(health.get_health() == 80.0, "burn cannot tick before its interval")
	burn._physics_process(0.02)
	check(health.get_health() == 77.0 and damage_events.size() == 2, "first burn interval applies exactly one tick")
	check(damage_events[-1].source == body and damage_events[-1].kind == &"burn", "burn tick keeps source and distinct damage kind")
	check(last_number_contains("3"), "burn tick displays its damage amount")
	var burn_number: Label3D = get_nodes_in_group("floating_damage_numbers")[-1]
	check(burn_number.text.contains("BURN") and burn_number.modulate.r > burn_number.modulate.b, "burn damage has a readable warm-colored label distinct from impact")
	burn._physics_process(1.0)
	burn._physics_process(1.0)
	check(health.get_health() == 71.0 and not burn.is_burning(), "three-second burn ends after three ticks totaling nine damage")
	burn._physics_process(10.0)
	check(health.get_health() == 71.0 and damage_events.size() == 4, "expired burn cannot inflict extra damage")
	# Exercise the actual cast adapter too: source/damage fields must be bound by
	# controls, not only by this fixture's direct-projectile helper.
	await prepare()
	var controls: Node = body.get_node("MotionTestControls")
	var driver: Node = body.get_node("CharacterAnimation")
	controls.cancel_motion()
	controls._cast_cooldown = 0.0
	driver.reset_presentation()
	burn.process_mode = Node.PROCESS_MODE_INHERIT
	body.camera_lock_behind = true
	body.get_node("Mesh").rotation.y = 0.0
	body.get_node("CameraPivot").rotation.y = PI
	body.get_node("CameraPivot/CameraTilt").rotation = Vector3.ZERO
	var camera: Camera3D = body.get_node("CameraPivot/CameraTilt/Camera3D")
	# Default camera height is 1.2 m above the body; aim down at the target's
	# actual center so the ray reaches its box rather than passing above it.
	camera.look_at(enemy.global_position, Vector3.UP)
	var releases: Array = []
	controls.cast_released.connect(func(origin: Vector3, direction: Vector3): releases.append([origin, direction]))
	check(controls.request_cast(), "real aim-mode controls accept a ranged cast")
	await frames(24)
	var emitted := get_nodes_in_group("motion_test_bolts")
	check(releases.size() == 1 and emitted.size() == 1 and emitted[0].source == body and emitted[0].source_rid == body.get_rid(), "real cast emits one bolt bound to original caster and collision exclusion")
	await frames(30)
	check(health.get_health() == 80.0 and burn.is_burning() and damage_events.size() == 1 and damage_events[0].source == body, "real cast flight hits aimed opponent for configured impact and burn")
	await frames(194)
	check(health.get_health() == 71.0 and not burn.is_burning() and damage_events.size() == 4 and damage_events[-1].source == body and damage_events[-1].kind == &"burn", "real cast burn naturally ticks three times and expires with original caster attribution")
	body.camera_lock_behind = false
	await prepare()
	check(burn.apply_burn(body, 3.0, 3, 1.0), "live opponent accepts a burn")
	burn._physics_process(0.8)
	check(burn.apply_burn(body, 3.0, 3, 1.0), "repeat application refreshes existing burn")
	burn._physics_process(0.3)
	check(health.get_health() == 97.0, "refresh retains next tick cadence rather than delaying burn or stacking timers")
	burn._physics_process(0.7)
	burn._physics_process(2.0)
	check(health.get_health() == 91.0 and not burn.is_burning(), "refreshed burn has one bounded tick stream")
	await prepare()
	check(not burn.apply_burn(body, -1.0, 3, 1.0) and not burn.apply_burn(body, 3.0, 0, 1.0) and not burn.apply_burn(body, 3.0, 3, 0.0), "invalid status parameters do not start burn")
	check(not burn.is_burning(), "invalid status attempts leave no pending ticks")
	health.apply_damage(-4.0, body)
	health.apply_damage(0.0, body)
	health.apply_damage(NAN, body)
	check(damage_events.is_empty() and get_nodes_in_group("floating_damage_numbers").is_empty(), "invalid damage produces neither events nor numbers")
	# The physical source is excluded; the bolt travels out of its collision volume.
	bolt = fire(body.global_position)
	await frames(28)
	check(body.get_health() == 100.0 and health.get_health() == 80.0, "projectile launched inside caster excludes self but reaches opponent")
	await prepare()
	enemy.get_node("Combatant").team_id = 0
	bolt = fire(ORIGIN + Vector3.BACK * 0.7)
	await frames(24)
	check(health.get_health() == 100.0 and not burn.is_burning() and damage_events.is_empty(), "friendly contact awards neither impact nor burn")
	enemy.get_node("Combatant").team_id = 1
	await prepare()
	health.network_replica = true
	bolt = fire(ORIGIN + Vector3.BACK * 0.7)
	await frames(24)
	check(health.get_health() == 100.0 and not burn.is_burning(), "local bolt cannot mutate replica health or status")
	check(not burn.apply_burn(body, 3.0, 3, 1.0), "replica rejects local burn application")
	health.apply_network_state(75.0, 100.0)
	check(damage_events.is_empty(), "first network health snapshot establishes a silent baseline")
	health.apply_network_state(68.0, 100.0)
	check(damage_events.size() == 1 and damage_events[-1].amount == 7.0 and last_number_contains("7"), "later replicated health loss displays the authoritative damage delta")
	health.apply_network_state(100.0, 100.0)
	check(damage_events.size() == 1, "replicated healing does not display a damage number")
	health.network_replica = false
	await prepare()
	var wall := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(3, 3, 0.2)
	collision.shape = shape
	wall.add_child(collision)
	wall.position = ORIGIN + Vector3.BACK * 2.0
	main.add_child(wall)
	await frames(3)
	bolt = fire(ORIGIN + Vector3.BACK * 0.7)
	await frames(24)
	check(not is_instance_valid(bolt) and health.get_health() == 100.0 and not burn.is_burning(), "world collision consumes bolt before target without damage")
	wall.free()
	await prepare()
	burn.apply_burn(body, 3.0, 3, 1.0)
	burn._physics_process(1.0)
	health.reset()
	burn._physics_process(5.0)
	check(health.get_health() == 100.0 and not burn.is_burning(), "health reset clears burn before the next life")
	# A lethal periodic tick must score for the original caster, not a transient bolt.
	await prepare()
	health.max_health = 2.0
	health.reset()
	var previous_score: int = manager.score_a
	check(burn.apply_burn(body, 3.0, 3, 1.0), "lethal fixture starts burn while alive")
	burn._physics_process(1.0)
	check(health.get_health() == 0.0 and manager.score_a == previous_score + 1, "lethal burn credits caster team once")
	check(damage_events[-1].amount == 2.0 and last_number_contains("2"), "overkill reports actual health lost instead of requested damage")
	check(not burn.is_burning(), "death clears remaining burn ticks")
	burn._physics_process(5.0)
	check(manager.score_a == previous_score + 1, "dead target cannot award repeated burn kills")
	await prepare()
	# Presentation is finite even when several damage labels coexist.
	health.apply_damage(1.0, body)
	health.apply_damage(2.0, body)
	check(get_nodes_in_group("floating_damage_numbers").size() == 2, "separate hits each display their own amount")
	await frames(100)
	check(get_nodes_in_group("floating_damage_numbers").is_empty(), "floating damage labels expire without accumulating")
	burn.apply_burn(body, 3.0, 3, 1.0)
	manager.score_limit = manager.score_a + 1
	manager.register_kill(0, 1)
	burn._physics_process(5.0)
	check(manager.get_phase() == 2 and health.get_health() == 97.0 and not burn.is_burning(), "match end clears burn and prevents late damage")
	main.free()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	print("RANGED_DAMAGE_CHECKS=", checks, " FAILURES=", failures, " ALL_TESTS_PASS=", failures == 0)
	quit(0 if failures == 0 else 1)
