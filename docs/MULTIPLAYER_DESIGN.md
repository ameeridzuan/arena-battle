# Multiplayer Design — ArenaBattle

> Milestone 0 design placeholder. **Networking is out of scope until the local gameplay loop
> (Milestone 3) is stable.** This document fixes the architecture direction early so gameplay
> code is written network-ready, without implementing it yet.

## 1. Model: Server-Authoritative

For competitive 4v4 play the **server is the single source of truth**. Clients send *intents*
(input requests); the server simulates, validates and broadcasts authoritative state.

## 2. Server-Authoritative Outcomes

The server — never a client — decides:
- Damage and health.
- Death and respawn.
- Ability cooldowns and resource costs.
- Team assignment.
- Score and match completion / victory.

**Never trust a client** that reports a hit, position, cooldown, score or victory. Validate
every client request server-side. Client-side prediction may be added later for responsiveness
but must never replace server validation.

## 3. Phased Networking Plan

| Phase | Milestone | Goal |
|-------|-----------|------|
| Local only | M1–M3 | Single-player movement, combat, gameplay loop. No netcode. |
| PoC (2 players) | M4 | Two clients join one match; sync spawning + minimal state; server validates damage/health/respawn/score. Handle disconnects & invalid requests. Measure latency. |
| 4v4 foundation | M5 | Enforce 8-player limit, two teams of four, team spawn points, match start/timer/score/end. Server determines the result. |
| Online readiness | M8 | Dedicated server, lobby/matchmaking, auth, monitoring, crash reporting, rate limits, abuse handling, network perf testing, security review. |

## 4. Godot Networking Notes (to re-research at M4)

- Godot 4 high-level multiplayer: `MultiplayerAPI`, `ENetMultiplayerPeer` (or WebSocket/WebRTC),
  `@rpc` annotations, `MultiplayerSpawner`, `MultiplayerSynchronizer`.
- **Re-verify the current Godot 4.x APIs before implementing** — they evolve between releases.
- Design scenes so ownership/authority is explicit (which peer owns which node).

## 5. Network-Ready Design Rules (apply from M1)

1. Keep authoritative game rules (damage, health, score, respawn) in dedicated components that
   can later run server-side, not scattered in the player controller.
2. Separate *input/intent* from *state mutation* so intents can be sent over the network.
3. Avoid client-only assumptions about who "owns" an outcome.
4. Prefer deterministic, config-driven values so server and clients agree.

## 6. Security & Anti-Cheat (from M4)

- Validate all incoming RPCs (range, cooldown, ownership, plausibility).
- Rate-limit actions; reject impossible positions/speeds.
- Never expose a local dev server publicly unless deliberately secured
  (`FOUNDATION_INSTRUCTIONS.md` §10.7).
- Keep credentials/tokens out of source control and agent instructions.

## 7. Open Questions

- Transport choice (ENet vs WebSocket vs WebRTC) — decide at M4.
- Hosting model for PoC (listen server on one client vs dedicated process).
- Tick rate and bandwidth budget — decide at M4/M5.
