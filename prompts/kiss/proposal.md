## Task: Propose the Simplest Solution

The problem statement is in the file you have been given as `problem.md`.
Read it carefully before proceeding.

If context files were provided (listed in your briefing), read any that are relevant before writing your proposal.

If this is round 2 or later, read your previous refinement from the file path given to you as your prior refinement. Use it as your starting point and advance it — do not start from scratch.

If clarifications were conducted, read the clarifications summary file provided in your briefing. The answers there are authoritative and must be reflected in your proposal.

---

Propose the simplest solution that meets the requirements of this problem. Do not add components or patterns the problem does not need.

Structure your response as follows:

## Core Idea
Describe the simplest design that meets the stated needs.

## Minimal Architecture
Outline only the essential components and their interactions.
Avoid unnecessary components, layers or frameworks.

### Non-Functional Considerations (Simplified)
Address only if the problem or constraints require it. Prefer one short sentence over a checklist.
#### Scalability
(Only address if truly needed. Prefer simple scaling strategies over complex ones.)
#### Security
(Use the simplest security approach that meets requirements. Avoid over-engineering.)
#### Maintainability
(Simplicity IS maintainability. Explain how keeping it simple makes it easier to maintain.)
#### Operational Concerns
(Keep deployment and operations as simple as possible. Avoid unnecessary complexity.)

## Simplifications
List where you intentionally reduced complexity or avoided over-engineering.

## Phased Path
If the problem has essential complexity, describe a phased approach:
1. Minimal viable version
2. Gradual additions as real needs arise

## Risks of Simplicity
Mention potential risks or trade-offs of keeping it simple.

## What We're NOT Building (YAGNI)
(Explicitly list features, components, or patterns you're deliberately omitting because they're not needed yet.)

## Summary
Summarize why this design is the simplest practical path forward.

---
Respond **only** in this structured format.
Tie every simplification to the problem. Do not suggest removing or avoiding things that the problem or constraints require.

**Important**: While advocating for simplicity, you MUST ensure all major requirements are fulfilled. The simplest solution that still satisfies all major requirements is preferred. You may add a final `## Requirements Coverage` section to explicitly map requirements to your design (this section is also required by shared instructions).
