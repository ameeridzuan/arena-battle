extends SceneTree
## Asset-only gate: names, skinning, dimensions, loop closure, finite moving poses.
var failures := 0
var checks := 0

func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(text)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene: PackedScene = load("res://assets/models/protagonist.glb")
	check(scene != null,"GLB loads")
	if not scene:
		quit(1)
		return
	var model := scene.instantiate()
	root.add_child(model)
	var skeletons := model.find_children("*","Skeleton3D",true,false)
	var players := model.find_children("*","AnimationPlayer",true,false)
	check(skeletons.size() == 1,"Exactly one skeleton")
	check(players.size() == 1,"Exactly one animation player")
	if skeletons.is_empty() or players.is_empty():
		quit(1)
		return
	var skeleton: Skeleton3D = skeletons[0]
	var player: AnimationPlayer = players[0]
	check(skeleton.get_bone_count() == 20,"20 bones")
	for bone in ["hips","spine","chest","neck","head","upper_arm.L","upper_arm.R","hand.L","hand.R","thigh.L","shin.R","foot.L"]:
		check(skeleton.find_bone(bone) >= 0,"Required bone " + bone)
	var meshes := model.find_children("*","MeshInstance3D",true,false)
	var skinned := 0
	for mesh: MeshInstance3D in meshes:
		if mesh.skin != null:
			skinned += 1
	check(skinned >= 100,"Skinned character pieces exported")
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/models/protagonist-animation-manifest.json"))
	var max_head := 0.0
	for item: Dictionary in manifest.clips:
		var clip: String = item.name
		check(player.has_animation(clip),"Required clip " + clip)
		if not player.has_animation(clip):
			continue
		var animation := player.get_animation(clip)
		check(animation.length > 0,"Positive duration " + clip)
		player.play(clip,0)
		player.seek(0,true)
		player.advance(0)
		var hand := skeleton.find_bone("hand.R")
		var start_hand := skeleton.get_bone_global_pose(hand).origin
		var first: Array[Transform3D] = []
		for b in skeleton.get_bone_count():
			first.append(skeleton.get_bone_pose(b))
		player.seek(animation.length*.45,true)
		player.advance(0)
		for b in skeleton.get_bone_count():
			check(skeleton.get_bone_global_pose(b).is_finite(),"Finite pose %s bone %d" % [clip,b])
		if clip.begins_with("Attack_"):
			check(start_hand.distance_to(skeleton.get_bone_global_pose(hand).origin) > .03,"Weapon hand moves " + clip)
		if bool(item.loop):
			player.seek(animation.length,true)
			player.advance(0)
			for b in skeleton.get_bone_count():
				var last := skeleton.get_bone_pose(b)
				check(first[b].origin.distance_to(last.origin) < .001,"Loop position closes %s bone %d" % [clip,b])
				check(absf(first[b].basis.get_rotation_quaternion().dot(last.basis.get_rotation_quaternion())) > .999,"Loop rotation closes %s bone %d" % [clip,b])
	player.play("Idle",0)
	player.seek(0,true)
	player.advance(0)
	max_head = skeleton.get_bone_global_pose(skeleton.find_bone("head")).origin.y
	check(max_head > 1.4 and max_head < 1.8,"Metre scale with head at ~1.6m")
	print("PROTAGONIST_ASSET_CHECKS=",checks," FAILURES=",failures)
	print("ALL_TESTS_PASS=",failures == 0)
	model.queue_free()
	quit(0 if failures == 0 else 1)
