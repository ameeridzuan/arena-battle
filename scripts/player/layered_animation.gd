extends RefCounted
## One pose writer. Independent presentation clocks keep gait and action cadence separate.
## Seeks make gallery stepping and deterministic pose comparisons use the same runtime graph.
const ACTION := preload("res://scripts/player/animation_action.gd")
var tree: AnimationTree
var player: AnimationPlayer
var base_clip := "Idle"
var base_time := 0.0
var base_speed := 1.0
var action: ACTION
var action_time := 0.0
var action_weight := 0.0
var mask_paths: Array[NodePath] = []
var _base: AnimationNodeAnimation
var _previous: AnimationNodeAnimation
var _action_node: AnimationNodeAnimation
var _overlay: AnimationNodeBlend2
var _previous_time := 0.0
var _previous_speed := 1.0
var _blend_elapsed := 0.0
var _blend_duration := 0.0

func bind(target: AnimationPlayer) -> void:
	player = target
	player.stop()
	var graph := AnimationNodeBlendTree.new()
	_base = AnimationNodeAnimation.new()
	_previous = AnimationNodeAnimation.new()
	_action_node = AnimationNodeAnimation.new()
	_base.animation = &"Idle"
	_previous.animation = &"Idle"
	_action_node.animation = &"Idle"
	graph.add_node(&"Base", _base)
	graph.add_node(&"Previous", _previous)
	graph.add_node(&"Action", _action_node)
	for slot in ["Base", "Previous", "Action"]:
		graph.add_node(slot + "Seek", AnimationNodeTimeSeek.new())
		graph.connect_node(slot + "Seek", 0, slot)
	graph.add_node(&"Locomotion", AnimationNodeBlend2.new())
	graph.connect_node(&"Locomotion", 0, &"PreviousSeek")
	graph.connect_node(&"Locomotion", 1, &"BaseSeek")
	_overlay = AnimationNodeBlend2.new()
	_overlay.filter_enabled = true
	# Resolve each rig's actual Skeleton3D paths; never copy Arclight paths to Warden.
	var animation_root := player.get_node(player.root_node)
	for skeleton_node in animation_root.find_children("*", "Skeleton3D", true, false):
		var skeleton := skeleton_node as Skeleton3D
		var spine := skeleton.find_bone("spine")
		if spine < 0:
			continue
		for bone in skeleton.get_bone_count():
			var ancestor := bone
			while ancestor >= 0 and ancestor != spine:
				ancestor = skeleton.get_bone_parent(ancestor)
			if ancestor == spine:
				var path := NodePath(str(animation_root.get_path_to(skeleton)) + ":" + skeleton.get_bone_name(bone))
				mask_paths.append(path)
				_overlay.set_filter_path(path, true)
	graph.add_node(&"Overlay", _overlay)
	graph.connect_node(&"Overlay", 0, &"Locomotion")
	graph.connect_node(&"Overlay", 1, &"ActionSeek")
	graph.connect_node(&"output", 0, &"Overlay")
	tree = AnimationTree.new()
	tree.name = "LayeredAnimationTree"
	player.get_parent().add_child(tree)
	tree.anim_player = tree.get_path_to(player)
	tree.root_node = tree.get_path_to(animation_root)
	tree.tree_root = graph
	tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	tree.active = true
	evaluate()

func select_base(clip: String, blend_s: float) -> void:
	if clip == base_clip or not player.has_animation(clip):
		return
	var phase := base_time / maxf(player.get_animation(base_clip).length, 0.001)
	_previous.animation = StringName(base_clip)
	_previous_time = base_time
	_previous_speed = base_speed
	var preserve := is_gait(base_clip) and is_gait(clip)
	base_clip = clip
	_base.animation = StringName(clip)
	base_time = phase * player.get_animation(clip).length if preserve else 0.0
	_blend_elapsed = 0.0
	_blend_duration = blend_s

func start_action(spec: ACTION) -> bool:
	if spec == null:
		return false
	if not is_finite(spec.playback_speed) or spec.playback_speed <= 0.0:
		return false
	if not player.has_animation(spec.clip):
		return false
	if spec.layer == ACTION.Layer.UPPER_BODY and mask_paths.is_empty():
		push_warning("Upper-body action rejected: rig has no validated spine mask.")
		return false
	if action != null and (not action.interruptible or spec.priority < action.priority):
		return false
	action = spec
	action_time = 0.0
	action_weight = 1.0 if spec.blend_in_s <= 0.0 else 0.0
	_action_node.animation = spec.clip
	_overlay.filter_enabled = spec.layer == ACTION.Layer.UPPER_BODY
	evaluate()
	return true

func cancel_action() -> void:
	action = null
	action_time = 0.0
	action_weight = 0.0

func reset() -> void:
	cancel_action()
	base_clip = "Idle"
	base_time = 0.0
	base_speed = 1.0
	_base.animation = &"Idle"
	_previous.animation = &"Idle"
	_action_node.animation = &"Idle"
	_previous_time = 0.0
	_previous_speed = 1.0
	_blend_elapsed = 0.0
	_blend_duration = 0.0
	_overlay.filter_enabled = true

func advance(delta: float) -> void:
	base_time = _advance_time(base_clip, base_time, delta * base_speed)
	_previous_time = _advance_time(String(_previous.animation), _previous_time, delta * _previous_speed)
	_blend_elapsed += delta
	if action != null:
		action_time += delta * action.playback_speed
		var length := player.get_animation(action.clip).length
		if action_time >= length:
			cancel_action()
		else:
			var fade_in := minf(1.0, action_time / action.playback_speed / maxf(action.blend_in_s, 0.0001))
			var fade_out := minf(1.0, (length - action_time) / action.playback_speed / maxf(action.blend_out_s, 0.0001))
			action_weight = minf(fade_in, fade_out)
	evaluate()

func evaluate() -> void:
	tree.set("parameters/BaseSeek/seek_request", base_time)
	tree.set("parameters/PreviousSeek/seek_request", _previous_time)
	tree.set("parameters/ActionSeek/seek_request", action_time)
	tree.set("parameters/Locomotion/blend_amount", minf(1.0, _blend_elapsed / maxf(_blend_duration, 0.0001)))
	tree.set("parameters/Overlay/blend_amount", action_weight)
	tree.advance(0.0)

func _advance_time(clip: String, time: float, delta: float) -> float:
	var animation := player.get_animation(clip)
	if animation.loop_mode != Animation.LOOP_NONE:
		return fposmod(time + delta, maxf(animation.length, 0.001))
	return minf(time + delta, animation.length)

static func is_gait(clip: String) -> bool:
	return clip in ["Walk", "Run", "Walk_Backward", "Walk_Left", "Walk_Right"]

func dispose() -> void:
	if is_instance_valid(tree):
		tree.active = false
		tree.queue_free()
