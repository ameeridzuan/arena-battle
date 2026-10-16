# M4 QA report — local two-client multiplayer

Date: 2026-10-16. Engine: Godot 4.7.2.stable.official.ed1daf0bf.
Owner accepted M3 and its feedback/health HUD follow-up, then authorized the next task.

## Implementation

Separate MultiplayerArena scene, loopback ENet server, two server-assigned teams and
server-owned movement/hits/HP/death/respawn/score/time/results. Existing Main.tscn stays
the local game. HUD late binding, replica health/match state, team colors and local camera
ownership are integrated. tools/start_multiplayer.ps1 starts a hidden server and two
playable clients, then stops only its own child processes when the windows close.

## Automated evidence

- Native staged import: exit 0.
- Real ENet multiprocess suite: **67/67 checks**, ALL_MULTIPLAYER_TESTS_PASS=true.
  Four scenarios: gameplay, player/server disconnect, time expiry/draw, unavailable server.
  Each multiplayer scenario uses one server plus two independent clients. The second
  client has a configured 100ms outbound control delay. All 10 process reports passed;
  runner also rejects engine/script errors in the logs.
- Gameplay: bounded server movement; stale input stops; finite/sequence rejection;
  token budget (lowered to 10/s, burst 5 only in the test fixture for a deterministic
  rate-limit probe); invalid requests leave HP/scores unchanged; range/arc misses;
  cooldown, self-hit exclusion, death/one-score, respawn, simultaneous attacks,
  score-limit win, replicated HUD result, post-match immutability.
- Failure paths: running-peer disconnect removes it and ends the match as a draw;
  remaining client receives the end, then reports server loss and clears replicas.
  A client without a listening server reports failure with no players.
- Local regressions: M1 movement 3/3, M2 combat 9/9, M3 match 44/44,
  player feedback/HP HUD 15/15 — **71/71**, ALL_TESTS_PASS=true, exit 0.
  Existing match suite emits one deliberate null-source warning; no unexpected errors.
- Rendered preview: two actual client processes, native Forward+ Vulkan on Intel UHD620,
  each captured successfully (error 0) and inspected. Correct local camera, blue/orange
  team meshes, owning-team status, HP bar, score and timer are visible in both views.
- Measured loopback application ping in staged gameplay: 7ms for both clients in the
  final run. This is local process scheduling/round-trip time, not a WAN benchmark;
  the injected 100ms control delay is recorded separately.

## Run commands

```powershell
python tests/run_multiplayer_smoke.py --godot 'C:\path\Godot_console.exe'
.\tools\start_multiplayer.ps1
```

Each automated run prints its temporary log directory and independent JSON reports.
The runner uses Python's standard library, binds local ports and cleans up its own
processes even on failure; it never terminates an existing editor or game instance.

## Limits and next acceptance

Owner two-window playtest is still required for actual multiplayer movement/combat feel,
health/readability, respawn, results and disconnect presentation. M4 remains open for
that acceptance; M5 has not started. No client prediction/interpolation/reconciliation,
lag compensation, public/LAN hosting, lobby/reconnect or 4v4. Unreliable control packets
may lose single-frame action edges under packet loss; packet loss/jitter was not emulated.
For another match, close both clients and rerun the launcher. See the M4 plan for details.

No commit or remote push was performed for this follow-up.

## Applied-project verification

Native project import exited 0. The same 67 real-process checks passed after applying
the changes to ArenaBattle, with no engine/script errors. Native gameplay RTT was 7ms
and 6ms for the two clients. git diff --check passed. Existing unrelated assets/models
were preserved.

Native local regressions also passed: movement 3, combat 9, match 44, feedback 15.
The feedback test initially sampled after a two-physics-frame wait and missed the 180ms
tint under concurrent process load; it now samples the visual callback at delta 0 before
expiry. All 15 assertions passed after this fixture-only correction. Total final
verification: 138 passing assertions. Launcher PowerShell parse: zero errors.
