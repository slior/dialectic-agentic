# Cursor Plugin Publishing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restructure the `dialectic-agent` repo into a Cursor Marketplace plugin (`dialectic`), add self-location to the user-facing skills, set up a `master`/`main` dev/release branch split, and ship `v0.1.0` to the marketplace while preserving the existing clone-and-reference workflow.

**Architecture:** The repo becomes the plugin. Skills and subagents move from `.cursor/skills/` to plugin-discoverable `skills/` and `agents/` directories; shared `prompts/` stay at the repo root. The user-facing `orchestrate` and `judge` skills gain a Phase 0.0 that self-locates `PROJECT` from the SKILL.md's own absolute load path, falling back to an explicit `PROJECT` parameter for backwards compatibility. A `.cursor-plugin/plugin.json` manifest drives marketplace packaging.

**Tech Stack:** Markdown skill files, YAML frontmatter, bash scripts (unchanged), JSON config files, Git.

**Spec:** [`docs/superpowers/specs/2026-05-01-cursor-plugin-publishing-design.md`](../specs/2026-05-01-cursor-plugin-publishing-design.md)

---

## Assumptions for this plan

- All commands are run from the repo root `/Users/liors/dev/dialectic-agent` unless stated otherwise.
- **Current execution branch: `plugin`.** All commits from Tasks 1–9 land on the `plugin` branch. After `plugin` is reviewed and merged back to `master`, Appendix A (release cut to `main` + marketplace submission) can be executed from `master`.
- Path references below use forward slashes relative to the repo root.
- When `git mv` is invoked, git's rename detection is preserved for files that are simple moves. For files that also have content changes (e.g., `clarify/SKILL.md` → `references/clarify-phase.md`), rename detection may fall back to add/delete; that's acceptable.

## Execution scope

- **Execute now (on `plugin` branch):** Tasks 1 through 9.
- **Deferred to Appendix A (do NOT execute in this session):** cutting the `v0.1.0` release to `main`, pushing, and submitting to the Cursor Marketplace. Run that after `plugin` has been merged to `master`.

---

## Task 1: Baseline hygiene — LICENSE, CHANGELOG, .gitignore

**Files:**
- Create: `LICENSE`
- Create: `CHANGELOG.md`
- Modify: `.gitignore`

- [ ] **Step 1.1: Update `.gitignore`**

Replace the current contents of `.gitignore` with:

```text
/tmp/
.obsidian/
.DS_Store
```

- [ ] **Step 1.2: Create `LICENSE` (MIT)**

Write to `LICENSE`:

```text
MIT License

Copyright (c) 2026 Lior Schejter.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

- [ ] **Step 1.3: Create `CHANGELOG.md`**

Write to `CHANGELOG.md`:

```markdown
# Changelog

All notable changes to this project are documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] — 2026-05-01
### Added
- Initial Cursor Marketplace release of the Dialectic plugin.
- Self-location Phase 0.0 in `orchestrate` and `judge` skills so installed-plugin
  users no longer need to supply a `PROJECT` parameter.
- Plugin manifest at `.cursor-plugin/plugin.json`.
- Repo layout aligned with Cursor plugin conventions: `skills/`, `agents/`,
  shared `prompts/` at the repo root.
- `LICENSE` (MIT), `CHANGELOG.md`.

### Changed
- `clarify` is now an internal reference under `skills/orchestrate/references/`
  instead of a top-level skill (it is always executed inline by the orchestrator,
  not dispatched as a subagent).
- `role-agent` and `role-clarify` moved under `agents/` as single-file subagent
  definitions (they are never user-invocable).
- The interactive config generator's CLI path changed from
  `scripts/create-debate-config.sh` to
  `skills/orchestrate/scripts/create-debate-config.sh`. (The old top-level
  wrapper was removed; the canonical script that did the real work is preserved
  at the new path.)

### Preserved
- Legacy clone-and-reference flow: users who supply `PROJECT=/abs/path`
  continue to work exactly as before.
```

- [ ] **Step 1.4: Verify files**

Run: `ls LICENSE CHANGELOG.md .gitignore`
Expected: all three files exist.

Run: `head -1 LICENSE CHANGELOG.md`
Expected: first line of LICENSE is `MIT License`; first line of CHANGELOG.md is `# Changelog`.

- [ ] **Step 1.5: Commit**

```bash
git add .gitignore LICENSE CHANGELOG.md
git commit -m "chore: add LICENSE (MIT), CHANGELOG, .gitignore updates for plugin release"
```

---

## Task 2: Restructure repo to plugin layout

**Files (moves):**
- `.cursor/skills/orchestrate/` → `skills/orchestrate/`
- `.cursor/skills/judge/SKILL.md` → `skills/judge/SKILL.md`
- `.cursor/skills/role-agent/SKILL.md` → `agents/role-agent.md`
- `.cursor/skills/role-clarify/SKILL.md` → `agents/role-clarify.md`
- `.cursor/skills/clarify/SKILL.md` → `skills/orchestrate/references/clarify-phase.md`
- `scripts/create-debate-config.sh` → `skills/orchestrate/scripts/create-debate-config.sh`
- `.cursor/plans/` → `docs/plans/`

**Files (content edits — paths updated in the same commit so the repo works before and after):**
- Modify: `skills/orchestrate/SKILL.md` (scripts path)
- Modify: `skills/orchestrate/references/debate-loop.md` (3 path references)
- Modify: `skills/orchestrate/references/clarify-phase.md` (strip YAML frontmatter)

This is a single atomic commit. Every path reference in the skills that changes location MUST be updated in this commit so the repo still works end-to-end when checked out.

- [ ] **Step 2.1: Create parent directories for moves**

```bash
mkdir -p skills agents docs/plans
```

- [ ] **Step 2.2: Move orchestrate skill (including references and scripts subdirs)**

```bash
git mv .cursor/skills/orchestrate skills/orchestrate
```

Verify:
```bash
ls skills/orchestrate
```
Expected output:
```
SKILL.md  references  scripts
```

- [ ] **Step 2.3: Move judge skill**

```bash
git mv .cursor/skills/judge skills/judge
```

- [ ] **Step 2.4: Move role-agent as single-file agent**

```bash
git mv .cursor/skills/role-agent/SKILL.md agents/role-agent.md
rmdir .cursor/skills/role-agent
```

- [ ] **Step 2.5: Move role-clarify as single-file agent**

```bash
git mv .cursor/skills/role-clarify/SKILL.md agents/role-clarify.md
rmdir .cursor/skills/role-clarify
```

- [ ] **Step 2.6: Move clarify SKILL content to references/clarify-phase.md**

```bash
git mv .cursor/skills/clarify/SKILL.md skills/orchestrate/references/clarify-phase.md
rmdir .cursor/skills/clarify
```

- [ ] **Step 2.7: Remove the repo-root `scripts/` wrapper**

The top-level `scripts/create-debate-config.sh` is a **thin wrapper** (not a duplicate) that `exec`s the canonical script inside the skill directory. It currently contains a latent bug (it points to `.cursor/skills/orchestrator/scripts/…` with a trailing `r` that does not match the actual `orchestrate/` directory). Since Step 2.2 already moved the canonical script to `skills/orchestrate/scripts/create-debate-config.sh`, the wrapper is redundant. Delete it.

Verify the canonical script is the substantive one, then delete the wrapper:

```bash
wc -l scripts/create-debate-config.sh skills/orchestrate/scripts/create-debate-config.sh
```
Expected: the wrapper is around 19 lines; the canonical script is substantially longer (the actual interactive generator).

```bash
git rm scripts/create-debate-config.sh
rmdir scripts
```

Verify:
```bash
ls scripts 2>/dev/null || echo "ok: scripts/ directory removed"
```
Expected: `ok: scripts/ directory removed`.

Note: The README update in Task 7 points users at the new canonical path `skills/orchestrate/scripts/create-debate-config.sh`. This is an intentional, documented breaking change to the CLI path.

- [ ] **Step 2.8: Move `.cursor/plans/` → `docs/plans/`**

The files under `.cursor/plans/` are currently untracked by git (confirmed via `git status` showing `?? .cursor/plans/…`). Use plain `mv` rather than `git mv` (which errors on untracked paths), then let Task 2.17's `git add -A` pick up the new location.

```bash
mv .cursor/plans/* docs/plans/
rmdir .cursor/plans
```

Verify:
```bash
ls docs/plans
```
Expected: the plan file(s) that were previously under `.cursor/plans/`.

- [ ] **Step 2.9: Remove now-empty `.cursor/skills/` and `.cursor/`**

```bash
rmdir .cursor/skills .cursor
```

Verify:
```bash
ls -la .cursor 2>/dev/null || echo "ok: .cursor removed"
```
Expected: `ok: .cursor removed`.

- [ ] **Step 2.10: Strip YAML frontmatter from `references/clarify-phase.md`**

The file currently starts with YAML frontmatter (`---\nname: clarify\n...\n---`). Since it's now a reference document read inline by the orchestrator (not a Cursor-discovered skill), the frontmatter is no longer needed and would be confusing.

Open `skills/orchestrate/references/clarify-phase.md` and replace lines 1–11 (the frontmatter block and the blank line that follows) with nothing. The file must now start at the former line 12: `# Clarify — Pre-Debate Clarification Phase`.

Exact old content to remove (lines 1–11 inclusive, including the closing `---` and the blank line on line 12):

```text
---
name: clarify
description: >-
  Facilitates the pre-debate clarification phase. Each participating agent gets
  a chance to ask clarifying questions about the problem; the orchestrator relays
  them to the user and records answers. Use when clarifications are enabled in
  the debate config before the debate loop begins.
compatibility: >-
  Requires Cursor IDE with Task tool for subagent dispatch. Requires the
  dialectic-agent project structure (prompts/, debate-config.json).
---

```

Verify the file now starts with `# Clarify — Pre-Debate Clarification Phase`:
```bash
head -1 skills/orchestrate/references/clarify-phase.md
```
Expected: `# Clarify — Pre-Debate Clarification Phase`

- [ ] **Step 2.11: Update `skills/orchestrate/SKILL.md` — scripts path**

Find the occurrence of `.cursor/skills/orchestrate/scripts/create-debate-config.sh` inside `skills/orchestrate/SKILL.md` and replace with `skills/orchestrate/scripts/create-debate-config.sh`.

Exact old text to find:

```text
Invoke `{PROJECT}/.cursor/skills/orchestrate/scripts/create-debate-config.sh` directly.
```

Replace with:

```text
Invoke `{PROJECT}/skills/orchestrate/scripts/create-debate-config.sh` directly.
```

Verify:
```bash
rg '\.cursor/skills' skills/orchestrate/SKILL.md
```
Expected: no matches.

- [ ] **Step 2.12: Update `skills/orchestrate/references/debate-loop.md` — clarify invocation**

Find this block in `skills/orchestrate/references/debate-loop.md`:

```text
Follow the skill at `{PROJECT}/.cursor/skills/clarify/SKILL.md`. Pass:
- `WORKSPACE`, `PROJECT`, `CONFIG`, `PROBLEM_TEXT`, `CONTEXT_FILES`
```

Replace with:

```text
Follow the instructions in `references/clarify-phase.md` (sibling of this file). Use these variables as you already have them in the orchestrator:
- `WORKSPACE`, `PROJECT`, `CONFIG`, `PROBLEM_TEXT`, `CONTEXT_FILES`
```

- [ ] **Step 2.13: Update `skills/orchestrate/references/debate-loop.md` — role-agent path**

Find all occurrences of:

```text
{PROJECT}/.cursor/skills/role-agent/SKILL.md
```

Replace each with:

```text
{PROJECT}/agents/role-agent.md
```

- [ ] **Step 2.14: Update `skills/orchestrate/references/debate-loop.md` — judge path**

Find all occurrences of:

```text
{PROJECT}/.cursor/skills/judge/SKILL.md
```

Replace each with:

```text
{PROJECT}/skills/judge/SKILL.md
```

- [ ] **Step 2.15: Verify no stale `.cursor/skills/` references remain**

```bash
rg '\.cursor/skills' skills/ agents/ prompts/
```
Expected: no matches anywhere.

```bash
rg 'clarify/SKILL\.md' skills/ agents/ prompts/
```
Expected: no matches.

- [ ] **Step 2.16: Sanity check repo layout**

```bash
ls -la .cursor-plugin 2>/dev/null || echo "(.cursor-plugin not yet created — that's Task 5)"
find skills agents prompts -maxdepth 3 -type f -name '*.md' | sort
```
Expected: prints a tree like
```
agents/role-agent.md
agents/role-clarify.md
prompts/architect/critique.md
prompts/architect/proposal.md
…
skills/judge/SKILL.md
skills/orchestrate/SKILL.md
skills/orchestrate/references/clarify-phase.md
skills/orchestrate/references/debate-loop.md
```

- [ ] **Step 2.17: Commit**

```bash
git add -A
git commit -m "refactor: restructure repo to Cursor plugin layout (skills/, agents/, prompts/)"
```

Verify the commit staged both renames AND the content edits:
```bash
git show --stat HEAD | head -30
```
Expected: a mix of `rename` lines and regular modified files covering all 11 moves + the 4 edited files (orchestrate SKILL.md, debate-loop.md, clarify-phase.md, …).

---

## Task 3: Add self-location Phase 0.0 to `skills/orchestrate/SKILL.md`

**Files:**
- Modify: `skills/orchestrate/SKILL.md` (insert Phase 0.0 above current Phase 0)

- [ ] **Step 3.1: Insert Phase 0.0**

Find this anchor line in `skills/orchestrate/SKILL.md`:

```text
## Phase 0: Load Configuration
```

Immediately before it (with a blank line separator), insert the following new section:

```text
## Phase 0.0: Resolve PLUGIN_ROOT

You just read this SKILL.md from an absolute path. Let that path be SKILL_PATH.
Compute CANDIDATE_ROOT by removing the trailing `/skills/orchestrate/SKILL.md`
from SKILL_PATH.

Verify that all of the following exist under CANDIDATE_ROOT:
- `prompts/shared/system.md`
- `prompts/generalist/system.md`
- `debate-config.json`

Resolve `PROJECT` as follows:
- If the `PROJECT` parameter was supplied at invocation: set `PROJECT` to that value and skip the rest of this phase. Do not overwrite the user's choice.
- Else if all three paths above exist under `CANDIDATE_ROOT`: set `PROJECT = CANDIDATE_ROOT`.
- Otherwise, stop and print to the user, verbatim:

  > I could not locate the dialectic plugin files automatically. Re-invoke this skill and include the parameter:
  >
  >   `PROJECT=<absolute path to the installed plugin or to a clone of the dialectic-agentic repository>`
  >
  > For example: `PROJECT=/Users/you/.cursor/plugins/local/dialectic`

For all downstream phases and every subagent you dispatch, pass `PROJECT` as a parameter exactly as set above.

---

```

(The trailing `---\n\n` separates Phase 0.0 from the existing Phase 0.)

- [ ] **Step 3.2: Verify insertion**

```bash
rg -n '^## Phase 0' skills/orchestrate/SKILL.md
```
Expected: two matches, in order — `## Phase 0.0: Resolve PLUGIN_ROOT` then `## Phase 0: Load Configuration`.

```bash
rg 'CANDIDATE_ROOT' skills/orchestrate/SKILL.md | wc -l
```
Expected: at least 3 (the variable appears multiple times in the new phase).

- [ ] **Step 3.3: Commit**

```bash
git add skills/orchestrate/SKILL.md
git commit -m "feat(orchestrate): add self-location Phase 0.0 for plugin installs"
```

---

## Task 4: Add self-location Phase 0.0 to `skills/judge/SKILL.md`

**Files:**
- Modify: `skills/judge/SKILL.md` (insert Phase 0.0 above current Step 1)

- [ ] **Step 4.1: Insert Phase 0.0**

Find this anchor line in `skills/judge/SKILL.md`:

```text
## Step 1: Establish Your Identity
```

Immediately before it (with a blank line separator), insert the following new section:

```text
## Phase 0.0: Resolve PLUGIN_ROOT (when invoked without PROJECT)

If the `PROJECT` parameter was supplied at invocation, skip this phase and proceed to Step 1.

Otherwise, let `SKILL_PATH` be the absolute path you just loaded this SKILL.md from. Compute `CANDIDATE_ROOT` by removing the trailing `/skills/judge/SKILL.md` from `SKILL_PATH`.

Verify that both of the following exist under `CANDIDATE_ROOT`:
- `prompts/shared/system.md`
- `prompts/generalist/system.md`

If both exist, set `PROJECT = CANDIDATE_ROOT`. Otherwise, stop and print to the user, verbatim:

> I could not locate the dialectic plugin files automatically. Re-invoke this skill and include the parameter:
>
>   `PROJECT=<absolute path to the installed plugin or to a clone of the dialectic-agentic repository>`
>
> For example: `PROJECT=/Users/you/.cursor/plugins/local/dialectic`

---

```

- [ ] **Step 4.2: Verify insertion**

```bash
rg -n '^## Phase 0\.0|^## Step 1' skills/judge/SKILL.md
```
Expected: `## Phase 0.0: Resolve PLUGIN_ROOT (when invoked without PROJECT)` appears before `## Step 1: Establish Your Identity`.

- [ ] **Step 4.3: Commit**

```bash
git add skills/judge/SKILL.md
git commit -m "feat(judge): add self-location Phase 0.0 for standalone invocation"
```

---

## Task 5: Create the Cursor plugin manifest

**Files:**
- Create: `.cursor-plugin/plugin.json`

- [ ] **Step 5.1: Create the manifest directory**

```bash
mkdir -p .cursor-plugin
```

- [ ] **Step 5.2: Write the manifest**

Write to `.cursor-plugin/plugin.json`:

```json
{
  "name": "dialectic",
  "version": "0.1.0",
  "description": "Configuration-first multi-agent design debate. Agents with different roles (architect, security, performance, simplicity, ...) run structured debate rounds and a judge decides when convergence is reached.",
  "author": {
    "name": "Lior Schejter"
  },
  "homepage": "https://github.com/slior/dialectic-agentic",
  "repository": "https://github.com/slior/dialectic-agentic",
  "license": "MIT",
  "keywords": [
    "multi-agent",
    "design",
    "debate",
    "architecture",
    "review",
    "consensus",
    "orchestration"
  ]
}
```

- [ ] **Step 5.3: Validate JSON**

```bash
python3 -c "import json; json.load(open('.cursor-plugin/plugin.json')); print('ok')"
```
Expected: `ok`.

- [ ] **Step 5.4: Commit**

```bash
git add .cursor-plugin/plugin.json
git commit -m "feat: add Cursor plugin manifest (.cursor-plugin/plugin.json)"
```

---

## Task 6: Update `AGENTS.md`

**Files:**
- Modify: `AGENTS.md`

- [ ] **Step 6.1: Replace the "Main Directories" and "Main Files" sections**

Find this block in `AGENTS.md`:

```text
## Main Directories

- `.cursor/skills/` - Core orchestration and role skills used by the host agent.
- `prompts/` - Role-specific and shared prompt templates for proposal, critique, and refinement phases.
- `docs/` - Project plans and design documentation.
- `scripts/` - Helper scripts, including debate config generation.

## Main Files

- `README.md` - Setup, usage, output structure, and customization docs.
- `debate-config.json` - Default debate configuration (agents, convergence, clarifications, tools).
```

Replace with:

```text
## Main Directories

- `skills/` - User-facing Cursor skills. `skills/orchestrate/` is the main entry point; `skills/judge/` is a secondary skill that can also be invoked standalone for post-hoc synthesis.
- `agents/` - Subagent definitions (`role-agent.md`, `role-clarify.md`) dispatched by the orchestrator via the Task tool. These are not user-invokable commands.
- `prompts/` - Role-specific and shared prompt templates for proposal, critique, and refinement phases.
- `docs/` - Project plans, configuration reference, and design documentation.
- `.cursor-plugin/` - Cursor plugin manifest (`plugin.json`).

## Main Files

- `README.md` - Setup, usage, output structure, and customization docs.
- `debate-config.json` - Default debate configuration (agents, convergence, clarifications, tools). Ships with the plugin as the fallback config.
- `CHANGELOG.md` - Release history, keep-a-changelog format.
- `LICENSE` - MIT license.
- `.cursor-plugin/plugin.json` - Cursor plugin manifest used by the marketplace.
```

- [ ] **Step 6.2: Verify**

```bash
rg -n '\.cursor/skills' AGENTS.md
```
Expected: no matches (the old reference is gone).

```bash
rg -n '\.cursor-plugin' AGENTS.md
```
Expected: at least one match.

- [ ] **Step 6.3: Commit**

```bash
git add AGENTS.md
git commit -m "docs: update AGENTS.md for plugin layout"
```

---

## Task 7: Rewrite `README.md` for marketplace install flow

**Files:**
- Modify: `README.md`

The restructure changes the primary install path from "clone and pass PROJECT" to "install from Cursor Marketplace." The old flow is preserved as a legacy/developer fallback at the bottom of the README.

- [ ] **Step 7.1: Rewrite the README**

Replace the entire contents of `README.md` with:

```markdown
# Dialectic Agent-Native

A multi-agent design debate system implemented entirely as agent skill files, prompt templates, and a JSON config. No code required. Runs on any agentic platform that supports subagent dispatch (Cursor, Claude Code, etc.).

## What It Does

Give it a design problem. Multiple AI agents — each with a distinct expert role (architect, security, performance, simplicity) — debate the problem through structured rounds of proposals, critiques, and refinements. A judge evaluates convergence after each round. The debate ends when the agents reach sufficient agreement or a round ceiling is hit. A judge synthesizes the final solution.

The entire system is driven by an agent following skill files. State lives in plain markdown and JSON files you can read at any time.

## Install

### From the Cursor Marketplace (recommended)

Search for **Dialectic** in the Cursor Marketplace and install it. Cursor handles the files; no cloning, no path setup.

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
cp existing-architecture.md context/
cp api-spec.json context/
```

**4. (Optional) Override the debate configuration:**

The plugin ships with a default `debate-config.json`. If you want to change agents, convergence settings, or tools for this debate only, create a workspace-local override:

```bash
cat > debate-config.json << 'EOF'
# ...your overrides here...
EOF
```

Or generate one interactively (when running the legacy clone-and-reference flow):

```bash
/path/to/dialectic-agent/skills/orchestrate/scripts/create-debate-config.sh
```

**5. Invoke the orchestrator:**

In Cursor, ask the agent:

> "Run the dialectic debate. `WORKSPACE=/absolute/path/to/my-debate`."

The `orchestrate` skill (installed by the plugin) self-locates the plugin root and runs the full debate. If you also want to use a workspace-specific config path, also pass `DEBATE_CONFIG=/absolute/path/to/debate-config.json`.

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

If you want to hack on the plugin directly without installing it, clone the repo and pass `PROJECT=/absolute/path` at invocation:

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
```

- [ ] **Step 7.2: Verify**

```bash
rg -n 'Cursor Marketplace' README.md
```
Expected: at least one match.

```bash
rg -n '\.cursor/skills' README.md
```
Expected: no matches.

```bash
rg -n 'PROJECT=' README.md
```
Expected: at least one match (in the legacy section).

- [ ] **Step 7.3: Commit**

```bash
git add README.md
git commit -m "docs: rewrite README for marketplace install flow; preserve legacy clone flow"
```

---

## Task 8: Local plugin verification

No code changes in this task — this is acceptance testing. All steps must pass before cutting the `v0.1.0` release.

**Files:** none created or modified.

- [ ] **Step 8.1: Symlink the repo as a local Cursor plugin**

```bash
mkdir -p ~/.cursor/plugins/local
ln -sfn /Users/liors/dev/dialectic-agent ~/.cursor/plugins/local/dialectic
ls -l ~/.cursor/plugins/local/dialectic
```
Expected: a symlink resolving to `/Users/liors/dev/dialectic-agent`.

- [ ] **Step 8.2: Reload Cursor**

Open the Command Palette and run **Developer: Reload Window** (or restart Cursor).

- [ ] **Step 8.3: Verify skill discovery**

In a fresh Cursor chat, open the skills panel (Cmd+Shift+J → Rules/Skills). Confirm:
- `orchestrate` appears as a skill.
- `judge` appears as a skill.
- `role-agent` does NOT appear as a user-invokable skill.
- `role-clarify` does NOT appear as a user-invokable skill.

If `role-agent` or `role-clarify` appears as a skill, the plugin's `agents/` discovery is not working as expected — that is open assumption #4 from the spec. Re-check the file locations and frontmatter.

- [ ] **Step 8.4: Run a full debate with no `PROJECT` parameter (plugin self-location)**

Create a scratch workspace:

```bash
mkdir -p /tmp/dialectic-smoke-test
cat > /tmp/dialectic-smoke-test/problem.md << 'EOF'
Design a caching strategy for a read-heavy e-commerce product detail API.
Requirements:
- p99 latency under 50ms
- Stock and price must never be stale by more than 5 seconds
- Must work across 3 regions
EOF
```

In Cursor, invoke:

> "Run the dialectic orchestrate skill. `WORKSPACE=/tmp/dialectic-smoke-test`."

Do NOT pass `PROJECT`. The orchestrator should self-locate from its own SKILL.md path (installed at `~/.cursor/plugins/local/dialectic/skills/orchestrate/SKILL.md`).

Expected:
- Phase 0.0 completes silently (no error about `PROJECT`).
- The debate proceeds through at least one full round.
- `/tmp/dialectic-smoke-test/debate/round-1/proposals/` contains one file per configured agent.
- `/tmp/dialectic-smoke-test/debate/synthesis.md` exists at completion.

- [ ] **Step 8.5: Run a full debate WITH `PROJECT` parameter (legacy flow)**

Create a second scratch workspace:

```bash
mkdir -p /tmp/dialectic-legacy-test
cat > /tmp/dialectic-legacy-test/problem.md << 'EOF'
Design a session storage layer for a web app with 10k concurrent users.
EOF
```

In Cursor, invoke:

> "Read and follow the skill at `/Users/liors/dev/dialectic-agent/skills/orchestrate/SKILL.md`. `WORKSPACE=/tmp/dialectic-legacy-test`. `PROJECT=/Users/liors/dev/dialectic-agent`."

Expected:
- Phase 0.0 honors the explicit `PROJECT` and does not overwrite it.
- Debate completes; `/tmp/dialectic-legacy-test/debate/synthesis.md` exists.

- [ ] **Step 8.6: Run the judge standalone (post-hoc synthesis)**

Using one of the finished debates from Step 8.4 or 8.5, invoke the `judge` skill on its own with `MODE=synthesis`:

> "Run the dialectic judge skill. `MODE=synthesis`. `ROUND=<final round number>`. `WORKSPACE=/tmp/dialectic-smoke-test`."

Expected:
- Judge's Phase 0.0 self-locates successfully.
- A fresh `synthesis.md` is written (or overwrites the prior one).

- [ ] **Step 8.7: Checklist verification**

Walk the submission checklist from spec §8 and confirm every box except logo is ticked.

No commit for this task — acceptance testing only. If any step fails, open a new task to fix the underlying issue and re-run Step 8 before proceeding to Task 9.

---

## Task 9: Tighten the plugin manifest after successful local test (if needed)

If Step 8.3 showed any unexpected skill/agent surfacing, this task fixes the manifest by adding explicit `skills` or `agents` path overrides. If Step 8.3 passed cleanly, SKIP this task.

**Files (only if needed):**
- Modify: `.cursor-plugin/plugin.json`

- [ ] **Step 9.1: Add explicit component paths in the manifest**

Only if needed, add to `.cursor-plugin/plugin.json`:

```json
{
  "skills": ["skills/orchestrate", "skills/judge"],
  "agents": ["agents/role-agent.md", "agents/role-clarify.md"]
}
```

- [ ] **Step 9.2: Re-run Step 8.3 after reload**

Confirm skill/agent visibility is as expected.

- [ ] **Step 9.3: Commit (only if changes were made)**

```bash
git add .cursor-plugin/plugin.json
git commit -m "fix: pin skills/ and agents/ paths explicitly in plugin manifest"
```

---

## Self-review checklist

(Author ran this after finishing the plan — fixed issues inline. Listed here for execution-time transparency.)

- **Spec coverage:** every spec section maps to at least one task.
  - §3 Repo layout → Tasks 2, 5
  - §4 Manifest → Task 5
  - §5 Self-location → Tasks 3, 4
  - §6 Branch/release → Appendix A (deferred)
  - §7 README/CHANGELOG/LICENSE/.gitignore/AGENTS.md → Tasks 1, 6, 7
  - §8 Submission checklist → Tasks 8 (acceptance testing), Appendix A (submission — deferred)
  - §9 Open assumptions → addressed in Tasks 8.3; marketplace branch pinning (§9 #1) addressed in Appendix A Step A.6
  - §11 Migration checklist → this plan IS the implementation of that checklist (Tasks 1–9 cover items 1–9; Appendix A covers item 10)
- **No placeholders:** every step contains actual content (file paths, exact strings, commands).
- **Type/path consistency:** every reference to a file path uses the post-restructure location consistently after Task 2.
- **Logical order:** hygiene files first (Task 1), structural move second (Task 2), feature additions third (Tasks 3–5), documentation fourth (Tasks 6–7), testing fifth (Task 8), contingency sixth (Task 9). Release cut and submission deferred to Appendix A, executed after the `plugin` branch is merged to `master`.
- **Each task ends with a commit** (except Task 8 acceptance test and Task 9 when no fix is needed).

---

## Appendix A — Release cut on `main` and marketplace submission (DEFERRED)

> **Status:** Not to be executed in the current session.
>
> **Precondition:** The `plugin` branch has been reviewed and merged back to `master`. You are on `master`, the merge commit is HEAD, and the working tree is clean.
>
> **Why deferred:** The restructure is being developed on the `plugin` feature branch. Releasing to `main` and submitting to the marketplace should only happen once the changes have landed on `master`.
>
> When ready, execute the steps below from a clean `master`.

**Files:** none; git operations only.

- [ ] **Step A.1: Ensure you are on `master` and the tree is clean**

```bash
git checkout master
git status
```
Expected: `On branch master` and `nothing to commit, working tree clean`.

```bash
git log --oneline -1
```
Expected: the merge commit that brought the `plugin` branch into `master`.

- [ ] **Step A.2: Create the `main` branch from `master`**

```bash
git checkout -b main
```

- [ ] **Step A.3: Tag `v0.1.0`**

```bash
git tag -a v0.1.0 -m "v0.1.0 — Initial Cursor Marketplace release"
```

- [ ] **Step A.4: Push `master`, `main`, and the tag**

```bash
git push origin master
git push origin main
git push origin v0.1.0
```

- [ ] **Step A.5: Verify on GitHub**

Open https://github.com/slior/dialectic-agentic in a browser. Confirm:
- `master` is the default branch (unchanged).
- `main` branch exists and has the same HEAD as `master`.
- `v0.1.0` release tag is visible under Releases / Tags.

- [ ] **Step A.6: Submit to the Cursor Marketplace**

Go to https://cursor.com/marketplace/publish.

Submit the repository URL (`https://github.com/slior/dialectic-agentic`). When prompted for a branch/ref (or equivalent field), select or enter `main`.

If the submission form only follows the GitHub default branch (open assumption #1 from spec §9), stop and decide:
- (a) Change GitHub default branch to `main` (simplest), or
- (b) Revisit the dev/release split (e.g., squash `master` = `main`).

- [ ] **Step A.7: Return to `master` for future development**

```bash
git checkout master
```

No new commit — tags and branch refs are the release artifact.
