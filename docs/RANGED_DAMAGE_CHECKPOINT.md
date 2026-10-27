# Damage numbers and local ranged burn

Run F5, toggle V to shoulder aim, point the reticle at an enemy and press R.
The traveling bolt deals 20 impact damage, then 3 damage at each of the next three
one-second burn ticks (29 total if all ticks occur). Repeated impacts refresh one
burn and its source without postponing the next tick or stacking timers. Both
character rigs use the same combat components. Motion and cooldowns are unchanged.

Red floating numbers report actual HP lost for melee and ranged hits, including
hits on the player. Orange BURN numbers and rising embers identify periodic damage.
Numbers cap at remaining HP, rise/fade for 0.9 seconds and stay at the hit location
when the character moves, swaps model or dies. Blocked/invalid hits, healing and
reset do not generate damage numbers. Initial network snapshots establish a
baseline; subsequent replicated HP losses can show neutral hit numbers.

The bolt performs a swept world/player/target ray and resolves only its first
collision. Walls and allies consume it; only a live enemy with an authoritative
Health component can take damage. The source RID is excluded. Source death,
expiry and match end remove flying bolts. Impact uses the existing body damage
interface, while burn ticks use Health with an explicit burn kind and the original
caster as damage source, preserving existing death/score behavior. The current
melee-only parry does not block projectiles or burn.

Health supplies actual-loss and explicit-reset signals. Shared Player/DummyTarget
scenes install one DamageFeedback presenter and one BurnStatus component. Burn
clears on death, reset/respawn, match end or a freed source. Already applied burn
can continue after caster death while that source object exists. Replica Health
cannot start burn or accept local damage. Network snapshots never start burn timers.
The local F5 adapter binds spell damage values; multiplayer spell commands and burn
replication are not part of this change. The portable build has not been rebuilt.

Tunables are exported on MotionTestControls: ranged_damage=20, burn_damage=3,
burn_ticks=3, burn_interval_s=1. Bolt speed remains 12 m/s and lifetime 2 seconds.
Burn visuals use built-in CPU particles and sphere meshes; no new asset dependency.

Godot 4.7.2 validation passed: 42 ranged-damage checks, including real casting
through emitted-bolt collision and three automatically scheduled burn ticks;
friendly/replica/wall gates; refresh cadence; exact damage numbers and expiration;
death/reset/match-end cleanup; and lethal burn score attribution. Six regression
suites passed: combat, match, player feedback, playable motion (67), parry/dash
(67) and Demo 1 hardening (20). No script errors appeared in those passing logs.
Manual readability and combat balance remain playtest items.
