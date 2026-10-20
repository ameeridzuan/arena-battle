extends SceneTree
var count := 0
var failed := 0
func check(ok: bool, label: String) -> void:
	count += 1
	if not ok:
		failed += 1
		printerr("FAIL ",label)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var gallery = load("res://scenes/characters/AnimationReviewGallery.tscn").instantiate()
	root.add_child(gallery)
	gallery.set_process(false)
	gallery._set_paused(true)
	for body in gallery.bodies:
		var player: AnimationPlayer = body.get_node("CharacterAnimation")._anim
		var skeleton: Skeleton3D = body.find_children("*","Skeleton3D",true,false)[0]
		var origin: Transform3D = body.transform
		var library := player.get_animation_library("Review")
		check(library.get_animation_list().size() == 8,"eight drafts available")
		for name in library.get_animation_list():
			var clip := library.get_animation(name)
			var paths_ok := true
			var translation_ok := true
			for track in clip.get_track_count():
				var path := clip.track_get_path(track)
				paths_ok = paths_ok and player.get_node(player.root_node).get_node_or_null(NodePath(path.get_concatenated_names())) == skeleton and skeleton.find_bone(path.get_subname(0)) >= 0
				if clip.track_get_type(track) == Animation.TYPE_POSITION_3D:
					translation_ok = translation_ok and clip.track_get_key_count(track) == 1
			check(paths_ok,name+" targets this rig")
			check(translation_ok,name+" has no translation motion")
			player.play("Idle",0)
			player.seek(0,true)
			var spine := skeleton.find_bone("spine")
			var neutral := skeleton.get_bone_pose_rotation(spine)
			player.play("Review/"+name,0)
			player.seek(clip.length*0.16,true)
			check(neutral.angle_to(skeleton.get_bone_pose_rotation(spine)) > 0.03,name+" changes visible spine pose")
			var finite := true
			for i in skeleton.get_bone_count():
				finite = finite and skeleton.get_bone_pose_rotation(i).is_finite()
			check(finite and body.transform.is_equal_approx(origin),name+" finite and body stationary")
			player.seek(0,true)
			var start := skeleton.get_bone_pose_rotation(spine)
			player.seek(clip.length,true)
			var end := skeleton.get_bone_pose_rotation(spine)
			check(end.angle_to(start if clip.loop_mode == Animation.LOOP_LINEAR else neutral) < 0.002,name+" seam or neutral recovery")
		check(body.get_node("Health").get_health() == 100,"preview health unchanged")
	gallery.free()
	print("REACTION_CHECKS=",count," FAILURES=",failed," ALL_TESTS_PASS=",failed==0)
	quit(0 if failed==0 else 1)
