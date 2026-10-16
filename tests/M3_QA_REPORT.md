# Milestone 3 QA report

Date: 2026-10-16 (Asia/Kuala_Lumpur). Role: QA Engineer.

## Reproduction

Engine verified: `4.7.2.stable.official.ed1daf0bf`.

```powershell
$console = 'C:\Users\ameer.noorfizan\Documents\BE Development\SourceCode\Qoder_Personal\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe'
$project = 'C:\Users\ameer.noorfizan\Documents\BE Development\SourceCode\Qoder_Personal\game_test\ArenaBattle'
& $console --headless --path $project --import
1..2 | ForEach-Object {
    & $console --headless --path $project --script res://tests/integration/movement_smoke_test.gd
    & $console --headless --path $project --script res://tests/integration/combat_smoke_test.gd
    & $console --headless --path $project --script res://tests/integration/match_smoke_test.gd
}
& $console --headless --path $project --quit-after 120
```

Run these against the native project path. The sandboxed Godot runtime could not access its editor data directory; final validation runs use approved native execution. No project runtime or user-wide environment configuration was changed to bypass the issue.

## Final execution evidence

**PASS — automated M3 acceptance and M1/M2 regression gates.** Final native execution was performed by the coordinating agent; QA independently inspected every final log. All exit codes below were captured by the coordinating runner.

| Check | Run 1 | Run 2 | Evidence |
|---|---|---|---|
| Import (`--import`) | Exit 0 | Not repeated | No errors or warnings |
| Movement | Exit 0; 3/3 checks | Exit 0; 3/3 checks | `ALL_TESTS_PASS=true` both runs |
| Combat | Exit 0; 9/9 checks | Exit 0; 9/9 checks | `ALL_TESTS_PASS=true` both runs |
| Match | Exit 0; 44/44 checks | Exit 0; 44/44 checks | `ALL_TESTS_PASS=true` both runs |
| Authored main scene (`--quit-after 120`) | Exit 0 | Not repeated | No errors or warnings |

No `SCRIPT ERROR:` or `ERROR:` appeared in any final log. Each match run emitted exactly one expected warning: `[Combatant] Opponent1: died with no damage source — kill not attributed, no score awarded.` Movement/combat/import/smoke logs had no warnings.

Final logs (local session evidence, not committed engine caches):
`C:\Users\ameer.noorfizan\Documents\Codex\2026-10-16\can-you-check-in-both-memory\work\m3-verified\`
with `import.log`, `movement-1.log`, `combat-1.log`, `match-1.log`, `movement-2.log`, `combat-2.log`, `match-2.log`, and `smoke.log`.

Automated results were deterministic across both complete passes. Visual/manual acceptance remains open as listed below; this report does not declare those criteria complete.

## Acceptance mapping

| Spec cases / criteria | Automated assertions |
|---|---|
| Case 1 / AC-M3-1 | Initial WAITING state; deferred start emits exactly once; RUNNING with positive countdown; authored tunable defaults |
| Case 2 / AC-M3-2 | Lethal opponent damage awards TEAM_A exactly one point and emits the correct score tuple |
| Case 3 / AC-M3-3/4 | Authored opponent auto-attack through physics overlap damages and then kills the player; TEAM_B score and player_died signal verified |
| Case 4 / AC-M3-5/6 | Player dead state disables collision, mesh, body physics and attack physics; no early respawn; default 3-second respawn restores health, spawn position and processing |
| Case 5 / AC-M3-7 | Both opponents disable and respawn at their distinct team-B spawn indices with maximum health |
| Case 6 / AC-M3-8 | Both teams end the match precisely at an overridden score limit of two, with the matching winner signal |
| Case 7 / AC-M3-9 | One-second test countdown ends with TEAM_A, TEAM_B or draw as appropriate |
| Case 8 / AC-M3-10 | Scoring stops after end; queued respawn, winning-kill respawn and post-match death do not respawn |
| Supplementary S1 | Null source produces death and respawn without any score or player_died event |
| Supplementary S2 / AC-M3-15 | Separate M2 combat regression command in the same validation session |
| AC-M3-16 | Separate M1 movement regression command in the same validation session |
| AC-M3-17 | Editor import, all suite logs, native scene smoke, and exit codes checked for script/engine errors |
| HUD supplementary | Initial labels, score update, both score-limit winner labels, three timed result labels and terminal clock text |
| Additional TDM guard | Same-team, negative-team and unknown-team requests produce no score, player_died or match_ended signal |
| Additional authored scene check | Both static opponents face the arena center within a dot-product tolerance of 0.999 |

Each M3 case uses a fresh authored Main scene. Scene setup, overlap settlement and teardown await bounded physics frames. Tests exercise real auto-attacks with the authored cooldown, and both player and opponent respawn tests retain the default 3-second delay. Shortened timer/respawn settings are confined to targeted match-end and null-source cases. The M2 suite retains its runtime input-lag calibration and physical self-exclusion checks.

## Defects resolved during this checkpoint

- **DEF-M3-01: invalid/friendly kill requests were accepted.** Reproduce by calling `register_kill(0, 0)` or `register_kill(0, -1)` during RUNNING. Expected: no score or signals. Before fix: TEAM_A point awarded. Gameplay added a guard requiring distinct valid teams; QA asserts both teams' invalid combinations leave all state/events unchanged.
- **Authored facing regression guard:** original scene transforms are retained. QA checks actual global basis vectors against the direction to the arena center. The targeted run measured alignment dot products of 1.000000119 and 1.0, passing the unchanged 0.999 threshold.
- The requested M2 testbed cleanup and removal of the obsolete `player_not_damageable` condition were already present on disk and were preserved. QA also corrected stale diagnostic text claiming no distance gate or health reset existed; all layer/mask exclusion assertions remain.

## Not verified

- **AC-M3-11/12 visual acceptance remains pending:** rendered HUD placement/readability and result appearance require a display playtest. Headless label content/state assertions do not verify layout.
- Manual movement/camera feel and combat feel; M2 red hit-flash appearance remain pending human/display verification.
- AC-M3-13/14 architectural review is owned by Architect/Gameplay, separate from runtime results.
- Restarting an ended match in-place is outside the approved single-match acceptance cases and is not verified; Combatant retains its match-over state.
- No networking, asset pipeline or later milestone is claimed tested.

The null-source test intentionally emits the documented no-source/no-score warning; any unrelated error or warning must be investigated rather than hidden behind a zero exit code.
