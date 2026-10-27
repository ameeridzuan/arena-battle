# Jump attack and weapon-contact feedback

Run F5. Left click performs a ground swing. Press Space, then left click while
airborne for an overhead cut. Both characters use the same local combat adapter.
The visible blade trail follows the current weapon, while a cyan contact burst
marks a confirmed ground hit and an amber burst marks a confirmed jump hit.
World collisions can also produce sparks without awarding damage.

Each swing deals 25 damage once per victim. Contact is permitted only during
30–80% of a 0.65-second ground swing or 0.9-second airborne swing. The air timing
keeps the downward cut in reach during a normal jump's descent. Repeated input
cannot restart an active attack; the cooldown includes recovery. One air attack
is allowed per airborne period. Gravity, horizontal movement and collision remain
in the movement controller; there is no forced teleport, hovering or ground AoE.
Landing restores the next air attack opportunity.

Ground attacks reuse Slash, Backhand, Overhead and Thrust. Air attacks reuse
Attack_Overhead on the upper-body layer while Jump supplies pelvis/legs. An action
playback_speed scales only its clock and preserves fade durations in seconds.
No new imported animation copies or movement-specific attack variants are needed.

Rig inspection found each blade fully skinned to hand.R. Hand-local endpoints:

| Rig | Blade base | Blade tip |
|---|---|---|
| Arclight | (0, 0.070, -0.111) | (0, 0.070, -0.851422) |
| Ashen Warden | (0, 0.070, -0.120) | (0, 0.070, -1.080) |

These come from actual blade vertices transformed through the skin bind, not an
assumed hand direction. Physics samples the current hand pose after animation,
then sweeps a 0.07 m radius capsule between previous/current blade segments with
up to 16 spatial subdivisions. Target collision is three-dimensional; an opponent
far below the blade cannot be hit by horizontal range alone. Center range/arc,
self, team, replica and living-target gates still apply. Local scenes disable
friendly fire. Shape queries supply the victim's actual collider contact surface
for line-of-sight tests and VFX placement. Blade-to-contact and body-to-contact
world rays prevent a hand animated through a wall from granting damage behind it.

Only confirmed HP loss emits weapon_hit and a victim impact effect. The existing
damage-number/health pipeline handles feedback and kill attribution. A blocked
parry therefore grants no false damage burst. Contact effects expire after 0.28 s
and remain in world space; the old floor swipe is hidden for this adapter.

Death, reset, focus/cursor loss, model replacement, match end, traversal ownership
or takeover by dodge/parry cancel pending contacts and the trail. Main and the
MotionTestCourse install local_weapon_attacker; shared Player/network scenes keep
their existing attacker. Legacy combat and feedback fixtures explicitly exercise
that shared contract; a separate weapon-contact suite checks the local behavior.
No multiplayer protocol or portable export is changed.

Godot 4.7.2 validation passed: 109 weapon-attack checks on both rigs. These cover
all four ground attacks, genuine Space-jump contact before landing, airborne
gravity/leg animation, collider-surface contact points, harmless windup, one hit
per target, thin-wall separation, friendly/replica gates, air budget after cooldown,
effect expiration, focus/reset/model/evasion/death cancellation, respawn readiness
and match-end cancellation. Eight regression suites also passed: shared combat,
player feedback, layered animation (310), playable motion (67), parry/dash (67),
ranged damage (42), match and Demo 1 hardening (20).

Implementation: local_weapon_attacker.gd owns local contact phases and blade
sweeps; weapon_impact.gd owns transient VFX; animation_action.gd and
layered_animation.gd supply independent playback speed. Main/MotionTestCourse
install the adapter; character_animation.gd avoids presenting a second action;
player_feedback.gd suppresses the old local floor wedge; MotionTestControls
cancels pending weapon contact when another action takes ownership.

Manual blade clearance, impact readability and balance remain playtest items.
