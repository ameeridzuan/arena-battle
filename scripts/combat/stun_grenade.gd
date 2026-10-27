extends Node3D
## Small ballistic grenade; only the authoritative instance may apply a stun.
var source: CharacterBody3D
var velocity := Vector3.ZERO
var fuse := .9
var blast_radius := 3.0
var exploded := false
var burst_left := .45
var presentation_only := false
var _body_visual: MeshInstance3D
var _ring: MeshInstance3D
var _manager: Node

func _ready() -> void:
	add_to_group("skill_grenades")
	_manager = get_tree().get_first_node_in_group("match_manager")
	if _manager != null: _manager.match_ended.connect(func(_winner: int): queue_free())
	_body_visual = MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = .12; ball.height = .24
	_body_visual.mesh = ball
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("243b53"); mat.emission_enabled = true
	mat.emission = Color("29cfe3"); mat.metallic = .7
	_body_visual.material_override = mat
	add_child(_body_visual)
	_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = .94; torus.outer_radius = 1
	_ring.mesh = torus
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow.albedo_color = Color(.2,.9,1,.65)
	_ring.material_override = glow
	_ring.visible = false
	add_child(_ring)

func _physics_process(delta: float) -> void:
	if presentation_only: return
	if not is_instance_valid(source) or source.get_health() <= 0 or source.get_node("Health").network_replica or (_manager != null and _manager.get_phase() == 2):
		queue_free(); return
	if exploded:
		burst_left -= delta
		_refresh()
		if burst_left <= 0: queue_free()
		return
	fuse -= delta
	velocity.y -= 12.0*delta
	var next := global_position + velocity*delta
	var query := PhysicsRayQueryParameters3D.create(global_position,next,1|2|4,[source.get_rid()])
	query.hit_from_inside = true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		global_position = hit.position + hit.normal*.13
		velocity = velocity.bounce(hit.normal)*.35
	else: global_position = next
	_body_visual.rotate_y(delta*7)
	if fuse <= .000001: detonate()

func detonate() -> void:
	if exploded or presentation_only or not is_instance_valid(source) or source.get_node("Health").network_replica or source.get_health() <= 0 or (_manager != null and _manager.get_phase() == 2): return
	exploded = true
	var shape := SphereShape3D.new(); shape.radius = blast_radius
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape; query.transform.origin = global_position
	query.collision_mask = 2|4; query.exclude = [source.get_rid()]
	var seen := {}
	for hit in get_world_3d().direct_space_state.intersect_shape(query,32):
		var target: Node3D = hit.collider
		if seen.has(target.get_instance_id()): continue
		seen[target.get_instance_id()] = true
		var stun := target.get_node_or_null("StunStatus")
		if stun == null: continue
		var ray := PhysicsRayQueryParameters3D.create(global_position,target.global_position,1,[source.get_rid()])
		ray.hit_from_inside = true
		if get_world_3d().direct_space_state.intersect_ray(ray).is_empty(): stun.apply_stun(source,4.0)
	_refresh()

func present_state(point: Vector3, spent: bool, left: float) -> void:
	if not presentation_only: return
	global_position = point; exploded = spent; burst_left = clampf(left,0,.45)
	_refresh()

func _refresh() -> void:
	_body_visual.visible = not exploded
	_ring.visible = exploded
	if exploded:
		_ring.scale = Vector3.ONE*maxf(.05,blast_radius*(1.0-burst_left/.45))
		_ring.material_override.albedo_color.a = clampf(burst_left/.45,0,.65)
