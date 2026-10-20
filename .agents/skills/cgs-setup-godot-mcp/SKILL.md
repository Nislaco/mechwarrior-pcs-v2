---
name: cgs-setup-godot-mcp
description: Use for setting up Godot MCP debugging when a Godot project needs live editor tooling; produces a configured godot-mcp plugin, a verified MCP server connection, and connection evidence for handoff.
model: bitrouter/auto
model_reasoning_effort: medium
argument-hint: Provide the Godot project path, the MCP server location, any editor version constraints, and the required verification evidence (editor log lines, registered-command count, socket state).
primary-agent: godot-specialist
tool-policy: read/edit/shell/tests/git as needed within the repository write policy
isolation: repository-root; no init-time generated prompt bodies
source-reference: https://github.com/WindSeries83/godot-mcp
source-hash: d6890e54b3d85af9477dc2d2839e6ce467a97c549861e17d273dc1d5be1c37e2
user-invocable: true
---

# Codex Game Studio Setup Godot MCP

Use this skill to configure a Godot project for MCP debugging with the godot-mcp plugin, avoiding the broken `--headless -s` mode.

## Objective

Install and wire the godot-mcp plugin and MCP server so the Godot editor exposes MCP tooling with verified connection evidence.

## Inputs

- AGENTS.md
- .codex/studio.json
- Target Godot 4.7.2+ project path
- MCP server checkout with Node.js + npm available

## Arguments

- Godot project path and MCP server location.
- Editor version constraints and plugin install scope.
- Required verification evidence (editor log lines, registered-command count, socket state).

## Procedure

1. Copy the godot-mcp plugin into `<godot-project>/addons/godot_mcp`.
2. Patch `addons/godot_mcp/plugin.gd`: add `@tool` on line 1 and wrap GUI setup so headless runs stay safe:
   ```gdscript
   if not DisplayServer.get_name() == "headless":
       var panel_scene: PackedScene = preload("res://addons/godot_mcp/ui/status_panel.tscn")
       status_panel = panel_scene.instantiate()
       add_control_to_bottom_panel(status_panel, "godot-mcp")
       status_panel.call_deferred("setup", websocket_server, command_router)
   ```
3. Enable the plugin in `project.godot`:
   ```ini
   [editor_plugins]
   enabled=PackedStringArray("res://addons/godot_mcp/plugin.cfg")
   ```
4. Build the MCP server: `cd <mcp-server> && npm install && npm run build` (compiles TypeScript to `dist/`).
5. Register the server with the MCP client (`mcp.json`): command `node`, args `[<mcp-server>/dist/index.js]`.
6. Start the MCP server, then the editor: `godot --editor --path <godot-project>`.

## Output Contract

- Installed plugin path and patched files.
- MCP client registration snippet.
- Connection evidence: editor log `[DEBUG] godot_mcp plugin _enter_tree called`, `[MCP] Registered 210 commands (210 with schemas)`, established socket on port 6505.
- Changed files and next owner.

## Quality Gates

- Plugin loads with `@tool` annotation and headless-safe GUI guard.
- MCP server resolves the registered-command count before the editor starts.
- Evidence is captured from actual logs, not assumed.

## Decision Gates

- Never use `--headless -s` for MCP sessions; use `--editor`.
- Stop and report if the plugin fails to load or the socket never establishes.
- Escalate to tools-programmer when the server build fails.

## Handoff

Report installed paths, verification log lines, residual risks, and the next owner.
