# Animation foundation checkpoint — 2026-10-19

> Historical checkpoint: current walk/run clips, speeds, thresholds and validation have since changed. See HUMAN_MOTION_CHECKPOINT.md for the latest implementation.

The first A0/A1 implementation batch is ready for visual review. This is an initial
transition pass, not completion of the full character-animation plan.

## Review in Godot

Open scenes/characters/AnimationReviewGallery.tscn and press F6 (Run Current Scene).
The normal F5 game entry remains unchanged. Both characters appear together.

- Auto mode samples idle, walk, run and speeds near transition thresholds.
- Select a named clip to inspect it on both characters; use Restart for one-shots.
- Pause, Step 1/30 s, and 0.25x / 0.5x / 1x playback support close inspection.
- Characters stay in place. This scene does not simulate combat or networking.

## Implemented

Locomotion changes now blend over 0.15 seconds. Run enters at 8 m/s and exits below
7.5 m/s; walking enters at 0.5 m/s and exits below 0.4 m/s. These separate enter/exit
thresholds reduce repeated clip switching around noisy replicated speeds.
Accepted attacks retain their existing immediate animation start.

Each animation player now owns copies of its animation resources before loop modes
are configured. The model preview uses the same helper. This prevents one character
from changing another's loops. Copies add memory overhead; import-time configuration
and measured performance budgets remain future work.

Files: scripts/player/character_animation.gd, scripts/player/animation_resources.gd,
scripts/characters/player_model_preview.gd, scripts/characters/animation_review_gallery.gd,
scenes/characters/AnimationReviewGallery.tscn and tests/integration/animation_foundation_smoke_test.gd.

## Baseline inventory

| Model | Bones | Mesh nodes | Existing clips |
|---|---:|---:|---|
| Arclight | 20 | 135 | Idle, Walk, Run, Jump, Attack_Slash, Attack_Backhand, Attack_Overhead, Attack_Thrust, Attack_Combo |
| Ashen Warden | 26 | 214 | Same nine clips |

The model-import test confirms unit scale and that attack animation drives each
skeleton. These node counts are inventory, not evidence that performance targets pass.

## Validation

All 286 automated checks passed: 28 new animation checks, 123 existing local checks,
67 two-client checks and 68 eight-client checks. Godot import and final gallery
regression passed. Multiplayer tests use local processes, not physical PCs.

28 new checks cover both models' speed transitions, attack playback/release,
gallery isolation, same-model resource independence, manual selection and paused stepping.
Existing local, two-client and eight-client regression results are recorded in the
chat workspace work/animation-*.log files. The gallery was rendered and inspected
at 1280x720; human motion-quality acceptance and physical two-PC tests remain pending.

## Next animation work

Finish A1 locomotion authoring and visible motion review: starts/stops, turning,
directional strafing, separate jump/fall/landing and foot sliding. Then cover hit
reactions and knockback travel/recovery for both rigs, including directional hits,
walls, airborne hits, repeated impacts, interruption and death priority.

Magic/energy casting remains tied to the toggled lock/aim view. Skills, parry, dash,
block, death/respawn and knockback clips are still planned, not implemented by this
gallery. Knockback displacement must eventually be server-authoritative.
Model swapping/rebinding, authoritative grounded/action state and attack phase
timing also remain open. The replica vertical-velocity grounding heuristic and
full-clip attack locomotion latch are unchanged limitations.

The existing Demo 1 ZIP has not been rebuilt with this batch. No commits or pushes
were made. New gameplay mechanics or balance changes were not introduced.
