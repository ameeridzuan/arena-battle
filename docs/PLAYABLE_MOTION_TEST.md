# Playable motion test — 20 October 2026

Open the ArenaBattle project in Godot and press **F5**. The configured main scene
is `scenes/main/Main.tscn`. This test is in the project; the existing portable
Demo 1 executable has not been rebuilt.

| Control | Test |
|---|---|
| WASD / Shift / Space | Existing walk, run and jump |
| Left mouse | Weapon-contact melee |
| Space, then left mouse while airborne | Overhead jump attack |
| V | Toggle shoulder aim; a cyan center reticle appears |
| R in aim view | Cast the new magic motion while standing or moving |
| Q while moving forward | Forward dash |
| Q while moving sideways/backward | Quick directional dodge |
| Q without movement | Backstep |
| F | Timed frontal parry against an incoming melee strike |
| Tab | Switch Arclight / Ashen Warden and clear the previous action |
| Esc | Release or re-capture the cursor |

Try left click close to an enemy: the blade trail follows the weapon and a spark
burst appears where it touches the target. Damage occurs during the active swing,
not at the click. Jump with Space and click while airborne for an overhead cut.
Gravity continues, each victim takes at most one 25-damage hit per swing, and one
air attack is allowed before landing. See WEAPON_ATTACK_CHECKPOINT.md for details.

Try V, then hold A/D and repeatedly press R. The upper-body cast should leave the
legs stepping. The left hand releases a visible energy bolt near the 0.34 s marker.
The bolt aims from the hand toward the camera reticle, checks hand obstruction,
stops on arena/target collision and expires after 2 s. An enemy hit deals **20 damage
plus 3 burn damage per second for 3 seconds**. Repeated hits refresh one burn while
preserving the next tick time. Red numbers show actual HP lost; orange BURN numbers
and embers identify the aftereffect. Walls block the spell and allies take no spell
damage. Exiting aim before release cancels it; exiting after release allows
the recovery to finish. Each cast has a 1 s test cooldown.

Try Q while walking forward, backward, left and right. Side/back dodges now respond
on the first physics tick, last 0.42 s and cover roughly 2.5 m without obstruction,
with an 8 m/s peak and 0.75 s cooldown. Forward intent uses a separate 0.36 s dash,
roughly 3.35 m of travel, an 11 m/s peak and 0.85 s cooldown. Its pose adapts the
accepted human running capture with a sprint lean instead of the former crouched
forward dodge. Both share an evasion cooldown, retain collision/gravity, require
ground contact and **grant no invulnerability**. Diagonal intent chooses a cardinal
direction relative to the facing when the action starts.

Approach an enemy and watch its orange **STRIKE** tell. Local enemies now wind up
for 0.32 s before checking their existing melee range and arc at contact. Try a
back/side dodge after the cue: moving out of range avoids the strike, while dodging
into a wall can still leave you in range and taking damage.

Tap **F** shortly before contact to parry. The local test has a 0.04 s startup,
an active interval ending at 0.22 s, recovery through 0.46 s and a 0.8 s cooldown.
Face the attacker: only a frontal 120-degree cone is covered. One successful melee
deflection closes the window and plays a 0.30 s success recoil with a PARRIED notice.
Early, late, rear and ordinary non-melee damage are not blocked. This is a timed
parry, not a held guard, automatic counterattack or invulnerability state. Parry
uses the upper-body layer so normal leg movement continues beneath it.

Tab lets you repeat the same tests on both models. Melee cannot fire while the
test cast, evasion or parry owns the action. Death, match end, lost application focus, releasing
the cursor and character switching cancel pending actions. Cooldown status and
current character appear below the camera-mode label.

## Implementation scope

Only Main's local player uses `local_motion_test_player.gd` and its
`MotionTestControls` child. The shared Player scene, gallery fixtures and multiplayer
player spawns do not install this input/movement adapter. Existing normal movement
still delegates to the original controller. The animation layer stays presentation
only; local test components own evasion travel, damaging bolt spawning and parry
resolution. A generic optional melee-contact interface is called after hit validation;
normal/network players without that interface keep their existing damage behavior.
Main-only sparring attackers add the visible windup; shared/network attack timing
is unchanged. Pose generation and travel read the same evasion profile timings.

`motion_cast`, `motion_dodge`, `motion_parry` and `motion_switch_character` are registered in InputMap
when this local harness loads. Their defaults are R, Q, F and Tab. All new keyboard
polling requires captured mouse input; direct action APIs support automated tests.

The pose studies remain blockouts. Review palm orientation, feet, weight transfer,
weapon/armor clearance and readability at game speed. Competitive
dodge rules, persistent aim pose, aim pitch offsets, authoritative action phases
and network synchronization are later work. These test values are tunable prototypes.

## Verification

The weapon-contact update passed 109 checks across both characters, including
real Space-jump attacks, the four ground swings, surface-positioned effects,
wall/friendly/replica gates, one-hit/air-budget rules and lifecycle cancellation.
Eight regression suites passed; see WEAPON_ATTACK_CHECKPOINT.md.

The latest damage/burn integration passed 42 checks, including an actual cast,
projectile collision and three native periodic ticks. Combat, match, player
feedback, playable motion, parry/dash and Demo 1 hardening were rerun and passed.
See RANGED_DAMAGE_CHECKPOINT.md for damage rules and test coverage.

The real-physics motion test covers aim gating, moving cast/leg motion, one
release, dodge direction/distance, wall collision, unchanged damage immunity, model
rebinding, and death/focus/mode cancellation. All 67 playable-motion checks passed
on Godot 4.7.2. The updated pose suite passed 320 checks. A separate 67-check
parry/dash suite verifies real enemy windup/contact timing, successful escape,
blocked retreat, immediate dash travel, frontal parry, single-hit consumption,
startup/recovery misses and environmental damage bypass on both rigs.
Movement, combat, player feedback, facing mode, model import, layered animation
(310), animation foundation (28), and Demo 1 snapshot hardening (20) also passed.
The match suite also passed after its fixture was updated to distinguish local
sparring overrides from unchanged shared DummyTarget defaults.

The lethal-damage fixture uses a noncombatant test source and emits the expected
unattributed-kill warning; there were no script errors in the passing run. Automatic
checks validate real physics and bone poses, not manual keyboard feel or rendered
visual polish. The owner playtest remains the acceptance step. No export, commit
or push was made for this local test adapter.
