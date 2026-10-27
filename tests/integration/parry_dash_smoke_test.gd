extends SceneTree
## Main-local combat tests: real windup/contact, displacement avoidance and timed frontal parry.
const MAIN := preload("res://scenes/main/Main.tscn")
const ORIGIN := Vector3(-6, 1, -6)
var checks := 0
var failures := 0
var main: Node
var body: CharacterBody3D
var controls: Node
var driver: Node
var enemy: Node3D
var attacker: Node
var successes: Array = []

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
	controls.cancel_motion()
	controls._cast_cooldown = 0.0
	controls._dodge_cooldown = 0.0
	controls._parry_cooldown = 0.0
	driver.reset_presentation()
	body.get_node("Health").reset()
	body.camera_lock_behind = false
	body.global_position = ORIGIN
	body.velocity = Vector3.ZERO
	body.get_node("Mesh").rotation.y = 0.0
	enemy.global_position = ORIGIN + Vector3.BACK * 1.5
	enemy.rotation.y = 0.0
	attacker.auto_attack = false
	attacker._cooldown_remaining = 0.0
	attacker._windup_remaining = -1.0
	attacker.set_physics_process(true)
	await frames(8)

func run() -> void:
	main = MAIN.instantiate()
	root.add_child(main)
	body = main.get_node("Player")
	controls = body.get_node("MotionTestControls")
	driver = body.get_node("CharacterAnimation")
	enemy = main.get_node("Opponent1")
	attacker = enemy.get_node("AttackHitbox")
	for name in ["Opponent1", "Opponent2"]:
		main.get_node(name + "/AttackHitbox").auto_attack = false
		main.get_node(name + "/AttackHitbox").set_physics_process(false)
	main.get_node("MatchManager").set_physics_process(false)
	controls.parry_succeeded.connect(func(source: Node): successes.append(source))
	await frames(12)
	check(attacker.has_method("start_windup"), "Main opponents expose a real telegraphed attack")
	for character in [0, 1]:
		body.get_node("Mesh").set_character(character)
		driver._physics_process(0.0)
		await prepare()
		check(attacker.start_windup(), "idle control starts enemy windup")
		await frames(8)
		check(body.get_health() == 100, "telegraph has no premature damage")
		await frames(18)
		check(body.get_health() == 80, "standing in range takes the real contact hit")
		await prepare()
		check(attacker.start_windup(), "avoidance fixture starts same attack")
		var start := body.global_position
		check(controls.request_dodge(Vector3.FORWARD), "backward dodge accepted before contact")
		await frames(1)
		check((body.global_position - start).dot(Vector3.FORWARD) > 0.015, "dodge responds on the first physics update")
		await frames(25)
		check(body.get_health() == 100 and body.global_position.distance_to(enemy.global_position) > attacker.attack_range, "actual displacement avoids the range-validated contact")
		body.apply_damage(3.0, main)
		check(body.get_health() == 97, "successful avoidance did not grant damage immunity")
		# A wall removes the escape distance: the same attack must damage the dodging body.
		await prepare()
		var wall := StaticBody3D.new()
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(4.0, 4.0, 0.2)
		collision.shape = shape
		wall.add_child(collision)
		main.add_child(wall)
		wall.global_position = ORIGIN + Vector3.FORWARD * 0.9
		await frames(3)
		check(attacker.start_windup() and controls.request_dodge(Vector3.FORWARD), "wall-blocked avoidance starts")
		await frames(26)
		check(body.get_health() == 80 and body.global_position.distance_to(enemy.global_position) < attacker.attack_range, "blocked dodge still takes the contact hit")
		wall.free()
		# Forward is a distinct dash: farther and faster than the side/back dodge.
		await prepare()
		enemy.global_position = Vector3(6, 1, 6)
		await frames(3)
		start = body.global_position
		check(controls.request_dodge(Vector3.BACK), "forward movement accepts dash")
		check(driver.get_action_clip() == "Actions/Dash_Forward", "forward request selects dash rather than dodge")
		await frames(1)
		check((body.global_position - start).z > 0.03, "dash moves immediately")
		await frames(27)
		var dash_distance := (body.global_position - start).length()
		check(dash_distance > 2.9 and dash_distance < 3.9, "forward dash delivers bounded approximately 3.35 m travel")
		# Parry late in a telegraph so the actual .32-second contact falls in its active window.
		await prepare()
		var prior_successes := successes.size()
		check(attacker.start_windup(), "parry fixture starts enemy telegraph")
		await frames(10)
		check(controls.request_parry(), "frontal parry accepted during enemy anticipation")
		check(not controls.request_parry(), "parry cannot restart its own active attempt")
		await frames(14)
		check(body.get_health() == 100 and successes.size() == prior_successes + 1 and successes[-1] == enemy, "timed frontal contact produces confirmed parry")
		check(driver.get_action_clip() == "Actions/Parry_Success", "success animation follows confirmed contact")
		check(enemy.get_node("Health").get_health() == 100, "parry never awards an automatic counterattack")
		attacker._perform_attack()
		check(body.get_health() == 80 and successes.size() == prior_successes + 1, "one attempt cannot block a second contact")
		check(not controls.request_parry(), "confirmed parry still obeys cooldown")
		await prepare()
		prior_successes = successes.size()
		check(controls.request_parry(), "startup fixture starts parry")
		attacker._perform_attack()
		check(body.get_health() == 80 and successes.size() == prior_successes, "startup is vulnerable before active window")
		await prepare()
		check(controls.request_parry(), "recovery fixture starts parry")
		await frames(18)
		attacker._perform_attack()
		check(body.get_health() == 80 and successes.size() == prior_successes, "late recovery is vulnerable after active window")
		await prepare()
		enemy.global_position = ORIGIN + Vector3.FORWARD * 1.5
		enemy.rotation.y = PI
		await frames(3)
		check(controls.request_parry(), "rear-contact fixture starts parry")
		await frames(5)
		attacker._perform_attack()
		check(body.get_health() == 80 and successes.size() == prior_successes, "rear melee contact bypasses frontal parry")
		await prepare()
		check(controls.request_parry(), "environmental-hit fixture starts parry")
		await frames(5)
		body.apply_damage(7.0, main)
		check(body.get_health() == 93 and successes.size() == prior_successes, "non-melee damage cannot be parried")
		controls.notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
		check(controls._parry_elapsed < 0 and driver.get_action_clip().is_empty(), "focus loss cancels parry presentation and active state")
		await prepare()
		check(controls.request_parry(), "model-swap fixture starts parry")
		controls.switch_character()
		check(controls._parry_elapsed < 0 and driver.get_action_clip().is_empty(), "model switch cancels parry")
	controls.cancel_motion()
	attacker.set_physics_process(false)
	main.free()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	print("PARRY_DASH_CHECKS=", checks, " FAILURES=", failures, " ALL_TESTS_PASS=", failures == 0)
	quit(0 if failures == 0 else 1)
