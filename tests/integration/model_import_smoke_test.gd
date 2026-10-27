extends SceneTree
## Headless integration smoke test for the M7 character art pass.
##
## Validates BOTH authored character GLBs — Arclight (player 1) and Ashen Warden (player 2):
##   1. Each exported GLB loads and instantiates.
##   2. It carries a Skeleton3D with the expected bone count.
##   3. It carries skinned meshes and materials.
##   4. It exposes the canonical animation set, and playing an attack clip drives the skeleton.
##   5. It imports at unit scale (no unintended scaling from the Blender->Godot hand-off).
##
## Run from the project root with the Godot console binary:
##   godot --headless --path . --script res://tests/integration/model_import_smoke_test.gd
## Exit code 0 = all checks passed, 1 = at least one failed.

const MODELS := [
	{"name": "arclight", "scene": "res://assets/models/arclight.glb", "bones": 20},
	{"name": "ashen_warden", "scene": "res://assets/models/ashen_warden.glb", "bones": 26},
	{"name": "astra_yao", "scene": "res://assets/models/astra_yao.glb", "bones": 222},
	{"name": "yixuan", "scene": "res://assets/models/yixuan.glb", "bones": 207},
]
## Canonical clips both models must expose (shared by scripts/player/character_animation.gd).
const REQUIRED_ANIMS := ["Idle", "Walk", "Run", "Jump", "Attack_Slash"]
## Clip + bone used to prove the animation actually drives the skeleton.
const DRIVE_ANIM := "Attack_Slash"
const DRIVE_BONE := "hand.R"


func _init() -> void:
	_run()


func _run() -> void:
	var all_pass := true
	for spec in MODELS:
		print("--- MODEL ", spec.name, " ---")
		var ok: bool = await _validate_model(spec)
		all_pass = all_pass and ok
	print("ALL_TESTS_PASS=", all_pass)
	quit(0 if all_pass else 1)


func _validate_model(spec: Dictionary) -> bool:
	var results: Array[bool] = []

	var packed: PackedScene = load(spec.scene)
	var model_ok := packed != null
	print("CHECK model_loads = ", model_ok)
	results.append(model_ok)
	if not model_ok:
		return false

	var model: Node3D = packed.instantiate() as Node3D
	root.add_child(model)
	# Let one frame settle so global transforms are valid.
	await physics_frame

	# --- Skeleton -----------------------------------------------------------
	var skeletons := model.find_children("*", "Skeleton3D", true, false)
	var skeleton: Skeleton3D = skeletons[0] if skeletons.size() > 0 else null
	var skeleton_ok := skeleton != null
	var bone_count: int = skeleton.get_bone_count() if skeleton_ok else 0
	print("skeleton=", skeleton.name if skeleton_ok else "NONE", " bones=", bone_count)
	print("CHECK skeleton_present = ", skeleton_ok)
	results.append(skeleton_ok)
	print("CHECK bone_count_", spec.bones, " = ", bone_count == spec.bones)
	results.append(bone_count == spec.bones)

	# --- Meshes + materials -------------------------------------------------
	var meshes := model.find_children("*", "MeshInstance3D", true, false)
	var mesh_ok := meshes.size() >= 2
	print("mesh_count=", meshes.size())
	print("CHECK meshes_present = ", mesh_ok)
	results.append(mesh_ok)

	var mat_count := 0
	for m in meshes:
		var mi := m as MeshInstance3D
		if mi.mesh:
			for s in range(mi.mesh.get_surface_count()):
				if mi.mesh.surface_get_material(s) != null:
					mat_count += 1
	var materials_ok := mat_count > 0
	print("material_slots=", mat_count)
	print("CHECK materials_present = ", materials_ok)
	results.append(materials_ok)

	# --- Unit scale ---------------------------------------------------------
	var scale_ok := model.scale == Vector3.ONE
	if skeleton != null:
		scale_ok = scale_ok and skeleton.scale == Vector3.ONE
	print("model_scale=", model.scale)
	print("CHECK unit_scale = ", scale_ok)
	results.append(scale_ok)

	# --- Animations ---------------------------------------------------------
	var players := model.find_children("*", "AnimationPlayer", true, false)
	var anim_player: AnimationPlayer = players[0] if players.size() > 0 else null
	print("animation_player=", anim_player.name if anim_player else "NONE",
		" libs=", (anim_player.get_animation_list() if anim_player else []))
	for clip in REQUIRED_ANIMS:
		var has_clip := anim_player != null and anim_player.has_animation(clip)
		print("CHECK anim_", clip, " = ", has_clip)
		results.append(has_clip)

	var drives := false
	if skeleton_ok and anim_player != null and anim_player.has_animation(DRIVE_ANIM):
		var hand_idx := skeleton.find_bone(DRIVE_BONE)
		if hand_idx >= 0:
			var before := skeleton.get_bone_global_pose(hand_idx)
			anim_player.play(DRIVE_ANIM)
			# Step well into the swing so a real pose change is observable.
			for _i in range(30):
				await physics_frame
			var after := skeleton.get_bone_global_pose(hand_idx)
			var delta := (after.origin - before.origin).length()
			print("hand_delta=", delta)
			drives = delta > 0.01
	print("CHECK animation_drives_skeleton = ", drives)
	results.append(drives)

	model.queue_free()

	for r in results:
		if not r:
			return false
	return true
