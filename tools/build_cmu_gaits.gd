extends SceneTree
## Reproducible positional retarget of CMU joint trajectories to the existing rigs.
const MAP := {
	"spine": ["Spine","Spine1"], "chest": ["Spine1","Neck1"],
	"neck": ["Neck1","Head"], "head": ["Head","Head_end"],
	"upper_arm.L": ["LeftArm","LeftForeArm"], "forearm.L": ["LeftForeArm","LeftHand"],
	"upper_arm.R": ["RightArm","RightForeArm"], "forearm.R": ["RightForeArm","RightHand"],
	"thigh.L": ["LeftUpLeg","LeftLeg"], "shin.L": ["LeftLeg","LeftFoot"],
	"thigh.R": ["RightUpLeg","RightLeg"], "shin.R": ["RightLeg","RightFoot"]}
func v(frame: Dictionary, joint: String) -> Vector3:
	var a: Array = frame[joint]
	return Vector3(a[0],a[1],a[2])
func _initialize() -> void:
	call_deferred("build")
func body_frame(right: Vector3, up: Vector3) -> Basis:
	var y := up.normalized()
	var z := right.cross(y).normalized()
	return Basis(y.cross(z).normalized(),y,z)
func build() -> void:
	DirAccess.make_dir_recursive_absolute("res://assets/animations/locomotion")
	var manifest: Dictionary = {}
	for model_name in ["arclight","ashen_warden"]:
		var model = load("res://assets/models/"+model_name+".glb").instantiate()
		root.add_child(model)
		var player: AnimationPlayer = model.find_children("*","AnimationPlayer",true,false)[0]
		var skeleton: Skeleton3D = model.find_children("*","Skeleton3D",true,false)[0]
		var path := player.get_node(player.root_node).get_path_to(skeleton)
		var library := AnimationLibrary.new()
		var leg_length := skeleton.get_bone_rest(skeleton.find_bone("shin.L")).origin.length()+skeleton.get_bone_rest(skeleton.find_bone("foot.L")).origin.length()
		manifest[model_name] = {}
		for clip_name in ["Walk","Run","JumpCapture","StrafeCapture"]:
			var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/animations/source/"+clip_name+"-cmu.json"))
			var frames: Array = source.frames
			var scale_factor: float = leg_length / float(source.source_leg_length)
			var looping: bool = clip_name in ["Walk","Run"]
			var floor_height := INF
			for frame: Dictionary in frames:
				floor_height = minf(floor_height,minf(v(frame,"LeftFoot").y,v(frame,"RightFoot").y))
			var sampled: Array = []
			# Keep original 120 Hz sampling during retargeting; export at roughly 30 Hz.
			var indices: Array[int] = []
			for index in range(0,frames.size()-1,4): indices.append(index)
			indices.append(frames.size()-1)
			for index in indices:
				var frame: Dictionary = frames[index]
				var global_poses: Array[Transform3D] = []
				var local_poses: Array[Transform3D] = []
				for i in skeleton.get_bone_count():
					var name := skeleton.get_bone_name(i)
					var rest := skeleton.get_bone_global_rest(i)
					var parent := skeleton.get_bone_parent(i)
					var basis := rest.basis
					if name == "hips":
						basis = body_frame(v(frame,"LeftUpLeg")-v(frame,"RightUpLeg"),v(frame,"Spine")-v(frame,"Hips"))*rest.basis
					elif MAP.has(name):
						var pair: Array = MAP[name]
						var direction := (v(frame,pair[1])-v(frame,pair[0])).normalized()
						basis = Basis(Quaternion(rest.basis.y.normalized(),direction))*rest.basis
					elif name.begins_with("foot"):
						var side := "Left" if name.ends_with(".L") else "Right"
						var direction := (v(frame,side+"ToeBase")-v(frame,side+"Foot")).normalized()
						# Remove the actor skeleton's ankle-to-toe rest slope; retain animated roll.
						direction.y += 0.22
						basis = Basis(Quaternion(Vector3.BACK,direction.normalized()))*rest.basis
					elif parent >= 0:
						basis = global_poses[parent].basis*skeleton.get_bone_rest(i).basis
					var origin := rest.origin
					if parent >= 0: origin = global_poses[parent]*skeleton.get_bone_rest(i).origin
					if name == "hips":
						origin.x += v(frame,"Hips").x*scale_factor
						origin.z += v(frame,"Hips").z*scale_factor
					global_poses.append(Transform3D(basis.orthonormalized(),origin))
				# Preserve capture flight/ground height and align the lowest ankle to the rig.
				var left := skeleton.find_bone("foot.L")
				var right := skeleton.find_bone("foot.R")
				var ankle_base := skeleton.get_bone_global_rest(left).origin.y
				var desired_y := ankle_base+(minf(v(frame,"LeftFoot").y,v(frame,"RightFoot").y)-floor_height)*scale_factor
				var correction := desired_y-minf(global_poses[left].origin.y,global_poses[right].origin.y)
				var hips := skeleton.find_bone("hips")
				for i in skeleton.get_bone_count():
					var ancestor := i
					while ancestor >= 0 and ancestor != hips: ancestor = skeleton.get_bone_parent(ancestor)
					if ancestor == hips: global_poses[i].origin.y += correction
				for i in skeleton.get_bone_count():
					var parent := skeleton.get_bone_parent(i)
					local_poses.append(global_poses[parent].affine_inverse()*global_poses[i] if parent>=0 else global_poses[i])
				sampled.append(local_poses)
			# Close the cycle smoothly over the final 15%; keep contact ordering from capture.
			if looping:
				var last: Array = sampled[-1]
				var first: Array = sampled[0]
				for k in sampled.size():
					var weight := smoothstep(0.85,1.0,float(k)/float(sampled.size()-1))
					for bone in skeleton.get_bone_count():
						var pose: Transform3D = sampled[k][bone]
						var delta: Quaternion = last[bone].basis.get_rotation_quaternion().inverse()*first[bone].basis.get_rotation_quaternion()
						pose.basis = Basis(pose.basis.get_rotation_quaternion()*Quaternion.IDENTITY.slerp(delta,weight))
						pose.origin += (first[bone].origin-last[bone].origin)*weight
						sampled[k][bone] = pose
			var clip := Animation.new()
			clip.length = source.duration
			clip.loop_mode = Animation.LOOP_LINEAR if looping else Animation.LOOP_NONE
			clip.set_meta("source_capture",source.source)
			clip.set_meta("nominal_speed_m_s",float(source.source_speed_units)*scale_factor)
			for bone in skeleton.get_bone_count():
				var track := clip.add_track(Animation.TYPE_ROTATION_3D)
				clip.track_set_path(track,NodePath(str(path)+":"+skeleton.get_bone_name(bone)))
				for k in sampled.size():
					clip.rotation_track_insert_key(track,float(indices[k])*float(source.dt),sampled[k][bone].basis.get_rotation_quaternion().normalized())
				track = clip.add_track(Animation.TYPE_POSITION_3D)
				clip.track_set_path(track,NodePath(str(path)+":"+skeleton.get_bone_name(bone)))
				for k in sampled.size():clip.position_track_insert_key(track,float(indices[k])*float(source.dt),sampled[k][bone].origin)
			library.add_animation(clip_name,clip)
			manifest[model_name][clip_name] = {"duration":clip.length,"nominal_speed_m_s":clip.get_meta("nominal_speed_m_s"),"source":source.source,"source_start":source.start_frame_without_tpose,"source_end":source.end_frame_without_tpose}
		var error := ResourceSaver.save(library,"res://assets/animations/locomotion/"+model_name+".tres")
		if error != OK:
			quit(1)
			return
		model.free()
	FileAccess.open("res://assets/animations/locomotion/manifest.json",FileAccess.WRITE).store_string(JSON.stringify(manifest,"\t"))
	print("CMU_GAITS_BUILT ",manifest)
	quit()
