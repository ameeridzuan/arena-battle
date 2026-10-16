extends CanvasLayer
## Milestone 3 — HUD display layer (docs/TECHNICAL_ARCHITECTURE.md §3.9, §4.3).
##
## PURE DISPLAY: it reads MatchManager state and writes Label text.  It contains no game
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

var _match_manager: Node
var _score_label: Label
var _timer_label: Label
var _result_label: Label


func _ready() -> void:
	_score_label = get_node_or_null(score_label_path) as Label
	_timer_label = get_node_or_null(timer_label_path) as Label
	_result_label = get_node_or_null(result_label_path) as Label

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


func _process(_delta: float) -> void:
	_refresh_timer()


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
