extends Node3D
## Isolated playable appearance test using the existing Player controller and arena.
## Local retargeted animation preview; production roster and build stay separate.
const PLAYER := preload("res://scenes/characters/Player.tscn")
const ARENA := preload("res://scenes/arena/ParkourArena.tscn")
const MODEL_OVERRIDE := preload("res://scripts/characters/genshin_local_model.gd")
const ANIMATION_OVERRIDE := preload("res://scripts/characters/genshin_local_animation.gd")

@export var test_mode := false
var player: CharacterBody3D
var preview_index := 0
var status: Label
var details: Label
var gallery_index := -1
var gallery_clips: Array[String] = []

func _ready() -> void:
	var arena: Node3D = ARENA.instantiate()
	add_child(arena)
	var floor_mesh: MeshInstance3D = arena.get_node("Arena/Floor/MeshInstance3D")
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color("364451")
	floor_mat.roughness = .88
	floor_mesh.material_override = floor_mat
	player = PLAYER.instantiate()
	player.name = "GenshinPreviewPlayer"
	player.position = Vector3(0, 1.03, 4)
	player.external_control = test_mode
	player.get_node("Mesh").set_script(MODEL_OVERRIDE)
	player.get_node("CharacterAnimation").set_script(ANIMATION_OVERRIDE)
	player.get_node("Mesh").rotation.y = PI
	var pivot := player.get_node("CameraPivot")
	pivot.local_input_enabled = not test_mode and DisplayServer.get_name() != "headless"
	pivot.rotation.y = PI
	var camera: Camera3D = player.get_node("CameraPivot/CameraTilt/Camera3D")
	camera.position = Vector3(0, .6, 3.7)
	camera.fov = 62
	player.get_node("CameraPivot/CameraTilt").rotation.x = deg_to_rad(-7)
	pivot.set("_pitch_deg", -7.0)
	add_child(player)
	_add_jump_blocks()
	_build_ui()
	_refresh_status()
	if "--genshin-capture" in OS.get_cmdline_user_args():
		_capture.call_deferred()
	if "--genshin-animation-capture" in OS.get_cmdline_user_args():
		_capture_animation.call_deferred()
	if "--genshin-showcase" in OS.get_cmdline_user_args():
		player.get_node("CameraPivot").rotation.y = PI - .5
		review_animation.call_deferred("Run")

func _add_jump_blocks() -> void:
	for i in range(3):
		var block := StaticBody3D.new()
		block.position = Vector3(-4, .15 + i*.15, 1 - i*2.2)
		var size := Vector3(2, .3 + i*.3, 1.6)
		var visual := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = size
		visual.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color("357e88")
		visual.material_override = mat
		block.add_child(visual)
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		block.add_child(collision)
		add_child(block)

func _build_ui() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var panel := PanelContainer.new()
	panel.position = Vector2(18,18)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(.035,.055,.075,.91)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel",style)
	canvas.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation",7)
	panel.add_child(col)
	var title := Label.new()
	title.text = "ARENABATTLE / LOCAL CHARACTER TEST"
	title.add_theme_font_size_override("font_size",22)
	col.add_child(title)
	status = Label.new()
	status.add_theme_color_override("font_color",Color("7fddd8"))
	col.add_child(status)
	var help := Label.new()
	help.text = "WASD: move  |  Shift: run  |  Space: jump  |  LMB: attack\nMouse: orbit  |  V: aim camera  |  F2: front/back\nF3: next animation  |  F4: resume play\nTab: compare characters  |  Home: reset  |  Esc: cursor"
	col.add_child(help)
	details = Label.new()
	details.add_theme_font_size_override("font_size",12)
	details.add_theme_color_override("font_color",Color("b0bdc8"))
	col.add_child(details)

func _refresh_status() -> void:
	status.text = ["GENSHIN CONCEPT / ANIMATED", "ARCLIGHT / EXISTING CHARACTER", "ASHEN WARDEN / EXISTING CHARACTER"][preview_index]
	details.text = "Local animation study. F3 reviews poses without traversal gameplay.\nThis preview does not change the multiplayer roster or Demo 1 build."

func _process(_delta: float) -> void:
	if not is_instance_valid(status):
		return
	var driver = player.get_node("CharacterAnimation")
	if gallery_index >= 0:
		status.text = "ANIMATION REVIEW / " + gallery_clips[gallery_index]
	elif preview_index == 0:
		var action: String = driver.get_action_clip()
		status.text = "GENSHIN CONCEPT / " + (action if not action.is_empty() else driver.get_locomotion_clip())

func select_preview(index: int) -> void:
	preview_index = posmod(index,3)
	var driver := player.get_node("CharacterAnimation")
	driver.set_manual_preview(false)
	gallery_index = -1
	player.external_control = test_mode
	player.get_node("AttackHitbox").external_control = test_mode
	driver.reset_presentation()
	driver.set_physics_process(false)
	player.get_node("Mesh").select_preview(preview_index)
	driver.set_physics_process(true)
	_refresh_status()

func review_animation(clip: String = "") -> void:
	var driver = player.get_node("CharacterAnimation")
	driver._locate_animation_player()
	var anim: AnimationPlayer = driver._anim
	if anim == null:
		return
	if clip.is_empty():
		gallery_clips.assign(anim.get_animation_list())
		gallery_clips.erase("RESET")
		gallery_clips.sort()
		if gallery_clips.is_empty():
			return
		gallery_index = posmod(gallery_index + 1, gallery_clips.size())
		clip = gallery_clips[gallery_index]
	else:
		gallery_clips.assign([clip])
		gallery_index = 0
	player.external_control = true
	player.velocity = Vector3.ZERO
	player.get_node("AttackHitbox").external_control = true
	driver.set_manual_preview(true)
	anim.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	anim.play(clip, .12)

func resume_play() -> void:
	var driver = player.get_node("CharacterAnimation")
	if gallery_index >= 0 and driver._anim != null:
		var clip: String = gallery_clips[gallery_index]
		driver._anim.get_animation(clip).loop_mode = Animation.LOOP_LINEAR if clip in driver.LOOPED else Animation.LOOP_NONE
	gallery_index = -1
	player.external_control = test_mode
	player.get_node("AttackHitbox").external_control = test_mode
	driver.set_manual_preview(false)

func reset_player() -> void:
	player.position = Vector3(0,1.03,4)
	player.velocity = Vector3.ZERO

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_TAB:
			select_preview(preview_index+1)
		elif event.keycode == KEY_F2:
			player.get_node("CameraPivot").rotation.y += PI
		elif event.keycode == KEY_HOME:
			reset_player()
		elif event.keycode == KEY_F3:
			review_animation()
		elif event.keycode == KEY_F4:
			resume_play()

func _capture_animation() -> void:
	player.get_node("CameraPivot").local_input_enabled = false
	player.get_node("CameraPivot").rotation.y = PI - .5
	for i in range(24):
		await get_tree().process_frame
	var folder := ProjectSettings.globalize_path("res://").path_join("../assets/characters/protagonist/genshin-concept-match").simplify_path()
	for clip in ["Idle", "Walk", "Run", "Jump", "Attack_Slash"]:
		review_animation(clip)
		var anim: AnimationPlayer = player.get_node("CharacterAnimation")._anim
		anim.pause()
		anim.seek(anim.get_animation(clip).length * .27, true)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var result := get_viewport().get_texture().get_image().save_png(folder.path_join("animation-" + clip + ".png"))
		print("ANIMATION_CAPTURE=", clip, " RESULT=", result)
	# Deterministic frames for an inline animation preview.
	var frames_folder := folder.path_join("run-frames")
	DirAccess.make_dir_recursive_absolute(frames_folder)
	review_animation("Run")
	var run_anim: AnimationPlayer = player.get_node("CharacterAnimation")._anim
	run_anim.pause()
	for frame in range(24):
		run_anim.seek(run_anim.get_animation("Run").length * frame / 24.0, true)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(frames_folder.path_join("%02d.png" % frame))
	print("RUN_FRAMES_CAPTURED=24")
	for angle in ["front", "side"]:
		player.get_node("CameraPivot").rotation.y = PI if angle == "front" else PI*.5
		for sample in range(3):
			run_anim.seek(run_anim.get_animation("Run").length * (.12 + sample*.25),true)
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(folder.path_join("style-run-%s-%d.png" % [angle,sample]))
	print("RUN_STYLE_ANGLES_CAPTURED=6")
	get_tree().quit()

func _capture() -> void:
	for i in range(24):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path("res://").path_join("../assets/characters/protagonist/genshin-concept-match/in-game-preview.png").simplify_path()
	var result := get_viewport().get_texture().get_image().save_png(path)
	print("GENSHIN_PREVIEW_CAPTURE=",result," PATH=",path)
	get_tree().quit(0 if result == OK else 1)
