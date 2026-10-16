extends Node3D
## Manual-preview helper for the imported character model (M6).
## Loops the "Attack" animation and, when run standalone (F5 on this scene),
## adds a temporary camera + sun so the owner can eyeball it.
## Presentation-only: no gameplay logic lives here.

const ANIM_NAME := "Idle"
const CAM_POS := Vector3(2.2, 1.6, -2.6)
const CAM_TARGET := Vector3(0, 1.0, 0)


func _ready() -> void:
	_start_animation()
	_ensure_preview_view()


func _start_animation() -> void:
	var players := find_children("*", "AnimationPlayer", true, false)
	if players.is_empty():
		push_warning("PlayerModelPreview: no AnimationPlayer found in imported model.")
		return
	var player: AnimationPlayer = players[0]
	if not player.has_animation(ANIM_NAME):
		push_warning("PlayerModelPreview: animation '%s' not found." % ANIM_NAME)
		return
	var anim: Animation = player.get_animation(ANIM_NAME)
	anim.loop_mode = Animation.LOOP_LINEAR
	player.play(ANIM_NAME)


func _ensure_preview_view() -> void:
	if get_viewport().get_camera_3d() != null:
		return
	var cam := Camera3D.new()
	cam.name = "PreviewCamera"
	add_child(cam)
	cam.global_position = CAM_POS
	cam.look_at(CAM_TARGET, Vector3.UP)
	var sun := DirectionalLight3D.new()
	sun.name = "PreviewSun"
	add_child(sun)
	sun.rotation_degrees = Vector3(50, 0, 30)
	sun.light_energy = 3.0
