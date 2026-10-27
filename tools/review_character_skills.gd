extends SceneTree
const PLAYER := preload("res://scenes/characters/Player.tscn")
const ARENA := preload("res://scenes/arena/Arena.tscn")
const WEAPON := preload("res://scripts/combat/local_weapon_attacker.gd")
var actors: Array[CharacterBody3D] = []

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var world := Node3D.new(); root.add_child(world)
	world.add_child(ARENA.instantiate())
	var floor_mesh: MeshInstance3D = world.get_child(0).get_node("Floor/MeshInstance3D")
	var floor_mat := StandardMaterial3D.new(); floor_mat.albedo_color = Color("263341"); floor_mat.roughness = .9
	floor_mesh.material_override = floor_mat
	for character in [0,1]:
		var body: CharacterBody3D = PLAYER.instantiate()
		body.external_control = true
		body.position = Vector3(-1.8 if character==0 else 1.8,1.01,0)
		body.get_node("Mesh").character = character
		body.get_node("CameraPivot").local_input_enabled = false
		body.get_node("AttackHitbox").set_script(WEAPON)
		body.get_node("AttackHitbox").network_authority = true
		body.get_node("AttackHitbox").external_control = true
		body.get_node("CharacterSkills").network_authority = true
		body.get_node("Combatant").team_id = character
		world.add_child(body); actors.append(body)
		var label := Label3D.new(); label.text = "ARCLIGHT" if character==0 else "ASHEN WARDEN"
		label.position = Vector3(0,1.25,0); label.font_size = 40; label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		body.add_child(label)
	var camera := Camera3D.new(); world.add_child(camera)
	camera.position = Vector3(-3.5,2.8,6.8); camera.fov = 38
	camera.look_at(Vector3(0,1,0)); camera.current = true
	var canvas := CanvasLayer.new(); world.add_child(canvas)
	var help := Label.new(); help.position = Vector2(24,20); help.add_theme_font_size_override("font_size",24)
	help.text = "CHARACTER SKILLS  /  [G]\nArclight: Pulse Grenade | 4s stun | 18s cooldown\nAshen Warden: Flame Scythe | 20s active | 40s cooldown\nScythe: sweeping reap, reverse hook, aerial cleave + burn"
	help.add_theme_color_override("font_shadow_color",Color.BLACK)
	help.add_theme_constant_override("shadow_offset_x",2); help.add_theme_constant_override("shadow_offset_y",2)
	canvas.add_child(help)
	for i in range(12): await process_frame
	actors[1].get_node("CharacterSkills").request_skill()
	var driver = actors[1].get_node("CharacterAnimation")
	driver.set_manual_preview(true); driver._anim.play("Idle")
	driver._anim.pause(); driver._anim.seek(.4,true)
	actors[0].get_node("CharacterSkills").request_skill()
	for grenade in get_nodes_in_group("skill_grenades"):
		grenade.set_physics_process(false)
		grenade.global_position = actors[0].position+Vector3(0,-.7,1.1)
		grenade.detonate(); grenade.burst_left=.22; grenade._refresh()
	for i in range(5): await process_frame
	await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path("res://").path_join("../assets/character-skills-preview.png").simplify_path()
	var result := root.get_texture().get_image().save_png(path)
	print("SKILLS_REVIEW_CAPTURE=",result," PATH=",path)
	quit(0 if result==OK else 1)
