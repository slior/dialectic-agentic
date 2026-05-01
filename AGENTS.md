# AGENTS

## Project Overview

Dialectic Agent-Native is a configuration-first, code-free multi-agent design debate system.
Agents with different roles (for example architect, security, performance, and simplicity) run structured debate rounds and a judge decides when convergence is reached.
Behavior is driven by skill files, prompt templates, and `debate-config.json`.

## Main Directories

- `skills/` - User-facing Cursor skills. `skills/orchestrate/` is the main entry point; `skills/judge/` is a secondary skill that can also be invoked standalone for post-hoc synthesis.
- `agents/` - Subagent definitions (`role-agent.md`, `role-clarify.md`) dispatched by the orchestrator via the Task tool. These are not user-invokable commands.
- `prompts/` - Role-specific and shared prompt templates for proposal, critique, and refinement phases.
- `docs/` - Project plans, configuration reference, and design documentation.
- `.cursor-plugin/` - Cursor plugin manifest (`plugin.json`).

## Main Files

- `README.md` - Setup, usage, output structure, and customization docs.
- `debate-config.json` - Default debate configuration (agents, convergence, clarifications, tools). Ships with the plugin as the fallback config.
- `CHANGELOG.md` - Release history, keep-a-changelog format.
- `LICENSE` - MIT license.
- `.cursor-plugin/plugin.json` - Cursor plugin manifest used by the marketplace.
