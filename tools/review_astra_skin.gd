extends SceneTree
## Render three Arclight-skin poses for visual inspection.
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(1400, 900)
	var animated := "--spring-review" in OS.get_cmdline_user_args()
	var graceful := "--grace-review" in OS.get_cmdline_user_args()
	var yixuan := "--yixuan-review" in OS.get_cmdline_user_args()
	animated = animated or graceful
	if animated:
		root.size = Vector2i(1100, 720)
	var models: Array[Node3D] = []
	var players: Array[AnimationPlayer] = []
	var labels: Array[Label3D] = []
	var stage := Node3D.new()
	root.add_child(stage)
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color("25334a")
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color(0.72, 0.57, 0.43)
	world.environment.ambient_light_energy = 0.35
	stage.add_child(world)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, -30, 0)
	light.light_color = Color(1.0, 0.72, 0.46)
	light.light_energy = 1.15
	stage.add_child(light)
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.position = Vector3(0, 1.4, 5.5)
	camera.look_at(Vector3(0, 1.0, 0))
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 3.5
	for i in (2 if graceful else 3):
		var model: Node3D = load("res://assets/models/yixuan.glb" if yixuan else "res://assets/models/astra_yao.glb").instantiate()
		stage.add_child(model)
		var springs := Node.new()
		springs.set_script(preload("res://scripts/player/astra_spring_motion.gd"))
		if yixuan:
			springs.bone_prefix = "Yixuan"
		model.add_child(springs)
		if graceful and i == 0:
			springs.graceful_pose.active = false
		model.position.x = (i - 0.5) * 1.7 if graceful else (i - 1) * 1.4
		if i == 2:
			model.rotation.y = PI
		var player: AnimationPlayer = model.find_children("*", "AnimationPlayer", true, false)[0]
		if yixuan:
			preload("res://scripts/player/skin_animation_retarget.gd").copy_base_clips(player, preload("res://assets/models/arclight.glb"))
		preload("res://scripts/player/animation_resources.gd").make_local(player)
		preload("res://scripts/player/locomotion_library.gd").install(player, 0)
		preload("res://scripts/player/action_library.gd").install(player, 0)
		preload("res://scripts/player/skin_animation_retarget.gd").fit_shared_libraries(player, preload("res://assets/models/arclight.glb"), yixuan)
		player.play("Run" if i == 1 else "Idle")
		player.advance(0.2)
		player.pause()
		models.append(model)
		players.append(player)
		var label := Label3D.new()
		label.text = ["FRONT / RUN", "RUN TO IDLE", "HAIR / SKIRT"][i] if animated else ["ASTRA YAO / IDLE", "ARCLIGHT RUN", "BACK VIEW"][i]
		if yixuan:
			label.text = ["YIXUAN", "ASTRA MOTION / RUN", "HAIR / CLOTH"][i]
		label.position = Vector3(model.position.x, 2.1, 0)
		label.font_size = 23
		labels.append(label)
		stage.add_child(label)
	if graceful:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.godot/astra_grace_frames"))
		var clips := ["Idle", "Walk", "Run", "Attack_Slash"]
		for frame in 360:
			var section := mini(frame / 90, 3)
			if frame % 90 == 0:
				for i in players.size():
					players[i].get_animation(clips[section]).loop_mode = Animation.LOOP_LINEAR
					players[i].play(clips[section], 0.15)
					labels[i].text = ("ORIGINAL / " if i == 0 else "GRACEFUL / ") + clips[section].to_upper()
			await process_frame
			RenderingServer.force_draw(false, 1.0 / 60.0)
			if frame % 6 == 0:
				root.get_texture().get_image().save_png("res://.godot/astra_grace_frames/frame_%03d.png" % frame)
		print("ASTRA_GRACE_FRAMES_CAPTURED")
		quit()
		return
	if animated:
		var frame_folder := "res://.godot/yixuan_spring_frames" if yixuan else "res://.godot/astra_spring_frames"
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(frame_folder))
		for player in players:
			player.get_animation("Run").loop_mode = Animation.LOOP_LINEAR
			player.play("Run")
		for frame in 180:
			var t := float(frame) / 60.0
			for i in models.size():
				models[i].position.x = (i - 1) * 1.4 + sin(t * 3.0) * 0.14 if frame < 120 else (i - 1) * 1.4
				models[i].rotation.y = (PI if i == 2 else 0.0) + sin(t * 2.0) * 0.35 if frame < 120 else (PI if i == 2 else 0.0)
			if frame == 120:
				for player in players:
					player.play("Idle", 0.2)
			await process_frame
			RenderingServer.force_draw(false, 1.0 / 60.0)
			if frame % 4 == 0:
				root.get_texture().get_image().save_png(frame_folder + "/frame_%03d.png" % frame)
		print("ASTRA_SPRING_FRAMES_CAPTURED")
	for i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tools/yixuan_skin_review.png" if yixuan else "res://tools/astra_skin_review.png")
	print("ASTRA_REVIEW_CAPTURED")
	quit()
