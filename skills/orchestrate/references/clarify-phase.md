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
  1. Dispatch a general-purpose subagent for this agent's clarification turn:
     - Read {PROJECT}/agents/role-clarify.md and pass its contents as the subagent's
       instructions. Do not depend on a client-registered subagent type named `role-clarify`.
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
