# Developing and testing the Cursor plugin locally

This repository is an [Agent Plugins](https://agent-plugins.org) 1.0.0 package: manifest at the root `plugin.json`, user-facing skills under `skills/`, subagent definitions under `agents/`, shared prompts under `prompts/`. Cursor loads Agent Plugins and its own `.cursor-plugin/` format side by side; this package uses the portable format only.

Conformance is about packaging and discovery. Two things a debate depends on are outside the standard, so they are worth keeping in mind while testing: subagent dispatch, which the standard does not define at all, and Phase 0.0 self-location, which needs the client to tell a skill the absolute path it was loaded from. The spec's `PLUGIN_ROOT` guarantee (§9.1) covers only stdio MCP subprocesses, and this package has no `mcp.json`, so it does not apply to the skills. Cursor supplies both; on a client that does not, invoke the skills with an explicit `PROJECT=/absolute/path`.

For Cursor’s documented local testing flow, see [Plugins — Test plugins locally](https://cursor.com/docs/plugins.md). For how skills are discovered and invoked in Agent chat (`/skill-name`), see [Agent Skills](https://cursor.com/docs/skills.md).

---

## Install into Cursor’s local plugins directory

Cursor loads user-local plugins from:

`~/.cursor/plugins/local/<plugin-folder>/`

That folder must contain `plugin.json` at its root (same layout as this repo).

**Recommended install folder name for this project:** `dialectic`  
(Folder name is arbitrary; it does not need to match `plugin.json` `name`.)

---

## Method A (fast): symlink the repo checkout

The Cursor docs suggest symlinking a plugin repo for faster iteration:

```bash
mkdir -p ~/.cursor/plugins/local
ln -sfn /Users/liors/dev/dialectic-agent ~/.cursor/plugins/local/dialectic
```

Then restart Cursor (or **Developer: Reload Window**) and verify components load.

### Known issue: symlink traversal may not work on some setups

Some developers observe that Cursor loads **zero** user-local plugins when the local plugin path is a symlink, even though:

- the symlink target contains a valid root `plugin.json`, and
- copying the same tree into `~/.cursor/plugins/local/dialectic/` fixes loading immediately.

Symptoms to look for in the **Cursor Plugins** output log:

- `loadUserLocalPlugins ... (0 plugins loaded)` persisting across reloads, **while** marketplace plugins still load normally.

**Mitigation:** use Method B (directory copy / mirror) below.

---

## Method B (reliable): mirror the repo into the local plugin directory

This creates a real directory at the install path (no symlink indirection), which avoids symlink-traversal limitations in the loader.

### One-time setup (clean mirror)

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
```

Notes:

- **Trailing slashes matter** in rsync: `SRC/` means “copy the contents of SRC”.
- `--delete` removes files in the destination that no longer exist in the source (keeps the mirror faithful).

### Day-to-day iteration (incremental sync)

After you change files in the repo:

```bash
rsync -a --delete \
  --exclude '.git/' \
  --exclude '.DS_Store' \
  --exclude '.obsidian/' \
  --exclude 'tmp/' \
  /Users/liors/dev/dialectic-agent/ \
  ~/.cursor/plugins/local/dialectic/
```

Excludes are optional but recommended:

- `.git/` is large and not needed for Cursor to load plugin components.
- `.obsidian/` is editor metadata and should not be part of the plugin mirror.
- `tmp/` holds gitignored model-experiment output and is not part of the package.

Then restart Cursor or reload the window if you changed plugin-level metadata and want to force a rescan.

---

## What “good” looks like after install

### In Cursor Settings

Open **Cursor Settings → Rules**:

- User-facing skills should appear under **Agent Decides** (or equivalent “skills” UI in your build), minimally:
  - `orchestrate`
  - `judge`

Subagent files under `agents/` should **not** show up as user slash-commands. `agents/` is not a
component type in the Agent Plugins standard, so a conformant client ignores it and the files
travel with the package as plain payload. The orchestrator reads them by path
(`{PROJECT}/agents/role-agent.md`) and passes their contents to a general-purpose subagent, so
debates work whether or not the client registers them as named agent types.

### In Agent chat

- Typing `/` should allow searching for `/orchestrate` and `/judge` (per [Skills](https://cursor.com/docs/skills.md)).

---

## Smoke test the debate workflow

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

In Cursor Agent chat:

> Run the dialectic orchestrate skill. `WORKSPACE=/tmp/dialectic-smoke-test`.

Do **not** pass `PROJECT` — the orchestrator should self-locate when running from the installed plugin mirror.

Expected artifacts include at least:

- `/tmp/dialectic-smoke-test/debate/round-1/proposals/*.md`
- `/tmp/dialectic-smoke-test/debate/synthesis.md`

---

## Troubleshooting checklist

1. **Confirm the installed tree exists and is readable**

```bash
ls -la ~/.cursor/plugins/local/dialectic/plugin.json
python3 -m json.tool ~/.cursor/plugins/local/dialectic/plugin.json >/dev/null && echo "plugin.json: OK"
```

2. **If symlink install fails but copy works**

Switch to Method B and treat symlink installs as unsupported on your machine.

3. **Inspect Cursor plugin logs**

In the **Cursor Plugins** output panel, search for:

- `loadUserLocalPlugins`
- `failed`
- `manifest`
- `dialectic`

4. **If skills still don’t show**

Confirm the manifest itself is the problem before anything else — run the validation section
below. A missing or misspelled `$schema` value causes a conformant client to reject the whole
plugin, and the symptom is that no components appear at all.

The Agent Plugins manifest is closed: it cannot pin component paths, so there is no
manifest-level override to force skill discovery. Skills are always discovered from immediate
child directories of `skills/` that contain a regular `SKILL.md` whose frontmatter `name`
matches the directory name.

---

## Validate the package

Run these checks from the repo root before cutting a release. They enforce the Agent Plugins
1.0.0 rules and the Agent Skills frontmatter rules directly rather than fetching the published
JSON Schemas, because the specification text is authoritative over the machine-readable schema
and clients are forbidden from retrieving schemas while loading a plugin.

These checks print `FAIL:` lines and exit non-zero on any violation, and print a `PASS:` line
only when everything holds. Never read "no output" as success — check the exit status.

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

try:
    manifest = json.loads(path.read_text())
except json.JSONDecodeError as exc:
    print(f"FAIL: plugin.json is not valid JSON: {exc}")
    sys.exit(1)

if not isinstance(manifest, dict):
    print(f"FAIL: manifest must be a JSON object, got {type(manifest).__name__} (5.2)")
    sys.exit(1)

errors = []

unknown = sorted(set(manifest) - ALLOWED)
if unknown:
    errors.append(f"unknown top-level fields {unknown} (closed schema, 5.2)")

if manifest.get("$schema") != CANONICAL:
    errors.append(f"$schema must be exactly {CANONICAL}, got {manifest.get('$schema')!r} (5.2/5.3)")

name = manifest.get("name")
if not isinstance(name, str) or not name:
    errors.append(f"name is missing, empty, or not a string: {name!r} (5.3)")
elif (len(name) > 64
      or not re.fullmatch(r"[a-z0-9]([a-z0-9.\-]*[a-z0-9])?", name)
      or "--" in name or ".." in name):
    errors.append(f"name {name!r} violates the naming constraints (5.5)")

for field in ("version", "description", "homepage", "repository", "license"):
    if field in manifest and not isinstance(manifest[field], str):
        errors.append(f"{field} must be a string, got {type(manifest[field]).__name__} (5.4)")

if "author" in manifest:
    author = manifest["author"]
    if not isinstance(author, dict):
        errors.append(f"author must be an object, got {type(author).__name__} (5.4)")
    else:
        extra = sorted(set(author) - {"name", "email", "url"})
        if extra:
            errors.append(f"author has disallowed fields {extra} (5.4)")
        for key, value in author.items():
            if not isinstance(value, str):
                errors.append(f"author.{key} must be a string (5.4)")

if "keywords" in manifest:
    keywords = manifest["keywords"]
    if not isinstance(keywords, list) or any(not isinstance(k, str) for k in keywords):
        errors.append("keywords must be an array of strings (5.4)")

if "extensions" in manifest and not isinstance(manifest["extensions"], dict):
    errors.append("extensions must be an object (8.1)")

for error in errors:
    print(f"FAIL: {error}")
if errors:
    sys.exit(1)
print("PASS: plugin.json conforms to Agent Plugins 1.0.0")
PYEOF
```

Expected: `PASS: plugin.json conforms to Agent Plugins 1.0.0`, exit status 0.

### Skills

```bash
python3 - << 'PYEOF'
import pathlib, re, sys

NAME_RE = re.compile(r"[a-z0-9]+(-[a-z0-9]+)*")


def scalar(frontmatter, key):
    """Read a frontmatter value, including '>-' and '|' folded block scalars."""
    lines = frontmatter.split("\n")
    for index, line in enumerate(lines):
        match = re.match(rf"^{key}:[ \t]*(.*)$", line)
        if not match:
            continue
        head = match.group(1).strip()
        if head in (">", ">-", ">+", "|", "|-", "|+", ""):
            body = []
            for continuation in lines[index + 1:]:
                if continuation.strip() and not continuation.startswith((" ", "\t")):
                    break
                body.append(continuation.strip())
            return " ".join(part for part in body if part).strip()
        return head.strip("'\"").strip()
    return None


errors = []
skills_dir = pathlib.Path("skills")
if not skills_dir.is_dir():
    print("FAIL: skills/ is missing or is not a directory (6.2)")
    sys.exit(1)

found = []
for child in sorted(skills_dir.iterdir()):
    if not child.is_dir():
        continue
    skill_md = child / "SKILL.md"
    if not skill_md.is_file():
        errors.append(f"{child}: no regular SKILL.md, so it is not discoverable (7.1)")
        continue
    found.append(child.name)

    match = re.match(r"---\n(.*?)\n---\n", skill_md.read_text(), re.S)
    if not match:
        errors.append(f"{skill_md}: missing or malformed YAML frontmatter")
        continue
    frontmatter = match.group(1)

    name = scalar(frontmatter, "name")
    if not name:
        errors.append(f"{skill_md}: name is missing or empty")
    else:
        if name != child.name:
            errors.append(f"{skill_md}: name {name!r} != directory {child.name!r}")
        if len(name) > 64 or not NAME_RE.fullmatch(name):
            errors.append(f"{skill_md}: name {name!r} is not 1-64 chars of [a-z0-9-] "
                          "without leading, trailing, or doubled hyphens")

    description = scalar(frontmatter, "description")
    if not description:
        errors.append(f"{skill_md}: description is missing or empty")
    elif len(description) > 1024:
        errors.append(f"{skill_md}: description is {len(description)} chars, max 1024")

    compatibility = scalar(frontmatter, "compatibility")
    if compatibility is not None and len(compatibility) > 500:
        errors.append(f"{skill_md}: compatibility is {len(compatibility)} chars, max 500")

if not found:
    errors.append("no skills discovered under skills/ — the package would load with no components")

print(f"discovered skills: {found}")
for error in errors:
    print(f"FAIL: {error}")
if errors:
    sys.exit(1)
print("PASS: all skills conform to the Agent Skills frontmatter rules")
PYEOF
```

Expected: `discovered skills: ['judge', 'orchestrate']` followed by
`PASS: all skills conform to the Agent Skills frontmatter rules`, exit status 0.

### Config generator

Syntax-check the script, then drive it to completion and validate what it writes. Never pipe it
into `head`: a pipeline reports the exit status of its last command, so a script failure would be
masked.

```bash
sh -n skills/orchestrate/scripts/create-debate-config.sh && echo "syntax: OK"

OUT=/tmp/dialectic-gen-check.json
rm -f "$OUT"
printf '1\narchitect\n\n\n\n\n\n\n\n%s\n' "$OUT" > /tmp/dialectic-gen-answers.txt
sh skills/orchestrate/scripts/create-debate-config.sh \
  < /tmp/dialectic-gen-answers.txt > /tmp/dialectic-gen-stdout.txt 2>&1
echo "exit status: $?"
grep '^Role suggestions loaded from ' /tmp/dialectic-gen-stdout.txt
python3 -c "import json,sys; c=json.load(open(sys.argv[1])); \
req=['agents','judge','convergence','clarifications','tools','agents_config']; \
missing=[k for k in req if k not in c]; \
sys.exit(f'FAIL: missing {missing}') if missing else print('PASS: generated config is valid')" "$OUT"
rm -f /tmp/dialectic-gen-check.json /tmp/dialectic-gen-answers.txt /tmp/dialectic-gen-stdout.txt
```

The answer stream is: `1` agent, role `architect`, seven blank lines accepting defaults, then the
output path. Expected `syntax: OK`, `exit status: 0`, a `Role suggestions loaded from` line
pointing **inside** the package, and `PASS: generated config is valid`. A prompts path above the
package root means the plugin-root resolution has regressed.
