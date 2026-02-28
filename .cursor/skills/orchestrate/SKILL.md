# Dialectic Debate Orchestrator

You are running a multi-agent design debate. Follow these instructions exactly and in order. This skill drives the entire debate from start to finish.

## Parameters

You will be invoked with:
- `WORKSPACE`: absolute path to the debate workspace directory (contains `problem.md`, optionally `context/` and `debate-config.json`)
- `PROJECT`: absolute path to the dialectic-agent project directory (contains `.cursor/skills/`, `prompts/`, `debate-config.json`)
- `DEBATE_CONFIG` (optional): absolute path to a debate config JSON file provided at invocation time

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
   - Invoke `{PROJECT}/.cursor/skills/orchestrator/scripts/create-debate-config.sh` directly.
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

## Phase 3: Clarifications (if enabled)

If `config.clarifications.enabled` is true:

Follow the skill at `{PROJECT}/.cursor/skills/clarify/SKILL.md`. Pass:
- `WORKSPACE`, `PROJECT`, `CONFIG`, `PROBLEM_TEXT`, `CONTEXT_FILES`

After the clarification skill completes, `{WORKSPACE}/debate/clarifications/summary.md` will exist.
Set `CLARIFICATIONS_SUMMARY` = `{WORKSPACE}/debate/clarifications/summary.md`.

If clarifications are disabled: set `CLARIFICATIONS_SUMMARY` = null.

---

## Phase 4: Debate Loop

Set `ROUND = 1`.

**LOOP** (repeat until exit condition):

### Step 4.1: Begin Round

Announce: "[Round {ROUND}] Starting."

Update `{WORKSPACE}/debate/status.json`:
```json
{
  "status": "running",
  "round": "{ROUND}",
  "phase": "proposals",
  "rounds_completed": "{ROUND - 1}",
  ...
}
```

Append to `{WORKSPACE}/debate/progress.md`:
```
## {timestamp} — Round {ROUND} started
```

Create directories:
- `{WORKSPACE}/debate/round-{ROUND}/proposals/`
- `{WORKSPACE}/debate/round-{ROUND}/critiques/`
- `{WORKSPACE}/debate/round-{ROUND}/refinements/`

### Step 4.2: Proposal Phase

Announce: "[Round {ROUND}] Launching proposals in parallel ({N} agents)..."

**Dispatch N subagents in parallel** — one per agent in `config.agents`:

For each agent, invoke a subagent with skill `{PROJECT}/.cursor/skills/role-agent/SKILL.md` and parameters:
```
AGENT_ID: {agent.id}
AGENT_NAME: {agent.name}
ROLE: {agent.role}
PHASE: "proposal"
ROUND: {ROUND}
ALL_AGENTS: {full agents list from config}
WORKSPACE: {WORKSPACE}
PROJECT: {PROJECT}
CONTEXT_FILES: {CONTEXT_FILES}
TOOL_BRIEFING: {TOOL_BRIEFING_BASE + agent-specific tool_hints if any}
CLARIFICATIONS_SUMMARY: {CLARIFICATIONS_SUMMARY}
```

**Wait** for all N subagents to complete.

**Verify** that each expected file exists: `{WORKSPACE}/debate/round-{ROUND}/proposals/{agent.id}.md`

If any file is missing:
1. Log a warning to `progress.md`: "WARNING: {agent.name} proposal missing in round {ROUND}. Retrying."
2. Re-dispatch that agent's subagent once.
3. If still missing after retry: log "WARNING: {agent.name} skipped in round {ROUND}" and continue without this agent. Inform the judge of missing agents when it runs.

Announce: "[Round {ROUND}] All proposals received."
Append to progress.md: `## {timestamp} — Round {ROUND} proposals complete`

### Step 4.3: Critique Phase

Announce: "[Round {ROUND}] Launching critiques in parallel ({N} agents)..."

**Dispatch N subagents in parallel** — one per agent:

Same parameters as proposal phase, but with `PHASE: "critique"`.

**Wait** for all N subagents to complete.

**Verify** that all N×(N-1) critique files exist:
For each agent A and each other agent B, check: `{WORKSPACE}/debate/round-{ROUND}/critiques/{A.id}-on-{B.id}.md`

Handle missing files the same way as the proposal phase (warn, retry once, skip with log).

Announce: "[Round {ROUND}] Critiques complete."
Append to progress.md: `## {timestamp} — Round {ROUND} critiques complete`

### Step 4.4: Refinement Phase

Announce: "[Round {ROUND}] Launching refinements in parallel ({N} agents)..."

**Dispatch N subagents in parallel** — one per agent:

Same parameters, but with `PHASE: "refinement"`.

**Wait** for all N subagents to complete.

**Verify** that each expected file exists: `{WORKSPACE}/debate/round-{ROUND}/refinements/{agent.id}.md`

Handle missing files as above.

Announce: "[Round {ROUND}] Refinements complete."
Append to progress.md: `## {timestamp} — Round {ROUND} refinements complete`

### Step 4.5: Convergence Check

Announce: "[Round {ROUND}] Judge evaluating convergence..."

**Dispatch one judge subagent** with skill `{PROJECT}/.cursor/skills/judge/SKILL.md` and parameters:
```
MODE: "convergence_check"
ROUND: {ROUND}
WORKSPACE: {WORKSPACE}
PROJECT: {PROJECT}
CONFIG: {config object including convergence.criteria and convergence.judge_threshold}
```

Wait for the subagent to complete.

Read `{WORKSPACE}/debate/round-{ROUND}/verdict.json`. Parse JSON.

Announce the result:
> "[Round {ROUND}] Verdict: {verdict.verdict} — confidence {verdict.confidence}"
> If open_issues is non-empty: "  Open issues: {open_issues joined with '; '}"

Update `{WORKSPACE}/debate/status.json` with `last_verdict`.
Append to progress.md: `## {timestamp} — Round {ROUND} verdict: {verdict} ({confidence})`

### Step 4.6: Check Exit Conditions

If `verdict.verdict == "DONE"` OR `ROUND >= config.convergence.max_rounds`:
- If DONE by convergence: announce "Convergence reached. Proceeding to synthesis."
- If DONE by ceiling: announce "Maximum rounds ({max_rounds}) reached. Proceeding to synthesis."
- **EXIT LOOP**

Otherwise: set `ROUND = ROUND + 1` and continue the loop.

---

## Phase 5: Synthesis

Announce: "[Synthesis] Judge writing final solution..."

**Dispatch one judge subagent** with skill `{PROJECT}/.cursor/skills/judge/SKILL.md` and parameters:
```
MODE: "synthesis"
ROUND: {ROUND}  (the final round number)
WORKSPACE: {WORKSPACE}
PROJECT: {PROJECT}
CONFIG: {config}
```

Wait for the subagent to complete.

Verify `{WORKSPACE}/debate/synthesis.md` exists.

---

## Phase 6: Completion

Update `{WORKSPACE}/debate/status.json`:
```json
{
  "status": "complete",
  "round": "{ROUND}",
  "phase": "done",
  "rounds_completed": "{ROUND}",
  "completed_at": "{current ISO 8601 timestamp}"
}
```

Append to `{WORKSPACE}/debate/progress.md`:
```
## {timestamp} — Debate complete
- Rounds: {ROUND}
- Final confidence: {last confidence score}
- Output: debate/synthesis.md
```

Announce to the user:
> "Debate complete. {ROUND} rounds, {N} participants. The synthesized solution is at:
> `{WORKSPACE}/debate/synthesis.md`
>
> All round contributions are saved in `{WORKSPACE}/debate/round-1/` through `round-{ROUND}/`."
