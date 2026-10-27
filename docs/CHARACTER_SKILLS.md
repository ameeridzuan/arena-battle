# Character skills

Press **G** in local play, the motion course or multiplayer. Tab switches character. The HUD shows the selected skill's cooldown and the remaining scythe duration. Multiplayer clients request a skill; the server validates identity, life state, stun, action state, match phase and cooldown.

| Character | Skill | Effect | Cooldown |
| --- | --- | --- | --- |
| Arclight | Pulse Grenade | Small ballistic grenade, 0.9-second fuse, 3 m blast radius, 4-second enemy stun | 18 seconds |
| Ashen Warden | Flame Scythe | Temporary burning polearm for 20 seconds; sweeping reap, reverse hook and aerial cleave | 40 seconds |

Cooldowns start on activation. Each character has its own timer on the same actor. Switching character cancels an active scythe but does not erase either cooldown; death also does not reset cooldowns. Death, respawn, model changes and match end remove the temporary weapon. No activation is accepted during a stun, traversal, another active action, death or an ended match.

The grenade deals no direct damage. The blast queries real collision geometry, ignores its thrower and teammates, and cannot stun through world cover. Stun interrupts attacks, casting, dodges, parries and traversal, prevents horizontal movement and jumping, and preserves gravity/collision. It clears after four seconds or on death/respawn/match end. An interrupted cast restores melee when the stun ends.

While the scythe is active, accepted melee attacks alternate `Skills/Scythe_Reap` and `Skills/Scythe_Return`; airborne attacks use `Skills/Scythe_Cleave`. These are rig-local animation variants with adjusted torso, arm and forearm poses and heavier timing. The visible hooked blade replaces Warden's sword. Contacts follow its animated hand transform, with a longer active follow-through window, once-per-swing hit tracking, range/arc gates and cover checks. Default impact remains 25 HP. A confirmed enemy hit adds the existing refreshable burn: 3 HP per second for three ticks (9 total). Misses, blocked/parried contacts and friendly contacts do not grant burn. Burn refreshes instead of stacking.

The server owns grenade travel/detonation, stun, weapon duration, cooldowns, blade contact and burn damage. Snapshots include skill timers, active weapon, stun and grenade/flash presentation. Replicas display these states and cannot activate skills, detonate authoritative grenades, grant stuns or damage health. Action bit 64 carries G; a reliable one-shot RPC also carries its sequence token so a single press survives movement packet loss. Both paths share replay protection and cooldown checks, with rate-limited reliable requests. Unknown bits above the defined mask remain rejected. Both peers must use the updated protocol/build.

Implementation: `scripts/combat/character_skills.gd`, `stun_grenade.gd`, `stun_status.gd`, and `scripts/player/skill_animations.gd`. Player and dummy scenes include stun status; Player also includes character skills. Balance values are exported on the skill component.

Verification commands:

```powershell
Godot --headless --path . --fixed-fps 60 --script res://tests/integration/character_skills_smoke_test.gd
python tests/run_character_skills_smoke.py --godot PATH_TO_GODOT_CONSOLE
Godot --path . --rendering-method gl_compatibility --script res://tools/review_character_skills.gd
```

The focused suite covers grenade activation/spam, blast/friendly/cover/range behavior, exact stun expiry, control lock and recovery after interrupted casting, independent cooldowns, temporary weapon expiry, slash selection, real blade contact and all burn ticks, replica rejection, serialized weapon state and death/match lifecycle. Existing weapon, casting/dodge and integrated parkour suites are also checked. The real ENet suite starts a server and two independent clients and checks accepted G requests, traveling grenade stun, replicated weapon/flash/timers, authority-only expiry and replica restrictions. Its reports stay in `.godot/skills-network-*`.

The visual review saves `../assets/character-skills-preview.png` outside the Godot project.

Validated on 27 October 2026: focused character skills 48/48, real ENet single-press delivery/presentation 25/25 (server 9, each client 8), existing weapon contact 109/109, cast/dodge 320/320 and integrated parkour 34/34. Reap, reverse hook and aerial cleave each made real contact and applied burn. The visual review was rendered and inspected in Godot. The initial sandboxed network run could not connect; the live ENet pass ran with local loopback access enabled.
