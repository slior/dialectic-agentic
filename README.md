# Dialectic Agent-Native

A multi-agent design debate system implemented entirely as agent skill files, prompt templates, and a JSON config. No code required. Runs on any agentic platform that supports subagent dispatch (Cursor, Claude Code, etc.).

## What It Does

Give it a design problem. Multiple AI agents — each with a distinct expert role (architect, security, performance, simplicity) — debate the problem through structured rounds of proposals, critiques, and refinements. A judge evaluates convergence after each round. The debate ends when the agents reach sufficient agreement or a round ceiling is hit. A judge synthesizes the final solution.

The entire system is driven by an agent following skill files. State lives in plain markdown and JSON files you can read at any time.

## Install

Dialectic ships as an [Agent Plugin](https://agent-plugins.org) targeting specification version 1.0.0: a self-contained directory with a `plugin.json` manifest at its root and its skills under `skills/`. Any client that implements the standard can discover and load it without modification.

Loading is not the same as running, though. A debate is built entirely on subagent dispatch, and the Agent Plugins standard does not define a subagent mechanism — so Dialectic needs a client that has one. Cursor is the first-class target and needs no configuration. On a client that does not tell a skill the path it was loaded from, pass `PROJECT=/absolute/path/to/the/plugin` when you invoke the skill; see [Legacy: clone-and-reference flow](#legacy-clone-and-reference-flow). `PROJECT` is the Dialectic plugin directory (the folder that contains `prompts/`, `agents/`, and `debate-config.json`), not the repo you are debating — that repo, or the debate folder inside it, is `WORKSPACE`.

### From the Cursor Marketplace (recommended)

Search for **Dialectic** in the Cursor Marketplace and install it. Cursor handles the files; no cloning, no path setup.

### From a clone

Clone the repository into your client's local plugin directory and reload the client. For Cursor:

```bash
git clone https://github.com/slior/dialectic-agentic.git ~/.cursor/plugins/local/dialectic
```

Then run **Developer: Reload Window**. See [`docs/development.md`](docs/development.md) for the full local-install, validation, and troubleshooting guide.

### Prerequisites

- An agentic platform with a Task tool for subagent dispatch (Cursor is the first-class target).
- The agent must have access to `file_read` and `file_write` capabilities.
- Any additional tools (`web_search`, MCP servers) are optional and declared in `debate-config.json`.

## Quickstart

**1. Create a debate workspace:**

```bash
mkdir my-debate
cd my-debate
```

**2. Write your problem statement:**

```bash
cat > problem.md << 'EOF'
Design a distributed rate limiting system for an API gateway handling 100k req/s.

Requirements:
- Must support per-user and per-IP rate limits
- Must respond within 10ms (p99)
- Must be horizontally scalable
- Should support burst allowances
EOF
```

**3. (Optional) Add context files:**

```bash
mkdir context
cp /path/to/existing-architecture.md context/
cp /path/to/api-spec.json context/
```

**4. (Optional) Override the debate configuration:**

Most users can skip this step. The plugin ships with a default `debate-config.json`. If you want to change agents, convergence settings, or tools for this debate only, create a workspace-local `debate-config.json` using the shipped `debate-config.json` as a template.

The workspace-local override must be valid JSON. Do not create a placeholder or non-JSON `debate-config.json`; the orchestrator parses `{WORKSPACE}/debate-config.json` as JSON when it exists.

Or generate one interactively (when running the legacy clone-and-reference flow):

```bash
/path/to/dialectic-agent/skills/orchestrate/scripts/create-debate-config.sh
```

**5. Invoke the orchestrator:**

In Cursor, ask the agent:

> "Run the dialectic debate. `WORKSPACE=/absolute/path/to/my-debate`."

The `orchestrate` skill (installed by the plugin) self-locates the plugin root and runs the full debate. Do not pass `PROJECT` unless that self-location fails; if you must, it is the plugin directory, not this workspace. If you also want to use a workspace-specific config path, also pass `DEBATE_CONFIG=/absolute/path/to/debate-config.json`.

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

Edit `debate-config.json` (workspace copy or the plugin's shipped default) to change:

- **`agents`**: which roles participate and their IDs/names
- **`convergence`**: max rounds, confidence threshold, convergence criteria
- **`clarifications`**: whether to run pre-debate Q&A and how many iterations per agent
- **`tools`**: which tools agents can use (built-ins or MCP server tools by name)
- **`agents_config`**: per-agent tool hints

See the shipped `debate-config.json` for the full example with all fields documented. For a field-by-field reference and behavior details, see `docs/configuration.md`.

## Prompt Customization

Role prompts live in `prompts/<role>/`. For installed-plugin users, customizing prompts means forking the plugin repo. For developers using the legacy clone-and-reference flow (see below), edit:

- `prompts/<role>/system.md` to change the persona
- `prompts/<role>/proposal.md`, `critique.md`, or `refinement.md` to change phase behavior
- `prompts/shared/*.md` to change cross-role rules (affects all roles)

## Adding a New Role

(Requires forking the plugin for marketplace-installed users.)

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

## Legacy: clone-and-reference flow

If you want to hack on the plugin directly without installing it, clone the repo and pass `PROJECT` at invocation. `PROJECT` is this clone — the Dialectic plugin root — not the application repo you are debating (`WORKSPACE`):

```bash
git clone https://github.com/slior/dialectic-agentic.git /path/to/dialectic-agentic
```

Invoke the orchestrator with both `WORKSPACE` and `PROJECT`:

> "Read and follow the skill at `/path/to/dialectic-agentic/skills/orchestrate/SKILL.md`.
> `WORKSPACE=/absolute/path/to/my-debate`.
> `PROJECT=/path/to/dialectic-agentic`.
> Optionally: `DEBATE_CONFIG=/absolute/path/to/debate-config.json`."

When `PROJECT` is provided explicitly, the orchestrator's self-location is skipped and your chosen path is used verbatim.

## Contributing

- Development happens on `master` (default branch).
- Releases are fast-forwarded to `main` and tagged `vX.Y.Z`. See `CHANGELOG.md` for history.
- Bug reports and PRs: https://github.com/slior/dialectic-agentic

## License

MIT. See `LICENSE`.
