# Dialectic Agent-Native: Design Document

**Date**: 2026-02-19  
**Status**: Draft  
**Context**: This document describes a new, standalone implementation of the Dialectic multi-agent debate system built agent-first — relying on a coding agent (Cursor, Claude Code, or any capable agentic platform) as the execution engine rather than a TypeScript orchestration layer.

---

## 1. Vision

The existing Dialectic implementation is a TypeScript/Node.js application that programmatically manages LLM providers, agent instances, state machines, and debate round coordination. It is robust but heavyweight: new roles, tools, and behaviors require code changes.

**Dialectic Agent-Native** reimagines this as a system of skill files and structured file conventions. The agent platform IS the orchestrator. Debate logic lives in SKILL.md files the agent reads and follows. State lives in plain files the agent reads and writes. Tools are whatever the agent platform has wired up — built-ins, MCP servers, shell scripts — declared by name in a JSON config. No TypeScript code is required.

### Core Properties

- **Agent-native**: the debate is driven by an agent following skill instructions, not a program
- **Minimal code**: zero required; optional shell scripts for bootstrapping or custom tools
- **Convergence-driven**: the judge decides when the debate is done — no fixed round count required
- **Parallel execution**: proposal and refinement phases run N subagents simultaneously via the Task tool
- **File-based state**: every contribution, verdict, and progress update is a file — readable mid-debate
- **Tool-open**: any tool the agent platform has access to (web search, file read, GitHub MCP, etc.) can be used by debate agents, declared in config only
- **Prompt-reusable**: existing role prompts from the TypeScript Dialectic are reused unchanged

---

## 2. Architecture Overview

```
┌─────────────────────────────────────────────────┐
│              User (or invoking agent)           │
│  Provides: problem.md, context/, config.json   │
└─────────────────┬───────────────────────────────┘
                  │ invokes
                  ▼
┌─────────────────────────────────────────────────┐
│         Orchestrator Agent                      │
│  reads: orchestrate.SKILL.md                   │
│  manages: round loop, convergence, progress     │
│  writes: progress.md, status.json              │
└──┬──────────────────────────────────┬───────────┘
   │ Task (parallel)                  │ Task (sequential)
   ▼                                  ▼
┌─────────────┐  ┌─────────────┐  ┌──────────────┐
│ Role Agent  │  │ Role Agent  │  │ Judge Agent  │
│ (architect) │  │ (security)  │  │              │
│             │  │             │  │ reads all    │
│ reads:      │  │ reads:      │  │ refinements  │
│ role-agent  │  │ role-agent  │  │ emits:       │
│ .SKILL.md   │  │ .SKILL.md   │  │ verdict.json │
│ prompts/    │  │ prompts/    │  │ synthesis.md │
│ architect   │  │ security.md │  │              │
│ .md         │  │             │  │ reads:       │
│             │  │             │  │ judge.SKILL  │
│ writes:     │  │ writes:     │  │ .md          │
│ proposals/  │  │ proposals/  │  └──────────────┘
│ architect   │  │ security.md │
│ .md         │  │             │
└─────────────┘  └─────────────┘
         │              │
         └──────────────┘
                │
                ▼ all contributions
┌─────────────────────────────────────────────────┐
│         debate/ (file-based state)              │
│  round-1/proposals/, critiques/, refinements/  │
│  round-1/verdict.json                          │
│  round-2/...                                   │
│  progress.md, status.json, synthesis.md        │
└─────────────────────────────────────────────────┘
```

The orchestrator is the only long-running agent. Role agents and the judge are short-lived subagents invoked per-phase via the Task tool, each with a focused context window.

---

## 3. Project File Structure

This is the installable project — authored once, reused across all debates.

```
dialectic-agent/
├── README.md                        # How to start a debate
│
├── skills/
│   ├── orchestrate.SKILL.md         # Main entry point — drives clarifications then debate loop
│   ├── clarify.SKILL.md             # Hosted by orchestrator — conducts clarification conversation
│   ├── role-clarify.SKILL.md        # Subagent: generates role-specific question list (JSON)
│   ├── role-agent.SKILL.md          # Generic role agent — parameterized by agent id/role/phase
│   └── judge.SKILL.md               # Convergence evaluation and final synthesis
│
├── prompts/
│   ├── shared/                      # Cross-role instructions, composed with role files at runtime
│   │   ├── system.md                # Grounding rules, requirements-first approach
│   │   ├── proposal.md              # Requirements coverage section, output format rules
│   │   ├── critique.md              # Requirements check, critique behavioral guidelines
│   │   ├── refinement.md            # Requirements preservation, accept/reject framework
│   │   ├── summarize.md             # Summarization guidelines (for long debates)
│   │   └── clarify.md               # Clarification JSON schema and guidelines
│   │
│   ├── architect/                   # Architect-specific framing per phase
│   │   ├── system.md                # Persona, focus areas (scalability, component boundaries, etc.)
│   │   ├── proposal.md              # Architect proposal structure and sections
│   │   ├── critique.md              # Architect critique framing
│   │   └── refinement.md            # Architect refinement framing
│   │
│   ├── security/
│   │   ├── system.md
│   │   ├── proposal.md
│   │   ├── critique.md
│   │   └── refinement.md
│   │
│   ├── performance/
│   │   └── ...
│   │
│   ├── kiss/
│   │   └── ...
│   │
│   ├── testing/
│   │   └── ...
│   │
│   ├── datamodeling/
│   │   └── ...
│   │
│   └── generalist/                  # Judge role
│       ├── system.md
│       └── synthesize.md            # Synthesis-specific instructions (replaces proposal/critique/refine)
│
└── debate-config.json               # Default configuration (user may override per debate)
```

---

## 4. Debate Workspace (Runtime)

The user creates a workspace directory for each debate. The orchestrator reads inputs from it and writes all state into it.

```
my-debate/
├── problem.md                       # Required: the problem statement
│
├── context/                         # Optional: extra context files
│   ├── existing-architecture.md
│   ├── api-spec.json
│   └── constraints.md
│
├── debate-config.json               # Optional: overrides the default config
│
└── debate/                          # Created and managed by the orchestrator
    ├── progress.md                  # Append-only progress log
    ├── status.json                  # Current state snapshot
    │
    ├── clarifications/              # Written during clarification phase (before round-1)
    │   ├── arch.md                  # Accumulated Q&A for architect agent
    │   ├── sec.md                   # Accumulated Q&A for security agent
    │   ├── arch-pending.json        # Temp: current question batch (deleted after each round)
    │   └── summary.md               # Consolidated Q&A for all agents — given to debate agents
    │
    ├── round-1/
    │   ├── proposals/
    │   │   ├── arch.md              # named by agent ID, not role
    │   │   ├── sec.md
    │   │   ├── perf.md
    │   │   └── kiss.md
    │   ├── critiques/               # <reviewer-id>-on-<target-id>.md
    │   │   ├── arch-on-sec.md
    │   │   ├── arch-on-perf.md
    │   │   ├── arch-on-kiss.md
    │   │   ├── sec-on-arch.md
    │   │   ├── sec-on-perf.md
    │   │   ├── sec-on-kiss.md
    │   │   └── ...                  # N×(N-1) files total
    │   ├── refinements/
    │   │   ├── arch.md
    │   │   ├── sec.md
    │   │   └── ...
    │   └── verdict.json             # Judge's convergence verdict
    │
    ├── round-2/
    │   └── ...
    │
    └── synthesis.md                 # Final output — written when DONE
```

**Design principles**:
- The `context/` directory is open-ended. Any file type is valid. Agents use their `file_read` tool to access files they find relevant.
- `debate/` is never manually edited. It is the agent's working memory.
- Every file is human-readable mid-debate. Open any `proposals/architect.md` while the debate is running to see partial work.
- `progress.md` and `status.json` provide external monitoring without inspecting the agent's chat.

---

## 5. Configuration

A single JSON file controls debate behavior. It focuses exclusively on debate semantics — not LLM infrastructure (no models, temperatures, API keys, or token limits, which the agent platform manages).

```json
{
  "agents": [
    { "id": "arch",  "name": "System Architect",     "role": "architect"   },
    { "id": "sec",   "name": "Security Engineer",     "role": "security"    },
    { "id": "perf",  "name": "Performance Engineer",  "role": "performance" },
    { "id": "kiss",  "name": "Simplicity Advocate",   "role": "kiss"        }
  ],

  "judge": {
    "id": "judge",
    "name": "Technical Judge",
    "role": "generalist",
    "extra_instructions": ""
  },

  "convergence": {
    "max_rounds": 6,
    "judge_threshold": 0.80,
    "criteria": "Proposals have converged when the refinements across agents are substantially aligned, no agent is raising fundamental unresolved objections, and the solution is comprehensive enough to act on."
  },

  "clarifications": {
    "enabled": true,
    "max_iterations_per_agent": 3
  },

  "tools": [
    {
      "name": "web_search",
      "description": "Search the web for documentation, benchmarks, RFCs, and current best practices"
    },
    {
      "name": "file_read",
      "description": "Read files from the context/ directory or previous round contributions"
    },
    {
      "name": "github_search_code",
      "description": "Search GitHub for real-world implementations and code examples"
    },
    {
      "name": "fetch",
      "description": "Fetch and read any URL — use for library documentation, specs, CVE databases"
    }
  ],

  "agents_config": {
    "sec": {
      "tool_hints": "Use fetch to look up CVE databases (cve.mitre.org) and OWASP documentation relevant to the problem."
    },
    "arch": {
      "tool_hints": "Use github_search_code to find reference implementations of patterns you propose."
    },
    "perf": {
      "tool_hints": "Use web_search to find real benchmark data and latency/throughput figures relevant to your recommendations."
    }
  }
}
```

### Configuration Fields

| Field | Description |
|---|---|
| `agents` | List of debate participants. Each must have a unique `id`, a human-readable `name`, and a `role` that maps to `prompts/<role>.md`. |
| `agents[].id` | Unique identifier used for file naming. Must be filesystem-safe (alphanumeric, hyphens, underscores). Must be unique across all agents and the judge. |
| `agents[].name` | Human-readable display name. Used in progress logs and synthesis output. |
| `agents[].role` | Functional role. Determines which prompt file is loaded (`prompts/<role>.md`). Multiple agents may share a role — they use the same prompt but have distinct IDs and thus distinct output files. |
| `judge.id` | Unique identifier for the judge. Must not collide with any agent ID. |
| `judge.role` | Judge's role — typically `"generalist"`. Maps to `prompts/generalist.md`. |
| `convergence.max_rounds` | Hard ceiling on debate rounds. The judge may terminate earlier. |
| `convergence.judge_threshold` | Confidence score (0–1) at or above which the judge stops the debate. |
| `convergence.criteria` | Plain-language description of what convergence means. Given verbatim to the judge. |
| `clarifications.enabled` | Whether to run the clarifications phase before the debate loop. Default: `true`. |
| `clarifications.max_iterations_per_agent` | Maximum question rounds per agent before moving on. Default: `3`. |
| `tools` | Tools available to all agents. Names must match the agent platform's tool names (built-ins or MCP). |
| `agents_config.<id>.tool_hints` | Optional per-agent guidance on tool use, keyed by agent ID. Appended to that agent's briefing. |
| `judge.extra_instructions` | Optional additional instructions for the judge. |

**Agent ID constraints**: IDs are used as filename components throughout the debate workspace. They must be:
- Unique across all agents and the judge within a debate
- Composed of alphanumeric characters, hyphens, or underscores only
- Non-empty and reasonably short (suggested: ≤ 32 characters)

**Multiple agents per role**: Two agents may share the same role (e.g., two `architect` agents with different focuses — one for systems architecture, one for data architecture). They load the same `prompts/architect.md` but produce distinct proposal, critique, and refinement files because their IDs differ.

**On tools**: The `tools` array is a semantic briefing, not access control. The agent platform controls what tools are actually available. Listing a tool the platform does not have is harmless — the agent will simply not be able to call it. Listing MCP server tools (e.g., `github_search_code` from a GitHub MCP server) works identically to built-in tools.

---

## 6. Debate Flow

The orchestrator follows this algorithm, encoded in `.cursor/skills/orchestrate/SKILL.md`:

```
1. READ problem.md and debate-config.json (workspace override or project default)
2. LIST context/ files (if the directory exists)
3. CREATE debate/ directory and initialize progress.md, status.json
4. SET round = 1

LOOP:
  5. LOG round start to progress.md, update status.json
  
  6. PROPOSAL PHASE (parallel):
     - Round 1: launch N subagents (one per role) each writing a fresh proposal
     - Round 2+: launch N subagents each reading their previous refinement
       and writing an updated proposal (carry-forward, not a blank slate)
     - Wait for all N proposal files to appear in round-R/proposals/
  
  7. CRITIQUE PHASE (parallel):
     - Launch N subagents (one per agent), each:
       a. Reads all OTHER agents' proposals from round-R/proposals/<agent_id>.md
       b. For each other agent, writes round-R/critiques/<reviewer_id>-on-<target_id>.md
     - Wait for all N×(N-1) critique files to appear in round-R/critiques/
     
     NOTE: critique and refinement MUST be separate phases. Agent A's refinement
     depends on critiques OF A's proposal from agents B, C, D — which do not exist
     yet while critiques are being produced in parallel. The phases are ordered:
     all critiques must land before any refinement begins.
  
  8. REFINEMENT PHASE (parallel):
     - Launch N subagents (one per agent), each:
       a. Reads its own proposal from round-R/proposals/<agent_id>.md
       b. Reads all critiques targeting it: round-R/critiques/*-on-<agent_id>.md
       c. Writes its refined proposal to round-R/refinements/<agent_id>.md
     - Wait for all N refinement files to appear in round-R/refinements/
  
  9. CONVERGENCE CHECK:
     - Launch judge subagent, which reads all refinements from round-R/refinements/
     - Judge writes round-R/verdict.json:
       { "verdict": "CONTINUE" | "DONE", "confidence": 0.82, "reasoning": "..." }
     - IF verdict == "DONE" OR round == max_rounds: EXIT LOOP
     - ELSE: increment round, continue
  
10. SYNTHESIS:
    - Launch judge subagent with all rounds of refinements
    - Judge writes debate/synthesis.md (the final output)
   
11. UPDATE status.json to { "status": "complete" }
12. LOG completion to progress.md
```

### Phase Parallelism and Synchronization

Each phase runs as N parallel subagents (one per role), dispatched simultaneously via the Task tool. The orchestrator waits for all output files before advancing to the next phase. This creates three synchronization barriers per round:

```
proposals phase ──► [barrier: all proposals exist] ──►
critique phase  ──► [barrier: all critiques exist]  ──►
refinement phase──► [barrier: all refinements exist] ──►
judge check
```

The barrier is implemented simply: the orchestrator checks for the existence of the expected output files. If a file is missing after the Task call returns, the orchestrator logs a warning to `progress.md` and retries the subagent once before continuing without that role's contribution.

### Critique File Naming

Critiques are named `<reviewer-id>-on-<target-id>.md` (e.g., `arch-on-sec.md`). This convention allows the refinement agent for agent `X` to find all critiques targeting it with a simple glob: `critiques/*-on-<X>.md`. No parsing of multi-section files required, and no collision even when multiple agents share a role.

For a 4-agent debate, each critique phase produces 12 files (4 × 3). Each critique subagent writes 3 files (one per other agent it critiques).

### Carry-Forward Proposals

From round 2 onward, each role agent reads its own previous refinement and uses it as the starting point for the new round. This implements the same "refinements become next round's proposals" behavior as the TypeScript implementation, without any special orchestrator logic — the agent simply reads the file.

---

## 7. Skill Files

### 7.1 `.cursor/skills/orchestrate/SKILL.md`

**Purpose**: Entry point. The user (or an invoking agent) reads and follows this skill to run a debate.

**Responsibilities**:
- Parse inputs (problem file, context directory, config)
- Create and manage the debate workspace
- Drive the round loop (proposals → critique+refinement → convergence check)
- Dispatch parallel subagents via the Task tool
- Accumulate progress
- Trigger final synthesis
- Report completion

**Key instructions it encodes**:
- How to locate and read the config (workspace override or project default)
- How to build the tool briefing string from the config's `tools` array
- How to launch role agents in parallel and wait for their output files
- How to interpret `verdict.json` and decide whether to continue
- How to handle a missing output file (subagent failure): retry once, then skip with a warning logged to `progress.md`

### 7.2 `.cursor/skills/role-agent/SKILL.md`

**Purpose**: Executed by a subagent for a specific role in a specific phase.

**Parameters** (passed in the Task tool invocation):
- `agent_id`: e.g., `"arch"` — the unique agent ID, used for all file naming
- `agent_name`: e.g., `"System Architect"` — human-readable, used in written content
- `role`: e.g., `"architect"` — determines which prompt file to load (`prompts/<role>.md`)
- `all_agents`: list of `{ id, name, role }` objects for all agents in the debate
- `phase`: `"proposal"` | `"critique"` | `"refinement"`
- `round`: integer
- `workspace`: path to the debate workspace
- `problem_file`: path to `problem.md`
- `config`: the resolved debate config object
- `context_files`: list of files in `context/` (may be empty)

**Responsibilities by phase**:

*Proposal phase* (`phase == "proposal"`):
- Read role persona from `prompts/<role>.md`
- Read the problem statement and any relevant context files
- Round 1: produce a fresh proposal reflecting this agent's perspective
- Round 2+: read `round-(R-1)/refinements/<agent_id>.md` as a starting point, produce an updated proposal that carries forward and advances the prior position
- Write `round-R/proposals/<agent_id>.md`

*Critique phase* (`phase == "critique"`):
- Read role persona from `prompts/<role>.md`
- For each other agent (from `all_agents`, excluding self):
  - Read their proposal from `round-R/proposals/<other_agent_id>.md`
  - Write a focused critique to `round-R/critiques/<agent_id>-on-<other_agent_id>.md`
- Critiques should be substantive: identify specific weaknesses, risks, or gaps from this agent's perspective; avoid generic praise
- Use tools to back up critique claims where useful (e.g., look up a known CVE relevant to a security concern)

*Refinement phase* (`phase == "refinement"`):
- Read role persona from `prompts/<role>.md`
- Read own proposal from `round-R/proposals/<agent_id>.md`
- Read all critiques targeting this agent: `round-R/critiques/*-on-<agent_id>.md`
- Produce a refined proposal that genuinely responds to valid critique points; document which concerns were accepted vs. rejected and why
- Write `round-R/refinements/<agent_id>.md`

**Across all phases**:
- Use tools from the briefing actively
- Write output files with complete content (no partial writes)

**Role persona loading**: the skill instructs the subagent to read `prompts/<role>.md` and treat its content as its system-level identity for the duration of the task.

### 7.3 `.cursor/skills/judge/SKILL.md`

**Purpose**: Evaluates convergence after each round and writes the final synthesis.

**Parameters**:
- `mode`: `"convergence_check"` or `"synthesis"`
- `round`: integer (for convergence check)
- `workspace`: path to the debate workspace
- `config`: the resolved config (includes `convergence.criteria` and `judge_threshold`)

**Convergence check mode**:
- Reads all `round-R/refinements/<role>.md` files
- Reads the convergence criteria from config
- Evaluates: are proposals substantially aligned? Are there unresolved fundamental objections?
- Writes `round-R/verdict.json`:
  ```json
  {
    "verdict": "CONTINUE",
    "confidence": 0.64,
    "reasoning": "Performance and architect are aligned on caching strategy, but security is raising an unresolved concern about token validation that the other roles have not yet addressed.",
    "open_issues": [
      "Token validation approach unresolved between security and architect"
    ]
  }
  ```
- `verdict` is `"DONE"` when `confidence >= judge_threshold` from config
- Reads `prompts/judge.md` for persona

**Synthesis mode**:
- Reads all rounds of refinements (to understand the trajectory)
- Focuses on the final round's refinements as the most refined positions
- Reads any open issues from the last verdict
- Writes `debate/synthesis.md`: a comprehensive solution document covering the agreed design, key tradeoffs, dissenting views that were not resolved, and recommendations
- The synthesis is not a simple summary — it is an expert integration of the debate's conclusions

---

## 8. Input and Output

### Input

| File | Required | Description |
|---|---|---|
| `problem.md` | Yes | The problem statement. Any length, any format. Agents read it verbatim. |
| `context/` | No | Directory of supplementary files. No size limit — agents read selectively. |
| `debate-config.json` | No | Config override. Falls back to project-level `debate-config.json`. |

**Providing context**: drop any relevant files into `context/`. Supported file types include markdown, plain text, JSON, YAML, code files. The orchestrator lists the directory and includes the file listing in every agent's briefing so agents know what is available. Agents use their `file_read` tool to access files they find relevant. This replaces the original `--context` single-file (5000-char truncated) mechanism with an open-ended, agent-selective approach.

### Output

| File | Description |
|---|---|
| `debate/synthesis.md` | The final solution — the primary output |
| `debate/round-N/proposals/<role>.md` | Each role's proposal for each round |
| `debate/round-N/critiques/<role>.md` | Each role's critique observations |
| `debate/round-N/refinements/<role>.md` | Each role's refined position |
| `debate/round-N/verdict.json` | Judge's convergence verdict per round |
| `debate/progress.md` | Append-only human-readable log |
| `debate/status.json` | Current machine-readable status |

The complete debate directory is the equivalent of the TypeScript implementation's saved JSON state — it contains the full history, all contributions, all verdicts, and the final synthesis. It is human-readable by design.

---

## 9. Progress Visibility

### Agent Narration (primary)

The orchestrator agent narrates its actions to the user in real time. Since the orchestrator runs in the user's IDE or terminal, this IS the live progress stream:

```
[Debate Start] Problem loaded. 4 roles: architect, security, performance, kiss.
[Debate Start] Context files: existing-architecture.md, api-spec.json
[Round 1] Launching proposals in parallel (4 subagents)...
[Round 1] All proposals received. Launching critique+refinement in parallel (4 subagents)...
[Round 1] All refinements received. Requesting judge convergence evaluation...
[Round 1] Verdict: CONTINUE — confidence 0.61
  Open issues: "Token validation approach unresolved between security and architect"
[Round 2] Launching proposals (carry-forward from round 1 refinements)...
...
[Round 3] Verdict: DONE — confidence 0.84. Proceeding to synthesis.
[Synthesis] Judge writing final synthesis...
[Complete] Debate finished in 3 rounds. Output: debate/synthesis.md
```

### File-Based Progress (secondary)

```json
// debate/status.json (updated after each phase)
{
  "status": "running",
  "round": 2,
  "phase": "critique_and_refine",
  "rounds_completed": 1,
  "last_verdict": { "verdict": "CONTINUE", "confidence": 0.61 },
  "started_at": "2026-02-19T10:00:00Z",
  "updated_at": "2026-02-19T10:08:23Z"
}
```

```markdown
<!-- debate/progress.md (append-only) -->
## 2026-02-19 10:00:00 — Debate started
- Problem: Design a distributed rate limiting system
- Roles: architect, security, performance, kiss
- Config: max_rounds=6, threshold=0.80

## 2026-02-19 10:02:15 — Round 1 proposals complete
## 2026-02-19 10:06:40 — Round 1 refinements complete  
## 2026-02-19 10:08:23 — Round 1 verdict: CONTINUE (0.61)
  Open issues: Token validation approach unresolved
```

The emerging files in `debate/round-N/` are themselves a live progress signal — you can open `proposals/architect.md` while it's being written.

---

## 10. Tools and MCP Integration

### Declaring Tools

Tools are declared in `debate-config.json` under `"tools"`. Each entry provides a name (matching the agent platform's tool name) and a description (used in agent briefings). No implementation code is required.

```json
"tools": [
  { "name": "web_search", "description": "Search the web for documentation and benchmarks" },
  { "name": "file_read",  "description": "Read context files or previous contributions" },
  { "name": "github_search_code", "description": "Search GitHub for reference implementations" },
  { "name": "fetch", "description": "Fetch any URL — library docs, specs, CVE databases" }
]
```

**MCP tools** (e.g., from a GitHub MCP server, a documentation MCP server, a Jira MCP server) are listed identically to built-in tools. The agent platform's MCP integration makes them callable. No adapter code or registration is needed in this project.

### Agent Tool Briefing

The orchestrator generates a tool briefing string from the config and includes it in every role agent's task:

```
## Tools Available to You

Use these tools actively to strengthen your analysis. Do not hesitate to look things up.

- **web_search** — Search the web for documentation and benchmarks
- **file_read** — Read context files from context/ or previous round contributions from debate/
- **github_search_code** — Search GitHub for reference implementations
- **fetch** — Fetch any URL — library docs, specs, CVE databases

[For security role only]
Tool guidance: Use fetch to look up CVE databases (cve.mitre.org) and OWASP documentation
relevant to the problem.
```

### Graceful Degradation

If an agent cannot call a listed tool (because the platform does not have it configured), it simply cannot use it. The debate continues. The tool listing is advisory, not mandatory. This makes configs portable — a user without a GitHub MCP server configured can run the same config and the agent will rely on `web_search` instead.

---

## 11. Prompt Structure and Composition

### Two-Layer Design

The prompt system mirrors the existing TypeScript structure exactly, with two layers composed per phase:

| Layer | TypeScript | Agent-Native |
|---|---|---|
| Cross-role, cross-phase rules | `shared.ts` | `prompts/shared/<phase>.md` |
| Role-specific framing | `architect-prompts.ts` etc. | `prompts/<role>/<phase>.md` |
| Composition | `appendSharedInstructions()` in code | Instruction in `role-agent.SKILL.md` |

The role-agent skill composes them with a simple instruction to the subagent:

> "Your identity for this task: read `prompts/shared/system.md` then `prompts/<role>/system.md`.
> Your task instructions: read `prompts/shared/<phase>.md` then `prompts/<role>/<phase>.md`.
> Together these define who you are and what to produce."

This keeps shared behavioral rules (`shared/`) cleanly separated from role-specific framing (`<role>/`). Updating critique guidelines for all roles means editing one file (`shared/critique.md`), not touching every role directory.

### Handling Dynamic Content

The TypeScript prompt functions inject content via string interpolation at call time:
```typescript
proposePrompt(problem, context, agentId, includeFullHistory)
```

In the agent-native model, prompt files are **task instructions** that tell the agent where to find dynamic content rather than receiving it as injected strings:

```markdown
<!-- prompts/architect/proposal.md -->
## Your Task

Read the problem statement from `problem.md` in your workspace.
Read any context files you find relevant in `context/`.
If this is round 2+, read your previous refinement from
`debate/round-{N-1}/refinements/{your-agent-id}.md` as your starting point.

As an architect, produce a proposal using this structure:
### Architecture Overview
...
```

The agent reads the problem and prior-round files itself. The skill parameters (`round`, `agent_id`, `workspace`) tell it where to look; the prompt file tells it what to do once it has read the content.

### Phases Without a Role-Specific File

Not every phase requires role-specific framing. If `prompts/<role>/critique.md` does not exist, the subagent uses only `prompts/shared/critique.md`. The shared file alone is sufficient for generic critique behavior; role files add only the framing that genuinely differs by role (e.g., security agents framing critiques around threat models vs. architect agents framing them around component boundaries).

## 11a. Reusing Existing Prompts

The `prompts/` directory translates directly from the existing Dialectic role prompts. The existing files in `packages/core/src/agents/prompts/` define:
- System-level role identity (who the agent is)
- How to approach proposal, critique, and refinement

These map directly into the agent-native model: each role agent reads its `prompts/<role>.md` file and treats it as its persona for the duration of the task. No modification is needed.

The one adaptation: the TypeScript prompts include function-based templates (`proposePrompt()`, `critiquePrompt()`, `refinePrompt()`) that inject dynamic content. In the agent-native model, the skill file provides this structure: the role-agent skill tells the agent what phase it is in and what to include, while the persona prompt defines how to think about the problem.

---

## 12. Starting a Debate (Usage)

```
1. Install: clone dialectic-agent/ somewhere accessible to your agent.

2. Create a workspace:
   mkdir my-rate-limiter-debate
   cd my-rate-limiter-debate

3. Write your problem:
   # problem.md
   Design a distributed rate limiting system for an API gateway handling
   100k req/s. Key constraints: ...

4. (Optional) Add context files:
   mkdir context
   cp existing-gateway-architecture.md context/
   cp load-profile.json context/

5. (Optional) Override config:
   cp /path/to/dialectic-agent/debate-config.json ./debate-config.json
   # edit as needed

6. Invoke the orchestrator skill in your agent:
   "Read and follow the skill at /path/to/dialectic-agent/.cursor/skills/orchestrate/SKILL.md.
    The debate workspace is at /path/to/my-rate-limiter-debate"
```

The `README.md` contains this verbatim as the quickstart.

---

## 13. Key Differences from the TypeScript Implementation

| Aspect | TypeScript Dialectic | Dialectic Agent-Native |
|---|---|---|
| Orchestration | Programmatic state machine (TS) | Agent following a skill file |
| Agent roles | TS classes with LLM calls | Subagents reading persona files |
| Round count | Configurable fixed count | Convergence-driven, max as ceiling |
| State | JSON files + in-memory | Plain markdown + JSON files |
| Tools | TS `ToolImplementation` interface | Agent platform built-ins + MCP, declared by name |
| Context | Single `--context` file (5000 char limit) | Open `context/` directory, agent reads selectively |
| Progress | CLI spinner + stderr log | Agent narration + `progress.md` + `status.json` |
| Providers | Configured per-agent (OpenAI/OpenRouter) | Agent platform's own LLM |
| New roles | New TS prompt file + registry entry | New `prompts/<role>.md` + add agent entry to config |
| New tools | TS implementation + registration | Add MCP server to platform + list in config |
| Parallelism | `Promise.all` over LLM calls | Task tool spawning N subagents |
| Codebase | ~5000 lines TypeScript | ~3 skill files + prompts + config |

---

## 14. Open Questions and Future Considerations

- **Clarifications phase**: Addressed below as a first-class feature (see Section 15).

- **Evaluation**: The TypeScript `eval` command post-evaluates a completed debate. A `.cursor/skills/evaluate/SKILL.md` could implement this by reading `synthesis.md` and all round files.

- **Report generation**: The TypeScript `report` command generates a Markdown report from debate state. In the agent-native model, `synthesis.md` serves this role. A dedicated report skill could format a richer report from the debate directory.

- **Partial failure handling**: If a subagent fails (no output file after the Task call), the orchestrator skill should retry once, then log a warning and continue without that role. The judge should be informed of the missing role in its convergence check.

- **Large context in late rounds**: As the debate accumulates, agents reading all previous refinements may approach context limits. The existing Dialectic's summarization approach (each agent summarizes its own history when it exceeds a threshold) could be implemented as an instruction in `role-agent.SKILL.md`: "If citing previous rounds, summarize rather than quoting verbatim."

---

## 15. Clarifications Phase

The clarifications phase is a first-class feature, not an optional add-on. It runs before the debate loop and gives each agent a chance to ask iterative, answer-informed clarifying questions about the problem.

### Interaction Model

The agentic platform's conversational nature makes it a **better interface** for clarifications than the original CLI (which used `readline` to block and wait for user input). In a chat-based agentic platform, the orchestrator IS already in a conversation with the user. Presenting questions and waiting for answers is just normal chat — the agent writes a message, the user responds, the agent continues.

**The orchestrator hosts the conversation.** Subagents are used only to **generate role-specific question lists** — they run, produce a JSON file of questions, and stop. The orchestrator reads the output, presents questions to the user, receives the user's reply, and loops.

### Flow

```
For each agent (in config order):
  iteration = 0
  LOOP:
    1. Launch role-clarify subagent:
       - reads: role persona, problem.md, context/, clarifications/<agent-id>.md (accumulated Q&A)
       - writes: clarifications/<agent-id>-pending.json  →  { "questions": ["...", "..."] }
                                                         or { "questions": [] }  (agent satisfied)
    
    2. If questions is empty OR iteration >= clarifications_max_per_agent: BREAK
    
    3. Orchestrator presents questions in chat:
       "**[Agent Name]'s questions:**
        1. ...
        2. ..."
    
    4. User responds in chat (next message = answers)
    
    5. Orchestrator appends to clarifications/<agent-id>.md:
       "## Round {iteration+1}
        Q: ...  A: ...
        Q: ...  A: ..."
    
    6. iteration++  →  go to step 1

When all agents done:
  Write clarifications/summary.md (all Q&A consolidated, one section per agent)
  Inform the user: "Clarification complete. Starting the debate."
  Delete all *-pending.json files
```

### Key Properties

- **Answers inform follow-ups**: each iteration of the role-clarify subagent reads the full accumulated Q&A from `clarifications/<agent-id>.md`, so its follow-up questions are genuinely guided by what the user has already answered — including answers to other questions in the same round.
- **Per-agent cap**: `convergence.clarifications_max_per_agent` (from config, default 3) limits the maximum iterations per agent. The orchestrator enforces this count.
- **Sequential agents, iterative per agent**: agents take turns. Within each agent's turn, question rounds repeat until satisfied or cap reached.
- **State persists in files**: `clarifications/<agent-id>.md` is the running Q&A log. If the conversation is interrupted, the orchestrator can resume from where it left off.
- **Summary for debate**: `clarifications/summary.md` is passed to every role agent as part of their context for all debate phases, so all agents benefit from all clarifications regardless of who asked.

### Skill Files

```
skills/
├── orchestrate.SKILL.md     # calls clarify.SKILL.md before debate loop if clarifications enabled
├── clarify.SKILL.md         # hosted by orchestrator — conducts the clarification conversation
└── role-clarify.SKILL.md    # subagent: given role + problem + Q&A → outputs question list JSON
```

**`clarify.SKILL.md`** is read by the orchestrator and describes the per-agent loop above. It instructs the orchestrator to present questions conversationally ("as [Agent Name]") and to append the user's answers to the running Q&A file before the next iteration.

**`role-clarify.SKILL.md`** is the subagent task. It reads:
- `prompts/shared/clarify.md` — shared clarification guidelines (ask only high-signal questions, avoid redundancy, return JSON)
- `prompts/<role>/system.md` — role persona (so questions reflect the role's specific perspective)
- `problem.md` and any context files
- `clarifications/<agent-id>.md` if it exists — previous Q&A so far

It outputs `clarifications/<agent-id>-pending.json`: `{ "questions": ["...", "..."] }` or `{ "questions": [] }` to signal that the agent has no more questions.

### Config

```json
"convergence": {
  "max_rounds": 6,
  "judge_threshold": 0.80,
  "criteria": "..."
},
"clarifications": {
  "enabled": true,
  "max_iterations_per_agent": 3
}
```

If `clarifications.enabled` is `false`, the orchestrator skips the clarification phase entirely and proceeds directly to the debate loop. The `max_iterations_per_agent` cap is enforced by the orchestrator regardless of how quickly each agent signals it has no more questions.
