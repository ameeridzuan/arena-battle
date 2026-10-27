extends Node3D
## Standalone local movement laboratory. All dimensions are metres.
const SPAWNS := [Vector3(0, 1.05, 20), Vector3(-17, 1.05, 12), Vector3(16, 1.05, 12), Vector3(-20, 1.05, -5), Vector3(0, 1.05, -15), Vector3(21, 1.05, -9)]
const ZONES := ["Orientation", "Free movement", "Jump gaps", "Steps and slopes", "Ledge climb", "Wall slide / wall jump"]
const INK := Color(0.13, 0.18, 0.24)
const CYAN := Color(0.12, 0.72, 0.82)
const AMBER := Color(0.95, 0.58, 0.19)
@onready var player: CharacterBody3D = $Player
var checkpoint := 0
var telemetry: Label
var _materials: Dictionary = {}

func _ready() -> void:
	_build_world()
	_build_ui()
	for index in SPAWNS.size():
		var action := "course_zone_%d" % index
		_bind(action, KEY_1 + index)
	_bind("course_reset", KEY_BACKSPACE)

func _bind(action: StringName, key: int) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	var event := InputEventKey.new()
	event.physical_keycode = key
	InputMap.action_add_event(action, event)

func _physics_process(_delta: float) -> void:
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		for index in SPAWNS.size():
			if Input.is_action_just_pressed("course_zone_%d" % index):
				reset_player(index)
		if Input.is_action_just_pressed("course_reset"):
			reset_player(checkpoint)
	if player.position.y < -8.0 or absf(player.position.x) > 36.0 or absf(player.position.z) > 34.0:
		reset_player(checkpoint)
	_update_camera()
	telemetry.text = "%s\nSpeed %.2f m/s | Vertical %+.2f m/s\nFeet %.2f m | %s" % [ZONES[checkpoint], Vector2(player.velocity.x, player.velocity.z).length(), player.velocity.y, player.position.y - 1.0, "GROUNDED" if player.is_motion_grounded() else "AIRBORNE"]
	telemetry.text += "\n%s | %s" % [player.get_traversal_mode().to_upper(), player.traversal_motor.notice]

func reset_player(index: int) -> void:
	checkpoint = clampi(index, 0, SPAWNS.size() - 1)
	player.get_node("MotionTestControls").cancel_motion()
	player.get_node("CharacterAnimation").reset_presentation()
	player.reset_traversal()
	player.position = SPAWNS[checkpoint]
	player.velocity = Vector3.ZERO
	player.get_node("CameraPivot").rotation.y = 0.0

func _update_camera() -> void:
	# Keep the original camera path for the cast harness, but shorten its boom at walls.
	var tilt: Node3D = player.get_node("CameraPivot/CameraTilt")
	var camera: Camera3D = tilt.get_node("Camera3D")
	var start := tilt.to_global(Vector3(0, 1.2, 0))
	var desired := tilt.to_global(Vector3(0, 1.2, 4))
	var query := PhysicsRayQueryParameters3D.create(start, desired, 1, [player.get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	camera.global_position = desired if hit.is_empty() else hit.position + hit.normal * 0.25

func _material(color: Color) -> StandardMaterial3D:
	if not _materials.has(color):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = 0.85
		_materials[color] = material
	return _materials[color]

func _box(title: String, size: Vector3, center: Vector3, color: Color, solid: bool = true) -> Node3D:
	var body: Node3D = StaticBody3D.new() if solid else Node3D.new()
	body.name = title
	body.position = center
	add_child(body)
	if solid:
		body.collision_layer = 1
		body.collision_mask = 2
		var shape := BoxShape3D.new()
		shape.size = size
		var collision := CollisionShape3D.new()
		collision.shape = shape
		body.add_child(collision)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = _material(color)
	body.add_child(mesh)
	return body

func _sign(text: String, at: Vector3, color: Color = Color.WHITE) -> void:
	var label := Label3D.new()
	label.text = text
	label.position = at
	label.font_size = 48
	label.pixel_size = 0.008
	label.modulate = color
	label.outline_size = 8
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)

func _build_world() -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.08, 0.12, 0.18)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.7, 0.8, 1.0)
	environment.ambient_light_energy = 0.65
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -25, 0)
	sun.light_energy = 1.4
	sun.shadow_enabled = true
	add_child(sun)
	_box("RecoveryFloor", Vector3(64, 1, 60), Vector3(0, -0.5, 0), INK)
	# Thin painted grid and lane boundaries never obstruct movement.
	for x in range(-30, 31, 2):
		_box("GridX", Vector3(0.025, 0.008, 60), Vector3(x, 0.005, 0), Color(0.22, 0.28, 0.34), false)
	for z in range(-28, 29, 2):
		_box("GridZ", Vector3(64, 0.008, 0.025), Vector3(0, 0.005, z), Color(0.22, 0.28, 0.34), false)
	for x in [-32.0, 32.0]:
		_box("Boundary", Vector3(0.4, 1.0, 60), Vector3(x, 0.5, 0), INK.lightened(0.1))
	for z in [-30.0, 30.0]:
		_box("Boundary", Vector3(64, 1.0, 0.4), Vector3(0, 0.5, z), INK.lightened(0.1))
	_sign("MOTION LAB\n1-6: select zone / Backspace: reset", Vector3(0, 3, 24), CYAN)
	_sign("02 / FREE MOVEMENT\nTurn / strafe / dash / dodge", Vector3(-18, 2.5, 3), CYAN)
	# A 16 m marked runway, with room around it for all directional actions.
	for z in range(4, 21, 2):
		_box("RunwayMark", Vector3(7, 0.012, 0.08), Vector3(-18, 0.012, z), CYAN, false)
	_sign("03 / JUMP GAPS\n0.75 / 1.50 / 2.25 m", Vector3(19, 3, 1), CYAN)
	var edge := 10.0
	for i in 4:
		var width := 3.0
		_box("JumpPlatform%d" % i, Vector3(width, 0.65, 5), Vector3(edge + width / 2, 0.325, 5), CYAN.darkened(0.3))
		if i < 3:
			var gap := 0.75 * (i + 1)
			_sign("%.2f m" % gap, Vector3(edge + width + gap / 2, 1.1, 7.8), CYAN)
			edge += width + gap
	_sign("04 / ADAPTIVE STAIRS\n15 / 30 / 40 cm risers", Vector3(-23, 4, -17), CYAN)
	for lane in 3:
		var riser: float = [0.15, 0.3, 0.4][lane]
		var x := -28.0 + lane * 5.0
		for i in 6:
			var height := (i + 1) * riser
			var step := _box("Stair%dStep%d" % [lane, i], Vector3(3.0, height, 1.2), Vector3(x, height / 2, -7 - i * 1.2), CYAN.darkened(0.3))
			step.set_meta("riser_height_m", riser)
		_sign("%d cm / walk + run" % int(riser * 100), Vector3(x, 1.2, -5.8), CYAN)
	for i in 2:
		var angle := 15.0 if i == 0 else 30.0
		var rise := sin(deg_to_rad(angle)) * 6.0
		var ramp := _box("Ramp%d" % i, Vector3(3, 0.3, 6), Vector3(-11 + i * 5, rise / 2 + 0.15, -10), CYAN.darkened(0.2))
		ramp.rotation_degrees.x = angle
		_sign("%d deg" % int(angle), Vector3(-11 + i * 5, 2.5, -6), CYAN)
	_sign("05 / LEDGE LAB\nE: grab / climb; A/D: shimmy; C: drop", Vector3(0, 5, -25), AMBER)
	for i in 5:
		var height := [0.6, 1.2, 1.8, 2.4, 3.2][i] as float
		var x := -9.0 + i * 4.5
		var ledge := _box("Ledge%d" % i, Vector3(3.5, height, 4), Vector3(x, height / 2, -22), AMBER.darkened(0.35))
		ledge.add_to_group("motion_test_ledge")
		ledge.set_meta("ledge_height_m", height)
		_box("LedgeLip", Vector3(3.5, 0.04, 0.12), Vector3(x, height + 0.02, -19.95), AMBER, false)
		_sign("%.1f m" % height, Vector3(x, height + 0.6, -20), AMBER)
	_sign("06 / WALL JUMP LAB\nHold into wall + Space / 1.5, 2.5, 4 m", Vector3(22, 7, -22), AMBER)
	for i in 3:
		var center := 14.0 + i * 6.0
		var gap := [1.5, 2.5, 4.0][i] as float
		for side in [-1, 1]:
			var wall := _box("WallLane%dSide%d" % [i, side], Vector3(0.5, 6, 10), Vector3(center + side * (gap / 2 + 0.25), 3, -16), AMBER.darkened(0.4))
			wall.add_to_group("motion_test_wall")
			wall.set_meta("lane_clearance_m", gap)
		_sign("%.1f m" % gap, Vector3(center, 1, -10), AMBER)
	for index in SPAWNS.size():
		_box("ZonePad%d" % index, Vector3(2, 0.015, 2), SPAWNS[index] - Vector3(0, 1.035, 0), CYAN if index < 4 else AMBER, false)

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var help := Label.new()
	help.position = Vector2(16, 16)
	help.text = "MOTION LAB | 1: hub  2: movement  3: jumps  4: slopes  5: ledges  6: walls\nWASD move / Shift run / Space jump / Mouse look / Esc cursor\nLeft click: swing | Space then left click: jump attack\nQ + WASD dash/dodge / V aim / R cast / F parry / Tab character\nE: grab/climb | A/D in hang: shimmy | Space: climb / wall jump | C: drop"
	help.add_theme_color_override("font_shadow_color", Color.BLACK)
	help.add_theme_constant_override("shadow_offset_x", 2)
	help.add_theme_constant_override("shadow_offset_y", 2)
	layer.add_child(help)
	telemetry = Label.new()
	telemetry.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	telemetry.position = Vector2(16, -125)
	telemetry.add_theme_color_override("font_color", CYAN.lightened(0.4))
	telemetry.add_theme_color_override("font_shadow_color", Color.BLACK)
	telemetry.add_theme_constant_override("shadow_offset_x", 2)
	telemetry.add_theme_constant_override("shadow_offset_y", 2)
	layer.add_child(telemetry)
