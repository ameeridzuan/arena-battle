extends Node
## Cosmetic secondary motion; gameplay bones and authority are never simulated here.
## Uses Godot's native SpringBoneSimulator3D after terrain/traversal pose modifiers.
@export var wind_strength := 0.008
@export var bone_prefix := "Astra"
var simulator: SpringBoneSimulator3D
var graceful_pose: SkeletonModifier3D
var limiter: SkeletonModifier3D
var skeleton: Skeleton3D
var chain_count := 0
var reset_count := 0
var _previous_transform := Transform3D.IDENTITY
var _clock := 0.0

func _ready() -> void:
	if bone_prefix == "Yixuan":
		wind_strength = 0.0
	skeleton = get_parent().find_children("*", "Skeleton3D", true, false)[0]
	graceful_pose = SkeletonModifier3D.new()
	graceful_pose.name = bone_prefix + "GracefulPose"
	graceful_pose.set_script(preload("res://scripts/player/astra_graceful_pose.gd"))
	skeleton.add_child(graceful_pose)
	simulator = SpringBoneSimulator3D.new()
	simulator.name = bone_prefix + "SpringBones"
	skeleton.add_child(simulator)
	var children := {}
	for bone in skeleton.get_bone_count():
		if _is_secondary(bone):
			children[bone] = []
	for bone: int in children:
		var parent := skeleton.get_bone_parent(bone)
		if children.has(parent):
			children[parent].append(bone)
	for bone: int in children:
		var parent := skeleton.get_bone_parent(bone)
		if children.has(parent) and children[parent].size() == 1:
			continue
		var end := bone
		while children[end].size() == 1:
			end = children[end][0]
		_add_chain(bone, end)
	_add_colliders()
	limiter = SkeletonModifier3D.new()
	limiter.name = bone_prefix + "SpringLimits"
	limiter.set_script(preload("res://scripts/player/astra_spring_limits.gd"))
	limiter.bone_prefix = bone_prefix
	skeleton.add_child(limiter)
	_previous_transform = skeleton.global_transform
	skeleton.child_entered_tree.connect(_on_skeleton_child)
	var body := get_parent().get_parent().get_parent()
	var health := body.get_node_or_null("Health")
	if health != null:
		health.reset_performed.connect(reset_motion)
		health.died.connect(reset_motion)
	process_physics_priority = 30
	simulator.reset()
	call_deferred("reset_motion")

func _is_secondary(bone: int) -> bool:
	var label := String(skeleton.get_bone_name(bone))
	return label.begins_with(bone_prefix + "Hair_") or label.begins_with(bone_prefix + "Skirt_") or label.begins_with(bone_prefix + "Sleeve_") or label.begins_with(bone_prefix + "Ribbon_")

func _add_chain(start: int, end: int) -> void:
	var index := chain_count
	chain_count += 1
	simulator.setting_count = chain_count
	simulator.set_root_bone(index, start)
	simulator.set_end_bone(index, end)
	simulator.set_extend_end_bone(index, true)
	simulator.set_end_bone_direction(index, SkeletonModifier3D.BONE_DIRECTION_FROM_PARENT)
	simulator.set_end_bone_length(index, 0.025)
	simulator.set_center_from(index, SpringBoneSimulator3D.CENTER_FROM_WORLD_ORIGIN)
	var label := String(skeleton.get_bone_name(start))
	var hair := label.begins_with(bone_prefix + "Hair_")
	var skirt := label.begins_with(bone_prefix + "Skirt_")
	simulator.set_stiffness(index, 3.5 if hair else (5.0 if skirt else 4.0))
	simulator.set_drag(index, 0.32 if hair else 0.48)
	simulator.set_gravity(index, 0.025 if hair else 0.04)
	simulator.set_gravity_direction(index, Vector3.DOWN)
	simulator.set_radius(index, 0.012 if hair else 0.008)
	if bone_prefix == "Yixuan":
		# Dense 20-joint strands need much less retained velocity than Astra's short chains.
		simulator.set_drag(index, 0.90 if hair else 0.95)
		simulator.set_stiffness(index, 2.0 if hair else 3.0)
		simulator.set_gravity(index, 0.004 if hair else 0.007)
		simulator.set_radius(index, 0.004 if hair else 0.003)
		simulator.set_end_bone_length(index, 0.012)
	simulator.set_enable_all_child_collisions(index, true)

func _add_colliders() -> void:
	# All collision shapes follow body bones, with dimensions in metres.
	var yixuan := bone_prefix == "Yixuan"
	_capsule("Torso", "spine", "neck", 0.075 if yixuan else 0.09)
	_capsule("LeftThigh", "thigh.L", "shin.L", 0.062 if yixuan else 0.075)
	_capsule("RightThigh", "thigh.R", "shin.R", 0.062 if yixuan else 0.075)
	var head := SpringBoneCollisionSphere3D.new()
	head.name = "Head"
	head.radius = 0.06 if yixuan else 0.072
	simulator.add_child(head)
	head.bone = skeleton.find_bone("head")
	head.position_offset = Vector3(0, 0.065, 0)

func _capsule(label: String, start_name: String, end_name: String, radius: float) -> void:
	var start := skeleton.find_bone(start_name)
	var end := skeleton.find_bone(end_name)
	var rest := skeleton.get_bone_global_rest(start)
	var offset := rest.basis.inverse() * (skeleton.get_bone_global_rest(end).origin - rest.origin)
	var collider := SpringBoneCollisionCapsule3D.new()
	collider.name = label
	collider.radius = radius
	collider.height = offset.length() + radius * 2.0
	simulator.add_child(collider)
	collider.bone = start
	collider.position_offset = offset * 0.5
	collider.rotation_offset = Quaternion(Vector3.UP, offset.normalized())

func _on_skeleton_child(_child: Node) -> void:
	call_deferred("_move_last")

func _move_last() -> void:
	if is_instance_valid(simulator):
		skeleton.move_child(graceful_pose, skeleton.get_child_count() - 1)
		skeleton.move_child(simulator, skeleton.get_child_count() - 1)
		skeleton.move_child(limiter, skeleton.get_child_count() - 1)

func reset_motion() -> void:
	if is_instance_valid(simulator):
		simulator.reset()
		if is_instance_valid(limiter):
			limiter.reset_motion()
		reset_count += 1

func _physics_process(delta: float) -> void:
	if not is_instance_valid(simulator):
		return
	var current := skeleton.global_transform
	if current.origin.distance_to(_previous_transform.origin) > 1.5 or current.basis.z.dot(_previous_transform.basis.z) < 0.0:
		reset_motion()
	_previous_transform = current
	_clock += delta
	simulator.external_force = Vector3(sin(_clock * 1.3), 0, cos(_clock * 0.9) * 0.4) * wind_strength
