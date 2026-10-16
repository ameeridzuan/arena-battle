class_name Health
extends Node
## Milestone 2 — pure health-state component.
##
## Attach as a child Node to any damageable body.  Exposes signals so the owner
## can react to damage / death without tight coupling.
## No Node3D dependency, no frame-rate dependency — fully deterministic.

signal health_changed(current: float, maximum: float)
signal died()

## Replicas only receive state through the session authority RPC.
@export var network_replica: bool = false

@export var max_health: float = 100.0

var _current: float = 0.0

## Milestone 3 — the node that dealt the most recent damage, kept so `combatant.gd`
## can attribute a kill after `died` fires without changing that signal's signature.
var last_damage_source: Node = null


func _ready() -> void:
	_current = max_health


## Reduces health by [param amount].  Ignored once health has reached zero.
## [param source] is the owning character node that dealt the damage (recorded in
## [member last_damage_source] for Milestone 3 kill attribution).
func apply_damage(amount: float, source: Node) -> void:
	if network_replica or _current <= 0.0:
		return
	last_damage_source = source
	_current = maxf(0.0, _current - amount)
	health_changed.emit(_current, max_health)
	if _current == 0.0:
		died.emit()


func get_health() -> float:
	return _current


## Milestone 3 — returns the component to its initial state (used on respawn).
## Named `reset()` deliberately: not `heal()` (partial restore, a future ability) and
## not `revive()` (a lifecycle concept owned by `combatant.gd`).  See ADR-0010 / §6.5.
func reset() -> void:
	if network_replica:
		return
	_current = max_health
	last_damage_source = null
	health_changed.emit(_current, max_health)


## Presentation-only state application. Not an RPC; server-owned session is the caller.
func apply_network_state(current: float, maximum: float) -> void:
	if not network_replica:
		return
	var next := clampf(current, 0.0, maximum)
	if is_equal_approx(next, _current) and is_equal_approx(maximum, max_health):
		return
	max_health = maximum
	_current = next
	health_changed.emit(_current, max_health)
