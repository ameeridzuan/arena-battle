# Climbing, wall-jump and shimmy animation review

Updated: 2026-10-23. Requested by the owner; reviewed by a dedicated animation
review agent and the implementation agent. This is an AI animation-team review,
including code, rendered phase sheets and independent contact measurements.


## Faster-climb and wall-slide follow-up (2026-10-23)

Climb duration is now 2.15 seconds, with a small anticipatory hip arc at the
palm-release handoff. The slide uses its own calibrated palm/forefoot contacts
and stable forward knee hinges. Its matching brace heights feed the jump
push-off anchors. Both rigs pass 122/122 animation checks and 50/50 clearance
checks on this revision. Slide marker error is below 0.001 mm; sampled torso
penetration is zero. The implementation agent inspected the rendered slide
and slide-to-jump phase sheets; the earlier independent review below applies
to the approved base sequence.

## Approved left-foot-led sequence (2026-10-23, current)

The owner approved the preview and requested this runtime sequence: the left
foot plants under the body, left-leg extension drives the body forward and up,
the right leg remains nearly straight behind, and the right foot comes through
after the torso has become at least halfway upright. Pelvis yaw/roll and chest
counterrotation accompany the weight transfer. The left sole remains planted
through that push. The current hang uses a deliberate high-left/low-right brace
with approximately 30 cm vertical foot stagger and extended arms.

The updated animation suite passed **112/112** assertions on both rigs. Actual
final-pose measurements confirmed:

- Loaded contact error peaked below **0.01 mm on Arclight** and **1.12 cm on
  Warden**. The left sole's total hold drift stayed below **1 micrometre**.
- The trailing right knee remained at least **165.49 degrees** extended through
  **20/20** sampled left-push frames. The measured push advanced the pelvis
  approximately **53.5 cm** and raised it **50.8 cm** before the right plant.
- Right planting is gated against the measured torso tilt at the first left
  plant: at most half that initial tilt, plus 5 degrees of sampling tolerance.
- Knee bend-plane and shin hinge-axis changes peaked at **10.95 degrees per
  physics frame**, with **zero measured medial knee deviation**. Hip-relative
  frames retain meaningful anatomical checks while the pelvis turns and rolls.
- The wall turn is sampled throughout its authored **0.55 second** duration,
  including a maximum **15-degree facing change per physics tick** acceptance
  bound, followed by the existing airborne recovery checks.

The suite retains the contact, visible-tread, limb-length and loaded-sole travel
limits from the previous reference pass. It now measures stable left support,
trailing right-leg extension, delayed right planting and knee/hinge continuity
through the approved sequence. Near-straight knees use hinge-axis continuity
where a position-derived bend plane becomes undefined.

**Final clearance regression and fresh runtime visual review passed for
this revision.** The clearance suite passed 50/50 checks across both rigs and
0.6, 1.2 and 1.8 metre ledges, with zero measured body-envelope penetration.
Maximum high-climb hip travel per 60 Hz physics frame was 3.66 cm for Arclight
and 3.24 cm for Warden, within the continuity gate.

Independent review of both rigs' main, front-knee and wall-jump sheets, plus
continuous-sequence samples at 1.75, 2.05, 2.35, 2.45 and 2.95 seconds, confirms
the approved left-foot support and delayed right-leg follow-through. The front
views show forward-facing kneecaps without reversed hinge plates. The sampled
late-climb and normal poses show no visible joint spin, ankle roll, transition
pop or wall penetration. These are sampled-frame findings, not a claim to have
reviewed full video playback or production-quality motion on arbitrary geometry.

The renderer includes both rigs' wall-jump samples and a front
knee sheet at climb phases 0.72 and 0.86, in addition to continuous actual-simulation
captures. Front views provide the absolute kneecap-orientation check alongside
the numerical continuity checks. Earlier visual findings below describe the
22 October implementation; they do not certify the new runtime sequence.

## Parkour reference revision (2026-10-22, previous reference pass)

The later revision follows the [parkour motion template](PARKOUR_MOTION_TEMPLATE.md):
a compact wall-braced cat hang, coordinated leg drive and pull, a distinct
top-palm support position, then supported foot placement and standing recovery.
The reference came from coaching text, available transcripts and research
abstracts; phase timings are authored, not extracted from video or mocap.

Finger, palm, forefoot and sole markers are calibrated from each rig's visible
geometry. Acceptance transforms those markers through the actual final bone
poses inside `modification_processed`; it does not treat target coordinates or
the restored pose read outside that signal as contact evidence. Loaded contact
and an unloaded swing are recorded separately. Shimmy feet step independently
while the hips balance beneath the current hand grips.

Confirmed measurements:

- The animation suite passed **97/97** after the supported recovery-step change.
  Worst loaded contact errors were **2.05 cm / 2.16 cm** for Arclight / Warden;
  the planted shimmy grip error was **1.55 cm**.
- The final clearance suite passed **50/50**
  across both rigs and 0.6, 1.2 and 1.8 m ledges. Tested armor-envelope penetration
  was zero, and root-relative hip continuity checks passed throughout the
  observed climbs.
- A new loaded-sole travel gate has been added: at least three consecutive
  physics sample pairs, with no more than **1 cm of actual horizontal sole
  travel per frame** while both samples mark that sole loaded. This raises the
  animation suite to **97 assertions**. The measured maximum was **1.90 mm per
  frame** on both rigs, with **21 consecutive sample pairs** per rig.

Final regressions also passed: traversal (34), stairs (34), playable motion
(67), parry/dash (67), and the live motion course. The playable-motion suite
retains its deliberate damage-source warning.

The first revised sheet and continuous-frame samples were reviewed on both
rigs. The compact hang and change from pull to palm press read clearly, and no
visible body/wall intersection was found in those inspected views. A constant
world hand orientation can remain credible here: the elbow and forearm pass
from below the grip to above it while the palm stays over the flat lip.

That visual review found a remaining late top-out problem: a loaded boot slid
along the tread during standing recovery. The correction now places the
trailing foot deeper, transfers support, then unloads, lifts and replants the
leading foot. This replaces moving a loaded sole anchor along the surface.
Refreshed recovery frames at 1.45, 1.60 and 1.70 seconds were reviewed on both
rigs: the support transfer and unloaded lead-boot lift now read clearly, ending
with both feet settled. No new body/wall intersection or ankle roll was found
in those inspected views. The Warden wall-jump sheet shows distinct compact
takeoff, wall separation and asymmetric flight recovery without crossed limbs.
This is a scoped prototype review, not production-quality certification.
Wall-jump tests cover pose, facing, anatomical sides and recovery rather than
measured physical takeoff forces or wall-contact timing.

The render tool now captures 60 frames per rig under
`.godot/parkour_frames/rig0_000.png` through `rig0_059.png`, with equivalent
`rig1_` files. It advances the actual simulation at 60 Hz and captures every
third physics tick (20 frames/s), including a settled hang and recovery hold.
The continuous sequence does not freeze phases. Contact sheets remain useful
for silhouettes but do not establish temporal fluidity by themselves.

**The sections below preserve the earlier procedural review as history.** Their
91/44 assertion counts, fixed 25-degree boot adjustment, 15 cm above-lip release
band and 25 cm corrective arc describe that earlier implementation and are
superseded by the reference revision above. Automated acceptance remains a
prototype check on the tested fixtures, not a claim of production animation
quality, arbitrary-geometry coverage or cloth collision validation.

## Findings and corrections

| Finding | Correction |
| --- | --- |
| Left/right limbs crossed for the wall-facing rigs | Correct wall tangent and anatomical side targets; tested on both rigs and four wall normals |
| Hands faded out before weight shifted onto the ledge | Sequential contact release, chest/hip transfer and a lead-leg plant |
| Capsule rise looked like floating upward then sliding inward | Timed pull/transfer/recovery pose over a collision-checked capsule route |
| Shin aimed beyond the clamped IK reach | Clamp the endpoint itself before both solve stages; explicit elbow/knee poles |
| Wall jump immediately became the generic airborne pose | Dedicated 0.55 s compression/extension/recovery, smooth facing turn and action arbitration |
| Swords obstructed believable two-handed contacts | Temporarily stow only the named weapon meshes; restore original visibility |
| Sideways traversal could look like sliding both hands | One reaching hand and one fixed world grip; bounded body sway |
| Near-end initial grab could put a hand in air | Use the same two-hand lip support envelope for grabs and lateral moves |
| Low mantles pushed ankles below ground | Preserve grounded start-foot anchors, lift before advancing, and plant in sequence |

## Review result

The earlier procedural pass passed its bone/contact checks, but user playtesting
revealed twisted hanging ankles and visible armor entering the wall. That
approval did not establish visible-mesh clearance. The corrective pass now
checks conservative armor envelopes throughout each simulated climb and uses
rest-model foot axes to control the boot independently of shin rotation.

Rendered phase sheets use the actual movement simulation. Both characters were
inspected at hang, pull, transfer and recovery, plus low mantles and wall jumps.
These checks cover the tested static ledges; cape cloth, arbitrary geometry and
subjective production animation quality remain outside automated acceptance.

## Automated animation acceptance

traversal_animation_smoke_test.gd contains 91 assertions. It samples the actual
post-animation SkeletonModifier3D output instead of the restored input pose.
Coverage includes both characters, four wall directions, hand support through
pull/transfer, invariant limb lengths, low-mantle ankle/tread clearance, weapon
visibility, alternating hand reaches, ledge-end and obstruction stops, climb
from the moved position, early lateral adjustment and wall-jump turn/recovery.

At sampled high-climb phases 0.17, 0.37, 0.55 and 0.69, the supporting hand stayed
within floating-point tolerance of its anchor. During the shimmy sample, the stationary
hand's largest measured anchor error was about 3.4 cm after the armor-clearance correction. Both rigs' early low-mantle
ankles remained about 13 cm above the ground. Feet cleared the lip before moving
onto the tread. The reviewer independently verified the low-mantle correction.

Run the headless suite with:

    godot --headless --path . --fixed-fps 60 --script res://tests/integration/traversal_animation_smoke_test.gd

## Reproduce visual review

Run with a graphical renderer:

    godot --path . --rendering-method gl_compatibility --resolution 960x540 --fixed-fps 60 --script res://tools/review_traversal_animation.gd

The tool creates three local contact sheets under .godot/:
traversal_animation_review.png, low_mantle_animation_review.png and
wall_jump_animation_review.png. Generated sheets remain outside source control.

For manual acceptance, run MotionTestCourse.tscn with F6. Use zone 5 for ledges
and zone 6 for walls. E grabs/climbs; A/D shimmies; E or Space commits the climb;
C drops. Try reversing direction, releasing the movement key, reaching both ledge
ends and climbing after a sideways move. Also test low mantles, both characters,
wall jumps in aimed mode and normal movement immediately after landing/reset.

Final regression on Godot 4.7.2: animation (91), stairs (34), traversal (34),
live course, playable motion (67) and parry/dash (67) suites all passed, exit 0.
The playable-motion suite retains its deliberate unattributed-damage-source
warning; the other suites produced no warnings or script errors.

## Ankle and visible-body clearance correction (2026-10-22)

- Hanging boots use a 25-degree toe-up contact frame with no lateral ankle roll;
  grounded low mantles keep the starting sole level. The orientation persists
  through leg-target recovery so shin rotation cannot twist the foot again.
- Rest-model armor envelopes are built once from skin weights. Torso, arm and thigh
  clearance projects the hips outward and resolves the original contact targets
  again, preserving supported grips. Capsule sweeps remain authoritative for
  physical movement.
- Reduced inward cosmetic hip travel, retained a crouch through transfer, raised
  wrist contacts, and
  staged foot lift/advance keep the visible body outside the face. Recovery
  targets retain sole clearance above the roof and starting floor.
- traversal_clearance_smoke_test.gd passes 44 assertions across both rigs and
  0.6, 1.2 and 1.8 m ledges. Each complete climb is observed through the actual
  modifier signal. Tested armor-envelope penetration was zero; minimum boot
  floor clearance was approximately 6 mm. This is a conservative skin-envelope
  check rather than an exact GPU mesh/cape collision system.
- Final regression: clearance (44), animation (91), traversal (34), stairs (34),
  playable motion (67), parry/dash (67), basic movement (3), and live course passed.
  Only the playable-motion suite emitted its intentional damage-source warning.

## Public motion references

- [Motionbeats ledge-climbing demonstration](https://www.youtube.com/watch?v=rs1oucmniR8)
  and [creator listing](https://www.fab.com/listings/fbfda52a-0a95-43ac-8875-8e5ce8b71ee0):
  mocap references for hanging, pulling onto a ledge and transitions.
- [Basic Ledge & Campus showcase](https://www.youtube.com/watch?v=SrSs-JpZZm4)
  and [creator listing](https://www.fab.com/listings/d927d48b-e1f3-4212-b19a-e543bc6d0594):
  references for ledge idle and sideways movement.
- [Epic motion warping](https://dev.epicgames.com/documentation/unreal-engine/motion-warping-in-unreal-engine?lang=en-US):
  contact-target alignment during defined animation windows.

These are reference links, not animation assets imported into the project.

Late-transfer review retained the trailing hand until phase 0.72, fading it by
0.88 while the hips rise from their transfer crouch. Independent measurements
found the trailing hand on its anchor through phase 0.69, about 1.6 cm away at
0.745 during release, with the leading sole above the tread. A 15 cm release
band above the lip prevents abrupt removal of the armor clearance constraint;
full horizontal protection remains below the top.

The review also detected 11–18 cm per-frame hip pops from reactive clearance.
The final pose anticipates the transfer with a continuous 25 cm outward arc,
ramping from phase 0.12 to 0.28 and releasing from 0.65 to 0.90. Geometry
projection remains as a safety constraint. The six complete-climb continuity
checks now pass: largest root-relative normal hip travel is about 3 cm per
physics frame at 60 Hz, and residual reactive correction is zero on the tested
fixtures. Leading boot lift/plant clearance includes reach-clamp compensation.
