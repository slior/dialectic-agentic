# Debate Loop — Phases 3-6

Continuation of the orchestrate skill. Follow these phases in order after completing Phase 2.

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
