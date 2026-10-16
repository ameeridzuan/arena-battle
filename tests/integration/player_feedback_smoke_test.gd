extends SceneTree
## Presentation integration: actual health/death/respawn and cooldown-gated attacks.
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

func _run() -> void:
	var main := MAIN.instantiate()
	root.add_child(main)
	await _frames(5)
	var player: Variant = main.get_node("Player")
	var health: Variant = player.get_node("Health")
	var feedback: Variant = player.get_node("PlayerFeedback")
	var attack: Variant = player.get_node("AttackHitbox")
	var mesh: Variant = player.get_node("Mesh")
	var hud: Variant = main.get_node("HUD")
	var bar: Variant = hud.get_node("HealthBar")
	var label: Variant = hud.get_node("HealthLabel")
	var original: Material = mesh.material_override
	var swings := [0]
	attack.attack_started.connect(func(_forward: Vector3): swings[0] += 1)
	_check("initial_hp", bar.value == 100.0 and bar.max_value == 100.0 and label.text == "HP: 100 / 100")
	_check("initial_feedback_idle", not feedback.get_node("AttackSwipe").visible and hud.get_node("DamageTint").color.a == 0.0)
	# Genuine input exercises the cooldown path. No opponent is nearby: this is a miss.
	Input.action_press("attack")
	await _frames(1)
	Input.action_release("attack")
	await _frames(1)
	_check("miss_has_swipe", swings[0] == 1 and feedback.get_node("AttackSwipe").visible)
	var forward: Vector3 = -player.get_node("CameraPivot").global_basis.z
	var visual_forward: Vector3 = -feedback.get_node("AttackSwipe").global_basis.z
	_check("swipe_aims_with_camera", forward.dot(visual_forward) > 0.999)
	Input.action_press("attack")
	await _frames(1)
	Input.action_release("attack")
	await _frames(1)
	_check("cooldown_does_not_repeat_swipe", swings[0] == 1)
	player.apply_damage(20.0, main.get_node("Opponent1"))
	_check("damage_updates_hp", bar.value == 80.0 and label.text == "HP: 80 / 100")
	_check("damage_flashes_player", mesh.material_override != original)
	# Sample the visual update before its 180ms fade expires. Waiting for physics
	# frames can exceed that wall time when other Godot processes load the machine.
	hud._process(0.0)
	_check("damage_tints_view", hud.get_node("DamageTint").color.a > 0.0)
	# Allow presentation effects to expire, independently of attack/health rules.
	await create_timer(0.3).timeout
	_check("effects_expire", not feedback.get_node("AttackSwipe").visible and mesh.material_override == original and hud.get_node("DamageTint").color.a == 0.0)
	# A zero-damage health notification must not trigger hurt feedback.
	player.apply_damage(0.0, main.get_node("Opponent1"))
	_check("unchanged_hp_no_flash", mesh.material_override == original and hud._tint_remaining == 0.0)
	player.get_node("Combatant").respawn_delay = 0.1
	player.apply_damage(999.0, main.get_node("Opponent1"))
	_check("death_zero_hp", bar.value == 0.0 and label.text == "HP: 0 / 100" and not mesh.visible)
	_check("death_clears_swipe", not feedback.get_node("AttackSwipe").visible)
	await create_timer(0.2).timeout
	await _frames(2)
	_check("respawn_restores_hp", bar.value == 100.0 and label.text == "HP: 100 / 100" and mesh.visible)
	_check("respawn_no_hurt_flash", mesh.material_override == original and hud.get_node("DamageTint").color.a == 0.0)
	# Non-default maximum must drive the bar and text, not a hardcoded 100.
	health.max_health = 150.0
	health.reset()
	_check("configurable_maximum", bar.max_value == 150.0 and bar.value == 150.0 and label.text == "HP: 150 / 150")
	main.queue_free()
	await _frames(2)
	var passed := not _results.has(false)
	print("ALL_TESTS_PASS=", passed)
	quit(0 if passed else 1)
