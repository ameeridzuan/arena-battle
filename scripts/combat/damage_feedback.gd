extends Node
## One common HP-loss presenter for player, targets and replicated health updates.
const NUMBER := preload("res://scripts/combat/floating_damage_number.gd")
@export var height := 1.5
var _sequence := 0

func _ready() -> void:
	get_parent().get_node("Health").damage_taken.connect(_on_damage_taken)

func _on_damage_taken(amount: float, _source: Node, kind: StringName) -> void:
	var body := get_parent() as Node3D
	if body == null or not is_finite(amount) or amount <= 0.0:
		return
	var label := Label3D.new()
	label.set_script(NUMBER)
	label.configure(amount, kind)
	# A sibling remains visible for the lethal hit even when the body mesh is hidden.
	body.get_parent().add_child(label)
	var offset := float(_sequence % 3 - 1) * 0.22
	label.global_position = body.global_position + Vector3(offset, height, 0.0)
	_sequence += 1
