# Adaptive stairs, ledge climbing and wall jumping

Implemented on 2026-10-21 for the local character motion harness in Main and
MotionTestCourse. Open scenes/characters/MotionTestCourse.tscn and press F6.

## Controls

| Action | Control |
| --- | --- |
| Walk / run up or down stairs | WASD / Shift; no jump required |
| Grab reachable ledge / mantle low ledge | E while facing it |
| Automatic airborne ledge catch | Move toward the ledge while descending or near jump apex |
| Climb from a hang | E or Space |
| Shimmy sideways along a ledge | A/D while hanging; camera-relative movement projects along the ledge |
| Adjust sideways at the start of a climb | A/D before the weight-transfer commitment |
| Drop from a hang | C |
| Wall slide | Hold movement into a wall while falling |
| Wall jump | Space while airborne beside a wall |
| Repeat wall jumps | Alternate between opposing walls |
| Reset / change test area | Backspace / 1–6 |

## Stair behavior

The course contains independent flights with 15, 30 and 40 cm risers. The local
controller exports max_step_height (default 0.4 metres). Ascent tests sweep the
whole capsule upward, forward and down, check headroom, and ray-check the actual
walkable tread on the obstructing static world body. Only a validated stair
contact can temporarily treat the rounded capsule toe as support. Walls,
ceilings and characters do not become climbable stair surfaces. The ordinary
slope limit is restored after the move. Descent uses bounded support snapping;
jumping bypasses stepping and preserves the upward impulse.

A short support grace bridges brief capsule edge contacts so the gait does not
flash into Jump between stair treads. Mesh and camera corrections decay with
frame-rate-independent exponential smoothing. Their initial offsets are the
actual vertical displacement, so a taller riser produces a larger correction.
Dash/dodge movement uses the same stair motor.

Terrain rays sample each animated foot independently. A post-animation
SkeletonModifier3D applies bounded two-bone leg IK and foot slope alignment.
This preserves the authored swing while changing the foot target according to
the tread height. Each character binds its own live rig. Jumping and full-body
actions suspend foot correction. Teleports, character changes and death reset
presentation offsets. The collision capsule remains authoritative; cosmetic
smoothing never changes its position.

## Ledges and walls

The traversal motor owns normal, hang, climb and wall-slide states. Ledge probes
check facing, a vertical wall, a walkable top within 2.15 m of the capsule feet,
and capsule clearance along an upward-then-inward climb route. A low reachable
ledge can be mantled directly; higher ledges first enter a hang. Standing support
must exist at the destination, so a thin lip without a landing is rejected.
Climb duration scales with the vertical lift (about 0.85–1.30 s). The pose stages a pull, chest transfer, lead-leg plant and recovery. Hands release in sequence after support transfers; feet lift above the lip before advancing. Low mantles preserve grounded initial foot anchors. Every climb segment is swept;
a newly introduced obstacle interrupts it. Moving or removed ledges release the
hang. Dropping has a regrab delay, and death/reset clear traversal state.

Wall sliding requires inward movement intent and falling velocity. It caps
fall speed at 2 m/s. A wall jump launches at 7.5 m/s up and 5.2 m/s away, with
0.18 s of protected outward momentum. The same wall normal cannot be used for
another jump until landing or jumping from an opposing wall. Climbing, hanging,
sliding and the wall-jump push phase suppress competing combat actions.

Traversal hand/leg targets blend after the animation mixer, binding to each
character's own skeleton. These are procedural blockout poses using the current
rigs, intended for playtesting and later animation refinement.

## Industry references and adaptation

- [Unity step offset](https://docs.unity3d.com/ja/6000.0/ScriptReference/CharacterController-stepOffset.html)
  separates automatic step height from general movement and slope limits.
- [Unreal Character Movement](https://dev.epicgames.com/documentation/unreal-engine/API/Runtime/Engine/UCharacterMovementComponent)
  exposes a maximum step height as a character movement setting.
- [Epic foot-placement pelvis settings](https://dev.epicgames.com/documentation/en-us/unreal-engine/python-api/class/FootPlacementPelvisSettings?application_version=5.2)
  describe actor-motion compensation and bounded pelvis interpolation. Here,
  bounded mesh correction and terrain-aware leg targets serve that purpose.
- [Godot body sweeps](https://docs.godotengine.org/en/4.4/classes/class_physicsbody3d.html)
  provide test_move for checking the capsule route before committing a step.
- [Godot skeleton modifiers](https://docs.godotengine.org/en/stable/classes/class_skeletonmodifier3d.html)
  run pose adjustments after the animation mixer.

These are documented engine techniques adapted to this project. This does not
claim to reproduce a particular commercial game's animation system.

## Code responsibilities

- scripts/player/local_motion_test_player.gd: local movement integration and tuning.
- scripts/player/stair_motor.gd: collision-tested stair movement and support grace.
- scripts/player/stair_presentation.gd: mesh/camera smoothing and terrain sampling.
- scripts/player/terrain_foot_modifier.gd: two-bone leg correction.
- scripts/player/traversal_motor.gd: grabs, climbs, slides, jumps and cancellation.
- scripts/player/traversal_pose_modifier.gd: contact targets, boot frames and cosmetic clearance.
- scripts/player/traversal_geometry.gd: cached rest-model armor envelopes.
- CharacterAnimation and MotionTestControls: traversal pose selection and action arbitration.

The shared Player scene and multiplayer movement retain their existing movement
adapter. Multiplayer replication of traversal state/poses remains a separate
integration task. Moving platforms, ledge-corner transitions, animation-authored root motion and
production animation polish remain outside this pass.

## Verification

Godot 4.7.2 headless checks use --fixed-fps 60:

- stair_motion_smoke_test.gd: 34 checks, including three riser heights at walk/run,
  ascent/descent, no false Jump clip, actual IK corrections, low ceilings,
  overheight obstacles, jump impulse and the second character rig.
- traversal_smoke_test.gd: 34 checks, including reach/clearance, mantle/hang/climb,
  drop/regrab delay, disappeared ledges, changing obstructions, death, wall-slide
  input, outward jump impulse, same/opposite-wall rules and both character poses.
- motion_course_smoke_test.gd: live course geometry, six spawns, falling recovery,
  dash over stairs, hanging action rejection and zone reset.

These passed with exit 0 and no script errors. Existing movement,
playable-motion and parry/dash suites also passed. The playable-motion suite
retains its intentional unattributed-damage-source warning.

Rendered stair and ledge poses were inspected using the OpenGL compatibility
renderer. Full manual play acceptance remains necessary to judge camera feel,
animation timing, weapons during traversal and transitions at all approach angles.

## Climb and wall-jump animation revision

Sideways hanging uses a 0.65 m/s ledge-tangent motor with acceleration and bounded
capsule sweeps. Initial grabs and shimmy use the same two-hand support envelope.
A single hand reaches at a time; the other anchor remains fixed in world space.
Movement stops before unsupported ends, gaps, corners or obstructions. Climbing
revalidates the standing support at the new shimmy position. Lateral adjustment
is allowed during the first 24% of a climb, before weight transfer commits.

The IK solver clamps the actual target before both solve stages, uses stable
elbow/knee poles, preserves segment lengths and keeps wrist-relative rotation.
Wall jumps have a 0.55 s compression/extension/recovery pose and a timed facing
turn independent of the 0.18 s protected physical impulse. Weapons are temporarily
hidden during supported traversal and restored to their prior visibility.

See [animation review findings and acceptance](TRAVERSAL_ANIMATION_REVIEW.md).

The 2026-10-22 correction adds explicit hanging boot orientation and visible
armor clearance during climbs. The 44-check clearance and continuity suite observes complete
climbs on both rigs at three heights; see the linked animation review for
measurements, public motion references and the limits of these checks.
