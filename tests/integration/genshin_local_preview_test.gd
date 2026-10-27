extends SceneTree
## Runtime GLB load, feet/scale, movement, jumping, walls and roster isolation.
var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var preview = load("res://scenes/characters/GenshinLocalArena.tscn").instantiate()
	preview.test_mode = true
	root.add_child(preview)
	var body: CharacterBody3D = preview.player
	var anchor = body.get_node("Mesh")
	check(anchor.last_load_error == OK,"Runtime GLB import succeeds")
	check(is_instance_valid(anchor._model),"Model instanced under stable Mesh anchor")
	if not is_instance_valid(anchor._model):
		quit(1)
		return
	var meshes: Array[Node] = anchor._model.find_children("*","MeshInstance3D",true,false)
	check(meshes.size() >= 70,"All costume meshes imported")
	var players: Array[Node] = anchor._model.find_children("*","AnimationPlayer",true,false)
	var skeletons: Array[Node] = anchor._model.find_children("*","Skeleton3D",true,false)
	check(players.size() == 1,"Retargeted AnimationPlayer imported")
	check(skeletons.size() == 1,"Character keeps its actual skin skeleton")
	if players.is_empty() or skeletons.is_empty():
		quit(1)
		return
	var anim: AnimationPlayer = players[0]
	var skeleton: Skeleton3D = skeletons[0]
	check(anim.get_animation_list().size() >= 49,"All 49 authored clips are available")
	check(skeleton.find_bone("spine") >= 0,"Upper-body blend mask resolves the local spine")
	var driver = body.get_node("CharacterAnimation")
	var minimum := Vector3(INF,INF,INF)
	var maximum := Vector3(-INF,-INF,-INF)
	for mesh: MeshInstance3D in meshes:
		var aabb := mesh.get_aabb()
		for i in range(8):
			var point: Vector3 = mesh.global_transform * aabb.get_endpoint(i)
			minimum = minimum.min(point)
			maximum = maximum.max(point)
	check(maximum.y-minimum.y > 1.8 and maximum.y-minimum.y < 2.0,"Character uses metre scale")
	check(absf(minimum.y-(body.position.y-1)) < .04,"Feet align to capsule bottom")
	for i in range(90):
		body.simulate_network_input(1.0/60,Vector2.ZERO,0,false,false)
		await physics_frame
	check(body.is_on_floor(),"Character settles on arena floor")
	check(driver.get_locomotion_clip() == "Idle","Idle selected while stationary")
	for i in range(40):
		body.simulate_network_input(1.0/60,Vector2(0,-1),0,false,false)
		await physics_frame
	check(driver.get_locomotion_clip() == "Walk","Walking selects retargeted gait")
	var origin := body.position
	for i in range(60):
		body.simulate_network_input(1.0/60,Vector2(0,-1),0,true,false)
		await physics_frame
	check(body.position.distance_to(origin) > 2.5,"Existing running movement drives the new visual")
	check(driver.get_locomotion_clip() == "Run","Running selects retargeted gait")
	var floor_y := body.position.y
	body.simulate_network_input(1.0/60,Vector2.ZERO,0,false,true)
	for i in range(12):
		body.simulate_network_input(1.0/60,Vector2.ZERO,0,false,false)
		await physics_frame
	check(body.position.y > floor_y+.4,"Existing jump works")
	check(driver.get_locomotion_clip() == "Jump","Jump selects airborne animation")
	# Inspect deterministic samples through the same AnimationPlayer used in the gallery.
	driver.set_manual_preview(true)
	for clip in anim.get_animation_list():
		if clip == "RESET":
			continue
		anim.play(clip)
		anim.seek(anim.get_animation(clip).length*.17,true)
		skeleton.force_update_all_bone_transforms()
		var first: Array[Quaternion] = []
		for bone in skeleton.get_bone_count():
			first.append(skeleton.get_bone_pose_rotation(bone))
		anim.seek(anim.get_animation(clip).length*.63,true)
		skeleton.force_update_all_bone_transforms()
		var finite := true
		var changed := false
		for bone in skeleton.get_bone_count():
			var transform := skeleton.get_bone_global_pose(bone)
			finite = finite and transform.is_finite() and transform.origin.length() < 5.0
			changed = changed or first[bone].angle_to(skeleton.get_bone_pose_rotation(bone)) > .0001
		check(finite,"Finite bounded pose: " + clip)
		check(changed,"Skeletal motion exists: " + clip)
	# Anatomical sprint regression: no sideways elbows or folded wrists.
	anim.play("Run")
	var compact_elbows := true
	var neutral_wrists := true
	for sample in range(12):
		anim.seek(anim.get_animation("Run").length * sample / 12.0,true)
		skeleton.force_update_all_bone_transforms()
		for side in ["L", "R"]:
			var upper := local_bone(skeleton,"upper_arm." + side)
			var fore := local_bone(skeleton,"forearm." + side)
			var hand := local_bone(skeleton,"hand." + side)
			if mini(upper,mini(fore,hand)) < 0:
				compact_elbows = false
				neutral_wrists = false
				continue
			var u := skeleton.get_bone_global_pose(upper)
			var f := skeleton.get_bone_global_pose(fore)
			var h := skeleton.get_bone_global_pose(hand)
			compact_elbows = compact_elbows and absf(f.origin.x-u.origin.x) < .065
			neutral_wrists = neutral_wrists and f.basis.y.normalized().dot(h.basis.y.normalized()) > .96
	check(compact_elbows,"Run elbows stay close instead of flaring sideways")
	check(neutral_wrists,"Run wrists follow forearms throughout cycle")
	driver.set_manual_preview(false)
	body.get_node("AttackHitbox").request_attack()
	check(not driver.get_action_clip().is_empty(),"Accepted melee attack drives action layer")
	preview.review_animation("Run")
	check(driver._manual_preview and anim.is_playing(),"Animation gallery plays selected clip")
	preview.resume_play()
	check(not driver._manual_preview and body.external_control,"Gallery returns to test controller")
	# A clear lane avoids the terrace colliders while checking the outer wall.
	body.position = Vector3(0,1.03,-4.5)
	body.velocity = Vector3.ZERO
	for i in range(360):
		body.simulate_network_input(1.0/60,Vector2(1,0),0,true,false)
		await physics_frame
	check(body.position.x < 14.1,"Arena wall collision contains the player")
	check(body.get_node("Health").get_health() == 100,"Visual preview does not change health")
	preview.select_preview(1)
	check(anchor._model.find_children("*","Skeleton3D",true,false).size() == 1,"Existing Arclight remains available")
	preview.select_preview(2)
	check(anchor._model.find_children("*","Skeleton3D",true,false).size() == 1,"Existing Warden remains available")
	preview.select_preview(0)
	check(anchor.last_load_error == OK and anchor._model.find_children("*","Skeleton3D",true,false).size() == 1,"Return to animated Genshin model works")
	print("GENSHIN_LOCAL_CHECKS=",checks," FAILURES=",failures)
	print("ALL_TESTS_PASS=",failures == 0)
	preview.queue_free()
	quit(0 if failures == 0 else 1)

func local_bone(skeleton: Skeleton3D, canonical: String) -> int:
	for bone in skeleton.get_bone_count():
		if skeleton.get_bone_name(bone).replace(".","_") == canonical.replace(".","_"):
			return bone
	return -1
