# Parkour traversal animation checkpoint

23 October 2026 · approved left-leg-driven climb implemented

## Current revision

Wall-slide follow-up: the slide now has a separate contact-driven brace rather
than the legacy generic pose. Palms face into the wall; staggered forefeet stay
below the pelvis and knees bend forward in stable anatomical hinge planes.
The detected wall plane supplies the contact anchors, and wall jumps start
from the matching left/right brace height. Measured slide marker errors are
below 0.001 mm on both rigs; sampled torso penetration is zero. The slide still
requires inward input, caps descent at 2 m/s and releases when input/contact
is lost. A small anticipatory clearance arc smooths the faster climb handoff.

Applied the approved interactive blocking and the supplied mannequin/pose-sheet
references to both Arclight and Ashen Warden. The hanging climb now takes 2.15 s (previously 2.40 s):
the left foot threads underneath the body and plants, the whole pelvis moves
forward/up as that leg extends, and the right leg stays extended behind until
the torso is halfway upright. Only then does the right foot follow. The left
sole stays fixed through this push; both feet are not required before rising.

The jump pose carries the pelvis/chest higher, with a lower free-leg recovery,
counterbalancing arms and a continuous turn away from the wall. The gameplay
launch impulse is unchanged. Pelvis yaw/roll, chest counter-rotation and explicit
rest-calibrated knee hinge frames replace unrestricted shortest-arc leg twist.
Traversal knee flexion is bounded at 150 degrees; grounded terrain IK retains
its existing default behavior. Released hands lift clear before unwinding.

The closer hanging-climb landing is checked again for floor support and capsule
sweep clearance. Grounded low mantles remain a separate motion family.

Confirmed current checks: **122/122 animation/anatomy (including wall slide)**, **50/50 clearance**,
**34/34 traversal**, **34/34 stairs**, **67/67 playable motion**.
The motion-course smoke test also passes.
Across both rigs, the loaded left sole stays fixed to numerical precision, the
right knee remains nearly straight through the early-push samples,
and the pelvis rises about 50 cm / moves inward over 50 cm before the right plant.
Loaded climb contact error is at most 1.12 cm. Knee-plane and shin-hinge changes
remain below the 45-degree limit per sampled frame with no measured medial collapse.
The full visible-armor envelope stays outside the tested ledges and floor.

Rendered 70 actual simulation frames per rig at 20 fps. The parent and animation
reviewer inspected the main sheet, front-knee views, both wall-jump rows and
late sequence samples through the transition into normal animation. The left
stance/right follow timing reads correctly; no reversed kneecaps, ankle roll,
visible ledge penetration or handoff pop was found in those inspected views.
These are prototype checks and sampled visual review, not mocap validation.

Current artifacts in `.godot/`: `parkour_motion_review.gif`,
`traversal_animation_review.png`, `parkour_knee_front_review.png`,
`wall_jump_animation_review.png`, and the `approved_motion_*.log` test records.

## Previous revision (22 October)

22 October 2026 · implemented and prototype-reviewed

The local motion course now uses the parkour research template for Arclight and Ashen Warden. This is authored procedural motion with contact IK, not imported motion capture. Grounded low mantles remain a separate motion family.

## Implemented motion

- Compact cat hang with extended arms, staggered wall forefeet near the hips, and boot contact frames calibrated against each rig.
- A 1.70-second hanging climb: load, leg drive/pull, grip turnover, palm-supported press, leading foot plant, deeper trailing foot plant, then an unloaded recovery step and standing.
- A continuous bounded hip trajectory with conservative visible-armor clearance in addition to the existing capsule sweeps. The safety blend spans the actual ledge surface, rather than treating empty space 16.5 cm above it as solid.
- Sideways traversal balances the hips between the hand anchors. Wall feet step using elapsed hang time, finish after input stops, and reset on a new grab. Starting a climb during a foot step re-establishes the brace during the initial load.
- Wall push-off uses a driving leg, opposing free leg/arm poses, brief forefoot release and airborne recovery. The immediate gameplay impulse is preserved.

Finger/palm and forefoot/sole markers describe visible contact patches. A contact flag alone grants no collision clearance. Support feet stay planted; moving feet are explicitly unloaded and lifted.

## Validation

Godot 4.7.2, both characters, 60 Hz test simulation:

| Check | Result |
| --- | --- |
| Animation, contacts, shimmy and wall-jump pose | 97/97 |
| Full armor clearance, floor, hip continuity and plant support | 50/50 |
| Traversal mechanics | 34/34 |
| Adaptive stairs | 34/34 |
| Playable movement and action arbitration | 67/67 |
| Parry/dash regression | 67/67 |
| Motion-course smoke test | Pass |

Final measured shimmy grip error was 1.55 cm. Consecutive loaded-sole horizontal travel was at most 1.90 mm per frame, measured from the transformed skeleton rather than the moving target. Loaded climb contact errors were under 2.2 cm on both rigs. The clearance suite sampled full 0.6/1.2/1.8 m climbs and found no visible armor penetration.

The playable test emits its existing damage-source attribution warning when its synthetic Main node causes a death; it still passes all 67 checks. No parser errors were reported.

## Visual review

Rendered 60 sequential frames per rig at 20 fps from the actual motor simulation. Reviewed the two-rig phase sheet and recovery frames, plus the wall-jump phase sheet. The animation reviewer identified a sliding loaded boot in the first render; the final render shows the trailing-foot transfer and a raised, unloaded leading recovery step. The parent reviewer also inspected the corrected recovery and wall jump.

Generated artifacts (local, under .godot):

- parkour_motion_review.gif — both continuous climbs, stacked.
- traversal_animation_review.png — hang, turnover, palm support and top-out.
- low_mantle_animation_review.png — grounded low-mantle phases.
- wall_jump_animation_review.png — takeoff through airborne recovery.

Recreate with tools/review_traversal_animation.gd and tools/compose_parkour_review.py. Tests are under tests/integration. See [review notes](TRAVERSAL_ANIMATION_REVIEW.md) and [research template](PARKOUR_MOTION_TEMPLATE.md).

## Scope and remaining limits

This review establishes prototype contact, continuity and visible clearance for the sampled rigs and fixtures; it does not certify universal human biomechanics. Wall-jump tests cover pose, orientation and recovery, not measured forces or launch-contact timing. The wall jump retains its immediate game impulse. Momentum-dependent catch absorption, wall runs, tic-tacs, cat-to-cat transfers and broader surface/approach-speed authoring remain future work. Body/equipment masses are undefined. Cloth/cape deformation is not part of the rigid armor collision envelope.
