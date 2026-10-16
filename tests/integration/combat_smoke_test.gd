extends SceneTree
## Headless integration test for Milestone 2 -- Basic Combat (Agent C / QA).
##
## Harness style copied from tests/integration/movement_smoke_test.gd (Milestone 1):
## extends SceneTree, driven entirely by `await physics_frame` + Input.action_press/release,
## prints "CHECK <name> = <bool>" per case, prints "ALL_TESTS_PASS=<bool>", quit(0) / quit(1).
##
## Run with the Godot 4.7.2 console binary:
##   Godot_v4.7.2-stable_win64_console.exe --headless --path <ArenaBattle> ^
##       --script res://tests/integration/combat_smoke_test.gd
##
## Spec cases (all six, in order):
##   1. hit_in_range_and_arc  - dummy 1.5 m in front (world -Z), one swing -> health 75
##   2. miss_out_of_range     - dummy 3.0 m in front (> attack_range 2.0)  -> health 100
##   3. miss_outside_arc      - dummy 1.5 m BEHIND (+Z => 180 deg > 60)    -> health 100
##   4. cooldown_gate         - 2nd swing inside the 0.6 s cooldown        -> health 75, not 50
##   5. lethal_and_died       - swings spaced past the cooldown until dead -> health 0, died x1
##   6. self_hit_exclusion    - Player never in AttackHitbox overlaps      -> no self damage/error
## Plus 3 clearly-labelled NON-spec checks: a cooldown positive control (guards case 4 against a
## false pass) and two testbed-integrity gates (the run is untrustworthy if they fail).
##
## State isolation: Main.tscn is re-instantiated for EVERY case (fresh Health = 100, fresh melee
## cooldown), the DummyTarget authored into Main.tscn is deleted, and a fresh DummyTarget.tscn
## instance is spawned per case. No state can leak between cases.
##
## Implementation facts this harness is designed around (verified by reading the code AND by
## measuring runtime behaviour -- see the two HARNESS NOTES below):
##   * melee_attacker.gd detects the swing in _physics_process via
##     Input.is_action_just_pressed("attack").
##     HARNESS NOTE 1 (measured, see _calibrate_input_lag): when Input.action_press() is called
##     from a coroutine resumed on SceneTree.physics_frame, the swing does NOT resolve on the next
##     physics frame -- it resolves two physics frames later, and an Input.action_release() in
##     between does NOT cancel it. Also, calling action_press() again before the pending swing
##     resolves OVERWRITES Input's pressed_physics_frame, so the pending swing is lost. Hence:
##       - the lag is measured at runtime instead of hardcoded;
##       - every read of health/cooldown happens at least `lag` frames after the press;
##       - the tightest achievable back-to-back swing is `lag` frames apart (33 ms at 60 Hz),
##         still 18x inside the 0.6 s cooldown, so case 4 remains a valid gate test;
##       - case 4 traces is_action_just_pressed() per frame to prove the 2nd press WAS registered
##         by the input system and was rejected by the cooldown gate (not silently swallowed).
##   * AttackHitbox is an Area3D (collision_mask = 4 = DamageableTarget). Area3D overlap lists only
##     refresh on a physics frame, so every spawn is followed by OVERLAP_SETTLE_FRAMES awaited
##     physics frames BEFORE any swing.
##   * HARNESS NOTE 2 (measured): the DummyTarget transform MUST be assigned before add_child().
##     add_child() creates the StaticBody3D at its default origin -- inside the player capsule --
##     and the later global_position write reaches the physics server one frame late, so
##     move_and_slide()'s recovery pass shoves the player ~1 m sideways and silently invalidates
##     every distance/angle under test. CHECK testbed_player_stationary guards against this.
##   * Health.reset() exists in M3; fresh scenes still isolate health, cooldown and lifecycle state.
##   * DummyTarget is a StaticBody3D in group "damageable" exposing apply_damage()/get_health().
##
## Typing note: script-defined members (get_health(), Health.died, attack_range,
## _cooldown_remaining) are NOT visible through statically typed Node3D/Area3D handles, so those
## are read through untyped Variant handles. Engine API stays strongly typed.

const MAIN_SCENE := "res://scenes/main/Main.tscn"
const DUMMY_SCENE := "res://scenes/targets/DummyTarget.tscn"

# project.godot does not override the physics tick rate -> 60 Hz, 1 frame = 1/60 s = 0.016667 s.
const PLAYER_SETTLE_FRAMES := 12    # let the CharacterBody3D land and come to rest on the floor
const OVERLAP_SETTLE_FRAMES := 4    # Area3D needs >= 1 physics frame to refresh overlaps; use 4
const POST_ATTACK_FRAMES := 4       # let the swing resolve + signals propagate before asserting
const COOLDOWN_CLEAR_FRAMES := 45   # 45/60 = 0.75 s > attack_cooldown (0.6 s)
const MAX_CALIBRATION_FRAMES := 8   # bound for the input-lag probe
const DRIFT_TOLERANCE_M := 0.01     # the player must not move while the testbed is built

const FRONT_OFFSET := Vector3(0.0, 0.0, -1.5)  # in range (1.5 <= 2.0), in arc (0 deg <= 60 deg)
const FAR_OFFSET := Vector3(0.0, 0.0, -3.0)    # out of range (3.0 > 2.0)
const BEHIND_OFFSET := Vector3(0.0, 0.0, 1.5)  # in range but behind -> 180 deg > 60 deg half-arc

var _checks: Array[String] = []
var _died_counter: int = 0
var _attack_lag_frames: int = 2      # calibrated at runtime by _calibrate_input_lag()
var _max_player_drift: float = 0.0   # testbed integrity: player must stay where it settled
var _harness_ok: bool = true


func _init() -> void:
	_run()


func _run() -> void:
	print("=== ArenaBattle M2 combat_smoke_test (headless) ===")
	await _calibrate_input_lag()
	await _case_1_hit_in_range_and_arc()
	await _case_2_miss_out_of_range()
	await _case_3_miss_outside_arc()
	await _case_4_cooldown_gate()
	await _case_5_lethal_and_died()
	await _case_6_self_hit_exclusion()
	# Supplementary probe (NOT one of the 6 spec cases, NOT part of ALL_TESTS_PASS):
	await _diagnostic_attack_range_boundary()

	print("--- TESTBED INTEGRITY (non-spec; invalidates the run above if false) ---")
	print("  max_player_drift_m=", "%0.6f" % _max_player_drift,
			" (tolerance ", DRIFT_TOLERANCE_M, " m) measured_attack_lag_frames=", _attack_lag_frames)
	_record("testbed_player_stationary", _max_player_drift < DRIFT_TOLERANCE_M)
	_record("testbed_input_timing_calibrated", _harness_ok)

	var all_pass := true
	for entry in _checks:
		if not entry.ends_with("=true"):
			all_pass = false
	print("ALL_TESTS_PASS=", all_pass)
	quit(0 if all_pass else 1)


# --------------------------------------------------------------------------- helpers

func _record(case_name: String, passed: bool) -> void:
	print("CHECK ", case_name, " = ", passed)
	_checks.append("%s=%s" % [case_name, passed])


func _wait(frames: int) -> void:
	for _i in frames:
		await physics_frame


## One swing. `Input.action_press` resolves `_attack_lag_frames` physics frames later
## (measured by _calibrate_input_lag), then the action is released so the next press
## produces a genuine just_pressed transition.
func _fire_attack() -> void:
	Input.action_press("attack")
	await _wait(_attack_lag_frames)
	Input.action_release("attack")
	await _wait(POST_ATTACK_FRAMES)


## Presses "attack" and traces is_action_just_pressed() + _cooldown_remaining + target health on
## every physics frame until the swing resolves, then releases. The trace is direct evidence that
## the input system registered the press, so a non-hit can only be a range/arc/cooldown gate.
func _press_attack_traced(atk: Variant, dummy: Variant) -> Array[String]:
	Input.action_press("attack")
	var trace: Array[String] = []
	for f in _attack_lag_frames:
		await physics_frame
		trace.append("frame+%d[just_pressed=%s cooldown=%0.4f dummy_health=%0.1f]" % [
			f + 1, Input.is_action_just_pressed("attack"), atk._cooldown_remaining,
			dummy.get_health()])
	Input.action_release("attack")
	return trace


## Instantiates a fresh Main.tscn, deletes its authored dummy, lets the player settle and
## (optionally) spawns a fresh DummyTarget at player.global_position + offset.
func _setup(dummy_offset: Vector3, spawn_dummy: bool) -> Dictionary:
	var main: Node3D = load(MAIN_SCENE).instantiate()
	root.add_child(main)

	var player: CharacterBody3D = main.get_node("Player")
	var hitbox: Area3D = player.get_node("AttackHitbox")

	# M3 CHANGE (ADR-0010): Main.tscn no longer authors a single "DummyTarget" node. It now
	# instances TWO static opponents ("Opponent1", "Opponent2") that each carry a Combatant
	# (team_id=1) and an auto_attack hitbox (collision_mask=2 -> damages the Player). This M2
	# suite spawns its OWN fresh DummyTarget per case, so free the authored opponents here to
	# keep the M2 testbed isolated from M3 match / kill-attribution / auto-attack / respawn logic.
	# They sit ~17 m from the Player, so removing them changes NO M2 geometry or timing
	# calibration (player settle position, overlap settle, cooldown lag are all unaffected).
	for opponent_name in ["Opponent1", "Opponent2"]:
		var authored: Node = main.get_node_or_null(opponent_name)
		if authored != null:
			authored.queue_free()

	await _wait(PLAYER_SETTLE_FRAMES)
	var settled_at: Vector3 = player.global_position

	# A (attack-follows-facing): the swing now travels along the Mesh front (+Z), not the camera.
	# Orient the stationary player to face world -Z so the front/behind/far offsets below (defined
	# on -Z / +Z) resolve exactly as they did under the old camera-aim convention. The player never
	# receives movement input here, so _face_movement_direction leaves this yaw untouched.
	(player.get_node("Mesh") as Node3D).rotation.y = PI

	var dummy: Node3D = null
	if spawn_dummy:
		dummy = load(DUMMY_SCENE).instantiate()
		# HARNESS NOTE 2: assign the transform BEFORE add_child. Main.tscn's root is at the
		# identity transform, so local == global (asserted by the print below).
		dummy.position = settled_at + dummy_offset
		main.add_child(dummy)
		await _wait(OVERLAP_SETTLE_FRAMES)

	var drift: float = _xzone(player.global_position, settled_at)
	_max_player_drift = maxf(_max_player_drift, drift)
	print("  testbed: main_global_transform=", main.global_transform,
			" player_settled_at=", settled_at, " player_drift_m=", "%0.6f" % drift)
	if drift > DRIFT_TOLERANCE_M:
		print("  HARNESS ERROR: the player was displaced by ", drift,
				" m while building the testbed -- distances/angles below are invalid!")

	return {"main": main, "player": player, "hitbox": hitbox, "dummy": dummy,
			"settled_at": settled_at}


func _teardown(ctx: Dictionary) -> void:
	Input.action_release("attack")
	var main: Node = ctx.get("main")
	if main != null and is_instance_valid(main):
		main.queue_free()
		await _wait(2)


func _names(bodies: Array[Node3D]) -> Array[String]:
	var out: Array[String] = []
	for b in bodies:
		out.append(String(b.name))
	return out


func _xzone(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _aim_forward(player: CharacterBody3D) -> Vector3:
	# A: the attack direction is the Mesh front (+Z), not the camera. Diagnostics only.
	var mesh: Node3D = player.get_node("Mesh")
	var basis: Basis = mesh.global_transform.basis
	var forward := Vector3(basis.z.x, 0.0, basis.z.z)
	return forward.normalized() if forward.length_squared() > 0.0001 else Vector3.ZERO


func _describe_geometry(ctx: Dictionary) -> void:
	var player: CharacterBody3D = ctx["player"]
	var hitbox: Area3D = ctx["hitbox"]
	var atk: Variant = hitbox  # dynamic handle -> exported script tunables
	var dummy: Variant = ctx.get("dummy")
	var forward := _aim_forward(player)
	print("  player=", player.global_position, " hitbox=", hitbox.global_position,
			" mesh_forward=", forward)
	print("  hitbox collision_layer=", hitbox.collision_layer,
			" collision_mask=", hitbox.collision_mask,
			" attack_range=", atk.attack_range, " attack_damage=", atk.attack_damage,
			" attack_cooldown=", atk.attack_cooldown, " attack_arc_deg=", atk.attack_arc_deg)
	if dummy != null:
		var to_body: Vector3 = dummy.global_position - hitbox.global_position
		var flat := Vector3(to_body.x, 0.0, to_body.z)
		var angle_deg := 0.0
		if flat.length_squared() > 0.0001:
			angle_deg = rad_to_deg(forward.angle_to(flat.normalized()))
		print("  dummy=", dummy.global_position,
				" xz_distance=", "%0.4f" % _xzone(dummy.global_position, hitbox.global_position),
				" angle_from_forward_deg=", "%0.2f" % angle_deg)
	var bodies: Array[Node3D] = hitbox.get_overlapping_bodies()
	print("  hitbox.get_overlapping_bodies()=", _names(bodies))


func _on_dummy_died() -> void:
	_died_counter += 1
	print("  [test] 'died' signal received (counter=", _died_counter, ")")


# ------------------------------------------------------------------- harness calibration

## Measures how many physics frames elapse between Input.action_press("attack") (called from a
## physics_frame continuation) and melee_attacker actually performing the swing. Detected via
## _cooldown_remaining flipping from negative to attack_cooldown.
func _calibrate_input_lag() -> void:
	print("--- HARNESS CALIBRATION: press -> swing resolution lag (no dummy in scene) ---")
	var ctx: Dictionary = await _setup(Vector3.ZERO, false)
	var hitbox: Area3D = ctx["hitbox"]
	var atk: Variant = hitbox

	Input.action_press("attack")
	var frames := 0
	var resolved := false
	while frames < MAX_CALIBRATION_FRAMES:
		await physics_frame
		frames += 1
		if atk._cooldown_remaining > 0.0:
			resolved = true
			break
	Input.action_release("attack")
	await _wait(POST_ATTACK_FRAMES)

	if resolved:
		_attack_lag_frames = frames
	else:
		_harness_ok = false
		print("  HARNESS ERROR: 'attack' never resolved within ", MAX_CALIBRATION_FRAMES, " frames.")
	print("DIAG measured_attack_lag_frames=", frames, " resolved=", resolved,
			" _cooldown_remaining=", "%0.4f" % atk._cooldown_remaining,
			" overlapping=", _names(hitbox.get_overlapping_bodies()))
	await _teardown(ctx)


# ------------------------------------------------------------------------- case 1

func _case_1_hit_in_range_and_arc() -> void:
	print("--- CASE 1: hit_in_range_and_arc ---")
	print("  steps: fresh Main + fresh dummy at player + (0,0,-1.5); settle ", OVERLAP_SETTLE_FRAMES,
			" physics frames; one swing; read get_health().")
	var ctx: Dictionary = await _setup(FRONT_OFFSET, true)
	var player: CharacterBody3D = ctx["player"]
	var dummy: Variant = ctx["dummy"]
	_describe_geometry(ctx)

	print("  health_before_swing=", "%0.4f" % dummy.get_health())
	await _fire_attack()
	var health_after: float = dummy.get_health()
	print("  health_after_swing=", "%0.4f" % health_after, " player_after_swing=", player.global_position)

	var expected := 75.0
	var passed: bool = is_equal_approx(health_after, expected)
	print("  EXPECTED=", expected, " ACTUAL=", health_after)
	_record("hit_in_range_and_arc", passed)
	await _teardown(ctx)


# ------------------------------------------------------------------------- case 2

func _case_2_miss_out_of_range() -> void:
	print("--- CASE 2: miss_out_of_range ---")
	print("  steps: fresh Main + fresh dummy at player + (0,0,-3.0) (xz distance 3.0 > range 2.0);")
	print("         settle; one swing; read get_health().")
	var ctx: Dictionary = await _setup(FAR_OFFSET, true)
	var player: CharacterBody3D = ctx["player"]
	var dummy: Variant = ctx["dummy"]
	var hitbox: Area3D = ctx["hitbox"]
	_describe_geometry(ctx)

	var bodies: Array[Node3D] = hitbox.get_overlapping_bodies()
	print("  dummy_inside_attack_area=", bodies.has(dummy))
	print("  health_before_swing=", "%0.4f" % dummy.get_health())
	await _fire_attack()
	var health_after: float = dummy.get_health()
	print("  health_after_swing=", "%0.4f" % health_after, " player_after_swing=", player.global_position)

	var expected := 100.0
	var passed: bool = is_equal_approx(health_after, expected)
	print("  EXPECTED=", expected, " ACTUAL=", health_after)
	_record("miss_out_of_range", passed)
	await _teardown(ctx)


# ------------------------------------------------------------------------- case 3

func _case_3_miss_outside_arc() -> void:
	print("--- CASE 3: miss_outside_arc ---")
	print("  steps: fresh Main + fresh dummy at player + (0,0,+1.5) (BEHIND => 180 deg > 60 deg")
	print("         half-arc, but xz distance 1.5 IS inside the 2.0 m hit sphere); settle; one swing.")
	var ctx: Dictionary = await _setup(BEHIND_OFFSET, true)
	var player: CharacterBody3D = ctx["player"]
	var dummy: Variant = ctx["dummy"]
	var hitbox: Area3D = ctx["hitbox"]
	_describe_geometry(ctx)

	var bodies: Array[Node3D] = hitbox.get_overlapping_bodies()
	var in_area: bool = bodies.has(dummy)
	print("  dummy_inside_attack_area=", in_area,
			"  <- must be true, so the miss is caused by the ARC gate, not by a non-overlap")
	print("  health_before_swing=", "%0.4f" % dummy.get_health())
	await _fire_attack()
	var health_after: float = dummy.get_health()
	print("  health_after_swing=", "%0.4f" % health_after, " player_after_swing=", player.global_position)

	var expected := 100.0
	var passed: bool = is_equal_approx(health_after, expected) and in_area
	print("  EXPECTED=", expected, " (and dummy must have been inside the Area3D)  ACTUAL=", health_after)
	_record("miss_outside_arc", passed)
	await _teardown(ctx)


# ------------------------------------------------------------------------- case 4

func _case_4_cooldown_gate() -> void:
	print("--- CASE 4: cooldown_gate ---")
	print("  steps: fresh Main + fresh dummy at player + (0,0,-1.5); swing #1 and WAIT for it to")
	print("         resolve; then release+re-press 'attack' in the very same inter-frame gap, so the")
	print("         2nd swing attempt resolves ", _attack_lag_frames, " physics frames (~",
			"%0.3f" % (_attack_lag_frames / 60.0), " s) after the 1st, deep inside the 0.6 s cooldown.")
	print("         NOTE: this is the tightest re-attack achievable -- pressing again BEFORE the")
	print("         pending swing resolves overwrites Input's pressed frame and the 1st swing is lost.")
	var ctx: Dictionary = await _setup(FRONT_OFFSET, true)
	var player: CharacterBody3D = ctx["player"]
	var dummy: Variant = ctx["dummy"]
	var hitbox: Area3D = ctx["hitbox"]
	var atk: Variant = hitbox  # dynamic handle -> _cooldown_remaining
	_describe_geometry(ctx)

	# Swing #1 -- wait for it to actually resolve before touching the input again.
	var trace1: Array[String] = await _press_attack_traced(atk, dummy)
	var health_after_first: float = dummy.get_health()
	var cd_after_first: float = atk._cooldown_remaining
	print("  swing #1 per-frame trace=", trace1)
	print("  after swing #1 resolved: health=", "%0.4f" % health_after_first,
			" _cooldown_remaining=", "%0.4f" % cd_after_first)

	# Swing #2 -- attempted at the earliest possible moment (same inter-frame gap).
	var trace2: Array[String] = await _press_attack_traced(atk, dummy)
	var health_after_second: float = dummy.get_health()
	var cd_after_second: float = atk._cooldown_remaining
	await _wait(POST_ATTACK_FRAMES)
	print("  swing #2 per-frame trace=", trace2)
	print("  after swing #2 attempt: health=", "%0.4f" % health_after_second,
			" _cooldown_remaining=", "%0.4f" % cd_after_second,
			" (> 0 on every traced frame => the cooldown gate rejected a registered press)")
	print("  player_after_both_swings=", player.global_position)

	var expected := 75.0
	var first_swing_landed: bool = is_equal_approx(health_after_first, expected)
	var second_swing_gated: bool = is_equal_approx(health_after_second, expected)
	var gate_was_active: bool = cd_after_first > 0.0 and cd_after_second > 0.0
	var second_press_registered := false
	for line in trace2:
		if line.contains("just_pressed=true"):
			second_press_registered = true
	var passed: bool = first_swing_landed and second_swing_gated and gate_was_active \
			and second_press_registered
	print("  EXPECTED=", expected, " (only ONE 25 dmg hit landed, NOT 50)  ACTUAL=", health_after_second)
	print("  ACTUAL detail: swing1_landed=", first_swing_landed,
			" swing2_press_registered_by_input=", second_press_registered,
			" swing2_gated=", second_swing_gated, " cooldown_active_both_reads=", gate_was_active)
	_record("cooldown_gate", passed)

	# Positive control (guards against a false pass): prove the very same press/release pattern
	# DOES land once the cooldown has elapsed. If this failed, the gate check above proved nothing.
	await _wait(COOLDOWN_CLEAR_FRAMES)
	await _fire_attack()
	var health_after_control: float = dummy.get_health()
	print("  control: waited ", COOLDOWN_CLEAR_FRAMES, " frames (0.75 s > 0.6 s cooldown) then swung again")
	print("           health=", "%0.4f" % health_after_control,
			" _cooldown_remaining=", "%0.4f" % atk._cooldown_remaining)
	_record("cooldown_clears_and_allows_next_swing", is_equal_approx(health_after_control, 50.0))
	await _teardown(ctx)


# ------------------------------------------------------------------------- case 5

func _case_5_lethal_and_died() -> void:
	print("--- CASE 5: lethal_and_died ---")
	print("  steps: fresh Main + fresh dummy at player + (0,0,-1.5); connect Health.died to a")
	print("         counter; swing, wait ", COOLDOWN_CLEAR_FRAMES,
			" frames (0.75 s > 0.6 s cooldown), repeat until health == 0;")
	print("         then swing once more after death and re-read health + died counter.")
	var ctx: Dictionary = await _setup(FRONT_OFFSET, true)
	var player: CharacterBody3D = ctx["player"]
	var dummy: Variant = ctx["dummy"]
	var health_node: Variant = dummy.get_node("Health")
	_died_counter = 0
	health_node.died.connect(_on_dummy_died)
	_describe_geometry(ctx)

	var never_negative := true
	var trajectory: Array[String] = []
	var swings := 0
	while swings < 8:
		await _fire_attack()
		swings += 1
		var h: float = dummy.get_health()
		trajectory.append("%0.1f" % h)
		print("  swing ", swings, " -> health=", "%0.4f" % h, " died_counter=", _died_counter)
		if h < 0.0:
			never_negative = false
		if h <= 0.0:
			break
		await _wait(COOLDOWN_CLEAR_FRAMES)

	var reached_zero: bool = is_equal_approx(dummy.get_health(), 0.0)
	var died_exactly_once: bool = (_died_counter == 1)
	print("  after ", swings, " swings: health=", "%0.4f" % dummy.get_health(),
			" died_counter=", _died_counter, " trajectory=", trajectory)

	# Extra attack after death must be a no-op (Health.apply_damage early-returns at <= 0).
	await _wait(COOLDOWN_CLEAR_FRAMES)
	await _fire_attack()
	await _wait(POST_ATTACK_FRAMES)
	var health_after_extra: float = dummy.get_health()
	print("  after post-death swing: health=", "%0.4f" % health_after_extra,
			" died_counter=", _died_counter, " player=", player.global_position)

	var extra_is_noop: bool = is_equal_approx(health_after_extra, 0.0) and (_died_counter == 1)
	var passed: bool = reached_zero and died_exactly_once and extra_is_noop \
			and never_negative and (swings == 4)
	print("  EXPECTED: health clamps to 0.0 in exactly 4 x 25 dmg swings, never negative,")
	print("            'died' fired exactly once, post-death swing is a no-op")
	print("  ACTUAL:   zero=", reached_zero, " never_negative=", never_negative,
			" died_once=", died_exactly_once, " extra_noop=", extra_is_noop, " swings=", swings)
	_record("lethal_and_died", passed)
	await _teardown(ctx)


# ------------------------------------------------------------------------- case 6

func _case_6_self_hit_exclusion() -> void:
	print("--- CASE 6: self_hit_exclusion ---")
	print("  steps: fresh Main with NO dummy at all; read AttackHitbox.get_overlapping_bodies();")
	print("         assert the Player is absent (layer/mask exclusion); fire a swing and assert")
	print("         nothing errors and the Player survives; then spawn a dummy in front and")
	print("         re-assert the Player is STILL excluded while the dummy IS detected.")
	var ctx: Dictionary = await _setup(Vector3.ZERO, false)
	var main_node: Node3D = ctx["main"]
	var player: CharacterBody3D = ctx["player"]
	var hitbox: Area3D = ctx["hitbox"]
	var atk: Variant = hitbox  # dynamic handle -> _cooldown_remaining

	await _wait(OVERLAP_SETTLE_FRAMES)
	var bodies: Array[Node3D] = hitbox.get_overlapping_bodies()
	print("  player collision_layer=", player.collision_layer,
			" hitbox collision_mask=", hitbox.collision_mask,
			" mask AND layer=", (hitbox.collision_mask & player.collision_layer))
	print("  overlapping_bodies (empty scene)=", _names(bodies))
	var mask_excludes_player: bool = (hitbox.collision_mask & player.collision_layer) == 0
	var player_absent_empty: bool = not bodies.has(player)
	# M3 SPEC CHANGE (ADR-0010): the Player NOW joins group "damageable" so the static opponents'
	# auto_attack hitbox (collision_mask=2 -> Player layer) can damage it. The former M2
	# sub-condition `player_not_damageable` (= NOT in "damageable") is therefore INVALID under the
	# approved M3 spec and has been REMOVED from the pass conjunction below. Self-hit exclusion was
	# NEVER guaranteed by group membership -- it is guaranteed by the collision layer/mask: the
	# Player's own AttackHitbox uses collision_mask=4 (layer 3 DamageableTarget) while the Player
	# body is on layer 2, so (mask & layer) == 0 and the hitbox can physically never overlap the
	# Player. That invariant is still asserted, unchanged, by mask_excludes_player +
	# player_absent_empty + player_absent_with_dummy + no_bodies_when_empty. The line below is kept
	# purely as INFORMATIONAL diagnostics (expected TRUE under M3); it does NOT affect pass/fail.
	var player_is_damageable_m3: bool = player.is_in_group("damageable")
	var no_bodies_when_empty: bool = bodies.is_empty()

	# Firing with nothing but the player present must not error out.
	await _fire_attack()
	await _wait(POST_ATTACK_FRAMES)
	var player_ok_after_swing: bool = is_instance_valid(player) and player.is_inside_tree()
	print("  swing with only the player present: _cooldown_remaining=", "%0.4f" % atk._cooldown_remaining,
			" (> 0 proves _perform_attack ran to completion) player_valid=", is_instance_valid(player),
			" player_in_tree=", player.is_inside_tree())

	# Now the realistic scene: a damageable dummy in front AND the player inside the hit sphere.
	var dummy_node: Node3D = load(DUMMY_SCENE).instantiate()
	dummy_node.position = player.global_position + FRONT_OFFSET  # before add_child, see NOTE 2
	main_node.add_child(dummy_node)
	var dummy: Variant = dummy_node
	ctx["dummy"] = dummy
	await _wait(COOLDOWN_CLEAR_FRAMES)
	await _wait(OVERLAP_SETTLE_FRAMES)
	_describe_geometry(ctx)
	var bodies2: Array[Node3D] = hitbox.get_overlapping_bodies()
	var player_absent_with_dummy: bool = not bodies2.has(player)
	var dummy_present: bool = bodies2.has(dummy_node)
	await _fire_attack()
	await _wait(POST_ATTACK_FRAMES)
	var dummy_took_damage: bool = is_equal_approx(dummy.get_health(), 75.0)
	var player_still_ok: bool = is_instance_valid(player) and player.is_inside_tree()
	print("  after swing with dummy present: dummy_health=", "%0.4f" % dummy.get_health(),
			" player_valid=", is_instance_valid(player), " player=", player.global_position,
			" overlapping=", _names(bodies2))

	# NOTE: `player_not_damageable` was REMOVED from this conjunction (M3 spec change, see comment
	# above). Every collision mask / overlap assertion is retained EXACTLY as in M2 -- none were
	# weakened. Self-hit exclusion is proven by layer/mask, not by "damageable" group membership.
	var passed: bool = mask_excludes_player and player_absent_empty \
			and no_bodies_when_empty and player_ok_after_swing and player_absent_with_dummy \
			and dummy_present and dummy_took_damage and player_still_ok
	print("  EXPECTED: Player never in get_overlapping_bodies() (hitbox mask=4 excludes Player")
	print("            layer=2), both swings complete without script errors, dummy takes its 25 dmg.")
	print("            (M3: Player IS in 'damageable' now -- exclusion is by layer/mask, not group.)")
	print("  ACTUAL:   mask_excludes_player=", mask_excludes_player,
			" player_absent_empty_scene=", player_absent_empty,
			" player_absent_with_dummy=", player_absent_with_dummy,
			" player_is_damageable_m3(informational)=", player_is_damageable_m3,
			" no_bodies_when_empty=", no_bodies_when_empty, " dummy_detected=", dummy_present,
			" player_ok_after_both_swings=", (player_ok_after_swing and player_still_ok),
			" dummy_health=", "%0.4f" % dummy.get_health())
	_record("self_hit_exclusion", passed)
	await _teardown(ctx)


# --------------------------------------------------- supplementary diagnostic (not scored)

## Out-of-spec probe: is `attack_range` enforced centre-to-centre, or only implicitly by the
## Area3D sphere (radius = attack_range) overlapping the target's collision shape?
## A 1x2x1 dummy centred 2.2 m away has its nearest face 1.7 m away -> inside the sphere but
## outside a 2.0 m centre distance. Reported as DIAG; does NOT affect ALL_TESTS_PASS.
func _diagnostic_attack_range_boundary() -> void:
	print("--- DIAGNOSTIC (not one of the 6 spec cases): attack_range boundary at 2.2 m ---")
	var ctx: Dictionary = await _setup(Vector3(0.0, 0.0, -2.2), true)
	var dummy: Variant = ctx["dummy"]
	var hitbox: Area3D = ctx["hitbox"]
	_describe_geometry(ctx)
	var in_area: bool = hitbox.get_overlapping_bodies().has(dummy)
	await _fire_attack()
	var damaged: bool = dummy.get_health() < 100.0
	print("DIAG centre_distance_2.2m_inside_area=", in_area,
			" centre_distance_2.2m_took_damage=", damaged,
			" health=", "%0.4f" % dummy.get_health())
	print("DIAG note: melee_attacker._perform_attack() enforces centre-to-centre attack_range.")
	print("DIAG note: Area3D overlap alone is insufficient; its sphere can overlap a target")
	print("DIAG note: whose centre is outside attack_range; that target must remain undamaged.")
	await _teardown(ctx)
