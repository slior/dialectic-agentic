# Debate Configuration Reference

This document explains `debate-config.json` for Dialectic Agent-Native.

## Config Resolution Order

The orchestrator selects the active config in this order:

1. `DEBATE_CONFIG` passed at invocation time
2. `{WORKSPACE}/debate-config.json`
3. `{PROJECT}/debate-config.json` (project default)

If `DEBATE_CONFIG` is provided but invalid, the orchestrator asks whether to generate one interactively.

## Full Structure

```json
{
  "agents": [{ "id": "...", "name": "...", "role": "..." }],
  "judge": { "id": "...", "name": "...", "role": "...", "extra_instructions": "..." },
  "convergence": { "max_rounds": 6, "judge_threshold": 0.8, "criteria": "..." },
  "clarifications": { "enabled": true, "max_iterations_per_agent": 3 },
  "tools": [{ "name": "...", "description": "..." }],
  "agents_config": {
    "<agent-id>": { "tool_hints": "..." }
  }
}
```

## Validation Rules

- All IDs in `agents[*].id` plus `judge.id` must be unique.
- IDs must contain: letters, numbers, hyphen, underscore only.
- Duplicate or invalid IDs stop the debate before execution.

## Top-Level Fields

### `agents`

Array of debate participants.

Each item has:
- `id` (string): unique short identifier used in filenames and internal routing.
- `name` (string): human-readable display name for logs and messages.
- `role` (string): role prompt set to use.

Note:
- More agents increases coverage but also increases runtime and critique volume.
- Critique count per round is `N * (N - 1)` where `N` is number of agents.

Role correspondence:
- `role` maps to prompt files in `prompts/<role>/`.
- Typical role values in this project: `architect`, `security`, `performance`, `kiss`, `generalist`, `datamodeling`, `testing`.
- Using a role without matching prompt files causes downstream role execution to fail.

### `judge`

Judge identity and persona settings.

Fields:
- `id` (string): unique judge ID, validated with the same rules as agent IDs.
- `name` (string): display name.
- `role` (string): judge role/profile.
- `extra_instructions` (string): additional judge guidance passed through config.

Note:
- The orchestrator passes the full config to the judge during convergence and synthesis.
- The orchestrator does not interpret `extra_instructions` directly. Judge behavior depends on the judge skill implementation.

### `convergence`

Controls when debate rounds stop.

Fields:
- `max_rounds` (integer): hard round ceiling.
- `judge_threshold` (number): target confidence threshold for convergence.
- `criteria` (string): convergence policy text for judge evaluation.

Behavior and interactions:
- Debate exits when either:
  - judge verdict is `DONE`, or
  - current round reaches `max_rounds`.
- `judge_threshold` and `criteria` are passed to the judge for convergence decisions.
- Lower threshold usually allows earlier completion. Higher threshold usually requires stronger alignment.
- `criteria` should match your quality bar. Strict criteria usually increase rounds.

### `clarifications`

Controls pre-debate clarification workflow.

Fields:
- `enabled` (boolean): turn clarification phase on or off.
- `max_iterations_per_agent` (integer): per-agent clarification loop cap.

Behavior:
- `enabled: true`:
  - orchestrator runs the clarify skill before round 1.
  - clarification summary is produced and shared into agent briefings.
- `enabled: false`:
  - clarify phase is skipped.
  - `max_iterations_per_agent` is effectively unused.

### `tools`

Shared tool catalog shown to all debate agents.

Each item has:
- `name` (string): tool identifier.
- `description` (string): usage guidance.

Behavior:
- Orchestrator builds a common tool briefing from this list.
- This briefing is injected into every role-agent run for proposal, critique, and refinement phases.
- Empty list means no shared tool briefing entries.

Practical guidance:
- `name` should match tools actually available in your agent platform.
- Include concrete descriptions so agents use tools with the intended scope.

### `agents_config`

Per-agent optional overrides, keyed by `agent.id`.

Supported fields:
- `tool_hints` (string): extra tool guidance appended to that specific agent's briefing.

Correspondence rules:
- Keys should match IDs in `agents[*].id`.
- If an agent has no `agents_config` entry, it receives only the shared `tools` briefing.
- If `tool_hints` exists, the final briefing becomes:
  - shared tools briefing, then
  - agent-specific `tool_hints`.

## Field Interactions Summary

- `agents[*].id` affects:
  - filename conventions (`proposals/<id>.md`, `refinements/<id>.md`, `critiques/<a>-on-<b>.md`)
  - `agents_config` lookup keys
  - uniqueness validation with `judge.id`
- `agents[*].role` affects which prompt set is used in role-agent execution.
- `tools` and `agents_config[*].tool_hints` combine to form per-agent tool briefings.
- `clarifications.enabled` controls whether clarification output exists and is passed to role agents.
- `convergence.max_rounds` and judge verdict jointly control loop termination.

## Example: Default Project Config

The repository default (`debate-config.json`) uses:

- 4 agents: `arch`, `sec`, `perf`, `kiss`
- judge role: `generalist`
- convergence: `max_rounds = 6`, `judge_threshold = 0.80`
- clarifications enabled with `max_iterations_per_agent = 3`
- shared tools: `web_search`, `file_read`
- agent-specific `tool_hints` for `sec`, `arch`, and `perf`
