extends Resource
## Presentation contract shared by idle/walking/running actions. Never grants gameplay effects.
enum Layer { UPPER_BODY, FULL_BODY }
@export var clip: StringName
@export var layer: Layer = Layer.UPPER_BODY
@export var priority: int = 0
@export var interruptible: bool = true
@export_range(0.0, 0.5) var blend_in_s: float = 0.06
@export_range(0.0, 0.5) var blend_out_s: float = 0.12
