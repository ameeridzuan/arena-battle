extends SkeletonModifier3D
## Limit spring swings around the authored local rest pose, preserving the silhouette.
## The native solver owns inertia/collisions; this final modifier bounds visible rotation.
var bounded_bones: Array[int] = []
@export var bone_prefix := "Astra"
var _limits: Dictionary = {}
var _rates: Dictionary = {}
var _filtered: Dictionary = {}

func _ready() -> void:
	var skeleton := get_skeleton()
	for bone in skeleton.get_bone_count():
		if String(skeleton.get_bone_name(bone)).begins_with(bone_prefix):
			bounded_bones.append(bone)
	if bone_prefix == "Yixuan":
		for bone in bounded_bones:
			var root := bone
			while bounded_bones.has(skeleton.get_bone_parent(root)):
				root = skeleton.get_bone_parent(root)
			var depth := _depth(skeleton, root)
			var label := String(skeleton.get_bone_name(bone))
			var hair := label.begins_with("YixuanHair_")
			var coat := label.begins_with("YixuanSkirt_")
			# A budget for the entire strand, not 32-40 degrees multiplied by every joint.
			_limits[bone] = deg_to_rad(minf(4.5, (12.0 if hair else (8.0 if coat else 7.0)) / depth))
			_rates[bone] = deg_to_rad((45.0 if hair else 30.0) / depth)
		reset_motion()

func _depth(skeleton: Skeleton3D, bone: int) -> int:
	var longest := 0
	for child in skeleton.get_bone_children(bone):
		if bounded_bones.has(child):
			longest = maxi(longest, _depth(skeleton, child))
	return 1 + longest

func reset_motion() -> void:
	_filtered.clear()
	if bone_prefix == "Yixuan" and is_inside_tree():
		for bone in bounded_bones:
			_filtered[bone] = get_skeleton().get_bone_rest(bone).basis.get_rotation_quaternion().normalized()

func _process_modification_with_delta(delta: float) -> void:
	var skeleton := get_skeleton()
	for bone in bounded_bones:
		var label := String(skeleton.get_bone_name(bone))
		var rest := skeleton.get_bone_rest(bone).basis.get_rotation_quaternion()
		var pose := skeleton.get_bone_pose_rotation(bone).normalized()
		var limit := deg_to_rad(32.0 if label.begins_with(bone_prefix + "Hair_") else (22.0 if label.begins_with(bone_prefix + "Skirt_") else 40.0))
		if bone_prefix == "Yixuan":
			limit = _limits[bone]
		var angle := rest.angle_to(pose)
		if bone_prefix != "Yixuan":
			if angle > limit:
				skeleton.set_bone_pose_rotation(bone, rest.slerp(pose, limit / angle).normalized())
			continue
		if angle > limit:
			pose = rest.slerp(pose, limit / angle).normalized()
		if bone_prefix == "Yixuan":
			var previous: Quaternion = _filtered.get(bone, rest)
			# Zero-time pose evaluations must not advance physics or restart the smoothing.
			var dt := clampf(delta, 0.0, 0.05)
			var response := 6.0 if label.begins_with("YixuanHair_") else 8.0
			pose = previous.slerp(pose, 1.0 - exp(-response * dt)).normalized()
			var difference := previous.angle_to(pose)
			var max_step: float = _rates[bone] * dt
			if difference > max_step and difference > 0.000001:
				pose = previous.slerp(pose, max_step / difference).normalized()
			_filtered[bone] = pose
		skeleton.set_bone_pose_rotation(bone, pose)
