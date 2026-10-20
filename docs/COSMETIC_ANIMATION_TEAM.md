# Cosmetic and animation team — 2026-10-19

Activated at the owner's request for an animation-first plan. This charter adds a
focused delivery team to AGENT_TEAM.md; it does not remove gameplay/network owners.
Planning reviews completed in this session; these are not persistent background jobs.

| Role | Planning reviewer | Owns |
|---|---|---|
| Cosmetic Lead / Coordinator | Primary agent | Consolidated plan, priorities, contracts, roadmap and handoffs |
| Animation Direction & Asset Lead | review agent | Rig/asset audit, silhouettes, movement/action clips, Blender/export plan |
| Technical Animation & Combat Integration Lead | animation_systems agent | Layers, transitions, aim mode, action phases, authority/replication dependencies |
| Animation QA & Readability Lead | qa agent | Visible-model acceptance, interruptions, local/remote checks and performance evidence |

## Hit-Reaction & Knockback Animation Specialist

Added at the owner's request, with the review-agent role assigned directional hit recoil, knockback travel/recovery, wall/air/repeated-impact reactions, defense interruption and death priority for both rigs. The specialist agents hit their usage limit before completing this implementation batch; the primary agent implemented and validated the foundation. They are not running background jobs. Reaction clips remain the next authoring work, not a completed feature.

## Mandate

Make movement and combat readable and smooth for Arclight and Ashen Warden before
adding cosmetic effects. Cover idle/walk/run/turn/strafe/jump/fall/land, melee,
locked-view magic/energy projectiles, per-character skills, parry, dash, block, directional knockback on being attacked, reactions and lifecycle.
The authoritative scope and coverage matrix are in CHARACTER_ANIMATION_PLAN.md.

The technical lead designs gameplay/network interfaces with their existing owners;
the cosmetic team cannot award damage, defense success or dash immunity from clips.
No mechanic becomes implemented merely because its preview animation exists.

## Delivery rules

1. Lead assigns one owner per shared file. Parallel implementation uses isolated
   branches/worktrees and explicit handoff; no blind overwrites of existing work.
2. Assets deliver a semantic clip manifest plus rig masks, sockets and before/after
   previews. Technical integration preserves player node contracts and both rigs.
3. QA inspects actual visible models, both view modes, owning and observing clients;
   headless assertions supplement visual review rather than replace it.
4. Lead records proposed vs implemented vs tested vs owner-accepted separately.
5. Magic/energy projectiles are the owner-selected ranged style. New keybindings,
   specific spell/skill design and balance remain explicit design decisions.
   Existing V view-toggle is retained. Ranged requests require lock/aim mode.
6. The owner subsequently authorized implementation. The first batch changes animation presentation and adds a review scene; new mechanics remain separate. No commits or pushes were requested.

## First work package

A0 baseline and clip/rig audit, then A1 polished locomotion review gallery for both
characters. A2 adds aim/strafe, A3 melee/lifecycle, A4 future-action animation blockouts,
A5 server/gameplay integration and A6 final polish/performance. See the plan for gates.

The earlier team document's M1/M2 staffing dates and 'Blender absent' statements are
historical. Current project already includes Blender-authored models and partial M7.
This charter is the current cosmetic-team assignment; it makes no new tool-install claim.


## 20 October2026 directional animation delivery

The directional_research specialist verified human capture sources and timing guidance. The directional_review specialist reviewed integration and found the diagonal cap/clip mismatch; the primary agent fixed it using shared direction sectors and added regression cases. The primary agent implemented and validated the nine new motions per rig. These assignments completed for this batch; they are not persistent background jobs. See OTHER_ANIMATION_CHECKPOINT.md.
