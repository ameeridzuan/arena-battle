extends Label3D
## Transient world-space presentation; no health or combat authority.
@export var lifetime_s := 0.9
@export var rise_speed := 0.8
var _remaining := 0.9

func configure(amount: float, kind: StringName) -> void:
	var value := str(int(roundf(amount))) if is_equal_approx(amount, roundf(amount)) else "%.1f" % amount
	text = ("BURN -" if kind == &"burn" else "-") + value
	modulate = Color(1.0, 0.48, 0.08) if kind == &"burn" else Color(1.0, 0.22, 0.18)
	font_size = 48
	pixel_size = 0.007
	outline_size = 10
	outline_modulate = Color(0.05, 0.02, 0.01)
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	no_depth_test = true
	shaded = false

func _ready() -> void:
	_remaining = lifetime_s
	add_to_group("floating_damage_numbers")

func _process(delta: float) -> void:
	_remaining -= delta
	if _remaining <= 0.0:
		queue_free()
		return
	position.y += rise_speed * delta
	modulate.a = minf(1.0, _remaining / 0.3)
