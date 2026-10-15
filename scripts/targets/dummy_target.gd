extends StaticBody3D
## Milestone 2 — training dummy target.
##
## Joins the "damageable" group on _ready() so the MeleeAttacker can find it.
## Delegates all health state to the child Health node and flashes the mesh red
## briefly on each hit.

const BASE_ALBEDO := Color(0.8, 0.8, 0.8)
const FLASH_ALBEDO := Color(1.0, 0.2, 0.2)
const FLASH_DURATION := 0.15  # seconds

@onready var _health: Health = $Health
@onready var _mesh: MeshInstance3D = $Mesh

var _own_material: StandardMaterial3D
var _flash_tween: Tween


func _ready() -> void:
	add_to_group("damageable")
	# Give this instance its own material so flashing never bleeds to other nodes.
	_own_material = StandardMaterial3D.new()
	_own_material.albedo_color = BASE_ALBEDO
	_mesh.set_surface_override_material(0, _own_material)
	_health.health_changed.connect(_on_health_changed)
	_health.died.connect(_on_died)


## Combat interface — routes damage to the Health component.
func apply_damage(amount: float, source: Node) -> void:
	_health.apply_damage(amount, source)


## Combat interface — returns current health from the Health component.
func get_health() -> float:
	return _health.get_health()


func _on_health_changed(current: float, maximum: float) -> void:
	print("[DummyTarget] health: %.1f / %.1f" % [current, maximum])
	_flash_red()


func _on_died() -> void:
	print("[DummyTarget] DIED")


func _flash_red() -> void:
	if _own_material == null:
		return
	# Kill any in-progress flash so rapid hits don't queue stale restores.
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	_own_material.albedo_color = FLASH_ALBEDO
	_flash_tween = create_tween()
	_flash_tween.tween_interval(FLASH_DURATION)
	_flash_tween.tween_callback(_restore_albedo)


func _restore_albedo() -> void:
	if _own_material:
		_own_material.albedo_color = BASE_ALBEDO
