# Human walk/run checkpoint — 2026-10-19

Walk and run now use adapted human motion capture on Arclight and Ashen Warden in
the actual game. The owner's armor reference and timing templates were read and
preserved under docs/references/armor/. A research agent investigated sources and
a QA agent independently reviewed gait/cadence pitfalls. The primary agent authored
the retargeting and runtime changes. Blender MCP was used to inspect the connection
and process motion data; background Blender created the editable review artifact.

## What changed

- CMU 35_01 replaces Walk; CMU 35_17 replaces Run on both rigs. Original GLBs remain
  preserved. Per-instance animation libraries install the new clips at runtime.
- Walking now travels at 1.2 m/s; running at 3.8 m/s, as authorized by the owner.
  These are authored gameplay choices, not measured armor performance limits.
- Animation rate follows actual speed divided by capture-derived nominal speed.
  Walk/run transitions preserve normalized gait phase. Attack, idle and airborne
  playback reset to normal rate. No armor-wide slowdown or mass was invented.
- Auto gallery speed samples and slow playback reflect the new cadence settings.
- CMU 16_01 jump and CMU 143_40 sideways-walk captures are retargeted for gallery
  review. They are not new runtime jump/strafe state integration.

The source BVHs include a calibration frame, which is removed. A matching full
stride is extracted, phased near left contact, closed and sampled at roughly 30 Hz.
Retargeting aligns the existing bone directions to captured joint trajectories,
retains pelvic vertical motion and adjusts ankle height for each rig. This is
animation adaptation, not a validated physics or armor simulator. Sources and
limitations are documented in HUMAN_MOTION_RESEARCH.md.

## Review

Open scenes/characters/AnimationReviewGallery.tscn and press F6. Walk and Run show
the new clips; Capture/JumpCapture and Capture/StrafeCapture show the other captures.
Normal F5 starts the game with the new movement and animation defaults.

The chat outputs include walk-human-reference.gif, run-human-reference.gif and
Human-Motion-Review.blend. The GIFs play a full source-cadence cycle on both rigs
from the side. The Blender file is an editable review copy with named Human Walk
and Human Run actions, not a replacement for the original character source files.
Both rigs start with Walk; select matching Human Run actions in the Action Editor
and set the end frame 24 for a run preview. Game playback scales cadence with speed.

## Verification

418 automated checks passed on the current project: 48 new gait checks, 28 gallery
checks, 84 reaction-draft checks, 123 existing local gameplay checks, 67 two-client
ENet checks and 68 eight-client checks. New checks sample 121 poses per cycle on both
rigs, checking finite transforms, forward knee bend, opposite arm/leg coordination,
pelvic movement, loop position, body immobility, phase changes and cadence resets.

Side-view renders were inspected at multiple phases of both cycles. Opposite arm/
leg correlations are about 0.99 for Walk and 0.82 for Run; pelvic vertical ranges
are about 5.3 cm and 7.9 cm. These are diagnostic values, not guarantees of realism.
The ankle-path metric includes foot roll and is not a pure foot-sliding measure;
the source and target retain similar low-ankle travel. Exact footplant constraints,
toe contacts and continuous loop velocity still require visual polish.

The multiplayer fixture originally assumed over 0.5 m of movement during its short
walk window. It now waits for configured-speed-relative displacement and checks
the speed bound; security/outcome tests pass. Physical two-PC testing and the
owner's acceptance of motion quality remain pending. Test logs: work/human-*.log.

## Current limits and next steps

Natural speeds intentionally change travel time and pursuit/combat spacing. Review
that feel in the arena. Foot IK, start/stop/turn clips, weapon and plate clearance,
cape motion, terrain and diagonal gait blending remain polish work. Camera-locked
sideways/backward gameplay still needs proper directional-state integration.
The existing replica airborne heuristic and full-body attack locomotion latch
remain open. Jump physics and attack timing were not changed in this batch.

Other researched references cover starts/stops, backward walk, side steps, blocks
and get-ups. Dash/parry/magic actions require authored adaptations and their own
gameplay contracts. Knockback drafts remain available but are not capture-based.

Demo1ZIP has not been rebuilt. No commits or pushes were made.

The saved Blender review was reopened successfully and passed 24 checks comparing baked walk poses with the game skeleton poses. Capture-derived stationary-ankle annotations and explicit uncertainty are saved in docs/references/armor/character-motion-records.json.
