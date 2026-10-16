extends SceneTree
## Headless integration smoke test for Milestone 6 (Art & Character Pipeline).
##
## Verifies the M6 acceptance criteria that CAN be checked without a human/display:
##   1. The exported character GLB loads and instantiates.
##   2. It carries a Skeleton3D with the expected bone count.
##   3. It carries the expected skinned meshes and materials.
##   4. It carries the "Attack" animation and playing it actually drives the skeleton.
##   5. It imports at unit scale (no unintended scaling from the Blender->Godot hand-off).
##
## Run from the project root with the Godot console binary:
##   godot --headless --path . --script res://tests/integration/model_import_smoke_test.gd
## Exit code 0 = all checks passed, 1 = at least one failed.

const MODEL_SCENE := "res://assets/models/player.glb"
const EXPECTED_BONES := 20
const EXPECTED_ANIM := "Attack"


func _init() -> void:
	_run()


func _run() -> void:
	var results: Array[bool] = []

	var packed: PackedScene = load(MODEL_SCENE)
	var model_ok := packed != null
	print("CHECK model_loads = ", model_ok)
	results.append(model_ok)
	if not model_ok:
		print("ALL_TESTS_PASS=false")
		quit(1)
		return

	var model: Node3D = packed.instantiate() as Node3D
	root.add_child(model)
	# Let one frame settle so global transforms are valid.
	await physics_frame

	# --- Skeleton -----------------------------------------------------------
	var skeletons := model.find_children("*", "Skeleton3D", true, false)
	var skeleton: Skeleton3D = null
	if skeletons.size() > 0:
		skeleton = skeletons[0] as Skeleton3D
	var skeleton_ok := skeleton != null
	var bone_count: int = 0
	if skeleton_ok:
		bone_count = skeleton.get_bone_count()
	print("skeleton=", skeleton.name if skeleton_ok else "NONE", " bones=", bone_count)
	print("CHECK skeleton_present = ", skeleton_ok)
	results.append(skeleton_ok)
	print("CHECK bone_count_", EXPECTED_BONES, " = ", bone_count == EXPECTED_BONES)
	results.append(bone_count == EXPECTED_BONES)

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

	# --- Animation ----------------------------------------------------------
	var players := model.find_children("*", "AnimationPlayer", true, false)
	var anim_player: AnimationPlayer = players[0] if players.size() > 0 else null
	var has_anim := anim_player != null and anim_player.has_animation(EXPECTED_ANIM)
	print("animation_player=", anim_player.name if anim_player else "NONE",
		" libs=", (anim_player.get_animation_list() if anim_player else []))
	print("CHECK animation_present = ", has_anim)
	results.append(has_anim)

	var drives := false
	if skeleton_ok and has_anim:
		var hand_idx := skeleton.find_bone("hand.R")
		if hand_idx >= 0:
			var before := skeleton.get_bone_global_pose(hand_idx)
			anim_player.play(EXPECTED_ANIM)
			# Attack is ~0.87 s; step well into the swing.
			for i in range(30):
				await physics_frame
			var after := skeleton.get_bone_global_pose(hand_idx)
			var delta := (after.origin - before.origin).length()
			print("hand_delta=", delta)
			drives = delta > 0.01
	print("CHECK animation_drives_skeleton = ", drives)
	results.append(drives)

	# --- Summary ------------------------------------------------------------
	var all_pass := true
	for r in results:
		if not r:
			all_pass = false
	print("ALL_TESTS_PASS=", all_pass)
	quit(0 if all_pass else 1)
