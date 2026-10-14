# 3D 4v4 Battle Arena — Foundation Instructions

> Purpose: Give Qoder and its AI agents a clear, incremental plan for establishing the foundation of a 3D multiplayer arena game.
>
> Initial technical direction: **Godot 4.x + GDScript + Blender + Git**. Confirm the installed stable Godot version before implementation. Keep the architecture simple until the first playable prototype works.

---

## 1. Project Vision

Build a third-person 3D platform/action battle arena in which **two teams of four players** compete in the same arena.

The long-term game may include:
- Multiple playable characters with distinct roles and abilities.
- Melee and/or ranged combat.
- Jumping, dodging, platforms and arena hazards.
- Team assignment, respawning, scoring and victory conditions.
- Online multiplayer with server-authoritative gameplay.
- Character selection, lobby, HUD, audio, visual effects and multiple arenas.

**Do not build all of these at once.** Establish a small, testable foundation first.

### Initial prototype scope

The first milestone must contain only:
1. A Godot project that opens and runs.
2. One simple 3D arena with a floor, walls or boundaries, lighting and a camera.
3. One controllable placeholder character.
4. Walking, running, jumping and gravity.
5. Basic collision with the arena.
6. A simple attack against a dummy target, only after movement works.
7. A README explaining how to run and test the project.

Use primitive meshes or a simple placeholder model initially. Do not delay progress while creating polished characters.

---

## 2. Technical Stack

### Required initially
- **Game engine:** Godot 4.x stable release.
- **Gameplay language:** GDScript.
- **3D creation:** Blender.
- **Asset interchange:** glTF 2.0 / GLB.
- **Version control:** Git.
- **AI development environment:** Qoder.
- **Documentation:** Markdown files in `docs/`.

### Add later, only when needed
- Blender MCP for controlled Blender automation.
- Context7 MCP or official documentation lookup for API research.
- GitHub MCP if repository and issue automation is useful.
- A Godot MCP integration, if a suitable and trustworthy implementation is available; otherwise create a small, restricted local integration for approved project checks.
- Automated test framework or project-specific test scripts.
- Dedicated game server and matchmaking infrastructure.

### Tool-selection rules
1. Prefer the engine's built-in capabilities before adding dependencies.
2. Verify compatibility, maintenance status, licensing and security before installing an MCP server or plugin.
3. Do not assume an MCP server can control a program unless its actual tools support the required operation.
4. Do not install every suggested MCP server at once.
5. Never put credentials, API keys, passwords or tokens into source control or agent instructions.
6. Restrict filesystem and command-execution access to the project wherever possible.

---

## 3. Required Repository Structure

Use this as a starting point. Adjust only when there is a clear technical reason.

```text
arena-battle/
├── project.godot
├── README.md
├── .gitignore
├── docs/
│   ├── GAME_DESIGN.md
│   ├── TECHNICAL_ARCHITECTURE.md
│   ├── MULTIPLAYER_DESIGN.md
│   ├── DEVELOPMENT_ROADMAP.md
│   ├── AGENT_RULES.md
│   └── DECISIONS.md
├── assets/
│   ├── characters/
│   ├── weapons/
│   ├── animations/
│   ├── environments/
│   ├── materials/
│   ├── textures/
│   ├── audio/
│   └── vfx/
├── scenes/
│   ├── main/
│   ├── arena/
│   ├── characters/
│   ├── targets/
│   └── ui/
├── scripts/
│   ├── core/
│   ├── player/
│   ├── combat/
│   ├── abilities/
│   ├── multiplayer/
│   ├── match/
│   └── ui/
├── resources/
│   ├── characters/
│   ├── weapons/
│   └── abilities/
└── tests/
    ├── unit/
    └── integration/
```

Do not create empty folders merely to make the tree look complete. Create folders when they are first needed.

---

## 4. Development Milestones

Complete and verify each milestone before starting the next.

### Milestone 0 — Environment and plan
- Inspect the existing workspace before changing anything.
- Check Godot, Git and Blender availability and versions.
- Confirm whether this is a new or existing repository.
- Write or update the architecture and roadmap documents.
- Identify unresolved design choices and state reasonable temporary assumptions.
- Do not overwrite existing files without inspecting them.

**Acceptance criteria:** The environment, project plan, assumptions and next steps are documented.

### Milestone 1 — Playable 3D movement
- Create or configure the Godot project.
- Create a main scene and a simple arena.
- Add a `CharacterBody3D`-based player controller.
- Implement movement relative to the camera, gravity and jumping.
- Add collision and sensible arena boundaries.
- Add a third-person camera that follows the player.
- Define input actions in Project Settings or through a documented setup.
- Display a simple instruction label if helpful.

**Acceptance criteria:**
- The project launches without script errors.
- The player can move, turn, jump and land.
- The player cannot fall through the floor.
- Camera behaviour is usable.
- Controls and run instructions are documented.

### Milestone 2 — Basic combat
- Add a simple dummy target with health.
- Implement one basic attack.
- Validate range and hit detection.
- Apply damage through a single, clearly defined combat interface.
- Add target health feedback.
- Do not add complex combos or character-specific abilities yet.

**Acceptance criteria:** The attack reliably damages the target within the intended range and does not damage it outside the defined rules.

### Milestone 3 — Local gameplay loop
- Add player health and death state.
- Add a simple respawn flow.
- Add a basic score counter and match end condition if appropriate.
- Separate player movement, combat and match logic into maintainable components.

**Acceptance criteria:** A short local test match can start, play and end predictably.

### Milestone 4 — Multiplayer proof of concept
Only start after the local gameplay loop is stable.
- Research the current Godot multiplayer APIs before implementing.
- Start with two clients, not eight.
- Define host/server and client responsibilities.
- Synchronize player spawning and the minimum required state.
- Ensure the server validates damage, health, respawning, scores and victory conditions.
- Handle disconnects and invalid requests.
- Test latency and simultaneous actions.
- Document known limitations.

**Acceptance criteria:** Two separate clients can join the same test match and observe consistent, validated gameplay.

### Milestone 5 — 4v4 match foundation
- Enforce an eight-player limit.
- Assign two teams of four.
- Add team-specific spawn points.
- Add match start, timer, score and end conditions.
- Test with eight clients or a documented mix of clients and test clients.
- Keep matchmaking and public deployment out of scope until this works.

**Acceptance criteria:** The match rules work correctly and the server, not an individual client, determines the result.

### Milestone 6 — Art and character pipeline
- Create or select a base character.
- Rig and animate it in Blender or use appropriately licensed assets.
- Export using GLB/glTF.
- Import into Godot and verify scale, skeleton, materials and animations.
- Establish naming and import conventions before making many characters.

**Acceptance criteria:** One character model imports correctly and plays the required basic animations.

### Milestone 7 — Expand content
Only after the foundation is stable:
- Add a second playable character.
- Add one distinct ability per character.
- Add character selection and HUD.
- Add sound, effects and improved arena art.
- Expand the roster and arena content incrementally.

### Milestone 8 — Online readiness
Treat this as a separate project phase:
- Dedicated server deployment.
- Lobby and matchmaking.
- Authentication.
- Monitoring and crash reporting.
- Rate limits and abuse handling.
- Network performance testing.
- Security review and deployment process.

---

## 5. Architecture Rules

1. Keep player movement, combat, abilities, networking and match rules separated.
2. Use reusable scenes and resources rather than copying entire scripts between characters.
3. Define interfaces before asking multiple agents to implement connected systems.
4. Keep game rules configurable where appropriate; avoid unexplained magic numbers.
5. Prefer small scripts with clear responsibilities.
6. Use typed GDScript where it improves clarity.
7. Follow Godot naming and scene conventions consistently.
8. Avoid adding abstractions that do not solve a current problem.
9. Do not claim a feature is complete unless it has been tested.
10. Record major architecture decisions and reasons in `docs/DECISIONS.md`.

### Multiplayer security rule

For competitive multiplayer, the server must be authoritative for important outcomes, including:
- Damage and health.
- Death and respawn.
- Ability cooldowns and resource costs.
- Team assignment.
- Score and match completion.

Never trust a client simply because it reports a hit, position, cooldown, score or victory. Validate client requests on the server. Client-side prediction may be added later for responsiveness, but it must not replace server validation.

---

## 6. Qoder Agent Roles

Start with three agents. Add more only when the project needs them.

### Agent A — Architect
**Owns:** `docs/` and cross-system interface decisions.

Responsibilities:
- Inspect the repository and tools.
- Write specifications and milestones.
- Define scene/script responsibilities and interfaces.
- Identify dependencies and risks.
- Avoid implementing large features before the plan is reviewed.

### Agent B — Gameplay Developer
**Owns:** The current approved gameplay milestone.

Responsibilities:
- Implement the approved feature in GDScript and Godot scenes.
- Keep changes scoped.
- Explain changed files and setup steps.
- Run available checks.
- Report anything not tested.

### Agent C — QA Engineer
**Owns:** `tests/` and test reports.

Responsibilities:
- Define reproducible test cases.
- Run project/script checks using approved tools.
- Test expected and failure paths.
- Record exact steps, expected results, actual results and relevant logs.
- Report defects before proposing large rewrites.

### Additional agents later
- **Asset Engineer:** Blender assets and import pipeline.
- **Multiplayer Engineer:** networking and server-authoritative match systems.
- **UI Engineer:** menus, HUD and character selection.
- **Code Reviewer:** reviews diffs, risks and test results.

### Agent collaboration rules
- One agent owns a file or subsystem at a time.
- Do not let multiple agents concurrently edit the same files without coordination.
- Agree on interfaces before parallel implementation.
- Use separate branches or Git worktrees for substantial parallel work.
- Review diffs before merging.
- Do not allow agents to commit secrets, generated caches or large temporary files.

---

## 7. Definition of Done

A task is complete only when all relevant conditions are satisfied:

- [ ] The requested behaviour is implemented.
- [ ] The changed files and design decisions are documented.
- [ ] The project opens and runs, or any blocker is explicitly reported.
- [ ] Relevant script/import/test checks have been run.
- [ ] No new known errors are left unexplained.
- [ ] The acceptance criteria have been checked.
- [ ] The final report lists files changed, tests run, results and remaining limitations.

If a check cannot be run, state that clearly. Do not report an unverified feature as passing.

---

## 8. Git and File-Safety Rules

- Initialize Git if this is a new project and the user approves.
- Inspect `git status` before making changes.
- Commit only coherent, tested milestones.
- Keep generated engine caches out of Git where appropriate; use Godot's recommended ignore patterns for the chosen version.
- Do not delete or overwrite user files without permission.
- Do not run destructive shell commands without explicit approval.
- Do not automatically push to a remote repository.
- Use Git LFS or another suitable strategy if large binary assets become difficult to manage.
- Keep `.env`, secrets, credentials and private configuration out of source control.

---

## 9. First Task for Qoder

Copy the following instructions into Qoder as the initial task.

> You are the Lead Architect for a new 3D multiplayer 4v4 arena game.
>
> Read `docs/FOUNDATION_INSTRUCTIONS.md` completely and follow it as the project's working agreement.
>
> **Do not implement the entire game now.**
>
> 1. Inspect the current workspace and repository. Do not overwrite existing files.
> 2. Check whether Godot 4.x, Git and Blender are installed, and report their versions where available.
> 3. Identify whether the workspace already contains a Godot project.
> 4. Create the proposed folder structure only where needed.
> 5. Create or update `README.md` and the documentation files listed in this instruction.
> 6. Write a concise technical plan for Milestone 1: one arena and one controllable third-person character.
> 7. Define the initial input actions, scene structure, player-controller responsibilities and test cases.
> 8. List any assumptions, risks, missing tools and decisions that require the user's input.
> 9. Do not install software, add MCP servers, download assets, overwrite files, push to a remote repository or perform destructive actions without asking first.
> 10. Stop after presenting the plan and file changes for review. Do not begin Milestone 1 implementation until the plan is approved.
>
> Final response format:
> - Environment discovered
> - Files created or changed
> - Architecture decisions
> - Proposed Milestone 1 tasks
> - Tests/checks performed
> - Blockers and questions
> - Next recommended action

---

## 10. Practical Rules for MCP Setup

Add MCP integrations gradually and verify each one.

1. **Context/documentation search:** Use official Godot documentation as the primary reference; a documentation MCP is optional.
2. **Blender MCP:** Verify the server's source, permissions, Blender compatibility and exposed tools before connecting it.
3. **GitHub MCP:** Add only if GitHub operations will be useful. Use the minimum required permissions.
4. **Godot integration:** Prefer an existing implementation only after reviewing its maintenance, source and security. Otherwise, build a restricted local bridge that exposes specific actions such as running a project check and retrieving logs.
5. **Filesystem:** Prefer Qoder's existing project access unless an MCP adds a needed capability. Restrict any filesystem server to the project directory.
6. **Browser automation:** Playwright is mainly for browser-based interfaces and web services; it is not a replacement for testing the Godot game itself.
7. Never expose a local MCP server publicly unless you have deliberately designed and secured that setup.

---

## 11. Current Decisions and Open Questions

Use these defaults until the user decides otherwise:

- **Camera:** Third-person.
- **Visual style:** Undecided; use simple placeholder shapes.
- **Target platform:** Windows PC first.
- **Engine:** Godot 4.x.
- **Language:** GDScript.
- **Initial player count:** One local player; then two networked players.
- **Long-term match size:** 4v4, eight players total.
- **First map:** One small arena.
- **Initial roster:** One placeholder character; add a second only after core combat works.
- **Networking:** Server-authoritative design for competitive gameplay.
- **Public matchmaking:** Out of scope for the initial foundation.

Do not block Milestone 1 on decisions that do not affect the prototype. Record temporary assumptions and revisit them before the relevant milestone.

---

## 12. Success Criteria for the Foundation

The foundation is ready when:
- The project structure and instructions are clear.
- The installed tool versions and missing prerequisites are known.
- The initial technical decisions are documented.
- The first milestone has specific acceptance criteria.
- Qoder agents have defined responsibilities and file ownership.
- Git and file-safety rules are established.
- No large, untested implementation has been generated prematurely.

**The immediate goal is a clean, testable foundation—not a complete game.**
