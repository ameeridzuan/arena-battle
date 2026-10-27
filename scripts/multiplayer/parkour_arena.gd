extends Node3D
## Mirrored routes keep both spawns equivalent; all traversal surfaces use world layer 1.
const BLUE := Color(0.15, 0.48, 0.63)
const AMBER := Color(0.67, 0.40, 0.17)
const STONE := Color(0.25, 0.31, 0.38)

func _ready() -> void:
	# Preserve match bounds when players jump from elevated routes.
	for wall in $Arena/Walls.get_children():
		var collision: CollisionShape3D = wall.get_node("CollisionShape3D")
		var shape: BoxShape3D = collision.shape.duplicate()
		shape.size = Vector3(shape.size.x, 12.0, shape.size.z)
		collision.shape = shape
		collision.position.y = 4.0
	for side in [-1.0, 1.0]:
		var tint := BLUE if side < 0.0 else AMBER
		_box("ClimbTerrace", Vector3(4, 1.8, 7), Vector3(side * 10, 0.9, 0), tint)
		# Step rises vary from 15 to 30 cm, feeding the adaptive stepping system.
		var heights := [0.15, 0.35, 0.60, 0.90, 1.20, 1.50]
		for step in heights.size():
			var height: float = heights[step]
			_box("ApproachStep", Vector3(3.2, height, 0.8), Vector3(side * 10, height * 0.5, side * (8.0 - step * 0.8)), STONE.lerp(tint, 0.25))
		_box("LowVault", Vector3(2.5, 0.65, 2.0), Vector3(side * 5.0, 0.325, -side * 9.0), tint)
		# Two opposing faces form an alternating wall-jump lane, open toward the court.
		for edge in [-1.0, 1.0]:
			_box("JumpWall", Vector3(0.65, 4.6, 4.8), Vector3(edge * 1.45, 2.3, side * 9.0), STONE)
		_box("UpperLanding", Vector3(4.2, 3.2, 2.0), Vector3(0, 1.6, side * 12.3), tint)
		_sign("WALL JUMP ROUTE", Vector3(0, 0.04, side * 6.1), tint.lightened(0.4))
		_sign("1.8 m CLIMB / SHIMMY", Vector3(side * 7.4, 0.04, 0), tint.lightened(0.4))
		_sign("STAIR ROUTE", Vector3(side * 10, 0.04, side * 9.3), tint.lightened(0.4))
	# A clear central court preserves direct melee/ranged approaches between the spawns.
	var floor_mesh: MeshInstance3D = $Arena/Floor/MeshInstance3D
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color(0.12, 0.16, 0.21)
	floor_mesh.material_override = floor_material

func _box(label: String, size: Vector3, at: Vector3, tint: Color) -> StaticBody3D:
	var solid := StaticBody3D.new()
	solid.name = label
	solid.position = at
	solid.collision_layer = 1
	solid.collision_mask = 0
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	solid.add_child(collision)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.roughness = 0.85
	mesh.material_override = material
	solid.add_child(mesh)
	add_child(solid, true)
	return solid

func _sign(text: String, at: Vector3, tint: Color) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 48
	label.pixel_size = 0.006
	label.modulate = tint
	label.rotation_degrees.x = -90.0
	label.position = at
	add_child(label)
