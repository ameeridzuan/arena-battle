extends SkeletonModifier3D
## Shared graceful skin presentation over existing animation clocks and contact poses.
## Hands used by combat and planted feet are constrained to their incoming transforms.
const SOLVER := preload("res://scripts/player/terrain_foot_modifier.gd")
@export_range(0.0, 1.0) var style_strength := 1.0
var reference_right_hand := Transform3D.IDENTITY
var reference_left_hand := Transform3D.IDENTITY
var reference_feet: Array[Transform3D] = []
var applied_count := 0
var protected_cast := false
var _body: CharacterBody3D
var _driver: Node
var _player: AnimationPlayer
var _bones: Dictionary = {}
var _clock := 0.0
var _solver := SOLVER.new()

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and is_instance_valid(_solver):
		_solver.free()

func _ready() -> void:
	var skeleton := get_skeleton()
	for name in ["hips", "spine", "chest", "neck", "head", "shoulder.L", "upper_arm.L", "forearm.L", "hand.L", "upper_arm.R", "forearm.R", "hand.R", "thigh.L", "shin.L", "foot.L", "thigh.R", "shin.R", "foot.R"]:
		_bones[name] = skeleton.find_bone(name)
	var model := skeleton.get_parent().get_parent()
	_player = model.find_children("*", "AnimationPlayer", true, false)[0]
	var ancestor: Node = model
	while ancestor != null:
		if ancestor is CharacterBody3D:
			_body = ancestor
			_driver = _body.get_node_or_null("CharacterAnimation")
			break
		ancestor = ancestor.get_parent()

func _process_modification_with_delta(delta: float) -> void:
	if _bones.is_empty() or style_strength <= 0.0:
		return
	if _body != null:
		if _body.get_health() <= 0.0 or _body.traversal_motor.pose_name() != "normal":
			return
		var traversal := get_skeleton().get_node_or_null("TraversalPose")
		if traversal != null and traversal.influence > 0.001:
			return
	_clock += clampf(delta, 0.0, 0.1)
	var clip := String(_player.current_animation)
	if clip.is_empty():
		clip = String(_player.assigned_animation)
	var time := _player.current_animation_position if not clip.is_empty() else _clock
	var action := ""
	if _driver != null and _driver._layers != null and not _driver._manual_preview:
		clip = _driver._layers.base_clip
		time = _driver._layers.base_time
		action = _driver.get_action_clip()
	var running := clip == "Run"
	var walking := clip in ["Walk", "Walk_Backward", "Walk_Left", "Walk_Right"]
	var idle := clip == "Idle" and action.is_empty()
	var grounded := idle or walking or running
	if _body != null:
		grounded = grounded and _body.is_motion_grounded()
	var length := _player.get_animation(clip).length if _player.has_animation(clip) else 1.0
	var phase := TAU * time / maxf(length, 0.001)
	var sway := sin(phase) if walking or running else sin(_clock * 1.7)
	var strength := style_strength
	var skeleton := get_skeleton()
	reference_right_hand = skeleton.get_bone_global_pose(_bones["hand.R"])
	reference_left_hand = skeleton.get_bone_global_pose(_bones["hand.L"])
	reference_feet.assign([skeleton.get_bone_global_pose(_bones["foot.L"]), skeleton.get_bone_global_pose(_bones["foot.R"])])
	var right_elbow := skeleton.get_bone_global_pose(_bones["forearm.R"]).origin
	var left_elbow := skeleton.get_bone_global_pose(_bones["forearm.L"]).origin
	var knees := [skeleton.get_bone_global_pose(_bones["shin.L"]).origin, skeleton.get_bone_global_pose(_bones["shin.R"]).origin]
	# A small weight transfer and soft knees, with the original planted-foot paths.
	var roll := deg_to_rad((1.5 + sway * 0.5) if idle else sway * (1.0 if running else 1.8)) * strength
	if grounded and action.is_empty():
		var hips := skeleton.get_bone_global_pose(_bones["hips"])
		hips.origin += Vector3(sway * (0.008 if running else 0.012), -0.009, 0) * strength
		hips.basis = Basis(Vector3.BACK, roll) * hips.basis
		skeleton.set_bone_global_pose(_bones["hips"], hips)
	else:
		roll = 0.0
	# Relaxed shoulders and a poised head; no animation duration or playback changes.
	_rotate("spine", Vector3.BACK, -roll * 0.6)
	_rotate("chest", Vector3.UP, deg_to_rad((sway * 2.0) if walking or running else -1.0) * strength)
	_rotate("chest", Vector3.RIGHT, deg_to_rad(1.0 if running else -0.6) * strength)
	_rotate("neck", Vector3.BACK, -roll * 0.4)
	_rotate("head", Vector3.BACK, deg_to_rad(-1.2 + sin(_clock * 1.1) * 0.35) * strength)
	var shoulder := skeleton.get_bone_global_pose(_bones["shoulder.L"])
	shoulder.origin.y -= 0.007 * strength
	skeleton.set_bone_global_pose(_bones["shoulder.L"], shoulder)
	_rotate("upper_arm.L", Vector3.RIGHT, deg_to_rad(-4.0 if running else -3.0) * strength)
	_rotate("upper_arm.L", Vector3.BACK, deg_to_rad(-4.0) * strength)
	_rotate("forearm.L", Vector3.RIGHT, deg_to_rad(-12.0 if running else -8.0) * strength)
	_rotate("hand.L", Vector3.UP, deg_to_rad(8.0) * strength)
	_rotate("hand.L", Vector3.BACK, deg_to_rad(-5.0) * strength)
	# Preserve the exact incoming sword transform, including orientation and reach.
	_pin([_bones["upper_arm.R"], _bones["forearm.R"], _bones["hand.R"]], reference_right_hand, right_elbow)
	protected_cast = action == "Actions/CastEnergy" or clip == "Actions/CastEnergy"
	if protected_cast:
		_pin([_bones["upper_arm.L"], _bones["forearm.L"], _bones["hand.L"]], reference_left_hand, left_elbow)
	if grounded and action.is_empty():
		for i in 2:
			var side := ".L" if i == 0 else ".R"
			_pin([_bones["thigh" + side], _bones["shin" + side], _bones["foot" + side]], reference_feet[i], knees[i])
	applied_count += 1

func _rotate(label: String, axis: Vector3, radians: float) -> void:
	var skeleton := get_skeleton()
	var pose := skeleton.get_bone_global_pose(_bones[label])
	pose.basis = Basis(axis, radians) * pose.basis
	skeleton.set_bone_global_pose(_bones[label], pose)

func _pin(chain: Array, target: Transform3D, pole: Vector3) -> void:
	var skeleton := get_skeleton()
	var start := skeleton.get_bone_global_pose(chain[0])
	var middle := skeleton.get_bone_global_pose(chain[1])
	var end := skeleton.get_bone_global_pose(chain[2])
	_solver._solve(skeleton, chain, start, middle, end, target.origin, Vector3.UP, pole - start.origin, false)
	skeleton.set_bone_global_pose(chain[2], target)
