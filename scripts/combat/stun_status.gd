extends Node3D
## Authority owns the four-second clock. Replicas only display accepted state.
var remaining := 0.0
var _health: Health
var _manager: Node
var _label: Label3D

func _ready() -> void:
	process_physics_priority = -40
	_health = get_parent().get_node("Health")
	_health.died.connect(clear)
	_health.reset_performed.connect(clear)
	_manager = get_tree().get_first_node_in_group("match_manager")
	if _manager != null:
		_manager.match_ended.connect(func(_winner: int): clear())
	_label = Label3D.new()
	_label.position.y = 1.45
	_label.font_size = 40
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.modulate = Color("8cefff")
	add_child(_label)
	_refresh()

func apply_stun(source: Node, duration: float = 4.0) -> bool:
	if _health.network_replica or _health.get_health() <= 0 or not is_instance_valid(source) or source == get_parent() or not is_finite(duration) or duration <= 0 or (_manager != null and _manager.get_phase() == 2):
		return false
	var source_health: Health = source.get_node_or_null("Health")
	if source_health == null or source_health.network_replica or source_health.get_health() <= 0:
		return false
	var a := source.get_node_or_null("Combatant")
	var b := get_parent().get_node_or_null("Combatant")
	if a != null and b != null and a.team_id == b.team_id:
		return false
	remaining = maxf(remaining,minf(duration,4.0))
	var body := get_parent()
	if body is CharacterBody3D:
		body.velocity.x = 0
		body.velocity.z = 0
	if body.has_method("reset_traversal"):
		body.reset_traversal()
	var motion := body.get_node_or_null("MotionTestControls")
	if motion != null:
		motion.cancel_motion()
	var weapon := body.get_node_or_null("AttackHitbox")
	if weapon != null:
		if weapon.has_method("cancel_attack"): weapon.cancel_attack()
		if weapon.has_method("cancel_windup"): weapon.cancel_windup()
	var driver := body.get_node_or_null("CharacterAnimation")
	if driver != null: driver.reset_presentation()
	_refresh()
	return true

func is_stunned() -> bool:
	return remaining > 0.000001 and _health != null and _health.get_health() > 0

func _physics_process(delta: float) -> void:
	if not _health.network_replica:
		remaining = maxf(0.0,remaining-delta)
	_refresh()

func apply_network_state(seconds: float) -> void:
	if _health.network_replica and is_finite(seconds):
		remaining = clampf(seconds,0,4)
		_refresh()

func clear() -> void:
	remaining = 0
	_refresh()

func _refresh() -> void:
	if _label != null:
		_label.visible = is_stunned()
		_label.text = "* STUN %.1f *" % remaining
