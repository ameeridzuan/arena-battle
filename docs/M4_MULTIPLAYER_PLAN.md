# M4 — two-client local multiplayer proof of concept

Owner accepted M3 and requested the next task on 2026-10-16. This plan implements only
the M4 roadmap scope. The separate scene keeps the accepted single-player loop available.

## Decisions and interfaces

- ENet UDP, bound exclusively to 127.0.0.1, default port 24560, maximum two clients.
  A headless local server process runs both players; server peer ID 1 owns all nodes.
  Client-to-client relay is disabled; replicas learn the roster from server snapshots.
- Physics stays at the project default 60 Hz. Clients capture/send controls at that rate;
  server snapshots are sent at 20 Hz. Explicit channel 0 carries ordered unreliable
  snapshots, channel 1 carries registration/reliable and input/unreliable ordered,
  channel 2 carries diagnostic ping/pong. Object decoding is not enabled.
- RPCs exist only on `/root/MultiplayerArena`. Registration and control RPCs derive
  ownership from `get_remote_sender_id()`. A packet cannot select another player or team.
- The input contract is sequence, Vector2 movement, yaw, run/jump/attack booleans.
  Reject negative/oversized/replayed or implausibly advanced sequence values, nonfinite
  controls and movement length >1. Normal controls are rate-budgeted per peer (90/s,
  burst 120); inputs stale for 250ms stop accelerating, followed by normal deceleration.
- Server invokes the existing player movement calculation with external controls and
  the same attack range/arc/cooldown/Health/Combatant/MatchManager paths. Player-versus-player
  hitboxes use layer 2; an explicit owner exclusion prevents self-damage.
- `replica_match_state.gd` is a client display model with no match simulation. Replicated
  Health rejects local apply_damage/reset. HUD binds only the local peer's player.
- Snapshots contain authoritative position, velocity, facing, HP/max HP, dead state,
  swing counter, team, score/timer/phase/result and connection status. Disappearing roster
  entries are removed. Only authority RPCs can deliver snapshots or ping responses.
- Game starts once both clients register. Disconnect before start leaves a slot open;
  disconnect during play ends the session as a draw, without more scoring/respawns.
  Server loss clears replicas and displays a stopped-session message. ENet peers use
  a 1–3 second timeout window for a server/client process that disappears abruptly.

## Acceptance checks

1. Two independent clients register, see both players and their own HP/camera.
2. Server simulates bounded movement; both clients observe server positions.
3. Remote attack intents respect range, facing, cooldown and self-hit exclusion.
4. Real intents produce damage, death, one score per kill, respawn and full HP restoration.
5. Server score/time conditions produce replicated results; post-match requests cannot
   move players, damage them, score or trigger another respawn.
6. Malformed/replayed controls and request floods are rejected without mutating outcomes.
7. Simultaneous attacks and a client with 100ms injected control delay remain consistent.
8. Client disconnect, server loss and initial connection failure terminate/report cleanly.
9. Existing local movement/combat/match/feedback checks still pass.
10. Owner verifies real two-window play feel after automated and rendered checks.

## Running

From a PowerShell prompt in the project folder:

```powershell
.\tools\start_multiplayer.ps1
```

The script resolves the existing Godot console executable relative to this repository;
use `-GodotPath 'C:\path\Godot_console.exe'` for another installation. It starts one
hidden server and two visible game windows. WASD, Shift, Space, mouse, left-click and Esc
match the local game. Close both client windows to end the launcher and its server.

Automated tests (Python standard library only):

```powershell
python tests/run_multiplayer_smoke.py --godot 'C:\path\Godot_console.exe'
```

For separate launches, use the same scene with `-- --server` for the headless server,
and without that flag for each client. `--port=24560` after `--` chooses a local test
port; `--input-delay-ms=100` injects outbound control delay for diagnostics.

## Limits

- Loopback only. No LAN/public server, matchmaking, authentication, lobby or reconnect.
- No client prediction, reconciliation, interpolation or lag compensation. Movement is
  displayed at snapshot rate, so it can feel less smooth than M3, especially under delay.
- Unreliable controls can drop single-frame jump/attack edges under loss. Packet-loss/
  jitter emulation is not part of the delay test; address reliable action delivery before
  public networking. No client position is ever trusted to compensate for latency.
- Simultaneous actions resolve in authoritative server iteration order, without rollback.
- One player per team; M5 owns 4v4. Restart all processes for a new match.
- Application RTT is displayed; injected control delay is reported separately and is not
  a claim of measured WAN latency. No new dependencies or public port exposure.

## API research

Verified 2026-10-16 against the official Godot documentation and installed
Godot 4.7.2.stable.official.ed1daf0bf:

- https://docs.godotengine.org/en/stable/tutorials/networking/high_level_multiplayer.html
- https://docs.godotengine.org/en/stable/classes/class_enetmultiplayerpeer.html
- https://docs.godotengine.org/en/stable/classes/class_enetpacketpeer.html

Runtime tests verify the installed engine's RPC signatures, channels and ENet methods.
