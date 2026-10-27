extends RefCounted
## Conservative bone-local envelopes from the visible rigid/skinned armor geometry.
## Built once per rig; traversal uses the envelopes, never GPU readback per frame.
var bounds: Dictionary = {}
var _skeleton: Skeleton3D

func build(skeleton: Skeleton3D) -> void:
	_skeleton = skeleton
	bounds.clear()
	var model: Node = skeleton.get_parent()
	for instance in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := instance as MeshInstance3D
		if mesh.skin == null or mesh.mesh == null:
			continue
		var name_lower := String(mesh.name).to_lower()
		if name_lower.begins_with("sword ") or name_lower.begins_with("longsword ") or name_lower.contains("cape"):
			continue
		var mapping: Array[int] = []
		for binding in mesh.skin.get_bind_count():
			var bone := mesh.skin.get_bind_bone(binding)
			if bone < 0:
				bone = skeleton.find_bone(mesh.skin.get_bind_name(binding))
			mapping.append(bone)
		for surface in mesh.mesh.get_surface_count():
			var arrays: Array = mesh.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			var stride := indices.size() / maxi(vertices.size(), 1)
			for vertex in vertices.size():
				for influence_index in int(stride):
					var index := vertex * int(stride) + influence_index
					if weights[index] < 0.001:
						continue
					var binding := indices[index]
					var bone := mapping[binding]
					if bone < 0:
						continue
					var point: Vector3 = skeleton.get_bone_global_rest(bone) * mesh.skin.get_bind_pose(binding) * vertices[vertex]
					bounds[bone] = bounds[bone].expand(point) if bounds.has(bone) else AABB(point, Vector3.ZERO)

func points(bone: int) -> PackedVector3Array:
	var result := PackedVector3Array()
	if not bounds.has(bone):
		return result
	var envelope: AABB = bounds[bone]
	var transform := _skeleton.global_transform * _skeleton.get_bone_global_pose(bone) * _skeleton.get_bone_global_rest(bone).affine_inverse()
	for corner in 8:
		result.append(transform * envelope.get_endpoint(corner))
	return result

func penetration(bones: Array, lip: Vector3, normal: Vector3, margin: float = 0.015) -> float:
	var depth := 0.0
	for bone in bones:
		for point in points(bone):
			if point.y < lip.y + margin:
				# Release above the top gradually, retaining full protection below it.
				var release := 1.0 - smoothstep(lip.y + margin, lip.y + margin + 0.15, point.y)
				depth = maxf(depth, (margin - (point - lip).dot(normal)) * release)
	return maxf(depth, 0.0)
