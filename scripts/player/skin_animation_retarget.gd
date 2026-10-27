extends RefCounted
## Fit shared motion curves to each skin's proportions and actual skeleton path.
## Astra's imported base clips are already fitted; Yixuan copies/fits the full Astra motion set.
static func copy_base_clips(player: AnimationPlayer, source_scene: PackedScene) -> void:
	var reference := source_scene.instantiate()
	var source: AnimationPlayer = reference.find_children("*", "AnimationPlayer", true, false)[0]
	for library_name in player.get_animation_library_list():
		player.remove_animation_library(library_name)
	for library_name in source.get_animation_library_list():
		player.add_animation_library(library_name, source.get_animation_library(library_name))
	reference.free()

static func fit_shared_libraries(player: AnimationPlayer, source_scene: PackedScene, all_clips: bool = false) -> void:
	var reference := source_scene.instantiate()
	var source: Skeleton3D = reference.find_children("*", "Skeleton3D", true, false)[0]
	var target: Skeleton3D = player.get_node(player.root_node).find_children("*", "Skeleton3D", true, false)[0]
	var target_path := String(player.get_node(player.root_node).get_path_to(target))
	for library_name in player.get_animation_library_list():
		var library := player.get_animation_library(library_name)
		for clip in library.get_animation_list():
			if not all_clips and library_name != "Actions" and clip not in ["Walk", "Run", "Walk_Backward", "Walk_Left", "Walk_Right"]:
				continue
			var animation := library.get_animation(clip)
			for track in animation.get_track_count():
				var path := animation.track_get_path(track)
				if path.get_subname_count() != 1:
					continue
				var bone_name := path.get_subname(0)
				var src := source.find_bone(bone_name)
				var dst := target.find_bone(bone_name)
				if src < 0 or dst < 0:
					continue
				animation.track_set_path(track, NodePath(target_path + ":" + bone_name))
				if animation.track_get_type(track) != Animation.TYPE_POSITION_3D:
					continue
				var offset := target.get_bone_rest(dst).origin - source.get_bone_rest(src).origin
				for key in animation.track_get_key_count(track):
					var value: Vector3 = animation.track_get_key_value(track, key)
					animation.track_set_key_value(track, key, value + offset)
	reference.free()
