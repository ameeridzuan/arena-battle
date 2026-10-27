# Character motion course

Open `scenes/characters/MotionTestCourse.tscn` in Godot and press **F6**.
This standalone local laboratory reuses the current player and motion harness.
The normal F5 match and multiplayer scenes are unchanged.

Use **1–6** to teleport to a selected zone and **Backspace** to reset to it.
Falling out of the course also returns to the selected zone. These shortcuts
are active while the mouse is captured; Esc toggles capture.

| Key | Zone | Purpose |
| --- | --- | --- |
| 1 | Hub | Orientation and controls |
| 2 | Movement pad | 16 m runway, starts/stops, turns, strafing, directional dodge/dash |
| 3 | Jump gaps | 0.65 m platforms separated by 0.75, 1.5, 2.25 m; recovery floor below |
| 4 | Steps/slopes | 15/30/40 cm stair flights and 15/30 degree ramps |
| 5 | Ledges | Independent 0.6, 1.2, 1.8, 2.4, 3.2 m surfaces with marked lips |
| 6 | Wall lanes | 6 m high walls; 1.5, 2.5, 4 m clear widths |

WASD moves, Shift runs, Space jumps. Q with a direction dashes/dodges;
V toggles aim, R casts, F parries, Tab switches character. The course has no
enemies or match timer, so parry is a pose test here and casting is cosmetic.
Telemetry shows horizontal/vertical speed, feet height and grounded state.
The camera shortens against world geometry to help inspect narrow lanes.

Automatic stepping, ledge grabbing/mantling, wall sliding and wall jumping are
now available. E grabs/climbs; Space climbs from a hang or jumps away from a wall;
C drops. See [adaptive traversal behavior and controls](ADAPTIVE_TRAVERSAL.md).
Geometry is built by `scripts/characters/motion_test_course.gd` on scene launch.
World units are metres; the character capsule is 2 m tall and 1 m wide.
Future collision queries can use world layer 1 and the `motion_test_ledge` /
`motion_test_wall` groups; metadata records ledge heights and lane clearances.

Headless validation:

```powershell
& $godotBinary --headless --path . --script res://tests/integration/motion_course_smoke_test.gd
```

Manual acceptance: visit each zone, switch both characters, try running jumps
and directional dodges, inspect ramp landings and wall camera clearance, then
reset from an elevated surface. Visual quality and movement feel require playtesting.

Validation on 2026-10-21: Godot 4.7.2 headless course smoke test returned
`ALL_TESTS_PASS=true`, exit 0. It covers all six spawns, jump/landing, fall
recovery, ledge collision heights and solid wall travel blocking.
