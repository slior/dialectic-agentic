# Agent Plugins Conformance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make this repository a conformant [Agent Plugins](https://agent-plugins.org) v1.0.0 package by moving the manifest to a root `plugin.json`, fix the plugin-root resolution bug in `create-debate-config.sh`, and update every document that describes the manifest location or install flow.

**Architecture:** The portable surface of the Agent Plugins standard is small: a root `plugin.json` carrying `$schema` and `name`, skills discovered from `skills/`, and an optional `mcp.json`. This repo's `skills/` tree already conforms, so the work is a manifest relocation plus a documentation sweep — no new production code. `agents/`, `prompts/`, `debate-config.json`, and `docs/` stay at the package root as plugin payload that the skills read through their resolved `{PROJECT}` path; they are not portable component types and are not asked to be.

**Tech Stack:** JSON manifest, POSIX shell (`sh`), Markdown skill and doc files, Git. `python3` is used only for one-off validation commands.

## Global Constraints

- Spec version targeted: Agent Plugins **1.0.0**. Every rule cited below (§N) refers to <https://agent-plugins.org/specification>.
- The manifest MUST live at `plugin.json` in the plugin root (§5.1). No other file may replace or supplement its core fields.
- `$schema` is REQUIRED and its value MUST be exactly `https://agent-plugins.org/schemas/1.0.0/plugin.schema.json` (§5.2, §5.3). A missing or unrecognized value means the client rejects the plugin.
- The manifest schema is **closed**. The only permitted top-level fields are `$schema`, `name`, `version`, `description`, `author`, `homepage`, `repository`, `license`, `keywords`, `extensions` (§5.2).
- `author` may contain only `name`, `email`, and `url`, each a string (§5.4). Any other key makes the manifest invalid.
- `name` MUST be 1–64 characters of `a-z`, `0-9`, `-`, `.`; MUST start and end alphanumeric; MUST NOT contain `--` or `..` (§5.5). `dialectic` satisfies this.
- Skills are discovered from immediate child directories of `skills/` containing a regular `SKILL.md` (§7.1). Each `SKILL.md` `name` MUST match its parent directory name (Agent Skills spec).
- No path supplied by the package may resolve outside the filesystem-resolved plugin root (§4.1). This is why the script bug in Task 2 is a conformance issue and not just a defect.
- Plugin `version` SHOULD be Semantic Versioning (§10.2).
- Execution branch: **`plugin_standard`** (already checked out, clean, level with `master`). Every task ends in its own commit. Release and marketplace steps are deferred to Appendix A.

---

## Decisions

Each decision below is load-bearing for the tasks that follow. Rationale, rejected alternatives, and the reversal path are recorded so a future reader does not have to re-derive them.

### D1: The root `plugin.json` replaces `.cursor-plugin/plugin.json` — we do not keep both

**Decision.** Create `plugin.json` at the repo root and delete `.cursor-plugin/plugin.json`, leaving exactly one manifest.

**Why.** Cursor identifies a plugin's format by manifest location: a root `plugin.json` means Agent Plugin, `.cursor-plugin/plugin.json` means Cursor Plugin. Cursor's docs do not define precedence when both exist, so keeping both puts the repo in undocumented territory for the one client we test against. Two manifests also means two places to bump `version` on every release, which will drift. And §8 of the spec says client-specific data belongs under a reverse-domain namespace (`extensions` in the manifest, or a top-level `com.example.client/` directory); `.cursor-plugin/` is neither, so keeping it is a soft violation of the thing we are trying to conform to.

**What we give up, and why it's acceptable.** The Cursor Plugin format supports component types the standard does not: rules, commands, hooks, variables, and `agents/`. We use exactly one of those — `agents/` — and only as data files (see D2), so nothing breaks. The other real loss is the `logo` field, which is not permitted by the closed portable schema; a conformant client must report and ignore it. There is no logo committed to this repo today, so nothing is lost now.

**Rejected alternative: keep both manifests.** Rejected for the precedence ambiguity and version drift above. **Rejected alternative: root manifest plus a `com.cursor…`-namespaced extension entry for Cursor-specific data.** Rejected because Cursor's docs do not publish its reverse-domain namespace, so we would be inventing a key no client reads.

**Risk.** If the plugin is already listed in the marketplace, the next re-index changes its detected format from Cursor Plugin to Agent Plugin. Both formats are supported and install identically per Cursor's docs, but this is a distribution-visible change; Appendix A calls it out at submission/refresh time.

**Reversal.** `git revert` the Task 1 commit restores `.cursor-plugin/plugin.json`. Task 7 is the gate that would trigger this.

### D2: `agents/` stays at the package root, unchanged

**Decision.** Keep `agents/role-agent.md` and `agents/role-clarify.md` where they are. Do not move them under `skills/`, and do not move them into a client-namespaced directory.

**Why.** Agent Plugins v1 defines exactly two component types, and the spec's Design Decisions section names agents, commands, hooks, and rules as deliberately out of scope for v1. That makes `agents/` invisible to the standard — but invisible is not forbidden. Nothing in the spec restricts what else may sit at the plugin root; the spec's own example layout includes `LICENSE` and `CHANGELOG.md`. These two files are package payload that the orchestrator reads by path, exactly like `prompts/` and `debate-config.json`.

Moving them under `skills/` would be actively wrong: §7.1 makes every immediate child of `skills/` containing a `SKILL.md` a user-discoverable skill, and these are internal subagent instructions that must never be user-invocable. Moving them into a namespaced extension directory would break the `{PROJECT}/agents/role-agent.md` references in the skills and buy nothing, since no client reads that namespace.

**Consequence handled in Task 3.** Under the Cursor Plugin format, Cursor discovered `agents/*.md` and registered `role-agent` / `role-clarify` as dispatchable subagent types. After D1 that registration probably goes away. The orchestrator never depended on it — `references/debate-loop.md` dispatches by naming the instruction *file* — but the wording is loose enough that an implementer could read it as "use the registered `role-agent` subagent." Task 3 makes the contract explicit so the dispatch is robust either way.

### D3: Bump `version` to `0.2.0`

**Decision.** The new manifest declares `"version": "0.2.0"`, with a matching `CHANGELOG.md` entry.

**Why.** `v0.1.0` is already tagged in this repo, so `0.1.0` is spent and new work cannot be folded into it. Clients MAY use `version` for update checks and cache freshness (§10.2), and the manifest relocation changes how clients load the package — that is user-visible and needs a version. It is backward compatible for anyone using the skills, so minor, not major.

### D4: No validator script is committed; the checks live in `docs/development.md`

**Decision.** Tasks 1 and 2 verify conformance with `python3` and `sh` commands typed inline. The same commands are recorded permanently in `docs/development.md` under a new "Validate the package" section. No `scripts/` directory is reintroduced at the repo root.

**Why.** This repository is deliberately code-free — no test framework, no CI, no dependencies. A committed validator would be the only executable at the root, would need its own maintenance, and would reintroduce the root `scripts/` directory that the 0.1.0 restructure removed on purpose. Documenting the commands in the doc that already covers local development and troubleshooting keeps them findable at the moment they are needed (before a release) without adding a maintenance surface. If conformance checks ever need to run automatically, that is a CI task with its own plan.

**Note on validation depth.** The manifest check in Task 1 enforces the §5.2–§5.5 rules directly rather than fetching the published JSON Schema, because clients are forbidden from retrieving schemas at load time (§5.2) and the spec text is authoritative over the machine-readable schema anyway. The skills check verifies frontmatter presence and that `name` matches its directory; it does not measure `description`/`compatibility` character limits, because parsing YAML folded scalars without PyYAML is not worth it and both fields are far inside their 1024 / 500 character caps today.

### D5: Fix the script by correcting the depth and adding a root assertion

**Decision.** Change `../../../..` to `../../..` and add an explicit check that the resolved root contains `prompts/` and `debate-config.json`, failing with a message that prints both the script path and the resolved root.

**Why.** The depth fix alone is correct but leaves the same trap armed for the next move: this exact line has now been wrong twice (once pointing at a non-existent `orchestrator/` directory, once off by a level after the `.cursor/` prefix disappeared). The current failure mode is a confusing one — the script reports "No available roles were found under /Users/liors/dev/prompts," which reads like a missing-prompts problem rather than a bad-root problem. Six lines of shell converts it into a diagnostic that names the actual cause.

**Rejected alternative: walk up the tree until a directory containing `debate-config.json` is found.** More code, and it papers over layout mistakes instead of reporting them — the script would silently succeed from the wrong root if one ever existed above it. A fixed depth plus a loud assertion is the better trade for a script that lives at exactly one path inside the package.

### D6: Historical plan and spec documents get a supersede note, not a rewrite

**Decision.** Prepend a short note to `docs/superpowers/plans/2026-05-01-cursor-plugin-publishing.md` and `docs/superpowers/specs/2026-05-01-cursor-plugin-publishing-design.md` pointing at this plan, and leave their bodies alone. Leave `docs/plans/improve_agent_skills_compliance_8a66858f.plan.md` untouched entirely.

**Why.** These are dated records of decisions that were correct when made. Editing them to match today's layout destroys the audit trail and makes the repo's history unreadable; leaving them with no pointer means the next reader follows Task 5 of the old plan and recreates `.cursor-plugin/plugin.json`. A note at the top solves the second problem without causing the first. The `docs/plans/` file is a completed plan from an earlier tool with already-stale `.cursor/skills/` paths and no instruction anyone would follow today, so it needs nothing.

### D7: Documents that describe the manifest are updated in full

**Decision.** `AGENTS.md`, `README.md`, and `docs/development.md` are corrected everywhere they name the manifest location, the plugin format, or the install flow. `docs/configuration.md` needs no change (it documents `debate-config.json` fields only, which are untouched).

**Why.** `AGENTS.md` is an always-applied rule file — a stale directory map there actively misleads every future agent session. `docs/development.md` is the local-install runbook and currently instructs the reader to verify a file we are deleting, and its troubleshooting step 4 points at a task in the old plan that no longer applies. These are not cosmetic edits; they are the difference between a working and a broken local install.

### D8: `.gitignore` and `debate-config.json` are not touched

**Decision.** No changes to `.gitignore`; the new root `plugin.json` is not matched by any existing pattern (`/tmp/`, `.obsidian/`, `.DS_Store`). No changes to `debate-config.json`.

**Why.** Verified, and out of scope. Note for Task 7: `tmp/` is gitignored but exists in the working tree with model-experiment output, so the local install mirror must exclude it — that exclusion is added to `docs/development.md` in Task 5.

---

## File Structure

| File | Change | Responsibility after the change |
|---|---|---|
| `plugin.json` | Create | The single portable manifest; identity, metadata, and targeted spec version |
| `.cursor-plugin/plugin.json` | Delete | — (directory removed) |
| `skills/orchestrate/scripts/create-debate-config.sh` | Modify lines 11–13 | Resolves the plugin root correctly and asserts it |
| `skills/orchestrate/references/debate-loop.md` | Modify line 58 | States the subagent dispatch contract explicitly |
| `AGENTS.md` | Modify | Accurate directory/file map for future agent sessions |
| `README.md` | Modify install section | User-facing install paths and the standard the package targets |
| `docs/development.md` | Modify throughout, add one section | Local install runbook plus the pre-release conformance checks |
| `CHANGELOG.md` | Add `0.2.0` entry | Release history |
| `docs/superpowers/plans/2026-05-01-cursor-plugin-publishing.md` | Prepend note | Historical record, marked partially superseded |
| `docs/superpowers/specs/2026-05-01-cursor-plugin-publishing-design.md` | Prepend note | Historical record, marked partially superseded |

---

## Task 1: Create the conformant root manifest

**Files:**
- Create: `plugin.json`
- Delete: `.cursor-plugin/plugin.json` (and the now-empty `.cursor-plugin/` directory)

**Depends on:** nothing.
**Produces:** a root `plugin.json` declaring `name: dialectic` and `version: 0.2.0`. Tasks 5, 6, and 7 reference both the path and the version.

- [ ] **Step 1.1: Write the conformance check and watch it fail**

Save the check to a scratch path (not the repo — see D4):

```bash
cat > /tmp/validate-plugin-manifest.py << 'PYEOF'
import json, pathlib, re, sys

ALLOWED = {"$schema", "name", "version", "description", "author",
           "homepage", "repository", "license", "keywords", "extensions"}
CANONICAL = "https://agent-plugins.org/schemas/1.0.0/plugin.schema.json"

path = pathlib.Path("plugin.json")
if not path.is_file():
    print("FAIL: no plugin.json at the plugin root (spec 5.1)")
    sys.exit(1)

try:
    manifest = json.loads(path.read_text())
except json.JSONDecodeError as exc:
    print(f"FAIL: plugin.json is not valid JSON: {exc}")
    sys.exit(1)

errors = []
if not isinstance(manifest, dict):
    errors.append("manifest is not a JSON object (5.2)")
    manifest = {}

unknown = sorted(set(manifest) - ALLOWED)
if unknown:
    errors.append(f"unknown top-level fields {unknown} (closed schema, 5.2)")

if manifest.get("$schema") != CANONICAL:
    errors.append(f"$schema must be exactly {CANONICAL} (5.2/5.3)")

name = manifest.get("name")
if not isinstance(name, str):
    errors.append("name is missing or not a string (5.3)")
elif (not re.fullmatch(r"[a-z0-9]([a-z0-9.\-]{0,62}[a-z0-9])?", name)
      or "--" in name or ".." in name):
    errors.append(f"name {name!r} violates the naming constraints (5.5)")

for field in ("version", "description", "homepage", "repository", "license"):
    if field in manifest and not isinstance(manifest[field], str):
        errors.append(f"{field} must be a string (5.4)")

if "author" in manifest:
    author = manifest["author"]
    if not isinstance(author, dict):
        errors.append("author must be an object (5.4)")
    else:
        extra = sorted(set(author) - {"name", "email", "url"})
        if extra:
            errors.append(f"author has disallowed fields {extra} (5.4)")
        if any(not isinstance(v, str) for v in author.values()):
            errors.append("author values must be strings (5.4)")

if "keywords" in manifest:
    keywords = manifest["keywords"]
    if not isinstance(keywords, list) or any(not isinstance(k, str) for k in keywords):
        errors.append("keywords must be an array of strings (5.4)")

if "extensions" in manifest and not isinstance(manifest["extensions"], dict):
    errors.append("extensions must be an object (8.1)")

if errors:
    for error in errors:
        print(f"FAIL: {error}")
    sys.exit(1)

print("PASS: plugin.json conforms to Agent Plugins 1.0.0")
PYEOF
python3 /tmp/validate-plugin-manifest.py
```

Expected output:

```text
FAIL: no plugin.json at the plugin root (spec 5.1)
```

Exit code 1. This is the failing state we are fixing.

- [ ] **Step 1.2: Write the root manifest**

Write to `plugin.json` (repo root):

```json
{
  "$schema": "https://agent-plugins.org/schemas/1.0.0/plugin.schema.json",
  "name": "dialectic",
  "version": "0.2.0",
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

Every field except `$schema` and `version` is carried over verbatim from `.cursor-plugin/plugin.json`; all of them are already legal under the closed schema. `$schema` is new and required. `version` moves from `0.1.0` to `0.2.0` per D3.

- [ ] **Step 1.3: Run the check and confirm it passes**

```bash
python3 /tmp/validate-plugin-manifest.py
```

Expected output:

```text
PASS: plugin.json conforms to Agent Plugins 1.0.0
```

Exit code 0.

- [ ] **Step 1.4: Verify the skills still satisfy the discovery rules**

```bash
python3 << 'PYEOF'
import pathlib, re, sys

errors = []
skills = pathlib.Path("skills")
found = []
for child in sorted(skills.iterdir()):
    if not child.is_dir():
        continue
    skill_md = child / "SKILL.md"
    if not skill_md.is_file():
        errors.append(f"{child}: no regular SKILL.md, not discoverable (7.1)")
        continue
    found.append(child.name)
    text = skill_md.read_text()
    match = re.match(r"---\n(.*?)\n---\n", text, re.S)
    if not match:
        errors.append(f"{skill_md}: missing YAML frontmatter")
        continue
    frontmatter = match.group(1)
    name_match = re.search(r"^name:[ \t]*(\S+)[ \t]*$", frontmatter, re.M)
    if not name_match:
        errors.append(f"{skill_md}: no name field")
    elif name_match.group(1) != child.name:
        errors.append(f"{skill_md}: name {name_match.group(1)!r} != directory {child.name!r}")
    if not re.search(r"^description:", frontmatter, re.M):
        errors.append(f"{skill_md}: no description field")

print(f"discovered skills: {found}")
for error in errors:
    print(f"FAIL: {error}")
sys.exit(1 if errors else 0)
PYEOF
```

Expected output:

```text
discovered skills: ['judge', 'orchestrate']
```

Exit code 0, no `FAIL:` lines. No changes to the skills are expected — this confirms the assumption that the `skills/` tree was already conformant.

- [ ] **Step 1.5: Remove the Cursor manifest**

```bash
git rm .cursor-plugin/plugin.json
rmdir .cursor-plugin
ls -la .cursor-plugin 2>/dev/null || echo "ok: .cursor-plugin removed"
```

Expected: `ok: .cursor-plugin removed`.

- [ ] **Step 1.6: Confirm no runtime file references the old manifest path**

```bash
rg -n '\.cursor-plugin' skills/ agents/ prompts/ debate-config.json
```

Expected: no matches. (Matches remain in `AGENTS.md`, `README.md`, `docs/` — those are Tasks 4, 5, and 6.)

- [ ] **Step 1.7: Commit**

```bash
git add plugin.json .cursor-plugin
git commit -m "feat: add Agent Plugins 1.0.0 root manifest, drop .cursor-plugin manifest"
```

Verify:

```bash
git show --stat HEAD
```

Expected: `plugin.json` added, `.cursor-plugin/plugin.json` deleted, nothing else.

---

## Task 2: Fix plugin-root resolution in `create-debate-config.sh`

**Files:**
- Modify: `skills/orchestrate/scripts/create-debate-config.sh:11-13`

**Depends on:** nothing (independent of Task 1).
**Produces:** a script that resolves `PROJECT_ROOT` to the plugin root from `skills/orchestrate/scripts/`, and exits 1 with a diagnostic naming the resolved root when it cannot.

**Background.** The script computes its root by walking up from its own directory. It walks up four levels, which was correct at the old location `.cursor/skills/orchestrate/scripts/` and is one level too many at the current `skills/orchestrate/scripts/`. The result resolves *outside* the plugin root, which is also what §4.1 forbids for package-supplied paths. Role discovery therefore always fails and the script exits 1 before asking anything.

- [ ] **Step 2.1: Reproduce the failure**

```bash
sh skills/orchestrate/scripts/create-debate-config.sh </dev/null 2>&1 | head -20
```

Expected output (the last line is the failure; the resolved path is the repo's *parent*):

```text
Interactive Debate Config Generator
This script will create a debate configuration JSON file.

No available roles were found under /Users/liors/dev/prompts
```

Note: the script is interactive, so `</dev/null` and `head -20` bound the run. In this pre-fix state it exits on its own before prompting.

- [ ] **Step 2.2: Fix the resolution and assert the root**

In `skills/orchestrate/scripts/create-debate-config.sh`, find lines 11–13:

```sh
# Resolve project paths from script location.
PROJECT_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/../../../.." && pwd)"
PROMPTS_DIR="$PROJECT_ROOT/prompts"
```

Replace with:

```sh
# Resolve the plugin root from this script's location:
# scripts/ -> orchestrate/ -> skills/ -> plugin root.
PROJECT_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/../../.." && pwd)"
PROMPTS_DIR="$PROJECT_ROOT/prompts"

if [ ! -d "$PROMPTS_DIR" ] || [ ! -f "$PROJECT_ROOT/debate-config.json" ]; then
  printf 'Cannot locate the plugin root from this script.\n' >&2
  printf '  script:        %s\n' "$0" >&2
  printf '  resolved root: %s\n' "$PROJECT_ROOT" >&2
  printf 'Expected both %s/prompts/ and %s/debate-config.json to exist.\n' \
    "$PROJECT_ROOT" "$PROJECT_ROOT" >&2
  printf 'Run the script from its packaged location, skills/orchestrate/scripts/.\n' >&2
  exit 1
fi
```

Leave the existing `list_roles` guard (line 135 pre-edit) and the "No available roles were found" check further down in place. They now cover a different case — a present but empty `prompts/` — and cost nothing.

- [ ] **Step 2.3: Syntax-check the script**

```bash
sh -n skills/orchestrate/scripts/create-debate-config.sh && echo "syntax: OK"
```

Expected: `syntax: OK`.

- [ ] **Step 2.4: Confirm the root now resolves inside the package**

```bash
sh skills/orchestrate/scripts/create-debate-config.sh </dev/null 2>&1 | head -6
```

Expected output, exactly these six lines:

```text
Interactive Debate Config Generator
This script will create a debate configuration JSON file.

Role suggestions loaded from /Users/liors/dev/dialectic-agent/prompts
How many debating agents do you want? [4]: 
Agent 1 of 4
```

The resolved path must be the repo root, not its parent. The script then reaches the role prompt with no input available and loops on "Role is required." until `head` closes the pipe and terminates it. That truncation is expected, not a failure. Confirm no `debate-config-*.json` file was written to the repo root:

```bash
ls debate-config-*.json 2>/dev/null || echo "ok: no stray config written"
```

Expected: `ok: no stray config written`.

- [ ] **Step 2.5: Verify the assertion fires when the root is wrong**

Copy the script somewhere with no package around it and confirm the new diagnostic:

```bash
mkdir -p /tmp/dialectic-badroot/a/b/c
cp skills/orchestrate/scripts/create-debate-config.sh /tmp/dialectic-badroot/a/b/c/
sh /tmp/dialectic-badroot/a/b/c/create-debate-config.sh </dev/null 2>&1 | head -10
rm -rf /tmp/dialectic-badroot
```

Expected output contains:

```text
Cannot locate the plugin root from this script.
  script:        /tmp/dialectic-badroot/a/b/c/create-debate-config.sh
  resolved root: /tmp/dialectic-badroot
```

- [ ] **Step 2.6: Commit**

```bash
git add skills/orchestrate/scripts/create-debate-config.sh
git commit -m "fix(orchestrate): resolve plugin root one level up, assert it exists

The script walked up four directories, correct at the old
.cursor/skills/orchestrate/scripts/ location but one level too many at
skills/orchestrate/scripts/. Role discovery therefore looked for prompts/
outside the package and the script always exited early."
```

---

## Task 3: State the subagent dispatch contract explicitly

**Files:**
- Modify: `skills/orchestrate/references/debate-loop.md:58`

**Depends on:** D1/D2 (the reason this matters).
**Produces:** dispatch instructions that do not rely on a client registering `agents/*.md` as named subagent types.

**Background.** With the Cursor manifest gone, Cursor will most likely stop registering `role-agent` and `role-clarify` as named subagent types, because `agents/` is a Cursor Plugin component and not part of the portable standard. The orchestrator never needed that registration — it names the instruction file — but the current phrasing ("invoke a subagent with agent instructions `{PROJECT}/agents/role-agent.md`") is loose enough to be read as "use the registered `role-agent` agent." One sentence removes the ambiguity. `references/clarify-phase.md` already phrases its dispatch correctly ("Read agent instructions: {PROJECT}/agents/role-clarify.md") and needs no change; keeping the authoritative wording in one place avoids duplicating it.

- [ ] **Step 3.1: Edit the proposal-phase dispatch**

In `skills/orchestrate/references/debate-loop.md`, find this line:

```text
For each agent, invoke a subagent with agent instructions `{PROJECT}/agents/role-agent.md` and parameters:
```

Replace with:

```text
For each agent, dispatch a general-purpose subagent whose instructions are the **contents** of `{PROJECT}/agents/role-agent.md`. Read that file and pass its text to the subagent; do not depend on a client-registered subagent type named `role-agent`. Pass these parameters:
```

The critique and refinement phases say "Same parameters as proposal phase" and inherit this contract; no further edits are needed.

- [ ] **Step 3.2: Verify**

```bash
rg -n 'role-agent' skills/orchestrate/references/debate-loop.md
```

Expected: one match, on the edited line, containing `contents`.

```bash
rg -n 'agents/role-(agent|clarify)\.md' skills/ agents/
```

Expected: exactly two matches — the edited line in `debate-loop.md` and the existing line in `clarify-phase.md`. Both point inside the plugin root (§4.1).

- [ ] **Step 3.3: Commit**

```bash
git add skills/orchestrate/references/debate-loop.md
git commit -m "docs(orchestrate): dispatch role agents by file contents, not registered type"
```

---

## Task 4: Update `AGENTS.md` and `README.md`

**Files:**
- Modify: `AGENTS.md`
- Modify: `README.md`

**Depends on:** Task 1 (the manifest path it documents).
**Produces:** an accurate always-applied directory map and a user-facing install section that names the standard.

- [ ] **Step 4.1: Update the `AGENTS.md` project overview**

Find:

```text
Dialectic Agent-Native is a configuration-first, code-free multi-agent design debate system.
```

Replace with:

```text
Dialectic Agent-Native is a configuration-first, code-free multi-agent design debate system.
It ships as an [Agent Plugins](https://agent-plugins.org) 1.0.0 package: a root `plugin.json`
manifest with user-facing skills under `skills/`.
```

- [ ] **Step 4.2: Update the `AGENTS.md` directory map**

Find:

```text
- `.cursor-plugin/` - Cursor plugin manifest (`plugin.json`).
```

Delete that line entirely (including its newline).

Then find:

```text
- `.cursor-plugin/plugin.json` - Cursor plugin manifest used by the marketplace.
```

Replace with:

```text
- `plugin.json` - Agent Plugins manifest at the package root. Required by the standard; carries the plugin name, version, and metadata.
```

- [ ] **Step 4.3: Verify `AGENTS.md`**

```bash
rg -n '\.cursor-plugin' AGENTS.md
```

Expected: no matches.

```bash
rg -n 'plugin\.json|agent-plugins\.org' AGENTS.md
```

Expected: at least two matches (the overview line and the file-map line).

- [ ] **Step 4.4: Rewrite the `README.md` install section**

Find this block in `README.md` (lines 11–17):

````text
## Install

### From the Cursor Marketplace (recommended)

Search for **Dialectic** in the Cursor Marketplace and install it. Cursor handles the files; no cloning, no path setup.

### Prerequisites
````

Replace with:

````text
## Install

Dialectic ships as an [Agent Plugin](https://agent-plugins.org) targeting specification version 1.0.0: a self-contained directory with a `plugin.json` manifest at its root and its skills under `skills/`. Any client that implements the standard can load it; Cursor is the first-class target.

### From the Cursor Marketplace (recommended)

Search for **Dialectic** in the Cursor Marketplace and install it. Cursor handles the files; no cloning, no path setup.

### From a clone

Clone the repository into your client's local plugin directory and reload the client. For Cursor:

```bash
git clone https://github.com/slior/dialectic-agentic.git ~/.cursor/plugins/local/dialectic
```

Then run **Developer: Reload Window**. See [`docs/development.md`](docs/development.md) for the full local-install, validation, and troubleshooting guide.

### Prerequisites
````

- [ ] **Step 4.5: Verify `README.md`**

```bash
rg -n 'agent-plugins\.org|plugins/local' README.md
```

Expected: at least two matches.

```bash
rg -n '\.cursor-plugin' README.md
```

Expected: no matches.

- [ ] **Step 4.6: Commit**

```bash
git add AGENTS.md README.md
git commit -m "docs: describe the Agent Plugins package layout in AGENTS.md and README"
```

---

## Task 5: Rewrite `docs/development.md` for the root manifest

**Files:**
- Modify: `docs/development.md`

**Depends on:** Tasks 1 and 2.
**Produces:** a local-install runbook that checks the file that now exists, plus the permanent home for the conformance checks (D4).

This file has six places that name the deleted manifest or an obsolete remedy. Apply each edit below.

- [ ] **Step 5.1: Update the opening description**

Find:

```text
This repository is structured as a Cursor plugin: manifest at `.cursor-plugin/plugin.json`, user-facing skills under `skills/`, subagent definitions under `agents/`, shared prompts under `prompts/`.
```

Replace with:

```text
This repository is an [Agent Plugins](https://agent-plugins.org) 1.0.0 package: manifest at the root `plugin.json`, user-facing skills under `skills/`, subagent definitions under `agents/`, shared prompts under `prompts/`. Cursor loads Agent Plugins and its own `.cursor-plugin/` format side by side; this package uses the portable format only.
```

- [ ] **Step 5.2: Update the install-folder requirement**

Find:

```text
That folder must contain `.cursor-plugin/plugin.json` at its root (same layout as this repo).
```

Replace with:

```text
That folder must contain `plugin.json` at its root (same layout as this repo).
```

- [ ] **Step 5.3: Update the symlink known-issue bullet**

Find:

```text
- the symlink target contains a valid `.cursor-plugin/plugin.json`, and
```

Replace with:

```text
- the symlink target contains a valid root `plugin.json`, and
```

- [ ] **Step 5.4: Exclude `tmp/` from the one-time mirror**

The repo's working tree contains a gitignored `tmp/` directory holding model-experiment output, which does not belong in an install mirror. Find:

```text
rm -rf ~/.cursor/plugins/local/dialectic
mkdir -p ~/.cursor/plugins/local/dialectic
rsync -a --delete /Users/liors/dev/dialectic-agent/ ~/.cursor/plugins/local/dialectic/
```

Replace with:

```text
rm -rf ~/.cursor/plugins/local/dialectic
mkdir -p ~/.cursor/plugins/local/dialectic
rsync -a --delete \
  --exclude '.git/' \
  --exclude '.DS_Store' \
  --exclude '.obsidian/' \
  --exclude 'tmp/' \
  /Users/liors/dev/dialectic-agent/ \
  ~/.cursor/plugins/local/dialectic/
```

Then, in the "Day-to-day iteration (incremental sync)" block below it, find:

```text
  --exclude '.obsidian/' \
  /Users/liors/dev/dialectic-agent/ \
```

Replace with:

```text
  --exclude '.obsidian/' \
  --exclude 'tmp/' \
  /Users/liors/dev/dialectic-agent/ \
```

And in the "Excludes are optional but recommended" list, find:

```text
- `.obsidian/` is editor metadata and should not be part of the plugin mirror.
```

Replace with:

```text
- `.obsidian/` is editor metadata and should not be part of the plugin mirror.
- `tmp/` holds gitignored model-experiment output and is not part of the package.
```

- [ ] **Step 5.5: Update the "what good looks like" expectation for `agents/`**

Find:

```text
Subagent files under `agents/` should **not** show up as user slash-commands.
```

Replace with:

```text
Subagent files under `agents/` should **not** show up as user slash-commands. `agents/` is not a
component type in the Agent Plugins standard, so a conformant client ignores it and the files
travel with the package as plain payload. The orchestrator reads them by path
(`{PROJECT}/agents/role-agent.md`) and passes their contents to a general-purpose subagent, so
debates work whether or not the client registers them as named agent types.
```

- [ ] **Step 5.6: Update the troubleshooting manifest check**

Find:

```text
ls -la ~/.cursor/plugins/local/dialectic/.cursor-plugin/plugin.json
python3 -m json.tool ~/.cursor/plugins/local/dialectic/.cursor-plugin/plugin.json >/dev/null && echo "plugin.json: OK"
```

Replace with:

```text
ls -la ~/.cursor/plugins/local/dialectic/plugin.json
python3 -m json.tool ~/.cursor/plugins/local/dialectic/plugin.json >/dev/null && echo "plugin.json: OK"
```

- [ ] **Step 5.7: Replace the obsolete troubleshooting remedy**

Find:

```text
4. **If skills still don’t show**

Execute Task 9 in `docs/superpowers/plans/2026-05-01-cursor-plugin-publishing.md` (explicit `skills` / `agents` paths in `.cursor-plugin/plugin.json`) as a discovery hard-pin.
```

Replace with:

```text
4. **If skills still don’t show**

Confirm the manifest itself is the problem before anything else — run the validation section
below. A missing or misspelled `$schema` value causes a conformant client to reject the whole
plugin, and the symptom is that no components appear at all.

The Agent Plugins manifest is closed: it cannot pin component paths, so there is no
manifest-level override to force skill discovery. Skills are always discovered from immediate
child directories of `skills/` that contain a regular `SKILL.md` whose frontmatter `name`
matches the directory name.
```

- [ ] **Step 5.8: Add the validation section**

Append to the end of `docs/development.md`:

````text

---

## Validate the package

Run these checks from the repo root before cutting a release. They enforce the Agent Plugins
1.0.0 rules directly rather than fetching the published JSON Schema, because the specification
text is authoritative over the machine-readable schema and clients are forbidden from
retrieving schemas while loading a plugin.

### Manifest

```bash
python3 - << 'PYEOF'
import json, pathlib, re, sys

ALLOWED = {"$schema", "name", "version", "description", "author",
           "homepage", "repository", "license", "keywords", "extensions"}
CANONICAL = "https://agent-plugins.org/schemas/1.0.0/plugin.schema.json"

path = pathlib.Path("plugin.json")
if not path.is_file():
    print("FAIL: no plugin.json at the plugin root (spec 5.1)")
    sys.exit(1)

manifest = json.loads(path.read_text())
errors = []
unknown = sorted(set(manifest) - ALLOWED)
if unknown:
    errors.append(f"unknown top-level fields {unknown} (closed schema, 5.2)")
if manifest.get("$schema") != CANONICAL:
    errors.append(f"$schema must be exactly {CANONICAL} (5.2/5.3)")
name = manifest.get("name")
if not isinstance(name, str) or not re.fullmatch(r"[a-z0-9]([a-z0-9.\-]{0,62}[a-z0-9])?", name) \
        or "--" in name or ".." in name:
    errors.append(f"invalid name {name!r} (5.3/5.5)")
if "author" in manifest:
    extra = sorted(set(manifest["author"]) - {"name", "email", "url"})
    if extra:
        errors.append(f"author has disallowed fields {extra} (5.4)")
for error in errors:
    print(f"FAIL: {error}")
print("PASS: plugin.json conforms to Agent Plugins 1.0.0" if not errors else "")
sys.exit(1 if errors else 0)
PYEOF
```

Expected: `PASS: plugin.json conforms to Agent Plugins 1.0.0`.

### Skills

```bash
python3 - << 'PYEOF'
import pathlib, re, sys

errors, found = [], []
for child in sorted(pathlib.Path("skills").iterdir()):
    if not child.is_dir():
        continue
    skill_md = child / "SKILL.md"
    if not skill_md.is_file():
        errors.append(f"{child}: no regular SKILL.md, not discoverable (7.1)")
        continue
    found.append(child.name)
    match = re.match(r"---\n(.*?)\n---\n", skill_md.read_text(), re.S)
    if not match:
        errors.append(f"{skill_md}: missing YAML frontmatter")
        continue
    name_match = re.search(r"^name:[ \t]*(\S+)[ \t]*$", match.group(1), re.M)
    if not name_match:
        errors.append(f"{skill_md}: no name field")
    elif name_match.group(1) != child.name:
        errors.append(f"{skill_md}: name {name_match.group(1)!r} != directory {child.name!r}")
    if not re.search(r"^description:", match.group(1), re.M):
        errors.append(f"{skill_md}: no description field")

print(f"discovered skills: {found}")
for error in errors:
    print(f"FAIL: {error}")
sys.exit(1 if errors else 0)
PYEOF
```

Expected: `discovered skills: ['judge', 'orchestrate']` and no `FAIL:` lines.

This checks structure and naming. `description` (max 1024 characters) and `compatibility`
(max 500) are checked for presence only; both are well inside their limits and parsing YAML
folded scalars is not worth a dependency here.

### Config generator

```bash
sh -n skills/orchestrate/scripts/create-debate-config.sh && echo "syntax: OK"
sh skills/orchestrate/scripts/create-debate-config.sh </dev/null 2>&1 | head -5
```

Expected: `syntax: OK`, then output containing `Role suggestions loaded from <repo root>/prompts`.
The script is interactive; `head` terminating it is expected. The path must be inside the
package — anything above it means the root resolution regressed.
````

- [ ] **Step 5.9: Verify**

```bash
rg -n '\.cursor-plugin' docs/development.md
```

Expected: exactly one match — the sentence in Step 5.1 explaining that Cursor supports both formats.

```bash
rg -n 'Validate the package' docs/development.md
```

Expected: one match.

- [ ] **Step 5.10: Commit**

```bash
git add docs/development.md
git commit -m "docs: update local dev guide for the root manifest, add validation checks"
```

---

## Task 6: Record the change and mark superseded documents

**Files:**
- Modify: `CHANGELOG.md`
- Modify: `docs/superpowers/plans/2026-05-01-cursor-plugin-publishing.md`
- Modify: `docs/superpowers/specs/2026-05-01-cursor-plugin-publishing-design.md`

**Depends on:** Tasks 1–5 (it describes them).
**Produces:** the `0.2.0` changelog entry Appendix A tags, and pointers that stop a future reader from re-executing the superseded tasks.

- [ ] **Step 6.1: Add the `0.2.0` changelog entry**

In `CHANGELOG.md`, find:

```text
## [Unreleased]

## [0.1.0] — 2026-05-01
```

Replace with:

```text
## [Unreleased]

## [0.2.0] — 2026-08-14
### Added
- Root `plugin.json` manifest conforming to the [Agent Plugins](https://agent-plugins.org)
  specification v1.0.0, so the package loads in any client that implements the standard.
- Plugin-root assertion in `skills/orchestrate/scripts/create-debate-config.sh`: it now fails
  with a diagnostic naming the resolved root instead of reporting a missing prompts directory.
- `docs/development.md`: a "Validate the package" section with the manifest, skill, and config
  generator checks to run before a release.

### Changed
- The manifest moved from `.cursor-plugin/plugin.json` to the root `plugin.json`. Dialectic is
  now an Agent Plugin rather than a Cursor-format plugin. `agents/`, `prompts/`, and
  `debate-config.json` still ship with the package; the skills read them through their
  resolved plugin-root paths.
- `skills/orchestrate/references/debate-loop.md` states the dispatch contract explicitly: read
  `agents/role-agent.md` and pass its contents to a general-purpose subagent, rather than
  relying on a client-registered agent type. `agents/` is not a component type in the
  standard, so clients are not expected to register it.

### Fixed
- `skills/orchestrate/scripts/create-debate-config.sh` resolved the plugin root one directory
  too high (`../../../..` from `skills/orchestrate/scripts/`). Role discovery looked for
  `prompts/` outside the package, so the script always exited with "No available roles were
  found". It now resolves `../../..`.

## [0.1.0] — 2026-05-01
```

- [ ] **Step 6.2: Mark the 0.1.0 publishing plan as partially superseded**

In `docs/superpowers/plans/2026-05-01-cursor-plugin-publishing.md`, find the first two lines:

```text
# Cursor Plugin Publishing Implementation Plan

> **For agentic workers:**
```

Insert the note between them, so the file reads:

```text
# Cursor Plugin Publishing Implementation Plan

> **Historical record — partially superseded.** Task 5 of this plan created the manifest at
> `.cursor-plugin/plugin.json`, and Task 9 offered explicit `skills`/`agents` path pinning in
> it. Both were replaced by the root `plugin.json` in
> [`2026-08-14-agent-plugins-conformance.md`](2026-08-14-agent-plugins-conformance.md).
> **Do not execute Tasks 5 or 9 from this file.** Everything else — the repo layout, the
> self-location Phase 0.0 in Tasks 3 and 4, and the release process in Appendix A — still
> stands. Kept as the record of the 0.1.0 restructure.

> **For agentic workers:**
```

- [ ] **Step 6.3: Mark the 0.1.0 design spec as partially superseded**

In `docs/superpowers/specs/2026-05-01-cursor-plugin-publishing-design.md`, find the first two lines:

```text
# Design — Publishing Dialectic as a Cursor Plugin

**Date:** 2026-05-01
```

Replace with:

```text
# Design — Publishing Dialectic as a Cursor Plugin

> **Historical record — partially superseded.** This design placed the manifest at
> `.cursor-plugin/plugin.json` (Section 4) and assumed the Cursor-specific plugin format
> throughout. The package now targets the [Agent Plugins](https://agent-plugins.org) 1.0.0
> standard with a root `plugin.json`; see
> [`../plans/2026-08-14-agent-plugins-conformance.md`](../plans/2026-08-14-agent-plugins-conformance.md)
> for the decisions that replaced it. The repo layout, self-location design, and release
> process described here are still current.

**Date:** 2026-05-01
```

- [ ] **Step 6.4: Verify**

```bash
rg -n '0\.2\.0' CHANGELOG.md plugin.json
```

Expected: matches in both files, and the versions agree.

```bash
rg -n 'superseded' docs/superpowers/plans/2026-05-01-cursor-plugin-publishing.md docs/superpowers/specs/2026-05-01-cursor-plugin-publishing-design.md
```

Expected: one match in each file.

- [ ] **Step 6.5: Commit**

```bash
git add CHANGELOG.md docs/superpowers/
git commit -m "docs: add 0.2.0 changelog entry, mark 0.1.0 plan and spec superseded"
```

---

## Task 7: Acceptance — install locally and run a full debate

No file changes and no commit. Every step must pass before Appendix A. This task is also the gate on D1: it is where we learn what Cursor does with `agents/` once the Cursor manifest is gone.

- [ ] **Step 7.1: Mirror the repo into Cursor's local plugin directory**

Use the mirror method; symlink installs are documented as unreliable on this machine.

```bash
rm -rf ~/.cursor/plugins/local/dialectic
mkdir -p ~/.cursor/plugins/local/dialectic
rsync -a --delete \
  --exclude '.git/' \
  --exclude '.DS_Store' \
  --exclude '.obsidian/' \
  --exclude 'tmp/' \
  /Users/liors/dev/dialectic-agent/ \
  ~/.cursor/plugins/local/dialectic/
ls -la ~/.cursor/plugins/local/dialectic/plugin.json
ls -la ~/.cursor/plugins/local/dialectic/.cursor-plugin 2>/dev/null || echo "ok: no Cursor manifest in the mirror"
```

Expected: `plugin.json` exists at the mirror root, and `ok: no Cursor manifest in the mirror`.

- [ ] **Step 7.2: Reload Cursor**

Run **Developer: Reload Window** from the Command Palette, or restart Cursor.

- [ ] **Step 7.3: Verify the plugin loaded as an Agent Plugin**

Open **Customize** in the sidebar and confirm `dialectic` is listed as an installed plugin. In the **Cursor Plugins** output panel, search for `dialectic` and `loadUserLocalPlugins` and confirm no manifest or validation errors.

If the plugin does not appear at all, suspect the manifest first: re-run the manifest validation from `docs/development.md`. A rejected `$schema` value suppresses every component.

- [ ] **Step 7.4: Verify skill discovery**

In a fresh Cursor chat, confirm:
- `orchestrate` is available as a skill (`/orchestrate`).
- `judge` is available as a skill (`/judge`).
- Neither `role-agent` nor `role-clarify` appears as a user-invocable skill.

- [ ] **Step 7.5: Record what happened to `agents/` registration**

Check whether `role-agent` and `role-clarify` are still offered as named subagent types when dispatching work.

Both outcomes are acceptable and neither blocks the release — this step exists to record the answer, since it is the open question behind D1 and D2:
- **Not registered** (the expected outcome): `agents/` is not a portable component type, so a client loading the package through the standard ignores it. Step 7.7 proves debates still run.
- **Still registered:** Cursor is applying folder-based discovery regardless of manifest format. Also fine.

Note the result in the commit message of the release commit or in the PR description so the next reader does not have to re-test it.

- [ ] **Step 7.6: Verify the config generator from the installed mirror**

This exercises the Task 2 fix at a second path, which is the point of resolving relative to the script:

```bash
sh ~/.cursor/plugins/local/dialectic/skills/orchestrate/scripts/create-debate-config.sh </dev/null 2>&1 | head -5
```

Expected output contains:

```text
Role suggestions loaded from /Users/liors/.cursor/plugins/local/dialectic/prompts
```

- [ ] **Step 7.7: Run a full debate with no `PROJECT` parameter**

```bash
mkdir -p /tmp/dialectic-conformance-test
cat > /tmp/dialectic-conformance-test/problem.md << 'EOF'
Design a caching strategy for a read-heavy e-commerce product detail API.
Requirements:
- p99 latency under 50ms
- Stock and price must never be stale by more than 5 seconds
- Must work across 3 regions
EOF
```

In Cursor:

> Run the dialectic orchestrate skill. `WORKSPACE=/tmp/dialectic-conformance-test`.

Do **not** pass `PROJECT`. Phase 0.0 must self-locate from the SKILL.md path at
`~/.cursor/plugins/local/dialectic/skills/orchestrate/SKILL.md`.

Expected:
- Phase 0.0 completes with no prompt for `PROJECT`.
- One proposal file per configured agent under `/tmp/dialectic-conformance-test/debate/round-1/proposals/`.
- Critiques and refinements for round 1, and a `verdict.json`.
- `/tmp/dialectic-conformance-test/debate/synthesis.md` exists at completion.

```bash
ls /tmp/dialectic-conformance-test/debate/round-1/proposals/
ls /tmp/dialectic-conformance-test/debate/synthesis.md
```

- [ ] **Step 7.8: Run the judge standalone**

> Run the dialectic judge skill. `MODE=synthesis`. `ROUND=<final round number>`. `WORKSPACE=/tmp/dialectic-conformance-test`.

Expected: the judge's Phase 0.0 self-locates and `synthesis.md` is rewritten.

- [ ] **Step 7.9: Verify the legacy clone-and-reference flow still works**

```bash
mkdir -p /tmp/dialectic-legacy-conformance
cat > /tmp/dialectic-legacy-conformance/problem.md << 'EOF'
Design a session storage layer for a web app with 10k concurrent users.
EOF
```

In Cursor:

> Read and follow the skill at `/Users/liors/dev/dialectic-agent/skills/orchestrate/SKILL.md`. `WORKSPACE=/tmp/dialectic-legacy-conformance`. `PROJECT=/Users/liors/dev/dialectic-agent`.

Expected: the explicit `PROJECT` is honored, not overwritten, and the debate completes with a `synthesis.md`.

- [ ] **Step 7.10: Clean up the scratch workspaces**

```bash
rm -rf /tmp/dialectic-conformance-test /tmp/dialectic-legacy-conformance /tmp/validate-plugin-manifest.py
```

If any step in this task failed because of the manifest change specifically, the reversal path in D1 is a `git revert` of the Task 1 commit — but fix forward first; the likely causes are a typo in `$schema` or a stale mirror.

---

## Self-review checklist

Ran against the request and the specification after drafting; issues found were fixed inline.

- **Request coverage:** root manifest → Task 1. Script path bug → Task 2. Documentation → Tasks 4, 5, 6 (plus Task 3, which is a runtime consequence of the manifest change rather than a doc edit). Keep `agents/` in the package → D2, enforced by Task 3 and verified by Steps 7.5 and 7.7.
- **Spec coverage:** §5.1 location → Step 1.2. §5.2/5.3 `$schema` and `name` → Steps 1.1–1.3. §5.4 metadata types → validator. §5.5 name constraints → validator. §6.1/§7.1 skill discovery → Step 1.4. §4.1 path containment → Task 2 and Step 3.2. §7.2 MCP → not applicable, no `mcp.json` and its absence must not be an error (§6.2). §8 extensions → D1 (why `.cursor-plugin/` goes away). §10.2 versioning → D3.
- **No placeholders:** every step has exact paths, exact find/replace text, exact commands, and expected output.
- **Path consistency:** every reference to the manifest after Task 1 is the root `plugin.json`; every reference to the generator is `skills/orchestrate/scripts/create-debate-config.sh`; the version `0.2.0` is identical in `plugin.json` and `CHANGELOG.md` and is checked in Step 6.4.
- **Ordering:** the two substantive changes come first and are independently testable (Tasks 1, 2), the behavioral clarification follows (Task 3), documentation catches up (Tasks 4, 5, 6), acceptance last (Task 7). Release is deferred.
- **Commits:** one per task, except Task 7 which is acceptance only.

---

## Appendix A — Release `v0.2.0` and refresh the marketplace (DEFERRED)

> **Status:** Do not execute in the same session as Tasks 1–7.
>
> **Precondition:** Tasks 1–7 complete, `plugin_standard` reviewed and merged to `master`, working tree clean.

- [ ] **Step A.1: Confirm state**

```bash
git checkout master
git status
git log --oneline -1
python3 -c "import json; print(json.load(open('plugin.json'))['version'])"
```

Expected: clean tree on `master`, the merge commit at HEAD, and `0.2.0`.

- [ ] **Step A.2: Fast-forward `main` to `master`**

```bash
git checkout main
git merge --ff-only master
```

If the fast-forward is refused, `main` has diverged; resolve that before tagging.

- [ ] **Step A.3: Tag**

```bash
git tag -a v0.2.0 -m "v0.2.0 — Agent Plugins 1.0.0 conformance"
```

- [ ] **Step A.4: Push**

```bash
git push origin master
git push origin main
git push origin v0.2.0
```

- [ ] **Step A.5: Refresh or submit the marketplace listing**

If the plugin is already listed, refresh it (or let Auto Refresh pick up the push to the tracked branch). Cursor re-indexes at most once every ten minutes.

If it has never been submitted, submit `https://github.com/slior/dialectic-agentic` at <https://cursor.com/marketplace/publish>, targeting `main`.

Two things to watch, both carried over from the 0.1.0 spec's open questions:

1. **Format switch.** Cursor detects a plugin's format from its manifest location. This release changes the detected format from Cursor Plugin to Agent Plugin. Both are supported and install through the same flow, but if the listing or existing installs misbehave after the refresh, this is the first thing to look at.
2. **Branch pinning.** The GitHub default branch is `master` while releases live on `main`. If the marketplace only follows the default branch, either change the GitHub default to `main` or collapse the dev/release split.

- [ ] **Step A.6: Note the logo constraint for later**

There is no logo in this repo. If one is wanted for the listing, remember that `logo` is not a permitted field in the closed Agent Plugins manifest — a conformant client must report and ignore it. Adding one means either putting it under `extensions` with Cursor's reverse-domain namespace (undocumented at the time of writing; ask at submission) or reintroducing a `.cursor-plugin/plugin.json`, which reopens D1.

- [ ] **Step A.7: Return to `master`**

```bash
git checkout master
```
