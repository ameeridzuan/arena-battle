# Character animation and cosmetic plan

> Hands-on test update: F5 Main now supports local R casting in V aim view, Q directional dodge travel and Tab character switching. See PLAYABLE_MOTION_TEST.md. These are isolated motion-test controls; multiplayer mechanics and visual acceptance remain pending.

> 2026-10-20 A4 preview update: one reusable magic-cast sequence and four directional dodge blockouts are available for both rigs. See CAST_DODGE_CHECKPOINT.md. Ranged/dodge gameplay, persistent aim stance and visual acceptance remain pending.

> 2026-10-20 layered-action update: locomotion and upper-body melee now have independent clocks in one AnimationTree. Shared attack clips can overlay idle, walking, running and directional steps. See LAYERED_ANIMATION_CHECKPOINT.md for the graph, future movement policy and verification status.

> 2026-10-20 checkpoint: backward/sideways walking is integrated for both rigs; start/stop, left/right turn and block captures are gallery previews. Local aim side/back fast steps use a 1.8 m/s target. See OTHER_ANIMATION_CHECKPOINT.md for scope, tests and pending integration.

> Latest implementation: walk/run now use retargeted CMU human capture on both rigs, with owner-approved1.2/3.8m/s defaults, speed-calibrated cadence and phase-preserving transitions. Jump and sideways capture previews are available. See HUMAN_MOTION_CHECKPOINT.md and HUMAN_MOTION_RESEARCH.md; full animation/physics scope remains open.

> Latest animation batch: eight review-only fall/landing/hit/knockback blockouts per rig are available in AnimationReviewGallery. See REACTION_ANIMATION_CHECKPOINT.md. Final motion polish, runtime triggers and authoritative knockback remain pending.

> 2026-10-19 implementation update: A0/A1 first batch adds the two-character review gallery, 0.15 s locomotion blending, speed-threshold hysteresis and per-player animation resource isolation. See ANIMATION_FOUNDATION_CHECKPOINT.md for validation and remaining work. Full A1 polish and knockback/new-action clips remain open.

Date: 2026-10-19. Status: planning deliverable; animation assets and gameplay below are
not implemented by this planning task. Applies to Arclight and Ashen Warden.

## Direction and scope

**Owner-selected ranged style: magic / energy projectiles.** Use casting rather than
gun handling. Final spell identities and balance are still open.

Owner priority: improve rough animation first, cover the full movement/action set,
and prepare animation for skills, ranged attacks in the toggled lock/aim view,
parry, dash, block and knockback when attacked. “Perry” is interpreted as parry.

Start with silhouette, pose, weight, foot placement, timing and transitions. Add
trails, particles, camera shake and audio after actions read clearly without them.
Keep the existing stylized characters, but give each its own posture and weight.
The same action contract must work for both rigs; do not assume their bone layouts
or authored clip lengths match. Share semantics, not unverified bone masks.

This is an animation-first track within M7.1 with preparation for M7.3. Animators
can preview future actions in an isolated gallery before their gameplay exists.
Previewing a successful parry or skill does not make that mechanic playable.

## Team and responsibilities

| Role | Responsibility | Deliverable / file ownership during implementation |
|---|---|---|
| Cosmetic Lead / Coordinator | Priorities, action specification, review and roadmap; coordinate with gameplay/network owners | This plan, team charter, clip manifest, approval records |
| Animation Direction & Asset Lead | Rig audit, poses, locomotion, action clips, weapon/hand contacts, Blender exports | Blender sources and animation exports; no direct network-code edits |
| Technical Animation & Combat Integration Lead | Blend/state graph, layer masks, model rebinding, timing adapters, aim mode and event contracts | Presentation scripts/scenes; combat/network edits only through agreed ownership |
| Animation QA & Readability Lead | Clip/transition tests, visual comparison, both-character/peer coverage, performance evidence | QA scenarios, regression fixtures and review recordings |

These four roles were activated for this planning session. They are assignments,
not permanently running background agents. Only one owner edits any shared file.
Keep existing work; use isolated branches/worktrees for simultaneous implementation.
Gameplay/network owners retain authority over damage, defense, dash movement and
skill outcomes. Audio/VFX are later responsibilities, not prerequisites for motion polish.

## Current evidence and gaps

The original driver replaced locomotion with each of four full-body attack clips.
The layered-action update removes that latch: one AnimationTree blends a continuous
locomotion base with a masked upper-body action, using the same authored attack
over multiple movement states. Explicit full-body presentation overrides remain
available through action definitions. Starts/stops, aim, guard, parry, dash,
hurt/stagger and lifecycle clips still need their planned integration and review.

Demo 1 fixed snapshot-driven attack animation, but animation resource loop modes
are still changed at runtime. Model rebinding, attack timing and performance work
remain in M7.1. Earlier passing tests do not establish visual polish.

The V toggle currently switches the **local** controller between movement-facing
free look and over-the-shoulder aim-facing movement. External-control players skip
the input path; the network controls currently carry yaw but not aim mode or pitch.
Networked lock/aim support is a prerequisite for playable multiplayer ranged attacks.
Lock view means shoulder aiming, not automatic target lock-on.

## Animation coverage matrix

Names are proposed semantic clip names, not claims that the files already exist.
Variants can share authored clips only when the on-screen result is approved.

| Family | Required coverage | Transition and polish focus |
|---|---|---|
| Neutral | Idle, CombatIdle, AimEnter, AimIdle, AimExit | Breathing/weight, casting-ready posture, stable loop seams |
| Ground movement | Walk/Run forward, accelerate/start, decelerate/stop, run-to-walk, quick reverse | Match stride to measured speed; do not skate during starts/stops |
| Direction changes | TurnInPlace L/R, moving pivots, 180-degree reversal | Feet plant before hips turn; avoid whole-body snapping |
| Aim movement | AimWalk F/B/L/R; diagonal blends; aim turn-in-place | Lower body follows movement; torso/weapon stays on aim; reverse is not a forward walk played backward |
| Sprint | SprintStart, SprintLoop, SprintStop | Proposed: relax the casting stance and suppress firing until aim-ready; server rule needed |
| Air | JumpStart, JumpRise, FallLoop, LandSoft, LandHard | Takeoff, apex, ledge fall and moving/stationary landing are distinct; hard landing is visual until rules exist |
| Melee | Slash, Backhand, Overhead, Thrust: windup/contact/recovery; whiff/recovery | Clear anticipation, weapon arc, weight transfer, recovery that returns to movement |
| Ranged in lock view | CastReadyEnter/Exit, AimHold, CastRelease, CastRecover; aim pitch up/down | Stable casting-hand/focus alignment and lower-body strafing; palm/focus release socket |
| Ranged conditional | EnergyGatherStart/Hold/Release/Cancel only if charged casting is selected | Charged casting remains optional; no reload, ammunition or gun recoil clips |
| Skill per character | Skill01_Start, optional Hold, Execute, Recover, Cancel | Distinct silhouette; reserve one skill family per character; effects and balance remain unspecified |
| Block | GuardRaise, GuardHold, GuardLower, guarded movement, BlockImpact | Readable sustained defense; impact briefly overlays hold; releasing guard restores correct movement |
| Parry | ParryStart, ActivePose, Success, Miss/Recover; interruption | Short deliberate action distinct from held block; success only on confirmed result; no automatic counterattack assumed |
| Dash | DashStart/Travel/End F/B/L/R; diagonal blending and stop-at-wall | Body lean matches authoritative travel; seamless exit to idle/run/aim; no implied invulnerability |
| Reactions | LightHit upper-body, directional hit, Stagger, GuardBreak conditional | Hurt can coexist with movement; forced interruption only when gameplay says so |
| Knockback | KnockbackHit F/B/L/R, KnockbackTravel, KnockbackRecover; airborne fall/land variants | Recoil matches impact direction; forced travel follows the server; clean recovery or death with no extra root displacement |
| Lifecycle | Death ground/air fallback, dead pose, RespawnEnter, ready pose | Death cancels all layers; respawn clears prior action, aim/guard/charge and feedback state |
| Session | Spawn/waiting ready, match-end settle, disconnect/menu exit | No endlessly looping attack or guard after simulation ends |

Both characters need the complete required semantic set. Charged casting, guard-break,
hard-landing penalties, air attacks, air dash and channeling are conditional scope,
not new gameplay commitments. Crouch, swimming, climbing and emotes are outside the
current movement system; add separate scope if requested.

## State and blending design

Use a locomotion state machine plus an action layer and explicit full-body overrides.
Prototype a small AnimationTree first; do not build one state for every combination.
Use movement direction in character-local space for directional blend parameters.
AnimationPlayer remains the imported clip library; AnimationTree becomes the single
runtime playback controller after migration. Do not let both independently drive bones.

- Base: grounded / airborne / landing with idle-walk-run blends, starts and stops.
- Aim overlay: torso/arms and bounded aim offsets, with character-specific bone masks.
- Action overlay: energy-cast release, light hit and supported guard/cast actions while moving.
- Full-body actions: committed melee poses, dash, stagger and death where needed.
- Precedence proposal: dead/session shutdown, forced stagger/guard-break, committed
  accepted action, sustained guard/aim, locomotion. Ordinary hurt flash is additive
  and must not cancel attacks unless an authoritative interrupt was received.

Motion clips are in-place. The server/controller moves the body, including dash;
animation root tracks must not translate the gameplay root or award extra distance.
Drive playback speed within an approved small range to match real movement. Do not
speed up a badly timed clip several times to hide a timing mismatch; re-author it.
Foot locking/IK is a later polish tool after stride timing and rigs are correct.

Godot supports blend spaces, state machines, one-shots and track filters for this
design: [official AnimationTree documentation](https://docs.godotengine.org/en/stable/tutorials/animation/animation_tree.html).
Validate the proposed graph against the project's installed engine before integration.

## Ranged attacks and the view toggle

Retain V as the existing view toggle. Preserve melee; do not silently change left-click
or add defense/skill keybindings in this planning task. Exact action bindings remain
a later control-map decision. Use remappable input actions for new mechanics.

The proposed ranged rule is: a ranged action can start only in accepted lock/aim mode.
Camera pitch/yaw drives aiming; sideways/backward movement must preserve aim-facing.
Camera orientation, upper-body casting pose, projectile origin and validated cast direction
must agree. The camera can see around an obstacle while the casting hand/focus cannot: test cast-origin
obstruction, aim-ray convergence and near targets before approving the ranged feel.

Proposed toggle behavior: entering aim blends into casting-ready; leaving aim before
release cancels the unreleased ranged action and blends down. After release, do not
undo the projectile; finish recovery while allowing the view to exit. A gameplay
owner must define the cancellation/resource-cost rule before live integration.

In multiplayer, add validated aim-mode intent and bounded yaw/pitch; echo accepted
mode/action state. Do not infer lock mode from each viewer's camera. A ranged request
in free-look must be rejected by the server, not merely hidden by the client UI.
Remote characters must never read the local user's input.

### Magic/energy casting choreography

For each character: transition into a clear casting-ready silhouette, track aim with
the torso/hand while feet strafe, gather energy only if that cast has a windup, release
from the palm or authored focus socket, then recover into AimHold or movement. Both
characters share the phase contract but can have different casting poses. Keep the
mechanically significant release frame consistent with the server event.

Create an uncharged basic energy cast first. Charged casts and sustained channels
are separate optional skill families, not mandatory delays on every ranged attack.
An energy-gather pose must be readable without glow. Add glow/trails/impact later,
after hand pose and release direction pass review. VFX cannot hide bad transitions.

Test release while stationary, strafing and backpedaling; extreme permitted pitch;
casting beside a wall; cancellation before release; death during gathering; and
remote receipt of a late release. The server spawns/validates the projectile once;
animation and cosmetic energy effects never spawn a second damaging projectile.

## Skills, parry, dash and block integration contracts

| Mechanic | Animation preview can be built now | Gameplay contract required before it is enabled |
|---|---|---|
| Skill01 on each character | Start/hold/execute/recover/cancel and casting pose | Identity, skill definition, allowed modes, target, resource/cooldown, cancellation, authoritative effect |
| Ranged | Magic aim, hand/focus release, recovery and strafing | Server-simulated energy projectile, palm/focus socket, direction/obstruction, speed/lifetime, cadence, damage; charge/resource rules if selected |
| Parry | Attempt, active tell, confirmed success, failed recovery | Parryable attack types, facing cone, timing window, impact resolution, success response |
| Block | Raise/hold/impact/lower and directional guard movement | Coverage, damage reduction, stamina/cost if any, move speed, guard-break rules |
| Dash | Directional pose, travel and exit | Server travel trajectory, collision stopping, allowed states, cooldown, cancellation, invulnerability decision |
| Knockback | Directional recoil, forced-travel pose and recovery | Confirmed hit eligibility, server impulse/trajectory, collision, interruption, defense interaction and repeated-hit policy |

No animation event grants damage, parry success, blocking, a projectile, or invulnerability.
Use server-owned action phases and outcomes. The approved melee Option B timing
remains the baseline task; prior suggested windup/active/recover values are tuning
starting points, not new universal timings for every skill or defensive move.

Each proposed ActionSpec records action ID, allowed view/state, phase durations,
movement policy, interrupt/cancel policy, clip mapping and presentation sockets.
Each accepted action instance needs a sequence ID and server start/phase time so
clients can enter the correct phase, reject duplicates and recover from lost events.
Replicate persistent states such as guarding/aiming in snapshots; never rely only
on one unreliable button edge. Echo explicit success/hit/blocked/parried outcomes.
This extends the current protocol: the swing counter alone is insufficient.

Also carry the accepted action variant and a life/session epoch: missing two snapshots
must not make peers choose different attacks, and an old-life release must not replay
after respawn. Replicate authoritative grounded/air phase; vertical speed near zero at
the jump apex must not select Idle. Clear held intents when focus/input capture is lost
and use server timeouts so a lost release cannot leave a player guarding indefinitely.

Suggested interaction defaults for preview (not balance decisions):

- No new attack while dash or a committed melee phase is active; return to prior aim
  mode after dash. Plan grounded dash first; air dash is deferred.
- Guard and firing/casting cannot simultaneously own the upper-body action layer.
- A parry attempt temporarily replaces guard; if guard is still held after recovery,
  return to GuardHold. Success is never inferred from the parry clip completing.
- Death ends all actions immediately; respawn begins neutral. Match end blocks new
  action starts and settles existing presentation without applying more outcomes.
- Current death hides the Mesh anchor immediately. To show a death clip later, keep
  gameplay death/collision immediate and use a separate presentation lifetime or a
  noninteractive visual proxy; never delay death or damage immunity for the animation.
- An animation-only preview may select success/failure manually, clearly labelled
  as a fixture; those preview controls must not be shipped as gameplay commands.

## Knockback on being attacked (owner requested 2026-10-19)

Provide both characters with an explicit knockback reaction family, distinct from
the small additive hurt flinch. The sequence is impact/recoil -> forced travel ->
brake/stumble recovery -> permitted idle, movement or aim state. Use front/back/left/
right impact variants or approved blends; translate the server's knockback vector
into victim-local space so a hit from behind does not play a front-hit pose.

Author the visible response first in the animation gallery. Keep the gameplay body
server-controlled and clips in-place: animation must not apply an impulse or double
the displacement. Do not infer an impulse from the camera, an HP decrease, or clip
playback. Damage and knockback eligibility are explicit attack-result fields.

Preview and later verify:

- Grounded impact while idle, running, strafing, aiming, attacking or casting.
- Travel stopping at a wall; a shorter recovery when displacement is obstructed,
  without penetrating geometry or playing an endless full-distance slide.
- Airborne impact and knockback off a ledge -> fall -> actual landing -> recovery.
  Knockdown/get-up is conditional future scope, not required for every knockback.
- Repeated impacts during travel/recovery: server defines refresh/replace/combine
  policy and maximum displacement; clients do not stack animation-driven impulses.
- Death during any phase: death overrides knockback; respawn clears the old action
  and late old-life impact events. Match end/disconnect also clears pending reactions.
- Block/parry success versus an unguarded hit: server decides whether knockback is
  suppressed, reduced or replaced; the animation never decides defensive outcomes.

An accepted knockback may interrupt melee, ranged, skill, guard or dash only according
to the action's published interruption rule. Before integration, define distance or
impulse, duration, movement/aim control during travel and recovery, applicable attack
types, resistance and repeated-hit handling. A request for knockback animation does
not mean every damaging hit must launch the victim or that a stun system is approved.

Replicate impact/action ID, life epoch, direction and phase/start time alongside the
authoritative body movement. Observers enter the current phase after a late packet;
duplicates cannot replay recoil or apply another displacement. Test both character
models, both views and attacker/victim/observer perspectives.

## Asset handoff

Audit both rigs, bone orientations, animation names/durations, mesh count and materials
before authoring. Preserve the existing Mesh anchor/node contracts and source files.
Keep game-root +Z mesh-facing and Y-up conventions verified by a reference pose; do
not copy the stale import document's conventions without checking the actual export.

Every clip manifest entry records: semantic ID, character, source Action, loop/one-shot,
duration, layer/mask, planted-foot intervals, anticipation/contact/recovery markers,
hand/weapon socket, cancel/re-entry behavior, and status (missing/blockout/polished/verified).
Markers aid alignment and preview; gameplay phase times remain authoritative.
Import loop flags explicitly. Avoid runtime mutation of shared imported resources.
Show both clips and transitions in the review, not isolated hero poses only.

## Delivery sequence and gates

| Phase | Deliverable | Exit gate |
|---|---|---|
| A0 Audit and reference | Clip manifest, rig/mask audit, current before-videos, representative hardware baseline | Both characters and gaps inventoried; no stale “done” claims |
| A1 Existing movement polish | Idle/walk/run start-stop-turn, jump/fall/land, initial blend graph | Smooth loop seams and transitions in an animation gallery; no visible foot skating at intended speeds |
| A2 Aim movement | Aim enter/exit, aim offsets, directional strafing and turns | Upper body tracks aim while feet move naturally; both view modes and both rigs reviewed |
| A3 Melee and lifecycle | Attack anticipation/recovery, hurt/stagger, knockback reaction previews, death/respawn, model rebinding | Phase-aligned animation; moving attack exit and all interruption/reset paths correct |
| A4 Future-action blockouts | Ranged + one Skill01 family per character + block/parry/dash in preview | Complete silhouettes and transition coverage without requiring live mechanics |
| A5 Gameplay/network integration | Aim protocol, action IDs/phases, ranged/defense/dash/skill adapters | Server-owned results and matching local/remote presentation; existing regressions retained |
| A6 Polish and release review | Secondary motion, minimal VFX/audio hooks, performance pass | Approved visible gameplay on two clients and measured eight-player budget |

A1-A4 focus on animation. Do not wait for particles or fully balanced skills to begin
them. Gate A5 per mechanic: ranged and defense/dash require explicit server rules;
character-specific skills also depend on M7.2 authoritative identity. Finish relevant
M7.1 resource/rebinding/timing tasks alongside A1-A3. No new public-online scope.

First implementation task: build the animation review gallery and capture the current
baseline, then polish idle -> walk -> run -> stop -> turn -> jump -> land for both
characters. Review that slice before producing all of the future-action clips.

## Acceptance and test plan

Automated checks cover required semantic clips, imports, loop modes, separate instance
parameters, stable model references, action exit/reset, duplicate/stale events, disabled
input after death, and no movement/damage from preview animation. Blend parameters
must follow authoritative velocity rather than key state on remote players.

Visual review covers both characters in free-look and aim view: start/stop/reverse,
strafe/diagonal/backpedal, speed changes, jumping/ledge fall/landing, moving attacks,
attack-to-idle, aim-toggle before/after release, block-hit-release, parry success/fail,
dash into walls/stop/turn, knockback from each direction and into walls/off ledges,
repeated knockback, skill cancel, death mid-action and respawn. Check at normal
speed and slow motion; inspect hands, feet, shoulders, weapon clipping and silhouettes.

Use fixed-camera before/after clips and a third-person opponent view. Review at 30 and
60 FPS, then test two real clients with delayed inputs and replicated outcomes. Add
loss/duplicate/out-of-order tests for the expanded action protocol; the old delay-only
suite is not packet-loss coverage. Eight-player review measures frame time/draw calls
on named hardware; choose the performance target from the baseline, not an invented pass.

Provisional tuning starting points: 0.10-0.20 s ordinary transition blends, shorter
action onset where needed, and no obvious loop seam at full speed. These are trial
values, not fixed combat windows or proof of quality. A visual action must enter its
correct phase by the next render update after an accepted state is applied; test
transport delay separately rather than requiring zero-latency network presentation.

The QA report records clip coverage and gameplay integration separately. A missing
gameplay mechanic cannot pass by playing its animation in a gallery. Owner sign-off
is required to mark visual polish accepted. No animation or gameplay tests were run
as part of this documentation-only planning task.

## Decisions still open (do not block locomotion work)

- Ranged style is decided: magic/energy projectiles. Default integration proposal is
  server-simulated traveling projectiles. Spell appearance, hand versus focus casting,
  projectile speed/lifetime and any resource/charge system still need definition.
- Exact Skill01 definitions for each character and their allowed view modes.
- New keybindings, guard cost/coverage, parry window/reward, dash distance/cooldown,
  invulnerability and cancel rules; knockback eligibility, strength, duration, defense
  interactions and repeated-hit policy. Do not assume dash grants invulnerability.
- Air combat/air dash, charged casts and channeling, if desired later. Gun-specific
  reload/ammo/recoil animation is outside this plan.

The user has already requested the feature families and animation-first priority;
these open details are design dependencies, not a reason to stop the audit and
locomotion/aim animation work.

## Local evasion/parry prototype update

The owner requested a more effective dodge, a forward dash and parry. Main now
uses immediate side/back evasion and a distinct Run-derived forward dash, with
shared timing profiles for movement and pose generation. Main sparring enemies
telegraph their strikes before contact. F provides a timed frontal single-hit
parry with separate attempt/success upper-body clips over ordinary locomotion.
These are playable local defaults; multiplayer action authority, rewards and final
balance remain future decisions. See DASH_PARRY_CHECKPOINT.md for exact values
and automated checks. Visual polish and keyboard feel still require a playtest.
