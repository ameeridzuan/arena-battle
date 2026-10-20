extends SceneTree
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ",label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var gallery = load("res://scenes/characters/AnimationReviewGallery.tscn").instantiate()
	root.add_child(gallery)
	check(gallery.bodies.size()==2,"both review bodies constructed")
	gallery.set_process(false)
	gallery._set_paused(true)
	for body in gallery.bodies:
		var driver = body.get_node("CharacterAnimation")
		var player: AnimationPlayer = driver._anim
		var mesh: Node3D = body.get_node("Mesh")
		var skeleton: Skeleton3D = body.find_children("*","Skeleton3D",true,false)[0]
		for yaw in [0.0,PI/2.0,-PI/2.0]:
			mesh.rotation.y = yaw
			for sample in [[Vector3.BACK,"Walk"],[Vector3.FORWARD,"Walk_Backward"],[Vector3.LEFT,"Walk_Left"],[Vector3.RIGHT,"Walk_Right"]]:
				driver.reset_presentation()
				body.velocity = mesh.global_basis * sample[0] * 1.2
				driver._physics_process(0.016)
				check(driver.get_locomotion_clip() == sample[1],"cardinal relative to rotated mesh "+str(yaw)+str(sample[1]))
				var nominal: float = player.get_animation(sample[1]).get_meta("nominal_speed_m_s")
				check(is_equal_approx(driver.get_locomotion_speed(),1.2/nominal),"directional cadence")
		mesh.rotation.y = 0
		driver._move_sector = 0
		driver._play("Walk")
		for sample in [[44.0,"Walk"],[49.0,"Walk"],[52.0,"Walk"],[56.0,"Walk_Right"],[43.0,"Walk_Right"],[36.0,"Walk"]]:
			body.velocity = Vector3(sin(deg_to_rad(sample[0])),0,cos(deg_to_rad(sample[0])))*1.2
			driver._physics_process(.016)
			check(driver.get_locomotion_clip()==sample[1],"angular hysteresis "+str(sample[0]))
		driver._play("Walk_Left")
		driver._layers.base_time = player.get_animation("Walk_Left").length*.37
		driver._play("Walk_Backward")
		check(absf(driver.get_locomotion_position()/player.get_animation("Walk_Backward").length-.37)<.005,"directional phase preservation")
		body.camera_lock_behind = true
		body.get_node("CameraPivot").rotation.y = .7
		mesh.rotation.y = -1.9 # deliberately lag desired camera aim
		var aim_yaw: float = .7+PI
		for local in [Vector3.FORWARD,Vector3.LEFT,Vector3.RIGHT]:
			var direction: Vector3 = local.rotated(Vector3.UP,aim_yaw)
			check(is_equal_approx(body._movement_target_speed(direction,true),1.8),"aim side/back tactical speed")
		check(is_equal_approx(body._movement_target_speed(Vector3.BACK.rotated(Vector3.UP,aim_yaw),true),3.8),"forward aim run remains3.8")
		body._movement_target_speed(Vector3.RIGHT.rotated(Vector3.UP,aim_yaw),true)
		for degrees in [40.0,44.0,46.0,44.0]:
			var diagonal := Vector3(sin(deg_to_rad(degrees)),0,cos(deg_to_rad(degrees))).rotated(Vector3.UP,aim_yaw)
			check(is_equal_approx(body._movement_target_speed(diagonal,true),1.8),"side-to-forward cap hysteresis "+str(degrees))
		for degrees in [36.0,44.0,46.0,52.0]:
			var diagonal := Vector3(sin(deg_to_rad(degrees)),0,cos(deg_to_rad(degrees))).rotated(Vector3.UP,aim_yaw)
			check(is_equal_approx(body._movement_target_speed(diagonal,true),3.8),"forward cap hysteresis "+str(degrees))
		body._movement_target_speed(Vector3.ZERO,true)
		var exact_diagonal := Vector3(1,0,1).rotated(Vector3.UP,aim_yaw)
		check(is_equal_approx(body._movement_target_speed(exact_diagonal,true),1.8),"fresh exact diagonal has stable cap")
		body.camera_lock_behind = false
		check(is_equal_approx(body._movement_target_speed(Vector3.LEFT,true),3.8),"free-look run unchanged")
		body.camera_lock_behind = true
		mesh.rotation.y = 0
		body.velocity = Vector3.RIGHT*3.0
		driver.reset_presentation()
		driver._physics_process(.016)
		check(driver.get_locomotion_clip()=="Walk_Right","decelerating side-step never chooses forward run")
		body.camera_lock_behind = false
		driver.set_manual_preview(true)
		var original: Transform3D = body.transform
		var library := player.get_animation_library("Direction")
		check(library.get_animation_list().size()==9,"nine new captured motions")
		for name in library.get_animation_list():
			var clip := library.get_animation(name)
			var looping := name.begins_with("Walk_")
			check(clip.loop_mode==(Animation.LOOP_LINEAR if looping else Animation.LOOP_NONE),name+" loop contract")
			player.play("Direction/"+name,0)
			var finite := true
			var hips := skeleton.find_bone("hips")
			player.seek(0,true)
			var initial_hip := skeleton.get_bone_global_pose(hips)
			var max_hand := -INF
			for sample in range(13):
				player.seek(clip.length*sample/12.0,true)
				for i in skeleton.get_bone_count():finite=finite and skeleton.get_bone_pose(i).is_finite()
				var hand := skeleton.find_bone("hand.L" if name=="BlockLeftCapture" else "hand.R")
				max_hand=maxf(max_hand,skeleton.get_bone_global_pose(hand).origin.y)
			check(finite and body.transform.is_equal_approx(original),name+" finite pose and stationary body")
			if looping:
				check(skeleton.get_bone_global_pose(hips).origin.distance_to(initial_hip.origin)<.003,name+" closes loop")
			elif name.begins_with("Turn"):
				var final := skeleton.get_bone_global_pose(hips).basis.z
				var first := initial_hip.basis.z
				var turn := wrapf(atan2(final.x,final.z)-atan2(first.x,first.z),-PI,PI)
				check(turn < -0.8 if name=="TurnLeftCapture" else turn > .8,name+" correct turn direction")
			elif name.begins_with("Block"):
				check(max_hand>1.2,name+" raises blocking hand")
		check(body.get_node("Health").get_health()==100,"preview does not apply damage")
	gallery.free()
	print("DIRECTIONAL_CHECKS=",checks," FAILURES=",failures," ALL_TESTS_PASS=",failures==0)
	quit(0 if failures==0 else 1)
