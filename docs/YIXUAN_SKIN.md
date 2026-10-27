# Yixuan skin for Ashen Warden

Run the main scene (F5), press **Tab** to select **Ashen Warden**, then press
**K** to toggle **Yixuan**. Arclight's K toggle still selects Astra Yao.
Each character remembers its skin choice for the current session. The Mesh
inspector also allows Character = Warden and Cosmetic Skin = Yixuan.

Yixuan keeps Warden's character ID (1), body capsule, movement settings,
longsword geometry/length, damage, attack timing and range limit. The skin has
its own ID (2); invalid character/skin combinations are rejected. Server-owned
skin requests and snapshots carry the current appearance to other players.

## Animations and secondary motion

Yixuan uses the **same animation set as Astra Yao**, including base attacks,
directional captured gaits, casting, dash/dodge and parry. Clips are cloned per
instance, their rotation curves/timing are retained, and translation tracks are
fitted to Yixuan's proportions and `AshenWardenRig/Skeleton3D` path. Default
Warden keeps its existing animation set.

The shared graceful pose layer preserves the incoming sword transform and
casting hand while styling posture/free-arm motion. Grounded feet retain their
incoming poses; parkour contacts bypass styling. As with Astra, fitting a skin
to different proportions can change the hand position relative to the body;
the graceful layer preserves Yixuan's fitted contact path rather than replacing
it with default Warden's hand path.

The imported model has **207 bones**: 26 original Warden rig bones and 181
weighted hair, sleeve, coat and ornament bones. It reuses Astra's native spring
solver, body colliders, bounded rotations and inertia reset handling. This is
cosmetic spring-bone motion rather than a cloth surface simulation; close folds
can still intersect during extreme poses.

### Heavier, damped Yixuan profile

Yixuan's long, dense chains use their own profile rather than Astra's settings.
Hair drag is `0.90` and cloth drag is `0.95`; artificial wind is disabled.
Restoring force/gravity are reduced, and smaller particle/body collision radii
avoid continuously pushing short segments away from the character at rest.

The bend budget applies across the whole strand: 12 degrees for hair, 8 for
the coat and 7 for sleeves/ornaments, with a 4.5-degree local cap. Long chains
share this budget across their depth instead of multiplying a large rotation
by 20 joints. Time-based rotational smoothing and angular speed limits suppress
snapping while keeping subtle follow-through. Zero-time pose refreshes reuse
the filtered pose; teleports and health resets clear the smoothing history.
Astra's solver settings and original limiter behavior are unchanged.

## Source and rebuild

- Source: `Skins/Yixuan/仪玄.pmx` and its supplied textures.
- Converted asset: `assets/models/yixuan.glb` with embedded textures.
- Rebuild: run `tools/build_yixuan_skin.py` with Python, numpy and Pillow.
- The source weapon materials and separate bird prop are omitted; Warden's
  longsword is retained. Facial morphs and original MMD rigid-body constraints
  are not recreated.

Model author: **观海子** (BiliBili), with rights credited to **miHoYo** by the
supplied `Skins/Yixuan/readme【一定要看】.txt`. Preserve that file. It permits
weight/physics fixes and limited appearance edits, prohibits commercial use and
redistribution, and lists additional restrictions. This local integration does
not grant permission to distribute the model or builds containing it.

## Verification

Validated in Godot 4.7.2 on 2026-10-27:

- `yixuan_skin_smoke_test.gd`: 527 checks for model/identity, Astra animation
  rotation curves and timing, Warden longsword, hitbox, speed, memory, snapshots,
  invalid pairs and a 25-damage melee hit.
- `astra_graceful_smoke_test.gd -- --yixuan`: 662 pose/contact checks.
- `astra_spring_smoke_test.gd -- --yixuan`: 20 spring/weight/stability checks,
  including high damping, limited bends, zero-time evaluation and settling.
  With primary bones held still, the final half-second of settling changed
  secondary local rotations by about 0.04 degrees in the measured run.
- `onevone_motion_smoke_test.gd`: 40 authority/combat/traversal checks, including
  both Astra and Yixuan skin requests and appearance replication.
- Model import and existing Astra skin/graceful regressions passed.

For a render review, run `tools/review_astra_skin.gd` with
`--fixed-fps 60 -- --yixuan-review --spring-review`. Frames are stored under
`.godot/yixuan_spring_frames/`, with a final PNG in `tools/yixuan_skin_review.png`.
