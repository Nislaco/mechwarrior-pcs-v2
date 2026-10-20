---
model: bitrouter/auto
model_reasoning_effort: high
primary-agent: godot-specialist
linked-skills: [cgs-dev-story, cgs-standards-engine-code]
phase: implement
risk: high
argument-hint: Provide a bounded implementation request with accepted design context, exact Godot target files/scenes, scope constraints, owner or handoff needs, and required verification evidence (screenshots, logs, test output).
source-reference: .codex/workflows/godot-implementation.md
source-hash: 8b228c42b9c534e85a539b021378748cf1e01cbc9ed40d91e8e1c47b23a3da92
output-artifacts: [plan, changed-files, verification-evidence, handoff]
---

# Godot Implementation Workflow

## Purpose

Execute a bounded implementation slice in Godot using MCP tools, ensuring all changes are verified with visual/log evidence.

## Inputs

- AGENTS.md
- .codex/studio.json
- .codex/workflows/godot-implementation.md
- Accepted feature spec, GDD context, target Godot scenes/scripts/assets, and verification commands

## Role

Godot Specialist (godot-specialist) owns this workflow.

## Taxonomy

Category: implementation-planning
CLI aliases:
- godot-implementation

## Outputs

- Minimal Godot scene, script, or asset changes needed for the requested slice.
- Verification command output (godot_screenshot, execute_editor_script results, test output) and changed-file summary.
- Risks, follow-up tasks, and handoff notes.

## Validation

- Implementation remains within the accepted scope.
- Visual/log evidence proves the changed behavior (screenshots, editor script output, test results).
- Godot conventions and rollback risks are addressed.

## Phase Gates

- Confirm project state, owner role, write policy, and selected context.
- Name required artifacts and acceptance criteria before implementation or review work.
- Do not advance to handoff until evidence is recorded or a blocker is explicit.

## Required Artifacts

- Summary of the workflow result.
- Files, scenes, assets, tasks, docs, release notes, or tests changed or proposed.
- Verification evidence (screenshots, logs, test output) and unresolved risks.

## Context Contract

- Load AGENTS.md, .codex/studio.json, this workflow, the primary agent, linked skills, and only task-relevant project files.
- Avoid broad context unless the user explicitly approves it.

## Output Contract

- Decision or change summary.
- Step-by-step work performed or planned.
- Evidence, blockers, warnings, and next owner.

## Stop Conditions

- Required project state, approval, target files, or verification path is missing.
- The task crosses into another role without an explicit handoff.
- The workflow would require generated prompt mirrors or hidden automation.

## Handoff

Report changed files, validation evidence, residual risks, and the next owner only when ownership changes.

## Documentation Impact

- After functional source, engine, or asset changes, update the owning game document or record a fresh `## Documentation Impact` decision in `production/session-state/active.md`.
- Run `./codex-game-studio docs-impact --base <review-base>` before handoff.
- A `no-update` decision must state why no player, architecture, production, or release document changed.