# Decisions Log (ADR) — ArenaBattle

> Milestone 0 document. Records architecture decisions and reasons. Append new entries; do not
> rewrite history. Format: Context → Decision → Rationale → Status.

## Adopted Defaults (from `FOUNDATION_INSTRUCTIONS.md` §11)

| Area | Decision | Status |
|------|----------|--------|
| Camera | Third-person (spring-arm follow + mouse look) | Adopted |
| Visual style | Undecided — use simple placeholder shapes for the prototype | Provisional |
| Target platform | Windows PC first | Adopted |
| Engine | Godot 4.x stable | Adopted |
| Language | GDScript (typed where useful) | Adopted |
| Initial player count | One local player, then two networked | Adopted |
| Long-term match size | 4v4 (8 players) | Adopted |
| First map | One small bounded arena | Adopted |
| Initial roster | One placeholder character; add a second only after core combat works | Adopted |
| Networking | Server-authoritative for competitive play | Adopted |
| Public matchmaking | Out of scope for the foundation | Adopted |

---

## ADR-0001 — Project memory scope separated as `arena-battle`
- **Context:** This is a brand-new personal project, distinct from existing work scopes
  (`cbpfos`, `LOS-FOS`, `personal-mcp`) already stored in the personal-memory MCP.
- **Decision:** Store all durable facts/config/decisions for this game under a new MCP system
  scope `arena-battle`, so it never mixes with unrelated project memories.
- **Rationale:** User explicitly asked to differentiate this new project in MCP memory; prevents
  cross-project contamination of recalled context.
- **Status:** Adopted (2026-10-14). Two seed memories recorded: project intro + environment/tooling.

## ADR-0002 — Documentation-first foundation; no gameplay code before approval
- **Context:** Foundation instructions require presenting the plan and stopping before Milestone 1
  implementation is approved.
- **Decision:** At Milestone 0 create only `README.md`, `.gitignore` and `docs/*`. Do **not**
  create `project.godot`, scenes, scripts, run `git init`, install software, or add MCP servers
  until the user approves.
- **Rationale:** Respects the review gate and file-safety rules; avoids premature untested code.
- **Status:** Adopted.

## ADR-0003 — Folders created only when first needed
- **Context:** Instruction: "Do not create empty folders merely to make the tree look complete."
- **Decision:** Only `docs/` exists now. `scenes/`, `scripts/`, `assets/`, `resources/`, `tests/`
  and their subfolders are created at the milestone that first populates them (M1 creates the
  scene/script folders it uses). Git does not track empty directories anyway.
- **Rationale:** Follows the rule; keeps the tree honest and avoids `.gitkeep` clutter.
- **Status:** Adopted.

## ADR-0004 — Placeholder primitive meshes for the prototype
- **Context:** No Blender installed; art is not on the critical path for movement validation.
- **Decision:** Use Godot primitive meshes (capsule/box) for the M1 character and arena.
- **Rationale:** Lets movement/collision/camera be built and tested immediately; defers the art
  pipeline to M6.
- **Status:** Adopted.

## ADR-0005 — Damage interface defined early, implemented at M2
- **Context:** Combat, health and (later) server validation all need one consistent contract.
- **Decision:** Fix `apply_damage(amount, source)` / `get_health()` now; implement at Milestone 2.
- **Rationale:** Prevents rework and keeps authoritative rules separable for future networking.
- **Status:** Proposed (documented in TECHNICAL_ARCHITECTURE.md §6).

---

## Open Questions / Temporary Assumptions

| # | Item | Temporary assumption | Revisit by |
|---|------|----------------------|-----------|
| Q1 | Exact Godot 4.x version | Latest stable 4.x; pin once installed | Before M1 code |
| Q2 | Renderer (Forward+ vs Mobile) | Forward+ default on desktop | M1 |
| Q3 | Arena size | ~30m × 30m box | M1 tuning |
| Q4 | Melee vs ranged combat focus | Melee-first, undecided | Before M2 |
| Q5 | Match objective (TDM vs objective) | Team-deathmatch placeholder | Before M3/M5 |
| Q6 | Art direction / visual style | Placeholder shapes | M6 |
| Q7 | `FOUNDATION_INSTRUCTIONS.md` location | Left at project root (doc text refers to `docs/`); not moved without approval | On approval |
| Q8 | Git init timing | Deferred until user approves | On approval |

> None of Q1–Q8 block writing the Milestone 1 **plan**. Q1/Q2 must be resolved before M1 code is
> verified in-editor.
