# Astra Yao skin for Arclight

Run the main scene (F5). While playing Arclight, press **K** to toggle between
the default model and **Astra Yao**. **Tab** still switches between Arclight and
Ashen Warden; returning to Arclight remembers the chosen skin for that session.
The player Mesh inspector also exposes **Cosmetic Skin → Astra Yao**.

Astra remains character ID 0 (Arclight), with the shared movement, attacks,
spells, damage, cooldowns and collision capsule. Arclight's sword is retained.
The appearance is included in authoritative multiplayer snapshots; K requests
are processed by the server. Skin selection is not saved across launches.

## Model conversion

Source: `Skins/AstraYao/耀嘉音.pmx`, with its supplied body, face, skin and hair
textures. Output: `assets/models/astra_yao.glb` (embedded textures).
`tools/build_astra_skin.py` rebuilds it using Python, numpy and Pillow.
The rig uses Arclight's bone names, axes, hierarchy and animations, fitted to
Astra's proportions. Imported clips are fitted during conversion; shared
locomotion/action libraries are fitted per player at runtime.

MMD facial morphs, sunglasses, makeup mirror, and separate PMX weapon props
are not imported.

## Warm sunlight and spring motion

The main arena (also inherited by multiplayer) and movement course use a warm
sun with colour `(1.0, 0.72, 0.46)`, energy `1.15`, and warm ambient fill at
`0.35`. This gives skin a golden brown appearance without recolouring textures.
The arena sun points downward onto the characters.

The converter preserves **202 weighted hair, skirt, sleeve and ribbon bones**
in addition to the 20 Arclight gameplay bones. `astra_spring_motion.gd` builds
nonbranching chains for Godot's native `SpringBoneSimulator3D`. Gravity, inertia,
drag, restoring stiffness and subtle wind drive their motion after terrain and
traversal poses. Head/torso/thigh colliders reduce body intersections. A final
modifier bounds each local swing to 32 degrees for hair, 22 for skirt panels,
and 40 for sleeves/ribbons. Teleports, abrupt turns, death and health resets
reset inertia; changing skins frees the simulation.

This is cosmetic spring-bone physics, not a full cloth surface simulation.
Close folds may still intersect during extreme poses. The original MMD
rigid-body/joint system is not recreated, and spring poses are simulated locally
rather than replicated as gameplay state.

Reference: [Godot SpringBoneSimulator3D documentation](https://docs.godotengine.org/en/stable/classes/class_springbonesimulator3d.html).

## Graceful animation style

`scripts/player/astra_graceful_pose.gd` adds a skin-specific pose layer over the
existing clips: a softer weight transfer, relaxed shoulders, a poised head,
gentler torso counter-motion and fluid free-arm/wrist poses. It runs after
terrain/traversal presentation and before hair/clothing springs.

The source right-hand transform is constrained exactly after posing, preserving
the existing sword grip, tip, orientation and swept contact path. The casting
hand is similarly constrained during casting, and grounded locomotion retains
both original foot transforms. Existing movement parameters, animation lengths,
gait speed metadata, collision capsule, attack range, contact windows and damage
are unchanged. This preserves Astra's existing reach; it does not change her
proportions to match Arclight. Parkour contact poses and death bypass the style.
Default Arclight and default Ashen Warden do not receive this layer.
[Yixuan](YIXUAN_SKIN.md), an Ashen Warden skin, reuses the same animation set and graceful layer.

`style_strength` on the runtime `AstraGracefulPose` modifier controls the effect
from 0 (original pose) to 1 (full style). Run the review tool with
`--fixed-fps 60 -- --grace-review` for an original/styled comparison of idle,
walk, run and slash. Frames are written to `.godot/astra_grace_frames/`.

## Source credits and terms

Model author: **观海子** (BiliBili). Rights credited by the supplied readme:
**miHoYo**. Preserve `Skins/AstraYao/readme【一定要看】.txt`.
That readme permits weight fixes and limited appearance edits, prohibits
commercial use and redistribution, and sets additional usage restrictions.
This integration is for the supplied local project; it does not grant permission
to publish or distribute the model or a build containing it.

## Verification

- `tests/integration/model_import_smoke_test.gd`: model, materials, rig and animations.
- `tests/integration/astra_skin_smoke_test.gd`: selection, identity, sword length,
  shared clips, snapshot appearance, switching back, invalid IDs.
- `tools/review_astra_skin.gd`: rendered idle, run and rear view capture.
- `tests/integration/astra_spring_smoke_test.gd`: weighted hair/cloth bones,
  native simulation, ordering, finite poses, swing bounds, teleport reset,
  lighting and cleanup (15 checks).
- Run the review tool with `--fixed-fps 60 -- --spring-review` to capture
  running, turning and settling frames under `.godot/astra_spring_frames/`.
- `tests/integration/astra_graceful_smoke_test.gd`: 662 checks sampling 15 clips
  with styling enabled/disabled. Sword transforms/contact endpoints, casting
  origin and planted feet match within 0.00002 m tolerance; observed maximum
  differences were below 0.000001 m. Checks also cover animation duration/speed
  metadata, gameplay parameters, parkour bypass and default-skin isolation.

Validated in Godot 4.7.2 on 2026-10-27: 23 skin checks, 109 weapon checks,
310 layered animation checks and 37 authoritative multiplayer/motion checks
passed. The skin test also confirms one melee contact deals 25 damage.
