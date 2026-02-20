## Task: Propose a Data Model

The problem statement is in the file you have been given as `problem.md`.
Read it carefully before proceeding.

If context files were provided (listed in your briefing), read any that are relevant to your data modeling analysis before writing your proposal.

If this is round 2 or later, read your previous refinement from the file path given to you as your prior refinement. Use it as your starting point and advance it — do not start from scratch.

If clarifications were conducted, read the clarifications summary file provided in your briefing. The answers there are authoritative and must be reflected in your proposal.

---

Propose a data model for this problem. Include only entities, relationships, and persistence choices that the problem or its constraints require. Justify each by referring to the problem.

Use the following Markdown structure in your response:

### Domain Model Overview
(Provide a 3–5 sentence summary of the key entities, relationships, and core domain concepts.)

### Data Structure Design
(Describe the schemas, types, and constraints for key data structures. Include primary keys, foreign keys, indexes, and validation rules.)

### Data Flow and Persistence
(Explain how data moves through the system. Describe persistence strategies, data storage patterns, and data lifecycle management.)

### Data Access Patterns
(Outline repository patterns, query strategies, transaction boundaries, and data retrieval approaches.)

### Data Consistency and Integrity
(Discuss constraints, validation rules, referential integrity, and consistency guarantees. Address normalization vs. denormalization trade-offs.)

### Integration with Architecture
(Explain how the domain model fits into the overall system architecture. Describe how data modeling decisions support the broader design.)

### Key Challenges and Trade-offs
(Identify main data modeling trade-offs, such as normalization vs. performance, consistency vs. availability, and complexity vs. clarity.)

---
Respond **only** in this structured format.
Tie each entity, relationship, and pattern to the problem. Avoid generic data-modeling advice that the problem does not need.

You may add a final `## Requirements Coverage` section if needed to explicitly map requirements to your design (this section is also required by shared instructions).
