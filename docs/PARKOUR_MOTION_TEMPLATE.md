# Parkour research and animation motion template

22 October 2026 · Arclight and Ashen Warden

Implementation update: the local hang, hanging climb, sideways traverse and wall push-off prototype now applies this brief. See [implementation and validation](PARKOUR_ANIMATION_CHECKPOINT.md). The original research proposals below remain an authoring reference; future motion families are explicitly listed in the checkpoint.

Research completed by the animation reviewer and wall-movement researcher,
consolidated by the implementation lead at the owner’s request. This is an
authoring blueprint for the next traversal animation revision. It does not
replace the saved live animation or certify the previous procedural pass.

The companion [structured template](references/parkour_motion_template.json)
records nine motion families, contact events and review requirements.
Its phase fractions are proposed blocking timings, not measurements of athletes.
We read coaching text, available transcripts and research abstracts. Video links
are viewing references; no frame-by-frame motion extraction was performed.

## What the human reference changes

A loaded parkour cat hang is compact: extended arms above, flexed knees, feet
pressing into the wall and hips low toward ankle height. It differs from a
relaxed unsupported dead hang. [Apex’s setup](https://apexmovement.com/parkour-as-life-skills-2)
and [London Parkour’s staggered-foot lesson](https://londonparkour.com/tutorials/how-to-cat-leap-foot-position-2/)
provide the reference. The exact posture must fit the character’s reach.

The climb needs a recognizable hand-supported position above the edge between
hanging and standing. The coordinated leg drive and arm pull become a push
through the palms, followed by bringing the feet onto the top. See
[Apex’s progression landmarks](https://apexmovement.com/climb-up-intro) and
[Swiss BASPO’s hang/support/stand training](https://www.mobilesport.ch/parkour/parkour-trainingsformen-zu-den-erscheinungsformen-dynamisch-und-sicher-zwischen-haengender-stuetzender-und-stehender-position-wechseln/).
Our default is a controlled athletic step-through; a slower knee-assisted
scramble would be a separate style. [London Parkour’s cat-to-climb-up task](https://londonparkour.com/tutorials/cat-to-climbup-2/)
explicitly uses a knee-free finish.

A fixed ankle angle cannot define this motion. Build a wall forefoot contact,
then pose the shin, heel and ankle together. Preserve the visible contact patch
while the leg loads and extends. The previous 25-degree adjustment was rig tuning,
not a researched human constant.

## Climb-up key-pose template

The overlapping intervals below are initial animation direction. Contacts and
clearance determine when a transition can happen; a clock alone is insufficient.
The sequence draws on the sources above and the association-authored
[APA/Parkourpedia manual](https://motricidadehumana.org/wp-content/uploads/2015/08/parkour-techniques-and-movements.pdf),
printed pages 15–19.

| Proposed phase | Body action to author | Visible contact requirement |
| --- | --- | --- |
| 0–15% load | Compact split-foot cat stance, prepare the leg drive | Both grips and wall feet have purchase |
| 12–40% drive/pull | Wall leg extends; pelvis rises in an outward/upward arc, then chest approaches edge | Driving forefoot stays fixed until its push finishes |
| 32–55% turnover | Chest clears lip; shoulders move over hands; grip changes to top-palm support | Show the wrist/grip transition, keeping credible support |
| 48–70% support | Arms press under torso; hips lift, legs remain clear | Palms carry weight on top; toes may still brace face |
| 62–90% top-out | Tuck and place lead foot near lip; trailing foot follows | Foot is reachable and supports weight before final hand unload |
| 85–100% recover | Weight shifts over feet into squat and then movement | Soles stay on tread; hands release smoothly |

A successful silhouette must show the change from pulling below the hands to
pushing above them. Do not lift the upright character like an elevator, then
slide it through the wall.

## Other motion templates

| Motion | Contact and motion sequence |
| --- | --- |
| Ledge catch | Reach → wall impact and edge catch → yielding knees/arms/shoulders → settled hang. Scale absorption to incoming motion. |
| Supported hang | Compact staggered wall brace with stable grip; subtle supported weight shifts. Use another pose when the wall cannot support the feet. |
| Sideways traverse | Load the support side → release/reach one hand → establish grip → shift pelvis and step wall feet → close trailing hand. Mirror and reverse from supported poses. |
| Low mantle | Ground push and top-hand support → step through → recover. Skip the high cat-hang pose. |
| Wall push-off | One forefoot plant → stance-leg compression → extension and toe-off → flight → prepare next contact. |
| Vertical wall run | Approach and ground takeoff → one wall-foot plant → upward drive with free knee/reach → toe-off → ledge catch or moving top-out. |
| Tic-tac | Angled approach → single wall-foot load → push toward exit target → flight → landing/catch. |
| Cat-to-cat | Supported hang → step up when height is needed → push/release → turn → reach and absorb next catch. |

The detailed traverse limb order is our conservative animation interpretation,
not a measured universal gait. Catch absorption is supported by
[London Parkour’s arm-preparedness transcript](https://londonparkour.com/tutorials/how-to-cat-leap-arm-preparedness/).
Low, walking and running approaches should use different entries;
[Apex’s progression library](https://apexmovement.com/climb-up-ground-up)
provides examples. Cat-to-cat height and turn ordering come from
[London Parkour’s coached lesson](https://londonparkour.com/tutorials/180-cat-to-cat/).

Wall run and tic-tac references appear in the APA manual, printed pages 38–41
and 56–58. [Croft, Schroeder and Bertram’s force-plate study](https://pubmed.ncbi.nlm.nih.gov/30446542/)
supports treating approach speed, wall-foot placement and the rising body path
together. It does not supply our joint angles, phase percentages or launch speed.
The existing game wall jump maps to push-off; other variants are template coverage,
not newly implemented mechanics.

## Original implementation gaps addressed by this revision

| Current implementation | Required authoring change |
| --- | --- |
| Hang feet fixed 1.28/1.34 m below lip; hips nearly upright | Pose a compact loaded cat brace using measured rig reach and wall contact markers |
| Grips remain at one anchor/orientation until fading | Author edge grip → turnover → palm support as distinct contact modes |
| Foot lift follows elapsed phase regardless of leg drive | Keep loaded forefoot planted through push; tuck after support is established |
| Mostly vertical capsule rise followed by late inward motion | Coordinate body arc with the authored support transitions and collision-safe route |
| Fixed outward/downward cosmetic offsets repair clearance | Use those as bounded residual corrections after the main body motion reads correctly |
| Generic wall pose with symmetric hands | Author a clear driving leg, free leg and target-dependent arms/turn |

Author the major poses and continuous body path first; retarget to both rigs.
Then use IK to adapt contacts to ledge geometry rather than making independent
limb targets invent the full action. Add finger/palm and forefoot/sole markers;
ankle and wrist origins alone cannot verify contact. Keep physical capsule
sweeps and visible-armor checks. Pelvis position is only a visual balance proxy,
not a computed whole-body centre of mass.

Ledge height selects a suitable motion family and adjusts reach/path within
that family. Grounded step-over, low mantle and hanging climb should not all be
created by stretching one clip. Incoming speed selects catch absorption versus
a flowing running entry. Body/equipment masses remain undefined; do not infer
an armor timing multiplier from appearance.

## Reference clips to compare during authoring

- [Apex controlled climb-up, level 2](https://www.youtube.com/watch?v=Jr7tcecaYCY)
- [Apex climb-up, level 3](https://www.youtube.com/watch?v=QDd5H_yUpSE)
- [Apex top-out, level 2](https://www.youtube.com/watch?v=pIalXR5Hj64)
- [Apex running entry, head-high](https://www.youtube.com/watch?v=zadG0WafktU)
- [London Parkour cat-leap side view](https://londonparkour.com/tutorials/cat-leap-side-view/)

Apex video URLs were verified through the coach’s progression page. Use side
views to trace contacts and pelvis path; front/three-quarter views reveal knee,
shoulder and wrist alignment. Record actual contact frames before claiming
capture-derived timing.

## Animation review gates

Review both rigs, both lead sides, low/medium/high reachable ledges, varying
approach speed, shimmy reversal and wall-jump directions. Watch continuous
normal-speed and slow playback in addition to phase sheets. Check contact
entry, load, release and flight separately; do not lock a limb to the wall after
toe-off. Reject visible wall penetration, floating loaded soles, grip skating,
ankle roll, unreachable plants, abrupt pelvis corrections and premature
weapon reappearance. Inspect cape/armor separately.

The existing headless tests remain useful for collision, reach and continuity.
Passing them does not establish the reference posture or human weight transfer.
Next implementation acceptance must include the explicit palm-support phase
and comparison against these human references. The original research delivery changed no runtime behavior; the subsequent implementation is recorded in the linked checkpoint.

Final research review: the animation reviewer checked the prose and structured
template against the cited findings. The subsequent prototype implementation and scoped motion acceptance are recorded in the linked checkpoint. The traverse interpretation
also uses the APA manual’s controlled-climbing contact guidance (printed p13),
without treating three contacts as a universal rule for explosive parkour.
