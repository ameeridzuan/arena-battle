extends RefCounted
## Capsule sweeps validate headroom, forward clearance and a walkable landing.
var last_height := 0.0
var total_steps := 0
var support_left := 0.0

func is_supported(body: CharacterBody3D) -> bool:
	return body.is_on_floor() or (support_left > 0.0 and body.velocity.y <= 0.1)

func move(body: CharacterBody3D, delta: float, max_height: float, can_step: bool) -> float:
	last_height = 0.0
	var grounded := is_supported(body)
	support_left = maxf(0.0, support_left - delta)
	var start_y := body.position.y
	var slope_limit := body.floor_max_angle
	var stepping := false
	var horizontal := Vector3(body.velocity.x, 0, body.velocity.z) * delta
	if can_step and grounded and body.velocity.y <= 0.0 and horizontal.length_squared() > 0.000001:
		stepping = _step_up(body, horizontal, max_height)
	if stepping:
		support_left = 0.1
		# A validated tread permits the capsule to roll over its rounded toe contact.
		body.floor_max_angle = deg_to_rad(89.0)
	body.move_and_slide()
	body.floor_max_angle = slope_limit
	if can_step and grounded and body.velocity.y <= 0.0 and not body.is_on_floor():
		var down := KinematicCollision3D.new()
		if body.test_move(body.global_transform, Vector3.DOWN * max_height, down, body.safe_margin, true):
			if down.get_normal().dot(Vector3.UP) >= cos(body.floor_max_angle):
				var drop := down.get_travel().y
				if drop < -0.005:
					body.position.y += drop
					last_height += drop
					body.apply_floor_snap()
	if can_step and grounded and absf(body.position.y - start_y) <= max_height + 0.02:
		last_height = body.position.y - start_y
	if absf(last_height) > 0.005:
		total_steps += 1
	return last_height

func _step_up(body: CharacterBody3D, horizontal: Vector3, max_height: float) -> bool:
	var obstruction := KinematicCollision3D.new()
	if not body.test_move(body.global_transform, horizontal, obstruction):
		return false
	if obstruction.get_normal().dot(Vector3.UP) >= cos(body.floor_max_angle):
		return false
	# Only static world geometry is eligible: never stand on an opponent to gain height.
	var collider := obstruction.get_collider()
	if not collider is StaticBody3D or (collider.collision_layer & 1) == 0:
		return false
	var raised := body.global_transform
	var lift := Vector3.UP * (max_height + 0.02)
	if body.test_move(raised, lift):
		return false
	raised.origin += lift
	if body.test_move(raised, horizontal):
		return false
	raised.origin += horizontal
	var landing := KinematicCollision3D.new()
	if not body.test_move(raised, -lift, landing):
		return false
	var rise := lift.y + landing.get_travel().y
	if rise < -0.005 or rise > max_height + 0.001:
		return false
	# Reject rounded capsule contacts against a tall vertical wall masquerading as a step.
	var point := body.global_position + horizontal.normalized() * (0.5 + horizontal.length() + 0.04)
	var feet := body.global_position.y - 1.0
	var query := PhysicsRayQueryParameters3D.create(Vector3(point.x, feet + max_height + 0.03, point.z), Vector3(point.x, feet - 0.03, point.z), 1, [body.get_rid()])
	var hit := body.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or hit.collider != collider or hit.position.y - feet < 0.01 or hit.normal.dot(Vector3.UP) < cos(body.floor_max_angle) or hit.position.y - feet > max_height + 0.001:
		return false
	body.position.y += maxf(rise, 0.0)
	body.velocity.y = 0.0
	last_height = rise
	return true
