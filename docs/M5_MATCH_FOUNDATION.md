# M5 — 4v4 match foundation

Status (2026-10-16): implemented and automatically verified; owner visual playtest pending.
Owner accepted M4 with “seems to work. can proceed”. M6 assets are being prepared by
another AI at the owner's request; coordinate shared player-scene integration.

## Behavior and ownership

- `network_session.gd`: default eight registrations start a 4v4 match. The server
  assigns the smaller team (A on ties) and first free slot 0–3. No team can exceed
  four players. A pre-start departure frees its slot; running disconnects end in a draw.
- ENet capacity is eight (two in explicit quick-test mode). Extra connections and
  registrations after match start are rejected. Results remain server-authoritative.
- Arena has four distinct markers per team. Combatant.spawn_index is set before
  adding the player to the tree, matching initial spawn and respawn assignments.
- Network melee disables friendly damage. Local prototype behavior is preserved.
  A swing stops processing further targets when match end disables the attacker.
- Five kills or 180 seconds ends the match; existing score/timer/draw rules are reused.
- Wire snapshots use positional arrays (id, team, slot, position, velocity, mesh yaw,
  aim yaw, HP, max HP, dead, swing count), avoiding repeated dictionary keys and the
  oversized unreliable-packet warning found with eight players. Both peers must run
  the same version. Clients reconstruct display records and own-player HUD bindings.
- `--bind=IP` and `--connect=IP` enable explicit LAN addressing; defaults remain
  127.0.0.1. `--players=8` is default; `--players=2` preserves quick 1v1 checks.
  No firewall changes or public hosting setup are performed by the game.

## Run

From the project folder, `./tools/start_multiplayer.ps1 -Players 8` starts a hidden
server and eight visible clients. Use `-Players 2` for a lighter combat check.
Close all clients to let the launcher clean up its own server.

For LAN, start one server with `--server --bind=SERVER_LAN_IP --players=8`, then eight
clients total with `--connect=SERVER_LAN_IP`, distributed across PCs. All commands
launch `res://scenes/multiplayer/MultiplayerArena.tscn`; custom options follow Godot's
`--` separator. UDP port 24560 must be reachable. A two-PC/two-client check uses
`--players=2` on the server. Restart processes for another match.

## M6 integration boundary

M6 can prepare models, rigs, animations and separate visual scenes independently.
Player.tscn integration needs coordination: current code expects a MeshInstance3D
named Mesh, and Health, Combatant, AttackHitbox, CameraPivot/CameraTilt/Camera3D,
CollisionShape3D and PlayerFeedback. A rigged model must preserve or deliberately
adapt team coloring, hurt flash, death visibility, aim/movement rotation and remote
animation. Remote characters must not read local input. Re-run networking and local
regressions after integration. M5 did not edit Player.tscn or the M6 asset/test files.

## Limits

No matchmaking, lobby, reconnect, prediction/interpolation, lag compensation or
public deployment. Tests use local processes, not eight physical PCs. Human visual
acceptance and physical LAN validation of this M5 build remain pending. A stable
assigned respawn slot is not a dynamic occupied-spawn avoidance system.
