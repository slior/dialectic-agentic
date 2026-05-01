# Design — Publishing Dialectic as a Cursor Plugin

**Date:** 2026-05-01
**Status:** Approved (pending user review)
**Scope:** Restructure the `dialectic-agent` repository to be installable as a Cursor plugin distributed through the Cursor Marketplace, preserving the existing clone-and-reference workflow as a secondary path.

---

## 1. Overview

Dialectic is a configuration-first, code-free multi-agent design debate system implemented entirely as agent skill files, prompt templates, and a JSON config. Today it is distributed by asking users to clone the repo and pass its path (`PROJECT=/abs/path`) to the `orchestrate` skill. This design converts the same repository into a Cursor plugin so users can install it from the Cursor Marketplace and invoke it with zero setup, while keeping the existing manual flow intact for developers and legacy users.

### Goals

- Ship a Cursor plugin called `dialectic` that contains the orchestrate skill, the judge skill, the supporting subagent definitions, and all shared prompt templates.
- Preserve backwards compatibility: existing users who clone the repo and pass `PROJECT` continue to work unchanged.
- Establish a release branch (`main`) and semantic version + git tag process so updates flow predictably to marketplace users.
- Keep a single source of truth — this repo is the plugin.

### Non-goals

- Building a logo for `v0.1.0` (deferred to a later minor release).
- In-plugin prompt customization for installed users (users who want to customize prompts fork or use the legacy flow).
- Multi-plugin repository / marketplace manifest (`.cursor-plugin/marketplace.json`) — this is a single-plugin repo.
- Hooks, MCP servers, or commands in this first release.

---

## 2. Summary of decisions

Captured here for quick reference; details follow in later sections.

| Decision | Choice |
| --- | --- |
| Repo strategy | (A) Restructure this repo to be the plugin |
| Prompts location | (P2) Plugin root, `prompts/` alongside `skills/` |
| Sub-skill visibility | (S3) `orchestrate` + `judge` as `skills/`, `role-agent` + `role-clarify` as `agents/`, `clarify` as an internal reference file under `skills/orchestrate/references/` |
| Branch strategy | GitHub default stays `master`; `main` is the release-only branch |
| Release process | (R1) Semver in `plugin.json` + git tags `vX.Y.Z` |
| Backwards compatibility | (BC2) Dual mode — honor `PROJECT` if provided, otherwise self-locate |
| License | MIT |
| Logo | Ship without logo in `v0.1.0` |

---

## 3. Repository layout (target state)

```text
dialectic-agentic/
├── .cursor-plugin/
│   └── plugin.json              # plugin manifest
├── skills/                      # auto-discovered by Cursor (user-facing)
│   ├── orchestrate/
│   │   ├── SKILL.md
│   │   ├── references/
│   │   │   ├── debate-loop.md        # unchanged (content-wise)
│   │   │   └── clarify-phase.md      # moved from .cursor/skills/clarify/SKILL.md
│   │   └── scripts/
│   │       └── create-debate-config.sh
│   └── judge/
│       └── SKILL.md             # user-facing; also runs synthesis post-hoc
├── agents/                      # subagent configs; not surfaced as /commands
│   ├── role-agent.md
│   └── role-clarify.md
├── prompts/                     # shared resource, consumed by role-agent and judge
│   ├── shared/…
│   ├── architect/…
│   ├── security/…
│   ├── performance/…
│   ├── kiss/…
│   ├── datamodeling/…
│   ├── testing/…
│   └── generalist/…
├── debate-config.json           # ships with the plugin; serves as final fallback
├── docs/
│   ├── configuration.md
│   └── superpowers/specs/…
├── AGENTS.md
├── README.md
├── CHANGELOG.md
├── LICENSE                      # MIT
├── .gitignore
└── .obsidian/                   # kept on disk, untracked via .gitignore
```

### Moves from the current layout

- `.cursor/skills/orchestrate/` → `skills/orchestrate/` (with internals preserved).
- `.cursor/skills/judge/SKILL.md` → `skills/judge/SKILL.md`.
- `.cursor/skills/role-agent/SKILL.md` → `agents/role-agent.md` (YAML frontmatter preserved; file renamed).
- `.cursor/skills/role-clarify/SKILL.md` → `agents/role-clarify.md` (same).
- `.cursor/skills/clarify/SKILL.md` → `skills/orchestrate/references/clarify-phase.md` (YAML frontmatter stripped; this file is read inline by the orchestrator, not dispatched as a subagent).
- `scripts/create-debate-config.sh` → `skills/orchestrate/scripts/create-debate-config.sh` (colocated with the only skill that invokes it).
- `.cursor/plans/` → `docs/plans/` (prevents `.cursor/plans/` files from being packaged into plugin installs).

### Unchanged

- `prompts/` stays at the repo root with its existing role subdirectories.
- `debate-config.json` stays at the repo root.
- `AGENTS.md`, `README.md`, `docs/configuration.md` stay at the repo root.

### Rationale: why `clarify` is not an `agents/` entry

`clarify` is not a subagent. Inspection of `debate-loop.md` (Phase 3) shows the orchestrator "follows the skill" inline — it reads the file and executes its instructions itself — rather than dispatching a Task-based subagent with parameters. This is the same semantic as how `debate-loop.md` itself is consumed. Treating `clarify` as an internal reference (sibling of `debate-loop.md`) matches its actual role and keeps the `agents/` directory limited to the two real subagent types: `role-agent` and `role-clarify`.

---

## 4. Plugin manifest

Location: `.cursor-plugin/plugin.json`

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

Fallback name: if `dialectic` is already taken in the Cursor marketplace, use `dialectic-debate`. `name` must be lowercase-kebab; both candidates comply.

### Explicitly omitted manifest fields

- `logo` — intentionally omitted for `v0.1.0`; add in a later release.
- `author.email` — omitted by default; decide before submission whether to include an email or not.
- `rules`, `agents`, `skills`, `commands`, `hooks`, `mcpServers` — omitted so Cursor uses automatic folder discovery from `skills/` and `agents/`.
- No `hooks/hooks.json` or `mcp.json` files — out of scope for `v0.1.0`.

---

## 5. Self-location and dual-mode PROJECT contract

### Contract

Every skill and subagent in the current codebase reads files via a `PROJECT` parameter (`{PROJECT}/prompts/...`, `{PROJECT}/debate-config.json`). This contract is preserved end-to-end. The only change is that the `orchestrate` and `judge` skills — the two user-facing entry points — gain a Phase 0.0 step that computes `PROJECT` automatically when the caller does not supply one.

### Phase 0.0: Resolve PLUGIN_ROOT (orchestrate skill)

Added at the top of `skills/orchestrate/SKILL.md`, immediately before the current Phase 0:

```text
## Phase 0.0: Resolve PLUGIN_ROOT

You just read this SKILL.md from an absolute path. Let that path be SKILL_PATH.
Compute CANDIDATE_ROOT by removing the trailing "/skills/orchestrate/SKILL.md"
from SKILL_PATH.

Verify all of the following exist under CANDIDATE_ROOT:
  - prompts/shared/system.md
  - prompts/generalist/system.md
  - debate-config.json

If the PROJECT parameter was supplied at invocation:
  - Set PROJECT to that value. (Do not overwrite the user's choice.)
Else if all three paths above exist:
  - Set PROJECT = CANDIDATE_ROOT.
Else:
  - STOP. Print to the user, verbatim:

    "I could not locate the dialectic plugin files automatically.
     Re-invoke this skill and include the parameter:
       PROJECT=<absolute path to the installed plugin or to a clone
                of the dialectic-agentic repository>
     For example: PROJECT=/Users/you/.cursor/plugins/local/dialectic"

For all downstream steps and every dispatched subagent, pass PROJECT as a
parameter exactly as set above.
```

### Phase 0.0 (judge skill)

Added at the top of `skills/judge/SKILL.md` so the judge is usable standalone for post-hoc synthesis on an existing debate workspace:

```text
## Phase 0.0: Resolve PLUGIN_ROOT (when invoked without PROJECT)

If the PROJECT parameter was supplied at invocation, skip this phase.

Otherwise, let SKILL_PATH be the absolute path you just loaded this SKILL.md
from. Compute CANDIDATE_ROOT by removing the trailing "/skills/judge/SKILL.md".
Verify that both prompts/shared/system.md and prompts/generalist/system.md
exist under CANDIDATE_ROOT. If so, set PROJECT = CANDIDATE_ROOT. Otherwise,
stop with the same error message as the orchestrate skill's Phase 0.0.
```

### Why this approach

- **The file-path anchor is reliable.** The agent loads `SKILL.md` from a fully-qualified absolute path; that path is a stable reference for every downstream lookup.
- **Dispatched subagents don't inherit file-location context.** `role-agent` and `role-clarify` receive parameters fresh on each Task invocation. Passing an absolute `PROJECT` from the orchestrator is the simplest, most robust contract. No sub-agent needs to self-locate.
- **The validation probes (`prompts/shared/system.md` etc.) catch broken layouts loudly.** If someone vendors the plugin incorrectly or reshuffles directories, we fail with an actionable error instead of silently producing nonsense.
- **Relative paths rejected as an alternative** because (a) Task-dispatched subagents don't have a stable "current file" anchor, (b) relative paths break under symlinks and vendored copies, (c) the current `PROJECT`-based contract is already clean — the minimal change is to auto-populate `PROJECT`.

### File path rewrites in the restructure

| Today | After restructure |
| --- | --- |
| `{PROJECT}/.cursor/skills/orchestrate/scripts/create-debate-config.sh` | `{PROJECT}/skills/orchestrate/scripts/create-debate-config.sh` |
| `{PROJECT}/.cursor/skills/clarify/SKILL.md` (in debate-loop.md) | relative `references/clarify-phase.md` (sibling file) |
| `{PROJECT}/.cursor/skills/role-agent/SKILL.md` | `{PROJECT}/agents/role-agent.md` |
| `{PROJECT}/.cursor/skills/role-clarify/SKILL.md` | `{PROJECT}/agents/role-clarify.md` |
| `{PROJECT}/.cursor/skills/judge/SKILL.md` | `{PROJECT}/skills/judge/SKILL.md` |
| `{PROJECT}/prompts/…` | unchanged |
| `{PROJECT}/debate-config.json` | unchanged |

### debate-config.json discovery chain

Unchanged in structure; rung names updated:

1. `DEBATE_CONFIG` parameter (if valid)
2. `{WORKSPACE}/debate-config.json` (if present)
3. `{PROJECT}/debate-config.json` — **now the plugin's shipped default, always available for installed users**

This removes the need for first-time plugin users to copy or generate a config file before running a debate.

---

## 6. Branch and release strategy

### Branches

- **`master`** — GitHub default; active development; all PRs land here.
- **`main`** — release-only; created fresh from `master` at first release and fast-forwarded on each subsequent release.

### Per-release process

1. On `master`: bump `version` in `.cursor-plugin/plugin.json`; add an entry to `CHANGELOG.md`; commit.
2. `git checkout main && git merge --ff-only master && git tag vX.Y.Z && git push origin main --tags`.
3. For the first release only: submit the repo to [cursor.com/marketplace/publish](https://cursor.com/marketplace/publish) pointing at `main`.
4. For subsequent releases: push to `main` and rely on whatever refresh mechanism the marketplace uses.

### Open assumption

**Marketplace branch pinning.** The Cursor plugin reference documentation does not explicitly document whether the submission form supports pinning a plugin to a branch other than the GitHub default. The plan is to submit pointing at `main` (via the form's repository/URL field) at first submission time. If the marketplace insists on following the GitHub default branch only, we will need to either (a) swap the GitHub default to `main`, or (b) reconsider the dev/release split. This uncertainty is called out again in Section 9.

---

## 7. README, CHANGELOG, LICENSE, .gitignore

### README.md rewrite

Proposed section ordering for the rewritten README:

1. **What it does** — keep existing prose.
2. **Install (primary)** — install from the Cursor Marketplace; invoke the `orchestrate` skill.
3. **Quickstart** — `mkdir workspace` → write `problem.md` → invoke orchestrate with `WORKSPACE=<path>`. Drop the step that asks users to copy `debate-config.json`; the plugin ships with a default.
4. **Output** — unchanged.
5. **Configuration** — unchanged.
6. **Prompt Customization** — note customization requires forking for installed-plugin users.
7. **Adding a New Role** — unchanged, with a note that this also requires forking for installed-plugin users.
8. **Adding MCP Tools** — unchanged.
9. **Legacy: clone-and-reference flow** — existing Quickstart preserved verbatim; explicit `PROJECT=/abs/path` example.
10. **Contributing** — dev on `master`; releases via `main`; link to `CHANGELOG.md`.

### CHANGELOG.md (new)

Keep-a-changelog format. Initial entry:

```markdown
# Changelog

## 0.1.0 — 2026-XX-XX
### Added
- Initial Cursor Marketplace release of the Dialectic plugin.
```

### LICENSE (new)

Standard MIT license text with copyright line `Copyright (c) 2026 Lior S.` (adjust attribution as you prefer).

### .gitignore update

```text
/tmp/
.obsidian/
.DS_Store
```

### AGENTS.md update

Update the "Main Directories" and "Main Files" sections to reference `skills/`, `agents/`, and the relocated `scripts/` path. Remove the line "`.cursor/skills/` - Core orchestration and role skills used by the host agent." and replace with equivalent entries for `skills/` and `agents/`.

---

## 8. Submission checklist

Acceptance criteria for the first Cursor Marketplace submission:

- [ ] Valid `.cursor-plugin/plugin.json` at repo root
- [ ] `name: dialectic` is unique in the marketplace (fallback: `dialectic-debate`)
- [ ] `description` clearly explains purpose
- [ ] All skills (`skills/*/SKILL.md`) have YAML frontmatter with `name` and `description`
- [ ] All agents (`agents/*.md`) have YAML frontmatter with `name` and `description`
- [ ] `README.md` documents marketplace install + legacy clone flow
- [ ] `LICENSE` file present (MIT)
- [ ] `CHANGELOG.md` present with `0.1.0` entry
- [ ] All manifest paths are relative (no `..`, no absolute)
- [ ] Plugin tested locally via `ln -s /Users/liors/dev/dialectic-agent ~/.cursor/plugins/local/dialectic`, Cursor reloaded, and a full debate run from a fresh workspace with no `PROJECT` parameter succeeds end-to-end
- [ ] `main` branch exists, fast-forwarded from `master`, tagged `v0.1.0`
- [ ] Submission form at cursor.com/marketplace/publish points to `main`

---

## 9. Open assumptions to verify

These are assumptions baked into the design that should be confirmed during implementation or at submission time:

1. **Marketplace branch pinning (Section 6).** Assumed: the submission form accepts a branch/URL targeting `main` even though the repo default is `master`. Verify before or during submission. Mitigation if false: swap GitHub default to `main`.
2. **Absolute-path handling in Task dispatch.** Assumed: when the orchestrator passes `PROJECT=/abs/path` to a Task-dispatched subagent, the subagent can use that path directly for reads. Verified today in the non-plugin flow; restructure does not change the semantics.
3. **Plugin install path shape.** Assumed: `skills/orchestrate/SKILL.md` resolves to a real absolute path when Cursor loads it from an installed plugin. Verify during the local-symlink test.
4. **Agents-folder discovery.** Assumed: Cursor auto-discovers `agents/*.md` as subagent-style agents (non-user-invocable), per the plugin reference docs. Verify that `role-agent.md` and `role-clarify.md` do NOT surface as `/role-agent` in the user skill menu after local install.
5. **Dual-mode Phase 0.0.** Assumed: the orchestrate skill's new Phase 0.0 does not regress the existing clone-and-reference flow when `PROJECT` is provided. Covered by keeping the legacy test scenario in the acceptance criteria.

---

## 10. Out of scope / future work

- Plugin logo (SVG or PNG in `assets/`), referenced from the manifest. Candidate for `v0.1.1` or `v0.2.0`.
- Workspace-local prompt override mechanism so installed-plugin users can customize prompts without forking.
- `/commands/start-debate.md` for a one-liner debate launch.
- Hooks (e.g., `sessionStart` auto-creation of a debate workspace).
- Marketplace manifest (`.cursor-plugin/marketplace.json`) if we ever split into multiple plugins (e.g., a separate minimal "role-agent-kit" plugin).

---

## 11. Migration checklist (for implementation plan)

High-level steps the implementation plan will break down into detailed tasks:

1. Create `.cursor-plugin/plugin.json` with the manifest from Section 4.
2. Move directories per Section 3 ("Moves from the current layout"): `.cursor/skills/*` → `skills/*` and `agents/*`; `scripts/` → `skills/orchestrate/scripts/`; `clarify` content into `skills/orchestrate/references/clarify-phase.md`; `.cursor/plans/` → `docs/plans/`.
3. Rewrite `skills/orchestrate/SKILL.md`:
   - Insert the new Phase 0.0 (Section 5).
   - Update the `scripts/create-debate-config.sh` path to `{PROJECT}/skills/orchestrate/scripts/create-debate-config.sh`.
4. Rewrite `skills/orchestrate/references/debate-loop.md`:
   - Change the clarify invocation from `Follow the skill at {PROJECT}/.cursor/skills/clarify/SKILL.md` to the inline reference `references/clarify-phase.md`.
   - Update `role-agent` path from `{PROJECT}/.cursor/skills/role-agent/SKILL.md` to `{PROJECT}/agents/role-agent.md`.
   - Update `judge` path from `{PROJECT}/.cursor/skills/judge/SKILL.md` to `{PROJECT}/skills/judge/SKILL.md`.
5. Rewrite `skills/judge/SKILL.md` to add its Phase 0.0 (Section 5) for standalone invocation.
6. Rewrite `agents/role-agent.md` and `agents/role-clarify.md` — no functional changes; confirm frontmatter is intact.
7. Add `LICENSE` (MIT), `CHANGELOG.md`, updated `.gitignore`, and updated `AGENTS.md`.
8. Rewrite `README.md` per Section 7.
9. Local testing: symlink `~/.cursor/plugins/local/dialectic` → repo root; reload Cursor; run a full debate from a fresh workspace with no `PROJECT` parameter; verify `role-agent`/`role-clarify` are not user-invocable; verify the clone-and-reference flow still works by passing `PROJECT` explicitly from a separate directory.
10. Create `main` branch from `master`; tag `v0.1.0`; push; submit to the Cursor Marketplace pointing at `main`.
