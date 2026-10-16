extends Area3D
## Milestone 2 — melee hit-detection component.
##
## Attach to an Area3D child ("AttackHitbox") of the player CharacterBody3D.
## On the "attack" input action the script sweeps overlapping bodies within the
## configured arc and range and calls apply_damage() on every valid target.
##
## Milestone 3 addition: [member auto_attack] lets an opponent swing on cooldown without
## reading player input.  Default false keeps the M2 behaviour byte-for-byte identical.
##
## All tunables are exported — no magic numbers.

@export var attack_damage: float = 25.0
@export var attack_range: float = 2.0
@export var attack_cooldown: float = 0.6
@export var attack_arc_deg: float = 120.0
## When true, attacks every [member attack_cooldown] seconds without reading Input
## (used by the static M3 opponents).  When false, the "attack" action is required.
@export var auto_attack: bool = false
@export var aim_reference_path: NodePath = ^"../CameraPivot"

var _cooldown_remaining: float = 0.0
var _aim_ref: Node3D
var _owner_body: Node


func _ready() -> void:
	# Size the child collision sphere to match attack_range.
	for child in get_children():
		if child is CollisionShape3D:
			var col := child as CollisionShape3D
			var shape: Shape3D = col.shape
			if shape is SphereShape3D:
				(shape as SphereShape3D).radius = attack_range
			break
	_aim_ref = get_node(aim_reference_path) as Node3D
	_owner_body = get_parent()


func _physics_process(delta: float) -> void:
	_cooldown_remaining -= delta
	if _cooldown_remaining <= 0.0:
		# Short-circuit: with auto_attack the Input action is never read (server-safe).
		if auto_attack or Input.is_action_just_pressed("attack"):
			_cooldown_remaining = attack_cooldown
			_perform_attack()


func _perform_attack() -> void:
	var basis := _aim_ref.global_transform.basis
	# XZ-project the camera pivot's -Z axis (forward direction).
	var forward := Vector3(-basis.z.x, 0.0, -basis.z.z)
	if forward.length_squared() < 0.0001:
		return
	forward = forward.normalized()

	var half_arc_rad := deg_to_rad(attack_arc_deg * 0.5)

	for body in get_overlapping_bodies():
		if not body.is_in_group("damageable"):
			continue
		# XZ vector from this hitbox to the target body.
		var to_body := Vector3(
			body.global_position.x - global_position.x,
			0.0,
			body.global_position.z - global_position.z
		)
		if to_body.length_squared() < 0.0001:
			continue
		if to_body.length() > attack_range:  # explicit centre-to-centre range gate
			continue
		var angle := forward.angle_to(to_body.normalized())
		if angle > half_arc_rad:
			continue
		body.apply_damage(attack_damage, _owner_body)
