extends "res://tests/integration/traversal_smoke_test.gd"
## Read actual modifier output while advancing the real motor continuously.
var current_rig := 0
var next_phase := 0
const PHASES := [0.32, 0.47, 0.55, 0.65, 0.78, 0.85, 0.94, 0.99]

func report_pose(skeleton: Skeleton3D, modifier: SkeletonModifier3D) -> void:
	var motor: RefCounted = body.traversal_motor
	var lip: Vector3 = motor.ledge_point
	print("POSE rig=", current_rig, " phase=", motor.climb_progress, " state=", body.get_traversal_mode(), " phase_name=", modifier.phase_name, " correction=", modifier.clearance_correction, " source=", modifier.clearance_source)
	for bone_name in ["hips", "upper_arm.L", "forearm.L", "hand.L", "upper_arm.R", "forearm.R", "hand.R", "thigh.L", "shin.L", "foot.L", "thigh.R", "shin.R", "foot.R"]:
		var bone := skeleton.find_bone(bone_name)
		print(" BONE ", bone_name, " lip_relative=", skeleton.to_global(skeleton.get_bone_global_pose(bone).origin) - lip)
	for key in modifier.contact_targets:
		var target: Dictionary = modifier.contact_targets[key]
		var marker: Dictionary = modifier.contact_markers[key]
		var actual: Vector3 = skeleton.global_transform * skeleton.get_bone_global_pose(marker.bone) * marker.local
		print(" CONTACT ", key, " weight=", target.weight, " actual=", actual - lip, " anchor=", target.anchor - lip, " error=", actual.distance_to(target.anchor))
	var worst := 0.0
	var offender := ""
	var at := Vector3.ZERO
	for bone in modifier.geometry.bounds:
		for point in modifier.geometry.points(bone):
			var depth: float = minf(lip.y - point.y, -(point - lip).dot(motor.wall_normal))
			if depth > worst:
				worst = depth
				offender = skeleton.get_bone_name(bone)
				at = point - lip
	print(" ENVELOPE depth=", worst, " bone=", offender, " corner=", at)

func run() -> void:
	world = Node3D.new()
	root.add_child(world)
	body = PLAYER.instantiate()
	body.set_script(LOCAL)
	body.get_node("Combatant").free()
	if body.has_node("BurnStatus"):
		body.get_node("BurnStatus").free()
	world.add_child(body)
	body.set_physics_process(false)
	for rig in 2:
		current_rig = rig
		body.get_node("Mesh").set_character(rig)
		await frames(4)
		await fixture(1.8)
		var skeleton: Skeleton3D = body.stair_presentation._skeleton
		var modifier: SkeletonModifier3D = body.stair_presentation._traversal_modifier
		next_phase = 0
		var observer := func():
			if body.get_traversal_mode() == "climb" and next_phase < PHASES.size() and body.traversal_motor.climb_progress >= PHASES[next_phase]:
				report_pose(skeleton, modifier)
				next_phase += 1
		modifier.modification_processed.connect(observer)
		check(body.traversal_motor.request_ledge(Vector3.FORWARD), "measurement fixture grabs")
		await tick(20)
		var hang_observer := func(): report_pose(skeleton, modifier)
		modifier.modification_processed.connect(hang_observer, CONNECT_ONE_SHOT)
		await tick(1)
		body.traversal_motor._start_climb()
		await tick(180)
		modifier.modification_processed.disconnect(observer)
	world.free()
	quit()
