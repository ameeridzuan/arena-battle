extends RefCounted
## Rig-local polearm windup, sweeping reap, reverse hook and airborne cleave.
static func install(player: AnimationPlayer) -> void:
	if player.has_animation_library("Skills"): return
	var library := AnimationLibrary.new()
	for name in ["Scythe_Reap","Scythe_Return","Scythe_Cleave","Grenade_Throw"]:
		var source := "Attack_Overhead" if name == "Scythe_Cleave" else ("Attack_Thrust" if name == "Grenade_Throw" else ("Attack_Backhand" if name == "Scythe_Return" else "Attack_Slash"))
		if not player.has_animation(source): continue
		var clip: Animation = player.get_animation(source).duplicate(true)
		var old_length := clip.length
		clip.length = .65 if name == "Grenade_Throw" else (1.05 if name == "Scythe_Cleave" else .85)
		clip.loop_mode = Animation.LOOP_NONE
		for track in clip.get_track_count():
			var order: Array = range(clip.track_get_key_count(track))
			if clip.length > old_length: order.reverse()
			for key in order:
				clip.track_set_key_time(track,key,clip.track_get_key_time(track,key)*clip.length/maxf(old_length,.001))
			if clip.track_get_type(track) != Animation.TYPE_ROTATION_3D: continue
			var bone := String(clip.track_get_path(track)).get_slice(":",1)
			if bone not in ["spine","chest","upper_arm.R","upper_arm.L","forearm.R","forearm.L"]: continue
			for key in clip.track_get_key_count(track):
				var phase := clip.track_get_key_time(track,key)/clip.length
				var sweep := sin(phase*TAU-PI*.5)
				var weight := sin(phase*PI)
				var sign := -1.0 if name == "Scythe_Return" else 1.0
				var delta := Quaternion.IDENTITY
				if name.begins_with("Scythe"):
					if bone in ["spine","chest"]: delta = Quaternion(Vector3.UP,sign*sweep*.18*weight)
					elif bone == "upper_arm.R": delta = Quaternion(Vector3.UP,sign*sweep*.16*weight)*Quaternion(Vector3.FORWARD,-.1*weight)
					elif bone == "upper_arm.L": delta = Quaternion(Vector3.RIGHT,-.35*weight)
					elif bone == "forearm.R": delta = Quaternion(Vector3.RIGHT,.1*weight)
					elif bone == "forearm.L": delta = Quaternion(Vector3.RIGHT,-.5*weight)
				elif bone == "upper_arm.R": delta = Quaternion(Vector3.RIGHT,-.45*weight)
				var q: Quaternion = clip.track_get_key_value(track,key)
				clip.track_set_key_value(track,key,(delta*q).normalized())
		library.add_animation(name,clip)
	player.add_animation_library("Skills",library)
