extends RefCounted
## Keep imported assets intact; install rig-specific captured locomotion per instance.
const LIBRARIES := [preload("res://assets/animations/locomotion/arclight.tres"),preload("res://assets/animations/locomotion/ashen_warden.tres")]
const DIRECTIONAL := [preload("res://assets/animations/directional/arclight.tres"),preload("res://assets/animations/directional/ashen_warden.tres")]
static func install(player: AnimationPlayer, character: int) -> void:
	var source: AnimationLibrary = LIBRARIES[clampi(character,0,1)]
	var target := player.get_animation_library("")
	for name in ["Walk","Run"]:
		if target.has_animation(name): target.remove_animation(name)
		target.add_animation(name,source.get_animation(name).duplicate(true))

	var directional: AnimationLibrary = DIRECTIONAL[clampi(character,0,1)]
	for name in ["Walk_Backward","Walk_Left","Walk_Right"]:
		if target.has_animation(name): target.remove_animation(name)
		target.add_animation(name,directional.get_animation(name).duplicate(true))
