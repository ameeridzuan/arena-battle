extends CanvasLayer
## Milestone 3 — HUD display layer (docs/TECHNICAL_ARCHITECTURE.md §3.9, §4.3).
##
## PURE DISPLAY: reads MatchManager/Health state and updates labels, bar and damage tint.  It contains no game
## rules, no scoring, no scene-tree shortcuts — in M4 it stays client-side and is driven by
## replicated state (AC-M3-13).
##
## The MatchManager is discovered via group "match_manager" (never by hardcoded path).

const MATCH_MANAGER_GROUP := "match_manager"

## Winner values emitted by match_ended(winner) — mirrors MatchManager.Team + its draw value.
const WINNER_TEAM_A := 0
const WINNER_TEAM_B := 1
const WINNER_DRAW := -1

const SECONDS_PER_MINUTE := 60

const SCORE_FORMAT := "TEAM A: %d  |  TEAM B: %d"
const CLOCK_FORMAT := "%d:%02d"

@export var score_label_path: NodePath = ^"ScoreLabel"
@export var timer_label_path: NodePath = ^"TimerLabel"
@export var result_label_path: NodePath = ^"ResultLabel"

## Explicit local-player binding; M4 must bind this to the owning peer's player.
@export var player_health_path: NodePath = ^"../Player/Health"
@export var damage_tint_duration: float = 0.18
@export var damage_tint_alpha: float = 0.12

var _health: Health
var _health_bar: ProgressBar
var _health_label: Label
var _damage_tint: ColorRect
var _last_health: float = 0.0
var _tint_remaining: float = 0.0

## M6 camera-mode indicator (single-player only). Bound to the local player's controller.
var _facing_label: Label
var _player_controller
var _camera_lock_b: bool = false

var _match_manager: Node
var _score_label: Label
var _timer_label: Label
var _result_label: Label


func _ready() -> void:
	_score_label = get_node_or_null(score_label_path) as Label
	_timer_label = get_node_or_null(timer_label_path) as Label
	_result_label = get_node_or_null(result_label_path) as Label

	_health_bar = get_node_or_null("HealthBar") as ProgressBar
	_health_label = get_node_or_null("HealthLabel") as Label
	_damage_tint = get_node_or_null("DamageTint") as ColorRect
	_facing_label = get_node_or_null("FacingLabel") as Label
	bind_health(get_node_or_null(player_health_path) as Health)

	_match_manager = get_tree().get_first_node_in_group(MATCH_MANAGER_GROUP)
	if _match_manager == null:
		push_warning("[HUD] no node in group '" + MATCH_MANAGER_GROUP
				+ "' — score/timer/result will not update.")
		return

	_match_manager.score_changed.connect(_on_score_changed)
	_match_manager.match_started.connect(_on_match_started)
	_match_manager.match_ended.connect(_on_match_ended)
	_refresh_score()
	_refresh_timer()


func _process(delta: float) -> void:
	_refresh_timer()
	_tint_remaining = maxf(0.0, _tint_remaining - delta)
	if _damage_tint:
		_damage_tint.color.a = damage_tint_alpha * _tint_remaining / maxf(damage_tint_duration, 0.01)
	_update_facing_label()


func _on_health_changed(current: float, maximum: float) -> void:
	if current < _last_health:
		_tint_remaining = maxf(damage_tint_duration, 0.01)
	elif current > _last_health:
		_tint_remaining = 0.0
	_last_health = current
	if _health_bar:
		_health_bar.max_value = maxf(maximum, 1.0)
		_health_bar.value = current
	if _health_label:
		_health_label.text = "HP: %d / %d" % [ceili(current), ceili(maximum)]


# --- Signal handlers -----------------------------------------------------------------

func _on_match_started() -> void:
	if _result_label:
		_result_label.visible = false
	_refresh_score()
	_refresh_timer()


func _on_score_changed(team_a_score: int, team_b_score: int) -> void:
	_set_score_text(team_a_score, team_b_score)


func _on_match_ended(winner: int) -> void:
	_refresh_timer()
	if _result_label == null:
		return
	_result_label.text = _result_text(winner)
	_result_label.visible = true


# --- Display helpers (write-only) ----------------------------------------------------

func _refresh_score() -> void:
	if _score_label == null or _match_manager == null:
		return
	_set_score_text(
		_match_manager.get_score(WINNER_TEAM_A),
		_match_manager.get_score(WINNER_TEAM_B)
	)


func _set_score_text(team_a_score: int, team_b_score: int) -> void:
	if _score_label == null:
		return
	_score_label.text = SCORE_FORMAT % [team_a_score, team_b_score]


func _refresh_timer() -> void:
	if _timer_label == null or _match_manager == null:
		return
	_timer_label.text = _format_clock(_match_manager.get_time_remaining())


## mm:ss — minutes are not zero-padded ("3:00"), seconds always are ("3:05").
func _format_clock(seconds: float) -> String:
	var total := int(ceilf(maxf(seconds, 0.0)))
	var minutes := int(total / float(SECONDS_PER_MINUTE))
	var remainder := total % SECONDS_PER_MINUTE
	return CLOCK_FORMAT % [minutes, remainder]


func _result_text(winner: int) -> String:
	if winner == WINNER_TEAM_A:
		return "TEAM A WINS"
	if winner == WINNER_TEAM_B:
		return "TEAM B WINS"
	if winner == WINNER_DRAW:
		return "DRAW"
	return "MATCH OVER"


## Local player can spawn after HUD _ready in a network session.
func bind_health(health: Health) -> void:
	if is_instance_valid(_health) and _health.health_changed.is_connected(_on_health_changed):
		_health.health_changed.disconnect(_on_health_changed)
	_health = health
	_tint_remaining = 0.0
	_player_controller = _health.get_parent() if _health != null else null
	if _health_bar:
		_health_bar.visible = _health != null
	if _health_label:
		_health_label.visible = _health != null
	if _health:
		_last_health = _health.get_health()
		_health.health_changed.connect(_on_health_changed)
		_on_health_changed(_last_health, _health.max_health)
	_update_facing_label()


## Shows the current camera mode (A = free mouse-look, B = locked behind the character) and the
## toggle key. Hidden for networked replicas (external_control), where the camera is server-driven
## and the toggle key is not read.
func _update_facing_label() -> void:
	if _facing_label == null:
		return
	if _player_controller == null:
		_facing_label.visible = false
		return
	var external = _player_controller.get("external_control")
	var mode = _player_controller.get("camera_lock_behind")
	if external == null or mode == null or external:
		_facing_label.visible = false
		return
	_facing_label.visible = true
	if bool(mode) != _camera_lock_b:
		_camera_lock_b = bool(mode)
		_facing_label.text = "Camera [V]: Locked (B)" if _camera_lock_b else "Camera [V]: Free-look (A)"
