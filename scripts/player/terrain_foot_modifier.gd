extends SkeletonModifier3D
## Runs after the animation mixer; modifies only the two leg chains.
var offsets := [0.0, 0.0]
var normals := [Vector3.UP, Vector3.UP]
var legs: Array = []
var solve_count := 0

func configure(skeleton: Skeleton3D) -> void:
	for side in ["L", "R"]:
		legs.append([skeleton.find_bone("thigh." + side), skeleton.find_bone("shin." + side), skeleton.find_bone("foot." + side)])

func _process_modification() -> void:
	var skeleton := get_skeleton()
	if skeleton == null:
		return
	for index in legs.size():
		var chain: Array = legs[index]
		if chain.has(-1) or absf(offsets[index]) < 0.001:
			continue
		var hip: Transform3D = skeleton.get_bone_global_pose(chain[0])
		var knee: Transform3D = skeleton.get_bone_global_pose(chain[1])
		var foot: Transform3D = skeleton.get_bone_global_pose(chain[2])
		var target: Vector3 = foot.origin + skeleton.global_basis.inverse() * Vector3.UP * offsets[index]
		_solve(skeleton, chain, hip, knee, foot, target, normals[index])
		solve_count += 1

func _solve(skeleton: Skeleton3D, chain: Array, hip: Transform3D, knee: Transform3D, foot: Transform3D, target: Vector3, normal: Vector3, pole_hint: Vector3 = Vector3.ZERO, align_to_ground: bool = true, maximum_flexion: float = PI, stable_hinge: bool = false) -> void:
	var upper := hip.origin.distance_to(knee.origin)
	var lower := knee.origin.distance_to(foot.origin)
	if minf(upper, lower) < 0.001:
		return
	var direction := (target - hip.origin).normalized()
	var flexion_limit := sqrt(maxf(upper*upper + lower*lower + 2.0*upper*lower*cos(maximum_flexion), 0.0))
	var distance := clampf(hip.origin.distance_to(target), maxf(absf(upper - lower) + 0.01, flexion_limit), (upper + lower) * 0.995)
	target = hip.origin + direction * distance
	var relative_end_basis := knee.basis.inverse() * foot.basis
	var along := (upper * upper - lower * lower + distance * distance) / (2.0 * distance)
	var bend := sqrt(maxf(upper * upper - along * along, 0.0))
	var pole := pole_hint if pole_hint.length_squared() > 0.00001 else knee.origin - hip.origin
	pole -= direction * pole.dot(direction)
	if pole.length_squared() < 0.00001:
		pole = Vector3.BACK - direction * Vector3.BACK.dot(direction)
	if pole.length_squared() < 0.00001:
		return
	var knee_target := hip.origin + direction * along + pole.normalized() * bend
	if stable_hinge:
		# Solve a common hinge plane explicitly; shortest-arc rotations can flip
		# the shin's twist by 180 degrees as a deeply folded thigh passes vertical.
		var hinge := pole.normalized().cross(direction).normalized()
		var upper_rest := skeleton.get_bone_global_rest(chain[0])
		var middle_rest := skeleton.get_bone_global_rest(chain[1])
		var end_rest := skeleton.get_bone_global_rest(chain[2])
		hip.basis = _hinge_frame(upper_rest.basis, middle_rest.origin - upper_rest.origin, knee_target - hip.origin, hinge)
		skeleton.set_bone_global_pose(chain[0], hip)
		knee = skeleton.get_bone_global_pose(chain[1])
		knee.origin = knee_target
		knee.basis = _hinge_frame(middle_rest.basis, end_rest.origin - middle_rest.origin, target - knee_target, hinge)
		skeleton.set_bone_global_pose(chain[1], knee)
		return
	var hip_rotation := Quaternion((knee.origin - hip.origin).normalized(), (knee_target - hip.origin).normalized())
	hip.basis = Basis(hip_rotation) * hip.basis
	skeleton.set_bone_global_pose(chain[0], hip)
	knee = skeleton.get_bone_global_pose(chain[1])
	var updated_foot := skeleton.get_bone_global_pose(chain[2])
	var shin_rotation := Quaternion((updated_foot.origin - knee.origin).normalized(), (target - knee.origin).normalized())
	knee.basis = Basis(shin_rotation) * knee.basis
	skeleton.set_bone_global_pose(chain[1], knee)
	updated_foot = skeleton.get_bone_global_pose(chain[2])
	var local_up := (skeleton.global_basis.inverse() * Vector3.UP).normalized()
	var local_normal := (skeleton.global_basis.inverse() * normal).normalized()
	updated_foot.basis = Basis(Quaternion(local_up, local_normal)) * foot.basis if align_to_ground else knee.basis * relative_end_basis
	skeleton.set_bone_global_pose(chain[2], updated_foot)

func _hinge_frame(rest_basis: Basis, rest_direction: Vector3, direction: Vector3, hinge: Vector3) -> Basis:
	var rest_y := -rest_direction.normalized()
	var rest_x := (rest_basis.x - rest_y * rest_basis.x.dot(rest_y)).normalized()
	var rest_frame := Basis(rest_x, rest_y, rest_x.cross(rest_y)).orthonormalized()
	var desired_y := -direction.normalized()
	var desired_x := (hinge - desired_y * hinge.dot(desired_y)).normalized()
	var desired_frame := Basis(desired_x, desired_y, desired_x.cross(desired_y)).orthonormalized()
	return desired_frame * rest_frame.inverse() * rest_basis
