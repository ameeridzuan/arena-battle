extends RefCounted
## Authority-owned pose data. Applying this snapshot never runs movement or damage.
const ACTION := preload("res://scripts/player/animation_action.gd")
const MOTOR_FIELDS := ["mode", "ledge_point", "wall_normal", "wall_contact_point", "climb_progress", "climb_from_hang", "climb_start_feet", "hand_anchors", "wall_jump_elapsed", "jump_wall_normal", "jump_origin", "jump_foot_anchor", "jump_leg", "contact_revision", "hang_elapsed", "catch_speed", "shimmy_speed", "shimmy_clock", "shimmy_direction", "_climb_start", "_climb_duration"]

static func capture(body: CharacterBody3D) -> Dictionary:
	var motor: RefCounted = body.traversal_motor
	var traversal := {}
	for field in MOTOR_FIELDS:
		traversal[field] = motor.get(field)
	var driver: Node = body.get_node("CharacterAnimation")
	var action: Array = []
	if driver._layers != null and driver._layers.action != null:
		var spec: Resource = driver._layers.action
		action = [String(spec.clip), driver._layers.action_time, spec.playback_speed, spec.layer, spec.blend_in_s, spec.blend_out_s]
	var health: Health = body.get_node("Health")
	return {"character": int(body.get_node("Mesh").character), "grounded": body.is_motion_grounded(), "aim": body.camera_lock_behind,
		"traversal": traversal, "action": action, "burn": body.get_node("BurnStatus").is_burning(), "damage_kind": String(health.last_damage_kind),
		"step_revision": body.step_revision, "step_height": body.network_step_height}

static func apply(body: CharacterBody3D, state: Dictionary) -> void:
	var mesh: Node = body.get_node("Mesh")
	var character: int = int(state.get("character", mesh.character))
	if character in [0, 1] and int(mesh.character) != character:
		mesh.set_character(character)
		body.get_node("CharacterAnimation")._physics_process(0.0)
		body.stair_presentation._bind_model()
	body.replicated_grounded = bool(state.get("grounded", false))
	body.camera_lock_behind = bool(state.get("aim", false))
	var motor: RefCounted = body.traversal_motor
	var traversal: Dictionary = state.get("traversal", {})
	for field in MOTOR_FIELDS:
		if not traversal.has(field):
			continue
		if field == "hand_anchors":
			motor.hand_anchors.assign(traversal[field])
		elif field == "climb_start_feet":
			motor.climb_start_feet.assign(traversal[field])
		else:
			motor.set(field, traversal[field])
	var revision: int = int(state.get("step_revision", body.step_revision))
	if revision != body.step_revision:
		body.step_revision = revision
		body.stair_presentation.on_step(float(state.get("step_height", 0.0)))
	var burn: Node = body.get_node("BurnStatus")
	burn._embers.emitting = bool(state.get("burn", false)) and body.get_health() > 0.0
	var driver: Node = body.get_node("CharacterAnimation")
	var action: Array = state.get("action", [])
	if action.is_empty() or body.get_health() <= 0.0:
		driver.cancel_action()
		return
	var clip := String(action[0])
	if driver._anim == null or not driver._anim.has_animation(clip):
		return
	if driver.get_action_clip() != clip or float(action[1]) + 0.10 < driver._layers.action_time:
		driver.cancel_action()
		var spec := ACTION.new()
		spec.clip = StringName(clip)
		spec.playback_speed = float(action[2])
		spec.layer = int(action[3])
		spec.blend_in_s = float(action[4])
		spec.blend_out_s = float(action[5])
		driver.present_action(spec)
	if driver._layers != null and driver._layers.action != null:
		driver._layers.action_time = float(action[1])
		driver._layers.evaluate()
