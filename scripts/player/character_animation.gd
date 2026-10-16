extends Node
## Character animation driver (M7 art pass).
##
## Presentation only: reads the owning body's motion state and plays the authored animations on
## the character model's AnimationPlayer (found under the `Mesh` anchor). It never mutates
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
@export var run_speed_threshold: float = 8.0
## Horizontal speed (m/s) below which Idle plays instead of Walk.
@export var walk_speed_threshold: float = 0.5
## For externally-controlled replicas: |velocity.y| above this counts as airborne (Jump).
@export var airborne_velocity_threshold: float = 0.6
## One-shot attack clips, cycled in order on each accepted swing.
@export var attack_animations: Array[String] = [
	"Attack_Slash", "Attack_Backhand", "Attack_Overhead", "Attack_Thrust",
]

const LOOPED := ["Idle", "Walk", "Run"]
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
	if hitbox != null and hitbox.has_signal("attack_started"):
		hitbox.attack_started.connect(_on_attack_started)
	_locate_animation_player()


## The model is instantiated at runtime by character_model.gd, so the AnimationPlayer may not
## exist yet on the first pass; re-scan until it is found.
func _locate_animation_player() -> void:
	if _mesh == null:
		return
	var players := _mesh.find_children("*", "AnimationPlayer", true, false)
	if players.is_empty():
		return
	_anim = players[0] as AnimationPlayer
	_anim.animation_finished.connect(_on_animation_finished)
	_configure_loop_modes()


func _configure_loop_modes() -> void:
	for clip in LOOPED:
		if _anim.has_animation(clip):
			_anim.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	for clip in [AIRBORNE] + attack_animations:
		if _anim.has_animation(clip):
			_anim.get_animation(clip).loop_mode = Animation.LOOP_NONE


func _physics_process(_delta: float) -> void:
	if _anim == null:
		_locate_animation_player()
		if _anim == null:
			return
	if _attack_playing:
		return
	if not _is_grounded():
		_play(AIRBORNE)
		return
	var horizontal := Vector2(_body.velocity.x, _body.velocity.z).length()
	if horizontal >= run_speed_threshold:
		_play("Run")
	elif horizontal >= walk_speed_threshold:
		_play("Walk")
	else:
		_play("Idle")


func _is_grounded() -> bool:
	if _body == null:
		return true
	# Externally-controlled replicas have physics disabled on clients, so is_on_floor() is stale;
	# infer airborne state from the snapshot's vertical velocity instead.
	if _body.external_control:
		return absf(_body.velocity.y) < airborne_velocity_threshold
	return _body.is_on_floor()


func _on_attack_started(_forward: Vector3) -> void:
	if _anim == null:
		_locate_animation_player()
	if _anim == null or attack_animations.is_empty():
		return
	var clip := _next_attack_clip()
	if clip == "":
		return
	_attack_playing = true
	_anim.play(clip)


func _next_attack_clip() -> String:
	# Cycle through available attack clips so repeated swings vary; skip any the model lacks.
	for _i in range(attack_animations.size()):
		var clip := attack_animations[_attack_index % attack_animations.size()]
		_attack_index += 1
		if _anim.has_animation(clip):
			return clip
	return ""


func _on_animation_finished(clip: StringName) -> void:
	if attack_animations.has(String(clip)):
		_attack_playing = false


func _play(clip: String) -> void:
	if not _anim.has_animation(clip):
		return
	if _anim.current_animation == clip and _anim.is_playing():
		return
	_anim.play(clip)
