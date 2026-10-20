# Layered animation checkpoint — 20 October 2026

## Scope

Ordinary accepted melee swings overlay the upper body while the legs continue idle,
walking, running or directional stepping. Both characters reuse their four existing
attack clips; no duplicate run-attack/walk-attack/strafe-attack assets are generated.
This fixes presentation only. Damage, cooldowns, movement, input and networking rules
remain owned by their existing systems.

## One animation owner

`character_animation.gd` selects movement from velocity with existing speed and
direction hysteresis. `layered_animation.gd` owns one per-model AnimationTree:

```
Previous locomotion -> TimeSeek --\
                                  Blend2 -> masked action Blend2 -> output
Current locomotion  -> TimeSeek --/                   /
Action clip         -> TimeSeek --------------------/
```

Independent clocks sample the same imported clips. Locomotion rate follows measured
speed and normalized gait phase survives gait changes. The action clock always runs
at normal presentation speed; gallery slow motion scales both clocks together.
Manual evaluation prevents a second automatic tree update when stepping a frame.
The original AnimationPlayer is stopped during runtime and retained as a clip library.
Raw gallery playback explicitly disables the tree before controlling that player.

Upper-body filters are generated from each actual Skeleton3D hierarchy beginning
at `spine`. The Arclight and Ashen Warden rig prefixes are resolved independently.
Root, hips and legs remain on locomotion. Missing masks reject upper-body actions
instead of silently replacing the whole pose. A full-body action deliberately
disables the filter while keeping locomotion's hidden clock advancing.

`animation_action.gd` is a reusable Resource contract: clip, layer, priority,
interruptibility and blend-in/out. Optional per-character definitions override shared
melee defaults. Higher/equal priority may replace an interruptible action; lower
priority cannot replace it. Authoritative death clears any action regardless of
its priority. Runtime model replacement rebuilds the player, tree and mask.

## Future movement strategy

| Family | Presentation strategy | Gameplay dependency |
|---|---|---|
| Light melee, cast release | Upper-body action over shared locomotion | Accepted action/phase; casting not enabled yet |
| Aim and guard | Persistent masked stance, transient actions coordinated above it | Accepted aim/guard state, facing and pitch |
| Small hit response | Additive local reaction after additive clips exist | Confirmed hit; must not imply stun |
| Heavy planted melee, dash, stagger, death | Explicit full-body ownership | Controller/server movement and interruption policy |
| Jump/fall/land, starts/stops, pivots | Base movement states driven by actual motion/contact | Ground/air and acceleration state contracts |

Keep movement restrictions in gameplay ActionSpecs: free movement, reduced speed,
direction lock, rooted or authoritative displacement. A presentation resource does
not enforce these rules or grant a dash, guard, hit or projectile. Add states and
clips when their motion genuinely differs; avoid one state or clip per combination
of weapon, movement and action. Continue to share semantics across rigs, validating
each rig's mask and weapon contact separately.

The current action clock still uses clip duration, and the existing replicated swing
counter still chooses variants. Server action IDs, life epochs and phase timing,
late-event recovery, combat contact alignment and persistent stances remain planned.
The existing remote jump-apex heuristic also remains unchanged.

## Review and validation

Open `scenes/characters/AnimationReviewGallery.tscn`, press F6 and select the
`Layered/WalkAttack`, `Layered/RunAttack`, `Layered/StrafeAttack` or
`Layered/BackwardAttack` entries. Both rigs cycle the four attacks over locomotion.
Bodies remain fixed for inspection. Pause, slow playback and frame stepping remain
available; raw clip preview modes retain their existing indices.

The new `tests/integration/layered_animation_smoke_test.gd` compares actual lower-body
poses against a locomotion-only reference throughout all four attacks at five speeds/
directions on both rigs. It checks upper-body contribution, gait phase, action timing,
movement changes, full-body arbitration, replicated death, manual preview ownership
and model rebinding. Existing animation and snapshot regressions are adapted to
query separate locomotion/action diagnostics.

Godot 4.7.2 headless validation passed all 310 focused layered-animation checks.
Eleven existing regression suites also passed: animation foundation (28), directional
animation (147), human gait (52), Demo 1 hardening (20), reaction blockouts (84),
movement, combat, match, model import, player feedback and facing mode. The final
focused run includes the reviewer-discovered run-to-idle reset and slow frame-step
regressions. `git diff --check` passed. Existing unrelated working changes were retained.

The first editor import attempt could not create its default user-data directories.
Runtime QA redirected APPDATA/LOCALAPPDATA into ignored `.godot/qa-*` folders and
completed successfully. A full editor import was not established by that failed
attempt. No real-client ENet/eight-player performance test was rerun for this change;
snapshot presentation was checked by the hardening suite.

Automated pose checks do not establish visual polish: torso/pelvis weight transfer,
weapon/armor clearance and natural moving melee need owner review. No portable demo
rebuild, commit or push.

API reference: [Godot AnimationTree and track filtering](https://docs.godotengine.org/en/stable/tutorials/animation/animation_tree.html).
