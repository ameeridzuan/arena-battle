extends Node3D
## Character identity selects the skill; cooldowns stay with the actor across switches.
signal skill_activated(character: int)
const GRENADE := preload("res://scripts/combat/stun_grenade.gd")
const ACTION := preload("res://scripts/player/animation_action.gd")
@export var grenade_cooldown_s := 18.0
@export var scythe_cooldown_s := 40.0
@export var scythe_duration_s := 20.0
var network_authority := false
var cooldowns: Array[float] = [0.0,0.0]
var scythe_left := 0.0
var _body: CharacterBody3D
var _mesh: Node3D
var _driver: Node
var _manager: Node
var _scythe: Node3D
var _hud: Label
var _hidden_weapons: Array[GeometryInstance3D] = []

func _ready() -> void:
	process_physics_priority = -25
	_body = get_parent()
	_mesh = _body.get_node("Mesh")
	_driver = _body.get_node("CharacterAnimation")
	_manager = get_tree().get_first_node_in_group("match_manager")
	_body.get_node("Health").died.connect(end_scythe)
	_body.get_node("Health").reset_performed.connect(end_scythe)
	_mesh.model_changed.connect(func(_model: Node3D): end_scythe())
	if _manager != null: _manager.match_ended.connect(func(_winner: int): end_scythe())
	var weapon := _body.get_node("AttackHitbox")
	if weapon.has_signal("weapon_hit"): weapon.weapon_hit.connect(_on_weapon_hit)
	if not InputMap.has_action("character_skill"):
		InputMap.add_action("character_skill")
		var key := InputEventKey.new(); key.physical_keycode = KEY_G
		InputMap.action_add_event("character_skill",key)
	_build_scythe()
	if not _body.external_control and DisplayServer.get_name() != "headless":
		var layer := CanvasLayer.new(); layer.layer = 11; add_child(layer)
		_hud = Label.new(); _hud.position = Vector2(16,245)
		_hud.add_theme_color_override("font_color",Color("ffce86"))
		_hud.add_theme_color_override("font_shadow_color",Color.BLACK)
		_hud.add_theme_constant_override("shadow_offset_x",2)
		_hud.add_theme_constant_override("shadow_offset_y",2)
		layer.add_child(_hud)

func _authority() -> bool:
	return is_instance_valid(_body) and not _body.get_node("Health").network_replica and (network_authority or not _body.external_control)

func _can_activate() -> bool:
	return _authority() and _body.get_health() > 0 and not _body.is_stunned() and (_manager == null or (_manager.get_phase() == 1 if network_authority else _manager.get_phase() != 2)) and (not _body.has_method("allows_motion_actions") or _body.allows_motion_actions())

func request_skill() -> bool:
	var character := int(_mesh.character)
	if not _can_activate() or character not in [0,1] or cooldowns[character] > 0 or not _driver.get_action_clip().is_empty(): return false
	if character == 0:
		var grenade := Node3D.new(); grenade.set_script(GRENADE)
		grenade.source = _body
		var forward := _mesh.global_basis.z.normalized()
		var origin := _body.global_position + Vector3.UP*.55
		# Do not spawn past a nearby wall or throw through it.
		var desired := origin + forward*.55
		var ray := PhysicsRayQueryParameters3D.create(origin,desired,1,[_body.get_rid()])
		ray.hit_from_inside = true
		var hit := get_world_3d().direct_space_state.intersect_ray(ray)
		if not hit.is_empty(): desired = hit.position-forward*.15
		grenade.velocity = forward*8.0+Vector3.UP*4.0
		_body.get_parent().add_child(grenade)
		grenade.global_position = desired
		cooldowns[0] = grenade_cooldown_s
		if _driver._anim != null and _driver._anim.has_animation("Skills/Grenade_Throw"):
			var spec := ACTION.new(); spec.clip = &"Skills/Grenade_Throw"; spec.priority = 25
			_driver.present_action(spec)
	else:
		scythe_left = scythe_duration_s
		cooldowns[1] = scythe_cooldown_s
		_hide_standard_weapon()
	skill_activated.emit(character)
	return true

func _physics_process(delta: float) -> void:
	if not _authority(): return
	if _manager != null and _manager.get_phase() == 2: return
	for i in range(2): cooldowns[i] = maxf(0,cooldowns[i]-delta)
	if scythe_left > 0:
		scythe_left = maxf(0,scythe_left-delta)
		if scythe_left <= .000001: end_scythe()
	if not _body.external_control and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and Input.is_action_just_pressed("character_skill"): request_skill()

func is_scythe_active() -> bool:
	return scythe_left > 0 and int(_mesh.character) == 1 and _body.get_health() > 0

func end_scythe() -> void:
	if scythe_left > 0:
		var attack := _body.get_node("AttackHitbox")
		if attack.has_method("cancel_attack"): attack.cancel_attack()
	scythe_left = 0
	for mesh in _hidden_weapons:
		if is_instance_valid(mesh): mesh.visible = true
	_hidden_weapons.clear()
	if _scythe != null: _scythe.visible = false

func _on_weapon_hit(target: Node, _point: Vector3, _normal: Vector3, amount: float) -> void:
	if not _authority() or not is_scythe_active() or amount <= 0 or target.get_node("Health").get_health() <= 0: return
	var burn := target.get_node_or_null("BurnStatus")
	if burn != null: burn.apply_burn(_body,3.0,3,1.0)

func describe() -> String:
	var character := int(_mesh.character)
	var name := "Pulse Grenade" if character == 0 else "Flame Scythe"
	var state := "READY" if cooldowns[character] <= 0 else "%.1fs cooldown" % cooldowns[character]
	if is_scythe_active(): state = "ACTIVE %.1fs | %.1fs cooldown" % [scythe_left,cooldowns[character]]
	var stunned: Node = _body.get_node_or_null("StunStatus")
	if stunned != null and stunned.is_stunned(): state = "STUNNED %.1fs | " % stunned.remaining + state
	return "[G] %s: %s" % [name,state]

func capture_state() -> Array:
	return [cooldowns[0],cooldowns[1],scythe_left]

func apply_network_state(state: Array) -> void:
	if not _body.get_node("Health").network_replica or state.size() != 3: return
	for value in state:
		if not is_finite(float(value)): return
	cooldowns[0] = clampf(float(state[0]),0,grenade_cooldown_s)
	cooldowns[1] = clampf(float(state[1]),0,scythe_cooldown_s)
	var previous := scythe_left
	scythe_left = clampf(float(state[2]),0,scythe_duration_s)
	if previous <= 0 and scythe_left > 0: _hide_standard_weapon()
	elif scythe_left <= 0: end_scythe()

func _process(_delta: float) -> void:
	if _hud != null: _hud.text = describe()
	_scythe.visible = is_scythe_active() and _mesh.visible
	if not _scythe.visible or not is_instance_valid(_mesh._model): return
	var skeletons: Array = _mesh._model.find_children("*","Skeleton3D",true,false)
	if skeletons.is_empty(): return
	var skeleton: Skeleton3D = skeletons[0]
	var hand := skeleton.find_bone("hand.R")
	if hand >= 0: _scythe.global_transform = skeleton.global_transform*skeleton.get_bone_global_pose(hand)

func _hide_standard_weapon() -> void:
	if not is_instance_valid(_mesh._model): return
	for mesh in _mesh._model.find_children("*","MeshInstance3D",true,false):
		var label := String(mesh.name).to_lower()
		if label.begins_with("longsword") or label.begins_with("weapon"):
			if mesh.visible:
				_hidden_weapons.append(mesh)
				mesh.visible = false

func _material(color: Color, glow: float = 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new(); mat.albedo_color = color
	mat.metallic = .6; mat.roughness = .32
	if glow > 0:
		mat.emission_enabled = true; mat.emission = color; mat.emission_energy_multiplier = glow
	return mat

func _build_scythe() -> void:
	_scythe = Node3D.new(); _scythe.name = "FlameScythe"; add_child(_scythe)
	_scythe.top_level = true; _scythe.visible = false
	var shaft := MeshInstance3D.new()
	var cylinder := CylinderMesh.new(); cylinder.top_radius = .035; cylinder.bottom_radius = .035; cylinder.height = 1.75
	shaft.mesh = cylinder; shaft.rotation.x = PI*.5; shaft.position = Vector3(0,.07,-.5)
	shaft.material_override = _material(Color("27232b")); _scythe.add_child(shaft)
	for z in [.2,-.2,-.6,-1.0,-1.32]:
		var ring := MeshInstance3D.new(); var torus := TorusMesh.new()
		torus.inner_radius = .035; torus.outer_radius = .055
		ring.mesh = torus; ring.rotation.x = PI*.5; ring.position = Vector3(0,.07,z)
		ring.material_override = _material(Color("c65b13"),.8); _scythe.add_child(ring)
	var surface := SurfaceTool.new(); surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(24):
		for side in [-1.0,1.0]:
			var points: Array[Vector3] = []
			for j in [i,i+1]:
				var t := float(j)/24; var angle := t*PI*.5
				var center := Vector3(.98*sin(angle),.07+side*.045,-1.42+.65*(1-cos(angle)))
				var width := .16*(1-t)+.008
				points.append(center+Vector3(0,0,-width))
				points.append(center+Vector3(0,0,width))
			for index in ([0,2,1,1,2,3] if side > 0 else [0,1,2,1,3,2]): surface.add_vertex(points[index])
		# Closed edge walls keep the hook readable when the flat blade turns edge-on.
		for edge in [-1.0,1.0]:
			var points: Array[Vector3] = []
			for j in [i,i+1]:
				var t := float(j)/24; var angle := t*PI*.5
				var center := Vector3(.98*sin(angle),.07,-1.42+.65*(1-cos(angle)))
				center.z += edge*(.16*(1-t)+.008)
				points.append(center+Vector3(0,-.045,0)); points.append(center+Vector3(0,.045,0))
			for index in [0,1,2,1,3,2]: surface.add_vertex(points[index])
	surface.generate_normals()
	var blade := MeshInstance3D.new(); blade.mesh = surface.commit()
	var mat := _material(Color("b9430a"),.7); mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	blade.material_override = mat; _scythe.add_child(blade)
	var sparks := CPUParticles3D.new(); sparks.amount = 32; sparks.lifetime = .45
	sparks.position = Vector3(.4,.07,-1.25); sparks.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE; sparks.emission_sphere_radius = .3
	sparks.initial_velocity_min = .2; sparks.initial_velocity_max = .6; sparks.gravity = Vector3(0,1.4,0)
	sparks.color = Color("ff5017"); var ember := SphereMesh.new(); ember.radius = .022; ember.height = .044
	ember.material = _material(Color("ff8c12"),2); sparks.mesh = ember
	_scythe.add_child(sparks)
