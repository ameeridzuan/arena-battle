# Agent Team Plan — ArenaBattle

> **Owner:** Business Owner (you) with the AI acting as Business Owner / Business Analyst.
> **Purpose:** Recruit, evaluate and organize the AI-agent team that will plan and build the game.
> **Rule respected:** `FOUNDATION_INSTRUCTIONS.md` §6 — *"Start with three agents. Add more only when
> the project needs them."* This document evaluates **all** candidates but **hires only the core now**,
> staging specialists against the roadmap.
> Complements [`AGENT_RULES.md`](AGENT_RULES.md) (roles/ownership) — this file adds recruitment,
> evaluation, governance, RACI, risks and KPIs.

---

## 1. Business Context & Objective

- **Product:** 3D third-person 4v4 battle arena (Godot 4.7.2 + GDScript), Windows-first, server-authoritative.
- **Current state (2026-10-16):** M1 movement and M2 combat are implemented; approved M3 local
  gameplay loop and feedback/HP follow-up were accepted by the owner on 2026-10-16.
  M4 multiplayer PoC is automatically verified; owner multiplayer acceptance gates M5.
  Later: M5 4v4, M6 art, M7 content, M8 online.
- **Objective of the team:** deliver each milestone to its acceptance criteria with clean separation of
  concerns, verified quality, and no premature/untested complexity.
- **Constraints:** solo developer + AI agents; lean coordination overhead; strict file-safety & security rules;
  "no feature is done unless tested."

**Business-analyst framing:** the "stakeholders" are You (product owner), the AI agents (delivery), and the
future players. Value is delivered milestone-by-milestone; the team must scale *just-in-time*, not up-front.

---

## 2. Recruitment — Candidate Roster

Twelve candidates were identified from `FOUNDATION_INSTRUCTIONS.md` §6 plus gap analysis against the roadmap.

| ID | Candidate | Mission (one line) | Primary demand |
|----|-----------|--------------------|----------------|
| C1 | **Architect** | Own `docs/`, interfaces, cross-system decisions | M0–M8 (all) |
| C2 | **Gameplay Developer** | Implement the approved milestone in GDScript/scenes | M1–M7 |
| C3 | **QA Engineer** | Own `tests/`, reproducible cases, verify or reject | M1–M8 (all) |
| C4 | Combat/Systems Designer | Design attack/damage/ability balance & rules | M2–M7 |
| C5 | Code Reviewer | Review diffs, risks, test evidence before merge | M2+ (grows) |
| C6 | Multiplayer/Network Engineer | Server-authoritative netcode, replication, RPC validation | M4–M5, M8 |
| C7 | Security/Anti-cheat Specialist | Threat model, server validation, abuse/rate limits | M4, M8 |
| C8 | Asset Engineer (Blender) | Model/rig/export GLB, import pipeline & conventions | M6–M7 |
| C9 | Technical Artist | Shaders, VFX, performance/visual quality | M6–M8 |
| C10 | UI Engineer | Menus, HUD, character select, lobby | M3, M7 |
| C11 | Audio Engineer | SFX/music hooks, mixing | M7 |
| C12 | DevOps/Release Engineer | Export builds, dedicated-server deploy, monitoring, CI | M8 |

> **Producer/Coordinator** is intentionally **not** a separate agent — that hat is worn by **You (Business
> Owner) + the Architect** to avoid overhead on a solo project.

---

## 3. Evaluation Framework

Weighted scoring, 1 (low) – 5 (high). Decision thresholds applied to the weighted total.

| Criterion | Weight | Meaning |
|-----------|--------|---------|
| Milestone criticality | 30% | On the critical path for the **next** milestones? |
| Unblocking/dependency | 20% | Does other work stall without this role? |
| Risk if absent | 20% | Quality/security/schedule exposure if unstaffed |
| Low operating cost | 15% | Coordination overhead (5 = cheap, 1 = heavy) |
| Reusability | 15% | Stays useful across many milestones |

**Thresholds:** **≥ 4.0 → Hire now (Core)** · **3.0–3.9 → Stage at its milestone** · **< 3.0 → Defer / merge into another role.**

### Scoring matrix

| ID | Candidate | Crit (30%) | Unblock (20%) | Risk (20%) | Cost (15%) | Reuse (15%) | **Weighted** | Decision |
|----|-----------|:--:|:--:|:--:|:--:|:--:|:--:|----------|
| C1 | Architect | 5 | 5 | 5 | 4 | 5 | **4.85** | ✅ Hire now |
| C2 | Gameplay Developer | 5 | 5 | 4 | 4 | 5 | **4.65** | ✅ Hire now |
| C3 | QA Engineer | 4 | 4 | 5 | 4 | 5 | **4.35** | ✅ Hire now |
| C5 | Code Reviewer | 3 | 3 | 4 | 4 | 5 | **3.65** | 🕓 Stage (M2/M3) |
| C4 | Combat/Systems Designer | 3 | 3 | 3 | 4 | 4 | **3.30** | 🕓 Stage (M2) — merged for now |
| C6 | Multiplayer Engineer | 2 | 2 | 5 | 3 | 3 | **2.90** | ⏸ Defer to M4 (advisory at M3) |
| C7 | Security/Anti-cheat | 2 | 2 | 5 | 3 | 2 | **2.65** | ⏸ Defer to M4/M8 (rules embedded now) |
| C12| DevOps/Release | 1 | 1 | 4 | 3 | 2 | **2.05** | ⏸ Defer to M8 |
| C8 | Asset Engineer | 1 | 2 | 3 | 2 | 3 | **2.05** | ⏸ Defer to M6 (Blender not installed) |
| C10| UI Engineer | 1 | 2 | 2 | 4 | 3 | **2.15** | ⏸ Defer to M7 (light HUD at M3) |
| C9 | Technical Artist | 1 | 2 | 2 | 2 | 3 | **1.85** | ⏸ Defer / merge into C8 |
| C11| Audio Engineer | 1 | 1 | 1 | 3 | 2 | **1.45** | ⏸ Defer to M7 |

*Worked example (C1):* 0.30·5 + 0.20·5 + 0.20·5 + 0.15·4 + 0.15·5 = 1.5 + 1.0 + 1.0 + 0.6 + 0.75 = **4.85**.

---

## 4. Selection Decision — Phased Hiring Plan

**Hire now (Core Team = 3):** Architect (C1), Gameplay Developer (C2), QA Engineer (C3).
This exactly matches the foundation rule and covers the next milestones (M2 combat, M3 loop) without sprawl.

| Milestone | Activate / add | Notes |
|-----------|----------------|-------|
| **Now (M1→M2)** | C1, C2, C3 | Combat design (C4) is a **shared hat** (Architect defines the `apply_damage` interface + rules; Gameplay implements; QA verifies). Code review (C5) performed by Architect. |
| **M3 (loop)** | + C5 Code Reviewer (light) | Introduce a distinct reviewer once multiple subsystems (movement/combat/match) coexist. Light HUD by C2. |
| **M4 (multiplayer PoC)** | + C6, + C7 (advisory) | Server-authoritative work is security-critical — staff a dedicated engineer; security rules already embedded in `MULTIPLAYER_DESIGN.md`. |
| **M5 (4v4)** | C6 continues | Match rules, teams, server-determined result. |
| **M6 (art pipeline)** | + C8 (Asset Engineer), C9 hat | Requires **Blender install** (currently absent). |
| **M7 (content)** | + C10 UI, + C11 Audio | Character select, HUD, sound/VFX. |
| **M8 (online)** | + C12 DevOps/Release, C7 hardening | Dedicated server, matchmaking, monitoring, security review. |

**Just-in-time principle:** a specialist is activated at the milestone that first needs it — never earlier
(avoid idle complexity), never later (avoid blocking).

---

## 5. Org Chart & Reporting

```text
Business Owner (You)  ── product vision, approvals, priority, "hire" gates
        │
        ▼
   Architect (C1)  ── technical lead; owns docs/ + interfaces; wears Producer & Code-Review hats early
        │
        ├── Gameplay Developer (C2)  ── owns the current approved milestone's scenes/scripts
        ├── QA Engineer (C3)         ── owns tests/ + verification evidence
        │
        └── (staged specialists report through Architect when activated)
              C5 Reviewer · C4 Combat Design · C6 Network · C7 Security · C8 Asset · C9 TechArt · C10 UI · C11 Audio · C12 DevOps
```

---

## 6. RACI Matrix (key activities)

R=Responsible, A=Accountable, C=Consulted, I=Informed

| Activity | Business Owner | Architect | Gameplay Dev | QA | Staged specialist |
|----------|:--:|:--:|:--:|:--:|:--:|
| Milestone scope & acceptance | A | R | C | C | I |
| Interfaces / architecture decisions | I | A/R | C | C | C (relevant one) |
| Implement milestone code | I | C | A/R | I | R (own domain) |
| Verification & test evidence | I | C | C | A/R | C |
| Code review before merge | I | A/R (→C5 later) | C | C | R (C5) |
| Multiplayer security model | I | A | C | C | R (C6/C7) |
| Git commits / push | A (push approval) | R | R | I | R |
| "Hire" a new agent | A | R/C | I | I | — |

---

## 7. Collaboration & Governance Workflow

1. **Single ownership:** one agent owns a file/subsystem at a time (see `AGENT_RULES.md` §2). No concurrent
   edits without coordination; use branches/worktrees for parallel work.
2. **Interfaces first:** Architect defines contracts (e.g. `apply_damage`) before parallel implementation.
3. **Gate per milestone:** plan → approve → implement → QA verify (evidence) → review → commit → (push only
   with Business Owner approval).
4. **Definition of Done:** behaviour implemented **and tested**, docs/decisions updated, project runs, no
   unexplained errors, acceptance criteria checked, final report filed.
5. **Memory discipline:** consult/recall `arena-battle` scope before work; record decisions, facts and mistakes after.
6. **Security:** never commit secrets/tokens; server authoritative for all competitive outcomes.

---

## 8. Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|-----------|
| Agent sprawl / over-engineering | High cost, slow | Lean core of 3; just-in-time staging; weighted evaluation gates |
| Concurrent-edit conflicts | Broken builds | Ownership map; branches; review before merge |
| Unverified "done" claims | False confidence | QA owns evidence; headless tests; DoD checklist |
| Multiplayer security gaps (M4) | Cheating, unfair play | Dedicated C6 + C7; server-authoritative rule; RPC validation |
| Art pipeline blocked (no Blender) | M6 delay | Defer C8 to M6; install Blender only when needed |
| Knowledge silos across agents | Rework | `docs/` + ADR log + `arena-battle` memory scope |
| Solo-owner bottleneck on approvals | Slow cadence | Batch approvals per milestone; clear acceptance criteria |

---

## 9. KPIs / Success Metrics

- **Milestone acceptance pass rate** (target 100% per gate).
- **Defect escape rate** — issues found after a milestone is marked done (target ↓).
- **Acceptance-criteria automated coverage** — % of criteria with a headless/repeatable test (M1: 3/5 automated).
- **Rework rate** — commits revising just-merged work (target ↓).
- **Docs/decision currency** — every milestone has an updated ADR + roadmap entry.
- **Safety** — zero secrets committed; zero unapproved pushes/installs/destructive ops.

---

## 10. Recommendation & Next Actions

**Recommendation (Business Owner decision):** Adopt the **Core Team of three (Architect, Gameplay Developer,
QA Engineer) now**, with the staged activation plan in §4. Do **not** instantiate the deferred specialists yet.

**Codex session (2026-10-16):** The owner requested use of the existing agents and continuation
from the latest checkpoint. The role definitions in the parent `game_test/.qoder/agents/`
folder (`architect.md`, `gameplay-developer.md` and `qa-engineer.md`) were loaded into three Codex subagents, preserving
their existing responsibilities. Architect owns docs, Gameplay owns scenes/scripts and targeted
fixes, and QA owns tests/evidence. No model defaults or persistent agent configuration were changed.

**Current next actions:** owner accepted M3 and authorized M4. Playtest the verified
M4 two-client scene with tools/start_multiplayer.ps1. Start M5 only after M4 acceptance. Push requires
the owner's separate authorization.

### M4 checkpoint — 2026-10-16

Owner accepted M3 + basic feedback/HP HUD and authorized the next task. M4 now implements
a separate local ENet server/two-client scene. Interfaces and QA are in M4_MULTIPLAYER_PLAN.md;
manual multiplayer acceptance gates M5. No remote push is authorized by this checkpoint.
