---
name: orchestrate
description: >-
  Drives the full multi-agent design debate lifecycle: loads config, initializes
  the workspace, runs optional clarification, executes debate rounds (proposal,
  critique, refinement), dispatches the judge for convergence checks, and writes
  the final synthesis. Use when the user wants to start or run a design debate.
compatibility: >-
  Requires a client that can dispatch subagents: every proposal, critique, refinement,
  clarification, and judge invocation runs as a dispatched subagent. Also requires the plugin
  payload that ships beside this skill (prompts/, agents/, debate-config.json), which the skill
  resolves from its own location; pass PROJECT=<plugin root> on clients that do not expose a
  skill's own path.
---

# Dialectic Debate Orchestrator

You are running a multi-agent design debate. Follow these instructions exactly and in order. This skill drives the entire debate from start to finish.

## Parameters

You will be invoked with:
- `WORKSPACE`: absolute path to the debate workspace directory (contains `problem.md`, optionally `context/` and `debate-config.json`)
- `PROJECT` (optional): absolute path to the dialectic-agent project directory (contains `skills/`, `agents/`, `prompts/`, `debate-config.json`). If omitted, Phase 0.0 self-locates the installed plugin root.
- `DEBATE_CONFIG` (optional): absolute path to a debate config JSON file provided at invocation time

## Example Invocation

```
WORKSPACE:    /Users/me/projects/cache-redesign
PROJECT:      /Users/liors/dev/dialectic-agent
DEBATE_CONFIG: /Users/me/projects/cache-redesign/debate-config.json
```

This runs a debate on the problem defined in `/Users/me/projects/cache-redesign/problem.md`, using the config at the specified path. Context files, if any, are read from `/Users/me/projects/cache-redesign/context/`. If `DEBATE_CONFIG` is omitted, the skill falls back to `{WORKSPACE}/debate-config.json` and then `{PROJECT}/debate-config.json`.

---

## Phase 0.0: Resolve PLUGIN_ROOT

Resolve `PROJECT` as follows:
- If the `PROJECT` parameter was supplied at invocation: set `PROJECT` to that value and skip the rest of this phase. Do not overwrite the user's choice.
- Otherwise, continue with self-location.

For self-location, you just read this SKILL.md from an absolute path. Let that path be SKILL_PATH.
Compute CANDIDATE_ROOT by removing the trailing `/skills/orchestrate/SKILL.md`
from SKILL_PATH.

Verify that all of the following exist under CANDIDATE_ROOT:
- `prompts/shared/system.md`
- `prompts/generalist/system.md`
- `debate-config.json`

If all three paths above exist under `CANDIDATE_ROOT`: set `PROJECT = CANDIDATE_ROOT`.

Otherwise, stop and print to the user, verbatim:

  > I could not locate the dialectic plugin files automatically. Re-invoke this skill and include the parameter:
  >
  >   `PROJECT=<absolute path to the installed plugin or to a clone of the dialectic-agentic repository>`
  >
  > For example: `PROJECT=/Users/you/.cursor/plugins/local/dialectic`

For all downstream phases and every subagent you dispatch, pass `PROJECT` as a parameter exactly as set above.

---

## Phase 0: Load Configuration

**Step 0.1: Validate invocation-provided config (if present)**

If `DEBATE_CONFIG` is provided:
- Check that the file exists and is readable.
- Parse it as JSON.
- If both checks pass, set this file as the active config and skip to Step 0.3.

If `DEBATE_CONFIG` is provided but is invalid (missing, unreadable, or not valid JSON):
1. Tell the user the path is invalid and ask: "Would you like to create a debate configuration now?"
2. If user says NO: stop the process immediately.
3. If user says YES:
   - Invoke `{PROJECT}/skills/orchestrate/scripts/create-debate-config.sh` directly.
   - Wait for the script to complete successfully.
   - Read the script output and extract the generated path from the line: `Wrote config to {path}`.
   - Validate the generated file exists and parse it as JSON.
   - Use that file as the active config for the rest of this process.
   - If the script fails or no valid output config can be resolved, stop and report the error to the user.

**Step 0.2: Find the config file (fallback when DEBATE_CONFIG is not provided)**

Check if `{WORKSPACE}/debate-config.json` exists.
- If YES: read it as the active config.
- If NO: read `{PROJECT}/debate-config.json` as the active config.

Parse the JSON. The config has these top-level fields:
- `agents`: array of `{ id, name, role }` — debate participants
- `judge`: `{ id, name, role, extra_instructions }` — the judge
- `convergence`: `{ max_rounds, judge_threshold, criteria }`
- `clarifications`: `{ enabled, max_iterations_per_agent }`
- `tools`: array of `{ name, description }`
- `agents_config`: object keyed by agent ID, each with optional `tool_hints`

**Step 0.3: Validate agent IDs**

All agent IDs (including the judge ID) must be unique. They must contain only alphanumeric characters, hyphens, or underscores. If any ID is invalid or duplicated, stop and report the error to the user.

**Step 0.4: Build the tool briefing string**

From `config.tools`, build a formatted string that will be included in every subagent's briefing:

```
## Tools Available to You

Use these tools actively to strengthen your analysis. Do not hesitate to look things up.

{for each tool in config.tools:}
- **{tool.name}** — {tool.description}
```

Store this as `TOOL_BRIEFING_BASE`. For each agent, also check `config.agents_config[agent.id].tool_hints` — if it exists, append it to the agent's specific tool briefing.

---

## Phase 1: Read Problem and Context

**Step 1.1: Read problem**

Read `{WORKSPACE}/problem.md`. Store as `PROBLEM_TEXT`.

If this file does not exist, stop and tell the user: "problem.md not found in {WORKSPACE}. Create this file with your problem statement and re-invoke."

**Step 1.2: List context files**

Check if `{WORKSPACE}/context/` exists. If yes, list all files in it recursively. Store as `CONTEXT_FILES`. If the directory does not exist, set `CONTEXT_FILES` to an empty list.

If context files exist, announce: "Found {N} context files: {comma-separated filenames}"

---

## Phase 2: Initialize Workspace

**Step 2.1: Create debate directory**

Create `{WORKSPACE}/debate/` if it does not exist.

**Step 2.2: Write initial status.json**

Write `{WORKSPACE}/debate/status.json`:
```json
{
  "status": "initializing",
  "round": 0,
  "phase": "setup",
  "rounds_completed": 0,
  "last_verdict": null,
  "started_at": "{current ISO 8601 timestamp}"
}
```

**Step 2.3: Write initial progress.md**

Write `{WORKSPACE}/debate/progress.md`:
```
# Debate Progress Log

## {timestamp} — Debate started
- Problem: {first line of PROBLEM_TEXT}
- Agents: {comma-separated list of agent names}
- Config: max_rounds={N}, judge_threshold={T}
- Clarifications: {enabled/disabled}
- Context files: {N files / none}
```

**Step 2.4: Announce startup**

Tell the user:
> "Debate initialized. {N} participants: {agent names}. Max rounds: {max_rounds}. Clarifications: {enabled/disabled}."

---

## Phases 3-6: Clarifications, Debate Loop, Synthesis, Completion

Read and follow [references/debate-loop.md](references/debate-loop.md) for the remaining phases. That file contains the complete clarification phase, debate loop (proposal / critique / refinement / convergence), synthesis, and completion procedures.
