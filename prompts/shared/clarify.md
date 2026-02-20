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
