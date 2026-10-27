# Responsive evasion and timed parry

The previous 0.72 s dodge enforced about 115 ms of still anticipation and about
158 ms of still recovery, moving only 1.53 m. Shared melee also resolved instantly,
so its visible swing provided no reaction interval. This update addresses both
problems in the local F5 test.

- Side/back dodges: immediate travel, 0.42 s, approximately 2.53 m, lighter hip dip,
  stronger leading/trailing step and shorter recovery.
- Forward dash: distinct `Dash_Forward` clip, 0.36 s, approximately 3.35 m, accepted
  human Run capture with authored forward lean. No duplicated forward-dodge asset.
- Main-only enemies: 0.32 s visible windup, then existing range/arc/contact validation.
- F parry: 0.04–0.22 s frontal active window, one deflected melee hit, 0.46 s attempt,
  0.30 s confirmed-success motion, 0.8 s cooldown and 120-degree facing cone.

Evasion remains physical displacement with collision and gravity. It does not award
invulnerability. A blocked retreat can still be hit. Forward dash is movement, not
an offensive hit or a guarantee of passing through enemies.

`motion_profiles.gd` shares evasion timing between generation and local movement.
The cast is retained unchanged. Parry attempt/success are upper-body actions reused
over locomotion on each rig. Success starts at full layer weight with a guarded pose,
avoiding a one-frame drop to ordinary locomotion before the confirmed recoil.
The generic zero-blend contract now applies its pose immediately.

Only the Main player implements `receive_melee_hit`. Melee calls it after ordinary
range, overlap, team and arc validation; players without the optional method retain
their existing direct damage path. Ordinary `apply_damage` bypasses parry, so falls
or environmental damage cannot be converted into a melee deflection. There is no
automatic counterattack, attacker damage, stamina system or multiplayer parry protocol.

Only Main enemies install `local_sparring_attacker.gd`; shared/network attackers
retain their previous timing. Windup is cleared on death and match end. Contact
uses the defender's current position, enabling actual displacement-based evasion.

Run F5; use Q with forward intent to dash, Q with side/back intent to dodge, and F
near the end of the enemy's windup to parry. Use V for stable aim-facing and Tab
to compare both rigs. Gallery fixtures include Dash/Forward, the three Dodge modes,
Parry/Attempt and Parry/Success; gallery success is never a gameplay outcome.

Automated validation passed on both rigs: 67 parry/dash checks, 67 playable-motion
checks and 320 cast/dodge/parry pose checks. These cover actual contact timing,
displacement, wall collision, parry direction and single-hit consumption. Manual
feel, feet/palm orientation and armor/weapon clearance remain owner review items.
