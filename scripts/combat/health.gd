class_name Health
extends Node
## Milestone 2 — pure health-state component.
##
## Attach as a child Node to any damageable body.  Exposes signals so the owner
## can react to damage / death without tight coupling.
## No Node3D dependency, no frame-rate dependency — fully deterministic.

signal health_changed(current: float, maximum: float)
signal died()

@export var max_health: float = 100.0

var _current: float = 0.0


func _ready() -> void:
	_current = max_health


## Reduces health by [param amount].  Ignored once health has reached zero.
## [param _source] is the owning character node that dealt the damage (unused here
## but required by the combat interface contract).
func apply_damage(amount: float, _source: Node) -> void:
	if _current <= 0.0:
		return
	_current = maxf(0.0, _current - amount)
	health_changed.emit(_current, max_health)
	if _current == 0.0:
		died.emit()


func get_health() -> float:
	return _current
