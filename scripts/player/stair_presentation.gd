extends Node
## Terrain-aware legs and smoothed mesh/camera; never moves the collision capsule.
const TRAVERSAL_POSE := preload("res://scripts/player/traversal_pose_modifier.gd")
const FOOT_MODIFIER := preload("res://scripts/player/terrain_foot_modifier.gd")
@export var mesh_response := 14.0
@export var camera_response := 10.0
@export var foot_response := 18.0
var visual_offset := 0.0
var camera_offset := 0.0
var last_step_height := 0.0
var _body: CharacterBody3D
var _mesh: Node3D
var _model: Node
var _skeleton: Skeleton3D
var _traversal_modifier: SkeletonModifier3D
var _modifier: SkeletonModifier3D
var _last_position := Vector3.ZERO
var _weapons: Array[Node3D] = []
var _weapon_visibility: Array[bool] = []
var _weapons_stowed := false

func _ready() -> void:
	process_physics_priority = 20
	_body = get_parent()
	_mesh = _body.get_node("Mesh")
	_last_position = _body.global_position

func on_step(height: float) -> void:
	visual_offset = clampf(visual_offset - height, -0.4, 0.4)
	camera_offset = clampf(camera_offset - height, -0.4, 0.4)
	last_step_height = height

func reset() -> void:
	_stow_weapons(false)
	visual_offset = 0.0
	camera_offset = 0.0
	last_step_height = 0.0
	if is_instance_valid(_mesh):
		_mesh.position.y = 0.0
		_body.get_node("CameraPivot").position.y = 0.0
	if is_instance_valid(_modifier):
		_modifier.offsets = [0.0, 0.0]
	if is_instance_valid(_traversal_modifier):
		_traversal_modifier.influence = 0.0

func _bind_model() -> void:
	_stow_weapons(false)
	_weapons.clear()
	_weapon_visibility.clear()
	_model = _mesh._model
	_skeleton = null
	_modifier = null
	if not is_instance_valid(_model):
		return
	for candidate in _model.find_children("*", "MeshInstance3D", true, false):
		if String(candidate.name).begins_with("Sword ") or String(candidate.name).begins_with("Longsword "):
			_weapons.append(candidate)
			_weapon_visibility.append(candidate.visible)
	var found := _model.find_children("*", "Skeleton3D", true, false)
	if found.is_empty():
		return
	_skeleton = found[0]
	_modifier = SkeletonModifier3D.new()
	_modifier.set_script(FOOT_MODIFIER)
	_modifier.name = "TerrainFootPlacement"
	_modifier.configure(_skeleton)
	_skeleton.add_child(_modifier)
	var traversal_pose := SkeletonModifier3D.new()
	_traversal_modifier = traversal_pose
	traversal_pose.influence = 0.0
	traversal_pose.set_script(TRAVERSAL_POSE)
	traversal_pose.name = "TraversalPose"
	traversal_pose.configure(_body, _skeleton)
	_skeleton.add_child(traversal_pose)
	reset()

func _physics_process(delta: float) -> void:
	if _model != _mesh._model or not is_instance_valid(_skeleton):
		_bind_model()
	if _last_position.distance_to(_body.global_position) > 1.0 or _body.get_health() <= 0.0:
		reset()
	_last_position = _body.global_position
	visual_offset *= exp(-mesh_response * delta)
	camera_offset *= exp(-camera_response * delta)
	_mesh.position.y = visual_offset
	_body.get_node("CameraPivot").position.y = camera_offset
	if not is_instance_valid(_modifier):
		return
	var pose_state: String = _body.traversal_motor.pose_name()
	_stow_weapons(pose_state != "normal" and _body.get_health() > 0.0)
	var target_weight := 0.0 if pose_state == "normal" else 1.0
	_traversal_modifier.influence = lerpf(_traversal_modifier.influence, target_weight, 1.0 - exp(-18.0 * delta))
	if _body.get_health() <= 0.0:
		_traversal_modifier.influence = 0.0
	var driver: Node = _body.get_node("CharacterAnimation")
	var full_body: bool = not driver.get_action_clip().is_empty() and driver.get_action_clip() != "Actions/CastEnergy"
	var eligible: bool = _body.is_motion_grounded() and _body.velocity.y <= 0.01 and _body.get_health() > 0.0 and not full_body and _body.get_traversal_mode() == "normal"
	var feet := _body.global_position.y - 1.0
	for index in _modifier.legs.size():
		var foot: int = _modifier.legs[index][2]
		var offset := 0.0
		var normal := Vector3.UP
		if eligible and foot >= 0:
			var at := _skeleton.to_global(_skeleton.get_bone_global_pose(foot).origin)
			var query := PhysicsRayQueryParameters3D.create(Vector3(at.x, feet + 0.5, at.z), Vector3(at.x, feet - 0.5, at.z), 1, [_body.get_rid()])
			var hit := _body.get_world_3d().direct_space_state.intersect_ray(query)
			if not hit.is_empty() and hit.normal.dot(Vector3.UP) >= cos(_body.floor_max_angle):
				offset = clampf(hit.position.y - feet - visual_offset, -0.4, 0.4)
				normal = hit.normal
		_modifier.offsets[index] = lerpf(_modifier.offsets[index], offset, 1.0 - exp(-foot_response * delta)) if eligible else 0.0
		_modifier.normals[index] = normal

func _stow_weapons(stow: bool) -> void:
	if stow == _weapons_stowed:
		return
	for index in _weapons.size():
		if is_instance_valid(_weapons[index]):
			_weapons[index].visible = false if stow else _weapon_visibility[index]
	_weapons_stowed = stow
