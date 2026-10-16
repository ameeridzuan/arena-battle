extends MeshInstance3D
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

const ARCLIGHT_SCENE := preload("res://assets/models/arclight.glb")
const WARDEN_SCENE := preload("res://assets/models/ashen_warden.glb")
const SCENES := {
	Character.ARCLIGHT: ARCLIGHT_SCENE,
	Character.WARDEN: WARDEN_SCENE,
}
## Origin-at-feet models sit at the capsule base (capsule spans y = -1 .. +1 about the body).
const MODEL_OFFSET := Vector3(0.0, -1.0, 0.0)

@export var character: Character = Character.ARCLIGHT

var _model: Node3D


func _ready() -> void:
	_instantiate()


## Runtime selection (used by the network session before the body enters the tree).
func set_character(value: int) -> void:
	character = value as Character
	if is_inside_tree():
		_instantiate()


func _instantiate() -> void:
	if _model != null and is_instance_valid(_model):
		_model.queue_free()
		_model = null
	var packed: PackedScene = SCENES.get(character)
	if packed == null:
		push_warning("character_model: no scene mapped for character %d" % character)
		return
	_model = packed.instantiate() as Node3D
	_model.name = "Model"
	_model.transform = Transform3D(Basis.IDENTITY, MODEL_OFFSET)
	add_child(_model)
