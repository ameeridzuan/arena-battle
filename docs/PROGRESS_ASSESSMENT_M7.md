# ArenaBattle - Progress Assessment at M7 (APPROVED - owner decisions locked 2026-10-17)

> Historical checkpoint: current walk/run clips, speeds, thresholds and validation have since changed. See HUMAN_MOTION_CHECKPOINT.md for the latest implementation.

- **Author:** Lead Architect (Agent A / C1)
- **Date:** 2026-10-17
- **Status:** APPROVED - owner decisions locked 2026-10-17 (combat timing = Option B;
  .blend sources confirmed present). This is an **additive** document. It does **not** modify
  any script, scene or test. The governance/spec documents have now been updated to reflect
  the approved plan and the two locked decisions.
- **Assessed revision:** `main` @ `70dd88c` ("M7: dual character models ... + animation"),
  pushed to `origin`, working tree clean.
- **Engine actually used for verification:** `Godot_v4.7.2-stable_win64_console.exe`,
  `--version` reported `4.7.2.stable.official.ed1daf0bf`.

> Encoding note: this file deliberately uses ASCII punctuation only (no em dashes). See AB-011 -
> `scripts/multiplayer/network_session.gd` currently contains four double-encoded em dashes in
> player-visible strings, which is how a documentation/encoding hazard becomes a shipped defect.

---

## A. EXECUTIVE SUMMARY

### A.1 Overall health

**Amber. The engineering foundations (M1-M5) are genuinely solid and genuinely verified; the M7
"content expansion" milestone is not complete, was committed and pushed as if it were, and the
governance trail for M5, M6 and M7 does not exist.**

What is real and good:

- **238 automated checks pass, and I ran every one of them myself** rather than trusting the
  reports: 103 local (movement 3, combat 9, match 44, facing_mode 8, player_feedback 15,
  model_import 24) plus 67 two-peer and 68 eight-player multiplayer checks. `--headless --import`
  exits 0 with no errors or warnings. See Appendix 1 for the exact commands.
- **The server-authoritative security model is sound.** I actively tried to find an authority hole
  and failed. Input validation, sequence anti-replay, token-bucket rate limiting, stale-input stop,
  roster caps, team balancing, friendly-fire suppression, server-only outcome determination and
  post-match mutation gates are all implemented and all adversarially tested (20 server-side
  adversarial checks in `multiplayer_peer_test.gd`, 18 in `multiplayer_eight_peer_test.gd`).
  See RC-09.
- **The glTF/Blender hand-off contract is correct.** I derived the facing convention from rest-pose
  bone positions and it matches the code on both sides (RC-05, RC-06). This was not assumed.
- **Component separation is clean** (`health.gd`, `combatant.gd`, `melee_attacker.gd`,
  `match_manager.gd`, `replica_match_state.gd`, `hud.gd` are small, single-purpose and typed),
  there is not one `TODO`/`FIXME`/`HACK` in the repo, and the test harness design (real Godot
  processes orchestrated by Python, JSON reports, file markers for deterministic ordering) is
  better than typical for a solo project.

What is not good:

- **M7 delivered roughly a quarter of its own documented scope**, and the roadmap was never
  updated to say so. Against `DEVELOPMENT_ROADMAP.md:372-374`, the shipped M7 provides the second
  character model and its animation driver. It provides **no ability for either character (zero
  ability code exists), no character selection (the API for it has zero call sites and is broken),
  no HUD work (the shipped HUD still says "Milestone 3"), no sound (zero audio assets or nodes in
  the repository), no authored effects (only the M3 placeholder swipe), and no arena art
  (the arena is still five grey boxes).**
- **The one thing M7 claimed to fix - remote animation - does not work in multiplayer at all.**
  AB-001: no character, including your own, ever plays an attack animation in a networked match.
  All 238 tests pass because not one of them looks.
- **The art assets are structurally wrong for a 4v4 game.** AB-004: 135 and 214 separate mesh
  nodes per character against only 7 and 9 distinct materials - a full 4v4 client instantiates
  **1633 skinned mesh nodes and ~1633 draw calls where 16 would do**. There is no performance
  test, no FPS gate and no budget anywhere in the project.
- **`docs/` can no longer be trusted to describe the project.** AB-012: the roadmap's M7 section
  has no status, no acceptance criteria and no verification block; "Immediate Next Steps" still
  points at the M5 playtest and commit `459b0ec`; `DECISIONS.md` stops at ADR-0011 (M4) so there
  is no ADR for M5, M6 or M7; `ART_IMPORT_CONVENTIONS.md` is contradicted by the shipped assets on
  at least five points (AB-013); and `TECHNICAL_ARCHITECTURE.md:786,799,811` still promises client
  prediction and display interpolation that ADR-0011 explicitly abandoned and the code does not
  implement (AB-008).
- **Two architectural anti-patterns will block the very next milestone.** AB-003 (instance
  configuration written into shared `Resource` objects - proven for both collision shapes and
  imported animations) and AB-020 (exactly one `class_name` and zero `.tres` resources in the whole
  repository, so every cross-module boundary is a duck-typed `get_node("Name")` string). M7
  requires "one distinct ability per character"; you cannot build per-character data-driven
  behaviour on either of those foundations.

### A.2 Readiness

| Question | Answer |
|---|---|
| Is the build stable and runnable? | **Yes.** Clean import, clean tree, 238/238 checks green, exit 0. |
| Is M5 (4v4 foundation) done? | **Functionally yes, formally no.** `DEVELOPMENT_ROADMAP.md:347` still reads "owner playtest pending"; no manual acceptance was ever recorded. |
| Is M6 (art pipeline) done? | **Mostly.** Assets import and animate; manual F5 look-dev is recorded as pending at `:370`; the conventions doc is stale; the pipeline is not reproducible from a clone (AB-024). |
| Is M7 (expand content) done? | **No - about 25%.** Second character: yes. Ability per character, character select, HUD, sound, effects, arena art: no. |
| Can we start M8 (online readiness)? | **No.** M8 needs interpolation, reconnect, per-peer abuse escalation and a measured bandwidth/frame budget. None exist, and AB-004/AB-008/AB-015/AB-028 are all M8 blockers. |
| Is the project safe to hand to another agent? | **Not from `docs/` alone.** A new agent reading only the roadmap and DECISIONS.md would conclude M7 is complete and M5/M6/M7 are all ADR-recorded. All three conclusions are false. |

### A.3 Top 5 concerns (ranked)

1. **Verification blind spot, not a code blind spot (AB-001, AB-010, CG-01..CG-13).** The test
   suite is large, deterministic and green - and it asserts nothing about anything M7 added. Nine
   of the confirmed defects below were found by a read-only diagnostic I had to write because no
   test covers animation, model identity, the team marker, the runtime swap, budgets or HUD copy.
   One existing check is an outright proxy: `player_feedback_smoke_test.gd:51` asserts
   `mesh.material_override != original` on the **invisible `Mesh` anchor whose own `mesh` is null**
   (`A.mesh_own_mesh_is_null = true`), so it would pass even if the model were never tinted.
   "All tests pass" is currently being used as evidence for milestones the tests do not examine.
2. **Performance is unmeasured and the asset structure guarantees a problem (AB-004, AB-015).**
   1633 skinned mesh nodes per 4v4 client, 24x more draw calls than the material count requires,
   `generate_lods` and `create_shadow_meshes` both on, and the headless authoritative server
   building 1856 nodes / 1728 mesh instances / 8 live AnimationPlayers / 8 cameras and 39.1 MB for
   a process that renders nothing. No FPS gate, no draw-call assertion, no budget document.
3. **The next milestone is architecturally blocked (AB-003, AB-009, AB-020).** Per-character
   abilities need per-character data. There are no Resource types, no `resources/` directory, one
   `class_name` in the entire repo, character identity is decided per-viewer and never replicated,
   and two independent proofs that mutating a per-instance export silently rewrites a shared
   resource for every other instance (`R.leak_confirmed = true`).
4. **Combat feel is decoupled from the authored animation (AB-005, AB-006).** Damage resolves in
   the same physics frame the swing starts (`melee_attacker.gd:78` then `:82-105`), while the
   authored clips run 1.033-1.833 s and the cooldown is 0.6 s. Damage therefore lands roughly
   1-1.8 s **before** the visual contact frame, locomotion animation is frozen for the whole clip
   while the body keeps moving at up to 10 m/s, and the two characters' "identical" clip set has
   different durations for 8 of 9 clips. There is no METHOD or VALUE track in any clip
   (`AA.*.attack_slash_track_types = {"1":1,"2":16}`) so nothing in the animation *could* gate a
   hit window today.
5. **Documentation and governance integrity (AB-012, AB-013, AB-022, AB-029).** Three milestones
   with no ADR, a roadmap whose M7 section is the untouched original scope text, an
   `ART_IMPORT_CONVENTIONS.md` that contradicts the shipped assets, a shipped HUD that still
   advertises Milestone 3, four mojibake strings in the most important session-status messages,
   and a toolchain whose engine binary lives outside the repository at a path that the brief for
   this very assessment recorded incorrectly.

### A.4 Recommendation

Do **not** proceed to M8 and do **not** start authoring abilities yet. Run one hardening milestone
(**M7.1**, section D) that (i) reconciles `docs/` with reality, (ii) fixes the presentation
contract so animation and model identity actually work in multiplayer, (iii) isolates shared
resources, (iv) establishes and enforces a performance budget, and (v) builds the test coverage
that should have gated M7. Then re-plan the remainder of M7 as **M7.2** (server-assigned character
identity + selection UI) and **M7.3** (abilities, audio, effects, arena art) on top of a foundation
that can actually carry them.

---

## B. MILESTONE STATUS TABLE (M0-M8)

Status key: DONE = implemented, automatically verified **and** owner-accepted. VERIFIED =
automatically verified but owner acceptance not recorded. PARTIAL = some scope delivered.
NOT STARTED = no code/assets exist.

| M | Name | Real status | Evidence |
|---|---|---|---|
| **M0** | Project setup & governance | **DONE** | `project.godot` (Godot 4.7, Forward Plus, 1280x720, `stretch canvas_items/expand`, input map, `physics/3d/default_gravity=20.0`, layer names World/Player/DamageableTarget). `docs/` has 10 files; `FOUNDATION_INSTRUCTIONS.md`, `AGENT_RULES.md`, `AGENT_TEAM.md` present. `--headless --import` exit 0. **Gaps:** FOUNDATION §3 requires `resources/{characters,weapons,abilities}` and `scripts/{core,abilities}` - **none exist** (glob for `*.tres`/`*.res` returns 0 files). `.gitignore:29-37` LFS block still commented out with ~12 MB of binaries committed. `export_templates/`, `feature_profiles/`, `script_templates/`, `text_editor_themes/` are all empty. |
| **M1** | Movement & camera | **DONE** | `player_controller.gd` (162 lines, all tunables `@export`), `camera_rig.gd` (44), `Player.tscn`, `Arena.tscn`. `movement_smoke_test.gd` 3/3 green (ran it). Later hardened by the M6 camera-lock work (`aa95f66`) and covered by `facing_mode_smoke_test.gd` 8/8 green. **Gap:** `player_controller.gd:122-124` `_handle_jump()` is dead code - grep returns exactly one hit repo-wide, its own definition (AB-021). |
| **M2** | Combat & damage | **DONE** | `health.gd` (66), `melee_attacker.gd` (106), `combatant.gd` (162), `DummyTarget.tscn`. `combat_smoke_test.gd` 9/9 green (ran it). **Gaps:** `health.gd:35` has no upper clamp (AB-016, proven: `U.health_after_negative_damage = 150.0` vs `U.max_health = 100.0`); `melee_attacker.gd:39-45` mutates a shared `SphereShape3D` (AB-003a, proven `R.leak_confirmed = true`); damage resolves on frame 0 of the swing with no windup (AB-005). |
| **M3** | Local gameplay loop (TDM) | **DONE** (owner accepted 2026-10-16) | `match_manager.gd` (114), `hud.gd` (192), `Main.tscn`, `HUD.tscn`. `match_smoke_test.gd` **44/44 green** (ran it; the 2 warnings in the log are the deliberate null-source `push_warning` from `combatant.gd:94`, documented at `DEVELOPMENT_ROADMAP.md:775`). M3 follow-up (feedback/HP HUD) accepted: `player_feedback_smoke_test.gd` 15/15 green. **Gap:** `Opponent1`/`Opponent2` in `Main.tscn` are still grey `BoxMesh` placeholders - `A.opponent1_has_CharacterAnimation = false`, `A.opponent1_mesh_type = BoxMesh` (AB-025). |
| **M4** | Multiplayer PoC (2 peers) | **DONE** (owner accepted: "seems to work. can proceed") | `network_session.gd` (423), `MultiplayerArena.tscn`, ADR-0011, `tests/M4_QA_REPORT.md`. **Ran it:** `run_multiplayer_smoke.py` -> `ALL_MULTIPLAYER_TESTS_PASS=true checks=67 EXIT=0` across all four scenarios (gameplay 20+8+8, disconnect 4+6+5, timeout 4+5+5, unavailable 2), loopback RTT 6-8 ms. **Gaps:** 4 mojibake strings introduced by this milestone's baseline commit `459b0ec` (AB-011); `_submit_input` is `unreliable_ordered` so action edges can be silently dropped (AB-019); `max_clients` off by one (AB-018); no interpolation despite `TECHNICAL_ARCHITECTURE.md:799` (AB-008). |
| **M5** | 4v4 match foundation | **VERIFIED - owner acceptance never recorded** | `replica_match_state.gd` (39), roster/team/slot logic in `network_session.gd`, 4 spawn markers per team in `Arena.tscn`. **Ran it:** `run_eight_player_smoke.py` -> `ALL_EIGHT_PLAYER_TESTS_PASS=true checks=68 EXIT=0` (server 18, 8 clients x 6, extra 2). **But** `DEVELOPMENT_ROADMAP.md:347` heading still reads "(automatically verified; owner playtest pending)" and `M5_MATCH_FOUNDATION.md:3,53-54` still says "owner visual playtest pending ... Human visual acceptance and physical LAN validation of this M5 build remain pending." No ADR exists for M5. Documented limits (no matchmaking/lobby/reconnect/prediction/interpolation/lag compensation) all still hold. `M5_MATCH_FOUNDATION.md:12` claims "ENet capacity is eight" which is inaccurate (AB-018). |
| **M6** | Art & character pipeline | **VERIFIED - manual look-dev pending; conventions doc stale** | `player.glb` (20 bones, 2 meshes, 1 animation - `I.player_legacy`), `player_model_preview.gd`, both preview scenes, `model_import_smoke_test.gd`, `ART_IMPORT_CONVENTIONS.md`, `tools/export_characters.py`. Commit `ba2d07d` swapped the model into `Player.tscn` keeping `Mesh` as the anchor. Regressions at `DEVELOPMENT_ROADMAP.md:369` (movement 3, combat 9, match 44, feedback 15, two-client 67, eight-client 68) **all reproduced green by me**. **Gaps:** `:370` "Manual F5 look-dev (facing/feel) pending" - never recorded. No ADR. `ART_IMPORT_CONVENTIONS.md:44-45` still says the swap "is deferred until the M4/M5 multiplayer work merges; M6 delivers assets + preview + automated gate only", which M6 itself violated. `tools/export_characters.py` hardcodes out-of-repo `.blend` paths (AB-024). `player_model_preview.gd` doc/code drift (AB-023). `player.glb` is now orphaned. |
| **M7** | Expand content | **PARTIAL - roughly 25% of documented scope; committed and pushed as if complete** | Roadmap scope (`DEVELOPMENT_ROADMAP.md:372-374`): "Second character; one ability per character; character select + HUD; sound/effects/improved arena art; incremental roster & arena growth." Delivered by `70dd88c`: `arclight.glb` (20 bones / 135 meshes / 9 clips), `ashen_warden.glb` (26 bones / 214 meshes / 9 clips), `character_model.gd` (52), `character_animation.gd` (131), team-marker orb replacing the full-body tint (`network_session.gd:233-246`), `player_feedback.gd` no longer drives animation. **Item-by-item:** second character = PARTIAL (assets exist, not selectable, identity viewer-relative AB-009); one ability per character = **NOT STARTED** (grep for `ability`/`Ability` across all `.gd`/`.tscn` returns 2 hits, both inside a comment at `health.gd:46`); character select = **NOT STARTED** (`set_character` has zero call sites, AB-021, and is broken, AB-002); HUD = **NOT STARTED / REGRESSED** (`T.controls_label_mentions_milestone3 = true`, AB-022); sound = **NOT STARTED** (grep `AudioStream` = 0 hits; glob `*.ogg/*.wav/*.mp3` = 0 files; no AUDIO track type in any clip); effects = PARTIAL (M3 `ImmediateMesh` swipe only; grep `GPUParticles`/`CPUParticles` = 0 hits); improved arena art = **NOT STARTED** (`Arena.tscn` is still a floor box + 4 wall boxes + `ProceduralSky`). **Governance:** `DEVELOPMENT_ROADMAP.md:372-374` has no status marker, no acceptance criteria and no verification block; no ADR-0012+; `:382-386` "Immediate Next Steps" still lists the M5 playtest and commit `459b0ec`. |
| **M8** | Online readiness | **NOT STARTED** | Scope at `DEVELOPMENT_ROADMAP.md:376-378`. No dedicated-server build path, no lobby/matchmaking, no auth, no monitoring or crash reporting, no per-peer abuse escalation (`rejected_inputs`/`rate_limited_inputs` at `network_session.gd:38-39` are global counters that never trigger a kick), no network performance testing, no security review. Prerequisites currently unmet: AB-004, AB-008, AB-015, AB-019, AB-028. |

**Roll-up:** M0-M4 DONE (5), M5-M6 VERIFIED but not formally accepted (2), M7 PARTIAL ~25% (1),
M8 NOT STARTED (1). **Three consecutive milestones have no ADR**, which breaches
`AGENT_RULES.md` §3.10 and the `AGENT_TEAM.md` §9 KPI "Docs/decision currency - every milestone
has an updated ADR + roadmap entry."

---

## C. BUG / TECH-DEBT / RISK REGISTER

Severity: **Critical** = breaks the build or corrupts authoritative state. **High** = breaks a
shipped or next-milestone feature, or an unmeasured risk that likely makes the game unplayable.
**Medium** = real defect or blocker for the next milestone, with a workaround today.
**Low** = hygiene, latent or cosmetic.

Category: `bug` (wrong behaviour) / `tech-debt` (structure that will cost later) /
`risk` (unmeasured exposure) / `coverage-gap` (no test would catch it).

**There are zero Critical findings.** The build imports clean, the tree is clean, all 238 checks
pass, and I could not break server authority. Everything below is High or lower.

### C.1 Confirmed defects (reproduced, with runtime or byte-level evidence)

| ID | Sev | Cat | Title | Evidence | Impact | Recommended fix |
|---|---|---|---|---|---|---|
| **AB-001** | **High** | bug | No attack animation ever plays in multiplayer - for any player, including your own | `network_session.gd:353-357` reacts to a new server swing by calling **only** `body.get_node("PlayerFeedback")._on_attack_started(forward)`. `character_animation.gd:41-43` binds its attack trigger **solely** to `AttackHitbox.attack_started`, and `network_session.gd:224` does `attack.set_physics_process(false)` on every client body, so that signal can never fire client-side. Every body in a session is `external_control` (`:195`), the local one included. **Runtime proof:** `E.hitbox_physics_processing = false`, `E.after_snapshot_swing_attack_playing = false`, `E.after_snapshot_swing_current_animation = Idle`, while `E.swipe_visible = true` and `E.replica_locomotion_runs = Run`. | Characters slide around in Idle/Walk/Run and never swing. The M3 placeholder arc is the only attack tell, so there is no windup to read and no way to react. Contradicts the M7 completion claim and `M5_MATCH_FOUNDATION.md:45-46`, which required integration to "preserve ... remote animation". | Give `CharacterAnimation` a public `play_attack()`; promote `player_feedback._on_attack_started` to a public `show_swipe(forward)`; drive both from one place in `_receive_snapshot`. Add an MP assertion that a client enters the attack state within one snapshot of a server swing. |
| **AB-002** | **High** | bug | Runtime `set_character()` breaks three invariants at once | **(a) node-name contract:** `character_model.gd:42` uses deferred `queue_free()`, so `:49` `_model.name = "Model"` collides and Godot auto-renames. Proof: `F.children_immediately_after_swap = ["Model","@Node3D@5"]` -> `F.children_after_frames = ["@Node3D@5"]`, `F.Model_node_exists_after_swap = false`, `L.anim_path_after_swap = /root/DiagHolder/LBody/Mesh/@Node3D@11/AnimationPlayer`. **(b) damage flash:** `player_feedback.gd:30-31` captures `_skin_meshes` once in `_ready()` and never refreshes. Proof: `K.skin_refs_after_swap = 135`, `K.skin_refs_still_valid = 0`, `K.skin_refs_freed = 135`, `K.real_mesh_count_after_swap = 214`, then `SCRIPT ERROR: Invalid access to property or key 'material_override' on a base object of type 'previously freed'` and `K.real_tinted_after_damage = 0`. `_apply_override` aborts at `:72-73` before `:74` ever runs, so the flash is dead permanently. **(c) animation latch:** the freed AnimationPlayer can never emit `animation_finished`, so `character_animation.gd:120-122` never clears `_attack_playing` and `:74-75` returns early forever. Proof: `L.attack_playing_mid_swing = true` -> swap -> `L.attack_playing_after_swap = true`, `L.current_after_swap = ""`, `L.current_after_run_velocity = ""`, `L.is_playing_after_run_velocity = false`, `L.attack_playing_still_latched = true`. | **Latent today** - grep shows `set_character` has exactly one hit repo-wide (its own definition at `character_model.gd:34`); `network_session.gd:209` assigns the `character` export directly before `add_child`. But this *is* the M7 character-select API. The moment it is used, a player becomes permanently invisible to the hurt flash, frozen in animation, and its `Mesh/Model` path unresolvable - plus one script error per hit. | Free the old model synchronously (`remove_child` + `free()`, or rename it before `queue_free()`) so `Model` is always the name. Add `signal model_changed(character: int)` emitted after the new child is in the tree; have `PlayerFeedback` re-capture `_skin_meshes` and `CharacterAnimation` rebind `_anim` and reset `_attack_playing = false`. Add `is_instance_valid()` guards in `_apply_override`/`_restore_override`. |
| **AB-003** | **High** | tech-debt | Instance configuration is written into **shared** `Resource` objects (two proven cases) | **(a) collision shapes:** `melee_attacker.gd:39-45` does `(shape as SphereShape3D).radius = attack_range` on `col.shape`. Proof: `R.attack_shape_is_same_resource = true`, `R.attack_shape_local_to_scene = false`, `R.body_shape_path = res://scenes/characters/Player.tscn::body_shape`, and after setting only instance B's `attack_range = 3.0`: `R.attack_radius_a_after_b_changed = 3.0`, **`R.leak_confirmed = true`**. (`R.dummy_attack_shape_shared_with_player = false`, so the leak is confined to Player instances.) **(b) imported animations:** `character_animation.gd:60-66` sets `loop_mode` via `_anim.get_animation(clip)`. Proof: `Q.idle_animation_same_resource = true`, `Q.idle_local_to_scene = false`, `Q.idle_animation_resource_path = res://assets/models/arclight.glb::Animation_g6ux4`, `Q.other_instance_sees_mutation = 2` (setting PINGPONG on A is instantly visible on B), `S.distinct_idle_animation_resources = 1` across 8 bodies. Same pattern in `player_model_preview.gd`. **`resource_local_to_scene` appears nowhere in the repo (grep: 0 hits).** **Important nuance:** `Q.idle_loop_mode_before = 0` and `arclight.glb.import:42` is `_subresources={}` - the imported clips do **not** loop, so this runtime mutation is currently *load-bearing* and cannot simply be deleted. | Benign today (all players share one stat block, all bodies want the same loop modes). It **hard-blocks per-character stats and abilities** - the exact M7 requirement: if Arclight gets 3 m reach and Warden keeps 2 m, the last `_ready()` to run wins for every player, and the code-level range gate at `melee_attacker.gd:100` would then disagree with the broad-phase sphere. It also leaks into the editor and the preview scenes. | Set loop modes at import time via `_subresources` in both `.glb.import` files, then delete `_configure_loop_modes()` and the preview mutation. In `melee_attacker._ready()`, `col.shape = col.shape.duplicate()` before resizing. Add a regression test that two instances are independent. Note: `_subresources` keys on generated names like `Animation_g6ux4`, so the test must assert by AnimationPlayer clip name, not resource path. |
| **AB-004** | **High** | risk | Character geometry is over-fragmented; a 4v4 client builds ~1633 skinned mesh nodes with no measured budget | `P.arclight`: `mesh_instance_nodes = 135`, `distinct_mesh_resources = 135`, **`distinct_materials = 7`**, `vertices = 46878`, `triangles = 37530`. `P.ashen_warden`: `mesh_instance_nodes = 214`, `distinct_mesh_resources = 214`, **`distinct_materials = 9`**, `vertices = 63304`, `triangles = 52694`. Import flags `meshes/generate_lods = true` and `meshes/create_shadow_meshes = true` (`arclight.glb.import:27-28`) multiply the per-node cost. `G.feedback_captured_names` shows the fragmentation directly - e.g. 10 separate `Longsword - grip winding*` meshes, 12 `Heraldry - broken sun ray*`, 16 `Gauntlet - finger lame*`. | 4v4 client = 1 Arclight + 7 Warden = **1633 MeshInstance3D nodes, ~415k vertices and ~1633 draw calls where 16 would suffice** (7 + 9 distinct materials) - a 24x over-draw-call. Each node also costs an AABB, a cull test, an LOD evaluation and a shadow-mesh pass every frame. Very likely unplayable at 1280x720 on integrated graphics. **There is no performance test, no FPS gate and no budget document anywhere in the project.** | Re-export with meshes joined per material (target <= 12 mesh objects and <= 8 materials per character). Until then, add a headless budget test asserting node/mesh/material/triangle caps, and record a manual FPS gate. Treat as an asset task for C8 - blocked by AB-024. |
| **AB-005** | **Medium** | bug | Attack clips are 1.7x-3x the attack cooldown; damage resolves before the visual contact frame | `AA.arclight.clip_lengths_s`: Slash **1.033**, Backhand 1.033, Overhead **1.433**, Thrust 1.133, Combo **3.033**. `AA.ashen_warden`: Slash **1.433**, Backhand 1.433, Overhead **1.833**, Thrust 1.433, Combo **4.033**. `melee_attacker.gd:18` `attack_cooldown = 0.6`. `melee_attacker.gd:78` emits `attack_started` and `:82-105` applies damage **in the same call, same physics frame**. `character_animation.gd:74-75` blocks all locomotion while `_attack_playing`. `AA.*.attack_slash_track_types = {"1":1,"2":16}` / `{"1":1,"2":22}` = POSITION_3D + ROTATION_3D bone tracks only - **no METHOD (7) or VALUE (0) track exists**, so nothing in the animation could gate a hit window. | (i) After a swing the character cannot animate Walk/Run/Idle for 1.03-1.83 s while still travelling at up to 10 m/s -> visible foot-sliding. (ii) A new swing is legal every 0.6 s but the clip needs 1.03-1.83 s, so clips are permanently interrupted and the 4-clip cycle never reads. (iii) Damage lands ~1-1.8 s **before** the visual contact, so there is no anticipation, no dodge read and no animation-driven hit window - the authored windups are pure decoration. | **Owner decision required.** Option A: re-time the authored clips to <= 0.6 s (asset work, blocked by AB-024). Option B (recommended): keep `attack_cooldown` as the rate limit and add authoritative `attack_windup_s` / `attack_active_s` / `attack_recover_s`; the server applies damage only after the windup, and `_attack_playing` suppresses locomotion only during windup+active. See ADR-0016. |
| **AB-006** | **Medium** | bug | The two characters do **not** share animation timings despite the "canonical set" claim | Same clip name, different duration for **8 of 9** clips: Slash 1.033 vs 1.433, Backhand 1.033 vs 1.433, Overhead 1.433 vs 1.833, Thrust 1.133 vs 1.433, Jump 1.433 vs 1.633, Walk 1.233 vs 1.633, Run 0.833 vs 1.033, Combo 3.033 vs 4.033. Only `Idle` matches (2.033). `model_import_smoke_test.gd` asserts clip **names** only, never durations. | Because identity is viewer-relative (AB-009), the same logical player animates at different speeds on different screens. Any animation-gated combat timing (AB-005 option B) would be inconsistent per character. Balance comparison between characters is impossible. | Publish a canonical per-clip duration table (with tolerance) in `ART_IMPORT_CONVENTIONS.md` v2 and assert it in `model_import_smoke_test.gd`. Either re-time the assets or explicitly accept per-character timing as a design feature and record it in an ADR. |
| **AB-007** | **Medium** | bug | `set_character()` destroys the model before validating the requested id | `character_model.gd:41-47`: `_model.queue_free()` runs first, then `SCENES.get(character)` returns null and the function returns with no model. Proof: `N.children_before = ["Model"]`, `N.skin_meshes_before = 135` -> `set_character(7)` -> `N.children_after_7 = []`, `N.character_value_after_7 = 7`, `N.skin_meshes_after_7 = 0`, `N.anim_null_after_7 = true`, **`N.body_still_physics_processing = true`**. Identical for `-1`. | An out-of-range character id yields an **invisible but fully collidable, fully damage-dealing player** plus a `push_warning`. No clamp, no fail-safe, no fallback. Character select (M7 requirement) is exactly the code path that would supply a bad index from a UI or a network field. | Validate before mutating: look up `SCENES` first and return `false` (keeping the current model) on a miss. Add a `bool` return so callers can detect failure. Add a test for `-1`, `7` and a valid re-select. |
| **AB-008** | **Medium** | risk | No snapshot interpolation or prediction - contradicting the project's own architecture document | `network_session.gd:348-350` writes `body.position`, `body.velocity` and `Mesh.rotation.y` **directly** from the wire, with no buffer, no blend and no dead reckoning. `network_session.gd:223` `body.set_physics_process(false)` on client bodies, so there is no prediction either. Measured cadence: `AE.physics_ticks_per_second = 60.0`, `AE.snapshot_hz_default = 20.0`, `AE.physics_frames_per_snapshot = 3.0`, `AE.metres_per_snapshot_at_run_speed = 0.5`, `AE.metres_per_render_frame_at_60fps = 0.1667`. **Documented contract violated:** `TECHNICAL_ARCHITECTURE.md:799` "Server tick is the single clock; **clients interpolate display**"; `:786` "client prediction mirrors locally"; `:811` "`player_controller.gd` (local prediction; server validates position)". | Every remote body teleports **0.5 m every 50 ms** - a 0.167 m jump on every third rendered frame with the body frozen in between. Loopback RTT is 6-8 ms, so **no automated test can ever detect this**; it appears only on a real LAN/WAN or under `--input-delay-ms`. Combined with AB-001 (no attack animation) the remote-player experience is currently stuttering slides. | Add a ~100 ms render-side interpolation buffer (two snapshots) for remote bodies plus short dead-reckoning extrapolation on snapshot gaps. **And** correct `TECHNICAL_ARCHITECTURE.md` §10 so the documented contract matches ADR-0011 and the shipped design. See ADR-0017. |
| **AB-009** | **Medium** | risk | Character identity is viewer-relative and never replicated | `network_session.gd:209` `mesh.character = 0 if id == _local_peer_id else 1`. The snapshot wire record at `:323-325` is `[id, team, slot, position, velocity, mesh_yaw, aim_yaw, hp, max_hp, dead, swings]` - **no character id**. On the server `_local_peer_id == 0`, so `id == _local_peer_id` is never true and **all 8 bodies become Warden** (consistent with `M.animation_players_actively_playing = 8` on an all-Warden roster). | Peer A sees itself as Arclight and everyone else as Warden; peer B sees the reverse; the server sees eight Wardens. **There is no agreed cast.** This makes character select, per-character abilities, per-character balance, spectator mode and replay impossible, and it makes any visual bug report unreproducible ("the Arclight player hit me through a wall" - which Arclight?). | The server assigns `character_id` at registration, stores it in the roster record, and appends it to the snapshot wire record (index 11). Clients apply it through a *fixed* `set_character()` (AB-002/AB-007). Wire-format change - `M5_MATCH_FOUNDATION.md:21-22` already states both peers must run the same version. See ADR-0015. |
| **AB-010** | **Medium** | coverage-gap | Zero automated coverage of everything M7 added | The 103 local + 135 multiplayer checks contain **no** reference to `character_animation`, `character_model`, `TeamMarker`, `Mesh/Model`, or any animation state. Grep: `set_character` = 1 hit (its own definition); `Attack_Combo` = **0 hits repo-wide** while `A.has_Attack_Combo = true` in both GLBs. `model_import_smoke_test.gd` `REQUIRED_ANIMS := ["Idle","Walk","Run","Jump","Attack_Slash"]` asserts **5 of 9** clips, and `mesh_ok := meshes.size() >= 2` against actual counts of 135/214. `player_feedback_smoke_test.gd:51` `_check("damage_flashes_player", mesh.material_override != original)` asserts on the **invisible `Mesh` anchor whose own `mesh` is null** (`A.mesh_own_mesh_is_null = true`) - a proxy that would pass even if the model were never tinted. | **Nine of the confirmed defects in this register would have been caught by tests that do not exist.** "All tests pass" is being used as evidence for milestones the tests do not examine - a direct breach of `FOUNDATION_INSTRUCTIONS.md` §5 ("Do not claim a feature is complete unless it has been tested") and `AGENT_RULES.md` §7. | See the test plan in D.7. Highest-value additions: a `character_presentation_smoke_test.gd`, a `model_budget_smoke_test.gd`, a `resource_isolation_smoke_test.gd`, extending `model_import_smoke_test.gd` to all 9 clips + durations + AABB, and fixing the `:51` proxy to assert on a real skinned child. |
| **AB-011** | **Medium** | tech-debt | Four double-encoded (mojibake) em dashes in player-visible session strings | Byte scan of `scripts/multiplayer/network_session.gd` (17546 bytes): `E2 80 94` (real UTF-8 em dash) occurs **1** time; `C3 A2 E2` (mojibake prefix) occurs **4** times. Locations: **`:84`** `hud.get_node("ControlsLabel").text = "ArenaBattle â€” Team multiplayer\n..."` (the client HUD), **`:381`** `"Player disconnected â€” session ended. Restart server and clients."`, **`:393`** `"Match ended â€” restart server and clients for a fresh match."`, **`:403`** `"Server disconnected â€” session stopped. Restart server and clients."`. The single clean em dash is the code comment at `:205` - i.e. **mixed encoding inside one file**. `git log -S "Team multiplayer"` attributes the corruption to **`459b0ec`** (the M4 baseline), not M7. Comparison files are clean: `combatant.gd` (7 real / 0 mojibake), `player_controller.gd` (9 / 0), `HUD.tscn` (2 / 0), `DECISIONS.md` (25 / 0). Tests miss it because `multiplayer_peer_test.gd:241` only asserts `status_text.begins_with("Server disconnected")`. | Corrupted on-screen text in the four most important session-status messages - disconnect, match end, server loss and the multiplayer controls card. Also proves there is no encoding guard anywhere in the toolchain. | Re-save the file as UTF-8 and repair the four strings. Add a repo-wide mojibake/non-ASCII byte check to the QA runner (`C3 A2`, `C3 AF`, `C2 BB` sequences) so this cannot recur silently. |
| **AB-012** | **Medium** | tech-debt | `docs/` has drifted from the shipped build; no ADR exists for M5, M6 or M7 | `DEVELOPMENT_ROADMAP.md:372-374` - the M7 section is the untouched original two-line scope, with **no status marker, no acceptance criteria and no verification block**, despite `70dd88c` being pushed. `:382-386` "Immediate Next Steps" still lists "Owner M5 playtest", "Coordinate M6 asset work" and "Review final test/documentation changes after owner commit **459b0ec**". `:347` M5 heading still "(automatically verified; owner playtest pending)". `DECISIONS.md` (239 lines) ends at **ADR-0011 (M4)**; its open-questions table still lists Q6 art direction as "Placeholder shapes / revisit by M6". `AGENT_TEAM.md:16-19` still says "M4 multiplayer PoC is automatically verified; owner multiplayer acceptance gates M5" and `:193-195` "Start M5 only after M4 acceptance". `TECHNICAL_ARCHITECTURE.md:786,799,811` promise prediction/interpolation that ADR-0011 abandoned (AB-008). | `AGENT_RULES.md` §3.10 and §7 (Definition of Done: "docs/decisions updated") are unmet for three consecutive milestones, and the `AGENT_TEAM.md` §9 "Docs/decision currency" KPI is failing. **A new agent or the owner cannot determine the real project state from `docs/`** - reading only the roadmap and DECISIONS.md yields three false conclusions (M7 complete, M5/M6/M7 ADR-recorded, prediction planned). | One documentation-reconciliation task, gated before any new feature work (D.2 Phase 0): update the roadmap M5/M6/M7/M8 sections and "Immediate Next Steps", add ADR-0012..0018 (section E), close or re-date the DECISIONS.md open questions, and correct `TECHNICAL_ARCHITECTURE.md` §10. |
| **AB-013** | **Medium** | tech-debt | `ART_IMPORT_CONVENTIONS.md` is stale and contradicted by the shipped assets on >= 5 points | Doc line -> shipped reality: **`:21`** "Origin: at the feet ... so Godot places characters on the floor with **no offset**" vs `character_model.gd:22` `MODEL_OFFSET = Vector3(0.0,-1.0,0.0)` (the origin rule is right - `I.arclight.aabb_min.y = 0.006`, `I.ashen_warden.aabb_min.y = 0.0065` - but the "no offset" conclusion is wrong for this capsule). **`:31`** animation naming "`Attack`, `Idle`, `Run`" vs the shipped 9-clip set. **`:44-45`** "the swap ... is **deferred** until the M4/M5 multiplayer work merges; M6 delivers assets + preview + automated gate only" vs `ba2d07d` (M6 swapped) and `70dd88c` (M7 replaced it with two models). **`:28`** weapons as "a SEPARATE mesh skinned to the hand bone ... so they stay swappable" vs the Warden's **16** separate longsword meshes. **`:33`** materials named `<Category>_<Name>` vs actual " - " (space em dash space) names, e.g. `Cuirass - gothic flute`. **Absent entirely:** the two-character roster, the host/remote mapping, the `Mesh`/`Mesh/Model` runtime-swap contract, uid references (`uid://5uteb3awcjrq`, `uid://bjouoksbyqluy`), any mesh/material/triangle budget, any per-clip duration table, any collider-vs-geometry extent rule. Lines `:40-43` *are* still correct and valuable (they warn that gameplay hard-references `$Mesh`, `CameraPivot`, `AttackHitbox`, `Combatant`, `Health`, `CollisionShape3D`). | The next asset drop has no valid contract to build against, and C8/C9 cannot be briefed. Three of the confirmed defects (AB-004, AB-006, AB-014) are convention gaps that a v2 document would have prevented. | Rewrite as v2 in the Phase 0 documentation task (owner: Architect), including the measured budgets and durations from this assessment, the `Mesh`/`Model` contract, the uid table and the extent rule. |
| **AB-014** | **Medium** | risk | Authored geometry substantially exceeds its collision volume | `I.ashen_warden.aabb_min = (-0.484, 0.0065, -0.4177)`, `aabb_size = (0.9056, 1.8165, 1.4977)` -> the model spans z from **-0.418 to +1.080 m**. `I.arclight.aabb_size = (0.843, 1.753, 1.0439)` -> z from -0.193 to +0.851. `Player.tscn:13-15` capsule is `radius = 0.5`, `height = 2.0` -> x/z extent is +/-0.5 m. | The Warden's longsword and cape protrude **0.58 m beyond** the collision capsule forward, so they visually pass through walls, through the arena boundary and through other characters during melee (which is exactly when they are closest). Both models also exceed the capsule sideways by ~0.35-0.48 m at the hands. Warden height 1.8165 m is marginally over the documented 1.7-1.8 m band; Arclight's 1.753 m is inside it. | Add an authored-extent budget to the conventions v2 (max abs(x)/abs(z) <= collider radius + tolerance; height <= 1.8 m) and assert it in `model_import_smoke_test.gd` via a world-AABB check. Then either pull the sword to the hip in the rest pose or consciously accept and document the overflow. |
| **AB-015** | **Medium** | risk | The headless authoritative server builds and animates full visual characters | `network_session.gd:192-228` `_spawn_player()` instantiates the full `Player.tscn` on the server too, with no headless path. Measured for 8 all-Warden bodies: **`M.total_nodes = 1856`**, **`M.mesh_instances = 1728`**, `M.skeletons = 8`, `M.animation_players = 8`, `M.cameras = 8`, **`M.animation_players_actively_playing = 8`**, `M.add_and_ready_8_ms = 61.5`, `M.static_memory_mb = 39.1`, `M.static_memory_peak_mb = 39.2`, `M.character_bodies_physics_processing = 8` (this last one is correct - the server must simulate). | A process that renders nothing carries 1728 renderable mesh nodes, 8 skeletons, 8 live AnimationPlayers ticking every physics frame (compounded by AB-026), 8 Camera3D nodes, ~39 MB and a 61.5 ms spawn hitch. Pure waste on the tick budget, and it multiplies directly against M8's dedicated-server goal. | Add `@export var headless_visuals: bool = false` on `network_session.gd` (set true when `server_mode`) and propagate it to `character_model.gd` so `_instantiate()` is skipped, and skip `CharacterAnimation`, `PlayerFeedback`, `CameraPivot` and `_add_team_marker` entirely. Keep `Mesh` as an empty anchor so the node-path contract still resolves. Add a server-side node-count assertion. |
| **AB-016** | Low | bug | `Health.apply_damage()` has no upper clamp | `health.gd:35` `_current = maxf(0.0, _current - amount)` - lower clamp only. Proof: `U.max_health = 100.0`, `U.health_after_negative_damage = 150.0`, **`U.exceeds_max_after_negative_damage = true`**. `apply_network_state` clamps correctly in both directions (`U.replica_clamps_negative = 0.0`, `U.replica_clamps_above_max = 100.0`), so only the **authoritative** path is unclamped. **This is foreseeable, not theoretical:** `health.gd:46` already documents `reset()` as deliberately "not `heal()` (partial restore, **a future ability**)", and M7 requires one ability per character. | Any negative `amount` (heal, lifesteal, an ability that refunds HP) exceeds `max_health`. The HUD would render "HP: 150 / 100" and `player_feedback.gd:90` (`current > _previous_health`) would treat it as a heal and clear the swipe. On the server this also breaks the `hp <= max_hp` invariant that `_broadcast_snapshot:325` relies on. | `_current = clampf(_current - amount, 0.0, max_health)`, and add an explicit `heal(amount: float) -> void` with its own contract and tests rather than overloading `apply_damage` with negative values. |
| **AB-017** | Low | bug | `_spawn_player()` indexes the spawn-point group with no bounds check | `network_session.gd:217-218` `var spawns := get_tree().get_nodes_in_group("spawn_team_%d" % team)` then `var spawn: Node3D = spawns[slot]`. Contrast `:242`, which *does* bounds-check `TEAM_COLORS`. `Arena.tscn` has exactly 4 markers per team and `TEAM_SIZE = 4` (`:13`), so it works today; my diagnostic reproduced the failure mode (`WARNING: [Combatant] ... group 'spawn_team_0' is empty`). | Any arena shipping fewer than `TEAM_SIZE` markers per team, or any future 3v3/5v5/2v2 configuration, produces an out-of-bounds script error **on the server** at spawn - killing the match for everyone. It is also the kind of bug a new arena artist would trigger without touching any code. | `if slot >= spawns.size():` push an error and reject the registration (fail closed), or use `spawns[slot % spawns.size()]` with a warning. Add a test with a deliberately under-populated spawn group. |
| **AB-018** | Low | tech-debt | ENet capacity is off by one and the channel count is an unexplained magic number | `network_session.gd:96` `_peer.create_server(port, required_players, 3)` and `:98` `_peer.create_client(server_address, port, 3)`. **Reflected signatures on this exact engine (`J.create_server`, `J.create_client`):** `create_server(port:int, max_clients:int, max_channels:int, in_bandwidth:int, out_bandwidth:int)` and `create_client(address:String, port:int, channel_count:int, in_bandwidth:int, out_bandwidth:int, local_port:int)`. | The host occupies peer id 1 and is not a client, so an 8-player match needs **7** client slots. Passing `required_players = 8` lets ENet admit a **9th** peer that `_register_player` must then reject - exactly what `multiplayer_eight_peer_test.gd:48-49` (`ninth_peer_rejected`, `ninth_peer_has_no_roster`) observes. `M5_MATCH_FOUNDATION.md:12` "ENet capacity is eight" is therefore inaccurate. Separately, neither `3` nor `required_players` has a named constant or a comment, contrary to FOUNDATION §5 / `AGENT_RULES.md` "no unexplained magic numbers". **Note: the suspicion that `3` was an `in_bandwidth` throttle is REFUTED - see RC-02.** | `const CHANNEL_COUNT := 3` with a comment listing channel 0 = snapshot, 1 = registration + input, 2 = ping; then `create_server(port, required_players - 1, CHANNEL_COUNT)`. Correct the M5 doc sentence. |
| **AB-019** | Low | tech-debt | Attack and jump button edges travel over an unreliable channel | `network_session.gd:258` `@rpc("any_peer","call_remote","unreliable_ordered",1)` on `_submit_input`. Edge accumulation at `:263-290` (`record.jump = record.jump or jump`, `record.attack = record.attack or attack`) with per-tick clearing at `_server_step:312-313` recovers loss **within** a tick only. | A packet dropped between ticks silently loses a swing or a jump, with no ack, no re-send and no client-side indication. At 60 Hz input on a good LAN this is rare; on Wi-Fi or a congested LAN it is not, and it presents to the player as "my attack didn't come out" - indistinguishable from a cooldown bug. | Move the two action edges onto a reliable channel (or a small dedicated reliable `request_action` RPC), keeping continuous movement on `unreliable_ordered`. Record the extra bandwidth in the M8 budget. |
| **AB-020** | Low | tech-debt | Cross-module private calls and duck-typed contracts; almost no typed interface layer | `network_session.gd:357` `body.get_node("PlayerFeedback")._on_attack_started(forward)` (private, cross-module). `:380` `manager._end_match(-1)` (private, cross-module). Tests do the same: `multiplayer_peer_test.gd` drives `session._broadcast_snapshot()` and `session._stage()` and pokes `AttackHitbox._cooldown_remaining = 0.0`; `facing_mode_smoke_test.gd` calls `hitbox._perform_attack()`; `player_feedback_smoke_test.gd` calls `hud._process(0.0)` and reads `hud._tint_remaining`. Repo-wide there is exactly **one** `class_name` (`Health`, `health.gd:1`) and **zero** `.tres`/`.res` files. | No compile-time contract exists between movement, combat, match, presentation and networking; every boundary is a `get_node("Name")` string. A rename silently breaks tests rather than the build, and three test suites would break on any internal refactor - which discourages refactoring. The absence of Resource types is also what makes data-driven characters (M7's core requirement) impossible without new structure. | Introduce `class_name` interfaces at the boundaries M7.1 touches (`CharacterPresentation`, and later `CharacterDefinition extends Resource`), and give tests public seams (`debug_force_snapshot()`, `debug_reset_cooldown()`) so they stop reaching into privates. |
| **AB-021** | Low | tech-debt | Dead code and orphaned assets | `player_controller.gd:122-124` `_handle_jump()` - grep returns **1 hit repo-wide, its own definition**; `_simulate_movement:74-75` inlines the jump instead. `character_model.gd:34` `set_character()` - grep returns **1 hit, its own definition**; never called by production or tests. `Attack_Combo` - grep returns **0 hits repo-wide**, yet `A.has_Attack_Combo = true` in both GLBs and it is the longest clip in each (`AA.arclight` 3.033 s, `AA.ashen_warden` 4.033 s). `assets/models/player.glb` (224.6 KB; `I.player_legacy` = 2 meshes, 20 bones, **1** animation) is orphaned but intentionally kept. `assets/models/preview_frames/frame_0001..0026.png` (~6 MB) and `attack_preview.html` are M6 review artefacts that Godot still imports on every fresh clone. `.gitignore:29-37` - the LFS block (`# *.glb`, `# *.png`, ...) is **still commented out** with ~12 MB of binaries committed, contrary to `AGENT_RULES.md` §5 ("Use Git LFS for large binary assets when they become hard to manage"). | Dead code invites incorrect assumptions (a reader will assume `set_character` works and is used). ~6 MB of orphaned PNGs inflate every clone and every import. No LFS means the repo grows by the full binary size on every asset revision - fatal once AB-004/AB-005/AB-014 require re-exports. | Delete `_handle_jump()`. Wire up `set_character()` in M7.1 (it becomes the identity path, AB-009) or delete it. Decide `Attack_Combo`: use it as the M7.3 ability animation, or export it out of the GLBs. Move `preview_frames/` and `attack_preview.html` to a non-imported location. Enable Git LFS for `*.glb` and `*.png` **before** the next asset revision. |
| **AB-022** | Low | bug | Shipped HUD copy still advertises Milestone 3 | `T.ControlsLabel.text = "ArenaBattle - Milestone 3 (Local Team Deathmatch) | Move: W / A / S / D     Run: hold Shift     Jump: Space     Attack: Left Mouse | Look: Mouse     Release / re-capture cursor: Esc | First team to 5 kills wins - or the higher score when the 3:00 timer ends. | Die and you respawn at your team spawn point after 3 s."` and **`T.controls_label_mentions_milestone3 = true`**, read live from `scenes/ui/HUD.tscn`. `network_session.gd:84` overwrites it for multiplayer clients (with mojibake, AB-011), but single-player `Main.tscn` shows the M3 card. No test asserts HUD copy. Also `T.HealthLabel.visible = false` and `T.FacingLabel.visible = false` at instantiation - they are only revealed by `bind_health()` / `_update_facing_label()`. | The shipped product tells the player it is a Milestone 3 build. Internal milestone vocabulary leaking into player-facing UI also means every milestone forces a UI edit. | Remove milestone labels from player-facing copy. Move all UI strings into one place (a `ui_copy.gd` const table or a `.tres`) so copy changes do not touch scenes, and add a copy-currency check to the test suite. |
| **AB-023** | Low | bug | `player_model_preview.gd` doc/code drift plus a third shared-resource mutation | `scripts/characters/player_model_preview.gd` declares `const ANIM_NAME := "Idle"` while its docstring states it "Loops the **Attack** animation". It also sets `loop_mode` on the imported shared `Animation` - the same anti-pattern as AB-003b, in a third location. `PlayerModelPreview.tscn` and `WardenModelPreview.tscn` reference the GLBs by uid (`5uteb3awcjrq` / `bjouoksbyqluy`). | The preview tool - the thing an asset engineer uses to validate a drop - misdescribes what it does, and it silently mutates global animation state that the game also depends on. | Correct the docstring, and delete the mutation once loop modes move to import settings (AB-003b). |
| **AB-024** | Low | risk | The art pipeline is not reproducible from a clone | `tools/export_characters.py` hardcodes absolute paths **outside the repository**: `C:\Users\ameer.noorfizan\Documents\Codex\2026-10-16\li\outputs\Arclight_Character_Review.blend` and `...\Ashen_Warden_Review.blend`, plus `OUT_DIR`. The `.blend` sources are neither committed nor in LFS (AB-021). Export params: GLB, `use_selection`, `export_yup=True`, `export_skins=True`, `export_animations=True`, `export_animation_mode="ACTIONS"` with `TypeError` fallbacks; it strips the `Warden_` action prefix for the second job, purges orphans and deletes non-kept rigs. | Nobody - including a future agent or a new artist - can re-export, re-time or re-pose a character. **AB-004 (join meshes), AB-005 option A (re-time clips) and AB-014 (pull the sword in) all require Blender-side fixes that are currently impossible to make reproducibly.** This is the single biggest schedule risk on the asset side. | Commit the `.blend` sources under `assets/src/` with Git LFS, parameterise the script's paths via argv, and record the Blender version in the conventions doc (the bundled Python used for the MP runners is Blender **5.2**, at `C:\Program Files\Blender Foundation\Blender 5.2\5.2\python\bin\python.exe`). |
| **AB-025** | Low | risk | Single-player opponents are still grey placeholder boxes | `A.opponent1_has_CharacterAnimation = false`, `A.opponent1_mesh_type = BoxMesh`. `scenes/targets/DummyTarget.tscn` uses a `BoxMesh 1x2x1` grey material. `Main.tscn` instances `Opponent1` and `Opponent2` from it. `scripts/targets/dummy_target.gd` uses **non-`@export`** constants (`BASE_ALBEDO`, `FLASH_ALBEDO`, `FLASH_DURATION := 0.15`) contrary to FOUNDATION §5 "no unexplained magic numbers", and `print()`s health on every hit. | The owner-accepted single-player build (M3) and the M7 art pass are visually inconsistent: anyone pressing F5 sees two grey boxes fighting an animated armoured knight. It also means the local build cannot be used to judge M7's look-dev - which is probably why the M6/M7 manual gates are still unrecorded. | Preferred: give `DummyTarget` the same `Mesh` anchor + `character_model.gd` treatment so it reuses the AB-002 fix and can wear either character. Alternative: explicitly scope single-player visuals out of M7 in the roadmap and say so. Also promote the `dummy_target.gd` constants to `@export` and remove the debug `print`. |
| **AB-026** | Low | risk | The animation driver keeps running on dead, hidden bodies | `combatant.gd` disables the body and hides `Mesh` on death but nothing notifies `CharacterAnimation`. Proof: `D.body_physics_processing_when_dead = false`, `D.mesh_visible_when_dead = false`, but **`D.canim_physics_processing_when_dead = true`** and **`D.anim_still_playing_when_dead = true`**. | Wasted CPU on every corpse (8 bodies x 60 Hz in a full match, and on the server too - compounding AB-015). It also forecloses death-presentation work: a corpse that keeps idling cannot later play a death animation without fixing this first. | `CharacterAnimation` should connect to `Combatant.combatant_died` / `combatant_respawned` and `set_physics_processing(false)` plus `_anim.stop()` on death, restoring on respawn. Add a test. |
| **AB-027** | Low | risk | The replica airborne heuristic has a 60 ms blind spot at jump apex | `character_animation.gd:88-95`: for `external_control` bodies, grounded is inferred as `absf(velocity.y) < airborne_velocity_threshold` (default `0.6`, `:22`). Measured: `AE.gravity_3d_project_setting = 20.0`, **`AE.airborne_heuristic_blind_spot_s = 0.06`**, `AE.jump_apex_height_m = 1.6`, `AE.jump_airtime_s = 0.8`. | For ~60 ms at the top of every remote jump the replica is judged grounded and plays Idle/Walk/Run **in mid-air**. Cosmetic, but at 0.8 s total airtime it reads as a visible hitch, and it will get worse if gravity or jump velocity is retuned. | Replicate a `grounded` bool in the snapshot wire record - the server knows it exactly via `is_on_floor()`, so the heuristic disappears. Cheaper alternative: latch airborne until `velocity.y` crosses zero *and* the following snapshot still reports near-zero vertical velocity. |
| **AB-028** | Low | risk | Snapshot fan-out is O(n^2) with no interest management or delta compression | `network_session.gd:317-330` builds the full 8-record roster array once, then sends **all records to each connected peer** every 50 ms (`snapshot_hz = 20.0`), each record carrying two `Vector3`s, two floats and four ints/bools. `:328` correctly filters on `ENetPacketPeer.STATE_CONNECTED`. | Acceptable at 8 players on a LAN. But `M5_MATCH_FOUNDATION.md:19-22` records that the earlier dictionary form already triggered Godot's "oversized unreliable packet" warning with eight players, so the format is near its ceiling. Cost scales quadratically, which blocks any M8 increase in roster size, tick rate or per-record content (e.g. the `character_id` and `grounded` fields proposed above). | Accept for M7.1, but record a measured bytes/second budget as an explicit M8 entry criterion, and consider per-peer interest (only nearby players) or delta-against-last-ack before raising `snapshot_hz`. |
| **AB-029** | Low | risk | The engine binary lives outside the repository and every tool hardcodes a relative guess at it | Real, verified path: `C:\Users\ameer.noorfizan\Documents\BE Development\SourceCode\Qoder_Personal\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe` (`--version` -> `4.7.2.stable.official.ed1daf0bf`). `tools/start_multiplayer.ps1:2` assumes `Join-Path $PSScriptRoot '..\..\..\Godot_v4.7.2-stable_win64.exe\...'`, which happens to resolve correctly. `tests/run_multiplayer_smoke.py` and `run_eight_player_smoke.py` require `--godot` to be passed explicitly. **The path supplied in the brief for this assessment (`...\game_test\Godot_v4.7.2-stable_win64.exe\...`) does not exist** - `Test-Path` returned `False`; the real location is one directory higher. Separately, a real `python` is **not** installed (Microsoft Store stub only); the MP runners were executed with Blender's bundled Python 3.13.13. Neither fact is recorded in `docs/`. | QA is not reproducible for anyone else, and an agent following the recorded path fails immediately with `CommandNotFoundException`. This is precisely the kind of undocumented environment assumption that `AGENT_RULES.md` §7 ("If a check cannot be run, say so") exists to prevent. | Add a short "Toolchain locations" section to `AGENT_RULES.md` (or a `tools/env.ps1` that resolves and validates the engine path once), documenting the console-vs-GUI binary distinction, the Windows stdout-swallowing workaround, and the Blender-Python substitution for the MP runners. |

### C.2 Suspected but NOT confirmed (need a decision or a further run before acting)

| ID | Sev | Cat | Suspicion | What is known | How to settle it |
|---|---|---|---|---|---|
| **SU-01** | Medium | risk | Real-LAN/WAN playability | Every multiplayer check runs on loopback at 6-8 ms RTT (`rtt_ms` in the JSON reports). `simulated_input_delay_ms` exists and the two-peer runner passes `--input-delay-ms=100` to `client_b`, but **nothing asserts smoothness** - only that outcomes are still correct. | Owner manual playtest with `-Players 8` and `--input-delay-ms=100..200`, plus a physical two-PC LAN run (`--bind` / `--connect`), both of which `M5_MATCH_FOUNDATION.md:53-54` already lists as pending. Record FPS and subjective smoothness. |
| **SU-02** | Medium | risk | Frame rate on real hardware | AB-004 quantifies the node/draw-call/vertex counts, but no FPS was measured - all runs were `--headless`, which does no rendering. | One windowed run with the Forward+ renderer and `Performance.get_monitor(Performance.MONITOR_FPS)` / `RENDER_TOTAL_DRAW_CALLS_IN_FRAME` logged over a full 8-player match. This is the single highest-value measurement not yet taken. |
| **SU-03** | Low | risk | Per-peer abuse escalation | `network_session.gd:38-39` `rejected_inputs` / `rate_limited_inputs` are **global** counters. No per-peer tally, no threshold, no kick. `_ping` (`:409-413`) has no rate limit and is a 1:1 packet amplifier. | Threat-model review with C7 at M8. For now, add per-peer counters and a disconnect-on-threshold policy. Not urgent: `input_rate_limit = 90` / `input_burst_limit = 120` already bound the damage a single peer can do. |
| **SU-04** | Low | risk | `_locate_animation_player()` race during the swap frame | `character_animation.gd:52` takes `find_children(...)[0]`. During a swap both the old (pending `queue_free`) and new `AnimationPlayer` exist in the same frame (`F.children_immediately_after_swap = ["Model","@Node3D@5"]`), so `[0]` could bind to the doomed one. | Add a case to the presentation test that swaps and immediately checks `_anim.get_path()` is under `Mesh/Model`. Cheap to prove once AB-002 is fixed. |
| **SU-05** | Low | risk | `_subresources` stability across re-export | Loop-mode keys in `.import` `_subresources` reference generated names such as `Animation_g6ux4` (`Q.idle_animation_resource_path`). A re-export from Blender may regenerate those hashes. | After applying the AB-003b fix, re-export once and diff the `.import` files. Mitigation already specified: the test must assert by AnimationPlayer **clip name**, not resource path, so a hash change fails loudly. |
| **SU-06** | Low | tech-debt | `send_controls` sequence gap under queue saturation | `network_session.gd:251` increments `_sequence` **before** the `:253-254` `_delayed_inputs.size() >= 120` early-return, so the sequence advances with nothing queued. Harmless (the server accepts any `sequence > record.seq` up to `+1024`) but it makes sequence numbers non-contiguous, which complicates any future packet-loss metric. | Cosmetic; fold into the AB-019 channel change if that goes ahead. |

### C.3 Refuted hypotheses - checked and cleared (recorded so nobody re-investigates)

Being explicit about what I *disproved* matters as much as what I found; three of these were
plausible Critical findings that the evidence killed.

| ID | Hypothesis I tested | Verdict and evidence |
|---|---|---|
| **RC-01** | Godot propagates `_ready()` in **reverse** tree order, so `PlayerFeedback._ready()` (`player_feedback.gd:30-31`) would run *before* `character_model._ready()` instantiated `Model`, capturing **zero** skinned meshes and permanently breaking the hurt flash. | **REFUTED.** `A.mesh_children = ["Model"]`, `A.skin_meshes_under_Mesh = 135`, **`A.feedback_captured_skin_meshes = 135`**; `B.skin_meshes_tinted_after_damage = 135`, `B.anchor_material_override_set = true`, `B.skin_meshes_tinted_after_expiry = 0`. Godot propagates `_ready()` in **forward** tree order. The network path is also correct: `G.skin_meshes_under_Mesh = 215`, `G.feedback_captured_skin_meshes = 215`, `G.hurt_tinted_count = 215` - because `_add_team_marker` (`network_session.gd:210`) runs before `$Players.add_child` (`:221`), so `TeamMarker` is captured too and `_restore_override` correctly puts its team material back. **The hurt flash works in both single-player and multiplayer.** |
| **RC-02** | The third positional `3` in `_peer.create_server(port, required_players, 3)` / `create_client(server_address, port, 3)` is `inbound_bandwidth`, i.e. a **3 bytes/second throttle** - which would have been Critical. | **REFUTED.** Reflected on this exact engine: `J.create_server = create_server(port:int, max_clients:int, max_channels:int, in_bandwidth:int, out_bandwidth:int)` and `J.create_client = create_client(address:String, port:int, channel_count:int, in_bandwidth:int, out_bandwidth:int, local_port:int)`. The `3` is `max_channels` / `channel_count`, matching the three channels in use (0 snapshot, 1 registration+input, 2 ping). Corroborated by 135 passing multiplayer checks. The genuine issue is much smaller - see AB-018. |
| **RC-03** | `player_controller` reads the wrong gravity setting (`physics/2d/default_gravity` = 980.0 rather than the 3D value). | **REFUTED.** `player_controller.gd:88-90` reads `physics/3d/default_gravity` with a `9.8` fallback, and `project.godot` sets `physics/3d/default_gravity = 20.0` (`AE.gravity_3d_project_setting = 20.0`). The `980.0` I observed is Godot's unrelated 2D default and is never read. **No gravity bug.** |
| **RC-04** | The remote swipe direction is derived from the wrong yaw, so remote attack arcs point the wrong way. | **REFUTED.** `network_session.gd:356` `Vector3.BACK.rotated(Vector3.UP, mesh_yaw)` reproduces the Mesh's world +Z, matching `melee_attacker.gd:72-74` under `aim_forward_positive_z = true` (`Player.tscn:49`). `player_feedback.gd:64` `atan2(-forward.x, -forward.z)` then re-derives the same yaw for a swipe mesh built along -Z (`:46`). Existing check `swipe_aims_with_facing` (`forward.dot(visual_forward) > 0.999`) also passes. |
| **RC-05** | The exported models face the wrong way in Godot, so melee would travel backwards. | **REFUTED - and the contract is provably correct.** `I.*.extremity_bone_positions` is **identical in all three models**: `hand.L = (0.32, 0.72, 0.0)`, `hand.R = (-0.32, 0.72, 0.0)`, `foot.L = (0.13, 0.13, 0.0)`, `foot.R = (-0.13, 0.13, 0.0)` - all at z = 0 in the rest pose, left hand at +X, right at -X. That proves Blender-space facing is **-Y**; `export_yup = True` (`tools/export_characters.py`) maps (x,y,z) -> (x,z,-y), so Blender -Y becomes Godot **+Z** - exactly what `aim_forward_positive_z = true` and `player_controller.gd:132` `atan2(flat.x, flat.z)` assume. `I.*.skeleton_transform` is identity in all three, so there is no hidden compensating rotation. |
| **RC-06** | The `MODEL_OFFSET = (0,-1,0)` in `character_model.gd:22` double-offsets origin-at-feet models, sinking them into the floor. | **REFUTED.** `I.arclight.aabb_min.y = 0.006`, `I.ashen_warden.aabb_min.y = 0.0065`, `I.player_legacy.aabb_min.y = 0.0` - all origin-at-feet. `Player.tscn:28-30` gives `Mesh` **no transform**, so it sits at the body origin = capsule centre; the capsule (`height = 2.0`) spans -1..+1, so -1 is exactly the feet. The offset is correct. (The `ART_IMPORT_CONVENTIONS.md:21` claim of "no offset" is what is wrong - AB-013.) |
| **RC-07** | A runtime model swap double-connects `animation_finished`, or leaves `_anim` dangling on a freed player. | **REFUTED.** `L.anim_instance_id_initial = 57109645469` -> `L.anim_instance_id_after_swap = 61052290934`; `L.finished_connections_initial = 1` -> `L.finished_connections_after_swap = 1`; `L.anim_valid_after_swap = true`. Godot nulls the freed reference, so the rescan guard at `character_animation.gd:70-73` re-finds and re-binds cleanly with no duplicate connection. **The `_attack_playing` latch (AB-002c) is a separate, real defect** - the rebind works, the flag reset does not. |
| **RC-08** | Replicated health can be corrupted or driven by a client. | **REFUTED.** `U.replica_ignores_local_damage = 100.0` (the `network_replica` guard at `health.gd:32` holds), `U.replica_accepts_network_state = 42.0`, `U.replica_clamps_negative = 0.0`, `U.replica_clamps_above_max = 100.0`. `U.health_after_overkill = 0.0` and `U.health_after_reset = 100.0`. Only the *authoritative* path lacks the upper clamp (AB-016). |
| **RC-09** | There is a server-authority hole: a client can force damage, health, position, score, team or victory. | **REFUTED - the model is genuinely sound.** `_accept_input` (`network_session.gd:263-290`) enforces sequence monotonicity plus `MAX_SEQUENCE_ADVANCE = 1024`, `movement.is_finite()`, `movement.length_squared() <= 1.001`, `is_finite(yaw)`, `wrapf(yaw, -PI, PI)`, a token bucket (`input_rate_limit = 90`, `input_burst_limit = 120`), and phase/dead gates; `_server_step:304-308` zeroes inputs after `input_timeout_ms = 250`. `_register_player` is server-only, rejects `id <= 1` and duplicates, caps the roster, gates on phase, and sets ENet liveness via `set_timeout(2, 1000, 3000)`. Clients get `Combatant.free()` + `Health.network_replica = true` + `set_physics_process(false)` + collision disabled (`:215-225`). 20 adversarial server checks pass, including `remote_invalid_requests_rejected`, `remote_flood_rate_limited`, `invalid_input_does_not_change_outcomes`, `replica_cannot_apply_damage`, `replica_does_not_simulate`, `post_match_requests_cannot_mutate_game`. Invalid-input probes used `Vector2(100,0)`, a `NAN` yaw, `sequence = -1` and a 20x flood. **No authority defect found.** The real weaknesses are AB-019 (lossy action edges) and SU-03 (no per-peer escalation) - both M8 concerns. |
| **RC-10** | The build or the import is dirty. | **REFUTED.** `--headless --import` -> exit 0, no errors or warnings. `git status --short` empty; `main` == `origin/main` == `70dd88c`. All 238 checks green with exit 0. |

### C.4 Severity roll-up

| Severity | Count | IDs |
|---|---|---|
| Critical | **0** | - |
| High | **4** | AB-001, AB-002, AB-003, AB-004 |
| Medium | **11** | AB-005, AB-006, AB-007, AB-008, AB-009, AB-010, AB-011, AB-012, AB-013, AB-014, AB-015 |
| Low | **14** | AB-016 .. AB-029 |
| Suspected (unconfirmed) | 6 | SU-01 .. SU-06 |
| Refuted / cleared | 10 | RC-01 .. RC-10 |
| Coverage gaps | 13 | CG-01 .. CG-13 (below) |

### C.5 Coverage gaps (explicit inventory)

Each was verified by me in a read-only diagnostic; **none has a test**.

| ID | Gap | Diagnostic evidence that it currently works (or does not) |
|---|---|---|
| CG-01 | Locomotion state machine and all thresholds/edges | All correct: `C.velocity_zero = Idle`, `walk_3 = Walk`, `run_9 = Run`, **`run_edge_8 = Run`** (inclusive), **`walk_edge_0.5 = Walk`** (inclusive), `below_walk_0.4 = Idle`, `airborne_up = Jump`, `airborne_down = Jump`, **`airborne_edge_0.6 = Jump`**, `falling_while_running = Jump`, `run_anim_reachable_by_controller = true` (`run_speed 10.0 >= threshold 8.0`). |
| CG-02 | Attack-clip cycling and the `_attack_playing` lifecycle | Correct locally: `D.attack_clip_cycle = ["Attack_Slash","Attack_Backhand","Attack_Overhead","Attack_Thrust","Attack_Slash"]`, `D.attack_index = 5`, `D.locomotion_resumes_after_attacks = Idle`, `D.attack_playing_cleared = true`. **Broken across a swap** (AB-002c) and **broken in multiplayer** (AB-001). |
| CG-03 | Runtime model swap (`set_character`) | Zero call sites; three invariants broken when used (AB-002, AB-007). |
| CG-04 | Team marker (colour, position, occlusion, interaction with the hurt flash) | Mechanically correct (`G.hurt_tinted_count = 215` includes `TeamMarker`), but visually unaudited: `AE.arclight.marker_gap_above_head_m = 0.397`, `AE.ashen_warden.marker_gap_above_head_m = 0.333`, `AE.marker_gap_above_capsule_top_m = 0.15` - the orb floats ~0.33-0.40 m above the head. |
| CG-05 | Per-clip durations / canonical timing table | `AA.*.clip_lengths_s` measured for all 9 clips on both models; 8 of 9 differ between characters (AB-006). |
| CG-06 | Model world-AABB vs collider extent | `I.*.aabb_min` / `aabb_size` measured; the Warden overflows its capsule by 0.58 m forward (AB-014). |
| CG-07 | Mesh / material / triangle / vertex budget | `P.*` measured; 135 and 214 nodes against 7 and 9 materials (AB-004). |
| CG-08 | Server-side node and memory budget | `M.*` measured; 1856 nodes / 1728 meshes / 39.1 MB / 61.5 ms (AB-015). |
| CG-09 | Shared-resource independence between instances | `R.leak_confirmed = true`, `Q.other_instance_sees_mutation = 2`, `S.distinct_idle_animation_resources = 1` (AB-003). |
| CG-10 | HUD / status copy currency, and a non-ASCII / mojibake byte guard | `T.controls_label_mentions_milestone3 = true` (AB-022); 4 mojibake sequences in `network_session.gd` (AB-011). |
| CG-11 | Remote-body smoothness under latency | `--input-delay-ms=100` is exercised by the runner but nothing asserts smoothness; no interpolation exists (AB-008, SU-01). |
| CG-12 | Any frame-rate or draw-call measurement at all | Nothing in the repo reads `Performance` monitors; every run is `--headless` (SU-02). |
| CG-13 | Anything requiring a display: real rendering, camera-lock feel, swipe readability, model look-dev | Structurally impossible headless. `DEVELOPMENT_ROADMAP.md:370` "Manual F5 look-dev (facing/feel) pending" and `M5_MATCH_FOUNDATION.md:53-54` "Human visual acceptance ... remain pending" - **neither manual gate has ever been recorded for M6 or M7.** |

---

## D. REVAMPED CURRENT-MILESTONE PLAN (PROPOSAL - not approved)

### D.0 Proposal in one paragraph

Split the unfinished M7 into three gated milestones and insert a hardening milestone first.
**M7.1 "Character Presentation Integrity and Performance Budget"** (this proposal, fully specified
below) fixes what M7 actually shipped, isolates shared resources, establishes measurable budgets,
reconciles `docs/`, and builds the test coverage that should have gated M7. **M7.2 "Authoritative
Character Identity and Selection"** then adds the server-assigned character id, the select flow and
the HUD. **M7.3 "Abilities, Audio, Effects and Arena Art"** delivers the remaining original M7 scope
on a foundation that can carry it. M8 stays gated behind all three.

Rationale for hardening first rather than pushing on to abilities: AB-003 (shared-resource
mutation) and AB-020 (no Resource types, one `class_name`) both make per-character data impossible
today; AB-002 makes the selection API unusable; AB-001 means nobody can see an attack in
multiplayer; and AB-004 means we have no idea whether the game runs. Building abilities on top of
that would produce work we would have to throw away.

### D.1 M7.1 scope

**In scope**

1. **Phase 0 - Governance reconciliation (docs only, no code).** AB-012, AB-013, AB-022 (copy
   location only), AB-029, plus closing DECISIONS.md open questions and correcting
   `TECHNICAL_ARCHITECTURE.md` §10.
2. **Phase 1 - Shared-resource isolation.** AB-003 (a and b), AB-023.
3. **Phase 2 - Presentation contract.** AB-001, AB-002, AB-007, AB-026, SU-04.
4. **Phase 3 - Attack timing authority.** AB-005, AB-006. **Requires an owner decision (D.5).**
5. **Phase 4 - Budgets and server-side stripping.** AB-004 (measurement + budget + test only;
   the re-export itself is an asset task gated on AB-024), AB-014 (budget + test), AB-015, AB-017.
6. **Phase 5 - Hygiene.** AB-011, AB-016, AB-018, AB-021 (dead code, LFS, orphaned preview
   frames), AB-022 (copy), AB-025 (decision only).
7. **Phase 6 - Test build-out.** AB-010, CG-01 .. CG-10.

**Explicitly out of scope for M7.1** (deferred, with reasons)

- Character selection UI and per-character HUD -> M7.2 (needs AB-002/AB-007/AB-009 fixed first).
- Server-assigned, replicated `character_id` -> M7.2 (AB-009). M7.1 only makes the *current*
  mapping deterministic and documented.
- Abilities, `resources/abilities/`, `CharacterDefinition` Resource -> M7.3 (needs Phase 1 first).
- Audio, authored VFX, arena art -> M7.3 (C11/C9/C8 activation; blocked by AB-024).
- Snapshot interpolation and client prediction -> **separate milestone M7.4 or M8-prep** (AB-008).
  Rationale: it is a netcode change with its own risk profile and its own test strategy, and mixing
  it into a presentation-hardening milestone would make M7.1 unreviewable. M7.1 does fix the
  *documentation* so the contract stops lying.
- Asset re-export (joining meshes, re-timing clips, pulling the sword in) -> an **asset task** for
  C8, gated on AB-024 (committing the `.blend` sources). M7.1 delivers the budgets, the tests and
  the conventions v2 that the re-export must satisfy; it does not perform the re-export.
- Per-peer abuse escalation, reconnect, lobby -> M8.

### D.2 Contracts and interfaces (decision-complete)

These are the interfaces the Gameplay Developer (C2) implements against and QA (C3) tests. New
public surface is marked **NEW**; changed surface is marked **CHANGED**.

**1. `scripts/player/character_model.gd`**

```gdscript
signal model_changed(character: int)      ## NEW - emitted AFTER the new Model child is in the tree

@export var character: Character = Character.ARCLIGHT
@export var headless: bool = false        ## NEW - when true, never instantiate; Mesh stays an empty anchor

func set_character(value: int) -> bool    ## CHANGED - returns false and changes NOTHING on an unknown id
func get_model() -> Node3D                ## NEW - the current "Model" child, or null
func get_character() -> int               ## NEW
```

Invariants (each is a test assertion):
- The instantiated child is **always** named `Model` (`Mesh/Model` resolves at all times when a
  valid character is set). Fix: `remove_child(_model)` then `_model.free()`, or rename the old node
  to a unique throwaway name *before* `queue_free()`.
- `set_character()` validates `SCENES.has(value)` **before** freeing anything (fixes AB-007).
- `set_character()` is idempotent: calling it with the current value does not re-instantiate and
  does not emit `model_changed`.
- `model_changed` fires only after `add_child`, so subscribers can `find_children` immediately.
- `headless == true` -> no `Model` child, no error, `Mesh` still resolvable by path.

**2. `scripts/player/character_animation.gd`**

```gdscript
func play_attack() -> void                ## NEW - the single authoritative "a swing occurred" entry point
func is_attack_animating() -> bool        ## NEW - public read of _attack_playing (test seam)
func get_current_clip() -> String         ## NEW - public read for tests
```

Invariants:
- `play_attack()` is safe to call from the network snapshot path and from the local
  `AttackHitbox.attack_started` signal; both routes must produce the same clip cycle.
- On `model_changed`: rebind `_anim`, set `_attack_playing = false`, **preserve** `_attack_index`,
  and never double-connect `animation_finished` (assert connection count == 1).
- On `Combatant.combatant_died`: `set_physics_process(false)` and `_anim.stop()`.
  On `combatant_respawned`: restore (fixes AB-026).
- `_configure_loop_modes()` is **deleted** once Phase 1 moves loop modes into the `.import`
  `_subresources` (fixes AB-003b). A test asserts the imported clips already carry the right
  `loop_mode` so the deletion cannot silently regress.

**3. `scripts/player/player_feedback.gd`**

```gdscript
func show_swipe(forward: Vector3) -> void ## NEW - public rename of _on_attack_started
```

Invariants:
- Subscribes to `Mesh.model_changed` and re-captures `_skin_meshes` (fixes AB-002b).
- `_apply_override` / `_restore_override` skip entries failing `is_instance_valid()` (defence in
  depth, not the primary fix).
- The existing private `_on_attack_started` is removed; `network_session.gd` and
  `melee_attacker.gd` both call `show_swipe`.

**4. `scripts/multiplayer/network_session.gd`**

- `:357` `body.get_node("PlayerFeedback")._on_attack_started(forward)` becomes **two public calls**
  driven from one place:
  `body.get_node("PlayerFeedback").show_swipe(forward)` **and**
  `body.get_node("CharacterAnimation").play_attack()` (fixes AB-001).
- `:380` `manager._end_match(-1)` becomes a public `manager.end_match_draw()` (fixes one AB-020
  instance).
- New `const CHANNEL_COUNT := 3` with a comment mapping channel 0 = snapshot, 1 = registration +
  input, 2 = ping; `create_server(port, required_players - 1, CHANNEL_COUNT)` (fixes AB-018).
- `_spawn_player` bounds-checks the spawn group and fails closed (fixes AB-017).
- New `@export var headless_visuals: bool = false`, forced `true` when `server_mode`; propagated to
  `character_model.headless` and used to skip `CharacterAnimation`, `PlayerFeedback`,
  `CameraPivot` activation and `_add_team_marker` (fixes AB-015).
- The four mojibake strings at `:84`, `:381`, `:393`, `:403` are repaired and the file re-saved
  as UTF-8 (fixes AB-011).
- **Not changed in M7.1:** the wire record format, the viewer-relative character mapping (documented
  as a known limitation with a pointer to M7.2), and `_submit_input`'s channel (AB-019 is a
  Low-severity decision the owner may defer).

**5. `scripts/combat/melee_attacker.gd`**

- `_ready()` must not mutate a shared shape: `col.shape = (col.shape as SphereShape3D).duplicate()`
  before assigning `radius` (fixes AB-003a). Test: two Player instances with different
  `attack_range` keep independent sphere radii.
- Phase 3 (only if the owner picks Option B): new exports `attack_windup_s`, `attack_active_s`,
  `attack_recover_s`; `request_attack()` schedules the damage application after the windup instead
  of applying it at `:82-105` in the same frame. **The damage decision stays server-side and stays
  in `melee_attacker.gd`** - no client ever applies damage.

**6. `scripts/combat/health.gd`**

- `apply_damage`: `_current = clampf(_current - amount, 0.0, max_health)` (fixes AB-016).
- New `func heal(amount: float) -> void` with its own contract: clamped to `max_health`, ignored on
  a replica or when dead, emits `health_changed`. This is the seam the M7.3 heal/lifesteal ability
  will use, and it is why `health.gd:46`'s existing comment about `heal()` is finally honoured.

**7. Import settings**

- `assets/models/arclight.glb.import` and `ashen_warden.glb.import`: `_subresources` gains
  per-animation `loop_mode` - `Idle`, `Walk`, `Run` = 1 (LINEAR); `Jump`, `Attack_Slash`,
  `Attack_Backhand`, `Attack_Overhead`, `Attack_Thrust`, `Attack_Combo` = 0 (NONE).
- Evaluate (and record the decision either way) turning `meshes/create_shadow_meshes` off for
  characters, and whether `meshes/generate_lods` is earning its cost at 135/214 nodes.

**8. Repository**

- `.gitignore`: uncomment and enable the LFS block for `*.glb` and `*.png`; add `.gitattributes`
  with the corresponding `filter=lfs` rules (fixes AB-021). **Must land before the next asset
  revision**, not after.
- `assets/models/preview_frames/` and `attack_preview.html` move out of the imported tree (e.g.
  `docs/art_review/`) or are deleted (fixes AB-021).
- `assets/src/*.blend` committed under LFS and `tools/export_characters.py` parameterised via argv
  (fixes AB-024). If the owner will not commit the sources, this must be recorded as an accepted
  risk with a named owner, because AB-004/AB-005/AB-014 all depend on it.

### D.3 Files affected

| File | Change | Phases |
|---|---|---|
| `scripts/player/character_model.gd` | NEW signal/`headless`/`get_model`; synchronous free; validate-before-free; `bool` return | 2, 4 |
| `scripts/player/character_animation.gd` | NEW `play_attack`/`is_attack_animating`/`get_current_clip`; `model_changed` + death/respawn subscription; delete `_configure_loop_modes` | 1, 2 |
| `scripts/player/player_feedback.gd` | NEW `show_swipe`; re-capture on `model_changed`; validity guards | 2 |
| `scripts/multiplayer/network_session.gd` | Public presentation calls; `CHANNEL_COUNT`; `required_players - 1`; spawn bounds check; `headless_visuals`; 4 string repairs | 2, 4, 5 |
| `scripts/combat/melee_attacker.gd` | `duplicate()` the shape; optional windup/active/recover | 1, 3 |
| `scripts/combat/health.gd` | Upper clamp; NEW `heal()` | 5 |
| `scripts/characters/player_model_preview.gd` | Docstring fix; drop the loop-mode mutation | 1, 5 |
| `scripts/player/player_controller.gd` | Delete `_handle_jump()` | 5 |
| `scenes/characters/Player.tscn` | Only if Phase 3 changes `attack_*` exports | 3 |
| `scenes/ui/HUD.tscn` | De-milestone the ControlsLabel copy | 5 |
| `assets/models/*.glb.import` (x2) | `_subresources` loop modes; LOD/shadow-mesh decision | 1 |
| `.gitignore`, `.gitattributes` | Enable LFS | 5 |
| `tools/export_characters.py` | Parameterise paths | 5 |
| `tests/integration/*.gd` | See D.7 | 6 |
| `docs/*` (roadmap, DECISIONS, ART_IMPORT_CONVENTIONS v2, TECHNICAL_ARCHITECTURE §10, AGENT_RULES toolchain, AGENT_TEAM currency) | Phase 0 reconciliation | 0 |
| **New** `tests/M7_QA_REPORT.md` | Manual + automated evidence | 6 |

### D.4 Acceptance criteria

Every criterion is testable; the test that proves it is named in D.7.

**Phase 0 - governance**
- AC-01 `DEVELOPMENT_ROADMAP.md` records true status, acceptance criteria and a verification block
  for M5, M6, M7 (split into M7.1/M7.2/M7.3), M8; "Immediate Next Steps" reflects the approved plan
  and no longer references commit `459b0ec`.
- AC-02 `DECISIONS.md` contains ADR-0012 .. ADR-0018 (section E), each with Context / Decision /
  Rationale / Status, and the open-questions table has no entry contradicted by shipped code.
- AC-03 `ART_IMPORT_CONVENTIONS.md` v2 documents: the 9-clip canonical set **with a duration
  table**, origin-at-feet **plus the required `MODEL_OFFSET`**, the `Mesh` / `Mesh/Model` contract,
  the uid table, the mesh/material/triangle/extent budgets, the weapon-as-one-mesh rule, and the
  Blender version. Every statement in it is true of the committed assets, or explicitly marked as a
  target for the pending re-export.
- AC-04 `TECHNICAL_ARCHITECTURE.md` §10 no longer claims client prediction or display
  interpolation; it states the shipped replica model and points at the interpolation milestone.
- AC-05 `AGENT_RULES.md` (or `tools/env.ps1`) records the engine binary location, the
  console-vs-GUI stdout distinction, the Windows stdout workaround, and the Blender-Python
  substitution for the MP runners.

**Phase 1 - resource isolation**
- AC-06 Two independently instantiated `Player.tscn` bodies with different `attack_range` values
  have **different** `AttackHitbox/CollisionShape3D` shape resources and independent radii.
- AC-07 A freshly loaded `arclight.glb` instance that has run **no** script reports
  `Idle.loop_mode == LOOP_LINEAR`, `Walk`/`Run` likewise, and `Jump` / all `Attack_*` ==
  `LOOP_NONE`. (Today this reports `0` for `Idle` - `Q.idle_loop_mode_before`.)
- AC-08 `_configure_loop_modes()` no longer exists in `character_animation.gd`, and no script in
  `scripts/` assigns `.loop_mode` on an imported `Animation`.
- AC-09 All 238 pre-existing checks still pass, unmodified in intent.

**Phase 2 - presentation contract**
- AC-10 A client that receives a snapshot reporting a new server swing has
  `CharacterAnimation.is_attack_animating() == true` and a non-empty `get_current_clip()` within one
  snapshot, **and** `show_swipe` fired. (Today: `E.after_snapshot_swing_attack_playing = false`.)
- AC-11 `set_character(1)` on a live body leaves exactly one child of `Mesh`, named `Model`, and
  `Mesh/Model` resolves. (Today: `F.Model_node_exists_after_swap = false`.)
- AC-12 After a live `set_character()`, applying damage tints **every** currently-mounted skinned
  mesh and produces **zero** script errors. (Today: `K.skin_refs_freed = 135`,
  `K.real_tinted_after_damage = 0`, plus a `previously freed` SCRIPT ERROR.)
- AC-13 An attack started immediately before a live `set_character()` does **not** latch:
  locomotion resumes and reaches `Run` at 9 m/s within 30 physics frames. (Today:
  `L.attack_playing_still_latched = true`, `L.current_after_run_velocity = ""`.)
- AC-14 `set_character(7)` and `set_character(-1)` return `false`, leave the previous model
  mounted and intact, and produce no invisible-but-lethal body. (Today: `N.children_after_7 = []`,
  `N.body_still_physics_processing = true`.)
- AC-15 On death, `CharacterAnimation.is_physics_processing() == false` and no clip is playing; on
  respawn both are restored. (Today: `D.canim_physics_processing_when_dead = true`,
  `D.anim_still_playing_when_dead = true`.)
- AC-16 `animation_finished` has exactly one connection to `CharacterAnimation` after any number of
  swaps. (Already true - `L.finished_connections_after_swap = 1` - now asserted so it cannot
  regress.)

**Phase 3 - attack timing (only the criteria for the chosen option)**
- AC-17 *(Option B)* Damage from `request_attack()` is applied no earlier than `attack_windup_s`
  after the swing starts, on the server, and the swing is still rejected while
  `_cooldown_remaining > 0`.
- AC-18 *(Option B)* Locomotion animation resumes at the end of `windup + active`, not at the end
  of the clip, so a moving attacker does not foot-slide.
- AC-19 *(either option)* Both characters' `Attack_Slash` durations are within the tolerance
  published in the conventions v2 duration table.
- AC-20 *(either option)* `Attack_Combo` is either referenced by code and tested, or removed from
  the shipped GLBs. It must not remain unreferenced (today: 0 grep hits repo-wide).

**Phase 4 - budgets and server stripping**
- AC-21 A headless server session with 8 registered players reports at most the budgeted node,
  `MeshInstance3D` and `AnimationPlayer` counts, and `AnimationPlayer`s actively playing == 0.
  (Today: `M.total_nodes = 1856`, `M.mesh_instances = 1728`,
  `M.animation_players_actively_playing = 8`.) Proposed budget: <= 400 nodes, <= 32 mesh instances,
  0 animation players.
- AC-22 `model_import_smoke_test.gd` asserts, per model: all 9 canonical clip names; per-clip
  duration within the published table; world-AABB height <= 1.80 m; world-AABB max abs(x) and
  abs(z) <= collider radius (0.5 m) + published tolerance; mesh-instance count <= budget; distinct
  material count <= budget; triangle count <= budget.
- AC-23 The budget numbers in AC-21/AC-22 are recorded in `ART_IMPORT_CONVENTIONS.md` v2 and in an
  ADR, with the current (failing) measurements recorded as known debt plus a dated re-export task -
  **not** silently relaxed to match the assets.
- AC-24 `_spawn_player` with a deliberately under-populated `spawn_team_N` group rejects the
  registration and produces no script error.

**Phase 5 - hygiene**
- AC-25 A repo-wide byte scan reports **zero** mojibake sequences (`C3 A2`, `C3 AF`, `C2 BB`) in any
  tracked text file. (Today: 4 in `network_session.gd`.)
- AC-26 `Health.apply_damage(-50)` on a 100 HP body leaves health at exactly 100, and `heal(50)`
  on a 60 HP / 100 max body yields 100, never more.
- AC-27 `create_server` is called with `required_players - 1` clients and a named `CHANNEL_COUNT`
  constant; both MP suites still pass, including `ninth_peer_rejected`.
- AC-28 `grep` for `_handle_jump` returns 0 hits; `set_character` has at least one production call
  site or is deleted; `*.glb` and `*.png` are LFS-tracked; `preview_frames/` is no longer imported.
- AC-29 No player-facing UI string contains a milestone identifier.

**Phase 6 - tests**
- AC-30 The new and extended suites in D.7 all pass headless with exit 0, and the total automated
  check count rises from 238 to >= 320.
- AC-31 `player_feedback_smoke_test.gd:51` asserts on a real skinned child mesh, not on the
  invisible `Mesh` anchor.
- AC-32 A recorded manual gate exists: owner F5 look-dev **and** an 8-window
  `start_multiplayer.ps1 -Players 8` session with at least two clients on
  `--input-delay-ms=100`, with FPS and subjective smoothness written into
  `tests/M7_QA_REPORT.md`. This closes the M5/M6/M7 manual gates that are still open
  (`DEVELOPMENT_ROADMAP.md:370`, `M5_MATCH_FOUNDATION.md:53-54`).

### D.5 Tunable defaults flagged for owner review

These are decisions, not implementation details. Each has a current value, a measurement, and a
recommendation. **I am not changing any of them without approval.**

| # | Tunable | Where | Current | Measurement / issue | Recommendation |
|---|---|---|---|---|---|
| T1 | `attack_cooldown` vs authored clip length | `melee_attacker.gd:18` | `0.6` s | Clips are 1.033-1.833 s (AA). Damage lands on frame 0. | **Decision required (AB-005).** Recommend Option B: keep `0.6` as the rate limit, add `attack_windup_s` / `attack_active_s` / `attack_recover_s`. Proposed defaults: windup `0.22`, active `0.08`, recover `0.30` - i.e. damage at ~0.22 s, total 0.60 s, matching the existing cooldown exactly. |
| T2 | Attack timing consistency between characters | assets | 8 of 9 clips differ (AA) | Slash 1.033 vs 1.433; Overhead 1.433 vs 1.833; Run 0.833 vs 1.033 | Publish a canonical duration table with +/-0.05 s tolerance and re-time the assets, **or** accept per-character timing as deliberate and record it in an ADR. Recommend the table. |
| T3 | Per-character asset budget | none exists | 135 / 214 meshes, 7 / 9 materials, 37.5k / 52.7k tris (P) | 1633 mesh nodes and ~1633 draw calls in 4v4 | Recommend caps: **<= 12 mesh objects, <= 8 materials, <= 60k triangles, <= 20k vertices** per character. Current assets fail the first two by 11x and 18x - recorded as dated debt with a re-export task (AC-23). |
| T4 | Authored extent vs collider | none exists | Warden z from -0.418 to +1.080 m; capsule radius 0.5 (I) | 0.58 m of sword/cape outside the collider | Recommend max abs(x)/abs(z) <= 0.60 m at rest pose, height <= 1.80 m. Warden fails on z; Arclight passes. |
| T5 | `airborne_velocity_threshold` | `character_animation.gd:22` | `0.6` | 60 ms blind spot at apex (AE) | Recommend replacing the heuristic with a replicated `grounded` bool (AB-027). If deferred, keep `0.6` and document the artifact. |
| T6 | `snapshot_hz` | `network_session.gd:23` | `20.0` | 0.5 m per snapshot at run speed; 3 physics frames frozen (AE) | Keep `20.0` for M7.1. Revisit with the interpolation milestone: 20 Hz + 100 ms interpolation buffer is the standard, cheaper choice. Do **not** raise it before AB-028 is measured. |
| T7 | Team marker placement | `network_session.gd:237-245` | `y = 1.15`, sphere `r = 0.12`, `h = 0.24` | 0.33-0.40 m above the head; 0.15 m above the capsule top (AE) | Recommend `y = 0.98` (just above the tallest model's head, inside the capsule) or attach to the `head` bone. Flagged as a **visual** decision needing the owner's eye, not just the arithmetic. |
| T8 | `MODEL_OFFSET` | `character_model.gd:22` | `(0, -1, 0)` | Correct (RC-06) but contradicts `ART_IMPORT_CONVENTIONS.md:21` | Keep the value; fix the doc. |
| T9 | `max_clients` / channel count | `network_session.gd:96,98` | `required_players`, `3` | Off by one; magic number (AB-018, RC-02) | `required_players - 1`, and `const CHANNEL_COUNT := 3`. |
| T10 | Input rate limits | `network_session.gd:24-26` | timeout `250` ms, rate `90`/s, burst `120` | Reviewed; adversarially tested and passing | **No change recommended.** |
| T11 | `_submit_input` channel | `network_session.gd:258` | `unreliable_ordered`, ch 1 | Action edges can be silently dropped (AB-019) | Recommend moving action edges to a reliable channel. Owner may defer to M8 - it is Low severity on a LAN. |
| T12 | Server-side visuals | none exists | Full `Player.tscn` on the server | 1856 nodes / 1728 meshes / 39.1 MB / 61.5 ms (M) | Add `headless_visuals`, default `false`, forced `true` when `server_mode` (AC-21). |
| T13 | Single-player opponents | `DummyTarget.tscn` | grey `BoxMesh` | `A.opponent1_mesh_type = BoxMesh` (AB-025) | **Decision required:** give them the `Mesh` anchor + `character_model.gd` treatment (recommended, reuses the AB-002 fix), or explicitly scope single-player visuals out of M7 in the roadmap. |
| T14 | Git LFS | `.gitignore:29-37` | commented out | ~12 MB committed; re-exports pending | Enable **before** the next asset revision. |

### D.6 Sequencing, ownership and effort

| Phase | Owner | Depends on | Rough effort | Gate |
|---|---|---|---|---|
| 0 Governance reconciliation | Architect (C1) | Owner approval of this document | 0.5 day | Owner reviews the doc diffs |
| 1 Resource isolation | Gameplay (C2) | Phase 0 | 0.5 day | AC-06..AC-09 |
| 2 Presentation contract | Gameplay (C2) | Phase 1 | 1.5 days | AC-10..AC-16 |
| 3 Attack timing | Architect + Gameplay + **owner decision T1/T2** | Phase 2; assets gated on AB-024 | 1 day (Option B code) + asset task | AC-17..AC-20 |
| 4 Budgets + server stripping | Gameplay (C2) + QA (C3) | Phase 2 | 1 day | AC-21..AC-24 |
| 5 Hygiene | Gameplay (C2) | Phase 1 | 0.5 day | AC-25..AC-29 |
| 6 Test build-out | QA (C3) | Phases 1-5 | 1.5 days | AC-30..AC-32 |
| Asset re-export (join meshes, re-time, sword-in) | Asset Engineer (C8) - **must be activated** | AB-024 resolved | 1-2 days | Re-run AC-22 |
| Manual acceptance | Owner | All above | 1 session | AC-32, recorded in `tests/M7_QA_REPORT.md` |

Total code+test effort: **~6.5 days**, plus 1-2 days of asset work that is currently **blocked** by
AB-024. Per `AGENT_TEAM.md` §4, C8 (Asset Engineer) and C9 (Technical Artist) must be activated for
the re-export, and C10 (UI) / C11 (Audio) stay deferred to M7.2 / M7.3.

**Risks to this plan**

| Risk | Likelihood | Mitigation |
|---|---|---|
| The `.blend` sources cannot be recovered, so AB-004/AB-005(A)/AB-014 cannot be fixed at the source | Medium | Ask the owner to confirm the files still exist at the paths in `tools/export_characters.py`. If not, the fallback is to accept the budgets as documented debt and re-author from the GLBs (lossy). Escalate immediately - this is the plan's critical path. |
| Phase 3 Option B changes combat feel and invalidates the owner-accepted M2/M3 balance | Medium | Option B is additive and gated by exports; keep `attack_windup_s = 0` reproducing today's behaviour exactly, so the change can be tuned without a code edit. Re-run all 44 match checks. |
| Touching `_receive_snapshot` regresses the 135 MP checks | Low | The MP suites are the strongest asset in the repo; run them after every phase, not just at the end. |
| The owner's manual gate (AC-32) stays pending as it has since M5 | **High** | Make it an explicit, scheduled, single-session gate with a written template in `tests/M7_QA_REPORT.md`, and do not mark M7.1 accepted without it. Three milestones are already in this state. |

### D.7 Test plan

**New suites** (all headless, `extends SceneTree`, same `CHECK`/`ALL_TESTS_PASS`/`quit(0|1)`
convention as the existing eight):

1. `tests/integration/character_presentation_smoke_test.gd` (~40 checks) - covers CG-01, CG-02,
   CG-03, CG-04, AB-026, SU-04. Must assert: every locomotion state and every threshold **edge**
   (0.4/0.5/8.0/0.6, using the values I measured in diag C); the full 4-clip attack cycle and
   `_attack_playing` clearing; `set_character` name-contract, idempotence, out-of-range rejection
   and `model_changed` emission; `_skin_meshes` re-capture and tint count after a swap;
   `animation_finished` connection count == 1 after N swaps; death stops the driver, respawn
   restores it; team marker exists, is at the budgeted offset, is team-coloured, and is included in
   the hurt flash.
2. `tests/integration/model_budget_smoke_test.gd` (~15 checks) - covers CG-06, CG-07. World-AABB
   height and x/z extent vs the collider, mesh-instance count, distinct-material count, vertex and
   triangle counts, bone count, skeleton transform identity.
3. `tests/integration/resource_isolation_smoke_test.gd` (~12 checks) - covers CG-09. Two Player
   instances with divergent `attack_range` keep independent shapes; a fresh GLB instance reports
   import-time loop modes with **no** script having run; mutating one instance's clip does not
   affect another.
4. `tests/check_encoding.py` (or a PowerShell equivalent wired into the runners) - covers CG-10 /
   AB-011 / AC-25. Fails on any `C3 A2` / `C3 AF` / `C2 BB` byte sequence in a tracked text file.

**Extended suites**

5. `model_import_smoke_test.gd` - `REQUIRED_ANIMS` goes from 5 to all **9** clips; add the duration
   table, AABB, mesh/material/triangle budgets and the import-time `loop_mode` assertions
   (AC-07, AC-22). Replace `meshes.size() >= 2` with the real budget.
6. `player_feedback_smoke_test.gd` - fix the `:51` proxy to assert on a real skinned child
   (AC-31); add a post-swap flash case (AC-12).
7. `multiplayer_peer_test.gd` and `multiplayer_eight_peer_test.gd` - add a client-side assertion
   that a server swing produces `is_attack_animating() == true` within one snapshot (AC-10), and a
   server-side assertion on the headless node budget (AC-21). **These must be added without
   reaching into new privates** - use the public seams from D.2.
8. `combat_smoke_test.gd` - add negative-damage and `heal()` clamp cases (AC-26); add a windup
   timing case if Option B is chosen (AC-17).
9. `match_smoke_test.gd` - add an under-populated spawn-group case (AC-24).

**Debt to retire in the tests themselves** (AB-020): the three suites that currently poke privates
(`session._broadcast_snapshot()`, `session._stage()`, `AttackHitbox._cooldown_remaining`,
`hitbox._perform_attack()`, `hud._process(0.0)`, `hud._tint_remaining`) should migrate to public
debug seams during Phase 6. This is explicitly a *test* refactor, not a behaviour change.

**Regression gate:** all 238 existing checks must remain green after **every** phase, not only at
the end. Both Python runners must be executed with Blender's bundled Python
(`C:\Program Files\Blender Foundation\Blender 5.2\5.2\python\bin\python.exe`), since a real
`python` is not installed (AB-029).

**Manual gate (AC-32), template to be filed as `tests/M7_QA_REPORT.md`:**
- F5 single-player: model look-dev, facing, camera lock (V), swipe readability, hurt flash on the
  authored model (not the invisible anchor), death/respawn presentation, HUD copy correctness.
- `tools/start_multiplayer.ps1 -Players 8`: all 8 bodies visible and distinct, team markers
  readable and correctly coloured, **attack animations visible on remote players** (AB-001), no
  foot-sliding after a swing (AB-005), no sword clipping through walls (AB-014), FPS recorded.
- Two clients with `--input-delay-ms=100` and, if two machines are available, a physical LAN run
  with `--bind` / `--connect` - closing `M5_MATCH_FOUNDATION.md:53-54`.
- Explicit statement of any criterion that could **not** be checked, per `AGENT_RULES.md` §7.

### D.8 Re-planned remainder of M7 (outline only, to be specified after M7.1 is accepted)

- **M7.2 - Authoritative character identity and selection.** AB-009: server-assigned `character_id`
  in the roster record and the snapshot wire record (index 11); a character-select flow
  (`scenes/ui/CharacterSelect.tscn`, C10 activated); `resources/characters/*.tres` with a
  `CharacterDefinition extends Resource` type; per-character HUD. Acceptance: every peer agrees on
  every other peer's character; selection is validated server-side; the wire-format bump is
  version-gated.
- **M7.3 - Abilities, audio, effects and arena art.** The remaining original M7 scope: one distinct
  ability per character (`scripts/abilities/`, `resources/abilities/`, server-authoritative
  cooldowns and costs per `MULTIPLAYER_DESIGN.md:16`), audio (C11; zero assets exist today),
  authored VFX (C9; zero particle systems exist today), and improved arena art. `Attack_Combo`
  (3.033 s / 4.033 s, currently unreferenced) is the natural candidate for an ability animation -
  decide its fate in AC-20.
- **M7.4 or M8-prep - Remote-body smoothing.** AB-008: a ~100 ms interpolation buffer plus short
  extrapolation, and a decision on whether client prediction is ever coming (which is what
  `TECHNICAL_ARCHITECTURE.md` §10 still implies).
- **M8 - Online readiness.** Unchanged scope, now with explicit entry criteria: AB-004 budget met,
  AB-008 landed, AB-015 landed, AB-019 decided, AB-028 measured, SU-03 per-peer escalation,
  reconnect, lobby, auth, monitoring, deployment.

---

## E. RECOMMENDED ADRs (DRAFT TEXT ONLY - **not** written into `docs/DECISIONS.md`)

`DECISIONS.md` currently ends at ADR-0011 (M4). The seven drafts below are proposed for owner
approval. ADR-0012 and ADR-0013 are **retroactive records** of decisions already shipped in M5/M6/M7
without an ADR - a breach of `AGENT_RULES.md` §3.10 that should be closed rather than left implicit.
Numbering continues from ADR-0011.

---

### ADR-0012 (retroactive) - 4v4 match foundation on the M4 authoritative session

**Context.** M4 proved a server-authoritative two-peer session (ADR-0011). The 4v4 requirement
needed eight players, two balanced teams, distinct spawn slots and a server-determined result,
without a second networking model.

**Decision.** Extend `network_session.gd` rather than introduce `MultiplayerSpawner` /
`MultiplayerSynchronizer`. The server assigns the smaller team (A on ties) and the first free slot
0-3; no team exceeds four. A pre-start departure frees its slot; a disconnect during a running
match ends it in a draw (`winner = -1`). Wire snapshots use **positional arrays** rather than
dictionaries, after the dictionary form triggered Godot's oversized-unreliable-packet warning at
eight players. `--bind=` / `--connect=` enable explicit LAN addressing; defaults stay loopback.
Friendly damage is disabled in network play only, preserving local prototype behaviour.

**Rationale.** The M4 validation path (sequence, bounds, rate, freshness, phase, roster) already
covered everything 4v4 adds; positional arrays cut per-packet bytes without a schema library.
Keeping one session script avoids two divergent authority models.

**Consequences.** Both peers must run the same version (the array layout is a positional
contract). Snapshot fan-out is O(n^2) with no interest management (AB-028). A single disconnect
terminates the match for everyone, with no reconnect (documented limit, M8). `max_clients` was set
to `required_players` rather than `required_players - 1`, so ENet admits a ninth peer that
application code must reject (AB-018). Verified by 68 automated checks
(`multiplayer_eight_peer_test.gd`); owner visual playtest was never recorded.

**Status.** Shipped in M5 (`0ec6e9a`), retroactively recorded 2026-10-17. Automated verification
current as of `70dd88c`; manual acceptance outstanding.

---

### ADR-0013 (retroactive) - Stable `Mesh` anchor with a runtime-instantiated `Model` child; team identity by overhead marker

**Context.** Gameplay code hard-references `Player.tscn` node paths - `$Mesh`, `CameraPivot`,
`AttackHitbox`, `Combatant`, `Health`, `CollisionShape3D`, `PlayerFeedback` (recorded at
`ART_IMPORT_CONVENTIONS.md:40-43` and `M5_MATCH_FOUNDATION.md:42-44`). M6 needed to replace the
placeholder mesh with an authored GLB, and M7 with two of them, without touching any of those
contracts. Separately, the M3 team identity mechanism was a full-body colour override, which
destroys authored materials.

**Decision.** Keep `Mesh` as a permanent `MeshInstance3D` **anchor** with no mesh of its own, and
instantiate the authored character as a child named `Model` at runtime (`character_model.gd`), with
`MODEL_OFFSET = (0, -1, 0)` to seat origin-at-feet models at the base of the 2 m capsule.
Presentation systems mirror onto the anchor's descendants (`player_feedback.gd:30-31`). For M7,
replace the full-body team tint with a small unshaded overhead `SphereMesh` marker in the team
colour (`network_session.gd:233-246`), leaving authored materials untouched.

**Rationale.** Zero node-path churn across six scripts and three test suites; the anchor stays
valid for `aim_reference_path`, visibility-on-death and `material_override` regardless of which
model is mounted. The marker preserves the artist's material work, which a tint would have hidden.

**Consequences.** Presentation systems that cache descendants at `_ready()` become stale if the
model is ever swapped at runtime (AB-002b). The `Mesh/Model` name contract breaks on a swap because
`queue_free()` is deferred (AB-002a). The marker floats 0.33-0.40 m above the head and is not
tuned visually (CG-04, T7). Ordering is safe: `_add_team_marker` runs before the body enters the
tree, so `PlayerFeedback._ready()` captures the marker (RC-01). No ADR existed for either the M6 or
the M7 variant of this decision when they shipped.

**Status.** Shipped in M6 (`ba2d07d`) and M7 (`70dd88c`), retroactively recorded 2026-10-17.
Superseded in part by ADR-0014 (swap robustness) if approved.

---

### ADR-0014 - Imported and shared `Resource` objects are read-only at runtime

**Context.** Two independent runtime paths write per-instance configuration into `Resource` objects
that are shared across every instance in the process: `melee_attacker.gd:39-45` resizes the shared
`SphereShape3D` sub-resource of `Player.tscn`, and `character_animation.gd:60-66` (plus
`player_model_preview.gd`) sets `loop_mode` on the imported `Animation` inside the GLB. Both were
proven: `R.leak_confirmed = true` (changing one instance's `attack_range` to 3.0 changed every
other instance's collision sphere), `Q.idle_animation_same_resource = true`,
`Q.idle_local_to_scene = false`, `Q.other_instance_sees_mutation = 2`, and
`S.distinct_idle_animation_resources = 1` across 8 bodies. `resource_local_to_scene` appears
nowhere in the repository. Critically, `Q.idle_loop_mode_before = 0` and `_subresources = {}` show
the imported clips do **not** loop, so the animation mutation is currently load-bearing.

**Decision.** No gameplay or presentation script may mutate a `Resource` it did not create.
Specifically: (1) animation `loop_mode` is configured **at import time** via `_subresources` in the
`.glb.import` files, and `_configure_loop_modes()` is deleted; (2) any component that must resize
or otherwise modify a scene sub-resource calls `duplicate()` first; (3) where a genuinely
per-instance resource is required, `resource_local_to_scene = true` is set deliberately and
recorded.

**Rationale.** Shared-resource mutation is invisible global state: it leaks between instances, into
the editor, into preview scenes, and across test cases. It also directly blocks per-character stats
and abilities - the M7 requirement - because the last `_ready()` to run wins for everyone. Moving
loop modes to import time makes the asset self-describing, removes redundant work (8 bodies
mutating 1 resource), and lets the mutation code be deleted rather than merely guarded.

**Consequences.** Requires editing both `.glb.import` files and re-running the importer.
`_subresources` keys on generated names such as `Animation_g6ux4`
(`Q.idle_animation_resource_path`), which can change on a Blender re-export, so the accompanying
test must assert by AnimationPlayer **clip name**, not resource path, and a re-export must be
verified by diffing the `.import` files (SU-05). `duplicate()`-ing collision shapes adds a small
per-instance allocation; at 8 players this is negligible.

**Status.** PROPOSED 2026-10-17. Owner approval required. Implements AB-003, AC-06..AC-09.

---

### ADR-0015 - Character identity is server-assigned and replicated, never viewer-relative

**Context.** `network_session.gd:209` sets `mesh.character = 0 if id == _local_peer_id else 1`, so
each viewer decides for itself what every other player looks like. The snapshot wire record
(`:323-325`) carries no character id. On the server `_local_peer_id == 0`, so all eight bodies
become Ashen Warden. Peer A sees itself as Arclight and B as Warden; B sees the reverse; the server
sees eight Wardens.

**Decision.** The server assigns a `character_id` at registration, stores it in the roster record,
and includes it in the snapshot wire record. Clients apply it through `set_character()` and never
derive it from `_local_peer_id`. The mapping policy (fixed per team, round-robin, or player-chosen
via the M7.2 select flow) is a server-side rule and is configurable, not hardcoded.

**Rationale.** `MULTIPLAYER_DESIGN.md:12-18` already states that the server - never a client -
decides team assignment; character identity is the same class of fact and belongs on the same
authority. Viewer-relative identity makes per-character abilities, per-character balance, spectator
mode, replay and bug reproduction impossible: a report about "the Arclight player" has no referent.
It is also the precondition for M7's character-select requirement.

**Consequences.** A wire-format change (append at index 11), acceptable under the existing rule
that both peers run the same version (`M5_MATCH_FOUNDATION.md:21-22`). Requires `set_character()`
to be correct first (AB-002, AB-007) - which is why this lands in M7.2, after M7.1. Existing MP
tests must be extended to assert that all peers agree on every peer's `character_id`.

**Status.** PROPOSED 2026-10-17, scheduled for M7.2. Owner approval required. Implements AB-009.

---

### ADR-0016 - Attack resolution is authoritative and animation-gated (windup / active / recover)

**Context.** `melee_attacker.gd:78` emits `attack_started` and `:82-105` applies damage in the same
physics frame, while the authored attack clips run 1.033-1.833 s and `attack_cooldown` is 0.6 s
(AA). Damage therefore lands roughly 1-1.8 s before the visual contact frame. The clips contain
only POSITION_3D and ROTATION_3D bone tracks (`AA.*.attack_slash_track_types = {"1":1,"2":16}`) -
no METHOD or VALUE track exists that could gate a hit window. Meanwhile
`character_animation.gd:74-75` freezes locomotion for the whole clip, so a moving attacker
foot-slides for up to 1.83 s.

**Decision.** *Pending the owner's choice between two options.*
**Option A (asset):** re-time all attack clips to <= `attack_cooldown` and leave the code unchanged.
**Option B (code, recommended):** keep `attack_cooldown` as the *rate limit* and add three exported
phases - `attack_windup_s`, `attack_active_s`, `attack_recover_s`. The server applies damage only
once the windup has elapsed, `attack_started` still fires at swing start for presentation, and
`_attack_playing` suppresses locomotion only during windup + active. Proposed defaults:
`0.22 / 0.08 / 0.30`, summing to exactly the existing 0.6 s so today's balance is preserved with
`windup = 0` reproducing current behaviour bit-for-bit.

**Rationale.** Option A cannot be executed reproducibly today (AB-024: the `.blend` sources are not
in the repository) and would leave the design unable to express a slow heavy attack versus a fast
light one - which per-character abilities will need. Option B keeps the authoritative decision on
the server (no client ever applies damage), makes the animation a *readable* tell, preserves the
accepted M2/M3 balance by construction, and is tunable from the Inspector without a code change,
per FOUNDATION §5.

**Consequences.** Adds latency between input and damage (windup), which must be accounted for in
the input-budget reasoning and tested. Requires new cases in `combat_smoke_test.gd` and a re-run of
all 44 match checks. A per-character timing table (T2) becomes necessary, since the two characters'
clips currently differ in duration for 8 of 9 clips (AB-006). `Attack_Combo` (3.033 s / 4.033 s,
unreferenced repo-wide) must be assigned a purpose or removed (AC-20).

**Status.** PROPOSED 2026-10-17. **Blocked on owner decision T1/T2.** Implements AB-005, AB-006.

---

### ADR-0017 - Remote-body smoothing by interpolation buffer; client prediction explicitly deferred

**Context.** `_receive_snapshot` (`network_session.gd:348-350`) writes `body.position`,
`body.velocity` and `Mesh.rotation.y` directly, with no buffer, and client bodies have physics
disabled (`:223`), so there is no prediction either. At `snapshot_hz = 20.0` against a 60 Hz
physics tick (AE: 3 physics frames per snapshot) a running body moves **0.5 m per snapshot** -
0.167 m on every third rendered frame, frozen in between. `TECHNICAL_ARCHITECTURE.md:786,799,811`
nonetheless states that "clients interpolate display" and that `player_controller.gd` does "local
prediction", which ADR-0011 already contradicted. Loopback RTT of 6-8 ms means no automated test
can observe this.

**Decision.** Introduce a render-side interpolation buffer for remote bodies: hold ~100 ms (two
snapshots) of history and lerp position and both yaws on the render frame, with short
dead-reckoning extrapolation from the last velocity when a snapshot is late. The local body stays
authoritative-position-driven (snap-to-server) until prediction is separately decided. **And**
correct `TECHNICAL_ARCHITECTURE.md` §10 so the documented contract matches the shipped design;
client prediction is explicitly deferred to a future ADR rather than implied.

**Rationale.** Interpolation is the cheapest change with the largest perceived-quality payoff, and
it is the standard remedy at 20 Hz. It requires no authority change, no wire change and no
server-side cost. Prediction is a much larger, riskier project (reconciliation, rollback,
server-side lag compensation) and ADR-0011 already scoped it out; leaving the architecture doc
claiming it is what allowed the gap to survive three milestones.

**Consequences.** Adds ~100 ms of visual latency to remote bodies, which is a deliberate trade for
smoothness and must be stated in the design doc. Requires a test strategy that does not depend on
loopback RTT - assert the buffer's state transitions and the interpolated output at a simulated
snapshot cadence rather than over a real socket. Should be its own milestone (M7.4 / M8-prep), not
folded into M7.1. Interacts with AB-028: raising `snapshot_hz` later reduces the buffer's needed
depth.

**Status.** PROPOSED 2026-10-17, scheduled after M7.1. Owner approval required. Implements AB-008.

---

### ADR-0018 - Character asset budget and Git LFS adoption

**Context.** Measured: Arclight is 135 `MeshInstance3D` nodes / 135 distinct mesh resources /
**7 distinct materials** / 46,878 vertices / 37,530 triangles; Ashen Warden is 214 / 214 / **9** /
63,304 / 52,694 (P). Import has `meshes/generate_lods = true` and
`meshes/create_shadow_meshes = true`. A 4v4 client therefore instantiates **1633 skinned mesh nodes
and ~1633 draw calls where 16 would suffice**. The Warden's rest-pose geometry also extends to
z = +1.080 m inside a 0.5 m-radius capsule (I). Meanwhile `.gitignore:29-37` still has the LFS
block commented out with ~12 MB of binaries committed, and the `.blend` sources are outside the
repository entirely (`tools/export_characters.py` hardcodes absolute user-profile paths).

**Decision.** Adopt a per-character budget, enforced by `model_budget_smoke_test.gd` and published
in `ART_IMPORT_CONVENTIONS.md` v2: **<= 12 mesh objects, <= 8 materials, <= 60,000 triangles,
<= 20,000 vertices, rest-pose world-AABB max abs(x)/abs(z) <= 0.60 m, height <= 1.80 m, all 9
canonical clips present and within the published duration table.** Enable Git LFS for `*.glb`,
`*.png` and `*.blend` **before** the next asset revision, commit the `.blend` sources under
`assets/src/`, and parameterise `tools/export_characters.py` by argv. Evaluate disabling
`create_shadow_meshes` for characters.

**Rationale.** The material counts (7 and 9) prove the fragmentation is unnecessary - roughly 19
and 24 separate meshes exist per material, which Blender could have joined. The project has no
performance test of any kind, so a budget asserted in CI is the only mechanism that prevents the
next asset drop from repeating this. LFS before the re-export, not after, because the re-export is
already required by three separate findings and would otherwise add another full binary revision to
history. Committing the sources is what makes AB-004, AB-005(A) and AB-014 fixable at all.

**Consequences.** **The current assets fail the mesh-object cap by 11x and 18x.** Per AC-23 the
budget is recorded with the failing measurements as dated, owned debt plus a re-export task - it is
**not** silently relaxed to match what shipped. Requires activating C8 (Asset Engineer) per
`AGENT_TEAM.md` §4, and requires the owner to confirm the `.blend` sources still exist (this is the
critical-path risk in D.6). LFS adoption changes clone behaviour for everyone and needs the owner's
explicit approval.

**Status.** PROPOSED 2026-10-17. **Blocked on owner confirmation that the `.blend` sources are
recoverable.** Implements AB-004, AB-014, AB-021, AB-024.

---

## APPENDIX 1 - Verification log (everything below was actually executed)

Engine: `Godot_v4.7.2-stable_win64_console.exe` -> `4.7.2.stable.official.ed1daf0bf`.
Repository: `main` @ `70dd88c`, `origin/main` in sync, `git status --short` empty before and after.
All Godot output was redirected to files and read back, because this shell swallows stdout.

| # | Command | Result |
|---|---|---|
| 1 | `--version` | `4.7.2.stable.official.ed1daf0bf`, exit 0 |
| 2 | `--headless --path <repo> --import` | **IMPORT_EXIT=0**, no errors, no warnings |
| 3 | `--headless --script res://tests/integration/movement_smoke_test.gd` | checks=3, false=0, errors=0, `ALL_TESTS_PASS=true`, EXIT=0 |
| 4 | `.../combat_smoke_test.gd` | checks=9, false=0, errors=0, `ALL_TESTS_PASS=true`, EXIT=0 |
| 5 | `.../match_smoke_test.gd` | checks=44, false=0, errors/warns=**2** (the deliberate null-source `push_warning` from `combatant.gd:94`), `ALL_TESTS_PASS=true`, EXIT=0 |
| 6 | `.../facing_mode_smoke_test.gd` | checks=8, false=0, errors=0, `ALL_TESTS_PASS=true`, EXIT=0 |
| 7 | `.../player_feedback_smoke_test.gd` | checks=15, false=0, errors=0, `ALL_TESTS_PASS=true`, EXIT=0 |
| 8 | `.../model_import_smoke_test.gd` | checks=24, false=0, errors=0, `ALL_TESTS_PASS=true`, EXIT=0 |
| 9 | Blender Python 3.13.13 `tests/run_multiplayer_smoke.py --godot <exe>` | **`ALL_MULTIPLAYER_TESTS_PASS=true` checks=67 EXIT=0.** gameplay: server 20 / client_a 8 / client_b 8 (RTT 7 and 6 ms); disconnect 4/6/5; timeout 4/5/5 (draw); unavailable client_a 2 |
| 10 | Blender Python `tests/run_eight_player_smoke.py --godot <exe> --project <repo>` | **`ALL_EIGHT_PLAYER_TESTS_PASS=true` checks=68 EXIT=0.** server 18, client_0..client_7 6 each (48), extra 2 |
| 11 | Read-only diagnostic #1, cases A-I (`.godot/qa_out/diag_m7.gd`) | 178 lines, EXIT=0. Local wiring, damage flash, locomotion state machine, attack cycling, replica attack animation, runtime swap, team-marker ordering, animation-resource leak, model metrics |
| 12 | Read-only diagnostic #2, cases J-AE (`.godot/qa_out/diag2_m7.gd`) | 235 lines, EXIT=0. ENet signatures, shared animation resources, clip lengths, stale skin refs, attack latch, out-of-range character, draw-call profile, 8-body server cost, snapshot cadence maths |
| 13 | Read-only diagnostic #3, cases R-U (`.godot/qa_out/diag3_m7.gd`) | EXIT=0. Shared collision sub-resources, redundant loop-mode writes, shipped HUD copy, Health clamping |
| 14 | Byte-level encoding scan of `.gd`/`.tscn`/`.md` files | `network_session.gd`: 17546 bytes, 1 real UTF-8 em dash (`E2 80 94`), **4 mojibake sequences** (`C3 A2 E2`). `combatant.gd` 7/0, `player_controller.gd` 9/0, `HUD.tscn` 2/0, `DECISIONS.md` 25/0 |
| 15 | `git log --oneline -15`, `git status --short`, `git branch -vv`, `git log -S "Team multiplayer"` | HEAD `70dd88c` == `origin/main`; clean tree; stale `feature/m6-art` at `222c7c3` (already merged via `6d2c295`); the mojibake was introduced by `459b0ec` |

**Total automated checks executed: 103 local + 67 two-peer + 68 eight-player = 238, all passing.**

### Environment discrepancies found while verifying (not repository defects)

- The Godot path supplied in the assessment brief
  (`...\game_test\Godot_v4.7.2-stable_win64.exe\...`) **does not exist**. The real location is one
  directory higher, at `...\Qoder_Personal\Godot_v4.7.2-stable_win64.exe\...`, which is what
  `tools/start_multiplayer.ps1:2` resolves to via `..\..\..`. See AB-029.
- A real `python` is **not** installed (Microsoft Store stub only). Both MP runners were executed
  with Blender's bundled Python at
  `C:\Program Files\Blender Foundation\Blender 5.2\5.2\python\bin\python.exe` (3.13.13).
- This shell frequently swallows native stdout and mangles multi-line commands; all Godot runs were
  redirected to files and read back, and one earlier attempt hung the shell because a command
  embedded a literal mojibake character (resolved by switching to a byte-level scan).

### Artefacts created during this assessment

**Everything except the one file named below is inside the git-ignored `.godot/` engine cache.**
No tracked script, scene, test or existing document was modified. Nothing was committed or pushed.

- `docs/PROGRESS_ASSESSMENT_M7.md` - **this file. The only tracked addition.**
- `.godot/qa_out/` (untracked, git-ignored): `diag_m7.gd`, `diag_out.txt`, `diag2_m7.gd`,
  `diag2_out.txt`, `diag2_slim.txt`, `diag3_m7.gd`, `diag3_out.txt`, `diag3_slim.txt`,
  `run_diag2.ps1`, `patch_diag2.ps1`, `version.txt`, `import.txt`, and one capture file per test
  suite and per MP runner.

All three diagnostics are `extends SceneTree` scripts that **read** state and `print` facts. They
assert nothing and change no tracked file. Diagnostic #3 does mutate two shared resources
deliberately, in order to prove AB-003 - it restores both to their original values in the same
function (`R.attack_radius_a_restored = 2.0`, `Q.idle_loop_mode_restored = 1`), and the mutations
are process-local because Godot does not write back to imported assets at runtime.

---

*End of assessment. Sections D and E were approved by the owner on 2026-10-17. Combat timing = Option B (ADR-0016); .blend sources confirmed present (ADR-0018).*
