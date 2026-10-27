extends Node3D
## Isolated asset review. Does not alter the playable roster or combat code.

var model: Node3D
var player: AnimationPlayer
var camera: Camera3D
var selector: OptionButton
var readout: Label
var scrub: HSlider
var pause_button: Button
var paused := false
var auto_cycle := true
var cycle_clock := 0.0
var speed := 1.0
var yaw := 0.22
var pitch := 0.12
var distance := 3.4
var selected_clip := "Idle"
var clips: Array[String] = []
var capture_mode := false
var capture_plan: Array = []
var capture_index := 0
var capture_wait := 0

const GROUPS := {
	"Locomotion": ["Idle", "Walk", "Run", "Walk_Backward", "Walk_Left", "Walk_Right", "RunStartCapture", "RunStopCapture", "TurnLeftCapture", "TurnRightCapture", "Jump", "FallLoop", "LandSoft", "Stair_Up", "Stair_Down"],
	"Combat": ["Attack_Slash", "Attack_Backhand", "Attack_Overhead", "Attack_Thrust", "Attack_Aerial", "CastEnergy", "Aim", "Dash_Forward", "Dodge_Backward", "Dodge_Left", "Dodge_Right", "Parry_Attempt", "Parry_Success", "BlockLeftCapture", "BlockRightCapture"],
	"Parkour": ["LedgeHang", "Shimmy_Left", "Shimmy_Right", "Climb", "Vault", "WallSlide", "WallJump", "LedgeDrop"],
	"Reactions and layers": ["HitFront", "HitBack", "HitLeft", "HitRight", "KnockbackTravel", "KnockbackRecover", "WalkAttack", "RunAttack", "StrafeAttack", "BackwardAttack", "Death"]
}

func _ready() -> void:
	_build_stage()
	model = load("res://assets/models/protagonist.glb").instantiate()
	add_child(model)
	var players := model.find_children("*", "AnimationPlayer", true, false)
	if players.is_empty():
		push_error("Protagonist GLB has no AnimationPlayer")
		return
	player = players[0]
	for clip in player.get_animation_list():
		if clip != "RESET":
			clips.append(clip)
	clips.sort()
	for clip in clips:
		player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	_build_ui()
	_select("Run")
	_update_camera()
	capture_mode = "--protagonist-capture" in OS.get_cmdline_user_args()
	if capture_mode:
		auto_cycle = false
		paused = true
		for clip in ["Idle", "Run", "Attack_Slash", "CastEnergy", "Parry_Attempt", "LedgeHang", "Climb", "WallJump"]:
			for i in range(16):
				capture_plan.append([clip, float(i) / 16.0])
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/models/protagonist_preview_frames"))
		print("CAPTURE_PLAN=", capture_plan.size())

func _build_stage() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("101b29")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("bdcee2")
	env.environment.ambient_light_energy = 0.65
	add_child(env)
	for i in range(3):
		var light := DirectionalLight3D.new()
		light.rotation_degrees = [Vector3(-50,-35,0), Vector3(-25,130,0),Vector3(-40,35,0)][i]
		light.light_energy = [1.1,0.9,0.35][i]
		light.light_color = [Color("e5efff"),Color("67dfe5"),Color("bbcaff")][i]
		add_child(light)
	var floor := MeshInstance3D.new()
	var disk := CylinderMesh.new()
	disk.top_radius = 1.18
	disk.bottom_radius = 1.22
	disk.height = 0.045
	disk.radial_segments = 96
	floor.mesh = disk
	floor.position.y = -0.028
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("26394b")
	mat.roughness = 0.65
	floor.material_override = mat
	add_child(floor)
	camera = Camera3D.new()
	add_child(camera)
	camera.current = true
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.5

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(20,20)
	panel.custom_minimum_size = Vector2(335,0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035,0.065,0.1,0.94)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	panel.add_theme_stylebox_override("panel",style)
	layer.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation",10)
	panel.add_child(col)
	var title := Label.new()
	title.text = "PROTAGONIST / MOTION STUDIO"
	title.add_theme_font_size_override("font_size",19)
	col.add_child(title)
	var note := Label.new()
	note.text = "%d clips · 20 bone rig\nOriginal anime character / first 3D pass" % clips.size()
	note.add_theme_color_override("font_color",Color("8aa5ba"))
	col.add_child(note)
	selector = OptionButton.new()
	for clip in clips:
		selector.add_item(clip)
	selector.item_selected.connect(func(index: int): auto_cycle = false; _select(clips[index]))
	col.add_child(selector)
	var group_select := OptionButton.new()
	group_select.add_item("Jump to a move category…")
	for category in GROUPS:
		group_select.add_item(category)
	group_select.item_selected.connect(func(index: int):
		if index > 0:
			auto_cycle = false
			_select(GROUPS[GROUPS.keys()[index-1]][0]))
	col.add_child(group_select)
	var row := HBoxContainer.new()
	col.add_child(row)
	pause_button = Button.new()
	pause_button.text = "Pause"
	pause_button.pressed.connect(func(): paused = not paused; pause_button.text = "Play" if paused else "Pause")
	row.add_child(pause_button)
	var previous := Button.new()
	previous.text = "Previous"
	previous.pressed.connect(func(): _step_clip(-1))
	row.add_child(previous)
	var next := Button.new()
	next.text = "Next"
	next.pressed.connect(func(): _step_clip(1))
	row.add_child(next)
	var auto := CheckButton.new()
	auto.text = "Auto tour / 3 seconds per clip"
	auto.button_pressed = true
	auto.toggled.connect(func(value: bool): auto_cycle = value; cycle_clock = 0)
	col.add_child(auto)
	var speed_select := OptionButton.new()
	for text in ["0.25× slow motion", "0.5× speed", "1× speed", "1.5× speed"]:
		speed_select.add_item(text)
	speed_select.select(2)
	speed_select.item_selected.connect(func(index: int): speed = [0.25,0.5,1.0,1.5][index])
	col.add_child(speed_select)
	scrub = HSlider.new()
	scrub.min_value = 0
	scrub.max_value = 1
	scrub.step = .001
	scrub.value_changed.connect(func(value: float):
		if player and player.current_animation != "":
			player.seek(value*player.current_animation_length,true))
	col.add_child(scrub)
	readout = Label.new()
	readout.add_theme_color_override("font_color",Color("76e1df"))
	col.add_child(readout)
	var help := Label.new()
	help.text = "Drag outside panel: orbit · Wheel: zoom\nSpace: pause · Left/Right: previous/next\nIn-place motion studies; game physics owns travel.\nParkour poses need game contact IK for live use."
	help.add_theme_font_size_override("font_size",12)
	help.add_theme_color_override("font_color",Color("8aa5ba"))
	col.add_child(help)

func _select(clip: String) -> void:
	if not player.has_animation(clip):
		return
	selected_clip = clip
	selector.select(clips.find(clip))
	player.play(clip,0)
	player.advance(0)
	cycle_clock = 0

func _step_clip(step: int) -> void:
	auto_cycle = false
	_select(clips[posmod(clips.find(selected_clip)+step,clips.size())])

func _update_camera() -> void:
	var target := Vector3(-.20,1.02,0)
	camera.position = Vector3(sin(yaw)*distance,1.45+pitch*distance,cos(yaw)*distance)
	camera.look_at(target)
	camera.size = distance * .72
	# Shift the character into the unobscured right portion of the window.
	camera.h_offset = -.34

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		yaw -= event.relative.x*.009
		pitch = clampf(pitch+event.relative.y*.004,-.25,.7)
		_update_camera()
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance = maxf(1.5,distance-.15)
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance = minf(6,distance+.15)
		_update_camera()
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_SPACE:
			paused = not paused
		if event.keycode == KEY_RIGHT:
			_step_clip(1)
		if event.keycode == KEY_LEFT:
			_step_clip(-1)

func _process(delta: float) -> void:
	if not player:
		return
	player.speed_scale = 0 if paused else speed
	if not player.current_animation.is_empty():
		var length := player.current_animation_length
		scrub.set_value_no_signal(player.current_animation_position/maxf(length,.001))
		readout.text = "%s\n%.2f / %.2f s" % [selected_clip,player.current_animation_position,length]
	if auto_cycle and not paused:
		cycle_clock += delta
		if cycle_clock > 3:
			_select(clips[posmod(clips.find(selected_clip)+1,clips.size())])
	if capture_mode:
		_capture_tick()

func _capture_tick() -> void:
	if capture_index >= capture_plan.size():
		print("PROTAGONIST_CAPTURE_DONE=",capture_index)
		get_tree().quit()
		return
	if capture_wait == 0:
		var item: Array = capture_plan[capture_index]
		_select(item[0])
		player.seek(float(item[1])*player.current_animation_length,true)
		capture_wait = 3
	else:
		capture_wait -= 1
		if capture_wait == 0:
			var image := get_viewport().get_texture().get_image()
			image.save_png("res://assets/models/protagonist_preview_frames/frame_%04d.png" % capture_index)
			capture_index += 1
