extends "res://scripts/player/character_animation.gd"
## Keep retargeted clips on the local rig; shared libraries target different skeletons.
func _configure_loop_modes() -> void:
	if not _mesh.get("use_genshin"):
		super._configure_loop_modes()
		return
	LOCAL_RESOURCES.make_local(_anim)
	for clip in _anim.get_animation_list():
		_anim.get_animation(clip).loop_mode = Animation.LOOP_LINEAR if clip in LOOPED else Animation.LOOP_NONE
	for clip in ["Walk", "Walk_Backward", "Walk_Left", "Walk_Right", "Run"]:
		if _anim.has_animation(clip):
			_anim.get_animation(clip).set_meta("nominal_speed_m_s", 3.8 if clip == "Run" else 1.2)
