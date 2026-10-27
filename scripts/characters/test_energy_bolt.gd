extends Node3D
## Authoritative traveling spell. Sweep collision once; only validated enemies take damage.
@export var speed := 12.0
@export var lifetime_s := 2.0
@export var damage := 20.0
@export var burn_damage := 3.0
@export var burn_ticks := 3
@export var burn_interval_s := 1.0
var direction := Vector3.BACK
var source_rid: RID
var source: Node
var _spent := false
var _manager: Node

func _ready() -> void:
	add_to_group("motion_test_bolts")
	_manager = get_tree().get_first_node_in_group("match_manager")
	if _manager != null:
		_manager.match_ended.connect(func(_winner: int): queue_free())
	var visual := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.09
	sphere.height = 0.18
	visual.mesh = sphere
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.15, 0.9, 1.0)
	material.emission_enabled = true
	material.emission = Color(0.1, 0.8, 1.0)
	material.emission_energy_multiplier = 2.0
	visual.material_override = material
	add_child(visual)

func _physics_process(delta: float) -> void:
	if _spent or (_manager != null and _manager.get_phase() == 2):
		queue_free()
		return
	if is_instance_valid(source):
		var source_health := source.get_node_or_null("Health") as Health
		if source_health != null and (source_health.network_replica or source_health.get_health() <= 0.0):
			queue_free()
			return
	lifetime_s -= delta
	if lifetime_s <= 0.0:
		queue_free()
		return
	var next := global_position + direction.normalized() * speed * delta
	var ray := PhysicsRayQueryParameters3D.create(global_position, next, 1 | 2 | 4)
	if source_rid.is_valid():
		ray.exclude = [source_rid]
	ray.hit_from_inside = true
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	if not hit.is_empty():
		_spent = true
		global_position = hit.position
		_apply_hit(hit.collider)
		queue_free()
	else:
		global_position = next

func _apply_hit(target: Object) -> void:
	if not is_instance_valid(source) or not target is Node or target == source or not target.is_in_group("damageable") or not target.has_method("apply_damage") or not is_finite(damage) or damage <= 0.0:
		return
	var health := target.get_node_or_null("Health") as Health
	if health == null or health.network_replica or health.get_health() <= 0.0:
		return
	var source_team := source.get_node_or_null("Combatant")
	var target_team: Node = target.get_node_or_null("Combatant")
	if source_team != null and target_team != null and source_team.team_id == target_team.team_id:
		return
	var before := health.get_health()
	target.apply_damage(damage, source)
	if health.get_health() >= before or health.get_health() <= 0.0 or (_manager != null and _manager.get_phase() == 2):
		return
	var burn: Node = target.get_node_or_null("BurnStatus")
	if burn != null:
		burn.apply_burn(source, burn_damage, burn_ticks, burn_interval_s)
