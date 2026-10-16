# M5 QA report — 2026-10-16

Godot 4.7.2.stable.official.ed1daf0bf, native Windows headless processes.

| Suite | Result |
|---|---|
| Eight clients + server + ninth-client rejection probe | 68 checks passed, exit 0 |
| Existing two-client gameplay/disconnect/timeout/unavailable | 67 checks passed, exit 0 |
| Local movement / combat / match / player feedback | 3 / 9 / 44 / 15 passed, all exit 0 |
| Total | 206 checks passed |

Import check passed. Network runners reject engine/script ERROR logs. The known
local match null-source warning is intentional negative-path coverage.

Commands from the project folder (substitute the installed Godot console path):

```powershell
py tests/run_eight_player_smoke.py --godot GODOT_CONSOLE_PATH
py tests/run_multiplayer_smoke.py --godot GODOT_CONSOLE_PATH
```

Each local suite uses Godot `--headless --path . --script res://tests/integration/NAME.gd`.

Eight-client evidence: ArenaBattle-M5-QA-jh6ljvx8 in the Windows temp folder.
Final two-client evidence: ArenaBattle-M4-QA-8nvcu142 in the same temp folder.

## Coverage

Seven registered clients do not start; the eighth starts. Server and all eight
clients agree on four players per team. Eight distinct team slots and separated
spawn positions. Ninth connection rejected without changing the running roster.
Each client binds its own HP HUD and receives the authoritative result. Real client
RPC attacks demonstrate friendly-fire protection, enemy damage, kill scoring,
death, assigned-slot respawn, and score-limit result; post-match scores stay fixed.
The existing two-client suite also covers invalid/replayed inputs, rate limits,
range/arc/cooldown, delayed controls, stale-input stop, simultaneous attacks,
disconnects, server loss, unavailable server and timer draws.

Fixture overrides: the server positions players, shortens one respawn to 1.2 seconds
and the score target to two. These are test-only; attacks still arrive over real RPCs.

## Issues found and resolved

- Eight-player dictionary snapshots exceeded the ENet MTU warning threshold. Compact
  positional wire records removed the warning in the final run.
- Test teleports reused a teammate's old physics position too quickly, causing the
  enemy to be carried away. Separate parked positions and a physics-settling interval
  fixed the fixture. This was not treated as passing gameplay evidence before correction.
- Early clients exiting after the done marker removed peers before slower clients
  checked roster size. Check the full roster during the result stage instead.

## Acceptance still required

Human eight-window or distributed LAN playtest: readable team colors, controls,
combat feedback, HP HUD, respawn presentation and result. No physical multi-PC test
was performed by this agent. M6 visual integration needs another regression pass.

## Git state

Owner created commit 459b0ec during this task. Despite its M3/M4 title it includes
the in-progress M5 implementation and initial eight-player tests. History was not
rewritten. Final test corrections and M5 documentation are subsequent working-tree
changes; this agent did not commit or push. Unrelated M6 assets/tests were preserved.
