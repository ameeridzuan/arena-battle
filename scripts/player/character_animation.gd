extends Node
## Character animation driver (M7 art pass).
##
## Presentation only: reads the owning body's motion state and plays the authored animations on
## one AnimationTree using the model's AnimationPlayer as its clip library. It never mutates
## gameplay state, damage, or timing.
##
## Both character GLBs expose an identical, canonical animation set (Idle / Walk / Run / Jump /
## Attack_Slash / Attack_Backhand / Attack_Overhead / Attack_Thrust), so this single controller
## drives Arclight and Ashen Warden alike.
##
## Motion is derived from `velocity` (not raw input), so it is correct for the locally simulated
## body AND for networked replicas whose transforms are written from snapshots. Grounded state
## uses `is_on_floor()` for a simulated body; for an externally-controlled replica (physics
## disabled on clients) it falls back to a vertical-velocity heuristic.

## Horizontal speed (m/s) at or above which Run plays instead of Walk.
@export var run_speed_threshold: float = 2.1
## Horizontal speed (m/s) below which Idle plays instead of Walk.
@export var walk_speed_threshold: float = 0.5
## For externally-controlled replicas: |velocity.y| above this counts as airborne (Jump).
@export var airborne_velocity_threshold: float = 0.6
## One-shot attack clips, cycled in order on each accepted swing.
@export var attack_animations: Array[String] = [
	"Attack_Slash", "Attack_Backhand", "Attack_Overhead", "Attack_Thrust",
]

const MOVE_DIRECTION := preload("res://scripts/player/movement_direction.gd")
const LOCOMOTION := preload("res://scripts/player/locomotion_library.gd")
const LOCAL_RESOURCES := preload("res://scripts/player/animation_resources.gd")
const LAYERS := preload("res://scripts/player/layered_animation.gd")
const ACTION := preload("res://scripts/player/animation_action.gd")
const ACTION_LIBRARY := preload("res://scripts/player/action_library.gd")
## Optional character-specific presentation definitions; empty uses shared melee defaults.
@export var action_definitions: Array[ACTION] = []
var _layers: LAYERS
var _bound_model: Node
var _manual_preview := false
var _health: Node

@export_range(0.0, 0.5) var locomotion_blend_s: float = 0.15
@export_range(0.0, 2.0) var run_hysteresis: float = 0.25
@export_range(0.0, 0.4) var idle_hysteresis: float = 0.1
var _locomotion_clip: String = "Idle"
var _gait_family: String = "Idle"
var _move_sector: int = 0
@export_range(0.0, 20.0) var direction_hysteresis_degrees: float = 8.0
## Review-gallery slow motion; gameplay keeps 1.0.
var playback_multiplier: float = 1.0

const LOOPED := ["Idle", "Walk", "Run", "Walk_Backward", "Walk_Left", "Walk_Right"]
const AIRBORNE := "Jump"

var _body: CharacterBody3D
var _mesh: Node
var _anim: AnimationPlayer
var _attack_index: int = 0
var _attack_playing: bool = false


func _ready() -> void:
	_body = get_parent() as CharacterBody3D
	_mesh = _body.get_node_or_null("Mesh") if _body != null else null
	var hitbox := _body.get_node_or_null("AttackHitbox") if _body != null else null
	if hitbox != null and hitbox.has_signal("attack_started") and not hitbox.has_method("owns_animation_action"):
		hitbox.attack_started.connect(_on_attack_started)
	_health = _body.get_node_or_null("Health") if _body != null else null
	if _health != null:
		_health.health_changed.connect(_on_health_changed)
	_locate_animation_player()


## The model is instantiated at runtime by character_model.gd, so the AnimationPlayer may not
## exist yet on the first pass; re-scan until it is found.
func _locate_animation_player() -> void:
	if _mesh == null:
		return
	var model: Node = _mesh._model
	if not is_instance_valid(model):
		return
	var players := model.find_children("*", "AnimationPlayer", true, false)
	if players.is_empty():
		return
	if _layers != null:
		_layers.dispose()
	_attack_playing = false
	_attack_index = 0
	_anim = players[0] as AnimationPlayer
	_bound_model = model
	_configure_loop_modes()
	_layers = LAYERS.new()
	_layers.bind(_anim)
	_layers.tree.active = not _manual_preview


func _configure_loop_modes() -> void:
	LOCAL_RESOURCES.make_local(_anim)
	LOCOMOTION.install(_anim,int(_mesh.character))
	ACTION_LIBRARY.install(_anim, int(_mesh.character))
	for clip in LOOPED:
		if _anim.has_animation(clip):
			_anim.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	for clip in [AIRBORNE] + attack_animations:
		if _anim.has_animation(clip):
			_anim.get_animation(clip).loop_mode = Animation.LOOP_NONE


func _physics_process(delta: float) -> void:
	if not is_instance_valid(_anim) or _bound_model != _mesh._model:
		if _layers != null:
			_layers.dispose()
		_layers = null
		_anim = null
		_attack_playing = false
		_gait_family = "Idle"
		_locomotion_clip = "Idle"
		_move_sector = 0
		_locate_animation_player()
		if _anim == null:
			return
	if _manual_preview:
		return
	if _health != null and _health.get_health() <= 0:
		reset_presentation()
		return
	if _body.has_method("get_traversal_mode") and _body.get_traversal_mode() != "normal":
		_play("Idle")
		_layers.base_speed = 1.0
		_layers.advance(delta * playback_multiplier)
		_attack_playing = false
		return
	if not _is_grounded():
		_play(AIRBORNE)
		_layers.base_speed = 1.0
		_layers.advance(delta * playback_multiplier)
		_attack_playing = _layers.action != null
		return
	var horizontal := Vector2(_body.velocity.x, _body.velocity.z).length()
	# Enter at the configured threshold; leave only below a lower threshold.
	# This avoids clip flicker when replicated speed jitters near the boundary.
	if horizontal >= run_speed_threshold or (_gait_family == "Run" and horizontal >= maxf(walk_speed_threshold, run_speed_threshold - run_hysteresis)):
		_gait_family = "Run"
	elif horizontal >= walk_speed_threshold or (_gait_family != "Idle" and horizontal >= maxf(0.0, walk_speed_threshold - idle_hysteresis)):
		_gait_family = "Walk"
	else:
		_gait_family = "Idle"
	_locomotion_clip = _select_directional_clip(_gait_family)
	_play(_locomotion_clip)
	if _is_gait_clip(_locomotion_clip):
		var nominal: float = _anim.get_animation(_locomotion_clip).get_meta("nominal_speed_m_s", 1.0)
		_layers.base_speed = clampf(horizontal / maxf(nominal, 0.1), 0.25, 2.0)
	else:
		_layers.base_speed = 1.0
	_layers.advance(delta * playback_multiplier)
	_attack_playing = _layers.action != null


func _is_grounded() -> bool:
	if _body == null:
		return true
	# Externally-controlled replicas have physics disabled on clients, so is_on_floor() is stale;
	# infer airborne state from the snapshot's vertical velocity instead.
	if _body.has_method("is_motion_grounded"):
		return _body.is_motion_grounded()
	if _body.external_control:
		return absf(_body.velocity.y) < airborne_velocity_threshold
	return _body.is_on_floor()


func _on_attack_started(_forward: Vector3) -> void:
	if not is_instance_valid(_anim) or _bound_model != _mesh._model:
		_locate_animation_player()
	if _anim == null or _manual_preview or attack_animations.is_empty():
		return
	if _health != null and _health.get_health() <= 0:
		return
	var clip := _next_attack_clip()
	if clip == "":
		return
	var spec: ACTION
	for definition in action_definitions:
		if definition != null and String(definition.clip) == clip:
			spec = definition
			break
	if spec == null:
		spec = ACTION.new()
		spec.clip = StringName(clip)
	present_action(spec)
	_attack_playing = _layers.action != null


## Presentation adapter for accepted actions or isolated previews. Never grants an effect.
func present_action(spec: ACTION) -> bool:
	if spec == null or _manual_preview or (_health != null and _health.get_health() <= 0):
		return false
	if not is_instance_valid(_anim) or _bound_model != _mesh._model:
		_locate_animation_player()
	if _layers == null or not is_instance_valid(_anim):
		return false
	var accepted: bool = _layers.start_action(spec)
	_attack_playing = _layers.action != null
	return accepted


func _next_attack_clip() -> String:
	# Cycle through available attack clips so repeated swings vary; skip any the model lacks.
	for _i in range(attack_animations.size()):
		var clip := attack_animations[_attack_index % attack_animations.size()]
		_attack_index += 1
		if _anim.has_animation(clip):
			return clip
	return ""


func _play(clip: String) -> void:
	_layers.select_base(clip, locomotion_blend_s)


func _is_gait_clip(clip: String) -> bool:
	return clip in ["Walk", "Run", "Walk_Backward", "Walk_Left", "Walk_Right"]


func _select_directional_clip(family: String) -> String:
	if family == "Idle":
		_move_sector = 0
		return "Idle"
	var local: Vector3 = _mesh.global_basis.orthonormalized().inverse() * Vector3(_body.velocity.x, 0, _body.velocity.z)
	var margin: float = _body.aim_direction_hysteresis_degrees if _body.camera_lock_behind else direction_hysteresis_degrees
	_move_sector = MOVE_DIRECTION.select(local, _move_sector, margin,
		not _is_gait_clip(get_locomotion_clip()))
	# No directional running capture is installed. Aimed side/back movement uses
	# tactical walking; residual forward-run velocity settles through that pose.
	if family == "Run" and not (_body.camera_lock_behind and _move_sector != 0):
		return "Run"
	if _move_sector != 0:
		_gait_family = "Walk"
	return ["Walk", "Walk_Right", "Walk_Backward", "Walk_Left"][_move_sector]


func get_locomotion_clip() -> String:
	return _layers.base_clip if _layers != null else ""

func get_locomotion_position() -> float:
	return _layers.base_time if _layers != null else 0.0

func get_locomotion_speed() -> float:
	return _layers.base_speed if _layers != null else 1.0

func get_action_clip() -> String:
	return String(_layers.action.clip) if _layers != null and _layers.action != null else ""

func cancel_action() -> void:
	_attack_playing = false
	if _layers != null:
		_layers.cancel_action()
		if not _manual_preview:
			_layers.evaluate()

func reset_presentation() -> void:
	_attack_playing = false
	_attack_index = 0
	_gait_family = "Idle"
	_locomotion_clip = "Idle"
	_move_sector = 0
	if _layers != null:
		_layers.reset()
		if not _manual_preview:
			_layers.evaluate()

## Raw clip gallery owns AnimationPlayer only while the runtime mixer is inactive.
func set_manual_preview(enabled: bool) -> void:
	_manual_preview = enabled
	reset_presentation()
	if _layers != null:
		_layers.tree.active = not enabled
	if not enabled and is_instance_valid(_anim):
		_anim.stop()
		_layers.evaluate()

func _on_health_changed(current: float, _maximum: float) -> void:
	if current <= 0:
		reset_presentation()
