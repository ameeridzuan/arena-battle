extends Node
## Milestone 3 — match state machine (see docs/TECHNICAL_ARCHITECTURE.md §6.7, ADR-0010).
##
## A plain scene node in Main.tscn (NOT an autoload).  Joins group "match_manager" so
## combatants / HUD can discover it without hardcoded paths.
##
## Pure and deterministic on purpose — no rendering, no Input reads, no scene-tree
## shortcuts (never calls reload_current_scene()).  This is the module that lifts
## server-side unchanged in Milestone 4.
##
## Objective is team-deathmatch (ADR-0009): the match ends on score_limit OR time_limit,
## whichever comes first.  Equal scores at time expiry => draw (winner == -1, no overtime).

enum Phase { WAITING, RUNNING, ENDED }
enum Team { TEAM_A = 0, TEAM_B = 1 }

signal match_started
signal score_changed(team_a_score: int, team_b_score: int)
signal player_died                                # convenience for HUD / camera
signal match_ended(winner: int)                   # Team value, or -1 for a draw

const DRAW := -1                                  # winner value meaning "no winner"

@export var score_limit: int = 5                  # kills needed to win the match
@export var time_limit: float = 180.0             # seconds; match ends when this reaches 0
@export var auto_start: bool = true               # start on _ready (deferred)

var phase: Phase = Phase.WAITING
var score_a: int = 0
var score_b: int = 0
var time_remaining: float = 0.0


func _ready() -> void:
	add_to_group("match_manager")
	if auto_start:
		# Deferred so every sibling's _ready() has run (combatants cached this node)
		# before the match actually starts.
		start_match.call_deferred()


func _physics_process(delta: float) -> void:
	# The timer only ticks while RUNNING — deterministic fixed-timestep countdown.
	if phase != Phase.RUNNING:
		return
	time_remaining = maxf(time_remaining - delta, 0.0)
	if time_remaining <= 0.0:
		_end_match(_resolve_time_winner())


## Resets scores, arms the countdown and moves WAITING/ENDED -> RUNNING.
func start_match() -> void:
	phase = Phase.RUNNING
	score_a = 0
	score_b = 0
	time_remaining = time_limit
	match_started.emit()


## Awards one kill to [param scorer_team] for the death of a [param victim_team] combatant.
## Ignored unless the match is RUNNING (no post-match scoring — AC-M3-10).
func register_kill(scorer_team: int, victim_team: int) -> void:
	if phase != Phase.RUNNING:
		return
	# TDM awards points only for valid opposing teams (ADR-0009).
	if victim_team != Team.TEAM_A and victim_team != Team.TEAM_B:
		return
	if scorer_team == victim_team:
		return
	if scorer_team == Team.TEAM_A:
		score_a += 1
	elif scorer_team == Team.TEAM_B:
		score_b += 1
	else:
		return                                    # unknown team — no score awarded
	score_changed.emit(score_a, score_b)
	if victim_team == Team.TEAM_A:
		player_died.emit()
	if scorer_team == Team.TEAM_A and score_a >= score_limit:
		_end_match(Team.TEAM_A)
	elif scorer_team == Team.TEAM_B and score_b >= score_limit:
		_end_match(Team.TEAM_B)


## Idempotent: only the first call transitions the phase and emits.
func _end_match(winner: int) -> void:
	if phase == Phase.ENDED:
		return
	phase = Phase.ENDED
	match_ended.emit(winner)


## Winner on time expiry: the higher score, or DRAW when the scores are equal.
func _resolve_time_winner() -> int:
	if score_a > score_b:
		return Team.TEAM_A
	if score_b > score_a:
		return Team.TEAM_B
	return DRAW


# --- Read-only queries (HUD / tests) -------------------------------------------------

func get_phase() -> Phase:
	return phase


func get_time_remaining() -> float:
	return time_remaining


func get_score(team: int) -> int:
	return score_a if team == Team.TEAM_A else score_b
