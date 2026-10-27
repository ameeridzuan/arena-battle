# Casting and dodge animation checkpoint — 20 October 2026

> Follow-up: the owner requested hands-on testing. F5 Main now installs local R casting, Q dodging and Tab character switching; see PLAYABLE_MOTION_TEST.md. Gallery-only status below describes the original asset batch. Local dodge travel and cosmetic bolts are test adapters, not completed multiplayer mechanics.

## Delivered animation slice

Both Arclight and Ashen Warden now have five rig-specific authored blockouts:

| Semantic clip | Duration | Ownership | Visible sequence |
|---|---:|---|---|
| CastEnergy | 0.86 s | Upper body | Gather/anticipation, left-hand release, follow-through, recovery |
| Dodge_Forward | 0.72 s | Full body | Low preload, forward push/lean, brake and recover |
| Dodge_Backward | 0.72 s | Full body | Low preload, backward push/lean, brake and recover |
| Dodge_Left | 0.72 s | Full body | Low preload, left leading foot/lean, brake and recover |
| Dodge_Right | 0.72 s | Full body | Low preload, right leading foot/lean, brake and recover |

These are authored pose studies, not motion-capture footage, measured armor motion
or visually approved final animations. Equal semantic durations avoid assuming a
universal armor slowdown. Each rig supplies its own hierarchy and limb lengths;
Warden uses a more contained arm silhouette. Original model files are preserved.

One cast clip is reused over idle, walking, running, strafing and backward movement.
The left hand extends toward mesh-forward (+Z) above the waist; the right hand
retains its local weapon grip. The cast's visual release marker is 0.34 s. Its
markers are metadata only and never spawn a projectile or award a hit.

Dodges change hips, spine, arms and legs. Analytical two-bone IK establishes distinct
leading/trailing foot targets, with a low preload, directional lean, modest lead-foot
lift and a braking pose. Root and horizontal hip translation remain in place; vertical
hip compression is cosmetic. The underlying locomotion clock continues while the
full-body pose owns the visible character, then resumes without restarting its gait.

## Reuse and integration

`scripts/player/action_library.gd` installs the rig's `Actions` library and supplies
shared action definitions. Cast uses upper-body priority 10; dodge uses noninterruptible
full-body priority 40. These are presentation arbitration defaults, not combat balance
or invulnerability rules. Death/reset still clears any action immediately.

`CharacterAnimation.present_action(spec)` is the common adapter for accepted future
actions and isolated gallery previews. It rejects missing definitions, manual raw-clip
ownership and dead characters. No new input handler calls it in normal gameplay.

Rebuild using the installed Godot binary:

```
godot --headless --path . --script res://tools/build_cast_dodge.gd
```

Generated libraries and the manifest live in `assets/animations/actions/`. They contain
only bone rotation, translation and scale tracks; no method, audio, damage, projectile
or body-displacement tracks. Metadata records blockout provenance and visual markers.

## Gallery review

Open `scenes/characters/AnimationReviewGallery.tscn` and press F6. New entries are:

- `Cast/Idle`, `Cast/Walk`, `Cast/Run`, `Cast/Strafe`, `Cast/Backward`.
- `Dodge/Forward`, `Dodge/Backward`, `Dodge/Left`, `Dodge/Right`.

Both models repeat each action over the selected base motion. Pause, slow playback,
restart and source-frame stepping use the same layer controller as melee. Bodies
stay fixed so reviewers can inspect joint motion independently of gameplay travel.

## Validation and limits

The new pose regression covers both rigs, all clips and five casting movement states,
actual lower-body continuity, forward release reach/height, directional dodge lean,
finite/resolvable bone tracks, gait recovery and unchanged body velocity, transform
and health. All 266 focused checks passed on Godot 4.7.2, including every new gallery
mode on both rigs, source-frame stepping at 0.25x, invalid-action rejection and
manual/runtime ownership. Existing layered-animation (310), animation-foundation
(28) and Demo 1 snapshot-hardening (20) checks also passed: 624 checks across four
suites. `git diff --check` passed. The reproducible builder completed for both rigs.
These headless checks do not replace rendered review or a multiplayer performance test.

Visual review remains open: hand/palm orientation, finger articulation where supported,
weapon/armor clearance, planted feet between samples, natural weight transfer and
readability at gameplay distance. The IK targets establish limb reach but do not prove
outward palm alignment or final motion quality.

Gallery playback remains cosmetic. The local F5 harness adds collision-based dodge
travel and non-damaging energy bolts for hands-on motion review. Before enabling
competitive ranged or dodge gameplay, define
accepted aim mode/yaw/pitch, server-owned cast phase and projectile origin/obstruction,
projectile trajectory/damage/cooldown, and dodge travel/collision/cancellation/cooldown.
Invulnerability is a separate explicit decision. Persistent aim/guard stances, charged
casting and dodge camera feedback remain later work. The local harness adds R/Q/Tab
test bindings; the network wire format remains unchanged.
