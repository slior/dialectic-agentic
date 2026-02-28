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

Or generate one interactively:

```bash
/path/to/dialectic-agent/scripts/create-debate-config.sh
```

**6. Invoke the orchestrator in your agent:**

Tell your agent:

> "Read and follow the skill at `/path/to/dialectic-agent/.cursor/skills/orchestrate/SKILL.md`.
> The debate workspace is at `/absolute/path/to/my-debate`.
> Optionally, use `DEBATE_CONFIG=/absolute/path/to/debate-config.json`."

If `DEBATE_CONFIG` is provided but invalid, the orchestrator asks whether to create a config now. If you decline, it stops. If you accept, it runs the interactive config generator and uses the resulting file for the debate.

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
For a full field-by-field reference and behavior details, see `docs/configuration.md`.

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
