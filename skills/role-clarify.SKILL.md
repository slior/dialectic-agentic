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
