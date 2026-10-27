extends MeshInstance3D
signal model_changed(model: Node3D)
## Character model swapper (M7 art pass).
##
## Gameplay hard-references the `Mesh` node path (see docs/ART_IMPORT_CONVENTIONS.md and the
## M3/M4/M5 contracts), so this script keeps `Mesh` as a stable MeshInstance3D anchor and
## instantiates the authored character GLB as a child named `Model` at runtime. Swapping the
## `character` export selects Arclight (player 1) or Ashen Warden (player 2) without touching
## any node-path contract.
##
## Both GLBs are exported origin-at-feet, so the model is dropped by 1 m to sit at the base of
## the 2 m-tall body capsule (identical to the previous placeholder offset).

enum Character { ARCLIGHT, WARDEN }
enum CosmeticSkin { DEFAULT, ASTRA_YAO, YIXUAN }

const ARCLIGHT_SCENE := preload("res://assets/models/arclight.glb")
const WARDEN_SCENE := preload("res://assets/models/ashen_warden.glb")
const ASTRA_YAO_SCENE := preload("res://assets/models/astra_yao.glb")
const YIXUAN_SCENE := preload("res://assets/models/yixuan.glb")
const SCENES := {
	Character.ARCLIGHT: ARCLIGHT_SCENE,
	Character.WARDEN: WARDEN_SCENE,
}
## Origin-at-feet models sit at the capsule base (capsule spans y = -1 .. +1 about the body).
const MODEL_OFFSET := Vector3(0.0, -1.0, 0.0)

@export var character: Character = Character.ARCLIGHT
## Cosmetic choice only; gameplay character identity remains unchanged.
@export var cosmetic_skin: CosmeticSkin = CosmeticSkin.DEFAULT

var _model: Node3D
var _skin_choices: Array[int] = [0, 0]


func _ready() -> void:
	if not is_skin_valid(int(character), int(cosmetic_skin)):
		cosmetic_skin = CosmeticSkin.DEFAULT
	_skin_choices[int(character)] = int(cosmetic_skin)
	_instantiate()


## Runtime selection (used by the network session before the body enters the tree).
func set_character(value: int) -> void:
	if value not in Character.values():
		return
	_skin_choices[int(character)] = int(cosmetic_skin)
	set_appearance(value, _skin_choices[value])


func set_cosmetic_skin(value: int) -> void:
	set_appearance(int(character), value)


func set_appearance(character_value: int, skin_value: int) -> void:
	if not is_skin_valid(character_value, skin_value):
		return
	if int(character) == character_value and int(cosmetic_skin) == skin_value:
		return
	character = character_value as Character
	cosmetic_skin = skin_value as CosmeticSkin
	_skin_choices[character_value] = skin_value
	if is_inside_tree():
		_instantiate()


func get_display_name() -> String:
	if character == Character.WARDEN:
		return "Yixuan (Ashen Warden)" if cosmetic_skin == CosmeticSkin.YIXUAN else "Ashen Warden"
	return "Astra Yao (Arclight)" if cosmetic_skin == CosmeticSkin.ASTRA_YAO else "Arclight"

static func is_skin_valid(character_value: int, skin_value: int) -> bool:
	return character_value in Character.values() and (skin_value == 0 or (character_value == 0 and skin_value == 1) or (character_value == 1 and skin_value == 2))

func has_graceful_skin() -> bool:
	return (character == Character.ARCLIGHT and cosmetic_skin == CosmeticSkin.ASTRA_YAO) or (character == Character.WARDEN and cosmetic_skin == CosmeticSkin.YIXUAN)

func toggle_skin() -> void:
	var alternate := CosmeticSkin.ASTRA_YAO if character == Character.ARCLIGHT else CosmeticSkin.YIXUAN
	set_cosmetic_skin(int(alternate) if cosmetic_skin == CosmeticSkin.DEFAULT else int(CosmeticSkin.DEFAULT))


func _instantiate() -> void:
	if _model != null and is_instance_valid(_model):
		remove_child(_model)
		_model.queue_free()
		_model = null
	var packed: PackedScene = SCENES.get(character)
	if character == Character.ARCLIGHT and cosmetic_skin == CosmeticSkin.ASTRA_YAO:
		packed = ASTRA_YAO_SCENE
	elif character == Character.WARDEN and cosmetic_skin == CosmeticSkin.YIXUAN:
		packed = YIXUAN_SCENE
	if packed == null:
		push_warning("character_model: no scene mapped for character %d" % character)
		return
	_model = packed.instantiate() as Node3D
	_model.name = "Model"
	_model.transform = Transform3D(Basis.IDENTITY, MODEL_OFFSET)
	add_child(_model)
	if has_graceful_skin():
		var springs := Node.new()
		var prefix := "Astra" if character == Character.ARCLIGHT else "Yixuan"
		springs.name = prefix + "SpringMotion"
		springs.set_script(preload("res://scripts/player/astra_spring_motion.gd"))
		springs.bone_prefix = prefix
		_model.add_child(springs)
	model_changed.emit(_model)
