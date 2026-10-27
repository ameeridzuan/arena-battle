# Team waiting lobby — 27 October 2026

Run scenes/multiplayer/Demo1.tscn (F6) or the new Windows package. Host opens a four-player lobby; Join connects to the host's LAN IP on UDP 24560. The host also counts as a player.

Players choose Team A/Blue or Team B/Orange and Arclight or Ashen Warden. Each team holds two players. Characters may repeat. Everyone marks Ready, then only the host can start. Two players start 1v1, three start 2v1 or 1v2, and four start 2v2. No bots fill empty slots. Both teams must contain at least one player. Loading readiness and the player's Ready choice are separate.

Roster and selection changes clear everyone's Ready choice. Team changes update authority combat identity, marker, spawn slot and respawn point. Match start locks lobby choices; existing in-match Tab character switching remains available. Existing authoritative damage, friendly-fire exclusion, scoring, respawn, parkour and match timer are retained. A disconnect during an active match still ends that session, matching the previous prototype. Host departure has no migration; return to menu to host a new lobby.

## Implementation

- scripts/multiplayer/demo1_menu.gd launches the dedicated authority with a generated, process-lifetime owner token and connects the host client. The owner claim prevents a faster joining guest from becoming host. No token is stored in the repository or sent in the roster.
- scripts/multiplayer/network_session.gd validates lobby RPCs using their actual sender ID, capacity, team/character bounds, phase and host identity. Selection requests are rate limited. Reliable revisioned rosters carry selections/readiness; compressed gameplay snapshots remain separate.
- scripts/multiplayer/waiting_lobby.gd presents open slots, both teams, selectors, Ready and host Start. Camera and gameplay input stay disabled while waiting, with a free cursor. The screen hides when the authority starts the match.
- Direct MultiplayerArena sessions retain legacy two/eight-player automatic-start regression modes. Lobby mode is explicit (--lobby, fixed four-player capacity), and is enabled by the Demo1 menu.

## Validation

Run tests/run_lobby_smoke.py --godot PATH for independent ENet server/client processes covering 1v1, 2v1, 2v2 and a four-player lobby dropping to three before start. Tests cover owner identity, waiting state, loading handshake, selections, invalid requests, full teams, team/respawn changes, ready resets, guest start rejection, host start, unique slots, selection lock, camera/cursor and HUD ownership.

Run tests/run_multiplayer_smoke.py --godot PATH for the existing authoritative combat/disconnect/timeout regression suite. Test artifacts stay under .godot/ or temporary directories. LAN on separate human PCs remains a manual acceptance step.

## Verified release

Windows package: `../builds/team-lobby-2026-10-27/Demo 1.zip`. Verification passed: 201 independent lobby-process checks, 14 actual packaged Host/Return checks, 67 isolated combat/disconnect/timer/unavailable-server checks, and 22 snapshot/health checks. ZIP CRC and all four SHA-256 manifest entries pass. Rendered lobby reviewed at 1280×720. Summary and logs: `.godot/team_lobby_release/`.

The released executable/resource pack uses the isolated export snapshot and excludes character skill work being edited concurrently in the shared working tree. Those separate changes were not altered or included in this release.

## Lobby with character skills

The combined package is `../builds/team-lobby-skills-2026-10-27/Demo 1.zip`. It includes Pulse Grenade (Arclight) and Flame Scythe (Ashen Warden), activated with G. Character selection now describes the selected skill and cooldown; the in-match HUD shows live timers. The previous lobby-only package remains available separately. See CHARACTER_SKILLS.md for effects and controls.

The expanded lobby tests verify that skills cannot activate while waiting and that every player can activate the selected skill after host start, across 1v1, 2v1/1v2, 2v2 and a four-player lobby reduced to three. All 218 checks passed. Focused skills passed 48/48, live network skill effects 25/25, and snapshot/health checks 22/22.

The combined exported EXE/PCK also passed the 25-check live skill network test and 14-check Host/Return test. ZIP CRC and all four SHA-256 file hashes passed. Verification summary: `.godot/team_lobby_skills_release/summary.json`.
