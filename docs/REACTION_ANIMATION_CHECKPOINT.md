# Fall, landing and knockback animation drafts — 2026-10-19

> Historical checkpoint: current walk/run clips, speeds, thresholds and validation have since changed. See HUMAN_MOTION_CHECKPOINT.md for the latest implementation.

Eight new Godot animation clips per character are available in the existing review
gallery. These are editable pose/timing blockouts, not final animation acceptance.

Open scenes/characters/AnimationReviewGallery.tscn in Godot and press F6. Select a
Review/ clip, slow playback to 0.25x, and use Pause/Step or Restart for closer review.

| Clip | Purpose | Arclight duration | Ashen Warden duration |
|---|---|---:|---:|
| FallLoop | Braced airborne pose, seamless hold | 0.8 s | 0.92 s |
| LandSoft | Compression and return to neutral | 0.42 s | 0.483 s |
| HitFront / Back / Left / Right | Directional recoil and recovery | 0.42 s | 0.483 s |
| KnockbackTravel | Sustained recoil while future server movement acts | 0.6 s | 0.69 s |
| KnockbackRecover | Travel pose settling back to neutral | 0.7 s | 0.805 s |

Directions are character-local impact-side labels. They do not infer attacker direction
from the current network packets. Warden's draft poses use 85% of Arclight's angular
offsets and 115% of its clip duration. Both rigs start from their own sampled Idle pose.
Every bone has explicit translation/scale baselines to prevent prior-clip residue;
only rotations animate. No body displacement or root-motion track awards knockback.

Resources live in assets/animations/review/arclight.tres and ashen_warden.tres.
tools/build_reaction_blockouts.gd is their reproducible source; run it with Godot
--headless --path . --script res://tools/build_reaction_blockouts.gd to rebuild.
These Godot resources leave the existing GLBs and Blender source files untouched.
Only the gallery loads the Review library. Existing game combat still uses its
previous animations and feedback; no new gameplay or network fields were added.

## Remaining polish and integration

These are first poses: foot contact/IK, pelvis compression, overshoot, moving landings,
weapon clearance, cape motion, wall/air/repeated-hit variants and visual continuity
under interruption need further authoring. Current travel/recover drafts represent
front-impact recoil; other travel directions remain pending. Separate fall/land
gameplay triggers require reliable authoritative airborne/grounded state.

Next: refine movement and reaction poses in motion, then wire accepted clips to the
presentation state graph with explicit interruption/death/respawn priorities. Physical
knockback must be a separate server-authoritative gameplay change. Magic/energy casting,
skills, parry, dash and block remain in the broader animation plan.

Demo 1 has not been rebuilt. No commits or pushes were made.

## Verification

112 focused checks passed: 84 new checks across both rigs for clip availability, valid bone paths, visible pose changes, finite rotations, unchanged body/health, no animated translations, loop seams and neutral recovery; plus 28 existing gallery checks. HitFront and LandSoft previews were rendered and inspected at 1280x720. git diff --check passed. The previous 286-check gameplay/multiplayer run remains historical evidence; it was not rerun for these gallery-only assets. Human motion-quality acceptance remains pending.
