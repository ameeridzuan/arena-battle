extends "res://scripts/combat/melee_attacker.gd"
## Blade-contact authority for local play and matches; replicas only draw accepted trails.
var network_authority := false
signal impact_presented(point: Vector3, normal: Vector3, airborne: bool)
signal weapon_hit(target: Node, point: Vector3, normal: Vector3, amount: float)
const ACTION := preload("res://scripts/player/animation_action.gd")
const IMPACT := preload("res://scripts/combat/weapon_impact.gd")
@export var ground_duration_s := 0.65
@export var air_duration_s := 0.9
@export var contact_start_phase := 0.30
@export var contact_end_phase := 0.80
@export var weapon_radius := 0.07
var current_clip := ""
var is_jump_attack := false
var _elapsed := -1.0
var _duration := 0.65
var _air_used := false
var _driver: Node
var _mesh: Node3D
var _manager: Node
var _hit_rids: Dictionary = {}
var _previous: Array[Vector3] = []
var _trail: MeshInstance3D
var _trail_mesh: ImmediateMesh
var _capture_was_active := false

func owns_animation_action() -> bool:
	return true

func _ready() -> void:
	super._ready()
	# Body movement and the pose writer finish before weapon collision is sampled.
	process_physics_priority = 10
	_driver = _owner_body.get_node("CharacterAnimation")
	_mesh = _owner_body.get_node("Mesh")
	_mesh.model_changed.connect(func(_model: Node3D): cancel_attack())
	var health: Health = _owner_body.get_node("Health")
	health.died.connect(cancel_attack)
	health.reset_performed.connect(func():
		cancel_attack()
		_cooldown_remaining = 0.0
		_air_used = false)
	_manager = get_tree().get_first_node_in_group("match_manager")
	if _manager != null:
		_manager.match_ended.connect(func(_winner: int): cancel_attack())
	_trail_mesh = ImmediateMesh.new()
	_trail = MeshInstance3D.new()
	_trail.name = "WeaponTrail"
	_trail.mesh = _trail_mesh
	_trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = Color(0.25, 0.9, 1.0, 0.35)
	_trail.material_override = mat
	add_child(_trail)
	_trail.top_level = true
	_trail.global_transform = Transform3D.IDENTITY
	_trail.visible = false

func _live() -> bool:
	var health: Health = _owner_body.get_node("Health")
	return (network_authority or (not external_control and not _owner_body.external_control)) and not health.network_replica and health.get_health() > 0.0 and (_manager == null or _manager.get_phase() != 2) and (not _owner_body.has_method("allows_motion_actions") or _owner_body.allows_motion_actions())

func _physics_process(delta: float) -> void:
	var captured := not external_control and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if _capture_was_active and not captured:
		cancel_attack()
	_capture_was_active = captured
	_cooldown_remaining = maxf(0.0, _cooldown_remaining - delta)
	if _grounded() and _owner_body.velocity.y <= 0.0:
		_air_used = false
	if not _live():
		cancel_attack()
		return
	if _elapsed >= 0.0:
		if _driver.get_action_clip() != current_clip:
			cancel_attack()
			return
		_elapsed += delta
		var segment := get_weapon_segment()
		var phase := _elapsed / _duration
		if phase >= contact_start_phase and phase <= contact_end_phase and segment.size() == 2:
			_sweep(segment)
		else:
			_trail.visible = false
		_previous = segment
		if _elapsed >= _duration:
			cancel_attack()
	elif captured and Input.is_action_just_pressed("attack"):
		request_attack()

func request_attack() -> bool:
	if not is_physics_processing() or not _live() or _cooldown_remaining > 0.0 or _elapsed >= 0.0 or not _driver.get_action_clip().is_empty():
		return false
	is_jump_attack = not _grounded() or _owner_body.velocity.y > 0.1
	if is_jump_attack and _air_used:
		return false
	var clip: String = "Attack_Overhead" if is_jump_attack else _driver._next_attack_clip()
	if clip.is_empty() or not is_instance_valid(_driver._anim) or not _driver._anim.has_animation(clip):
		return false
	_duration = air_duration_s if is_jump_attack else ground_duration_s
	var spec := ACTION.new()
	spec.clip = StringName(clip)
	spec.priority = 20
	spec.blend_in_s = 0.035
	spec.blend_out_s = 0.08
	spec.playback_speed = _driver._anim.get_animation(clip).length / maxf(_duration, 0.1)
	if not _driver.present_action(spec):
		return false
	current_clip = clip
	_elapsed = 0.0
	_cooldown_remaining = maxf(attack_cooldown, _duration + 0.05)
	_hit_rids.clear()
	_previous = get_weapon_segment()
	if is_jump_attack:
		_air_used = true
	attack_started.emit(_mesh.global_basis.z.normalized())
	return true

func _grounded() -> bool:
	return _owner_body.is_motion_grounded() if _owner_body.has_method("is_motion_grounded") else _owner_body.is_on_floor()

func get_weapon_segment() -> Array[Vector3]:
	var result: Array[Vector3] = []
	if not is_instance_valid(_mesh) or not is_instance_valid(_mesh._model):
		return result
	var skeletons: Array = _mesh._model.find_children("*", "Skeleton3D", true, false)
	if skeletons.is_empty():
		return result
	var skeleton: Skeleton3D = skeletons[0]
	var hand := skeleton.find_bone("hand.R")
	if hand < 0:
		return result
	var pose := skeleton.global_transform * skeleton.get_bone_global_pose(hand)
	# Blade vertices transformed by their hand.R skin bind (see checkpoint).
	var warden: bool = int(_mesh.character) == 1
	result.append(pose * Vector3(0, 0.07, -0.12 if warden else -0.111))
	result.append(pose * Vector3(0, 0.07, -1.08 if warden else -0.851422))
	return result

func _sweep(segment: Array[Vector3]) -> void:
	if _previous.size() != 2:
		_previous = segment
	var travel := maxf(_previous[0].distance_to(segment[0]), _previous[1].distance_to(segment[1]))
	var steps := clampi(int(ceil(travel / maxf(weapon_radius, 0.01))), 1, 16)
	for step in range(1, steps + 1):
		if _elapsed < 0.0 or not _live():
			return
		var weight := float(step) / steps
		_sample_contacts(_previous[0].lerp(segment[0], weight), _previous[1].lerp(segment[1], weight))
	if _elapsed < 0.0 or _previous.size() != 2:
		return
	_draw_trail(segment)

func _draw_trail(segment: Array[Vector3]) -> void:
	_trail_mesh.clear_surfaces()
	_trail_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for point in [_previous[0], _previous[1], segment[0], segment[1]]:
		_trail_mesh.surface_add_vertex(point)
	_trail_mesh.surface_end()
	_trail.visible = true

func _sample_contacts(grip: Vector3, tip: Vector3) -> void:
	var shape := CapsuleShape3D.new()
	shape.radius = weapon_radius
	shape.height = grip.distance_to(tip) + weapon_radius * 2.0
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis(Quaternion(Vector3.UP, (tip - grip).normalized())), (grip + tip) * 0.5)
	query.collision_mask = 1 | 2 | 4
	query.exclude = [_owner_body.get_rid()]
	var space := get_world_3d().direct_space_state
	var contacts := space.intersect_shape(query, 32)
	for contact in contacts:
		if _elapsed < 0.0 or not _live():
			return
		var target: Node = contact.collider
		var rid: RID = contact.rid
		if _hit_rids.has(rid):
			continue
		var excludes: Array[RID] = [_owner_body.get_rid()]
		for other in contacts:
			if other.rid != rid:
				excludes.append(other.rid)
		query.exclude = excludes
		var info := space.get_rest_info(query)
		if info.is_empty() or info.rid != rid:
			continue
		var point: Vector3 = info.point
		var normal: Vector3 = info.normal
		if target.is_in_group("damageable"):
			if not _valid_target(target):
				continue
			var blocker := PhysicsRayQueryParameters3D.create(grip, point, 1, [_owner_body.get_rid()])
			blocker.hit_from_inside = true
			if not space.intersect_ray(blocker).is_empty():
				continue
			# Animation can move a hand through a thin wall; that cannot grant a hit.
			blocker.from = _owner_body.global_position + Vector3.UP * 0.5
			if not space.intersect_ray(blocker).is_empty():
				continue
			_hit_rids[rid] = true
			var health: Health = target.get_node_or_null("Health")
			var before := health.get_health()
			if target.has_method("receive_melee_hit"):
				target.receive_melee_hit(attack_damage, _owner_body)
			else:
				target.apply_damage(attack_damage, _owner_body)
			var amount := before - health.get_health()
			if amount > 0.0:
				_impact(point, normal)
				weapon_hit.emit(target, point, normal, amount)
		else:
			_hit_rids[rid] = true
			_impact(point, normal)

func _valid_target(target: Node) -> bool:
	if target == _owner_body or not target.has_method("apply_damage"):
		return false
	var health: Health = target.get_node_or_null("Health")
	if health == null or health.network_replica or health.get_health() <= 0.0:
		return false
	var source_team := _owner_body.get_node_or_null("Combatant")
	var target_team := target.get_node_or_null("Combatant")
	if not friendly_fire and source_team != null and target_team != null and source_team.team_id == target_team.team_id:
		return false
	var toward: Vector3 = target.global_position - _owner_body.global_position
	toward.y = 0.0
	var forward := _mesh.global_basis.z
	forward.y = 0.0
	return toward.length() <= attack_range and (toward.length_squared() < 0.0001 or forward.normalized().dot(toward.normalized()) >= cos(deg_to_rad(attack_arc_deg * 0.5)))

func _impact(point: Vector3, normal: Vector3) -> void:
	impact_presented.emit(point, normal, is_jump_attack)
	var effect := Node3D.new()
	effect.set_script(IMPACT)
	effect.normal = normal
	effect.air_attack = is_jump_attack
	_owner_body.get_parent().add_child(effect)
	effect.global_position = point

func cancel_attack() -> void:
	if _elapsed >= 0.0 and is_instance_valid(_driver) and _driver.get_action_clip() == current_clip:
		_driver.cancel_action()
	_elapsed = -1.0
	current_clip = ""
	_previous.clear()
	_hit_rids.clear()
	if is_instance_valid(_trail):
		_trail.visible = false

func _notification(what: int) -> void:
	if not network_authority and what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_instance_valid(_owner_body):
		cancel_attack()

## Client presentation only: draw accepted swings without ever querying damage contacts.
func present_network_trail() -> void:
	if not _owner_body.get_node("Health").network_replica:
		return
	var clip: String = _driver.get_action_clip()
	if not clip.begins_with("Attack_") or _driver._layers == null or _driver._layers.action == null:
		_trail.visible = false
		_previous.clear()
		return
	var segment := get_weapon_segment()
	var length: float = _driver._anim.get_animation(clip).length
	var phase: float = _driver._layers.action_time / maxf(length, 0.001)
	if segment.size() == 2 and _previous.size() == 2 and phase >= contact_start_phase and phase <= contact_end_phase:
		_draw_trail(segment)
	else:
		_trail.visible = false
	_previous = segment
