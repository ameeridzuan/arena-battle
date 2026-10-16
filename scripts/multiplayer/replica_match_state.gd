extends Node
## Read-only client display model. No timer, scoring, death or respawn simulation.
signal match_started
signal score_changed(a: int, b: int)
signal match_ended(winner: int)

var phase: int = 0
var score_a: int = 0
var score_b: int = 0
var time_remaining: float = 0.0
var winner: int = -1

func _ready() -> void:
	add_to_group("match_manager")

func apply_state(next_phase: int, a: int, b: int, remaining: float, result: int) -> void:
	var old_phase := phase
	var changed := score_a != a or score_b != b
	phase = next_phase
	score_a = a
	score_b = b
	time_remaining = remaining
	winner = result
	if old_phase != phase and phase == 1:
		match_started.emit()
	if changed:
		score_changed.emit(a, b)
	if old_phase != phase and phase == 2:
		match_ended.emit(winner)

func get_score(team: int) -> int:
	return score_a if team == 0 else score_b

func get_time_remaining() -> float:
	return time_remaining

func get_phase() -> int:
	return phase
