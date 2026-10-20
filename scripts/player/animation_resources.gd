extends RefCounted
## Imported animations are shared assets. Give each player its own editable clips.
static func make_local(player: AnimationPlayer) -> void:
	for library_name in player.get_animation_library_list():
		var source := player.get_animation_library(library_name)
		var local := AnimationLibrary.new()
		for clip in source.get_animation_list():
			local.add_animation(clip, source.get_animation(clip).duplicate(true) as Animation)
		player.remove_animation_library(library_name)
		player.add_animation_library(library_name, local)
