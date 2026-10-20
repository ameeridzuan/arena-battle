extends SceneTree
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ",label)
func correlation(a: Array[float], b: Array[float]) -> float:
	var ma := 0.0
	var mb := 0.0
	for i in a.size(): ma += a[i]/a.size(); mb += b[i]/b.size()
	var product := 0.0
	var aa := 0.0
	var bb := 0.0
	for i in a.size():
		product += (a[i]-ma)*(b[i]-mb)
		aa += pow(a[i]-ma,2); bb += pow(b[i]-mb,2)
	return product/sqrt(maxf(aa*bb,0.000001))
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var gallery = load("res://scenes/characters/AnimationReviewGallery.tscn").instantiate()
	root.add_child(gallery)
	gallery.set_process(false)
	gallery._set_paused(true)
	var metrics: Dictionary = {}
	for body in gallery.bodies:
		var driver = body.get_node("CharacterAnimation")
		var player: AnimationPlayer = driver._anim
		var skeleton: Skeleton3D = body.find_children("*","Skeleton3D",true,false)[0]
		var origin: Transform3D = body.transform
		metrics[body.name] = {}
		check(is_equal_approx(body.walk_speed,1.2) and is_equal_approx(body.run_speed,3.8),"natural default speeds")
		for name in ["Walk","Run"]:
			driver.set_manual_preview(true)
			var clip := player.get_animation(name)
			check(clip.has_meta("source_capture"),name+" is captured motion")
			check(clip.loop_mode == Animation.LOOP_LINEAR,name+" loops")
			var leg: Array[float] = []
			var opposite_arm: Array[float] = []
			var feet: Array[Vector3] = []
			var pelvic_y: Array[float] = []
			var maximum_knee_forward := -INF
			var finite := true
			player.play(name,0)
			for sample in range(121):
				player.seek(clip.length*sample/120.0,true)
				var hip := skeleton.get_bone_global_pose(skeleton.find_bone("thigh.L")).origin
				var knee := skeleton.get_bone_global_pose(skeleton.find_bone("shin.L")).origin
				var ankle := skeleton.get_bone_global_pose(skeleton.find_bone("foot.L")).origin
				var shoulder := skeleton.get_bone_global_pose(skeleton.find_bone("upper_arm.R")).origin
				var hand := skeleton.get_bone_global_pose(skeleton.find_bone("hand.R")).origin
				leg.append(ankle.z-hip.z)
				opposite_arm.append(hand.z-shoulder.z)
				feet.append(ankle)
				pelvic_y.append(skeleton.get_bone_global_pose(skeleton.find_bone("hips")).origin.y)
				maximum_knee_forward = maxf(maximum_knee_forward,knee.z-(hip.z+ankle.z)*0.5)
				for i in skeleton.get_bone_count(): finite = finite and skeleton.get_bone_pose(i).is_finite()
			check(finite,name+" finite transforms")
			check(feet[0].distance_to(feet[-1])<0.003,name+" ankle loop closes")
			check(maximum_knee_forward>0.04,name+" knee bends forward")
			var coordination := correlation(leg,opposite_arm)
			check(coordination>0.25,name+" opposite arm and leg coordinate")
			var bob: float = pelvic_y.max()-pelvic_y.min()
			check(bob>0.005 and bob<0.25,name+" captures pelvic vertical motion")
			check(body.transform.is_equal_approx(origin),name+" cannot move gameplay body")
			var minimum_height := INF
			for point in feet: minimum_height = minf(minimum_height,point.y)
			var contact_slip := 0.0
			var contact_pairs := 0
			var dt := clip.length/120.0
			var speed: float = clip.get_meta("nominal_speed_m_s")
			for i in range(1,feet.size()):
				if feet[i].y < minimum_height+0.02 and feet[i-1].y < minimum_height+0.02:
					var displacement := feet[i]-feet[i-1]+Vector3(0,0,speed*dt)
					contact_slip += Vector2(displacement.x,displacement.z).length()
					contact_pairs += 1
			metrics[body.name][name] = {"contralateral_correlation":coordination,"pelvis_bob_m":bob,"maximum_knee_forward_m":maximum_knee_forward,"flat_ankle_path_m":contact_slip,"flat_ankle_samples":contact_pairs,"nominal_speed_m_s":speed}
			# Cadence must follow speed, then reset for an attack and idle.
			driver.set_manual_preview(false)
			driver.reset_presentation()
			body.velocity = Vector3(0,0,body.walk_speed if name=="Walk" else body.run_speed)
			driver._physics_process(0.016)
			check(is_equal_approx(driver.get_locomotion_speed(),body.velocity.z/speed),name+" cadence follows velocity")
			driver._layers.base_time = clip.length*0.37
			var other := "Run" if name=="Walk" else "Walk"
			driver._play(other)
			check(absf(driver.get_locomotion_position()/player.get_animation(other).length-0.37)<0.005,"walk/run preserves phase")
		driver._on_attack_started(Vector3.BACK)
		check(driver.get_action_clip() == "Attack_Slash", "attack starts independently of gait cadence")
		driver._physics_process(0.1)
		check(is_equal_approx(driver._layers.action_time,0.1),"attack cadence unchanged")
		driver._physics_process(player.get_animation("Attack_Slash").length)
		check(driver.get_action_clip() == "", "attack finishes on its own clock")
		body.velocity = Vector3.ZERO
		driver._physics_process(0.016)
		check(driver.get_locomotion_clip() == "Idle" and is_equal_approx(driver.get_locomotion_speed(),1.0),"idle resets cadence")
		check(player.has_animation("Capture/JumpCapture") and player.has_animation("Capture/StrafeCapture"),"other captured moves available")
	FileAccess.open("user://human-gait-metrics.json",FileAccess.WRITE).store_string(JSON.stringify(metrics,"\t"))
	print(JSON.stringify(metrics))
	gallery.free()
	print("HUMAN_GAIT_CHECKS=",checks," FAILURES=",failures," ALL_TESTS_PASS=",failures==0)
	quit(0 if failures==0 else 1)
