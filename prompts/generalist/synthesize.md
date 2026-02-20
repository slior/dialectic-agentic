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
