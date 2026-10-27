extends "res://scripts/combat/melee_attacker.gd"
## Main-only readable attack windup. Shared/network melee retains its existing timing.
@export var windup_s := 0.32
var _windup_remaining := -1.0
var _tell: Label3D
var _manager: Node

func _ready() -> void:
	super._ready()
	_tell = Label3D.new()
	_tell.name = "StrikeTell"
	_tell.text = "STRIKE"
	_tell.position = Vector3(0, 1.5, 0)
	_tell.font_size = 52
	_tell.modulate = Color(1.0, 0.55, 0.12)
	_tell.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_tell.visible = false
	add_child(_tell)
	_owner_body.get_node("Health").health_changed.connect(func(current: float, _max: float):
		if current <= 0.0: cancel_windup())
	_manager = get_tree().get_first_node_in_group("match_manager")
	if _manager != null:
		_manager.match_ended.connect(func(_winner: int): cancel_windup())

func _physics_process(delta: float) -> void:
	if external_control or _is_stunned() or _owner_body.get_health() <= 0.0 or (_manager != null and _manager.get_phase() == 2):
		cancel_windup()
		return
	_cooldown_remaining = maxf(0.0, _cooldown_remaining - delta)
	if _windup_remaining >= 0.0:
		_windup_remaining -= delta
		if _windup_remaining <= 0.0:
			cancel_windup()
			# Re-evaluate range/arc at contact, after the defender has had time to evade.
			_perform_attack()
	elif auto_attack and _cooldown_remaining <= 0.0:
		start_windup()

func start_windup() -> bool:
	if not is_physics_processing() or external_control or _is_stunned() or _owner_body.get_health() <= 0.0 or _windup_remaining >= 0.0 or _cooldown_remaining > 0.0 or (_manager != null and _manager.get_phase() == 2):
		return false
	_windup_remaining = maxf(0.01, windup_s)
	_cooldown_remaining = _windup_remaining + attack_cooldown
	_tell.visible = true
	return true

func request_attack() -> bool:
	return start_windup()

func cancel_windup() -> void:
	_windup_remaining = -1.0
	if is_instance_valid(_tell):
		_tell.visible = false
