extends SceneTree
## Rebuild editable, rig-specific review libraries. Does not modify imported GLBs.
const SPECS := {
	"FallLoop": [0.8, true, "fall"],
	"LandSoft": [0.42, false, "land"],
	"HitFront": [0.42, false, "front"],
	"HitBack": [0.42, false, "back"],
	"HitLeft": [0.42, false, "left"],
	"HitRight": [0.42, false, "right"],
	"KnockbackTravel": [0.6, true, "travel"],
	"KnockbackRecover": [0.7, false, "recover"],
}
func _initialize() -> void:
	call_deferred("build")
func offset(bone: String, pose: String) -> Vector3:
	var lean := 0.0
	var side := 0.0
	match pose:
		"front", "travel", "recover": lean = -22.0
		"back": lean = 22.0
		"left": side = -22.0
		"right": side = 22.0
		"land": lean = 15.0
		"fall": lean = -8.0
	if bone == "spine": return Vector3(lean, 0, side)
	if bone == "chest": return Vector3(lean * 0.45, 0, side * 0.35)
	if bone == "head": return Vector3(-lean * 0.35, 0, -side * 0.2)
	if bone.begins_with("upper_arm"):
		return Vector3(-15, 0, 12 if bone.ends_with(".L") else -12)
	if bone.begins_with("forearm"): return Vector3(-20, 0, 0)
	if pose in ["fall", "land", "travel", "recover"]:
		if bone.begins_with("thigh"): return Vector3(-25 if pose == "land" else -14, 0, 0)
		if bone.begins_with("shin"): return Vector3(42 if pose == "land" else 24, 0, 0)
		if bone.begins_with("foot"): return Vector3(-17 if pose == "land" else -10, 0, 0)
	return Vector3.ZERO
func build() -> void:
	DirAccess.make_dir_recursive_absolute("res://assets/animations/review")
	for model_name in ["arclight", "ashen_warden"]:
		var model = load("res://assets/models/"+model_name+".glb").instantiate()
		root.add_child(model)
		var player: AnimationPlayer = model.find_children("*", "AnimationPlayer", true, false)[0]
		var skeleton: Skeleton3D = model.find_children("*", "Skeleton3D", true, false)[0]
		player.play("Idle")
		player.seek(0, true)
		player.pause()
		var skeleton_path := player.get_node(player.root_node).get_path_to(skeleton)
		var library := AnimationLibrary.new()
		for clip_name in SPECS:
			var spec: Array = SPECS[clip_name]
			var clip := Animation.new()
			clip.length = spec[0] * (1.15 if model_name == "ashen_warden" else 1.0)
			clip.loop_mode = Animation.LOOP_LINEAR if spec[1] else Animation.LOOP_NONE
			var times := [0.0, 0.16, 0.42, 1.0]
			var weights := [0.0, 1.0, 0.65, 0.0]
			if spec[1]: weights = [1.0, 1.02, 0.98, 1.0]
			if spec[2] == "recover": weights = [1.0, 0.8, 0.35, 0.0]
			for i in skeleton.get_bone_count():
				var bone := skeleton.get_bone_name(i)
				var path := NodePath(str(skeleton_path)+":"+bone)
				var track := clip.add_track(Animation.TYPE_ROTATION_3D)
				clip.track_set_path(track,path)
				var base := skeleton.get_bone_pose_rotation(i)
				var angles := offset(bone,spec[2]) * (0.85 if model_name == "ashen_warden" else 1.0)
				for k in times.size():
					var delta := Quaternion.from_euler(angles * (PI / 180.0) * weights[k])
					clip.rotation_track_insert_key(track,times[k]*clip.length,(base*delta).normalized())
				# Explicit baseline translations/scales prevent stale pose values from prior clips.
				track = clip.add_track(Animation.TYPE_POSITION_3D)
				clip.track_set_path(track,path)
				clip.position_track_insert_key(track,0,skeleton.get_bone_pose_position(i))
				track = clip.add_track(Animation.TYPE_SCALE_3D)
				clip.track_set_path(track,path)
				clip.scale_track_insert_key(track,0,skeleton.get_bone_pose_scale(i))
			library.add_animation(clip_name,clip)
		var error := ResourceSaver.save(library,"res://assets/animations/review/"+model_name+".tres")
		if error != OK:
			quit(1)
			return
		print("BUILT ",model_name," clips=",library.get_animation_list())
		model.free()
	quit()
