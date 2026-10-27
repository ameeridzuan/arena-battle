extends Node3D
## Short confirmed-contact burst. World-space lifetime, no damage or combat authority.
var normal := Vector3.UP
var air_attack := false
var _life := 0.28
var _material: StandardMaterial3D
var _velocities: Array[Vector3] = []
var _sparks: Array[MeshInstance3D] = []

func _ready() -> void:
	add_to_group("weapon_hit_effects")
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.albedo_color = Color(1.0, 0.65, 0.12) if air_attack else Color(0.4, 0.95, 1.0)
	_material.emission_enabled = true
	_material.emission = _material.albedo_color
	_material.emission_energy_multiplier = 2.0
	var sphere := SphereMesh.new()
	sphere.radius = 0.025
	sphere.height = 0.05
	for i in 9:
		var spark := MeshInstance3D.new()
		spark.mesh = sphere
		spark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		spark.material_override = _material
		add_child(spark)
		_sparks.append(spark)
		var angle := float(i) * TAU / 9.0
		var direction := (normal.normalized() * 0.7 + Vector3(cos(angle), 0.4 + sin(angle * 2.0) * 0.6, sin(angle))).normalized()
		_velocities.append(direction * (1.8 + float(i % 3) * 0.5))

func _process(delta: float) -> void:
	_life -= delta
	if _life <= 0.0:
		queue_free()
		return
	_material.albedo_color.a = minf(1.0, _life / 0.12)
	for i in _sparks.size():
		_sparks[i].position += _velocities[i] * delta
		_velocities[i].y -= delta * 3.0
