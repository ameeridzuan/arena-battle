# Other animation checkpoint — 20 October 2026

Backward and sideways walking now use their own captured motions on both rigs.
Nine new motions per rig are available: three walking loops in gameplay and six
one-shot previews for starts/stops, turns and blocks. Forward Walk/Run retain the
previous owner-accepted clips and default speeds.

## Current availability

| Clip | Human capture | Duration | Integration |
|---|---|---:|---|
| BlockLeftCapture | 144_07.bvh | 1.850 s | Gallery preview |
| BlockRightCapture | 144_26.bvh | 1.850 s | Gallery preview |
| RunStartCapture | 143_03.bvh | 1.325 s | Gallery preview |
| RunStopCapture | 143_02.bvh | 1.383 s | Gallery preview |
| TurnLeftCapture | 69_18.bvh | 1.900 s | Gallery preview |
| TurnRightCapture | 69_16.bvh | 1.592 s | Gallery preview |
| Walk_Backward | 143_39.bvh | 0.625 s | Gameplay |
| Walk_Left | 143_40.bvh | 0.642 s | Gameplay |
| Walk_Right | 143_40.bvh | 0.692 s | Gameplay |

Sources: [CMU motion library](https://mocap.cs.cmu.edu/) and the
[BVH conversion index](https://raw.githubusercontent.com/una-dinosauria/cmu-mocap/master/cmu-mocap-index-text.txt).
The raw data, converter permission notes and checksums remain in assets/animations/source/.
The new libraries are assets/animations/directional/{arclight,ashen_warden}.tres.
Rebuild with tools/prepare_directional_motion.py using Blender Python, then
tools/build_directional_gaits.gd using Godot. The accepted forward libraries and
original model GLBs are preserved.

## Gameplay behavior

Directional selection uses actual horizontal velocity relative to Mesh facing,
including a rotated parent. Local +Z is forward; +X is right. An 8-degree angular
margin reduces clip flicker at diagonal boundaries. Compatible walking/run loops
retain their estimated contact phase when changing clips; each loop has its own
capture-derived cadence. This is cardinal selection, not a complete diagonal blend tree.

Ordinary walking remains 1.2 m/s and forward running 3.8 m/s. In local V aim view,
holding run while stepping sideways/backward uses an authored 1.8 m/s target cap.
The cap uses desired camera aim, so lagging mesh rotation does not change target
speed. Movement speed and animation share sector hysteresis: a side step stays capped
until below about 37 degrees from forward; a forward run changes to the side-step
cap beyond about 53 degrees. A fresh exact 45-degree diagonal uses the side-step cap.
This prevents 44/46-degree input jitter and a fast side-step in the 37–45-degree band. Fast sideways residual velocity still selects a side-step while slowing.
These are game-feel choices, not an armor mass simulation or measured limits.

The wire format is unchanged: existing velocity and mesh yaw drive directional
presentation. Multiplayer aim-lock input support is still pending; this does not
enable a new online aiming mode.

## Gallery review

Open scenes/characters/AnimationReviewGallery.tscn and press F6. Select Walk_Backward,
Walk_Left or Walk_Right for the integrated walking loops. The Direction/ modes show
RunStartCapture, RunStopCapture, TurnLeft/RightCapture and BlockLeft/RightCapture.
Use slow playback, pause and stepping to inspect feet, knees, hips, hands and weapons.

The one-shot previews strip horizontal root travel frame by frame. Source root
trajectory data is preserved for future integration. They never move the gameplay
body or award damage/defense. Turn retargeting retains captured torso/head rotations
as well as joint positions, instead of leaving the chest facing forward as hips turn.
The block captures are references for blocking gestures; they are not impact capture,
parry success, guard mechanics or proof of safe weapon/plate clearance.

## Validation and remaining work

The final batch passed 565 checks: 147 directional/preview checks plus the existing
418 checks, including two-client and eight-client ENet suites. The new coverage
includes the reviewer-discovered diagonal speed mismatch and first-input diagonals.
New checks cover rotated facing, cardinal directions, diagonal hysteresis, cadence,
phase transfer, aim speed caps, finite poses, loop closure, turn direction, raised
blocking arms, preview body immobility and unchanged health.

Research and read-only integration review were delegated to specialist agents.
The primary agent implemented assets/runtime and ran validation. The owner's armor
reference, motion template and constructed timing example continue to govern provenance:
unknown masses stay unknown, and there is no blanket armor slowdown.

Owner visual acceptance of these new clips remains pending. Exact footplants,
continuous loop velocity, diagonal blends, terrain IK, cape/weapon/plate clearance
and interruption polish remain open. Starts/stops and turns need state/acceleration
integration before gameplay use. Blocks need explicit guard/parry server rules.
The existing airborne heuristic and full-body attack latch remain separate work.

Demo 1 has not been rebuilt. No commits or pushes were made.

## Preview files

Backward walking: backward-human.gif. Left/right strafe: strafe-human.gif. Start/stop: start-stop-human.gif. Turns: turn-human.gif. Blocks: block-human.gif. These show both rigs at capture cadence, with the game body held stationary. They are review evidence, not owner visual acceptance or gameplay integration of the one-shots.

One eight-client attempt timed out during concurrent preview encoding. Its logs showed registration waits failing without script errors; a standalone rerun passed all 68 checks (ArenaBattle-M5-QA-2sfxp8z4). This is not an eight-player performance benchmark. Rendered walking, turning and block poses were inspected on both rigs. Preview GIF frame timing distributes 10 ms rounding to retain capture cadence.
