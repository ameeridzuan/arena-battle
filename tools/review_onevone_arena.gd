extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var arena: Node3D = load("res://scenes/arena/ParkourArena.tscn").instantiate()
	root.add_child(arena)
	var camera := Camera3D.new()
	arena.add_child(camera)
	camera.position = Vector3(28, 27, 29)
	camera.look_at(Vector3(0, 0.5, 0))
	camera.fov = 51.0
	camera.current = true
	for i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/onevone_arena_review.png")
	arena.free()
	quit()
