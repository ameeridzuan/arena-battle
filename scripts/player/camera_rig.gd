extends Node3D
## Milestone 1 — third-person mouse-look camera rig.
##
## Attached to "CameraPivot". Yaw rotates this pivot; pitch rotates the child "CameraTilt"
## so the camera orbits the player vertically. The pivot has NO pitch, which keeps
## camera-relative movement in player_controller.gd stable (it reads pivot yaw only).
##
## Esc toggles mouse capture so the cursor can be released/re-captured.

@export var local_input_enabled: bool = true

@export var look_sensitivity_deg: float = 0.15  # degrees of rotation per pixel of mouse motion
@export var pitch_min_deg: float = -55.0         # look-down limit
@export var pitch_max_deg: float = 60.0          # look-up limit

@onready var _camera_tilt: Node3D = $CameraTilt

var _pitch_deg: float = 0.0


func _ready() -> void:
	if local_input_enabled:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if not local_input_enabled:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotation_degrees.y -= event.relative.x * look_sensitivity_deg
		_pitch_deg = clampf(
			_pitch_deg - event.relative.y * look_sensitivity_deg, pitch_min_deg, pitch_max_deg
		)
		_camera_tilt.rotation_degrees.x = _pitch_deg
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_toggle_mouse_mode()


func _toggle_mouse_mode() -> void:
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
