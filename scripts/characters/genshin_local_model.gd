extends "res://scripts/player/character_model.gd"
## Local-only visual override. The restricted model stays outside res:// and builds.
const LOCAL_GLB := "../assets/characters/protagonist/genshin-concept-match/protagonist-local-styled.glb"
var use_genshin := true
var last_load_error := OK

func local_model_path() -> String:
	return ProjectSettings.globalize_path("res://").path_join(LOCAL_GLB).simplify_path()

func _instantiate() -> void:
	if not use_genshin:
		super._instantiate()
		return
	if is_instance_valid(_model):
		remove_child(_model)
		_model.queue_free()
		_model = null
	var path := local_model_path()
	if not FileAccess.file_exists(path):
		last_load_error = ERR_FILE_NOT_FOUND
		push_error("Local Genshin preview model is missing: " + path)
		return
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	last_load_error = document.append_from_file(path, state)
	if last_load_error != OK:
		push_error("Local Genshin GLB load failed: %s" % error_string(last_load_error))
		return
	_model = document.generate_scene(state) as Node3D
	if _model == null:
		last_load_error = ERR_CANT_CREATE
		push_error("Could not generate local Genshin model scene")
		return
	_model.name = "Model"
	_model.position = MODEL_OFFSET
	add_child(_model)
	model_changed.emit(_model)

func select_preview(index: int) -> void:
	use_genshin = index == 0
	character = Character.ARCLIGHT if index != 2 else Character.WARDEN
	_instantiate()
