extends Node
## Milestone 3 — team identity + death/respawn glue (docs/TECHNICAL_ARCHITECTURE.md §6.8, §6.10).
##
## Attach as a child Node alongside Health on any combatant body.  Owns:
##   - team_id (exported, not hardcoded)
##   - death -> kill attribution -> MatchManager notification
##   - respawn scheduling (disable/enable in place + SceneTree timer)
##   - spawn-point lookup by group ("spawn_team_<team_id>") + spawn_index
##
## Deliberately does NOT own movement or attack logic (separation of concerns, ADR-0010).

signal combatant_died(team_id: int)
signal combatant_respawned(team_id: int)

const MATCH_MANAGER_GROUP := "match_manager"
const SPAWN_GROUP_FORMAT := "spawn_team_%d"
const NO_TEAM := -1                                # unresolvable damage source

@export var team_id: int = 0                       # 0 = TEAM_A (player), 1 = TEAM_B (opponents)
@export var respawn_delay: float = 3.0             # seconds dead before respawning
@export var spawn_index: int = 0                   # selects among the team's spawn markers

var _is_dead: bool = false
var _match_over: bool = false
var _health: Health
var _parent_body: Node3D
var _mesh: MeshInstance3D
var _collision: CollisionShape3D
var _attack_hitbox: Area3D
var _match_manager: Node
var _spawn_point: Node3D


func _ready() -> void:
	_parent_body = get_parent() as Node3D
	if _parent_body != null:
		_health = _parent_body.get_node_or_null("Health") as Health
		_mesh = _parent_body.get_node_or_null("Mesh") as MeshInstance3D
		_collision = _parent_body.get_node_or_null("CollisionShape3D") as CollisionShape3D
		_attack_hitbox = _parent_body.get_node_or_null("AttackHitbox") as Area3D
	_match_manager = get_tree().get_first_node_in_group(MATCH_MANAGER_GROUP)
	_resolve_spawn_point()

	if _match_manager == null:
		push_warning("[Combatant] " + _owner_name() + ": no node in group '"
				+ MATCH_MANAGER_GROUP + "' — kills are not scored and respawn is not "
				+ "gated by match end.")
	else:
		# match_ended is emitted by the same call that sets phase = ENDED, so this flag is
		# equivalent to querying MatchManager.get_phase() == ENDED (AC-M3-10).
		_match_manager.match_ended.connect(_on_match_ended)

	if _health == null:
		push_warning("[Combatant] " + _owner_name()
				+ ": no sibling 'Health' node — death will never be observed.")
	else:
		_health.died.connect(_on_died)


func get_team_id() -> int:
	return team_id


func is_dead() -> bool:
	return _is_dead


# --- Death -> kill attribution -> respawn scheduling ---------------------------------

func _on_died() -> void:
	if _is_dead:
		return
	_is_dead = true
	combatant_died.emit(team_id)
	_attribute_kill()
	_disable_combatant()
	if not _match_over:
		get_tree().create_timer(respawn_delay).timeout.connect(_respawn)


func _attribute_kill() -> void:
	if _match_manager == null:
		return
	var source: Node = _health.last_damage_source if _health else null
	var scorer_team := _resolve_team(source)
	if scorer_team >= 0:
		_match_manager.register_kill(scorer_team, team_id)


## Maps an attacker node -> its team_id.  Returns NO_TEAM (-1) when unresolvable, so the
## death still processes (disable + respawn) but no team scores (§6.9 safe degradation).
func _resolve_team(source: Node) -> int:
	if source == null or not is_instance_valid(source):
		push_warning("[Combatant] " + _owner_name() + ": died with no damage source — "
				+ "kill not attributed, no score awarded.")
		return NO_TEAM
	var combatant := source.get_node_or_null("Combatant")
	if combatant != null and combatant.has_method("get_team_id"):
		return combatant.get_team_id()
	push_warning("[Combatant] " + _owner_name() + ": damage source '" + str(source.name)
			+ "' has no Combatant child — kill not attributed, no score awarded.")
	return NO_TEAM


# --- Disable / enable cycle (in place — the body is never removed) -------------------

func _disable_combatant() -> void:
	if _collision:
		_collision.disabled = true
	if _mesh:
		_mesh.visible = false
	if _parent_body:
		_parent_body.set_physics_process(false)
	if _attack_hitbox:
		_attack_hitbox.set_physics_process(false)


func _respawn() -> void:
	if _match_over:
		return
	_is_dead = false
	if _spawn_point and _parent_body:
		_parent_body.global_position = _spawn_point.global_position
	if _collision:
		_collision.disabled = false
	if _mesh:
		_mesh.visible = true
	if _health:
		_health.reset()
	if _parent_body:
		_parent_body.set_physics_process(true)
	if _attack_hitbox:
		_attack_hitbox.set_physics_process(true)
	combatant_respawned.emit(team_id)


func _on_match_ended(_winner: int) -> void:
	_match_over = true
	if _attack_hitbox:
		_attack_hitbox.set_physics_process(false)


# --- Spawn point resolution (by group, robust against scene-tree restructuring) ------

func _resolve_spawn_point() -> void:
	var group_name := SPAWN_GROUP_FORMAT % team_id
	var spawns := get_tree().get_nodes_in_group(group_name)
	if spawns.is_empty():
		# Safe fallback per §11: the combatant respawns in place instead.
		push_warning("[Combatant] " + _owner_name() + ": group '" + group_name
				+ "' is empty — respawning in place.")
		return
	var index := spawn_index % spawns.size()
	if index < 0:
		index += spawns.size()
	_spawn_point = spawns[index] as Node3D


## Diagnostic label for warnings: the owning body's name when available.
func _owner_name() -> String:
	return str(_parent_body.name) if _parent_body != null else str(name)
