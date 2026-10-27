extends RefCounted
## Shared action semantics, rig-specific clips. No input, movement or combat authority.
const ACTION := preload("res://scripts/player/animation_action.gd")
const MODEL_NAMES := ["arclight", "ashen_warden"]
const IDS := ["CastEnergy", "Dash_Forward", "Dodge_Backward", "Dodge_Left", "Dodge_Right", "Parry_Attempt", "Parry_Success"]

static func install(player: AnimationPlayer, character: int) -> void:
	var source: AnimationLibrary = load("res://assets/animations/actions/%s.tres" % MODEL_NAMES[clampi(character, 0, 1)])
	if source == null:
		return
	if player.has_animation_library("Actions"):
		player.remove_animation_library("Actions")
	player.add_animation_library("Actions", source.duplicate(true))

static func definition(id: String) -> ACTION:
	if not IDS.has(id):
		return null
	var spec := ACTION.new()
	spec.clip = StringName("Actions/" + id)
	var dodge := id.begins_with("Dodge_") or id.begins_with("Dash_")
	spec.layer = ACTION.Layer.FULL_BODY if dodge else ACTION.Layer.UPPER_BODY
	spec.priority = 40 if dodge else 10
	spec.interruptible = not dodge
	spec.blend_in_s = 0.025 if dodge else 0.06
	spec.blend_out_s = 0.075 if dodge else 0.12
	if id.begins_with("Parry_"):
		spec.priority = 65 if id == "Parry_Success" else 60
		spec.interruptible = id != "Parry_Success"
		spec.blend_in_s = 0.0 if id == "Parry_Success" else 0.025
		spec.blend_out_s = 0.08
	return spec
