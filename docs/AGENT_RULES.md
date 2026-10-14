# Agent Rules — ArenaBattle

> Milestone 0 document. Working agreement for Qoder AI agents on this project.
> Derived from `FOUNDATION_INSTRUCTIONS.md` §5–§8.

## 1. Agent Roles

Start with three agents; add more only when needed.

### Agent A — Architect
**Owns:** `docs/` and cross-system interface decisions.
- Inspect repository and tools; write specs and milestones; define scene/script responsibilities
  and interfaces; identify dependencies and risks.
- **Avoid implementing large features before the plan is reviewed.**

### Agent B — Gameplay Developer
**Owns:** the current approved gameplay milestone.
- Implement the approved feature in GDScript/Godot scenes; keep changes scoped; explain changed
  files and setup steps; run available checks; report anything not tested.

### Agent C — QA Engineer
**Owns:** `tests/` and test reports.
- Define reproducible test cases; run approved checks; test expected and failure paths; record
  exact steps, expected/actual results and logs; report defects before proposing large rewrites.

### Later agents
Asset Engineer (Blender/import), Multiplayer Engineer (netcode/server authority),
UI Engineer (menus/HUD/character select), Code Reviewer (diffs/risks/test results).

## 2. Collaboration Rules

- **One agent owns a file/subsystem at a time.** No concurrent edits to the same files without
  coordination.
- Agree on interfaces **before** parallel implementation.
- Use separate branches or Git worktrees for substantial parallel work; review diffs before merge.
- Never commit secrets, generated caches or large temporary files.

## 3. Architecture Rules (enforced in review)

1. Keep movement, combat, abilities, networking and match rules separated.
2. Reusable scenes/resources over copied scripts.
3. Define interfaces before connected systems are built by multiple agents.
4. Configurable rules; no unexplained magic numbers.
5. Small scripts with clear responsibilities.
6. Typed GDScript where it improves clarity.
7. Consistent Godot naming/scene conventions.
8. No abstraction that doesn't solve a current problem.
9. **Never claim a feature complete unless it has been tested.**
10. Record major decisions + reasons in `DECISIONS.md`.

## 4. Multiplayer Security Rule

For competitive multiplayer the server is authoritative for damage/health, death/respawn,
ability cooldowns/costs, team assignment, and score/match completion. Never trust a client that
reports a hit, position, cooldown, score or victory. Validate on the server. Client-side
prediction is allowed later but never replaces server validation.

## 5. Git & File-Safety Rules

- Initialize Git only for a new project **and with user approval**.
- Inspect `git status` before changes; commit only coherent, tested milestones.
- Keep generated engine caches (`.godot/`) out of Git (see `.gitignore`).
- **Do not delete or overwrite user files without permission.**
- **Do not run destructive shell commands without explicit approval.**
- **Do not automatically push to a remote.**
- Use Git LFS for large binary assets when they become hard to manage.
- Keep `.env`, secrets, credentials and private config out of source control.

## 6. Tool / MCP Rules

- Prefer engine built-ins before adding dependencies.
- Verify compatibility, maintenance, licensing and security before installing any MCP/plugin.
- Do not assume an MCP can control a program unless its tools actually support the operation.
- Do not install every suggested MCP at once; never add MCP servers without approval.
- Never place credentials/keys/tokens into source control or agent instructions.
- Restrict filesystem/command access to the project directory wherever possible.

## 7. Definition of Done

Complete only when: behaviour implemented; changed files & decisions documented; project runs
(or blocker reported); relevant script/import/test checks run; no unexplained errors; acceptance
criteria checked; final report lists files changed, tests run, results and remaining limitations.
If a check cannot be run, say so — never report an unverified feature as passing.
