# Developing and testing the Cursor plugin locally

This repository is structured as a Cursor plugin: manifest at `.cursor-plugin/plugin.json`, user-facing skills under `skills/`, subagent definitions under `agents/`, shared prompts under `prompts/`.

For Cursor’s documented local testing flow, see [Plugins — Test plugins locally](https://cursor.com/docs/plugins.md). For how skills are discovered and invoked in Agent chat (`/skill-name`), see [Agent Skills](https://cursor.com/docs/skills.md).

---

## Install into Cursor’s local plugins directory

Cursor loads user-local plugins from:

`~/.cursor/plugins/local/<plugin-folder>/`

That folder must contain `.cursor-plugin/plugin.json` at its root (same layout as this repo).

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

- the symlink target contains a valid `.cursor-plugin/plugin.json`, and
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
rsync -a --delete /Users/liors/dev/dialectic-agent/ ~/.cursor/plugins/local/dialectic/
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
  /Users/liors/dev/dialectic-agent/ \
  ~/.cursor/plugins/local/dialectic/
```

Excludes are optional but recommended:

- `.git/` is large and not needed for Cursor to load plugin components.
- `.obsidian/` is editor metadata and should not be part of the plugin mirror.

Then restart Cursor or reload the window if you changed plugin-level metadata and want to force a rescan.

---

## What “good” looks like after install

### In Cursor Settings

Open **Cursor Settings → Rules**:

- User-facing skills should appear under **Agent Decides** (or equivalent “skills” UI in your build), minimally:
  - `orchestrate`
  - `judge`

Subagent files under `agents/` should **not** show up as user slash-commands.

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
ls -la ~/.cursor/plugins/local/dialectic/.cursor-plugin/plugin.json
python3 -m json.tool ~/.cursor/plugins/local/dialectic/.cursor-plugin/plugin.json >/dev/null && echo "plugin.json: OK"
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

Execute Task 9 in `docs/superpowers/plans/2026-05-01-cursor-plugin-publishing.md` (explicit `skills` / `agents` paths in `.cursor-plugin/plugin.json`) as a discovery hard-pin.
