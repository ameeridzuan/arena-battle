# 1v1 parkour build — 23 October 2026

The portable Demo 1 Host/Join match now uses the approved shared movement and
combat components. Both clients run the same protocol/build.

## Included

- Height-adaptive stairs, hanging/shimmying, left-foot-led 2.15-second climbs,
  corrected wall-slide braces, and higher, fluid wall-jump recovery.
- Timed blade contact, jump overhead attacks, forward dash/directional dodges,
  frontal timed parry, moving cast, impact damage and refreshable burn.
- Server-approved Tab character changes, consistent identity on both viewers,
  authoritative animation/pose state, blade trails, impact sparks, projectiles,
  health numbers and burn presentation.
- A mirrored parkour arena: 1.8 m side terraces with 15–30 cm stair rises,
  low vault blocks, opposing wall-jump lanes, 3.2 m upper landings and an open
  central duel court. Existing team spawn positions are preserved.

Clients send bounded controls and action bits, never positions, damage or
cooldowns. The server simulates movement/collision, weapon contacts, projectiles,
burn, death, respawn and match rules. Only server snapshots grant presentation.
Pose/effect data uses bounded DEFLATE compression to avoid oversized 1v1 packets.
The connection grace allows character resources to load without false timeouts.

## Verification

- Integrated authority/terrain suite: 34/34, including actual blade contact,
  spell impact and all three burn ticks, stairs, ledge completion, wall slide,
  wall jump, serialized pose round trips, cooldown/invalid-input rejection,
  replica damage rejection and death/match-end cancellation.
- Snapshot/health/resource hardening suite: 22/22, including a 411-byte compressed
  sample and application through the actual compressed snapshot receiver.
- Terrain overview rendered in Godot and inspected. Upper collision bounds keep
  elevated routes inside the match arena; an above-wall sweep rejection is covered.
- Live two-client and packaged startup results are recorded after export below.

No physical second-PC/LAN or human feel acceptance is claimed by these checks.

## Build

Use tools/build_demo1.py with the installed full Godot executable and an output
folder. Matching Windows export templates are unavailable, so this preview uses
the full Godot executable as a portable runtime alongside its exported PCK.
Both files, engine notices, controls and checksums are included in the ZIP.
The isolated build selects the tested OpenGL compatibility renderer.
The helper can resume its own isolated stage with --reuse-stage; it never changes
the source main scene or the user's editor settings.

References used for transport implementation: [Godot high-level multiplayer](https://docs.godotengine.org/en/stable/tutorials/networking/high_level_multiplayer.html) and [PackedByteArray compression](https://docs.godotengine.org/en/stable/classes/class_packedbytearray.html).

Final live regression: **67/67 passed**, exit 0, with an actual dedicated server
and two independent ENet client processes. Gameplay, disconnect cleanup, timer
result replication and unavailable-server handling all pass without engine errors.
Logs/reports are saved under .godot/onevone_live_qa/.

Final Windows artifact: ../builds/1v1-parkour-2026-10-23/Demo 1.zip
(89,316,885 bytes). The actual exported Demo 1.exe loaded its own packed menu
and terrain under OpenGL, confirmed the readiness handshake and 12 m upper
collision bounds, rendered both screens, and exited 0 with no engine errors.
All four SHA-256 entries and all ZIP CRCs pass. Both .exe and .pck must stay
together; the ZIP also contains controls, engine notices and checksums.
