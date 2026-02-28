# AGENTS

## Project Overview

Dialectic Agent-Native is a configuration-first, code-free multi-agent design debate system.
Agents with different roles (for example architect, security, performance, and simplicity) run structured debate rounds and a judge decides when convergence is reached.
Behavior is driven by skill files, prompt templates, and `debate-config.json`.

## Main Directories

- `.cursor/skills/` - Core orchestration and role skills used by the host agent.
- `prompts/` - Role-specific and shared prompt templates for proposal, critique, and refinement phases.
- `docs/` - Project plans and design documentation.
- `scripts/` - Helper scripts, including debate config generation.

## Main Files

- `README.md` - Setup, usage, output structure, and customization docs.
- `debate-config.json` - Default debate configuration (agents, convergence, clarifications, tools).
