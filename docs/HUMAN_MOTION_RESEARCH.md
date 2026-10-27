# Human motion research and implementation

19 October 2026 · ArenaBattle · Arclight and Ashen Warden

Walk and run now use retargeted human motion capture on both character rigs. Jump and sideways movement have capture-based gallery previews. This document separates the implemented work from references for later actions; validation results are recorded separately after testing.

## Implemented scope

| Action | Source | Current use | Extracted cycle duration | Nominal capture-derived speed |
|---|---|---|---:|---:|
| Walk | CMU `35_01` | Runtime on both rigs | 1.1166622 s | 1.1757926 m/s |
| Run | CMU `35_17` | Runtime on both rigs | 0.7416637 s | 2.881879 m/s |
| Jump | CMU `16_01` | Full capture in the review gallery only | Full capture, not a gait loop | Not applicable |
| Sideways walk | CMU `143_40` | Full capture in the review gallery only | Full capture, not a gait loop | Not applicable |

The walk/run numbers describe this extraction and retargeting pipeline, not universal human gait values. Capture timing and spatial motion supply the baseline; runtime cadence follows actual horizontal velocity. At steady movement, playback rate is horizontal speed divided by the corresponding nominal speed. Walk/run changes preserve normalized cycle phase to reduce discontinuities between the feet. Contacts and transitions still require visual review.

The owner-approved natural movement defaults are **1.2 m/s walking and 3.8 m/s running**. These are gameplay choices. Their approximate steady playback ratios are 1.02 for walk and 1.32 for run. There is no blanket armor speed multiplier.

This adaptation uses **positional retargeting** to reproduce captured joint coordination on the two existing rigs. It is not a validated human dynamics or armor simulation. Human capture does not, by itself, establish that a fictional character's equipment clears every pose.

## Sources and reuse

The [CMU Graphics Lab Motion Capture Database](https://mocap.cs.cmu.edu/) permits all uses. Its [resources page](https://mocap.cs.cmu.edu/resources.php) links Bruce Hahne's BVH conversions. The [converter's release notes](https://raw.githubusercontent.com/una-dinosauria/cmu-mocap/master/READMEFIRST.txt) add no restrictions to reuse. Preserve provenance and attribution with derived assets.

The individual source files are available through the conversion mirror: [walk `35_01`](https://raw.githubusercontent.com/una-dinosauria/cmu-mocap/master/data/035/35_01.bvh), [run `35_17`](https://raw.githubusercontent.com/una-dinosauria/cmu-mocap/master/data/035/35_17.bvh), [jump `16_01`](https://raw.githubusercontent.com/una-dinosauria/cmu-mocap/master/data/016/16_01.bvh), and [sideways walk `143_40`](https://raw.githubusercontent.com/una-dinosauria/cmu-mocap/master/data/143/143_40.bvh). These BVHs include an added first-frame calibration pose; it must be excluded from playable motion. The conversion uses 120 Hz timing. It retains the source recording's imperfections, so capture provenance is not a quality guarantee.

## Contact and coordination criteria

Retain the captured relationship between feet, knees, pelvis, torso and opposite arm swing. Review stance, push-off, swing clearance and the next contact together. Choose loop boundaries at corresponding contacts, inspect the seam, and reconcile stride distance with playback speed. Check both rigs from the side, front and three-quarter views at normal speed as well as slow playback.

Foot sliding can appear after retargeting or blending even with good source capture. [Kovar, Schreiner and Gleicher's Footskate Cleanup research](https://research.cs.wisc.edu/graphics/Gallery/kovar.vol/Cleanup/) motivates checking stationary contacts and smooth entry/exit corrections. It also explains why independent frame-by-frame corrections can create jumps or knee popping. **This change does not implement that paper's algorithm.** Contact locking, clearance and transition quality remain review criteria rather than a claim of solved footskate.

## Applying the owner's armor reference

Read the owner's [armor movement reference](</C:/Users/ameer.noorfizan/Documents/Codex/2026-10-19/can-x20/outputs/armor-movement-reference.md>) alongside the [blank character record](</C:/Users/ameer.noorfizan/Documents/Codex/2026-10-19/can-x20/outputs/character-motion-template.json>) and [constructed timing example](</C:/Users/ameer.noorfizan/Documents/Codex/2026-10-19/can-x20/outputs/constructed-walk-timing-example.json>).

The example's 100 steps/minute, 0.72 m step length and 1.20 s stride are explicitly synthetic timing inputs. They are not measurements of these characters or substitutes for the extracted capture cycle. The template's unknown body mass, equipment masses, dimensions, centers of mass, fit, joint clearance and experience remain **null** until defined. No equipment mass or material property has been inferred from the characters' appearance.

The research supports keeping recognizable human coordination when articulation permits it. The [Metropolitan Museum's armor reference](https://www.metmuseum.org/essays/arms-and-armor-common-misconceptions-and-frequently-asked-questions) describes substantial mobility in properly fitted field armor. The owner's guide also cites [Askew and colleagues' armor experiment](https://pmc.ncbi.nlm.nih.gov/articles/PMC3248716/) and [Jaquet and colleagues' movement study](https://doi.org/10.1080/01615440.2015.1112753). Their tested equipment and participants do not define these fictional characters. Increased effort is not a universal speed ratio; future load, fatigue and clearance adjustments need a defined equipment record and action-specific evidence.

## References for other actions

These are **capture candidates for inspection and adaptation**, not implemented game actions or approved final clips. Descriptions are identified in the [CMU motion index compiled by Bruce Hahne](https://raw.githubusercontent.com/una-dinosauria/cmu-mocap/master/cmu-mocap-index-text.txt).

| Planned action | Candidate recording | Adaptation still needed |
|---|---|---|
| Run start and stop | `143_03` start to run; `143_02` run to stop | Match entry speed, facing, braking steps and final contact. |
| Fast stop/reversal | `16_08` run/jog with sudden stop | Inspect balance and braking; author reversal separately. |
| Backward movement | `143_39` backward walk | Retarget, extract a useful segment and check direction-specific cadence. |
| Dash | `127_13` run sidestep left; `127_14` right | Reference for a push and recovery; these are not ready-made game dashes. |
| Block/parry | `144_07` left blocks; `144_26` right blocks | Select guard and deflection poses, then author timing and equipment clearance. |
| Ground recovery | Subject `140` get-up recordings | Choose a strategy compatible with the character's equipment. |
| Knockback/hit reactions | No verified matching directional capture selected | Retain the existing drafts for review; find or author evidence-based reactions before claiming capture replication. |
| Magic/energy casting and skills | No matching real-world action selected | Use human reach, weight transfer and recovery references; the magical action remains authored. |

Next review priorities are walk/run foot contact, visible balance, equipment intersections and transitions at the approved speeds. Jump/strafe integration and the reference-only actions follow their separate roadmap tasks.

## Parkour traversal research (22 October 2026)

The team’s [parkour motion template](PARKOUR_MOTION_TEMPLATE.md) covers human
hanging, catches, climb-ups, traversing and wall jumps. It distinguishes
coaching evidence from proposed animation timing and identifies missing
contact transitions in the current procedural implementation. It is an
authoring reference, not imported motion capture or a completed runtime change.
