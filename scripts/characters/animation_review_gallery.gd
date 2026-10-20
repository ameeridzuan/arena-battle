extends Node3D
## Isolated, noninteractive gameplay bodies for animation review. No damage or networking.
const PLAYER := preload("res://scenes/characters/Player.tscn")
const MODES := ["Auto: locomotion transitions", "Idle", "Walk", "Run", "Jump", "Attack_Slash", "Attack_Backhand", "Attack_Overhead", "Attack_Thrust", "Attack_Combo", "Review/FallLoop", "Review/LandSoft", "Review/HitFront", "Review/HitBack", "Review/HitLeft", "Review/HitRight", "Review/KnockbackTravel", "Review/KnockbackRecover", "Capture/JumpCapture", "Capture/StrafeCapture", "Walk_Backward", "Walk_Left", "Walk_Right", "Direction/RunStartCapture", "Direction/RunStopCapture", "Direction/TurnLeftCapture", "Direction/TurnRightCapture", "Direction/BlockLeftCapture", "Direction/BlockRightCapture"]
const SPEEDS := [0.0, 0.8, 1.2, 3.8, 2.0, 1.9, 1.8, 1.2, 0.55, 0.45, 0.35, 0.0]
var bodies: Array[CharacterBody3D] = []
var mode := 0
var paused := false
var playback_speed := 1.0
var elapsed := 0.0
var readout: Label
var mode_selector: OptionButton
var pause_button: Button
const MOVING_ACTION_MODES := ["Layered/WalkAttack", "Layered/RunAttack", "Layered/StrafeAttack", "Layered/BackwardAttack"]
var _last_attack_tick := -1

func _ready() -> void:
	_build_stage()
	for i in range(2):
		var body: CharacterBody3D = PLAYER.instantiate()
		body.name = "Arclight" if i == 0 else "AshenWarden"
		body.external_control = true
		body.collision_layer = 0
		body.collision_mask = 0
		body.get_node("Combatant").free()
		body.get_node("Mesh").character = i
		body.get_node("AttackHitbox").external_control = true
		body.get_node("AttackHitbox").monitoring = false
		body.get_node("CameraPivot").local_input_enabled = false
		body.get_node("CameraPivot/CameraTilt/Camera3D").current = false
		body.position = Vector3(-2.0 if i == 0 else 2.0, 1.0, 0.0)
		add_child(body)
		body.set_physics_process(false)
		body.get_node("AttackHitbox").set_physics_process(false)
		var library_path := "res://assets/animations/review/%s.tres" % ("arclight" if i == 0 else "ashen_warden")
		body.get_node("CharacterAnimation")._anim.add_animation_library("Review", load(library_path))
		var captured: AnimationLibrary = load("res://assets/animations/locomotion/%s.tres" % ("arclight" if i == 0 else "ashen_warden"))
		body.get_node("CharacterAnimation")._anim.add_animation_library("Capture", captured.duplicate(true))
		var directional: AnimationLibrary = load("res://assets/animations/directional/%s.tres" % ("arclight" if i == 0 else "ashen_warden"))
		body.get_node("CharacterAnimation")._anim.add_animation_library("Direction", directional.duplicate(true))
		bodies.append(body)
	_build_ui()
	_set_mode(0)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _build_stage() -> void:
	var camera := Camera3D.new()
	add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 5.5
	camera.position = Vector3(2, 2.8, 10)
	camera.look_at(Vector3(0, 1.4, 0))
	camera.current = true
	var light := DirectionalLight3D.new()
	add_child(light)
	light.rotation_degrees = Vector3(-50, -25, 0)
	light.light_energy = 1.5
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("16202e")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.6
	add_child(environment)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(16, 12)
	floor_mesh.mesh = plane
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("47505b")
	floor_mesh.material_override = material
	add_child(floor_mesh)
	for i in range(2):
		var label := Label3D.new()
		label.text = "ARCLIGHT" if i == 0 else "ASHEN WARDEN"
		label.position = Vector3(-2 if i == 0 else 2, 2.6, 0)
		label.font_size = 40
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		add_child(label)

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := VBoxContainer.new()
	panel.position = Vector2(20, 16)
	panel.add_theme_constant_override("separation", 8)
	layer.add_child(panel)
	var title := Label.new()
	title.text = "ANIMATION REVIEW  |  HUMAN MOTION"
	title.add_theme_font_size_override("font_size", 24)
	panel.add_child(title)
	var note := Label.new()
	note.text = "In-place clip review. Bodies do not move; no combat or network simulation."
	panel.add_child(note)
	var controls := HBoxContainer.new()
	panel.add_child(controls)
	var select := OptionButton.new()
	mode_selector = select
	for entry in MODES:
		select.add_item(entry)
	for entry in MOVING_ACTION_MODES:
		select.add_item(entry)
	select.item_selected.connect(_set_mode)
	controls.add_child(select)
	pause_button = Button.new()
	pause_button.text = "Pause"
	pause_button.pressed.connect(func(): _set_paused(not paused))
	controls.add_child(pause_button)
	var step := Button.new()
	step.text = "Step 1/30 s"
	step.pressed.connect(_step)
	controls.add_child(step)
	var restart := Button.new()
	restart.text = "Restart"
	restart.pressed.connect(func(): _set_mode(mode))
	controls.add_child(restart)
	var speed := OptionButton.new()
	for value in ["0.25x", "0.5x", "1x"]:
		speed.add_item(value)
	speed.select(2)
	speed.item_selected.connect(func(index: int):
		playback_speed = [0.25, 0.5, 1.0][index]
		_apply_playback())
	controls.add_child(speed)
	readout = Label.new()
	panel.add_child(readout)
	var pending := Label.new()
	pending.position = Vector2(20, 625)
	pending.text = "GAMEPLAY: forward/backward/side walking and forward run. Other modes are animation previews.\nDirectional hit / knockback remain drafts. Casting / skills / parry / block / dash / death are planned.\nCapture previews and reaction drafts have no new gameplay triggers or displacement."
	layer.add_child(pending)

func _set_mode(index: int) -> void:
	mode = index
	mode_selector.select(index)
	elapsed = 0.0
	_last_attack_tick = -1
	for body in bodies:
		var driver: Node = body.get_node("CharacterAnimation")
		driver.set_manual_preview(not _runtime_mode())
		driver.reset_presentation()
		driver._anim.stop()
		if not _runtime_mode() and driver._anim.has_animation(MODES[mode]):
			driver._anim.play(MODES[mode], 0.0)
	_set_paused(false)

func _set_paused(value: bool) -> void:
	paused = value
	pause_button.text = "Resume" if paused else "Pause"
	_apply_playback()

func _apply_playback() -> void:
	for body in bodies:
		var driver: Node = body.get_node("CharacterAnimation")
		driver.playback_multiplier = playback_speed
		driver.set_physics_process(_runtime_mode() and not paused)
		if not _runtime_mode():
			driver._anim.speed_scale = 0.0 if paused else playback_speed

func _step() -> void:
	_set_paused(true)
	elapsed += 1.0 / 30.0
	_update_velocity()
	for body in bodies:
		var driver: Node = body.get_node("CharacterAnimation")
		if _runtime_mode():
			var multiplier: float = driver.playback_multiplier
			driver.playback_multiplier = 1.0
			driver._physics_process(1.0 / 30.0)
			driver.playback_multiplier = multiplier
		else:
			driver._anim.speed_scale = 1.0
			driver._anim.advance(1.0 / 30.0)
			driver._anim.speed_scale = 0.0

func _update_velocity() -> void:
	var speed: float = SPEEDS[int(elapsed / 1.4) % SPEEDS.size()]
	for body in bodies:
		body.velocity = Vector3(0, 0, speed if mode == 0 else 0.0)
		if mode >= MODES.size():
			body.velocity = [Vector3.BACK * 1.2, Vector3.BACK * 3.8, Vector3.RIGHT * 1.2, Vector3.FORWARD * 1.2][mode - MODES.size()]
	if mode >= MODES.size() and int(elapsed / 1.4) != _last_attack_tick:
		_last_attack_tick = int(elapsed / 1.4)
		for body in bodies:
			body.get_node("CharacterAnimation")._on_attack_started(Vector3.BACK)

func _runtime_mode() -> bool:
	return mode == 0 or mode >= MODES.size()

func _process(delta: float) -> void:
	if not paused:
		elapsed += delta * playback_speed
	_update_velocity()
	var descriptions: Array[String] = []
	for body in bodies:
		var driver: Node = body.get_node("CharacterAnimation")
		var animation: AnimationPlayer = driver._anim
		if _runtime_mode():
			descriptions.append("%s: %s + %s  %.2f s" % [body.name, driver.get_locomotion_clip(), driver.get_action_clip(), driver.get_locomotion_position()])
		else:
			descriptions.append("%s: %s  %.2f s" % [body.name, animation.current_animation, animation.current_animation_position if animation.is_playing() else 0.0])
	readout.text = "Sample speed: %.2f m/s | blend: 0.15 s\n%s" % [Vector2(bodies[0].velocity.x, bodies[0].velocity.z).length(), "  /  ".join(descriptions)]
