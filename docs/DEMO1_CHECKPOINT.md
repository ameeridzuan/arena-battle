Current 23 October 2026 build: see [1v1 parkour build](ONEVONE_PARKOUR_BUILD.md).
The checkpoint below describes the earlier 17 October package.

# Demo 1 and continuation checkpoint — 2026-10-17

Demo 1 is a portable Windows x64 1v1 preview based on main `70dd88c` plus the
changes listed below. The packaged entry point is Demo1.tscn; normal F5/Main.tscn
is unchanged. Extract the ZIP and run Demo 1.exe alongside Demo 1.pck. No install.

## Implemented and verified in this continuation

- Host/Join menu, LAN address display, invalid-address feedback, return-to-menu,
  separate headless host server and cleanup of that child when the host closes.
- Multiplayer snapshot swings now emit the existing presentation signal, driving
  both authored character animation and swipe. Clients still cannot apply damage.
- Melee collision shapes are duplicated before per-instance range configuration.
- Nonfinite/nonpositive damage is ignored without changing attribution or signals;
  invalid replicated health values are ignored.
- Four garbled multiplayer status separators replaced with readable ASCII.
- Repeatable build helper `tools/build_demo1.py` exports in an isolated temporary
  project; it does not overwrite the source project's main scene or rendering settings.

Build example: `py tools/build_demo1.py --godot PATH_TO_GODOT_EXE --output OUTPUT_DIR`.
Matching export templates were unavailable, so the bundle uses the installed full
Godot executable as a portable runtime plus an exported PCK. Its engine metadata/icon
remain intact, and it is larger than a template release. Both engine MIT and third-party
license notices are included. Package contents exclude tests, docs, Blender sources,
Git metadata and credentials. See Godot's official license guide:
https://docs.godotengine.org/en/stable/about/complying_with_licenses.html

## Verification

Godot 4.7.2 native Windows. Fresh isolated import and PCK export passed.
258 assertions passed: 103 existing local, 20 new hardening, 67 two-client and 68
eight-client checks. New coverage exercises actual snapshot presentation handling,
attack clip cycling, duplicate/stale/dead snapshot suppression, shape independence,
invalid damage/health, signal counts and kill attribution. Snapshot fixtures are
explicitly distinct from the real-process network suites.

The actual packaged EXE launched by implicit sibling-PCK discovery. A packaged host
spawned its own background server and a second packaged executable joined; both
reported a running two-player match. Host shutdown removed its server process.
The menu was rendered and inspected at 1280x720. No physical second-PC, real LAN,
human combat-feel or FPS acceptance is claimed.

## Current status and remaining work

Saved memory previously stopped at M5; current code has M6 character integration and
partial M7 content. The assessment PROGRESS_ASSESSMENT_M7.md records an approved
hardening plan, but several body sections still call it proposed. Treat its findings
as a backlog, not evidence that fixes or manual acceptance already happened.

M5 is automatically verified; its human 4v4 acceptance remains unrecorded. M6 imports
and animation are verified; visual/performance acceptance remains pending. M7 is
PARTIAL, not complete: two models/animation exist, but abilities, selection, audio,
authored VFX and arena art remain deferred. Demo packaging does not close those gates.

Continue M7.1: finish animation resource isolation (import-time loop configuration),
then stable/idempotent model swaps and feedback/animation rebinding, death/respawn
presentation cleanup, approved Option B authoritative attack timing, measured asset
budgets and headless presentation stripping. The small fixes above are an initial
batch, not completion of the whole M7.1 plan. Current Demo 1 preserves instant-hit
combat timing; approved windup/active/recovery is not yet implemented.

After M7.1 acceptance: M7.2 replicated character identity/selection; M7.3 abilities,
audio/effects/arena art; interpolation/prediction separately before online readiness.
Current character mapping is viewer-relative: self Arclight, others Ashen Warden.

Assessment corrections: retain eight ENet client slots for eight players because the
dedicated server is separate. The suggested required_players-1 would cap 4v4 at seven.
Use .gitattributes, not asset exclusions in .gitignore, if adopting Git LFS. Import-time
loop settings prevent runtime mutation by convention, not by making shared resources
intrinsically immutable. Keep measured budget failures visible until assets improve.

No commits, pushes, firewall changes or public deployment were performed. Existing
untracked assessment/helper documents were preserved. This file supersedes stale
"Immediate Next Steps" text and old memory where they disagree about current status.
