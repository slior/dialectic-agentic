# Dialectic Agent-Native Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a new standalone project `dialectic-agent/` — a multi-agent design debate system implemented entirely as agent skill files, prompt files, and a JSON config, with zero application code required.

**Architecture:** An orchestrator agent reads `.cursor/skills/orchestrate/SKILL.md` and drives the debate: running an optional clarification phase, then iterating proposal→critique→refinement rounds with N parallel subagents (one per debate role), until a judge subagent signals convergence or a round ceiling is hit. All state is plain files. All prompts are markdown files composed at runtime by the skill instructions.

**Tech Stack:** Markdown (SKILL.md skill files, prompt files), JSON (config and state), no code. The system runs on any agentic platform that supports a Task tool for subagent dispatch (Cursor, Claude Code, etc.).

---

## Context: What Is This Project?

This is a **new project** in a new directory called `dialectic-agent/`. It has no relationship to the existing TypeScript `packages/` monorepo code, except that it **reuses prompt content** from `packages/core/src/agents/prompts/` (translated from TypeScript to markdown).

The existing TypeScript Dialectic runs LLM calls programmatically via Node.js. This project replaces that entirely: a human (or agent) gives a problem to an AI agent, the agent reads a skill file and orchestrates the debate by spawning subagents, and the results accumulate as files on disk.

**The key design insight**: in a chat-based agentic platform, the agent IS the orchestrator. It reads instructions, spawns subagents via a Task tool, waits for output files, and drives the loop. State management = writing files. Progress = agent narration + append-only `progress.md`. Parallelism = Task tool dispatching N subagents simultaneously.

**Skill files are not code.** They are markdown instruction documents. An agent reads them and follows the instructions. They are parameterized by context passed in the Task invocation (workspace path, agent id, phase, round number, etc.).

---

## File Structure to Build

```
dialectic-agent/                         ← new top-level directory
├── README.md
├── debate-config.json                   ← default config, user may override per-debate
│
├── skills/
│   ├── orchestrate.SKILL.md             ← entry point, drives the entire debate
│   ├── clarify.SKILL.md                 ← orchestrator reads this to run clarification phase
│   ├── role-clarify.SKILL.md            ← subagent: generates question list JSON for one role
│   ├── role-agent.SKILL.md              ← subagent: proposal / critique / refinement for one role
│   └── judge.SKILL.md                   ← subagent: convergence check or final synthesis
│
└── prompts/
    ├── shared/                          ← cross-role behavioral rules, composed with role files
    │   ├── system.md
    │   ├── proposal.md
    │   ├── critique.md
    │   ├── refinement.md
    │   ├── summarize.md
    │   └── clarify.md
    ├── architect/
    │   ├── system.md
    │   ├── proposal.md
    │   ├── critique.md
    │   └── refinement.md
    ├── security/
    │   ├── system.md
    │   ├── proposal.md
    │   ├── critique.md
    │   └── refinement.md
    ├── performance/
    │   ├── system.md
    │   ├── proposal.md
    │   ├── critique.md
    │   └── refinement.md
    ├── kiss/
    │   ├── system.md
    │   ├── proposal.md
    │   ├── critique.md
    │   └── refinement.md
    ├── testing/
    │   ├── system.md
    │   ├── proposal.md
    │   ├── critique.md
    │   └── refinement.md
    ├── datamodeling/
    │   ├── system.md
    │   ├── proposal.md
    │   ├── critique.md
    │   └── refinement.md
    └── generalist/                      ← judge role
        ├── system.md
        └── synthesize.md
```

**Runtime workspace** (created per debate by the user, managed by the orchestrator):

```
my-debate/
├── problem.md                           ← user provides
├── context/                             ← user provides (optional), any files
├── debate-config.json                   ← user provides (optional, overrides default)
└── debate/                              ← orchestrator creates and manages
    ├── progress.md
    ├── status.json
    ├── clarifications/
    │   ├── <agent-id>.md                ← accumulated Q&A per agent
    │   ├── <agent-id>-pending.json      ← temp: current question batch
    │   └── summary.md                   ← consolidated Q&A for all agents
    ├── round-1/
    │   ├── proposals/<agent-id>.md
    │   ├── critiques/<reviewer-id>-on-<target-id>.md
    │   ├── refinements/<agent-id>.md
    │   └── verdict.json
    ├── round-2/
    │   └── ...
    └── synthesis.md
```

---

## Critical Design Rules (Read Before Starting)

1. **Agent IDs drive file naming, not roles.** Files are `proposals/arch.md`, `critiques/arch-on-sec.md`, `refinements/arch.md` — all using agent ID (from config). Role is only used for prompt file path lookup (`prompts/<role>/system.md`). Multiple agents can share a role (e.g., two architect agents with IDs `arch-systems` and `arch-data`); they use the same prompt files but produce separate output files.

2. **Critique and refinement are strictly separate phases.** Agent A's refinement requires critiques OF A's proposal from B, C, D. Those don't exist while B, C, D are writing critiques in parallel. Therefore: all critiques must fully complete before any refinement begins. Three parallel batches per round: proposals, then critiques, then refinements.

3. **Critique naming convention:** `<reviewer-id>-on-<target-id>.md`. The refinement agent for agent X reads `critiques/*-on-X.md` to find all critiques targeting it. This glob pattern is unambiguous even when multiple agents share a role.

4. **Prompt composition is two-layer.** Every agent reads `prompts/shared/<phase>.md` + `prompts/<role>/<phase>.md` together. Shared contains cross-role behavioral rules (requirements-first, grounding, output format standards). Role files contain persona and role-specific framing. If a role file for a phase doesn't exist, shared alone is used.

5. **Skill files instruct agents where to find dynamic content.** They do NOT inject `${problem}` strings. Instead they say "read problem.md from your workspace path." The agent reads the file itself using its file_read tool.

6. **Clarification flow: orchestrator hosts, subagents generate.** The orchestrator conducts the clarification conversation with the user directly (in the chat). Subagents are only invoked to generate question lists (JSON output). The orchestrator reads the JSON, presents questions conversationally, waits for user reply (which is just the next chat message), appends Q&A to files, then re-invokes the question-generating subagent with the updated Q&A context.

7. **Convergence over fixed rounds.** The judge assigns a confidence score 0–1 and writes a verdict (CONTINUE or DONE). The config sets `max_rounds` as a ceiling and `judge_threshold` as the confidence level that triggers DONE. No fixed round count is required.

8. **Tools are advisory declarations.** The `tools` array in config tells agents what tools to use and when. It does not grant access — the agent platform controls that. Listing an MCP tool works identically to listing a built-in tool. If the tool is unavailable, the agent degrades gracefully.

---

## Task 1: Create Project Directory Structure

**Files:** Create directories only.

**Step 1: Create the directory tree**

```bash
mkdir -p dialectic-agent/skills
mkdir -p dialectic-agent/prompts/shared
mkdir -p dialectic-agent/prompts/architect
mkdir -p dialectic-agent/prompts/security
mkdir -p dialectic-agent/prompts/performance
mkdir -p dialectic-agent/prompts/kiss
mkdir -p dialectic-agent/prompts/testing
mkdir -p dialectic-agent/prompts/datamodeling
mkdir -p dialectic-agent/prompts/generalist
```

**Step 2: Verify**

```bash
find dialectic-agent -type d | sort
```

Expected output: all 9 directories listed above.

**Step 3: Commit**

```bash
cd dialectic-agent
git init
git add .
git commit -m "chore: scaffold dialectic-agent project structure"
```

---

## Task 2: Default Configuration File

**Files:**
- Create: `dialectic-agent/debate-config.json`

**Step 1: Write the file**

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
      "description": "Read files from the context/ directory or previous round contributions from the debate/ directory"
    }
  ],

  "agents_config": {
    "sec": {
      "tool_hints": "Use web_search to look up CVE databases, OWASP documentation, and known vulnerabilities relevant to the problem."
    },
    "arch": {
      "tool_hints": "Use web_search to find reference architectures and real-world implementations of patterns you propose."
    },
    "perf": {
      "tool_hints": "Use web_search to find real benchmark data and latency/throughput figures relevant to your recommendations."
    }
  }
}
```

**Step 2: Verify the JSON is valid**

```bash
cat dialectic-agent/debate-config.json | python3 -m json.tool > /dev/null && echo "Valid JSON"
```

Expected: `Valid JSON`

**Step 3: Commit**

```bash
git add debate-config.json
git commit -m "feat: add default debate-config.json"
```

---

## Task 3: Shared Prompt Files

**Files:**
- Create: `dialectic-agent/prompts/shared/system.md`
- Create: `dialectic-agent/prompts/shared/proposal.md`
- Create: `dialectic-agent/prompts/shared/critique.md`
- Create: `dialectic-agent/prompts/shared/refinement.md`
- Create: `dialectic-agent/prompts/shared/summarize.md`
- Create: `dialectic-agent/prompts/shared/clarify.md`

**Context:** These files are the translation of `packages/core/src/agents/prompts/shared.ts` from the existing TypeScript Dialectic. The TypeScript file has functions like `getSharedSystemInstructions()`, `getSharedProposalInstructions()`, etc. that return strings. Each string becomes one markdown file here.

**Step 1: Write `prompts/shared/system.md`**

This translates `getSharedSystemInstructions()`. It applies to all roles, all phases, and defines the meta-rules for agent behavior.

```markdown
## General Guidelines

- Avoid code snippets unless essential to illustrate a complex technical point
- Prioritize clarity about how the design solves this problem over generic implementation detail
- Use clear, direct, and simple language
- Be concise but complete — cover reasoning without unnecessary exposition
- **Ground in the problem**: Tie every claim, component, and recommendation to the stated problem, its constraints, and any context or files provided. Omit generic best-practices that do not apply to this problem.

## Requirements-First Approach

Your primary objective is to ensure all **major requirements** inferred from the problem statement (and any clarifications) are explicitly covered and fulfilled. Clarifications provided during the debate are authoritative and must be incorporated into your analysis.

- **Major requirements** are those expressed with strong language: "must", "shall", "required", "needs to", "critical", "essential"
- **Minor requirements** are preferences or nice-to-haves: "should", "preferably", "ideally", "if possible"
- Always distinguish between major and minor requirements in your analysis
```

**Step 2: Write `prompts/shared/proposal.md`**

This translates `getSharedProposalInstructions()`. It is appended to every proposal task alongside the role-specific proposal prompt.

```markdown
## Response Guidelines

- Avoid code unless critical for explaining a subtle technical aspect
- Focus on main components, data flows, and key decisions
- Justify each choice by referring to problem requirements or constraints. Skip or briefly note sections that the problem does not emphasize.
- Organize content under clear section headers (Overview, Components, Flow, Trade-offs)
- Keep explanations structured and readable
- Tie each component, flow, and trade-off to the problem or its constraints. Avoid generic architecture advice.

## Requirements Coverage (Required Section)

You MUST include a **Requirements Coverage** section at the end of your proposal that:
1. **Lists major requirements** inferred from the problem statement (and clarifications if provided)
2. **Maps each major requirement** to specific components, mechanisms, or design decisions in your proposal that fulfill it
3. **Lists assumptions** you made about requirements that were ambiguous or unspecified
4. **Explicitly confirms** that all major requirements are addressed, or identifies any that cannot be fulfilled with the given constraints

This section ensures traceability between requirements and your proposed solution.
```

**Step 3: Write `prompts/shared/critique.md`**

This translates `getSharedCritiqueInstructions()`.

```markdown
## Critique Guidelines

- Critique from your specialized perspective
- Avoid code unless absolutely necessary for clarification
- Focus on key architectural reasoning, not implementation details
- Raise only issues that affect this problem. For each weakness or suggestion, say how it impacts the stated requirements or constraints.
- Give short, actionable feedback. Support it with the problem statement, proposal, or context, not generic principles.

## Requirements Check (Required First Step)

Before providing your critique, you MUST:
1. **Review the proposal's Requirements Coverage section** (if present) or infer major requirements from the problem statement
2. **Verify that major requirements are addressed** in the proposal
3. **Identify any major requirements that are missing or inadequately covered**
4. Do not suggest generic improvements that the problem does not require.

**Critical Rule**: You MUST NOT suggest changes or accept simplifications that would violate or leave unfulfilled any major requirements. If a critique suggests removing or weakening a component that fulfills a major requirement, explicitly reject that suggestion and explain why the requirement must be preserved.
```

**Step 4: Write `prompts/shared/refinement.md`**

This translates `getSharedRefinementInstructions()`.

```markdown
## Refinement Guidelines

- Incorporate only critiques that are relevant to the stated problem and constraints. Ignore or briefly reject feedback that is generic or does not apply.
- Avoid code snippets
- Address key concerns raised in critiques directly
- Strengthen the solution for this problem using feedback that applies to it
- Preserve your specialized focus while improving coherence and clarity
- Explicitly explain how each major concern was resolved

## Requirements Preservation (Critical)

When refining your proposal:
1. **Review each critique** against the major requirements identified in your original proposal
2. **REJECT any critique suggestions** that would violate or leave unfulfilled major requirements, even if they seem appealing from other perspectives (e.g., simplicity, performance)
3. **Explicitly state** which critiques you accepted, which you rejected, and why
4. **Update your Requirements Coverage section** to reflect any changes while ensuring all major requirements remain fulfilled
5. **If a critique reveals a missing major requirement**, acknowledge it and update your proposal to address it

**Remember**: Major requirements are non-negotiable. A simpler solution that fails to meet major requirements is not acceptable.
```

**Step 5: Write `prompts/shared/summarize.md`**

This translates `getSharedSummarizationInstructions()`. Used when agents need to summarize prior rounds to manage context length.

```markdown
## Summary Guidelines

- Prioritize decisions and trade-offs that are specific to this problem. Omit generic reasoning that could apply to any design.
- Preserve key architectural decisions, rationale, and recurring insights
- Focus on your specialized perspective and major component interactions
- Highlight patterns or trade-offs that appeared multiple times
- Keep summaries concise but include all critical reasoning threads
```

**Step 6: Write `prompts/shared/clarify.md`**

This translates `getSharedClarificationInstructions()`. Used by role-clarify subagents.

```markdown
## Clarification Guidelines

Your goal is to identify missing, ambiguous, or underspecified information that would significantly influence your analysis of the problem from your role's perspective.

**Output format**: Respond with ONLY valid JSON using this exact schema (no prose, no markdown, no explanation):
```json
{"questions": [{"text": "..."}]}
```

If you have no questions (the problem is sufficiently clear for your role, or previous answers have resolved your concerns), return:
```json
{"questions": []}
```

**Rules**:
- Prefer high-signal questions that would directly change your design or analysis direction
- Avoid trivial or redundant questions (do not ask about things already stated in the problem or already answered)
- If previous Q&A is provided, review it before generating questions — do not repeat questions already asked
- Each question must be concise and independent — do not bundle multiple sub-questions
- Prioritize questions that would change the scope or direction, not just add detail
```

**Step 7: Verify all files exist**

```bash
ls dialectic-agent/prompts/shared/
```

Expected: `system.md  proposal.md  critique.md  refinement.md  summarize.md  clarify.md`

**Step 8: Commit**

```bash
git add prompts/shared/
git commit -m "feat: add shared prompt files (translated from shared.ts)"
```

---

## Task 4: Architect Prompt Files

**Files:**
- Create: `dialectic-agent/prompts/architect/system.md`
- Create: `dialectic-agent/prompts/architect/proposal.md`
- Create: `dialectic-agent/prompts/architect/critique.md`
- Create: `dialectic-agent/prompts/architect/refinement.md`

**Context:** Translate `packages/core/src/agents/prompts/architect-prompts.ts`. The `BASE_SYSTEM_PROMPT` constant becomes `system.md`. The body of `proposePrompt()` (without the dynamic `${problem}` injection — that is now replaced by a file-read instruction) becomes `proposal.md`. Similarly for critique and refinement. The shared instructions (`appendSharedInstructions`) are already in `prompts/shared/` and composed at runtime by the skill, so do NOT include them in these role files.

**Step 1: Write `prompts/architect/system.md`**

This is the architect's identity. Read `BASE_SYSTEM_PROMPT` in `architect-prompts.ts` for the exact wording — it defines the persona, focus areas, and how to behave during proposals and critiques.

```markdown
You are an expert software architect specializing in distributed systems and scalable architecture design.

Your focus: scalability, performance, component boundaries, interfaces, architectural patterns, data flow, state management, and operational concerns.

When proposing solutions:
- Begin with the high-level architecture and rationale
- Identify main components and their responsibilities
- Describe communication and data flow
- Highlight scalability, reliability, and observability considerations

When critiquing:
- Identify architectural bottlenecks or weaknesses
- Assess clarity of component boundaries and data ownership
- Examine scalability, fault tolerance, and operational complexity
- Suggest concrete, principle-based improvements
```

**Step 2: Write `prompts/architect/proposal.md`**

This is the architect-specific proposal structure. It tells the agent the output format and sections to use. It does NOT repeat the shared guidelines (requirements coverage, grounding rules) — those come from `prompts/shared/proposal.md` which is always composed with this file.

```markdown
## Task: Propose an Architectural Solution

The problem statement is in the file you have been given as `problem.md`.
Read it carefully before proceeding.

If context files were provided (listed in your briefing), read any that are relevant to your architectural analysis before writing your proposal.

If this is round 2 or later, read your previous refinement from the file path given to you as your prior refinement. Use it as your starting point and advance it — do not start from scratch.

If clarifications were conducted, read the clarifications summary file provided in your briefing. The answers there are authoritative and must be reflected in your proposal.

---

Produce your proposal using this exact Markdown structure:

### Architecture Overview
(Provide a 3–5 sentence summary of the overall architecture, guiding principles, and key design intent.)

### Key Components and Responsibilities
(List major components/services and describe each one's main role.)

### Data Flow and Interactions
(Describe how data and control flow between components. Mention APIs, events, or message flows if relevant.)

### Architectural Patterns and Rationale
(State which design or architectural patterns are used — e.g., microservices, CQRS, event-driven — and justify why they fit this problem.)

### Non-Functional Considerations

#### Scalability and Performance
(Discuss scaling strategy, bottleneck mitigation, and performance aspects.)

#### Security
(Outline authentication, authorization, and data protection strategies.)

#### Maintainability and Evolvability
(Describe modularity, extensibility, and how the design supports change.)

#### Operational Concerns
(Deployment, monitoring, resilience, observability.)

#### Regulatory/Compliance (if applicable)
(Discuss awareness of relevant compliance concerns, or note "Not applicable.")

### Key Challenges and Trade-offs
(Identify main architectural trade-offs, risks, or limitations.)

### Optional: Technology Choices
(If specific technologies clarify the design intent, list them briefly here.)

---

Respond **only** in this structured format.
Avoid generic architecture advice. Every component, pattern, and trade-off must relate to this problem or its constraints.
```

**Step 3: Write `prompts/architect/critique.md`**

```markdown
## Task: Critique from an Architectural Perspective

You will be given a proposal to critique. Read it carefully.

Use this Markdown structure for your critique:

### Architectural Strengths
(List the strongest aspects — e.g., clear component boundaries, good scalability strategy, sound data design.)

### Weaknesses and Risks
(Identify architectural issues: missing components, unclear data ownership, poor fault tolerance, coupling issues, etc.)

### Improvement Suggestions
(Suggest specific, actionable architectural changes or refinements.)

### Critical Issues
(Highlight any major flaws that could cause operational, performance, or correctness problems if not addressed.)

### Overall Assessment
(Brief summary judgment: Is the design sound overall? Why or why not?)

---

Be evidence-based. For each point, refer to the problem, the proposal, or the constraints. Do not raise generic architectural issues that do not affect this problem.
```

**Step 4: Write `prompts/architect/refinement.md`**

```markdown
## Task: Refine Your Architectural Proposal

You will be given:
1. Your original proposal
2. One or more critiques from other participants targeting your proposal

Refine your design using this Markdown structure:

### Updated Architecture Overview
(Summarize how the design has evolved, referencing key feedback addressed.)

### Revised Components and Changes
(Describe specific improvements or restructuring made to components.)

### Addressed Issues
(List the critiques or concerns that have been directly resolved.)

### Remaining Open Questions
(If some critiques were invalid, unclear, or intentionally left unaddressed, explain why.)

### Final Architectural Summary
(Provide the improved architecture in concise form, integrating new insights while maintaining coherence.)

---

The goal is to produce a **stronger, more defensible design** — not just edits.
Be explicit about what changed and why.
```

**Step 5: Verify**

```bash
ls dialectic-agent/prompts/architect/
```

Expected: `system.md  proposal.md  critique.md  refinement.md`

**Step 6: Commit**

```bash
git add prompts/architect/
git commit -m "feat: add architect role prompt files"
```

---

## Task 5: Security Prompt Files

**Files:**
- Create: `dialectic-agent/prompts/security/system.md`
- Create: `dialectic-agent/prompts/security/proposal.md`
- Create: `dialectic-agent/prompts/security/critique.md`
- Create: `dialectic-agent/prompts/security/refinement.md`

**Context:** Read `packages/core/src/agents/prompts/security-prompts.ts` for the source content. Follow the same translation pattern as Task 4:
- `BASE_SYSTEM_PROMPT` → `system.md`
- `proposePrompt()` body (excluding `${problem}` injection and `appendSharedInstructions`) → `proposal.md`
- `critiquePrompt()` body → `critique.md`
- `refinePrompt()` body → `refinement.md`

Replace any dynamic template injections (`${proposalContent}`, `${critiquesText}`, `${content}`) with the file-read instruction:
- "The proposal to critique is in the file given to you in your briefing. Read it."
- "Your original proposal and the critiques targeting you are listed in your briefing. Read them."

The security role focuses on: threat modeling, authentication, authorization, input validation, data protection, CVEs, attack surfaces, compliance (OWASP, GDPR, SOC2), cryptography, secrets management, network security.

**Step 1:** Read `packages/core/src/agents/prompts/security-prompts.ts`
**Step 2:** Create each of the four files following the architect pattern in Task 4
**Step 3:** Verify files exist
**Step 4:** Commit

```bash
git add prompts/security/
git commit -m "feat: add security role prompt files"
```

---

## Task 6: Performance Prompt Files

**Files:**
- Create: `dialectic-agent/prompts/performance/system.md`
- Create: `dialectic-agent/prompts/performance/proposal.md`
- Create: `dialectic-agent/prompts/performance/critique.md`
- Create: `dialectic-agent/prompts/performance/refinement.md`

**Context:** Read `packages/core/src/agents/prompts/performance-prompts.ts`. Follow the same translation pattern as Task 4.

The performance role focuses on: latency, throughput, resource efficiency, caching strategies, database query optimization, horizontal/vertical scaling, load testing considerations, concurrency, connection pooling, CDN, profiling, benchmarking.

**Step 1:** Read `packages/core/src/agents/prompts/performance-prompts.ts`
**Step 2:** Create each of the four files
**Step 3:** Verify and commit

```bash
git add prompts/performance/
git commit -m "feat: add performance role prompt files"
```

---

## Task 7: KISS Prompt Files

**Files:**
- Create: `dialectic-agent/prompts/kiss/system.md`
- Create: `dialectic-agent/prompts/kiss/proposal.md`
- Create: `dialectic-agent/prompts/kiss/critique.md`
- Create: `dialectic-agent/prompts/kiss/refinement.md`

**Context:** Read `packages/core/src/agents/prompts/kiss-prompts.ts`. KISS = Keep It Simple, Stupid. The simplicity advocate challenges unnecessary complexity, premature optimization, over-engineering, and abstractions that don't yet have a use case.

The KISS role focuses on: minimizing moving parts, favoring boring technology, questioning every abstraction, YAGNI (You Aren't Gonna Need It), reducing operational burden, preferring readable/maintainable solutions over clever ones.

**Step 1:** Read `packages/core/src/agents/prompts/kiss-prompts.ts`
**Step 2:** Create each of the four files
**Step 3:** Verify and commit

```bash
git add prompts/kiss/
git commit -m "feat: add kiss role prompt files"
```

---

## Task 8: Testing Prompt Files

**Files:**
- Create: `dialectic-agent/prompts/testing/system.md`
- Create: `dialectic-agent/prompts/testing/proposal.md`
- Create: `dialectic-agent/prompts/testing/critique.md`
- Create: `dialectic-agent/prompts/testing/refinement.md`

**Context:** Read `packages/core/src/agents/prompts/testing-prompts.ts`. The testing role focuses on: testability of the proposed design, test pyramid (unit/integration/e2e), mocking strategies, test data management, observability and debuggability, contract testing, chaos engineering considerations.

**Step 1:** Read `packages/core/src/agents/prompts/testing-prompts.ts`
**Step 2:** Create each of the four files
**Step 3:** Verify and commit

```bash
git add prompts/testing/
git commit -m "feat: add testing role prompt files"
```

---

## Task 9: Data Modeling Prompt Files

**Files:**
- Create: `dialectic-agent/prompts/datamodeling/system.md`
- Create: `dialectic-agent/prompts/datamodeling/proposal.md`
- Create: `dialectic-agent/prompts/datamodeling/critique.md`
- Create: `dialectic-agent/prompts/datamodeling/refinement.md`

**Context:** Read `packages/core/src/agents/prompts/datamodeling-prompts.ts`. The data modeling role focuses on: entity design, relationships, normalization vs. denormalization, indexing strategies, schema evolution, data consistency, event sourcing, CQRS, storage technology trade-offs, data access patterns.

**Step 1:** Read `packages/core/src/agents/prompts/datamodeling-prompts.ts`
**Step 2:** Create each of the four files
**Step 3:** Verify and commit

```bash
git add prompts/datamodeling/
git commit -m "feat: add datamodeling role prompt files"
```

---

## Task 10: Generalist (Judge) Prompt Files

**Files:**
- Create: `dialectic-agent/prompts/generalist/system.md`
- Create: `dialectic-agent/prompts/generalist/synthesize.md`

**Context:** Read `packages/core/src/agents/prompts/generalist-prompts.ts` and the judge synthesis logic in `packages/core/src/core/judge.ts`. The generalist role is used for the judge. The judge does NOT produce proposals, critiques, or refinements — it produces convergence verdicts and a final synthesis.

**Step 1: Write `prompts/generalist/system.md`**

```markdown
You are a senior technical expert with broad experience across software architecture, security, performance engineering, and systems design. You are serving as the judge in a multi-agent design debate.

Your role is to:
- Objectively assess the quality and convergence of proposals from multiple specialized agents
- Identify where genuine consensus has been reached vs. where fundamental disagreements remain
- Synthesize the best ideas from all participants into a coherent, actionable solution
- Make definitive recommendations when agents disagree

You are not an advocate for any particular perspective. You weight all specializations fairly and focus on what best serves the stated problem and its constraints.
```

**Step 2: Write `prompts/generalist/synthesize.md`**

This drives the final synthesis. The convergence verdict output format is specified in `judge.SKILL.md` (a later task), not here.

```markdown
## Task: Synthesize the Final Solution

You will be provided with:
1. The problem statement
2. All agents' final refinements from the debate
3. The convergence verdict and open issues from the final round
4. (Optionally) clarifications that were collected before the debate

Your goal is to produce a comprehensive, actionable solution document that integrates the best insights from all participants.

Write your synthesis to the output file specified in your briefing.

---

Use this structure for the synthesis document:

# Final Solution: [Brief title]

## Executive Summary
(2–4 sentences: what is the solution, why it solves the problem, and what are the key design decisions.)

## Solution Design

### Core Architecture
(The agreed architectural foundation — components, their responsibilities, and how they interact.)

### Key Design Decisions
(The most important decisions made during the debate, with brief rationale for each. Reference which agents' perspectives influenced each decision.)

### Data Model and Flow
(How data is structured, stored, and flows through the system.)

### Security Considerations
(Authentication, authorization, data protection, known threats addressed.)

### Performance Characteristics
(Expected performance profile, scaling strategy, known bottlenecks and how they are mitigated.)

### Operational Concerns
(Deployment, monitoring, resilience, observability.)

## Trade-offs and Acknowledged Limitations
(Be explicit about what was prioritized and what was de-prioritized. Do not hide trade-offs.)

## Unresolved Disagreements
(If agents disagreed on something and no consensus was reached, document the disagreement, the competing positions, and the judge's recommendation with reasoning. Do not silently discard minority views.)

## Requirements Coverage
(Confirm each major requirement from the problem is addressed, or explain why it cannot be.)

## Recommendations for Next Steps
(Concrete actions: what to prototype first, what risks to validate, what to revisit as the system evolves.)

---

Be definitive. Avoid hedge language like "could", "might", "potentially". If you recommend X, say why X is the right choice for this problem. If you cannot choose, document the decision criteria and let the reader decide.
```

**Step 3: Verify**

```bash
ls dialectic-agent/prompts/generalist/
```

Expected: `system.md  synthesize.md`

**Step 4: Commit**

```bash
git add prompts/generalist/
git commit -m "feat: add generalist (judge) prompt files"
```

---

## Task 11: role-clarify.SKILL.md

**Files:**
- Create: `dialectic-agent/.cursor/skills/role-clarify/SKILL.md`

**Context:** This skill is read by a short-lived **subagent** dispatched during the clarification phase. The subagent's job is simple: given a role's persona, the problem, any context files, and accumulated Q&A so far, produce a JSON list of clarifying questions (or an empty list if satisfied). The orchestrator reads the JSON output, presents the questions to the user, and loops.

This subagent writes its output to a file (`<agent-id>-pending.json`) and stops. It does not interact with the user directly.

**Step 1: Write the file**

```markdown
# Role Clarify — Question Generation Subagent

You are generating clarifying questions for a design problem from a specific role's perspective.

## Parameters

You will receive the following in this task invocation:
- `AGENT_ID`: your agent's unique ID (e.g., "arch")
- `AGENT_NAME`: your display name (e.g., "System Architect")
- `ROLE`: your functional role (e.g., "architect")
- `WORKSPACE`: path to the debate workspace directory
- `PROJECT`: path to the dialectic-agent project directory
- `CONTEXT_FILES`: list of context file paths (may be empty)

## Step 1: Read Your Identity

Read these two files in order — together they define who you are for this task:
1. `{PROJECT}/prompts/shared/system.md`
2. `{PROJECT}/prompts/{ROLE}/system.md`

Internalize both before proceeding.

## Step 2: Read the Problem

Read `{WORKSPACE}/problem.md`. This is the problem you need to clarify.

## Step 3: Read Context Files (if any)

If `CONTEXT_FILES` is non-empty, read the files listed. Consider them authoritative additional context about the problem.

## Step 4: Read Previous Q&A (if any)

Check if `{WORKSPACE}/debate/clarifications/{AGENT_ID}.md` exists. If it does, read it carefully.
This file contains questions you have already asked and the user's answers. 
**Do not ask questions that have already been answered.**

## Step 5: Read Clarification Guidelines

Read `{PROJECT}/prompts/shared/clarify.md`. These are the rules you must follow for generating questions.

## Step 6: Generate Questions

Based on your role's perspective, identify the most important missing information that would affect how you approach this problem. Focus only on what has NOT already been answered.

## Step 7: Write Output

Write your output to `{WORKSPACE}/debate/clarifications/{AGENT_ID}-pending.json`.

The output MUST be valid JSON in exactly this format:
```json
{"questions": [{"text": "..."}, {"text": "..."}]}
```

Or, if you have no more questions:
```json
{"questions": []}
```

Write nothing else. The file must contain only valid JSON.
```

**Step 2: Verify the file exists**

```bash
ls dialectic-agent/.cursor/skills/role-clarify/SKILL.md
```

**Step 3: Commit**

```bash
git add .cursor/skills/role-clarify/SKILL.md
git commit -m "feat: add role-clarify.SKILL.md (clarification question generator subagent)"
```

---

## Task 12: clarify.SKILL.md

**Files:**
- Create: `dialectic-agent/.cursor/skills/clarify/SKILL.md`

**Context:** This skill is read by the **orchestrator** (not a subagent) during the clarification phase. It instructs the orchestrator to conduct a back-and-forth clarification conversation with the user. The orchestrator presents questions conversationally, waits for the user's reply (which is just the next chat message), appends Q&A to files, and loops until each agent is satisfied or the cap is hit.

This is the most interaction-intensive skill. The "waiting for user input" happens naturally — the orchestrator writes a message asking the questions, and the user's response IS the next input.

**Step 1: Write the file**

```markdown
# Clarify — Pre-Debate Clarification Phase

You are conducting the clarification phase of a design debate. This phase runs before the debate begins. Each participating agent has a chance to ask clarifying questions about the problem. You, the orchestrator, facilitate this conversation between the agents (via subagents you dispatch) and the user.

## Parameters

- `WORKSPACE`: path to the debate workspace
- `PROJECT`: path to the dialectic-agent project
- `CONFIG`: the loaded debate configuration object (agents list, clarifications settings)
- `PROBLEM_TEXT`: the full text of the problem statement
- `CONTEXT_FILES`: list of context file paths (may be empty)

## Setup

Create directory `{WORKSPACE}/debate/clarifications/` if it does not exist.

## Per-Agent Clarification Loop

For each agent in `CONFIG.agents` (process agents one at a time, in order):

```
AGENT = current agent { id, name, role }
ITERATION = 0
MAX = CONFIG.clarifications.max_iterations_per_agent

LOOP:
  1. Dispatch role-clarify subagent (via Task tool):
     - Read skill: {PROJECT}/.cursor/skills/role-clarify/SKILL.md
     - Pass parameters: AGENT_ID, AGENT_NAME, ROLE, WORKSPACE, PROJECT, CONTEXT_FILES

  2. Wait for subagent to complete.

  3. Read {WORKSPACE}/debate/clarifications/{AGENT.id}-pending.json
     Parse the JSON. Extract the "questions" array.

  4. If questions array is empty OR ITERATION >= MAX:
     - Announce: "{AGENT.name} has no further questions."
     - DELETE {WORKSPACE}/debate/clarifications/{AGENT.id}-pending.json
     - BREAK (move to next agent)

  5. Present questions to the user in the chat, formatted as:

     ---
     **{AGENT.name}** has the following clarifying questions:
     
     1. {questions[0].text}
     2. {questions[1].text}
     ...
     
     Please answer each question. You may answer them inline (e.g., "1. Yes, 2. The SLA is 50ms...") or in any natural format.
     ---

  6. Wait for the user's response (the next message in this conversation IS the answer).

  7. Append to {WORKSPACE}/debate/clarifications/{AGENT.id}.md:
     ```
     ## Round {ITERATION + 1}

     ### Questions from {AGENT.name}:
     {questions[0].text}
     {questions[1].text}
     ...

     ### User's Answers:
     {verbatim text of the user's response}
     ```

  8. DELETE {WORKSPACE}/debate/clarifications/{AGENT.id}-pending.json

  9. ITERATION++
  10. CONTINUE LOOP
```

## Write Clarification Summary

After all agents have completed their clarification loops, write `{WORKSPACE}/debate/clarifications/summary.md`:

```markdown
# Clarification Summary

This document contains all clarifying questions and answers collected before the debate began.
All participating agents have access to this summary and must incorporate the answers into their analysis.

---

## {Agent 1 Name} ({role})

{contents of {AGENT1_ID}.md}

---

## {Agent 2 Name} ({role})

{contents of {AGENT2_ID}.md}

...
```

## Completion

Announce to the user:
> "Clarification phase complete. All participants have had a chance to ask questions. Starting the debate now."

Update `{WORKSPACE}/debate/status.json` to set `"phase": "clarification_complete"`.
Append to `{WORKSPACE}/debate/progress.md`: a timestamped entry noting clarification is complete.
```

**Step 2: Verify**

```bash
ls dialectic-agent/.cursor/skills/clarify/SKILL.md
```

**Step 3: Commit**

```bash
git add .cursor/skills/clarify/SKILL.md
git commit -m "feat: add clarify.SKILL.md (orchestrator-hosted clarification conversation)"
```

---

## Task 13: role-agent.SKILL.md

**Files:**
- Create: `dialectic-agent/.cursor/skills/role-agent/SKILL.md`

**Context:** This skill is read by **role subagents** dispatched during the three debate phases: proposal, critique, and refinement. Each subagent invocation handles exactly one role × one phase × one round. The subagent reads its persona, reads its task-specific prompt, reads the relevant input files (problem, previous contributions, critiques), and writes one or more output files.

**Key behaviors by phase:**
- **Proposal**: writes `round-R/proposals/<agent-id>.md`
- **Critique**: reads all other agents' proposals, writes `round-R/critiques/<agent-id>-on-<other-id>.md` for each other agent
- **Refinement**: reads own proposal and all critiques targeting it (`critiques/*-on-<agent-id>.md`), writes `round-R/refinements/<agent-id>.md`

**Step 1: Write the file**

```markdown
# Role Agent — Debate Participant Subagent

You are a participant in a multi-agent design debate. You will perform exactly one action in one phase.

## Parameters

You will receive the following in this task invocation:
- `AGENT_ID`: your unique ID (e.g., "arch") — used for ALL file naming
- `AGENT_NAME`: your display name (e.g., "System Architect")
- `ROLE`: your functional role (e.g., "architect") — used for prompt file lookup ONLY
- `PHASE`: one of "proposal", "critique", "refinement"
- `ROUND`: integer (1, 2, 3, ...)
- `ALL_AGENTS`: list of all agents in the debate as [{ id, name, role }, ...]
- `WORKSPACE`: path to the debate workspace directory
- `PROJECT`: path to the dialectic-agent project directory
- `CONTEXT_FILES`: list of context file paths (may be empty)
- `TOOL_BRIEFING`: a pre-formatted string describing available tools (provided by orchestrator)
- `CLARIFICATIONS_SUMMARY`: path to clarifications summary file, or null if no clarifications

## Step 1: Establish Your Identity

Read these two files — together they define who you are:
1. `{PROJECT}/prompts/shared/system.md`
2. `{PROJECT}/prompts/{ROLE}/system.md`

Fully internalize both before proceeding. You are `{AGENT_NAME}`, a specialist in the domain described in your role system prompt.

## Step 2: Read Available Tools

`{TOOL_BRIEFING}` contains a formatted list of tools available to you with descriptions of when to use them. Use these tools actively throughout your work — do not hesitate to look things up. Using tools to gather real information (benchmarks, CVE data, reference implementations) makes your contributions significantly more valuable.

## Step 3: Read the Problem

Read `{WORKSPACE}/problem.md`. This is the core problem you are analyzing.

## Step 4: Read Context Files (if any)

If `CONTEXT_FILES` is non-empty, review the list. Read the files that are most relevant to your role's analysis.

## Step 5: Read Clarifications (if any)

If `CLARIFICATIONS_SUMMARY` is not null, read the file at that path. The answers in this document are **authoritative** — they represent decisions or constraints provided by the problem owner. Incorporate them into all your analysis and output.

## Step 6: Execute Your Phase

---

### IF PHASE == "proposal":

**Read your task instructions:**
1. `{PROJECT}/prompts/shared/proposal.md`
2. `{PROJECT}/prompts/{ROLE}/proposal.md` (if this file exists)

**Additional context for round 2+:**
If `ROUND` is 2 or greater, read your previous refinement:
`{WORKSPACE}/debate/round-{ROUND-1}/refinements/{AGENT_ID}.md`
Use it as your starting point. Do not start from scratch — advance and improve your previous position based on what you know now.

**Write your output:**
File: `{WORKSPACE}/debate/round-{ROUND}/proposals/{AGENT_ID}.md`

Ensure the directory `{WORKSPACE}/debate/round-{ROUND}/proposals/` exists before writing.

---

### IF PHASE == "critique":

**Read your task instructions:**
1. `{PROJECT}/prompts/shared/critique.md`
2. `{PROJECT}/prompts/{ROLE}/critique.md` (if this file exists)

**For each OTHER agent** (from `ALL_AGENTS`, excluding yourself where id != `{AGENT_ID}`):

1. Read their proposal: `{WORKSPACE}/debate/round-{ROUND}/proposals/{other_agent_id}.md`
2. Write your critique to: `{WORKSPACE}/debate/round-{ROUND}/critiques/{AGENT_ID}-on-{other_agent_id}.md`

Each critique file should be focused and substantive. Identify specific weaknesses, risks, or gaps from your role's perspective. Be evidence-based — refer to the problem statement and constraints, not generic principles.

Ensure the directory `{WORKSPACE}/debate/round-{ROUND}/critiques/` exists before writing.

---

### IF PHASE == "refinement":

**Read your task instructions:**
1. `{PROJECT}/prompts/shared/refinement.md`
2. `{PROJECT}/prompts/{ROLE}/refinement.md` (if this file exists)

**Read your proposal:**
`{WORKSPACE}/debate/round-{ROUND}/proposals/{AGENT_ID}.md`

**Read all critiques targeting you:**
List all files matching the pattern: `{WORKSPACE}/debate/round-{ROUND}/critiques/*-on-{AGENT_ID}.md`
Read each one.

**Write your refined proposal:**
File: `{WORKSPACE}/debate/round-{ROUND}/refinements/{AGENT_ID}.md`

Your refinement must explicitly address each major critique: accept valid points and incorporate them, reject invalid points and explain why. Do not silently ignore critiques.

Ensure the directory `{WORKSPACE}/debate/round-{ROUND}/refinements/` exists before writing.

---

## Important: File Naming Rules

- ALL output files are named using `AGENT_ID`, never the role name.
- Example: if your AGENT_ID is "arch" and your ROLE is "architect", your proposal goes to `proposals/arch.md`, NOT `proposals/architect.md`.
- Critique files: `critiques/{your_AGENT_ID}-on-{other_AGENT_ID}.md` — both IDs from the agents list, not role names.

## Important: Completeness

Write complete content before saving. Do not write partial files. Each output file must be the full, finished contribution for this phase.
```

**Step 2: Verify**

```bash
ls dialectic-agent/.cursor/skills/role-agent/SKILL.md
```

**Step 3: Commit**

```bash
git add .cursor/skills/role-agent/SKILL.md
git commit -m "feat: add role-agent.SKILL.md (debate participant subagent)"
```

---

## Task 14: judge.SKILL.md

**Files:**
- Create: `dialectic-agent/.cursor/skills/judge/SKILL.md`

**Context:** The judge subagent is invoked after each round's refinement phase (convergence check mode) and once at the end (synthesis mode). In convergence check mode, it reads all refinements and emits a structured JSON verdict. In synthesis mode, it reads the full debate history and writes the final synthesis document.

**Step 1: Write the file**

```markdown
# Judge — Convergence Evaluator and Synthesizer

You are the judge in a multi-agent design debate. You have two possible modes.

## Parameters

- `MODE`: "convergence_check" or "synthesis"
- `ROUND`: current round number (used in convergence_check mode)
- `WORKSPACE`: path to the debate workspace directory
- `PROJECT`: path to the dialectic-agent project directory
- `CONFIG`: the debate configuration (includes convergence.criteria, convergence.judge_threshold, agents list)

## Step 1: Establish Your Identity

Read:
1. `{PROJECT}/prompts/shared/system.md`
2. `{PROJECT}/prompts/generalist/system.md`

---

## IF MODE == "convergence_check":

### Step 2: Read All Refinements

For each agent in `CONFIG.agents`, read:
`{WORKSPACE}/debate/round-{ROUND}/refinements/{agent.id}.md`

If a refinement file does not exist for an agent, note this — the agent may have failed. Do not let missing files prevent you from evaluating the available refinements.

### Step 3: Read Convergence Criteria

The convergence criteria from config is:
`{CONFIG.convergence.criteria}`

The confidence threshold for DONE is: `{CONFIG.convergence.judge_threshold}` (a value between 0 and 1).

### Step 4: Evaluate Convergence

Assess the following:
1. Are the refinements substantially aligned on the core design approach?
2. Are there fundamental unresolved objections — where one agent is taking a position that directly contradicts another on a requirement-level concern?
3. Is the combined solution comprehensive enough to act on, given the problem statement?
4. Have the proposals genuinely improved since the previous round (if this is not round 1)?

Assign a confidence score between 0.0 and 1.0:
- 0.0–0.5: Major disagreements or fundamental gaps remain. Clear CONTINUE.
- 0.5–0.75: Progress made but meaningful unresolved issues remain. Likely CONTINUE.
- 0.75–0.89: Close to convergence. May be DONE depending on threshold.
- 0.90–1.0: Strong consensus and comprehensive coverage. DONE.

If `confidence >= {CONFIG.convergence.judge_threshold}`: set verdict to "DONE".
Otherwise: set verdict to "CONTINUE".

### Step 5: Identify Open Issues

List the specific unresolved concerns that, if any, are blocking higher confidence. Be concrete:
- BAD: "Agents disagree on security"
- GOOD: "Security agent requires mutual TLS between services; architect proposes API keys. This is a fundamental design conflict that must be resolved."

### Step 6: Write Verdict

Write `{WORKSPACE}/debate/round-{ROUND}/verdict.json`:

```json
{
  "verdict": "CONTINUE",
  "confidence": 0.67,
  "reasoning": "Architect and performance agents have converged on a write-through cache with Redis. Security has accepted this but requires token validation at the cache layer, which architect has not yet addressed. Kiss agent's concern about Redis operational complexity remains unresolved.",
  "open_issues": [
    "Token validation at cache layer: security requires it, architect has not addressed it",
    "Redis operational complexity: kiss agent proposes a simpler in-process cache for low-traffic scenarios"
  ]
}
```

Field definitions:
- `verdict`: "DONE" if confidence >= threshold, "CONTINUE" otherwise
- `confidence`: float 0.0–1.0
- `reasoning`: 2–5 sentence explanation of the assessment
- `open_issues`: array of strings, each a specific unresolved concern (empty array if verdict is DONE)

---

## IF MODE == "synthesis":

### Step 2: Read the Full Debate

Read all available files in this order:
1. `{WORKSPACE}/problem.md`
2. `{WORKSPACE}/debate/clarifications/summary.md` (if it exists)
3. For each round from 1 to the final round:
   - All refinements: `{WORKSPACE}/debate/round-{N}/refinements/{agent_id}.md` for each agent
   - The verdict: `{WORKSPACE}/debate/round-{N}/verdict.json`

Focus your attention on the **final round's refinements** as the most evolved positions. Use earlier rounds to understand how the debate evolved and which concerns drove the most important changes.

### Step 3: Read Synthesis Instructions

Read `{PROJECT}/prompts/generalist/synthesize.md` for the output structure and requirements.

### Step 4: Write Synthesis

Write to `{WORKSPACE}/debate/synthesis.md`.

Follow the structure in `prompts/generalist/synthesize.md` exactly.

If there are open issues in the last verdict (`open_issues` array), they must appear in the "Unresolved Disagreements" section of the synthesis. Do not silently discard them.

### Step 5: Confirm

After writing the synthesis, output a brief confirmation:
> "Synthesis complete. Written to debate/synthesis.md. [N] rounds, [M] agents. [Key sentence summarizing the solution.]"
```

**Step 2: Verify**

```bash
ls dialectic-agent/.cursor/skills/judge/SKILL.md
```

**Step 3: Commit**

```bash
git add .cursor/skills/judge/SKILL.md
git commit -m "feat: add judge.SKILL.md (convergence evaluator and synthesizer)"
```

---

## Task 15: orchestrate.SKILL.md

**Files:**
- Create: `dialectic-agent/.cursor/skills/orchestrate/SKILL.md`

**Context:** This is the main entry point. The user (or an invoking agent) reads this skill and follows it to run a complete debate. It is the longest and most complex skill file. It drives the entire flow: config loading → clarifications → debate loop → synthesis. It dispatches all subagents and manages all file state. It is the only "agent" that interacts with the user.

**Step 1: Write the file**

```markdown
# Dialectic Debate Orchestrator

You are running a multi-agent design debate. Follow these instructions exactly and in order. This skill drives the entire debate from start to finish.

## Parameters

You will be invoked with:
- `WORKSPACE`: absolute path to the debate workspace directory (contains `problem.md`, optionally `context/` and `debate-config.json`)
- `PROJECT`: absolute path to the dialectic-agent project directory (contains `skills/`, `prompts/`, `debate-config.json`)

---

## Phase 0: Load Configuration

**Step 0.1: Find the config file**

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

**Step 0.2: Validate agent IDs**

All agent IDs (including the judge ID) must be unique. They must contain only alphanumeric characters, hyphens, or underscores. If any ID is invalid or duplicated, stop and report the error to the user.

**Step 0.3: Build the tool briefing string**

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
  "round": {ROUND},
  "phase": "proposals",
  "rounds_completed": {ROUND - 1},
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
  "round": {ROUND},
  "phase": "done",
  "rounds_completed": {ROUND},
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
```

**Step 2: Verify**

```bash
ls dialectic-agent/.cursor/skills/orchestrate/SKILL.md
```

**Step 3: Commit**

```bash
git add .cursor/skills/orchestrate/SKILL.md
git commit -m "feat: add orchestrate.SKILL.md (main entry point)"
```

---

## Task 16: README.md

**Files:**
- Create: `dialectic-agent/README.md`

**Step 1: Write the file**

````markdown
# Dialectic Agent-Native

A multi-agent design debate system implemented entirely as agent skill files, prompt files, and a JSON config. No code required. Runs on any agentic platform that supports subagent dispatch (Cursor, Claude Code, etc.).

## What It Does

Give it a design problem. Multiple AI agents — each with a distinct expert role (architect, security, performance, simplicity) — debate the problem through structured rounds of proposals, critiques, and refinements. A judge evaluates convergence after each round. The debate ends when the agents reach sufficient agreement or a round ceiling is hit. A judge synthesizes the final solution.

The entire system is driven by an agent following skill files. State lives in plain markdown and JSON files you can read at any time.

## Prerequisites

- An agentic platform with a Task tool for subagent dispatch (Cursor, Claude Code, etc.)
- The agent must have access to `file_read` and `file_write` capabilities
- Any additional tools (web_search, MCP servers) are optional and declared in `debate-config.json`

## Quickstart

**1. Clone this project to a location your agent can access:**

```bash
git clone <repo> /path/to/dialectic-agent
```

**2. Create a debate workspace:**

```bash
mkdir my-debate
cd my-debate
```

**3. Write your problem statement:**

```bash
# Create problem.md with your design problem
cat > problem.md << 'EOF'
Design a distributed rate limiting system for an API gateway handling 100k req/s.

Requirements:
- Must support per-user and per-IP rate limits
- Must respond within 10ms (p99)
- Must be horizontally scalable
- Should support burst allowances
EOF
```

**4. (Optional) Add context files:**

```bash
mkdir context
cp existing-architecture.md context/
cp api-spec.json context/
```

**5. (Optional) Create a local config override:**

```bash
cp /path/to/dialectic-agent/debate-config.json ./debate-config.json
# Edit to change agents, convergence settings, or tools
```

**6. Invoke the orchestrator in your agent:**

Tell your agent:

> "Read and follow the skill at `/path/to/dialectic-agent/.cursor/skills/orchestrate/SKILL.md`.
> The debate workspace is at `/absolute/path/to/my-debate`."

## Output

After the debate completes, find:

| File | Description |
|---|---|
| `debate/synthesis.md` | The final solution — the primary output |
| `debate/round-N/proposals/<agent-id>.md` | Each agent's proposal per round |
| `debate/round-N/critiques/<reviewer>-on-<target>.md` | Each critique |
| `debate/round-N/refinements/<agent-id>.md` | Each agent's refined position |
| `debate/round-N/verdict.json` | Judge's convergence assessment |
| `debate/progress.md` | Human-readable progress log |
| `debate/clarifications/summary.md` | Pre-debate Q&A (if clarifications were enabled) |

## Configuration

Edit `debate-config.json` (workspace copy or the project default) to change:

- **`agents`**: which roles participate and their IDs/names
- **`convergence`**: max rounds, confidence threshold, convergence criteria
- **`clarifications`**: whether to run pre-debate Q&A and how many iterations per agent
- **`tools`**: which tools agents can use (built-ins or MCP server tools by name)
- **`agents_config`**: per-agent tool hints

See `debate-config.json` for the full example with all fields documented.

## Prompt Customization

Role prompts live in `prompts/<role>/`. To customize a role:
- Edit `prompts/<role>/system.md` to change the persona
- Edit `prompts/<role>/proposal.md`, `critique.md`, or `refinement.md` to change phase behavior
- Edit `prompts/shared/` files to change cross-role rules (affects all roles)

## Adding a New Role

1. Create `prompts/<new-role>/system.md` with the persona
2. Create `prompts/<new-role>/proposal.md`, `critique.md`, `refinement.md`
3. Add an agent entry to `debate-config.json` with the new role name

## Adding MCP Tools

1. Configure the MCP server in your agent platform
2. Add the tool to `debate-config.json`:
   ```json
   { "name": "github_search_code", "description": "Search GitHub for reference implementations" }
   ```
3. Optionally add tool hints to specific agents in `agents_config`

The agent platform grants access; the config tells agents when and how to use it.

## File Naming Conventions

All output files use **agent IDs** (from config), not role names:
- `proposals/arch.md` — not `proposals/architect.md`
- `critiques/arch-on-sec.md` — not `critiques/architect-on-security.md`

Agent IDs must be unique across all agents and the judge. Use alphanumeric characters, hyphens, and underscores only.
````

**Step 2: Commit**

```bash
git add README.md
git commit -m "docs: add README.md with quickstart and configuration guide"
```

---

## Task 17: End-to-End Validation

**Files:** None created — validation only.

This task verifies the project works by running a minimal debate with a simple problem.

**Step 1: Verify complete file tree**

```bash
find dialectic-agent -type f | sort
```

Expected output (at minimum):

```
dialectic-agent/README.md
dialectic-agent/debate-config.json
dialectic-agent/prompts/architect/critique.md
dialectic-agent/prompts/architect/proposal.md
dialectic-agent/prompts/architect/refinement.md
dialectic-agent/prompts/architect/system.md
dialectic-agent/prompts/datamodeling/critique.md
dialectic-agent/prompts/datamodeling/proposal.md
dialectic-agent/prompts/datamodeling/refinement.md
dialectic-agent/prompts/datamodeling/system.md
dialectic-agent/prompts/generalist/synthesize.md
dialectic-agent/prompts/generalist/system.md
dialectic-agent/prompts/kiss/critique.md
dialectic-agent/prompts/kiss/proposal.md
dialectic-agent/prompts/kiss/refinement.md
dialectic-agent/prompts/kiss/system.md
dialectic-agent/prompts/performance/critique.md
dialectic-agent/prompts/performance/proposal.md
dialectic-agent/prompts/performance/refinement.md
dialectic-agent/prompts/performance/system.md
dialectic-agent/prompts/security/critique.md
dialectic-agent/prompts/security/proposal.md
dialectic-agent/prompts/security/refinement.md
dialectic-agent/prompts/security/system.md
dialectic-agent/prompts/shared/clarify.md
dialectic-agent/prompts/shared/critique.md
dialectic-agent/prompts/shared/proposal.md
dialectic-agent/prompts/shared/refinement.md
dialectic-agent/prompts/shared/summarize.md
dialectic-agent/prompts/shared/system.md
dialectic-agent/prompts/testing/critique.md
dialectic-agent/prompts/testing/proposal.md
dialectic-agent/prompts/testing/refinement.md
dialectic-agent/prompts/testing/system.md
dialectic-agent/.cursor/skills/clarify/SKILL.md
dialectic-agent/.cursor/skills/judge/SKILL.md
dialectic-agent/.cursor/skills/orchestrate/SKILL.md
dialectic-agent/.cursor/skills/role-agent/SKILL.md
dialectic-agent/.cursor/skills/role-clarify/SKILL.md
```

**Step 2: Validate JSON files**

```bash
cat dialectic-agent/debate-config.json | python3 -m json.tool > /dev/null && echo "Config: valid JSON"
```

**Step 3: Create a minimal test workspace**

```bash
mkdir /tmp/test-debate
cat > /tmp/test-debate/problem.md << 'EOF'
Design a simple in-memory key-value store that supports GET, SET, and DELETE operations with TTL (time-to-live) expiry. It must handle 10,000 operations per second on a single server.
EOF
```

Create a minimal config with only 2 agents and no clarifications for speed:

```bash
cat > /tmp/test-debate/debate-config.json << 'EOF'
{
  "agents": [
    { "id": "arch", "name": "Architect", "role": "architect" },
    { "id": "kiss", "name": "Simplicity Advocate", "role": "kiss" }
  ],
  "judge": { "id": "judge", "name": "Judge", "role": "generalist", "extra_instructions": "" },
  "convergence": { "max_rounds": 2, "judge_threshold": 0.70, "criteria": "Both agents agree on the core design approach." },
  "clarifications": { "enabled": false, "max_iterations_per_agent": 2 },
  "tools": [],
  "agents_config": {}
}
EOF
```

**Step 4: Run the debate**

Tell your agent:
> "Read and follow the skill at `{absolute path to dialectic-agent}/.cursor/skills/orchestrate/SKILL.md`. The debate workspace is at `/tmp/test-debate`."

**Step 5: Verify outputs**

After completion, check:

```bash
# Check workspace was created
ls /tmp/test-debate/debate/

# Check round 1 was produced
ls /tmp/test-debate/debate/round-1/proposals/
# Expected: arch.md  kiss.md

ls /tmp/test-debate/debate/round-1/critiques/
# Expected: arch-on-kiss.md  kiss-on-arch.md

ls /tmp/test-debate/debate/round-1/refinements/
# Expected: arch.md  kiss.md

cat /tmp/test-debate/debate/round-1/verdict.json
# Expected: valid JSON with "verdict" and "confidence" fields

# Check synthesis was written
ls /tmp/test-debate/debate/synthesis.md
# Expected: exists and contains a meaningful solution document

# Check progress log
cat /tmp/test-debate/debate/progress.md
# Expected: timestamped entries for each phase
```

**Step 6: Final commit**

```bash
cd dialectic-agent
git add -A
git commit -m "feat: complete dialectic-agent-native project"
```

---

## Summary: All Files to Create

| Task | File(s) |
|---|---|
| 1 | Directory structure only |
| 2 | `debate-config.json` |
| 3 | `prompts/shared/{system,proposal,critique,refinement,summarize,clarify}.md` (6 files) |
| 4 | `prompts/architect/{system,proposal,critique,refinement}.md` (4 files) |
| 5 | `prompts/security/{system,proposal,critique,refinement}.md` (4 files) |
| 6 | `prompts/performance/{system,proposal,critique,refinement}.md` (4 files) |
| 7 | `prompts/kiss/{system,proposal,critique,refinement}.md` (4 files) |
| 8 | `prompts/testing/{system,proposal,critique,refinement}.md` (4 files) |
| 9 | `prompts/datamodeling/{system,proposal,critique,refinement}.md` (4 files) |
| 10 | `prompts/generalist/{system,synthesize}.md` (2 files) |
| 11 | `.cursor/skills/role-clarify/SKILL.md` |
| 12 | `.cursor/skills/clarify/SKILL.md` |
| 13 | `.cursor/skills/role-agent/SKILL.md` |
| 14 | `.cursor/skills/judge/SKILL.md` |
| 15 | `.cursor/skills/orchestrate/SKILL.md` |
| 16 | `README.md` |
| 17 | Validation only |

**Total: 37 files**

Tasks 5–9 (security, performance, kiss, testing, datamodeling) follow the same pattern as Task 4 (architect). For each, read the corresponding TypeScript source file in `packages/core/src/agents/prompts/` and translate using the same pattern: `BASE_SYSTEM_PROMPT` → `system.md`, prompt function bodies → phase files, stripping dynamic injection syntax (`${variable}`) and replacing with file-read instructions.
