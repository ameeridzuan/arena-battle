extends Node3D
## M3 follow-up: presentation only; never applies damage or changes attack timing.
## Replace the placeholder swipe with authored animation/VFX during M6/M7.

@export var damage_flash_duration: float = 0.18
@export var swipe_duration: float = 0.18
@export var hurt_color: Color = Color(1.0, 0.12, 0.12)
@export var swipe_color: Color = Color(0.3, 0.85, 1.0, 0.8)
@export_range(4, 64) var swipe_segments: int = 24
@export var swipe_width: float = 0.18

var _health: Health
var _mesh: MeshInstance3D
var _original_material: Material
var _hurt_material: StandardMaterial3D
var _swipe: MeshInstance3D
var _swipe_material: StandardMaterial3D
var _previous_health: float
var _flash_remaining: float = 0.0
var _swipe_remaining: float = 0.0
# M6: the authored skinned model lives under Mesh; mirror presentation onto it.
var _skin_meshes: Array[MeshInstance3D] = []
var _skin_saved: Array[Material] = []
var _anim: AnimationPlayer

func _ready() -> void:
	var body := get_parent()
	_health = body.get_node("Health") as Health
	_mesh = body.get_node("Mesh") as MeshInstance3D
	_original_material = _mesh.material_override
	for sm in _mesh.find_children("*", "MeshInstance3D", true, false):
		_skin_meshes.append(sm as MeshInstance3D)
	var anims := _mesh.find_children("*", "AnimationPlayer", true, false)
	_anim = (anims[0] as AnimationPlayer) if anims.size() > 0 else null
	_hurt_material = StandardMaterial3D.new()
	_hurt_material.albedo_color = hurt_color
	_previous_health = _health.get_health()
	_health.health_changed.connect(_on_health_changed)
	var attack := body.get_node("AttackHitbox")
	attack.attack_started.connect(_on_attack_started)
	_build_swipe(attack.attack_range, attack.attack_arc_deg)

func _build_swipe(radius: float, arc_degrees: float) -> void:
	var geometry := ImmediateMesh.new()
	geometry.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var half_arc := deg_to_rad(arc_degrees * 0.5)
	for i in range(swipe_segments + 1):
		var angle := lerpf(-half_arc, half_arc, float(i) / swipe_segments)
		var direction := Vector3(sin(angle), 0.0, -cos(angle))
		geometry.surface_add_vertex(direction * maxf(0.0, radius - swipe_width))
		geometry.surface_add_vertex(direction * radius)
	geometry.surface_end()
	_swipe_material = StandardMaterial3D.new()
	_swipe_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_swipe_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_swipe_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_swipe_material.albedo_color = swipe_color
	_swipe = MeshInstance3D.new()
	_swipe.name = "AttackSwipe"
	_swipe.mesh = geometry
	_swipe.material_override = _swipe_material
	_swipe.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_swipe.visible = false
	add_child(_swipe)

func _on_attack_started(forward: Vector3) -> void:
	_swipe.global_rotation = Vector3(0.0, atan2(-forward.x, -forward.z), 0.0)
	_swipe_remaining = maxf(swipe_duration, 0.01)
	_swipe_material.albedo_color = swipe_color
	_swipe.visible = true
	if _anim != null and _anim.has_animation("Attack"):
		_anim.play("Attack")

func _apply_override(mat: Material) -> void:
	# Snapshot current overrides so a team tint applied after _ready survives the flash.
	_skin_saved.clear()
	for sm in _skin_meshes:
		_skin_saved.append(sm.material_override)
	_mesh.material_override = mat
	for sm in _skin_meshes:
		sm.material_override = mat

func _restore_override() -> void:
	_mesh.material_override = _original_material
	for i in range(_skin_meshes.size()):
		_skin_meshes[i].material_override = _skin_saved[i] if i < _skin_saved.size() else null

func _on_health_changed(current: float, _maximum: float) -> void:
	if current < _previous_health:
		_flash_remaining = maxf(damage_flash_duration, 0.01)
		_apply_override(_hurt_material)
	else:
		_flash_remaining = 0.0
		_restore_override()
	if current <= 0.0 or current > _previous_health:
		_swipe_remaining = 0.0
		_swipe.visible = false
	_previous_health = current

func _process(delta: float) -> void:
	if _flash_remaining > 0.0:
		_flash_remaining = maxf(0.0, _flash_remaining - delta)
		if _flash_remaining == 0.0:
			_restore_override()
	if _swipe_remaining > 0.0:
		_swipe_remaining = maxf(0.0, _swipe_remaining - delta)
		var color := swipe_color
		color.a *= _swipe_remaining / maxf(swipe_duration, 0.01)
		_swipe_material.albedo_color = color
		_swipe.visible = _swipe_remaining > 0.0
