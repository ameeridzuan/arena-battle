# M3 follow-up — player feedback and health HUD

Approved by the owner on 2026-10-16: add basic player hit visualization before M4 and
check/add a health bar. The existing roadmap had no explicit health bar requirement.

## Changes

- PlayerFeedback presentation component: cyan camera-directed melee arc and red hurt flash.
- AttackHitbox emits `attack_started(forward)` once per accepted swing, including misses.
- HUD: anchored player HP bar/current-max text and a brief non-interactive damage tint.
- Death displays zero HP; respawn restores HP and clears transient feedback.
- Roadmap/architecture/README document the M3 extension and later M6/M7 polish.

## Verification — Godot 4.7.2.stable.official.ed1daf0bf, 2026-10-16

Native editor import: exit 0. `player_feedback_smoke_test.gd`: 15/15 checks, exit 0.
The test covers initial state, a missed swing, camera alignment, cooldown rejection,
damage-to-HUD/material/tint, effect expiry, unchanged-health notification, lethal damage,
respawn restoration and a non-default maximum of 150 HP.

M1 movement: 3/3 checks; M2 combat: 9/9 checks. Both ALL_TESTS_PASS=true, exit 0.
M3 match: 44/44 checks, ALL_TESTS_PASS=true, exit 0 after restoring the missing
Opponent2 `Combatant.spawn_index = 1` override in the existing edited Main.tscn.
The initial match run exposed that pre-existing scene issue: both opponents used spawn
index 0. Other existing editor metadata in Main.tscn was preserved. The null-source
attribution warning is intentional in the existing negative-path match test.

A native Forward+ Vulkan render was captured and inspected: the lower-left health bar
shows 80/100 with the expected fill, the player flashes red, and the cyan arc is visible.
The capture temporarily lengthened effect durations only in an external preview script;
the project defaults remain 0.18 seconds. Render check exited 0 with no errors.

Run the new test with the same console binary and project path used by M3_QA_REPORT.md:

```powershell
& $console --headless --path $project --script res://tests/integration/player_feedback_smoke_test.gd
```

## Remaining acceptance

Owner subsequently reported “all works well” on 2026-10-16 and authorized the next
task. M3 and this feedback/HP HUD follow-up are manually accepted. M4 is now implemented;
its separate two-client manual acceptance remains pending. Polished animation and effects remain M6/M7.
Changes are left for review; no commit or push was performed for this follow-up.
