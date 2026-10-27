extends SceneTree
var course: Node3D
var body: CharacterBody3D
var camera: Camera3D
var title: Label
func _initialize() -> void:
	call_deferred("run")
func frames(count: int) -> void:
	for i in count:
		await physics_frame
	await process_frame
func simulate_ticks(count: int) -> void:
	for i in count:
		await physics_frame
		body._simulate_movement(1.0 / 60.0, Vector3.ZERO, false, false)
	await process_frame
func picture(sheet: Image, column: int, row: int, label: String, settle_frames: int = 3) -> void:
	title.text = label
	if settle_frames > 0:
		await frames(settle_frames)
	await RenderingServer.frame_post_draw
	var shot := root.get_texture().get_image()
	shot.convert(Image.FORMAT_RGB8)
	shot.resize(640, 360, Image.INTERPOLATE_LANCZOS)
	sheet.blit_rect(shot, Rect2i(0, 0, 640, 360), Vector2i(column * 640, row * 360))

func capture_sequence(rig: int) -> void:
	body.get_node("Mesh").set_character(rig)
	await frames(4)
	body.reset_traversal()
	body.position = Vector3(0, 1.01, -19.25)
	body.velocity = Vector3.ZERO
	body.move_and_slide()
	body.traversal_motor.regrab_delay = 0.0
	body.traversal_motor.request_ledge(Vector3.FORWARD)
	camera.position = Vector3(4.6, 2.5, -17.1)
	camera.look_at(Vector3(0, 1.7, -20.0))
	camera.fov = 40.0
	await simulate_ticks(20)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.godot/parkour_frames"))
	var index := 0
	for tick_index in range(-30, 180):
		if tick_index == 0:
			body.traversal_motor._start_climb()
		await physics_frame
		body._simulate_movement(1.0 / 60.0, Vector3.ZERO, false, false)
		if tick_index % 3 == 0:
			title.text = ("Arclight" if rig == 0 else "Warden") + " | %.2f s | %s" % [float(tick_index) / 60.0, body.get_traversal_mode()]
			await RenderingServer.frame_post_draw
			var shot := root.get_texture().get_image()
			shot.convert(Image.FORMAT_RGB8)
			shot.resize(640, 360, Image.INTERPOLATE_LANCZOS)
			shot.save_png("res://.godot/parkour_frames/rig%d_%03d.png" % [rig, index])
			index += 1
	print("CONTINUOUS_FRAMES rig=", rig, " count=", index)

func run() -> void:
	course = load("res://scenes/characters/MotionTestCourse.tscn").instantiate()
	root.add_child(course)
	body = course.get_node("Player")
	body.external_control = true
	await frames(4)
	for layer in course.find_children("*", "CanvasLayer", true, false):
		layer.hide()
	for label in course.find_children("*", "Label3D", true, false):
		label.hide()
	var ui := CanvasLayer.new()
	course.add_child(ui)
	title = Label.new()
	title.position = Vector2(20, 20)
	title.add_theme_font_size_override("font_size", 30)
	ui.add_child(title)
	camera = Camera3D.new()
	course.add_child(camera)
	camera.current = true
	camera.fov = 35.0
	var sheet := Image.create(2560, 720, false, Image.FORMAT_RGB8)
	var knee_sheet := Image.create(1280, 720, false, Image.FORMAT_RGB8)
	for rig in 2:
		body.get_node("Mesh").set_character(rig)
		await frames(4)
		body.reset_traversal()
		body.position = Vector3(0, 1.01, -19.25)
		body.velocity = Vector3.ZERO
		body.move_and_slide()
		body.traversal_motor.regrab_delay = 0.0
		body.traversal_motor.request_ledge(Vector3.FORWARD)
		camera.position = Vector3(2.8, 2.7, -16.8)
		camera.look_at(Vector3(0, 1.2, -20))
		await simulate_ticks(15)
		await picture(sheet, 0, rig, ("Arclight" if rig == 0 else "Warden") + " / planted hang")
		body.traversal_motor._start_climb()
		var motor: RefCounted = body.traversal_motor
		for column in range(1, 4):
			var phase: float = [0.0, 0.43, 0.72, 0.86][column]
			while motor.climb_progress < phase:
				await physics_frame
				body._simulate_movement(1.0 / 60.0, Vector3.ZERO, false, false)
			var focus := Vector3(0, body.position.y - 0.2, -20)
			camera.position = focus + Vector3(2.8, 1.5, 3.2)
			camera.look_at(focus)
			await frames(10)
			await picture(sheet, column, rig, ["", "Higher pop + left knee", "Left foot under body", "Left-leg push / right extended"][column])
			if column >= 2:
				camera.position = focus + Vector3(-2.8, 1.6, -3.2)
				camera.look_at(focus)
				await picture(knee_sheet, column - 2, rig, ("Arclight" if rig == 0 else "Warden") + " front knees / %.2f" % phase)
	sheet.save_png("res://.godot/traversal_animation_review.png")
	knee_sheet.save_png("res://.godot/parkour_knee_front_review.png")
	for rig in 2:
		await capture_sequence(rig)
	camera.fov = 35.0
	var low_sheet := Image.create(2560, 720, false, Image.FORMAT_RGB8)
	for rig in 2:
		body.get_node("Mesh").set_character(rig)
		await frames(4)
		body.reset_traversal()
		body.position = Vector3(-9, 1.01, -19.25)
		body.velocity = Vector3.ZERO
		body.move_and_slide()
		body.traversal_motor.regrab_delay = 0.0
		body.traversal_motor.request_ledge(Vector3.FORWARD)
		var low_motor: RefCounted = body.traversal_motor
		for column in 4:
			var phase: float = [0.11, 0.22, 0.44, 0.66][column]
			while low_motor.climb_progress < phase:
				await physics_frame
				body._simulate_movement(1.0 / 60.0, Vector3.ZERO, false, false)
			var focus := Vector3(-9, body.position.y - 0.2, -20)
			camera.position = focus + Vector3(2.8, 1.5, 3.2)
			camera.look_at(focus)
			await frames(10)
			await picture(low_sheet, column, rig, ("Arclight" if rig == 0 else "Warden") + " low mantle / %.2f" % phase)
	low_sheet.save_png("res://.godot/low_mantle_animation_review.png")
	var wall_sheet := Image.create(2560, 720, false, Image.FORMAT_RGB8)
	var slide_sheet := Image.create(1280, 720, false, Image.FORMAT_RGB8)
	course._box("ReviewWall", Vector3(5, 6, 0.3), Vector3(-18, 3, 9.3), Color(0.5, 0.32, 0.12))
	await frames(2)
	for rig in 2:
		body.get_node("Mesh").set_character(rig)
		await frames(4)
		body.reset_traversal()
		var motor: RefCounted = body.traversal_motor
		body.position = Vector3(-18, 3.0, 10)
		body.velocity = Vector3.DOWN
		body.move_and_slide()
		await frames(2)
		for slide_tick in 16:
			await physics_frame
			body._simulate_movement(1.0 / 60.0, Vector3.FORWARD, false, false)
		camera.position = body.position + Vector3(3, 0.8, 3)
		camera.look_at(body.position)
		await picture(slide_sheet, 0, rig, ("Arclight" if rig == 0 else "Warden") + " wall slide / side", 0)
		camera.position = body.position + Vector3(0, 0.5, 4)
		camera.look_at(body.position)
		await picture(slide_sheet, 1, rig, ("Arclight" if rig == 0 else "Warden") + " wall slide / rear", 0)
		motor.simulate(1.0 / 60.0, Vector3.FORWARD, true, false, false)
		var elapsed_ticks := 0
		for column in 4:
			var target_tick: int = [2, 6, 14, 26][column]
			while elapsed_ticks < target_tick:
				await physics_frame
				body._simulate_movement(1.0 / 60.0, Vector3.ZERO, false, false)
				elapsed_ticks += 1
			camera.position = body.position + Vector3(3, 0.8, 3)
			camera.look_at(body.position)
			await picture(wall_sheet, column, rig, ("Arclight" if rig == 0 else "Warden") + " wall jump / %.2f s" % motor.wall_jump_elapsed, 0)
	wall_sheet.save_png("res://.godot/wall_jump_animation_review.png")
	slide_sheet.save_png("res://.godot/wall_slide_animation_review.png")
	course.free()
	quit()
