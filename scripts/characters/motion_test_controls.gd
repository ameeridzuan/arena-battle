extends Node
## Shared action state: local input or authoritative network requests drive its clocks.
signal cast_released(origin: Vector3, direction: Vector3)
signal dodge_started(direction: Vector3, clip: String)
signal parry_succeeded(source: Node)
const ACTIONS := preload("res://scripts/player/action_library.gd")
const SECTORS := preload("res://scripts/player/movement_direction.gd")
const BOLT := preload("res://scripts/characters/test_energy_bolt.gd")
const PROFILES := preload("res://scripts/player/motion_profiles.gd")
const DODGE_IDS := ["Dash_Forward", "Dodge_Right", "Dodge_Backward", "Dodge_Left"]
const DODGE_DIRECTIONS := [Vector3.BACK, Vector3.RIGHT, Vector3.FORWARD, Vector3.LEFT]
## Session drives authoritative clocks and requests; replicas only present snapshots.
var network_authority := false
var network_driven := false
@export var cast_cooldown_s := 1.0
@export var ranged_damage := 20.0
@export var burn_damage := 3.0
@export var burn_ticks := 3
@export var burn_interval_s := 1.0
@export var dodge_cooldown_s := 0.75
@export var dash_cooldown_s := 0.85
@export var dodge_peak_speed := 8.0
@export var dash_peak_speed := 11.0
var _body: CharacterBody3D
var _driver: Node
var _melee: Node
var _manager: Node
var _cast_cooldown := 0.0
var _dodge_cooldown := 0.0
var _cast_elapsed := -1.0
var _cast_release_time := 0.34
var _cast_duration := 0.86
var _cast_released := false
var _cast_token := 0
var _last_released_token := -1
var _dodge_active := false
var _dodge_elapsed := 0.0
var _dodge_duration := 0.72
var _dodge_direction := Vector3.ZERO
var _evasion_id := "Dodge_Backward"
var _parry_elapsed := -1.0
var _parry_duration := PROFILES.PARRY_DURATION
var _parry_cooldown := 0.0
var _parry_confirmed := false
var _melee_suppressed := false
var _melee_was_enabled := false
var _status: Label
var _reticle: Label
var _capture_was_active := false
var _notice := "V then R: fire + burn. Q: dash/dodge. F: parry. Tab: switch character."

func _ready() -> void:
	process_physics_priority = -20
	_body = get_parent() as CharacterBody3D
	_driver = _body.get_node("CharacterAnimation")
	_melee = _body.get_node("AttackHitbox")
	_manager = get_tree().get_first_node_in_group("match_manager")
	_body.get_node("Health").health_changed.connect(_on_health_changed)
	if _manager != null:
		_manager.match_ended.connect(func(_winner: int): cancel_motion())
	_register_key("motion_cast", KEY_R)
	_register_key("motion_dodge", KEY_Q)
	_register_key("motion_parry", KEY_F)
	_register_key("motion_switch_character", KEY_TAB)
	if not network_driven:
		_show_controls.call_deferred()

func _register_key(action: StringName, key: Key) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	var event := InputEventKey.new()
	event.physical_keycode = key
	InputMap.action_add_event(action, event)

func _show_controls() -> void:
	var help := get_node_or_null("../../HUD/ControlsLabel") as Label
	if help != null:
		help.text = "LOCAL MOTION TEST | WASD: move | Shift: run | Space: jump | Left click: melee\nSpace + left click: jump attack | Weapon sparks confirm contact\nV then R: fire + burn | Q + forward: dash | Q + side/back: dodge | Q alone: backstep\nF: timed frontal parry | Tab: switch character | Esc: release cursor\nReact to enemies' orange STRIKE windup. Spell: 20 damage + 3 burn/second for 3 seconds."
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	_status = Label.new()
	_status.position = Vector2(16, 180)
	_status.add_theme_color_override("font_shadow_color", Color.BLACK)
	_status.add_theme_constant_override("shadow_offset_x", 2)
	_status.add_theme_constant_override("shadow_offset_y", 2)
	layer.add_child(_status)
	_reticle = Label.new()
	_reticle.text = "+"
	_reticle.anchor_left = 0.5
	_reticle.anchor_right = 0.5
	_reticle.anchor_top = 0.5
	_reticle.anchor_bottom = 0.5
	_reticle.offset_left = -10.0
	_reticle.offset_right = 10.0
	_reticle.offset_top = -16.0
	_reticle.offset_bottom = 16.0
	_reticle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reticle.add_theme_font_size_override("font_size", 24)
	_reticle.add_theme_color_override("font_color", Color(0.2, 0.95, 1.0))
	_reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reticle.visible = false
	layer.add_child(_reticle)

func _physics_process(delta: float) -> void:
	_cast_cooldown = maxf(0.0, _cast_cooldown - delta)
	_dodge_cooldown = maxf(0.0, _dodge_cooldown - delta)
	_parry_cooldown = maxf(0.0, _parry_cooldown - delta)
	var captured := not network_driven and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if _capture_was_active and not captured:
		cancel_motion()
	_capture_was_active = captured
	if not _can_act():
		cancel_motion()
		_update_status()
		return
	if captured and Input.is_action_just_pressed("motion_switch_character"):
		switch_character()
	elif captured and Input.is_action_just_pressed("motion_dodge"):
		request_dodge(_body._camera_relative_input())
	elif captured and Input.is_action_just_pressed("motion_parry"):
		request_parry()
	elif captured and Input.is_action_just_pressed("motion_cast"):
		request_cast()
	if _cast_elapsed >= 0.0:
		if _driver.get_action_clip() != "Actions/CastEnergy" or (not _body.camera_lock_behind and not _cast_released):
			_cancel_cast()
		else:
			_cast_elapsed += delta
			if not _cast_released and _cast_elapsed >= _cast_release_time:
				_cast_released = true
				# Read the hand after this frame's animation update, once, with cancellation token.
				_release_cast.call_deferred(_cast_token)
			if _cast_elapsed >= _cast_duration:
				_cast_elapsed = -1.0
	if _parry_elapsed >= 0.0:
		_parry_elapsed += delta
		if _parry_elapsed >= _parry_duration:
			_parry_elapsed = -1.0
	if _cast_elapsed < 0.0 and not _dodge_active and _parry_elapsed < 0.0:
		_restore_melee()
	_update_status()

func _can_act() -> bool:
	if is_instance_valid(_body) and _body.has_method("allows_motion_actions") and not _body.allows_motion_actions():
		return false
	return is_instance_valid(_body) and (network_authority or not _body.external_control) and _body.is_physics_processing() and _body.get_health() > 0.0 and (_manager == null or (_manager.get_phase() == 1 if network_authority else _manager.get_phase() != 2))

func request_cast() -> bool:
	if not _can_act() or _dodge_active or _parry_elapsed >= 0.0 or _cast_cooldown > 0.0 or not _driver.get_action_clip().is_empty():
		return false
	if not _body.camera_lock_behind:
		_notice = "Press V to enter aim view, then R to cast."
		return false
	var spec := ACTIONS.definition("CastEnergy")
	if not _driver.present_action(spec):
		return false
	_cast_token += 1
	_cast_elapsed = 0.0
	_cast_released = false
	var clip: Animation = _driver._anim.get_animation(spec.clip)
	_cast_duration = clip.length
	_cast_release_time = float(clip.get_meta("release_time_s"))
	_cast_cooldown = cast_cooldown_s
	_suppress_melee()
	_notice = "Casting — keep moving to check the legs."
	return true

func request_dodge(world_direction: Vector3 = Vector3.ZERO) -> bool:
	if not _can_act() or not _body.is_on_floor() or _dodge_active or _parry_elapsed >= 0.0 or _dodge_cooldown > 0.0:
		return false
	var mesh: Node3D = _body.get_node("Mesh")
	var sector := 2 # No movement intent: backstep relative to the current facing.
	world_direction.y = 0.0
	if world_direction.length_squared() > 0.0001:
		sector = SECTORS.select(mesh.global_basis.orthonormalized().inverse() * world_direction, 0, 0.0, true)
	var spec := ACTIONS.definition(DODGE_IDS[sector])
	if not _driver.present_action(spec):
		return false
	_cancel_cast(false)
	_dodge_direction = mesh.global_basis.orthonormalized() * DODGE_DIRECTIONS[sector]
	_dodge_direction.y = 0.0
	_dodge_direction = _dodge_direction.normalized()
	_dodge_duration = _driver._anim.get_animation(spec.clip).length
	_dodge_elapsed = 0.0
	_dodge_active = true
	_evasion_id = DODGE_IDS[sector]
	_dodge_cooldown = dash_cooldown_s if sector == 0 else dodge_cooldown_s
	_suppress_melee()
	_notice = "Forward dash" if sector == 0 else "Quick %s dodge" % DODGE_IDS[sector].trim_prefix("Dodge_").to_lower()
	dodge_started.emit(_dodge_direction, String(spec.clip))
	return true

## Called by the local player's movement adapter, once per physics update.
func simulate_dodge(delta: float) -> bool:
	if not _dodge_active:
		return false
	if not _can_act():
		cancel_motion()
		return false
	var step := minf(delta, maxf(0.0, _dodge_duration - _dodge_elapsed))
	var phase := (_dodge_elapsed + step * 0.5) / maxf(_dodge_duration, 0.001)
	var weight := PROFILES.speed_weight(_evasion_id, phase)
	_body._apply_gravity(delta)
	var peak := dash_peak_speed if _evasion_id == "Dash_Forward" else dodge_peak_speed
	var speed := peak * weight * step / maxf(delta, 0.001)
	_body.velocity.x = _dodge_direction.x * speed
	_body.velocity.z = _dodge_direction.z * speed
	if _body.has_method("move_with_stairs"):
		_body.move_with_stairs(delta)
	else:
		_body.move_and_slide()
	_dodge_elapsed += delta
	if _dodge_elapsed >= _dodge_duration:
		_dodge_active = false
	return true

func request_parry() -> bool:
	if not _can_act() or not _body.is_on_floor() or _dodge_active or _parry_elapsed >= 0.0 or _parry_cooldown > 0.0:
		return false
	if not _driver.present_action(ACTIONS.definition("Parry_Attempt")):
		return false
	_cancel_cast(false)
	_parry_elapsed = 0.0
	_parry_duration = PROFILES.PARRY_DURATION
	_parry_confirmed = false
	_parry_cooldown = PROFILES.PARRY_COOLDOWN
	_suppress_melee()
	_notice = "Parry — time the guard for the incoming strike."
	return true

## Only the validated melee-contact adapter calls this; ordinary damage bypasses it.
func try_parry_melee(source: Node) -> bool:
	if not _can_act() or _parry_confirmed or _parry_elapsed < PROFILES.PARRY_START or _parry_elapsed > PROFILES.PARRY_END:
		return false
	if not is_instance_valid(source) or not source is Node3D or source == _body:
		return false
	var toward: Vector3 = source.global_position - _body.global_position
	toward.y = 0.0
	if toward.length_squared() < 0.0001:
		return false
	var facing: Vector3 = _body.get_node("Mesh").global_basis.z
	facing.y = 0.0
	if facing.normalized().dot(toward.normalized()) < cos(deg_to_rad(PROFILES.PARRY_CONE_DEGREES * 0.5)):
		return false
	_parry_confirmed = true
	_parry_elapsed = 0.0
	_parry_duration = PROFILES.PARRY_SUCCESS_DURATION
	_driver.present_action(ACTIONS.definition("Parry_Success"))
	_notice = "PARRIED! Strike deflected."
	parry_succeeded.emit(source)
	return true

func _release_cast(token: int) -> void:
	if token != _cast_token or token == _last_released_token or not _can_act() or not _body.camera_lock_behind or _driver.get_action_clip() != "Actions/CastEnergy":
		return
	var mesh: Node3D = _body.get_node("Mesh")
	var model: Node = mesh._model
	if not is_instance_valid(model):
		return
	var skeletons := model.find_children("*", "Skeleton3D", true, false)
	if skeletons.is_empty():
		return
	var skeleton: Skeleton3D = skeletons[0]
	var hand := skeleton.find_bone("hand.L")
	var chest := skeleton.find_bone("chest")
	if hand < 0 or chest < 0:
		return
	var origin := skeleton.global_transform * skeleton.get_bone_global_pose(hand).origin
	var chest_position := skeleton.global_transform * skeleton.get_bone_global_pose(chest).origin
	var space := _body.get_world_3d().direct_space_state
	var hand_ray := PhysicsRayQueryParameters3D.create(chest_position, origin, 1 | 2 | 4, [_body.get_rid()])
	var obstruction := space.intersect_ray(hand_ray)
	if not obstruction.is_empty():
		origin = obstruction.position - (origin - chest_position).normalized() * 0.04
	var camera: Camera3D = _body.get_node("CameraPivot/CameraTilt/Camera3D")
	var target := camera.global_position - camera.global_basis.z * 30.0
	var aim_ray := PhysicsRayQueryParameters3D.create(camera.global_position, target, 1 | 2 | 4, [_body.get_rid()])
	var aim_hit := space.intersect_ray(aim_ray)
	if not aim_hit.is_empty():
		target = aim_hit.position
	var direction := (target - origin).normalized()
	if direction.length_squared() < 0.001:
		return
	_last_released_token = token
	var bolt := Node3D.new()
	bolt.set_script(BOLT)
	bolt.name = "TestEnergyBolt"
	bolt.direction = direction
	bolt.source_rid = _body.get_rid()
	bolt.source = _body
	bolt.damage = ranged_damage
	bolt.burn_damage = burn_damage
	bolt.burn_ticks = burn_ticks
	bolt.burn_interval_s = burn_interval_s
	_body.get_parent().add_child(bolt)
	bolt.global_position = origin
	cast_released.emit(origin, direction)

func switch_character() -> void:
	if not _can_act():
		return
	cancel_motion()
	var mesh: Node = _body.get_node("Mesh")
	mesh.set_character(1 - int(mesh.character))
	_driver._physics_process(0.0)
	_notice = "Character switched. V: aim, R: cast, Q + direction: dash/dodge, F: parry."

func _cancel_cast(clear_pose: bool = true) -> void:
	_cast_token += 1
	_cast_elapsed = -1.0
	_cast_released = false
	if clear_pose and is_instance_valid(_driver) and _driver.get_action_clip() == "Actions/CastEnergy":
		_driver.cancel_action()

func cancel_motion() -> void:
	if is_instance_valid(_melee) and _melee.has_method("cancel_attack"):
		_melee.cancel_attack()
	_cancel_cast()
	_parry_elapsed = -1.0
	_parry_confirmed = false
	if is_instance_valid(_driver) and _driver.get_action_clip().begins_with("Actions/Parry_"):
		_driver.cancel_action()
	if _dodge_active:
		_dodge_active = false
		_body.velocity.x = 0.0
		_body.velocity.z = 0.0
		_driver.cancel_action()
	_restore_melee()

func _suppress_melee() -> void:
	if _melee.has_method("cancel_attack"):
		_melee.cancel_attack()
	if not _melee_suppressed:
		_melee_was_enabled = _melee.is_physics_processing()
		_melee_suppressed = true
	_melee.set_physics_process(false)

func _restore_melee() -> void:
	if not _melee_suppressed:
		return
	if _melee_was_enabled and _can_act():
		_melee.set_physics_process(true)
	_melee_suppressed = false

func _on_health_changed(current: float, _maximum: float) -> void:
	if current <= 0.0:
		cancel_motion()
		_cast_cooldown = 0.0
		_dodge_cooldown = 0.0
		_parry_cooldown = 0.0

func _notification(what: int) -> void:
	if not network_driven and what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_instance_valid(_body):
		cancel_motion()

func _update_status() -> void:
	if _status == null:
		return
	_reticle.visible = _can_act() and _body.camera_lock_behind
	_status.text = "%s | Cast: %s | Dash/dodge: %s | Parry: %s\n%s" % ["Arclight" if int(_body.get_node("Mesh").character) == 0 else "Ashen Warden", "ready" if _cast_cooldown <= 0.0 else "%.1f s" % _cast_cooldown, "ready" if _dodge_cooldown <= 0.0 else "%.1f s" % _dodge_cooldown, "ready" if _parry_cooldown <= 0.0 else "%.1f s" % _parry_cooldown, _notice]
