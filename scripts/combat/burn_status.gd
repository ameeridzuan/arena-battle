extends Node3D
## One refreshable burn per actor. Damage remains in Health; this owns tick timing.
var _health: Health
var _source: Node
var _damage := 0.0
var _ticks_left := 0
var _interval := 1.0
var _remaining := 0.0
var _manager: Node
var _embers: CPUParticles3D

func _ready() -> void:
	_health = get_parent().get_node("Health") as Health
	_health.died.connect(clear)
	_health.reset_performed.connect(clear)
	_manager = get_tree().get_first_node_in_group("match_manager")
	if _manager != null:
		_manager.match_ended.connect(func(_winner: int): clear())
	_build_embers()
	set_physics_process(false)

func _can_damage() -> bool:
	return _health != null and not _health.network_replica and _health.get_health() > 0.0 and (_manager == null or _manager.get_phase() != 2)

func apply_burn(source: Node, damage: float = 3.0, ticks: int = 3, interval: float = 1.0) -> bool:
	if not _can_damage() or not is_instance_valid(source) or source == get_parent() or not is_finite(damage) or damage <= 0.0 or ticks <= 0 or not is_finite(interval) or interval <= 0.0:
		return false
	var source_health := source.get_node_or_null("Health") as Health
	if source_health != null and source_health.network_replica:
		return false
	var source_team := source.get_node_or_null("Combatant")
	var target_team := get_parent().get_node_or_null("Combatant")
	if source_team != null and target_team != null and source_team.team_id == target_team.team_id:
		return false
	var refreshing := is_burning()
	_source = source
	_damage = damage
	_ticks_left = ticks
	_interval = interval
	# Refresh duration without postponing an already scheduled tick.
	_remaining = minf(_remaining, interval) if refreshing else interval
	_embers.emitting = true
	set_physics_process(true)
	return true

func is_burning() -> bool:
	return _ticks_left > 0

func clear() -> void:
	_ticks_left = 0
	_remaining = 0.0
	_source = null
	if _embers != null:
		_embers.emitting = false
	set_physics_process(false)

func _physics_process(delta: float) -> void:
	if not _can_damage() or not is_instance_valid(_source):
		clear()
		return
	_remaining -= delta
	while _ticks_left > 0 and _remaining <= 0.000001:
		_ticks_left -= 1
		_remaining += _interval
		_health.apply_damage(_damage, _source, &"burn")
		# Damage can synchronously end the match, kill, or reset the target.
		if not _can_damage() or _ticks_left <= 0:
			clear()
			return

func _build_embers() -> void:
	_embers = CPUParticles3D.new()
	_embers.name = "BurnEmbers"
	_embers.emitting = false
	_embers.amount = 18
	_embers.lifetime = 0.55
	_embers.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_embers.emission_sphere_radius = 0.35
	_embers.direction = Vector3.UP
	_embers.spread = 25.0
	_embers.gravity = Vector3(0.0, 0.7, 0.0)
	_embers.initial_velocity_min = 0.5
	_embers.initial_velocity_max = 1.1
	_embers.color = Color(1.0, 0.4, 0.05)
	var sphere := SphereMesh.new()
	sphere.radius = 0.035
	sphere.height = 0.07
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1.0, 0.4, 0.05)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.2, 0.02)
	sphere.material = material
	_embers.mesh = sphere
	add_child(_embers)
	_embers.position.y = 0.3
